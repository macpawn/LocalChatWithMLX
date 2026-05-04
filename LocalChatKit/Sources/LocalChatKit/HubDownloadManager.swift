import Foundation

struct HubDownloadConfiguration: Sendable {
    let chunkedDownloadThreshold: Int64
    let chunkSize: Int64
    let maxConcurrentChunksPerFile: Int

    init(
        chunkedDownloadThreshold: Int64 = 64 * 1024 * 1024,
        chunkSize: Int64 = 16 * 1024 * 1024,
        maxConcurrentChunksPerFile: Int = 4
    ) {
        precondition(chunkedDownloadThreshold > 0, "Chunked download threshold must be positive")
        precondition(chunkSize > 0, "Chunk size must be positive")
        precondition(maxConcurrentChunksPerFile > 0, "Chunk concurrency must be positive")
        self.chunkedDownloadThreshold = chunkedDownloadThreshold
        self.chunkSize = chunkSize
        self.maxConcurrentChunksPerFile = maxConcurrentChunksPerFile
    }
}

// MARK: - HubDownloadManager

public actor HubDownloadManager: HubDownloaderProtocol {

    public let storage: ModelStorageConfig
    private let modelFileRegistry: ModelFileManifestRegistry
    private let repoMetadataProvider: any HFRepoMetadataProviding
    private let session: URLSession
    private let downloadConfiguration: HubDownloadConfiguration

    public init(
        storage: ModelStorageConfig = .default,
        modelFileRegistry: ModelFileManifestRegistry = ModelFileManifestRegistry()
    ) {
        self.init(
            storage: storage,
            modelFileRegistry: modelFileRegistry,
            repoMetadataProvider: LiveHFRepoMetadataProvider(),
            session: .shared,
            downloadConfiguration: HubDownloadConfiguration()
        )
    }

    init(
        storage: ModelStorageConfig,
        modelFileRegistry: ModelFileManifestRegistry = ModelFileManifestRegistry(),
        repoMetadataProvider: any HFRepoMetadataProviding,
        session: URLSession = .shared,
        downloadConfiguration: HubDownloadConfiguration = HubDownloadConfiguration()
    ) {
        self.storage = storage
        self.modelFileRegistry = modelFileRegistry
        self.repoMetadataProvider = repoMetadataProvider
        self.session = session
        self.downloadConfiguration = downloadConfiguration
    }

    // MARK: - Public API

    public func isDownloaded(_ model: Model, check: ModelDownloadCheckMode = .fast) async -> Bool {
        guard let meta = try? await repoMetadataProvider.fetchRepoMeta(modelID: model.huggingFaceID),
              !meta.files.isEmpty else { return false }

        let snapshotDirectory = storage.baseDirectory
            .appendingPathComponent(model.hubCacheDirName)
            .appendingPathComponent("snapshots")
            .appendingPathComponent(meta.commitHash)

        return meta.files.allSatisfy { file in
            let fileURL = snapshotDirectory.appendingPathComponent(file.relativePath)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return false }

            switch check {
            case .fast:
                guard file.size > 0,
                      let actualSize = try? fileURL.localFileSize() else { return false }
                return actualSize == file.size
            case .thorough:
                guard !file.sha256.isEmpty,
                      let actualHash = try? ModelFileHasher.sha256(for: fileURL) else { return false }
                return actualHash == file.sha256
            }
        }
    }

    public nonisolated func download(_ model: Model) -> AsyncThrowingStream<DownloadProgress, Error> {
        let storage = self.storage
        let session = self.session
        let downloadConfiguration = self.downloadConfiguration
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let meta = try await repoMetadataProvider.fetchRepoMeta(modelID: model.huggingFaceID)
                    let dirs = try HFCacheDirs.prepare(
                        base: storage.baseDirectory,
                        model: model,
                        commit: meta.commitHash
                    )
                    let totalBytes = max(meta.totalBytes, 1)
                    let progress = DownloadProgressAggregator()
                    let semaphore = AsyncSemaphore(limit: 4)

                    try await withThrowingTaskGroup(of: Void.self) { group in
                        for file in meta.files {
                            group.addTask {
                                try await semaphore.acquire()
                                do {
                                    let blobKey = file.sha256.isEmpty ? file.relativePath : file.sha256
                                    let blobPath = dirs.blobs.appendingPathComponent(blobKey)
                                    let linkPath = dirs.snapshot.appendingPathComponent(file.relativePath)

                                    if FileManager.default.fileExists(atPath: blobPath.path) {
                                        let (current, speed) = await progress.addCached(file.size)
                                        continuation.yield(DownloadProgress(
                                            percent: hfPct(current, of: totalBytes),
                                            bytesDownloaded: current,
                                            totalBytes: totalBytes,
                                            bytesPerSecond: speed
                                        ))
                                        try HFCacheDirs.ensureSymlink(at: linkPath, blobKey: blobKey, relativePath: file.relativePath)
                                        await semaphore.release()
                                        return
                                    }

                                    var components = URLComponents()
                                    components.scheme = "https"
                                    components.host = "huggingface.co"
                                    components.path = "/\(model.huggingFaceID)/resolve/\(meta.commitHash)/\(file.relativePath)"
                                    guard let remoteURL = components.url else {
                                        throw HFError.invalidURL
                                    }

                                    for try await written in self.streamDownload(
                                        from: remoteURL,
                                        to: blobPath,
                                        expectedSize: file.size,
                                        session: session,
                                        configuration: downloadConfiguration
                                    ) {
                                        let (current, speed) = await progress.update(file: file.relativePath, written: written)
                                        continuation.yield(DownloadProgress(
                                            percent: hfPct(current, of: totalBytes),
                                            bytesDownloaded: current,
                                            totalBytes: totalBytes,
                                            bytesPerSecond: speed
                                        ))
                                    }

                                    let (current, speed) = await progress.finish(file: file.relativePath, finalSize: file.size)
                                    continuation.yield(DownloadProgress(
                                        percent: hfPct(current, of: totalBytes),
                                        bytesDownloaded: current,
                                        totalBytes: totalBytes,
                                        bytesPerSecond: speed
                                    ))
                                    try HFCacheDirs.ensureSymlink(at: linkPath, blobKey: blobKey, relativePath: file.relativePath)
                                    await semaphore.release()
                                } catch {
                                    await semaphore.release()
                                    throw error
                                }
                            }
                        }
                        try await group.waitForAll()
                    }

                    try modelFileRegistry.saveManifest(
                        for: model,
                        storage: storage,
                        commitHash: meta.commitHash,
                        relativePaths: meta.files.map(\.relativePath)
                    )

                    continuation.yield(DownloadProgress(
                        percent: 100,
                        bytesDownloaded: totalBytes,
                        totalBytes: totalBytes,
                        bytesPerSecond: 0
                    ))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: LocalChatError.downloadFailed(underlying: error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Download Stream

    nonisolated private func streamDownload(
        from url: URL,
        to destination: URL,
        expectedSize: Int64,
        session: URLSession,
        configuration: HubDownloadConfiguration
    ) -> AsyncThrowingStream<Int64, Error> {
        AsyncThrowingStream { c in
            let task = Task {
                do {
                    if expectedSize > configuration.chunkedDownloadThreshold {
                        do {
                            try await self.chunkedDownload(
                                from: url,
                                to: destination,
                                expectedSize: expectedSize,
                                session: session,
                                configuration: configuration,
                                progress: { c.yield($0) }
                            )
                            c.finish()
                            return
                        } catch is RangeDownloadUnsupported {
                            try await self.singleStreamDownload(
                                from: url,
                                to: destination,
                                session: session,
                                progress: { c.yield($0) }
                            )
                            c.finish()
                            return
                        }
                    }

                    try await self.singleStreamDownload(
                        from: url,
                        to: destination,
                        session: session,
                        progress: { c.yield($0) }
                    )
                    c.finish()
                } catch {
                    c.finish(throwing: error)
                }
            }
            c.onTermination = { _ in task.cancel() }
        }
    }

    nonisolated private func singleStreamDownload(
        from url: URL,
        to destination: URL,
        session: URLSession,
        progress: (Int64) -> Void
    ) async throws {
        let (asyncBytes, response) = try await session.bytes(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let tmp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        fm.createFile(atPath: tmp.path, contents: nil)
        let fh = try FileHandle(forWritingTo: tmp)
        var didClose = false
        defer {
            if !didClose {
                try? fh.close()
            }
            try? fm.removeItem(at: tmp)
        }

        var buf = [UInt8]()
        buf.reserveCapacity(1024 * 1024)
        var total: Int64 = 0
        for try await byte in asyncBytes {
            try Task.checkCancellation()
            buf.append(byte)
            if buf.count >= 1024 * 1024 {
                try fh.write(contentsOf: buf)
                total += Int64(buf.count)
                buf.removeAll(keepingCapacity: true)
                progress(total)
            }
        }
        if !buf.isEmpty {
            try fh.write(contentsOf: buf)
            total += Int64(buf.count)
        }
        try fh.close()
        didClose = true
        try? fm.removeItem(at: destination)
        try fm.moveItem(at: tmp, to: destination)
        progress(total)
    }

    nonisolated private func chunkedDownload(
        from url: URL,
        to destination: URL,
        expectedSize: Int64,
        session: URLSession,
        configuration: HubDownloadConfiguration,
        progress: (Int64) -> Void
    ) async throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let ranges = byteRanges(totalSize: expectedSize, chunkSize: configuration.chunkSize)
        let semaphore = AsyncSemaphore(limit: configuration.maxConcurrentChunksPerFile)
        var results: [ChunkDownloadResult] = []
        var completedBytes: Int64 = 0

        try await withThrowingTaskGroup(of: ChunkDownloadResult.self) { group in
            for (index, range) in ranges.enumerated() {
                group.addTask {
                    try await semaphore.acquire()
                    do {
                        let result = try await downloadChunk(
                            from: url,
                            range: range,
                            index: index,
                            tempDir: tempDir,
                            session: session
                        )
                        await semaphore.release()
                        return result
                    } catch {
                        await semaphore.release()
                        throw error
                    }
                }
            }

            for try await result in group {
                results.append(result)
                completedBytes += result.byteCount
                progress(min(completedBytes, expectedSize))
            }
        }

        guard results.count == ranges.count else {
            throw URLError(.badServerResponse)
        }

        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let assembled = tempDir.appendingPathComponent("assembled")
        fm.createFile(atPath: assembled.path, contents: nil)
        let output = try FileHandle(forWritingTo: assembled)
        var didClose = false
        defer {
            if !didClose {
                try? output.close()
            }
        }

        for result in results.sorted(by: { $0.index < $1.index }) {
            let data = try Data(contentsOf: result.fileURL)
            try output.write(contentsOf: data)
        }

        try output.close()
        didClose = true
        try? fm.removeItem(at: destination)
        try fm.moveItem(at: assembled, to: destination)
    }
}

private struct ByteRange: Sendable {
    let start: Int64
    let end: Int64

    var byteCount: Int64 {
        end - start + 1
    }

    var headerValue: String {
        "bytes=\(start)-\(end)"
    }
}

private struct ChunkDownloadResult: Sendable {
    let index: Int
    let byteCount: Int64
    let fileURL: URL
}

private struct RangeDownloadUnsupported: Error {}

private func byteRanges(totalSize: Int64, chunkSize: Int64) -> [ByteRange] {
    stride(from: Int64(0), to: totalSize, by: Int(chunkSize)).map { start in
        ByteRange(start: start, end: min(start + chunkSize - 1, totalSize - 1))
    }
}

private func downloadChunk(
    from url: URL,
    range: ByteRange,
    index: Int,
    tempDir: URL,
    session: URLSession
) async throws -> ChunkDownloadResult {
    var request = URLRequest(url: url)
    request.setValue(range.headerValue, forHTTPHeaderField: "Range")

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
        throw URLError(.badServerResponse)
    }

    guard http.statusCode == 206 else {
        if (200..<300).contains(http.statusCode) {
            throw RangeDownloadUnsupported()
        }
        throw URLError(.badServerResponse)
    }

    guard Int64(data.count) == range.byteCount else {
        throw URLError(.badServerResponse)
    }

    let fileURL = tempDir.appendingPathComponent(String(format: "%06d.chunk", index))
    try data.write(to: fileURL, options: .atomic)
    return ChunkDownloadResult(index: index, byteCount: Int64(data.count), fileURL: fileURL)
}

// MARK: - DownloadProgressAggregator

private actor DownloadProgressAggregator {
    private var completedBytes: Int64 = 0
    private var inFlight: [String: Int64] = [:]
    private var speedTracker = DownloadSpeedTracker()

    func update(file: String, written: Int64) -> (Int64, Double) {
        inFlight[file] = written
        let current = completedBytes + inFlight.values.reduce(0, +)
        let speed = speedTracker.speed(at: current)
        return (current, speed)
    }

    func finish(file: String, finalSize: Int64) -> (Int64, Double) {
        inFlight[file] = nil
        completedBytes += finalSize
        let current = completedBytes
        let speed = speedTracker.speed(at: current)
        return (current, speed)
    }

    func addCached(_ size: Int64) -> (Int64, Double) {
        completedBytes += size
        let current = completedBytes
        let speed = speedTracker.speed(at: current)
        return (current, speed)
    }
}

// MARK: - DownloadSpeedTracker

private struct DownloadSpeedTracker {
    private var lastDate = Date()
    private var lastBytes: Int64 = 0
    private var smoothed: Double = 0

    mutating func speed(at bytes: Int64) -> Double {
        let now = Date()
        let dt = now.timeIntervalSince(lastDate)
        guard dt >= 0.3 else { return smoothed }
        let instant = Double(bytes - lastBytes) / dt
        smoothed = smoothed == 0 ? instant : smoothed * 0.7 + instant * 0.3
        lastDate = now
        lastBytes = bytes
        return max(0, smoothed)
    }
}

// MARK: - Helpers

private func hfPct(_ done: Int64, of total: Int64) -> Int {
    guard total > 0 else { return 0 }
    return Int(min(100.0, Double(done) / Double(total) * 100.0))
}

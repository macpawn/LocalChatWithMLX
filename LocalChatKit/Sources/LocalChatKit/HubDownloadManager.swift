import Foundation

// MARK: - HubDownloadManager

public actor HubDownloadManager: HubDownloaderProtocol {

    public let storage: ModelStorageConfig
    private let modelFileRegistry: ModelFileManifestRegistry
    private let repoMetadataProvider: any HFRepoMetadataProviding

    public init(
        storage: ModelStorageConfig = .default,
        modelFileRegistry: ModelFileManifestRegistry = ModelFileManifestRegistry()
    ) {
        self.init(
            storage: storage,
            modelFileRegistry: modelFileRegistry,
            repoMetadataProvider: LiveHFRepoMetadataProvider()
        )
    }

    init(
        storage: ModelStorageConfig,
        modelFileRegistry: ModelFileManifestRegistry = ModelFileManifestRegistry(),
        repoMetadataProvider: any HFRepoMetadataProviding
    ) {
        self.storage = storage
        self.modelFileRegistry = modelFileRegistry
        self.repoMetadataProvider = repoMetadataProvider
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

                                    for try await written in self.streamDownload(from: remoteURL, to: blobPath) {
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

    nonisolated private func streamDownload(from url: URL, to destination: URL) -> AsyncThrowingStream<Int64, Error> {
        AsyncThrowingStream { c in
            let task = Task {
                do {
                    let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
                    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        throw URLError(.badServerResponse)
                    }
                    let tmp = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                    FileManager.default.createFile(atPath: tmp.path, contents: nil)
                    let fh = try FileHandle(forWritingTo: tmp)
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
                            c.yield(total)
                        }
                    }
                    if !buf.isEmpty {
                        try fh.write(contentsOf: buf)
                        total += Int64(buf.count)
                    }
                    try fh.close()
                    try FileManager.default.moveItem(at: tmp, to: destination)
                    c.yield(total)
                    c.finish()
                } catch {
                    c.finish(throwing: error)
                }
            }
            c.onTermination = { _ in task.cancel() }
        }
    }
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

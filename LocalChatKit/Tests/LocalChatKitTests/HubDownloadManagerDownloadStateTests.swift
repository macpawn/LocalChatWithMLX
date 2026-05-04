import Foundation
import Testing
@testable import LocalChatKit

private struct StubHFRepoMetadataProvider: HFRepoMetadataProviding {
    let meta: HFRepoMeta

    func fetchRepoMeta(modelID: String) async throws -> HFRepoMeta {
        meta
    }
}

@Suite(.serialized)
struct HubDownloadManagerDownloadStateTests {

    @Test func thoroughIsDownloadedFetchesRemoteManifestAndValidatesLocalHashes() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HubDownloadManagerDownloadStateTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let snapshot = tmpDir
            .appendingPathComponent(Model.smolLM135M.hubCacheDirName)
            .appendingPathComponent("snapshots")
            .appendingPathComponent("abc123")
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: snapshot.appendingPathComponent("config.json"))

        let manager = HubDownloadManager(
            storage: ModelStorageConfig(baseDirectory: tmpDir),
            repoMetadataProvider: StubHFRepoMetadataProvider(
                meta: HFRepoMeta(
                    commitHash: "abc123",
                    files: [
                        HFFileMeta(
                            relativePath: "config.json",
                            sha256: "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
                            size: 5
                        )
                    ]
                )
            )
        )

        #expect(await manager.isDownloaded(.smolLM135M, check: .thorough))
    }

    @Test func isDownloadedReturnsFalseWhenRemoteHashDoesNotMatchLocalFile() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HubDownloadManagerDownloadStateTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let snapshot = tmpDir
            .appendingPathComponent(Model.smolLM135M.hubCacheDirName)
            .appendingPathComponent("snapshots")
            .appendingPathComponent("abc123")
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)
        try Data("changed".utf8).write(to: snapshot.appendingPathComponent("config.json"))

        let manager = HubDownloadManager(
            storage: ModelStorageConfig(baseDirectory: tmpDir),
            repoMetadataProvider: StubHFRepoMetadataProvider(
                meta: HFRepoMeta(
                    commitHash: "abc123",
                    files: [
                        HFFileMeta(
                            relativePath: "config.json",
                            sha256: "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
                            size: 5
                        )
                    ]
                )
            )
        )

        #expect(!(await manager.isDownloaded(.smolLM135M, check: .thorough)))
    }

    @Test func fastIsDownloadedOnlyRequiresMatchingRemoteFileSize() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HubDownloadManagerDownloadStateTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let snapshot = tmpDir
            .appendingPathComponent(Model.smolLM135M.hubCacheDirName)
            .appendingPathComponent("snapshots")
            .appendingPathComponent("abc123")
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)
        try Data("abcde".utf8).write(to: snapshot.appendingPathComponent("config.json"))

        let manager = HubDownloadManager(
            storage: ModelStorageConfig(baseDirectory: tmpDir),
            repoMetadataProvider: StubHFRepoMetadataProvider(
                meta: HFRepoMeta(
                    commitHash: "abc123",
                    files: [
                        HFFileMeta(
                            relativePath: "config.json",
                            sha256: "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
                            size: 5
                        )
                    ]
                )
            )
        )

        #expect(await manager.isDownloaded(.smolLM135M, check: .fast))
    }

    @Test func largeFileDownloadUsesRangeRequestsAndReportsProgress() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HubDownloadManagerDownloadStateTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let bytes = Data((0..<16).map(UInt8.init))
        RangeStubURLProtocol.reset(bytes: bytes, mode: .rangeResponses)
        let session = URLSession(configuration: RangeStubURLProtocol.sessionConfiguration())
        defer { session.invalidateAndCancel() }

        let manager = HubDownloadManager(
            storage: ModelStorageConfig(baseDirectory: tmpDir),
            repoMetadataProvider: StubHFRepoMetadataProvider(
                meta: HFRepoMeta(
                    commitHash: "abc123",
                    files: [
                        HFFileMeta(
                            relativePath: "model.safetensors",
                            sha256: "large-sha",
                            size: Int64(bytes.count)
                        )
                    ]
                )
            ),
            session: session,
            downloadConfiguration: HubDownloadConfiguration(
                chunkedDownloadThreshold: 8,
                chunkSize: 4,
                maxConcurrentChunksPerFile: 2
            )
        )

        var progressEvents: [DownloadProgress] = []
        for try await event in manager.download(.smolLM135M) {
            progressEvents.append(event)
        }

        let savedBlob = tmpDir
            .appendingPathComponent(Model.smolLM135M.hubCacheDirName)
            .appendingPathComponent("blobs")
            .appendingPathComponent("large-sha")
        #expect(try Data(contentsOf: savedBlob) == bytes)
        #expect(Set(RangeStubURLProtocol.rangeHeaders) == [
            "bytes=0-3",
            "bytes=4-7",
            "bytes=8-11",
            "bytes=12-15",
        ])
        #expect(progressEvents.contains { $0.bytesDownloaded > 0 && $0.bytesDownloaded < Int64(bytes.count) })
        #expect(progressEvents.last?.bytesDownloaded == Int64(bytes.count))
        #expect(progressEvents.last?.percent == 100)
    }

    @Test func largeFileDownloadFallsBackWhenRangeRequestsAreNotSupported() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HubDownloadManagerDownloadStateTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let bytes = Data((32..<48).map(UInt8.init))
        RangeStubURLProtocol.reset(bytes: bytes, mode: .ignoreRangeRequests)
        let session = URLSession(configuration: RangeStubURLProtocol.sessionConfiguration())
        defer { session.invalidateAndCancel() }

        let manager = HubDownloadManager(
            storage: ModelStorageConfig(baseDirectory: tmpDir),
            repoMetadataProvider: StubHFRepoMetadataProvider(
                meta: HFRepoMeta(
                    commitHash: "abc123",
                    files: [
                        HFFileMeta(
                            relativePath: "model.safetensors",
                            sha256: "large-sha",
                            size: Int64(bytes.count)
                        )
                    ]
                )
            ),
            session: session,
            downloadConfiguration: HubDownloadConfiguration(
                chunkedDownloadThreshold: 8,
                chunkSize: 4,
                maxConcurrentChunksPerFile: 2
            )
        )

        var progressEvents: [DownloadProgress] = []
        for try await event in manager.download(.smolLM135M) {
            progressEvents.append(event)
        }

        let savedBlob = tmpDir
            .appendingPathComponent(Model.smolLM135M.hubCacheDirName)
            .appendingPathComponent("blobs")
            .appendingPathComponent("large-sha")
        #expect(try Data(contentsOf: savedBlob) == bytes)
        #expect(!RangeStubURLProtocol.rangeHeaders.isEmpty)
        #expect(RangeStubURLProtocol.fullRequestCount > 0)
        #expect(progressEvents.last?.bytesDownloaded == Int64(bytes.count))
        #expect(progressEvents.last?.percent == 100)
    }
}

private final class RangeStubURLProtocol: URLProtocol {
    enum Mode {
        case rangeResponses
        case ignoreRangeRequests
    }

    private static let lock = NSLock()
    private static var responseBytes = Data()
    private static var responseMode = Mode.rangeResponses
    private static var storedRangeHeaders: [String] = []
    private static var storedFullRequestCount = 0

    static var rangeHeaders: [String] {
        lock.withLock { storedRangeHeaders }
    }

    static var fullRequestCount: Int {
        lock.withLock { storedFullRequestCount }
    }

    static func reset(bytes: Data, mode: Mode) {
        lock.withLock {
            responseBytes = bytes
            responseMode = mode
            storedRangeHeaders = []
            storedFullRequestCount = 0
        }
    }

    static func sessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RangeStubURLProtocol.self]
        return configuration
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "huggingface.co"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let rangeHeader = request.value(forHTTPHeaderField: "Range")
        let (bytes, mode) = Self.lock.withLock {
            (Self.responseBytes, Self.responseMode)
        }

        if let rangeHeader {
            Self.lock.withLock {
                Self.storedRangeHeaders.append(rangeHeader)
            }

            if mode == .rangeResponses,
               let range = Self.parseRange(rangeHeader, byteCount: bytes.count) {
                respond(statusCode: 206, data: bytes.subdata(in: range))
                return
            }
        }

        Self.lock.withLock {
            Self.storedFullRequestCount += 1
        }
        respond(statusCode: 200, data: bytes)
    }

    override func stopLoading() {}

    private func respond(statusCode: Int, data: Data) {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Length": "\(data.count)"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func parseRange(_ header: String, byteCount: Int) -> Range<Int>? {
        guard header.hasPrefix("bytes=") else { return nil }
        let parts = header.dropFirst("bytes=".count).split(separator: "-", maxSplits: 1)
        guard parts.count == 2,
              let start = Int(parts[0]),
              let end = Int(parts[1]),
              start >= 0,
              end >= start,
              end < byteCount else { return nil }
        return start..<(end + 1)
    }
}

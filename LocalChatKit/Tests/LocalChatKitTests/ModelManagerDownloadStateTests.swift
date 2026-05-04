import Foundation
import Testing
@testable import LocalChatKit

private final class AlwaysDownloadedDownloader: HubDownloaderProtocol, @unchecked Sendable {
    private(set) var isDownloadedCallCount = 0

    func isDownloaded(_ model: Model, check: ModelDownloadCheckMode) async -> Bool {
        isDownloadedCallCount += 1
        return true
    }

    func download(_ model: Model) -> AsyncThrowingStream<DownloadProgress, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

struct ModelManagerDownloadStateTests {

    @Test func isDownloadedFallsBackToDownloaderWhenManifestRegistryMisses() async {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelManagerDownloadStateTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let manager = ModelManager(
            storage: ModelStorageConfig(baseDirectory: tmpDir),
            downloader: AlwaysDownloadedDownloader(),
            modelFileRegistry: ModelFileManifestRegistry(store: InMemoryModelFileManifestStore())
        )

        let isDownloaded = await manager.isDownloaded(.smolLM135M)

        #expect(isDownloaded)
    }

    @Test func isDownloadedDoesNotCallDownloaderWhenManifestRegistryHits() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelManagerDownloadStateTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let snapshot = tmpDir
            .appendingPathComponent(Model.smolLM135M.hubCacheDirName)
            .appendingPathComponent("snapshots")
            .appendingPathComponent("abc123")
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: snapshot.appendingPathComponent("config.json"))

        let store = InMemoryModelFileManifestStore()
        try store.save(
            ModelFileManifest(
                commitHash: "abc123",
                files: [
                    ModelFileManifest.File(
                        relativePath: "config.json",
                        sha256: "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
                        size: 5
                    )
                ]
            ),
            for: .smolLM135M
        )

        let downloader = AlwaysDownloadedDownloader()
        let manager = ModelManager(
            storage: ModelStorageConfig(baseDirectory: tmpDir),
            downloader: downloader,
            modelFileRegistry: ModelFileManifestRegistry(store: store)
        )

        let isDownloaded = await manager.isDownloaded(.smolLM135M)

        #expect(isDownloaded)
        #expect(downloader.isDownloadedCallCount == 0)
    }
}

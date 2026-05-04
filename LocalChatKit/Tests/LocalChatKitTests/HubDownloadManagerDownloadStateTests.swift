import Foundation
import Testing
@testable import LocalChatKit

private struct StubHFRepoMetadataProvider: HFRepoMetadataProviding {
    let meta: HFRepoMeta

    func fetchRepoMeta(modelID: String) async throws -> HFRepoMeta {
        meta
    }
}

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
}

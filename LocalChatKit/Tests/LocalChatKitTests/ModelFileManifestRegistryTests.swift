import Foundation
import Testing
@testable import LocalChatKit

final class InMemoryModelFileManifestStore: ModelFileManifestStore, @unchecked Sendable {
    private var manifests: [Model: ModelFileManifest] = [:]

    func manifest(for model: Model) -> ModelFileManifest? {
        manifests[model]
    }

    func save(_ manifest: ModelFileManifest, for model: Model) throws {
        manifests[model] = manifest
    }

    func removeManifest(for model: Model) throws {
        manifests[model] = nil
    }
}

struct ModelFileManifestRegistryTests {

    @Test func userDefaultsStorePersistsManifestByModel() throws {
        let suiteName = "ModelFileManifestRegistryTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsModelFileManifestStore(defaults: defaults)
        let manifest = ModelFileManifest(
            commitHash: "abc123",
            files: [ModelFileManifest.File(relativePath: "config.json", sha256: "hash")]
        )

        try store.save(manifest, for: .smolLM135M)

        #expect(store.manifest(for: .smolLM135M) == manifest)
        #expect(store.manifest(for: .gemma4_e2b) == nil)
    }

    @Test func returnsTrueWhenStoredManifestFilesExistAndHashesMatch() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelFileManifestRegistryTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let snapshot = tmpDir
            .appendingPathComponent(Model.smolLM135M.hubCacheDirName)
            .appendingPathComponent("snapshots")
            .appendingPathComponent("abc123")
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)

        let configFile = snapshot.appendingPathComponent("config.json")
        try Data("hello".utf8).write(to: configFile)

        let store = InMemoryModelFileManifestStore()
        let registry = ModelFileManifestRegistry(store: store)
        try store.save(
            ModelFileManifest(
                commitHash: "abc123",
                files: [
                    ModelFileManifest.File(
                        relativePath: "config.json",
                        sha256: "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
                    )
                ]
            ),
            for: .smolLM135M
        )

        #expect(registry.isDownloaded(.smolLM135M, storage: ModelStorageConfig(baseDirectory: tmpDir), check: .thorough))
    }

    @Test func returnsFalseWhenStoredManifestHashDoesNotMatchFileContents() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelFileManifestRegistryTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let snapshot = tmpDir
            .appendingPathComponent(Model.smolLM135M.hubCacheDirName)
            .appendingPathComponent("snapshots")
            .appendingPathComponent("abc123")
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)

        let configFile = snapshot.appendingPathComponent("config.json")
        try Data("changed".utf8).write(to: configFile)

        let store = InMemoryModelFileManifestStore()
        let registry = ModelFileManifestRegistry(store: store)
        try store.save(
            ModelFileManifest(
                commitHash: "abc123",
                files: [
                    ModelFileManifest.File(
                        relativePath: "config.json",
                        sha256: "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
                    )
                ]
            ),
            for: .smolLM135M
        )

        #expect(!registry.isDownloaded(.smolLM135M, storage: ModelStorageConfig(baseDirectory: tmpDir), check: .thorough))
    }

    @Test func fastCheckReturnsTrueWhenStoredManifestFileSizesMatch() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelFileManifestRegistryTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let snapshot = tmpDir
            .appendingPathComponent(Model.smolLM135M.hubCacheDirName)
            .appendingPathComponent("snapshots")
            .appendingPathComponent("abc123")
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)

        let configFile = snapshot.appendingPathComponent("config.json")
        try Data("abcde".utf8).write(to: configFile)

        let store = InMemoryModelFileManifestStore()
        let registry = ModelFileManifestRegistry(store: store)
        try store.save(
            ModelFileManifest(
                commitHash: "abc123",
                files: [
                    ModelFileManifest.File(
                        relativePath: "config.json",
                        sha256: "not-checked",
                        size: 5
                    )
                ]
            ),
            for: .smolLM135M
        )

        #expect(registry.isDownloaded(.smolLM135M, storage: ModelStorageConfig(baseDirectory: tmpDir), check: .fast))
    }
}

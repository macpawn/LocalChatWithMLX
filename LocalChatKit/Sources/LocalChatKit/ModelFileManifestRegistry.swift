import CryptoKit
import Foundation

public struct ModelFileManifest: Codable, Equatable, Sendable {
    public struct File: Codable, Equatable, Sendable {
        public let relativePath: String
        public let sha256: String
        public let size: Int64?

        public init(relativePath: String, sha256: String, size: Int64? = nil) {
            self.relativePath = relativePath
            self.sha256 = sha256
            self.size = size
        }
    }

    public let commitHash: String
    public let files: [File]

    public init(commitHash: String, files: [File]) {
        self.commitHash = commitHash
        self.files = files
    }
}

public protocol ModelFileManifestStore: Sendable {
    func manifest(for model: Model) -> ModelFileManifest?
    func save(_ manifest: ModelFileManifest, for model: Model) throws
    func removeManifest(for model: Model) throws
}

// @unchecked: UserDefaults is documented as thread-safe; no mutable state beyond it.
public final class UserDefaultsModelFileManifestStore: ModelFileManifestStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix: String

    public init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "LocalChatKit.modelFileManifest"
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    public func manifest(for model: Model) -> ModelFileManifest? {
        guard let data = defaults.data(forKey: key(for: model)) else { return nil }
        return try? JSONDecoder().decode(ModelFileManifest.self, from: data)
    }

    public func save(_ manifest: ModelFileManifest, for model: Model) throws {
        let data = try JSONEncoder().encode(manifest)
        defaults.set(data, forKey: key(for: model))
    }

    public func removeManifest(for model: Model) throws {
        defaults.removeObject(forKey: key(for: model))
    }

    private func key(for model: Model) -> String {
        "\(keyPrefix).\(model.rawValue)"
    }
}

// @unchecked: store conforms to Sendable; FileManager.default is thread-safe; no mutable instance state.
public final class ModelFileManifestRegistry: @unchecked Sendable {
    private let store: any ModelFileManifestStore
    private let fileManager: FileManager

    public init(
        store: any ModelFileManifestStore = UserDefaultsModelFileManifestStore(),
        fileManager: FileManager = .default
    ) {
        self.store = store
        self.fileManager = fileManager
    }

    public func isDownloaded(
        _ model: Model,
        storage: ModelStorageConfig,
        check: ModelDownloadCheckMode = .fast
    ) -> Bool {
        guard let manifest = store.manifest(for: model),
              !manifest.files.isEmpty else { return false }

        let snapshotDirectory = snapshotDirectory(
            for: model,
            storage: storage,
            commitHash: manifest.commitHash
        )

        return manifest.files.allSatisfy { file in
            let fileURL = snapshotDirectory.appendingPathComponent(file.relativePath)
            guard fileManager.fileExists(atPath: fileURL.path) else { return false }

            switch check {
            case .fast:
                guard let expectedSize = file.size,
                      expectedSize > 0,
                      let actualSize = try? fileURL.localFileSize() else { return false }
                return actualSize == expectedSize
            case .thorough:
                guard let actualHash = try? ModelFileHasher.sha256(for: fileURL) else { return false }
                return actualHash == file.sha256
            }
        }
    }

    public func saveManifest(
        for model: Model,
        storage: ModelStorageConfig,
        commitHash: String,
        relativePaths: [String]
    ) throws {
        let snapshotDirectory = snapshotDirectory(
            for: model,
            storage: storage,
            commitHash: commitHash
        )
        let files = try relativePaths.map { relativePath in
            let fileURL = snapshotDirectory.appendingPathComponent(relativePath)
            return ModelFileManifest.File(
                relativePath: relativePath,
                sha256: try ModelFileHasher.sha256(for: fileURL),
                size: try fileURL.localFileSize()
            )
        }
        try store.save(ModelFileManifest(commitHash: commitHash, files: files), for: model)
    }

    public func removeManifest(for model: Model) throws {
        try store.removeManifest(for: model)
    }

    private func snapshotDirectory(
        for model: Model,
        storage: ModelStorageConfig,
        commitHash: String
    ) -> URL {
        storage.baseDirectory
            .appendingPathComponent(model.hubCacheDirName)
            .appendingPathComponent("snapshots")
            .appendingPathComponent(commitHash)
    }

}

extension URL {
    func localFileSize() throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard let size = attributes[.size] as? NSNumber else { return 0 }
        return size.int64Value
    }
}

enum ModelFileHasher {
    static func sha256(for url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

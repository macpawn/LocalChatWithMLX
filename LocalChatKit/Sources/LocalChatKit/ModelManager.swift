import Foundation
import HuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

public actor ModelManager: ModelManagerProtocol {
    private let storage: ModelStorageConfig
    private let downloader: any HubDownloaderProtocol
    private let mlxDownloader: any MLXLMCommon.Downloader
    private let tokenizerLoader: any MLXLMCommon.TokenizerLoader
    private let modelFileRegistry: ModelFileManifestRegistry

    public init(
        storage: ModelStorageConfig = .default,
        downloader: (any HubDownloaderProtocol)? = nil,
        mlxDownloader: (any MLXLMCommon.Downloader)? = nil,
        tokenizerLoader: any MLXLMCommon.TokenizerLoader = TransformersTokenizerLoader(),
        modelFileRegistry: ModelFileManifestRegistry = ModelFileManifestRegistry()
    ) {
        self.storage = storage
        self.modelFileRegistry = modelFileRegistry
        self.downloader = downloader ?? HubDownloadManager(
            storage: storage,
            modelFileRegistry: modelFileRegistry
        )
        self.mlxDownloader = mlxDownloader ?? HubDownloader(cacheDirectory: storage.baseDirectory)
        self.tokenizerLoader = tokenizerLoader
    }

    public func isDownloaded(_ model: Model, check: ModelDownloadCheckMode = .fast) async -> Bool {
        if modelFileRegistry.isDownloaded(model, storage: storage, check: check) {
            return true
        }
        return await downloader.isDownloaded(model, check: check)
    }

    public func delete(_ model: Model) throws {
        let repoURL = storage.baseDirectory.appendingPathComponent(model.hubCacheDirName)
        if FileManager.default.fileExists(atPath: repoURL.path) {
            try FileManager.default.removeItem(at: repoURL)
        }
        try modelFileRegistry.removeManifest(for: model)
    }

    public func download(_ model: Model) -> AsyncThrowingStream<DownloadProgress, Error> {
        downloader.download(model)
    }

    /// Streams load progress. Final event is `.ready(LoadedModel)`.
    /// Throws `LocalChatError.modelNotDownloaded` if files are not on disk.
    public func load(_ model: Model) -> AsyncThrowingStream<LoadProgress, Error> {
        return AsyncThrowingStream { continuation in
            let task = Task {
                let isReady = await self.isDownloaded(model)
                guard isReady else {
                    continuation.finish(throwing: LocalChatError.modelNotDownloaded(model))
                    return
                }
                do {
                    let container = try await LLMModelFactory.shared.loadContainer(
                        from: mlxDownloader,
                        using: tokenizerLoader,
                        configuration: model.llmConfiguration,
                        useLatest: false,
                        progressHandler: { progress in
                            let fraction = max(0.0, min(1.0, progress.fractionCompleted))
                            continuation.yield(.loading(fraction: fraction))
                        }
                    )
                    let loadedModel = try await LoadedModel(model: model, container: container)
                    continuation.yield(.ready(loadedModel))
                    continuation.finish()
                } catch let error as LocalChatError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: LocalChatError.loadFailed(underlying: error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

public struct HubDownloader: MLXLMCommon.Downloader {
    private let upstream: HuggingFace.HubClient

    public init(upstream: HuggingFace.HubClient = .init()) {
        self.upstream = upstream
    }

    public init(cacheDirectory: URL) {
        self.upstream = HuggingFace.HubClient(
            cache: HuggingFace.HubCache(cacheDirectory: cacheDirectory)
        )
    }

    public func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        guard let repoID = HuggingFace.Repo.ID(rawValue: id) else {
            throw LocalChatError.loadFailed(
                underlying: NSError(
                    domain: "LocalChatKit",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid Hugging Face model id: \(id)"]
                )
            )
        }

        return try await upstream.downloadSnapshot(
            of: repoID,
            revision: revision ?? "main",
            matching: patterns,
            localFilesOnly: !useLatest
        ) { @MainActor progress in
            progressHandler(progress)
        }
    }
}

public struct TransformersTokenizerLoader: MLXLMCommon.TokenizerLoader {
    public init() {}

    public func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let tokenizer = try await Tokenizers.AutoTokenizer.from(modelFolder: directory)
        return HuggingFaceTokenizerBridge(tokenizer)
    }
}

public struct HuggingFaceTokenizerBridge: MLXLMCommon.Tokenizer {
    private let upstream: any Tokenizers.Tokenizer

    public init(_ upstream: any Tokenizers.Tokenizer) {
        self.upstream = upstream
    }

    public func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    public func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    public func convertTokenToId(_ token: String) -> Int? {
        upstream.convertTokenToId(token)
    }

    public func convertIdToToken(_ id: Int) -> String? {
        upstream.convertIdToToken(id)
    }

    public var bosToken: String? {
        upstream.bosToken
    }

    public var eosToken: String? {
        upstream.eosToken
    }

    public var unknownToken: String? {
        upstream.unknownToken
    }

    public func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(
                messages: messages,
                tools: tools,
                additionalContext: additionalContext
            )
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}

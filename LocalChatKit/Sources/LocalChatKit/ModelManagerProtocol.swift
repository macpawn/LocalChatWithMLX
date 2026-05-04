import Foundation

/// Abstracts `ModelManager` for testing and alternative implementations.
public protocol ModelManagerProtocol: Actor {
    /// Returns true if the model's files are present on disk.
    func isDownloaded(_ model: Model, check: ModelDownloadCheckMode) async -> Bool

    /// Removes the model's cache directory from disk.
    func delete(_ model: Model) throws

    /// Streams download progress. Completes when all model files are on disk.
    func download(_ model: Model) -> AsyncThrowingStream<DownloadProgress, Error>

    /// Streams load progress. Final event is `.ready(LoadedModel)`.
    func load(_ model: Model) -> AsyncThrowingStream<LoadProgress, Error>
}

public extension ModelManagerProtocol {
    /// Returns true if the model's files are present on disk.
    func isDownloaded(_ model: Model) async -> Bool {
        await isDownloaded(model, check: .fast)
    }

    /// Convenience: loads a model and returns it, ignoring intermediate progress.
    func loadModel(_ model: Model) async throws -> LoadedModel {
        for try await progress in load(model) {
            if case .ready(let loaded) = progress { return loaded }
        }
        throw LocalChatError.loadFailed(
            underlying: NSError(
                domain: "LocalChatKit",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Load stream finished without emitting .ready"]
            )
        )
    }
}

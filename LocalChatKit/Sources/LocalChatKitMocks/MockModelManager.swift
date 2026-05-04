import Foundation
import LocalChatKit

public actor MockModelManager: ModelManagerProtocol {
    public var downloadedModels: Set<Model> = []
    public var stubbedDownloadEvents: [DownloadProgress] = []
    public var stubbedDownloadError: Error? = nil
    public var stubbedLoadError: Error? = nil
    public var loadCallCount: Int = 0

    public init() {}

    /// Pre-populate which models appear as downloaded.
    public func seed(downloaded: Set<Model>) {
        downloadedModels = downloaded
    }

    /// Stub download progress events (clears any previous error stub).
    public func stub(downloadEvents: [DownloadProgress]) {
        stubbedDownloadEvents = downloadEvents
        stubbedDownloadError = nil
    }

    /// Stub a download error (clears any previous events stub).
    public func stub(downloadError: Error) {
        stubbedDownloadError = downloadError
        stubbedDownloadEvents = []
    }

    /// Stub a load error.
    public func stub(loadError: Error) {
        stubbedLoadError = loadError
    }

    // MARK: - ModelManagerProtocol

    public func isDownloaded(_ model: Model, check: ModelDownloadCheckMode = .fast) async -> Bool {
        downloadedModels.contains(model)
    }

    public func delete(_ model: Model) throws {
        downloadedModels.remove(model)
    }

    /// Yields stubbed download progress events.
    /// Note: does NOT mutate `downloadedModels` — call `seed(downloaded:)` after download
    /// if you need `isDownloaded` to reflect the result.
    public func download(_ model: Model) -> AsyncThrowingStream<DownloadProgress, Error> {
        let events = stubbedDownloadEvents
        let error = stubbedDownloadError
        return AsyncThrowingStream { continuation in
            Task {
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                for event in events {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }

    public func load(_ model: Model) -> AsyncThrowingStream<LoadProgress, Error> {
        loadCallCount += 1
        let error = stubbedLoadError
        return AsyncThrowingStream { continuation in
            Task {
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                // LoadedModel cannot be instantiated without MLX's ModelContainer.
                // Emit a synthetic loading(1.0) to indicate the stream ran to completion.
                continuation.yield(.loading(fraction: 1.0))
                continuation.finish()
            }
        }
    }
}

import Foundation

public enum ModelDownloadCheckMode: Sendable {
    case fast
    case thorough
}

/// Abstracts the download portion of model management.
/// Conform to this to provide a custom download implementation to `ModelManager`.
public protocol HubDownloaderProtocol: Sendable {
    func isDownloaded(_ model: Model, check: ModelDownloadCheckMode) async -> Bool
    func download(_ model: Model) -> AsyncThrowingStream<DownloadProgress, Error>
}

public extension HubDownloaderProtocol {
    func isDownloaded(_ model: Model) async -> Bool {
        await isDownloaded(model, check: .fast)
    }
}

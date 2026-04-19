import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLMCommon
import Tokenizers

private let modelFilePatterns = ["*.safetensors", "*.json", "*.jinja"]

public actor ModelManager {
    private let storage: ModelStorageConfig

    public init(storage: ModelStorageConfig = .default) {
        self.storage = storage
    }

    /// Returns true if the model's files are present on disk.
    /// Checks for at least one `.safetensors` file inside the HubCache snapshot directory.
    public func isDownloaded(_ model: Model) -> Bool {
        let snapshotsURL = storage.baseDirectory
            .appendingPathComponent(model.hubCacheDirName)
            .appendingPathComponent("snapshots")

        guard let snapshots = try? FileManager.default.contentsOfDirectory(atPath: snapshotsURL.path),
              !snapshots.isEmpty else { return false }

        return snapshots.contains { snapshot in
            let files = (try? FileManager.default.contentsOfDirectory(
                atPath: snapshotsURL.appendingPathComponent(snapshot).path
            )) ?? []
            return files.contains { $0.hasSuffix(".safetensors") }
        }
    }

    /// Removes the model's cache directory from disk.
    public func delete(_ model: Model) throws {
        let repoURL = storage.baseDirectory.appendingPathComponent(model.hubCacheDirName)
        guard FileManager.default.fileExists(atPath: repoURL.path) else { return }
        try FileManager.default.removeItem(at: repoURL)
    }

    /// Streams download progress. Completes when all model files are on disk.
    public func download(_ model: Model) -> AsyncThrowingStream<DownloadProgress, Error> {
        let storage = self.storage
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let client = HubClient(cache: HubCache(cacheDirectory: storage.baseDirectory))
                    let downloader = #hubDownloader(client)

                    final class ProgressState: @unchecked Sendable {
                        var lastDate: Date = Date()
                        var lastCompleted: Int64 = 0
                    }
                    let state = ProgressState()

                    _ = try await downloader.download(
                        id: model.huggingFaceID,
                        revision: nil,
                        matching: modelFilePatterns,
                        useLatest: false,
                        progressHandler: { progress in
                            let now = Date()
                            let completed = progress.completedUnitCount
                            let total = progress.totalUnitCount
                            let percent = total > 0 ? Int(Double(completed) / Double(total) * 100) : 0

                            let elapsed = now.timeIntervalSince(state.lastDate)
                            let bytesPerSecond: Double
                            if elapsed >= 0.1 {
                                bytesPerSecond = Double(completed - state.lastCompleted) / elapsed
                                state.lastDate = now
                                state.lastCompleted = completed
                            } else {
                                bytesPerSecond = 0
                            }

                            continuation.yield(DownloadProgress(
                                percent: min(percent, 100),
                                bytesDownloaded: completed,
                                totalBytes: total,
                                bytesPerSecond: max(0, bytesPerSecond)
                            ))
                        }
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: LocalChatError.downloadFailed(underlying: error))
                }
            }
        }
    }

    /// Loads the model into memory for inference.
    /// Throws `LocalChatError.modelNotDownloaded` if files are not on disk.
    public func load(_ model: Model) async throws -> LoadedModel {
        guard isDownloaded(model) else {
            throw LocalChatError.modelNotDownloaded(model)
        }
        do {
            let client = HubClient(cache: HubCache(cacheDirectory: storage.baseDirectory))
            let downloader = #hubDownloader(client)
            let container = try await loadModelContainer(
                from: downloader,
                using: #huggingFaceTokenizerLoader(),
                configuration: model.llmConfiguration,
                useLatest: false,
                progressHandler: { _ in }
            )
            return LoadedModel(model: model, container: container)
        } catch let error as LocalChatError {
            throw error
        } catch {
            throw LocalChatError.loadFailed(underlying: error)
        }
    }
}

import Foundation
import Testing
@testable import LocalChatKit

/// Real-network tests. Run manually or in a CI environment with internet access.
/// These tests do NOT download entire models — they verify that the download
/// stream starts and emits valid progress events, then cancel early.
@Suite("Model Download – API", .timeLimit(.minutes(3)))
struct ModelDownloadTests {

    @Test("Download stream emits progress events with valid values")
    func downloadEmitsProgress() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalChatKitAPITests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let manager = ModelManager(storage: ModelStorageConfig(baseDirectory: tmpDir))

        var firstRealProgress: DownloadProgress?

        for try await event in await manager.download(.smolLM135M) {
//            if event.bytesDownloaded > 0 {
//                firstRealProgress = event
//                break
//            }
        }

        let progress = try #require(firstRealProgress, "Expected at least one event with bytesDownloaded > 0")
        #expect(progress.bytesDownloaded > 0)
        #expect(progress.totalBytes > 0)
        #expect(progress.bytesDownloaded <= progress.totalBytes)
        #expect(progress.percent >= 0 && progress.percent <= 100)
    }
}

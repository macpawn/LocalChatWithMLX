import Testing
import Foundation
@testable import LocalChatKit
import LocalChatKitMocks

struct MockModelManagerTests {

    @Test func isDownloadedReturnsFalseByDefault() async {
        let manager = MockModelManager()
        let result = await manager.isDownloaded(.llama3_2_1B)
        #expect(result == false)
    }

    @Test func isDownloadedReturnsTrueWhenSeeded() async {
        let manager = MockModelManager()
        await manager.seed(downloaded: [.llama3_2_1B])
        let result = await manager.isDownloaded(.llama3_2_1B)
        #expect(result == true)
    }

    @Test func deleteRemovesFromDownloadedSet() async throws {
        let manager = MockModelManager()
        await manager.seed(downloaded: [.llama3_2_1B])
        try await manager.delete(.llama3_2_1B)
        let result = await manager.isDownloaded(.llama3_2_1B)
        #expect(result == false)
    }

    @Test func downloadYieldsProgressEvents() async throws {
        let manager = MockModelManager()
        let events = [
            DownloadProgress(percent: 50, bytesDownloaded: 512, totalBytes: 1024, bytesPerSecond: 100),
            DownloadProgress(percent: 100, bytesDownloaded: 1024, totalBytes: 1024, bytesPerSecond: 200),
        ]
        await manager.stub(downloadEvents: events)

        var received: [DownloadProgress] = []
        for try await p in await manager.download(.llama3_2_1B) {
            received.append(p)
        }

        #expect(received == events)
    }

    @Test func downloadThrowsWhenErrorStubbed() async throws {
        let manager = MockModelManager()
        await manager.stub(downloadError: LocalChatError.downloadFailed(
            underlying: NSError(domain: "test", code: 1)
        ))

        await #expect(throws: (any Error).self) {
            for try await _ in await manager.download(.llama3_2_1B) {}
        }
    }

    @Test func loadTracksCallCount() async {
        let manager = MockModelManager()
        _ = await manager.load(.llama3_2_1B)
        _ = await manager.load(.llama3_2_1B)
        let count = await manager.loadCallCount
        #expect(count == 2)
    }

    @Test func loadThrowsWhenErrorStubbed() async throws {
        let manager = MockModelManager()
        await manager.stub(loadError: LocalChatError.loadFailed(
            underlying: NSError(domain: "test", code: 2)
        ))

        await #expect(throws: (any Error).self) {
            for try await _ in await manager.load(.llama3_2_1B) {}
        }
    }

    @Test func loadEmitsLoadingProgressWithoutReadyEvent() async throws {
        // MockModelManager cannot emit .ready(LoadedModel) because ModelContainer
        // has no public initializer in MLX. Verified: stream emits .loading(1.0) then finishes.
        let manager = MockModelManager()
        var events: [LoadProgress] = []
        for try await p in await manager.load(.llama3_2_1B) {
            events.append(p)
        }
        #expect(events.count == 1)
        if case .loading(let fraction) = events[0] {
            #expect(fraction == 1.0)
        } else {
            Issue.record("Expected .loading event")
        }
    }

    @Test func conformsToProtocol() {
        let _: any ModelManagerProtocol = MockModelManager()
    }
}

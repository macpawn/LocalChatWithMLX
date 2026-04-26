import Testing
import Foundation
@testable import LocalChatKit
import LocalChatKitMocks

struct MockChatSessionTests {

    private func makeStats() -> GenerationStats {
        GenerationStats(
            timeToFirstToken: 0.1,
            tokensPerSecond: 50,
            promptTokenCount: 5,
            generatedTokenCount: 3,
            totalDuration: 0.2
        )
    }

    @Test func sendAccumulatesTokens() async throws {
        let session = MockChatSession()
        let stats = makeStats()
        await session.stub(events: [.token("Hello"), .token(" world"), .completed(stats)])

        let response = try await session.send("Hi", options: .default)

        #expect(response.text == "Hello world")
        #expect(response.stats == stats)
    }

    @Test func sendTracksCallCount() async throws {
        let session = MockChatSession()
        let stats = makeStats()
        await session.stub(events: [.token("ok"), .completed(stats)])

        _ = try await session.send("msg1", options: .default)
        _ = try await session.send("msg2", options: .default)

        let count = await session.sendCallCount
        #expect(count == 2)
    }

    @Test func sendTracksLastMessage() async throws {
        let session = MockChatSession()
        let stats = makeStats()
        await session.stub(events: [.token("ok"), .completed(stats)])

        _ = try await session.send("hello there", options: .default)

        let last = await session.lastMessage
        #expect(last == "hello there")
    }

    @Test func sendThrowsWhenErrorStubbed() async throws {
        let session = MockChatSession()
        await session.stub(error: LocalChatError.generationFailed(
            underlying: NSError(domain: "test", code: 99)
        ))

        await #expect(throws: (any Error).self) {
            _ = try await session.send("hi", options: .default)
        }
    }

    @Test func clearHistoryResetsHistory() async throws {
        let session = MockChatSession()
        let stats = makeStats()
        await session.stub(events: [.token("reply"), .completed(stats)])
        _ = try await session.send("msg", options: .default)

        let historyBeforeClear = await session.history
        #expect(historyBeforeClear.count == 2)  // user + assistant

        await session.clearHistory()

        let history = await session.history
        #expect(history.isEmpty)
    }

    @Test func sendStreamingYieldsEvents() async throws {
        let session = MockChatSession()
        let stats = makeStats()
        await session.stub(events: [.token("A"), .token("B"), .completed(stats)])

        var tokens: [String] = []
        var finalStats: GenerationStats? = nil
        for try await event in await session.sendStreaming("q", options: .default) {
            switch event {
            case .token(let t): tokens.append(t)
            case .completed(let s): finalStats = s
            }
        }

        #expect(tokens == ["A", "B"])
        #expect(finalStats == stats)
    }

    @Test func conformsToProtocol() {
        // Compile-time check: MockChatSession must satisfy ChatSessionProtocol.
        let _: any ChatSessionProtocol = MockChatSession()
    }
}

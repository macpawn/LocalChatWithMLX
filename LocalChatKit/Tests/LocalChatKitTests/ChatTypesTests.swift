import Testing
import Foundation
@testable import LocalChatKit

struct ChatTypesTests {

    @Test func chatMessageInit() {
        let msg = ChatMessage(role: .user, content: "Hello")
        #expect(msg.role == .user)
        #expect(msg.content == "Hello")
    }

    @Test func chatMessageRolesExist() {
        _ = ChatMessage(role: .user, content: "")
        _ = ChatMessage(role: .assistant, content: "")
        _ = ChatMessage(role: .system, content: "")
    }

    @Test func generationStatsHoldsValues() {
        let stats = GenerationStats(
            timeToFirstToken: 0.5,
            tokensPerSecond: 42.0,
            promptTokenCount: 10,
            generatedTokenCount: 20,
            totalDuration: 1.5
        )
        #expect(stats.timeToFirstToken == 0.5)
        #expect(stats.tokensPerSecond == 42.0)
        #expect(stats.promptTokenCount == 10)
        #expect(stats.generatedTokenCount == 20)
        #expect(stats.totalDuration == 1.5)
    }

    @Test func downloadProgressHoldsValues() {
        let p = DownloadProgress(percent: 50, bytesDownloaded: 500, totalBytes: 1000, bytesPerSecond: 100)
        #expect(p.percent == 50)
        #expect(p.bytesDownloaded == 500)
        #expect(p.totalBytes == 1000)
        #expect(p.bytesPerSecond == 100)
    }

    @Test func chatResponseHoldsValues() {
        let stats = GenerationStats(timeToFirstToken: 0, tokensPerSecond: 1, promptTokenCount: 1, generatedTokenCount: 1, totalDuration: 1)
        let response = ChatResponse(text: "hi", stats: stats)
        #expect(response.text == "hi")
    }

    @Test func localChatErrorIsError() {
        let error: any Error = LocalChatError.modelNotDownloaded(.gemma4_e2b)
        #expect(error is LocalChatError)
    }
}

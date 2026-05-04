import Foundation
import Testing
@testable import LocalChatKit

private struct StubChatGenerator: ChatGenerating {
    let tokens: [String]
    var info: ChatGenerationInfo? = nil

    func generate(
        prompt: String,
        messages: [ChatMessage],
        sampling: SamplingConfig
    ) -> AsyncThrowingStream<ChatGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            for token in tokens {
                continuation.yield(.chunk(token))
            }
            if let info {
                continuation.yield(.info(info))
            }
            continuation.finish()
        }
    }
}

private final class CapturingChatGenerator: ChatGenerating, @unchecked Sendable {
    private let lock = NSLock()
    private var capturedPrompt: String?
    private var capturedSampling: SamplingConfig?

    var prompt: String? {
        lock.withLock { capturedPrompt }
    }

    var sampling: SamplingConfig? {
        lock.withLock { capturedSampling }
    }

    func generate(
        prompt: String,
        messages: [ChatMessage],
        sampling: SamplingConfig
    ) -> AsyncThrowingStream<ChatGenerationEvent, Error> {
        lock.withLock {
            capturedPrompt = prompt
            capturedSampling = sampling
        }

        return AsyncThrowingStream { continuation in
            continuation.yield(.chunk("OK"))
            continuation.finish()
        }
    }
}

struct ChatSessionGeneratorTests {
    @Test func sendUsesGeneratorAndRecordsHistory() async throws {
        let loaded = LoadedModel(
            model: .gemma4_e2b,
            modelID: "test/model",
            localURL: URL(fileURLWithPath: "/tmp/test-model"),
            generator: StubChatGenerator(tokens: ["Hel", "lo"])
        )
        let session = loaded.makeChatSession(systemPrompt: "Be brief.")

        let response = try await session.send("Hello?")

        #expect(response.text == "Hello")
        #expect(response.stats.generatedTokenCount == 2)
        #expect(response.stats.promptTokenCount > 0)
        #expect(await session.history == [
            ChatMessage(role: .user, content: "Hello?"),
            ChatMessage(role: .assistant, content: "Hello"),
        ])
    }

    @Test func sendUsesGeneratorInfoForStatsWhenAvailable() async throws {
        let loaded = LoadedModel(
            model: .gemma4_e2b,
            modelID: "test/model",
            localURL: URL(fileURLWithPath: "/tmp/test-model"),
            generator: StubChatGenerator(
                tokens: ["Hi"],
                info: .init(
                    promptTokenCount: 12,
                    generatedTokenCount: 4,
                    tokensPerSecond: 42
                )
            )
        )
        let session = loaded.makeChatSession()

        let response = try await session.send("Hello?")

        #expect(response.stats.promptTokenCount == 12)
        #expect(response.stats.generatedTokenCount == 4)
        #expect(response.stats.tokensPerSecond == 42)
    }

    @Test func makeChatSessionUsesModelSpecificTemplate() async throws {
        let generator = CapturingChatGenerator()
        let loaded = LoadedModel(
            model: .llama3_2_1B,
            modelID: "test/model",
            localURL: URL(fileURLWithPath: "/tmp/test-model"),
            generator: generator
        )
        let session = loaded.makeChatSession(systemPrompt: "Be brief.")

        _ = try await session.send("Hello?")

        #expect(generator.prompt?.contains("<|start_header_id|>user<|end_header_id|>") == true)
        #expect(generator.prompt?.contains("<start_of_turn>") == false)
    }

    @Test func defaultSamplingDoesNotSetTokenLimit() {
        let sampling = SamplingConfig()

        #expect(sampling.maxTokens == nil)
    }

    @Test func sendStreamingCanOverrideSamplingPerMessage() async throws {
        let generator = CapturingChatGenerator()
        let loaded = LoadedModel(
            model: .gemma4_e2b,
            modelID: "test/model",
            localURL: URL(fileURLWithPath: "/tmp/test-model"),
            generator: generator
        )
        let session = loaded.makeChatSession()
        let sampling = SamplingConfig(temperature: 0.2, topP: 0.5, maxTokens: 64)

        for try await _ in await session.sendStreaming("Hello?", sampling: sampling) {}

        #expect(generator.sampling == sampling)
    }
}

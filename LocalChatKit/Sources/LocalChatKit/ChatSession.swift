import Foundation
import MLXLMCommon

public actor ChatSession {
    private let mlxSession: MLXLMCommon.ChatSession
    private var _history: [ChatMessage] = []

    public init(model: LoadedModel, systemPrompt: String? = nil) {
        self.mlxSession = MLXLMCommon.ChatSession(
            model.container,
            instructions: systemPrompt
        )
    }

    // MARK: - Public API

    /// Streams tokens one by one. The final event is `.completed(GenerationStats)`.
    /// If called concurrently, subsequent calls queue behind the current generation.
    public func sendStreaming(_ message: String) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream(ChatEvent.self) { continuation in
            Task {
                var fullResponse = ""
                let startTime = Date()
                var firstTokenDate: Date? = nil

                do {
                    for try await generation in self.mlxSession.streamDetails(
                        to: message, images: [], videos: []
                    ) {
                        switch generation {
                        case .chunk(let text):
                            if firstTokenDate == nil { firstTokenDate = Date() }
                            fullResponse += text
                            if case .terminated = continuation.yield(.token(text)) { return }

                        case .info(let info):
                            let stats = GenerationStats(
                                timeToFirstToken: firstTokenDate.map {
                                    $0.timeIntervalSince(startTime)
                                } ?? 0,
                                tokensPerSecond: info.tokensPerSecond,
                                promptTokenCount: info.promptTokenCount,
                                generatedTokenCount: info.generationTokenCount,
                                totalDuration: Date().timeIntervalSince(startTime)
                            )
                            continuation.yield(.completed(stats))

                        case .toolCall:
                            break
                        }
                    }
                    self._history.append(ChatMessage(role: .user, content: message))
                    self._history.append(ChatMessage(role: .assistant, content: fullResponse))
                    continuation.finish()
                } catch {
                    continuation.finish(
                        throwing: LocalChatError.generationFailed(underlying: error)
                    )
                }
            }
        }
    }

    /// Sends a message and returns the complete response.
    public func send(_ message: String) async throws -> ChatResponse {
        var fullText = ""
        var stats: GenerationStats? = nil

        for try await event in sendStreaming(message) {
            switch event {
            case .token(let text):   fullText += text
            case .completed(let s): stats = s
            }
        }

        guard let stats else {
            throw LocalChatError.generationFailed(
                underlying: NSError(
                    domain: "LocalChatKit",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Generation completed without stats"]
                )
            )
        }
        return ChatResponse(text: fullText, stats: stats)
    }

    /// Conversation history, excluding the system prompt.
    public var history: [ChatMessage] { _history }

    /// Clears conversation history and resets the underlying KV cache.
    public func clearHistory() async {
        _history = []
        await mlxSession.clear()
    }
}

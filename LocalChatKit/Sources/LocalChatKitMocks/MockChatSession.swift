import Foundation
import LocalChatKit

public actor MockChatSession: ChatSessionProtocol {
    public var stubbedEvents: [ChatEvent] = []
    public var stubbedError: Error? = nil
    public var sendCallCount: Int = 0
    public var lastMessage: String? = nil
    private var _history: [ChatMessage] = []

    public init() {}

    /// Configure stub events for the next send call.
    public func stub(events: [ChatEvent]) {
        stubbedEvents = events
        stubbedError = nil
    }

    /// Configure a stub error thrown by the next send call.
    public func stub(error: Error) {
        stubbedError = error
        stubbedEvents = []
    }

    // MARK: - ChatSessionProtocol

    public func sendStreaming(_ message: String, options: GenerationOptions) -> AsyncThrowingStream<ChatEvent, Error> {
        sendCallCount += 1
        lastMessage = message
        let events = stubbedEvents
        let error = stubbedError
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

    public func send(_ message: String, options: GenerationOptions) async throws -> ChatResponse {
        var text = ""
        var stats: GenerationStats? = nil
        for try await event in sendStreaming(message, options: options) {
            switch event {
            case .token(let t): text += t
            case .completed(let s): stats = s
            }
        }
        guard let stats else {
            throw LocalChatError.generationFailed(
                underlying: NSError(
                    domain: "LocalChatKitMocks",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No .completed event in stubbedEvents"]
                )
            )
        }
        _history.append(ChatMessage(role: .user, content: message))
        _history.append(ChatMessage(role: .assistant, content: text))
        return ChatResponse(text: text, stats: stats)
    }

    public var history: [ChatMessage] { _history }

    public func clearHistory() async {
        _history = []
    }
}

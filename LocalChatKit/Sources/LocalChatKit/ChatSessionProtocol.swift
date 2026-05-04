/// Abstracts `ChatSession` for testing and alternative implementations.
public protocol ChatSessionProtocol: Actor {
    /// Streams tokens one by one. The final event is `.completed(GenerationStats)`.
    func sendStreaming(_ message: String) -> AsyncThrowingStream<ChatEvent, Error>

    /// Sends a message and returns the complete response.
    func send(_ message: String) async throws -> ChatResponse

    /// Conversation history, excluding the system prompt.
    var history: [ChatMessage] { get }

    /// Clears conversation history.
    func clearHistory() async
}

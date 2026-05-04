import Foundation

public protocol ChatGenerating: Sendable {
    func generate(
        prompt: String,
        messages: [ChatMessage],
        sampling: SamplingConfig
    ) -> AsyncThrowingStream<ChatGenerationEvent, Error>
}

public enum ChatGenerationEvent: Sendable {
    case chunk(String)
    case info(ChatGenerationInfo)
}

public struct ChatGenerationInfo: Sendable, Equatable {
    public let promptTokenCount: Int
    public let generatedTokenCount: Int
    public let tokensPerSecond: Double

    public init(
        promptTokenCount: Int,
        generatedTokenCount: Int,
        tokensPerSecond: Double
    ) {
        self.promptTokenCount = promptTokenCount
        self.generatedTokenCount = generatedTokenCount
        self.tokensPerSecond = tokensPerSecond
    }
}

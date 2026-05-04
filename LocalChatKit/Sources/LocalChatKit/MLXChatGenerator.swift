import Foundation
import MLXLMCommon

public struct MLXChatGenerator: ChatGenerating {
    private let container: MLXLMCommon.ModelContainer

    public init(container: MLXLMCommon.ModelContainer) {
        self.container = container
    }

    public func generate(
        prompt: String,
        messages: [ChatMessage],
        sampling: SamplingConfig
    ) -> AsyncThrowingStream<ChatGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let input = MLXLMCommon.UserInput(
                        chat: messages.map(MLXLMCommon.Chat.Message.init)
                    )
                    let preparedInput = try await container.prepare(input: input)
                    let parameters = MLXLMCommon.GenerateParameters(
                        maxTokens: sampling.maxTokens,
                        temperature: sampling.temperature,
                        topP: sampling.topP
                    )
                    let stream = try await container.generate(
                        input: preparedInput,
                        parameters: parameters
                    )

                    for await generation in stream {
                        if Task.isCancelled {
                            throw CancellationError()
                        }
                        switch generation {
                        case .chunk(let text):
                            continuation.yield(.chunk(text))
                        case .info(let info):
                            continuation.yield(.info(.init(
                                promptTokenCount: info.promptTokenCount,
                                generatedTokenCount: info.generationTokenCount,
                                tokensPerSecond: info.tokensPerSecond
                            )))
                        case .toolCall:
                            break
                        }
                    }

                    _ = prompt
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private extension MLXLMCommon.Chat.Message {
    init(_ message: ChatMessage) {
        switch message.role {
        case .system:
            self = .system(message.content)
        case .user:
            self = .user(message.content)
        case .assistant:
            self = .assistant(message.content)
        }
    }
}

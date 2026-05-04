import Foundation

public actor ChatSession: ChatSessionProtocol {
    public private(set) var history: [ChatMessage]

    private let loadedModel: LoadedModel
    private let systemPrompt: String?
    private let sampling: SamplingConfig
    private let template: any ChatTemplate

    public init(
        loadedModel: LoadedModel,
        systemPrompt: String? = nil,
        sampling: SamplingConfig = .init(),
        template: any ChatTemplate
    ) {
        self.loadedModel = loadedModel
        self.systemPrompt = systemPrompt
        self.sampling = sampling
        self.template = template
        self.history = []
    }

    public init(
        loadedModel: LoadedModel,
        systemPrompt: String? = nil,
        sampling: SamplingConfig = .init()
    ) {
        self.init(
            loadedModel: loadedModel,
            systemPrompt: systemPrompt,
            sampling: sampling,
            template: loadedModel.model.chatTemplate
        )
    }

    public init(model: LoadedModel, systemPrompt: String? = nil) {
        self.loadedModel = model
        self.systemPrompt = systemPrompt
        self.sampling = .init()
        self.template = model.model.chatTemplate
        self.history = []
    }

    public func sendStreaming(_ message: String) -> AsyncThrowingStream<ChatEvent, Error> {
        sendStreaming(message, sampling: sampling)
    }

    public func sendStreaming(
        _ message: String,
        sampling: SamplingConfig
    ) -> AsyncThrowingStream<ChatEvent, Error> {
        history.append(.init(role: .user, content: message))

        let messages = renderedMessages()
        let prompt = template.render(messages: messages)
        let generator = loadedModel.generator
        let startTime = Date()

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var content = ""
                    var generatedTokenCount = 0
                    var firstTokenDate: Date? = nil

                    var generationInfo: ChatGenerationInfo?

                    for try await event in generator.generate(
                        prompt: prompt,
                        messages: messages,
                        sampling: sampling
                    ) {
                        switch event {
                        case .chunk(let token):
                            if firstTokenDate == nil {
                                firstTokenDate = Date()
                            }
                            content += token
                            generatedTokenCount += 1

                            if case .terminated = continuation.yield(.token(token)) {
                                return
                            }
                        case .info(let info):
                            generationInfo = info
                        }
                    }

                    let totalDuration = Date().timeIntervalSince(startTime)
                    let stats = GenerationStats(
                        timeToFirstToken: firstTokenDate.map {
                            $0.timeIntervalSince(startTime)
                        } ?? 0,
                        tokensPerSecond: generationInfo?.tokensPerSecond
                            ?? (totalDuration > 0
                                ? Double(generatedTokenCount) / totalDuration
                                : 0),
                        promptTokenCount: generationInfo?.promptTokenCount
                            ?? prompt.split(whereSeparator: \.isWhitespace).count,
                        generatedTokenCount: generationInfo?.generatedTokenCount
                            ?? generatedTokenCount,
                        totalDuration: totalDuration
                    )

                    self.appendAssistantMessage(content)
                    continuation.yield(.completed(stats))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(
                        throwing: LocalChatError.generationFailed(underlying: error)
                    )
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func send(_ message: String) async throws -> ChatResponse {
        var fullText = ""
        var stats: GenerationStats?

        for try await event in sendStreaming(message) {
            switch event {
            case .token(let text):
                fullText += text
            case .completed(let generationStats):
                stats = generationStats
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

    public func clearHistory() async {
        history.removeAll()
    }

    private func renderedMessages() -> [ChatMessage] {
        if let systemPrompt, !systemPrompt.isEmpty {
            [.init(role: .system, content: systemPrompt)] + history
        } else {
            history
        }
    }

    private func appendAssistantMessage(_ content: String) {
        history.append(.init(role: .assistant, content: content))
    }
}

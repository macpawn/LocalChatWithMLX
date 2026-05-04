import Foundation
import MLXLMCommon

// @unchecked: ModelContainer from MLX does not yet conform to Sendable; all properties are write-once at init.
public final class LoadedModel: @unchecked Sendable {
    public let model: Model
    public let modelID: String
    public let localURL: URL

    let generator: any ChatGenerating

    public init(
        model: Model,
        modelID: String,
        localURL: URL,
        generator: any ChatGenerating
    ) {
        self.model = model
        self.modelID = modelID
        self.localURL = localURL
        self.generator = generator
    }

    init(model: Model, container: ModelContainer) async throws {
        self.model = model
        self.modelID = model.huggingFaceID
        self.localURL = try await container.modelDirectory
        self.generator = MLXChatGenerator(container: container)
    }

    public func makeChatSession(
        systemPrompt: String? = nil,
        sampling: SamplingConfig = .init()
    ) -> ChatSession {
        ChatSession(loadedModel: self, systemPrompt: systemPrompt, sampling: sampling)
    }
}

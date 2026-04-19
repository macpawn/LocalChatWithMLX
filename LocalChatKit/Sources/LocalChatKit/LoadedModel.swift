import MLXLMCommon

public final class LoadedModel: @unchecked Sendable {
    public let model: Model
    let container: ModelContainer

    init(model: Model, container: ModelContainer) {
        self.model = model
        self.container = container
    }
}

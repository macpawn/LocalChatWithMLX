public struct GenerationOptions: Sendable {
    public var temperature: Float?
    public var maxTokens: Int?

    public static let `default` = GenerationOptions()

    public init(temperature: Float? = nil, maxTokens: Int? = nil) {
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

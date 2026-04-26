public enum LoadProgress: Sendable {
    /// Fraction of weights loaded into memory, 0.0 – 1.0.
    case loading(fraction: Double)
    /// Model is fully loaded and ready for inference.
    case ready(LoadedModel)
}

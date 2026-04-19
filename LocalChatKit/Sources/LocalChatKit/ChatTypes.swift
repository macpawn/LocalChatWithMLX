import Foundation

// MARK: - ChatMessage

public struct ChatMessage: Sendable, Equatable {
    public enum Role: Sendable, Equatable {
        case user
        case assistant
        case system
    }

    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

// MARK: - Generation Events

public enum ChatEvent: Sendable {
    case token(String)
    case completed(GenerationStats)
}

public struct GenerationStats: Sendable, Equatable {
    public let timeToFirstToken: TimeInterval
    public let tokensPerSecond: Double
    public let promptTokenCount: Int
    public let generatedTokenCount: Int
    public let totalDuration: TimeInterval

    public init(
        timeToFirstToken: TimeInterval,
        tokensPerSecond: Double,
        promptTokenCount: Int,
        generatedTokenCount: Int,
        totalDuration: TimeInterval
    ) {
        self.timeToFirstToken = timeToFirstToken
        self.tokensPerSecond = tokensPerSecond
        self.promptTokenCount = promptTokenCount
        self.generatedTokenCount = generatedTokenCount
        self.totalDuration = totalDuration
    }
}

public struct ChatResponse: Sendable, Equatable {
    public let text: String
    public let stats: GenerationStats

    public init(text: String, stats: GenerationStats) {
        self.text = text
        self.stats = stats
    }
}

// MARK: - Download Progress

public struct DownloadProgress: Sendable, Equatable {
    public let percent: Int
    public let bytesDownloaded: Int64
    public let totalBytes: Int64
    public let bytesPerSecond: Double

    public init(percent: Int, bytesDownloaded: Int64, totalBytes: Int64, bytesPerSecond: Double) {
        self.percent = percent
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.bytesPerSecond = bytesPerSecond
    }
}

// MARK: - Errors

public enum LocalChatError: Error, Sendable {
    case modelNotDownloaded(Model)
    case downloadFailed(underlying: Error)
    case loadFailed(underlying: Error)
    case generationFailed(underlying: Error)
}

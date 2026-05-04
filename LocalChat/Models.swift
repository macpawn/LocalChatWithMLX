import Foundation
import LocalChatKit

// MARK: - Model State

enum ModelStatus: Equatable {
    case unloaded
    case downloading(progress: Double, speedMBps: Double)
    case loading
    case ready
    case error(String)

    var statusDotColor: String {
        switch self {
        case .ready:       return "ready"
        case .loading, .downloading: return "loading"
        case .unloaded:    return "unloaded"
        case .error:       return "error"
        }
    }
}

// MARK: - Messages

struct MessageMetrics: Equatable {
    let ttft: Double          // seconds → displayed as ms
    let tokPerSec: Double
    let promptTokens: Int
    let responseTokens: Int
}

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: Role
    var content: String
    var metrics: MessageMetrics?
    var isStreaming: Bool

    enum Role { case user, assistant }

    static func user(_ text: String) -> ChatMessage {
        ChatMessage(id: UUID(), role: .user, content: text, metrics: nil, isStreaming: false)
    }

    static func assistantStreaming() -> ChatMessage {
        ChatMessage(id: UUID(), role: .assistant, content: "", metrics: nil, isStreaming: true)
    }
}

// MARK: - Conversations

struct Conversation: Identifiable, Equatable {
    let id: UUID
    var title: String
    var preview: String
    var createdAt: Date
    var isPinned: Bool
    var model: LocalChatKit.Model
    var generationOptions: SamplingConfig

    static func new(model: LocalChatKit.Model) -> Conversation {
        Conversation(
            id: UUID(),
            title: "New chat",
            preview: "",
            createdAt: Date(),
            isPinned: false,
            model: model,
            generationOptions: .init()
        )
    }
}

struct TokenLimitEditorState: Equatable {
    var isEnabled: Bool
    var text: String

    init(maxTokens: Int?) {
        self.isEnabled = maxTokens != nil
        self.text = maxTokens.map(String.init) ?? ""
    }

    var maxTokens: Int? {
        Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    mutating func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            text = ""
        }
    }

    mutating func setText(_ newText: String) {
        text = newText
    }
}

// MARK: - Model Metadata

extension LocalChatKit.Model {
    var quantLabel: String { "4bit" }

    var paramsLabel: String {
        switch self {
        case .smolLM135M:  return "135M"
        case .gemma4_e2b:  return "2B"
        case .gemma4_e4b:  return "4B"
        case .llama3_2_1B: return "1B"
        case .llama3_2_3B: return "3B"
        }
    }

    var accentColor: AppColor {
        switch self {
        case .smolLM135M:  return AppColor(r: 0.000, g: 0.749, b: 0.820) // teal
        case .gemma4_e2b:  return AppColor(r: 0.400, g: 0.361, b: 0.804) // purple
        case .gemma4_e4b:  return AppColor(r: 0.188, g: 0.820, b: 0.345) // green
        case .llama3_2_1B: return AppColor(r: 0.039, g: 0.518, b: 1.000) // blue
        case .llama3_2_3B: return AppColor(r: 1.000, g: 0.624, b: 0.039) // amber
        }
    }
}

struct AppColor {
    let r, g, b: Double
}

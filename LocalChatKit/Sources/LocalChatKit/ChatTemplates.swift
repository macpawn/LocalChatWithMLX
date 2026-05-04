import Foundation

public protocol ChatTemplate: Sendable {
    func render(messages: [ChatMessage]) -> String
}

public struct Gemma4ChatTemplate: ChatTemplate {
    public init() {}

    public func render(messages: [ChatMessage]) -> String {
        "<bos>"
            + messages.map { message in
                let role = switch message.role {
                case .system: "system"
                case .user: "user"
                case .assistant: "model"
                }

                return "<|turn>\(role)\n\(message.content.trimmingCharacters(in: .whitespacesAndNewlines))<turn|>"
            }
            .joined(separator: "\n")
            + "\n<|turn>model\n"
    }
}

public struct Llama32ChatTemplate: ChatTemplate {
    private let dateString: String

    public init(dateString: String = "26 Jul 2024") {
        self.dateString = dateString
    }

    public func render(messages: [ChatMessage]) -> String {
        var remaining = messages
        let systemMessage: String

        if remaining.first?.role == .system {
            systemMessage = remaining.removeFirst().content.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            systemMessage = ""
        }

        var prompt = """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>

        Cutting Knowledge Date: December 2023
        Today Date: \(dateString)

        \(systemMessage)<|eot_id|>
        """

        for message in remaining {
            let role = switch message.role {
            case .system: "system"
            case .user: "user"
            case .assistant: "assistant"
            }

            prompt += """
            <|start_header_id|>\(role)<|end_header_id|>

            \(message.content.trimmingCharacters(in: .whitespacesAndNewlines))<|eot_id|>
            """
        }

        prompt += """
        <|start_header_id|>assistant<|end_header_id|>

        """

        return prompt
    }
}

public struct SmolLMChatTemplate: ChatTemplate {
    public init() {}

    public func render(messages: [ChatMessage]) -> String {
        messages
            .map { message in
                let role = switch message.role {
                case .system: "system"
                case .user: "user"
                case .assistant: "assistant"
                }

                return "<|im_start|>\(role)\n\(message.content)<|im_end|>"
            }
            .joined(separator: "\n")
            + "\n<|im_start|>assistant\n"
    }
}

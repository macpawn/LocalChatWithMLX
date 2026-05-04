import Testing
@testable import LocalChatKit

struct ChatTemplatesTests {
    @Test func rendersSmolLMChatMLTurns() {
        let template = SmolLMChatTemplate()
        let prompt = template.render(messages: [
            ChatMessage(role: .system, content: "Be brief."),
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi"),
        ])

        #expect(prompt == """
        <|im_start|>system
        Be brief.<|im_end|>
        <|im_start|>user
        Hello<|im_end|>
        <|im_start|>assistant
        Hi<|im_end|>
        <|im_start|>assistant

        """)
    }

    @Test func rendersLlama32InstructTurns() {
        let template = Llama32ChatTemplate()
        let prompt = template.render(messages: [
            ChatMessage(role: .system, content: "Be brief."),
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi"),
        ])

        #expect(prompt == """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>

        Cutting Knowledge Date: December 2023
        Today Date: 26 Jul 2024

        Be brief.<|eot_id|><|start_header_id|>user<|end_header_id|>

        Hello<|eot_id|><|start_header_id|>assistant<|end_header_id|>

        Hi<|eot_id|><|start_header_id|>assistant<|end_header_id|>

        """)
    }

    @Test func rendersGemma4Turns() {
        let template = Gemma4ChatTemplate()
        let prompt = template.render(messages: [
            ChatMessage(role: .system, content: "Be brief."),
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi"),
        ])

        #expect(prompt == """
        <bos><|turn>system
        Be brief.<turn|>
        <|turn>user
        Hello<turn|>
        <|turn>model
        Hi<turn|>
        <|turn>model

        """)
    }
}

import Foundation
import LocalChatKit

struct ChatRunner {
    let session: ChatSession
    let modelName: String

    func run() async {
        print("\(modelName) ready. Type /help for commands.\n")
        while true {
            print("User: ", terminator: "")
            fflush(stdout)
            guard let line = readLine() else { break }
            let input = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !input.isEmpty else { continue }

            if input.hasPrefix("/") {
                // Yes, a message cannot start with a slash
                await handleCommand(input)
            } else {
                await streamResponse(for: input)
            }
        }
    }

    // MARK: - Private

    private func handleCommand(_ command: String) async {
        switch command.lowercased() {
        case "/new":
            await session.clearHistory()
            print("Starting new chat...\n")
        case "/exit":
            print("Goodbye!")
            exit(0)
        case "/help":
            print("""
            Commands:
              /new   Start a new chat (clears history)
              /exit  Quit the application
              /help  Show this help message
            """)
            print("")
        default:
            print("Unknown command '\(command)'. Type /help for available commands.\n")
        }
    }

    private func streamResponse(for message: String) async {
        print("AI: ", terminator: "")
        fflush(stdout)
        do {
            let stream = await session.sendStreaming(message)
            for try await event in stream {
                switch event {
                case .token(let text):
                    print(text, terminator: "")
                    fflush(stdout)
                case .completed(let stats):
                    print("")
                    print(TerminalOutput.formatStats(stats))
                    print("")
                }
            }
        } catch is CancellationError {
            print("\n[Generation cancelled]\n")
        } catch {
            print("\n[Error: \(error.localizedDescription)]\n")
        }
    }
}

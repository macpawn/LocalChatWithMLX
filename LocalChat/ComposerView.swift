import SwiftUI

struct ComposerView: View {
    var vm: ChatViewModel
    @State private var inputText: String = ""
    @State private var isFocused: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            composerBox
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 18)
    }

    // MARK: - Composer box

    private var composerBox: some View {
        VStack(spacing: 0) {
            // Text area
            TextEditor(text: $inputText)
                .font(.system(size: 13.5))
                .foregroundColor(LC.textPrimary)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 24, maxHeight: 180)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .focused($focused)
                .onSubmit { handleSend() }

            // Bottom action bar
            HStack(spacing: 4) {
                // Attach
                composerIconButton("paperclip")
                // Mic
                composerIconButton("mic")

                // Params hint
                HStack(spacing: 10) {
                    Text("temp 0.7")
                    Text("top_p 0.9")
                    Text("ctx 8k")
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(LC.textTertiary)
                .padding(.leading, 10)
                .padding(.horizontal, 4)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color(white: 1.0, opacity: 0.08))
                        .frame(width: 0.5)
                }

                Spacer()

                // Char count / hint
                Group {
                    if inputText.isEmpty {
                        Text("Enter · Shift+Enter for newline")
                    } else {
                        Text("\(inputText.count) chars")
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(LC.textTertiary)
                .padding(.trailing, 6)

                // Send / Stop button
                if vm.isGenerating {
                    stopButton
                } else {
                    sendButton
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .padding(.top, 2)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LC.composerBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isFocused ? LC.blue.opacity(0.5) : Color(white: 1.0, opacity: 0.10),
                    lineWidth: 0.5
                )
        )
        .shadow(
            color: .black.opacity(isFocused ? 0 : 0.2),
            radius: isFocused ? 0 : 8
        )
        .shadow(
            color: LC.blue.opacity(isFocused ? 0.12 : 0),
            radius: 12
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        .onChange(of: focused) { _, newValue in isFocused = newValue }
        .onKeyPress(.return, phases: .down) { keyPress in
            guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .ignored }
            if keyPress.modifiers.contains(.shift) { return .ignored }
            handleSend()
            return .handled
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Buttons

    private var sendButton: some View {
        Button(action: handleSend) {
            Image(systemName: "arrow.up")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(white: 1.0, opacity: 0.3) : .white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              ? Color(white: 1.0, opacity: 0.06)
                              : LC.blue)
                )
                .shadow(
                    color: LC.blue.opacity(inputText.isEmpty ? 0 : 0.3),
                    radius: 4,
                    y: 1
                )
        }
        .buttonStyle(.plain)
        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.modelStatus != .ready)
        .keyboardShortcut(.return, modifiers: .command)
    }

    private var stopButton: some View {
        Button(action: vm.stopGeneration) {
            HStack(spacing: 6) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 9))
                Text("Stop")
                    .font(.system(size: 12, weight: .semibold))
                Text("⌘⏎")
                    .font(.system(size: 10))
                    .opacity(0.7)
            }
            .foregroundColor(Color(red: 1.0, green: 0.412, blue: 0.380))
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.271, blue: 0.227, opacity: 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color(red: 1.0, green: 0.271, blue: 0.227, opacity: 0.40), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: .command)
    }

    // MARK: - Helpers

    private func composerIconButton(_ systemName: String) -> some View {
        Button {} label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(LC.textSecondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverBackground(radius: 5)
    }

    private func handleSend() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, case .ready = vm.modelStatus else { return }
        vm.sendMessage(text)
        inputText = ""
    }
}

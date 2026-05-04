import LocalChatKit
import SwiftUI

struct ComposerView: View {
    var vm: ChatViewModel
    @State private var isFocused: Bool = false
    @State private var showGenerationSettings: Bool = false
    @FocusState private var focused: Bool

    private var inputText: Binding<String> {
        Binding(
            get: { vm.selectedDraft },
            set: { vm.selectedDraft = $0 }
        )
    }

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
            TextEditor(text: inputText)
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

            // Bottom status bar
            HStack(spacing: 4) {
                HStack(spacing: 10) {
                    generationSettingsButton
                    Text("temp \(formatDecimal(vm.selectedGenerationOptions.temperature))")
                    Text("top_p \(formatDecimal(vm.selectedGenerationOptions.topP))")
                    Text(maxTokensLabel)
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(LC.textTertiary)
                .padding(.horizontal, 4)

                Spacer()

                // Char count / hint
                Group {
                    if vm.selectedDraft.isEmpty {
                        Text("Enter · Shift+Enter for newline")
                    } else {
                        Text("\(vm.selectedDraft.count) chars")
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
            guard !vm.selectedDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .ignored }
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
                .foregroundColor(vm.selectedDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(white: 1.0, opacity: 0.3) : .white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(vm.selectedDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              ? Color(white: 1.0, opacity: 0.06)
                              : LC.blue)
                )
                .shadow(
                    color: LC.blue.opacity(vm.selectedDraft.isEmpty ? 0 : 0.3),
                    radius: 4,
                    y: 1
                )
        }
        .buttonStyle(.plain)
        .disabled(vm.selectedDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.modelStatus != .ready)
        .keyboardShortcut(.return, modifiers: .command)
    }

    private var generationSettingsButton: some View {
        Button {
            showGenerationSettings.toggle()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(LC.textSecondary)
                .frame(width: 24, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(white: 1.0, opacity: 0.05))
                )
        }
        .buttonStyle(.plain)
        .help("Generation settings")
        .popover(isPresented: $showGenerationSettings, arrowEdge: .top) {
            GenerationSettingsPopover(vm: vm)
        }
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

    private func handleSend() {
        let text = vm.selectedDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, case .ready = vm.modelStatus else { return }
        vm.sendMessage(text)
        vm.selectedDraft = ""
    }

    private var maxTokensLabel: String {
        if let maxTokens = vm.selectedGenerationOptions.maxTokens {
            "max \(maxTokens)"
        } else {
            "max ∞"
        }
    }

    private func formatDecimal(_ value: Float) -> String {
        String(format: "%.2g", Double(value))
    }
}

private struct GenerationSettingsPopover: View {
    var vm: ChatViewModel
    @State private var tokenLimitEditor: TokenLimitEditorState

    init(vm: ChatViewModel) {
        self.vm = vm
        _tokenLimitEditor = State(
            initialValue: TokenLimitEditorState(maxTokens: vm.selectedGenerationOptions.maxTokens)
        )
    }

    private var options: SamplingConfig {
        get { vm.selectedGenerationOptions }
        nonmutating set { vm.selectedGenerationOptions = newValue }
    }

    private var temperature: Binding<Double> {
        Binding(
            get: { Double(options.temperature) },
            set: {
                var updated = options
                updated.temperature = Float($0)
                options = updated
            }
        )
    }

    private var topP: Binding<Double> {
        Binding(
            get: { Double(options.topP) },
            set: {
                var updated = options
                updated.topP = Float($0)
                options = updated
            }
        )
    }

    private var tokenLimitEnabled: Binding<Bool> {
        Binding(
            get: { tokenLimitEditor.isEnabled },
            set: { enabled in
                tokenLimitEditor.setEnabled(enabled)
                applyTokenLimit()
            }
        )
    }

    private var maxTokensText: Binding<String> {
        Binding(
            get: { tokenLimitEditor.text },
            set: { text in
                tokenLimitEditor.setText(text)
                applyTokenLimit()
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingHeader

            VStack(alignment: .leading, spacing: 12) {
                sliderRow(
                    title: "Temperature",
                    value: temperature,
                    range: 0...2,
                    displayValue: String(format: "%.2f", temperature.wrappedValue)
                )

                sliderRow(
                    title: "Top P",
                    value: topP,
                    range: 0.05...1,
                    displayValue: String(format: "%.2f", topP.wrappedValue)
                )

                Divider()
                    .overlay(LC.divider)

                Toggle("Limit response tokens", isOn: tokenLimitEnabled)
                    .toggleStyle(.checkbox)

                TextField("No limit", text: maxTokensText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .disabled(!tokenLimitEnabled.wrappedValue)
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(LC.toolbarBg)
    }

    private var settingHeader: some View {
        HStack {
            Text("Generation")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(LC.textPrimary)
            Spacer()
            Button("Reset") {
                let defaults = SamplingConfig()
                vm.selectedGenerationOptions = defaults
                tokenLimitEditor.reset(maxTokens: defaults.maxTokens)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(LC.blue)
        }
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        displayValue: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(displayValue)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(LC.textTertiary)
            }
            .font(.system(size: 12))
            .foregroundColor(LC.textSecondary)

            Slider(value: value, in: range)
                .tint(LC.blue)
        }
    }

    private func applyTokenLimit() {
        var updated = options
        updated.maxTokens = tokenLimitEditor.isEnabled ? tokenLimitEditor.maxTokens : nil
        options = updated
    }
}

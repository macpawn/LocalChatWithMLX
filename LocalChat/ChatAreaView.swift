import SwiftUI

struct ChatAreaView: View {
    @ObservedObject var vm: ChatViewModel
    @Namespace private var bottomID

    var body: some View {
        VStack(spacing: 0) {
            if vm.messages.isEmpty {
                EmptyStateView(vm: vm)
            } else {
                messageScrollView
            }
            ComposerView(vm: vm)
        }
    }

    // MARK: - Scroll view

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.messages) { message in
                        messageView(for: message)
                            .padding(.horizontal, 24)
                    }
                    Color.clear
                        .frame(height: 8)
                        .id(bottomID)
                }
                .padding(.top, 8)
                .padding(.horizontal, 0)
            }
            .scrollIndicators(.hidden)
            .onChange(of: vm.messages.count) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .onChange(of: vm.messages.last?.content) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private func messageView(for message: ChatMessage) -> some View {
        switch message.role {
        case .user:
            UserMessageView(message: message)
        case .assistant:
            AssistantMessageView(message: message, modelName: vm.selectedModel.displayName)
        }
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    @ObservedObject var vm: ChatViewModel

    private let suggestions = [
        ("Draft a Swift function", "to parse GGUF headers into a struct"),
        ("Explain memory-mapped I/O", "in the context of LLM inference"),
        ("Refactor this SwiftUI view", "into a reusable component"),
        ("Compare quantization methods", "Q4_K_M vs Q5_K_M vs Q8_0"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Sparkle icon
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                LC.blue.opacity(0.2),
                                Color(red: 0.749, green: 0.353, blue: 0.949).opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .lcBorder(Color(white: 1.0, opacity: 0.12), radius: 14)
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(Color(white: 1.0, opacity: 0.9))
            }
            .padding(.bottom, 20)

            Text("What can I help you with?")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(Color(white: 1.0, opacity: 0.95))
                .padding(.bottom, 6)

            Text("Running \(vm.selectedModel.displayName) · local · private")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(LC.textSecondary)
                .padding(.bottom, 32)

            // Suggestion cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(suggestions, id: \.0) { suggestion in
                    SuggestionCard(title: suggestion.0, subtitle: suggestion.1) {
                        vm.sendMessage(suggestion.0 + " " + suggestion.1)
                    }
                }
            }
            .frame(maxWidth: 560)

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SuggestionCard: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(Color(white: 1.0, opacity: 0.92))
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundColor(LC.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? Color(white: 1.0, opacity: 0.07) : Color(white: 1.0, opacity: 0.04))
            )
            .lcBorder(isHovered ? Color(white: 1.0, opacity: 0.16) : Color(white: 1.0, opacity: 0.08), radius: 10)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - User message

struct UserMessageView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.416, green: 0.353, blue: 0.804),
                                     Color(red: 0.290, green: 0.565, blue: 0.886)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("LC")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 24, height: 24)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("You")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(LC.textSecondary)
                Text(message.content)
                    .font(.system(size: 13.5))
                    .foregroundColor(LC.textPrimary)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Assistant message

struct AssistantMessageView: View {
    let message: ChatMessage
    let modelName: String
    @State private var showActions = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Model icon
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(white: 1.0, opacity: 0.08))
                    .lcBorder(Color(white: 1.0, opacity: 0.12), radius: 6)
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(Color(white: 1.0, opacity: 0.75))
            }
            .frame(width: 24, height: 24)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                // Model name + streaming indicator
                HStack(spacing: 6) {
                    Text(modelName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(LC.textSecondary)
                    if message.isStreaming {
                        Text("·")
                            .foregroundColor(LC.textTertiary)
                        HStack(spacing: 4) {
                            PulsingDot()
                            Text("generating")
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundColor(LC.green)
                        }
                    }
                }

                // Message body
                if message.content.isEmpty && message.isStreaming {
                    BlinkingCursor()
                } else {
                    Text(message.content)
                        .font(.system(size: 13.5))
                        .foregroundColor(LC.textPrimary)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                    if message.isStreaming {
                        BlinkingCursor()
                    }
                }

                // Metrics footer (after completion)
                if let metrics = message.metrics, !message.isStreaming {
                    MetricsFooterView(metrics: metrics)
                        .padding(.top, 6)
                }

                // Action buttons
                if !message.isStreaming {
                    MessageActionsView()
                        .padding(.top, 4)
                        .opacity(showActions ? 1 : 0)
                }
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .onHover { showActions = $0 }
    }
}

// MARK: - Blinking cursor

struct BlinkingCursor: View {
    @State private var visible = true

    var body: some View {
        Rectangle()
            .fill(Color(white: 1.0, opacity: 0.7))
            .frame(width: 8, height: 15)
            .opacity(visible ? 1 : 0)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: visible)
            .onAppear { visible = false }
            .padding(.top, 2)
    }
}

// MARK: - Pulsing dot

struct PulsingDot: View {
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(LC.green)
            .frame(width: 5, height: 5)
            .scaleEffect(animate ? 2.0 : 1.0)
            .opacity(animate ? 0 : 0.8)
            .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: animate)
            .onAppear { animate = true }
    }
}

// MARK: - Metrics footer

struct MetricsFooterView: View {
    let metrics: MessageMetrics

    var body: some View {
        HStack(spacing: 14) {
            metricItem(label: "TTFT", value: String(format: "%.0f", metrics.ttft * 1000), unit: "ms")
            divider
            metricItem(label: "speed", value: String(format: "%.1f", metrics.tokPerSec), unit: "tok/s")
            divider
            metricItem(label: "prompt", value: "\(metrics.promptTokens)", unit: "tok")
            divider
            metricItem(label: "response", value: "\(metrics.responseTokens)", unit: "tok")
            divider
            metricItem(label: "total", value: "\(metrics.promptTokens + metrics.responseTokens)", unit: "tok")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(white: 1.0, opacity: 0.025))
        )
        .lcBorder(Color(white: 1.0, opacity: 0.06), radius: 6)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(white: 1.0, opacity: 0.08))
            .frame(width: 1, height: 14)
    }

    private func metricItem(label: String, value: String, unit: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(LC.textTertiary)
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(white: 1.0, opacity: 0.85))
                Text(unit)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(LC.textTertiary)
            }
        }
    }
}

// MARK: - Message action buttons

struct MessageActionsView: View {
    var body: some View {
        HStack(spacing: 2) {
            actionButton("doc.on.doc", action: {})
            actionButton("arrow.clockwise", action: {})
            actionButton("arrow.branch", action: {})
            actionButton("hand.thumbsup", action: {})
        }
        .padding(.leading, -4)
    }

    private func actionButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(LC.textSecondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverBackground(radius: 5)
    }
}

// MARK: - Model loading overlay

struct ModelLoadingOverlayView: View {
    let modelName: String
    let progress: Double?   // nil = indeterminate
    let stage: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [LC.blue, Color(red: 0.749, green: 0.353, blue: 0.949)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        PulsingRing(color: LC.blue, size: 38)
                        Image(systemName: "cpu")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(modelName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(LC.textPrimary)
                        Text(stage)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(LC.textSecondary)
                    }
                }
                .padding(.bottom, 16)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(white: 1.0, opacity: 0.08))
                            .frame(height: 5)
                        if let p = progress {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [LC.blue, Color(red: 0.392, green: 0.710, blue: 1.0)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * p, height: 5)
                                .shadow(color: LC.blue.opacity(0.5), radius: 4)
                                .animation(.easeInOut(duration: 0.3), value: p)
                        } else {
                            // Indeterminate shimmer
                            IndeterminateProgressBar()
                                .frame(height: 5)
                        }
                    }
                }
                .frame(height: 5)
                .padding(.bottom, 8)

                // Stats row
                HStack {
                    if let p = progress {
                        Text(String(format: "%d%%", Int(p * 100)))
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(LC.textSecondary)
                        Spacer()
                        let remaining = (1.0 - p) * 6.0
                        Text(String(format: "%.1fs remaining", remaining))
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(LC.textSecondary)
                    } else {
                        Spacer()
                    }
                }
            }
            .padding(24)
            .frame(width: 360)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.172, green: 0.172, blue: 0.180, opacity: 0.95))
            )
            .lcBorder(Color(white: 1.0, opacity: 0.12), radius: 12)
            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
        }
    }
}

struct IndeterminateProgressBar: View {
    @State private var offset: CGFloat = -0.4

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [.clear, LC.blue, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: geo.size.width * 0.4, height: 5)
                .offset(x: geo.size.width * (offset + 0.4))
        }
        .clipped()
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                offset = 1.0
            }
        }
    }
}

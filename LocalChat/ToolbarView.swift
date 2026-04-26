import SwiftUI

struct ToolbarView: View {
    var vm: ChatViewModel

    var body: some View {
        HStack(spacing: 6) {
            // Show traffic-lights area + sidebar toggle when sidebar is hidden
            if !vm.sidebarVisible {
                // Traffic light spacer (window chrome places them top-left)
                Color.clear.frame(width: 68)
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        vm.sidebarVisible = true
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(LC.textTertiary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .hoverBackground(radius: 5)
            }

            // Conversation title
            Text(currentTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(white: 1.0, opacity: 0.88))
                .lineLimit(1)
                .padding(.horizontal, 6)

            Spacer()

            // Model pill
            ModelPillView(vm: vm)
                .onTapGesture { vm.showModelLibrary = true }

            Spacer().frame(width: 4)

            // Share
            ToolbarIconButton(systemName: "square.and.arrow.up")
            // More
            ToolbarIconButton(systemName: "ellipsis")
        }
        .padding(.horizontal, 10)
        .background(
            ZStack {
                LC.toolbarBg
            }
        )
        .background(.ultraThinMaterial)
        // Allow window drag from toolbar
        .simultaneousGesture(
            DragGesture().onChanged { _ in }
        )
    }

    private var currentTitle: String {
        guard let id = vm.selectedConversationId,
              let conv = vm.conversations.first(where: { $0.id == id }) else {
            return "LocalChat"
        }
        return conv.title
    }
}

// MARK: - Model Pill

struct ModelPillView: View {
    var vm: ChatViewModel
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Status dot
            statusDot
            // Model info
            VStack(alignment: .leading, spacing: 0) {
                Text(vm.selectedModel.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineHeight(1.15)
                Text("\(vm.selectedModel.quantLabel) · \(vm.selectedModel.sizeLabel)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(white: 1.0, opacity: 0.5))
                    .lineHeight(1.15)
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(white: 1.0, opacity: 0.55))
        }
        .foregroundColor(LC.textPrimary)
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isHovered ? Color(white: 1.0, opacity: 0.08) : Color(white: 1.0, opacity: 0.05))
        )
        .lcBorder(Color(white: 1.0, opacity: 0.10), radius: 7)
        .onHover { isHovered = $0 }
        .contentShape(RoundedRectangle(cornerRadius: 7))
    }

    @ViewBuilder
    private var statusDot: some View {
        ZStack {
            Circle()
                .fill(LC.statusColor(for: vm.modelStatus))
                .frame(width: 8, height: 8)
                .shadow(color: LC.statusColor(for: vm.modelStatus).opacity(
                    vm.modelStatus == .ready ? 0.6 : 0
                ), radius: 3)

            if case .loading = vm.modelStatus {
                PulsingRing(color: LC.amber, size: 12)
            }
            if case .downloading = vm.modelStatus {
                PulsingRing(color: LC.amber, size: 12)
            }
        }
        .frame(width: 8, height: 8)
    }
}

// MARK: - Pulsing ring animation

struct PulsingRing: View {
    let color: Color
    let size: CGFloat
    @State private var animate = false

    var body: some View {
        Circle()
            .stroke(color.opacity(0.4), lineWidth: 1)
            .frame(width: size, height: size)
            .scaleEffect(animate ? 2.0 : 1.0)
            .opacity(animate ? 0 : 0.8)
            .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: animate)
            .onAppear { animate = true }
    }
}

// MARK: - Toolbar icon button

struct ToolbarIconButton: View {
    let systemName: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button { action?() } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color(white: 1.0, opacity: 0.70))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverBackground(radius: 5)
    }
}

// Convenience to set line height on Text
extension View {
    func lineHeight(_ multiplier: CGFloat) -> some View {
        self
    }
}

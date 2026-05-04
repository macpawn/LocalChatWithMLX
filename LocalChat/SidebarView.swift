import SwiftUI

struct SidebarView: View {
    var vm: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            newChatButton
            conversationList
            footer
        }
        .background(
            ZStack {
                LC.sidebarBg
                Color(white: 1.0, opacity: 0.02) // subtle tint
            }
        )
        .background(.ultraThinMaterial)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(LC.divider)
                .frame(width: 0.5)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            // macOS traffic lights placeholder area (they float in window chrome above)
            Spacer()
            sidebarToggleButton
        }
        .frame(height: 44)
        .padding(.horizontal, 12)
    }

    private var sidebarToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                vm.sidebarVisible.toggle()
            }
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(LC.textTertiary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.clear)
        .hoverBackground(radius: 5)
    }

    // MARK: - New chat

    private var newChatButton: some View {
        Button {
            vm.newConversation()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                Text("New chat")
                    .font(.system(size: 12.5, weight: .medium))
                Spacer()
                Text("⌘N")
                    .font(.system(size: 10))
                    .foregroundColor(LC.textTertiary)
            }
            .foregroundColor(LC.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(white: 1.0, opacity: 0.06))
            )
            .lcBorder(Color(white: 1.0, opacity: 0.10), radius: 6)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("n", modifiers: .command)
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Conversation list

    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(vm.groupedConversations, id: \.group.rawValue) { section in
                    sectionHeader(section.group.rawValue)
                    ForEach(section.items) { conv in
                        ConversationRowView(
                            conv: conv,
                            isSelected: vm.selectedConversationId == conv.id
                        ) {
                            vm.selectConversation(conv.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(LC.textTertiary)
                .tracking(0.3)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
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
                    .frame(width: 22, height: 22)
                Text("LC")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text("Local user")
                .font(.system(size: 12))
                .foregroundColor(Color(white: 1.0, opacity: 0.85))
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .overlay(alignment: .top) {
            Rectangle().fill(LC.divider).frame(height: 0.5)
        }
    }
}

// MARK: - Conversation Row

struct ConversationRowView: View {
    let conv: Conversation
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(conv.title)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(LC.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if conv.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundColor(LC.textTertiary)
                    }
                }
                if !conv.preview.isEmpty {
                    HStack(spacing: 6) {
                        Text(conv.preview)
                            .font(.system(size: 11))
                            .foregroundColor(LC.textTertiary)
                            .lineLimit(1)
                        Spacer()
                        Text(relativeTime(conv.createdAt))
                            .font(.system(size: 10.5))
                            .foregroundColor(Color(white: 1.0, opacity: 0.35))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? LC.selectedConv : (isHovered ? LC.messageHover : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .numeric
        formatter.unitsStyle = .abbreviated
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "now" }
        if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m"
        }
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        if cal.isDateInYesterday(date) { return "Yest" }
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "MMM d"
        return dayFormatter.string(from: date)
    }
}

// MARK: - Hover background helper

struct HoverBackgroundModifier: ViewModifier {
    let radius: CGFloat
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(isHovered ? Color(white: 1.0, opacity: 0.08) : Color.clear)
            )
            .onHover { isHovered = $0 }
    }
}

extension View {
    func hoverBackground(radius: CGFloat = 6) -> some View {
        modifier(HoverBackgroundModifier(radius: radius))
    }
}

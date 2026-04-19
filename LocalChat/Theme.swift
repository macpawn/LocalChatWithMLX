import SwiftUI

// MARK: - App colour palette (mirrors LocalChat.html)

enum LC {
    // Backgrounds
    static let windowBg       = Color(red: 0.110, green: 0.110, blue: 0.118, opacity: 1.0) // #1c1c1e
    static let sidebarBg      = Color(red: 0.157, green: 0.157, blue: 0.165, opacity: 0.72)
    static let toolbarBg      = Color(red: 0.118, green: 0.118, blue: 0.125, opacity: 0.72)
    static let composerBg     = Color(white: 1.0, opacity: 0.04)
    static let codeBlockBg    = Color(white: 0, opacity: 0.35)
    static let messageHover   = Color(white: 1.0, opacity: 0.04)
    static let selectedConv   = Color(white: 1.0, opacity: 0.08)
    static let divider        = Color(white: 1.0, opacity: 0.08)

    // Accent colours
    static let blue           = Color(red: 0.039, green: 0.518, blue: 1.000, opacity: 1.0) // #0a84ff
    static let green          = Color(red: 0.188, green: 0.820, blue: 0.345, opacity: 1.0) // #30d158
    static let amber          = Color(red: 1.000, green: 0.624, blue: 0.039, opacity: 1.0) // #ff9f0a
    static let red            = Color(red: 1.000, green: 0.271, blue: 0.227, opacity: 1.0) // #ff453a

    // Text
    static let textPrimary    = Color(white: 1.0, opacity: 0.92)
    static let textSecondary  = Color(white: 1.0, opacity: 0.55)
    static let textTertiary   = Color(white: 1.0, opacity: 0.40)
    static let textMono       = Color(white: 1.0, opacity: 0.85)

    // Status dot colours
    static func statusColor(for status: ModelStatus) -> Color {
        switch status {
        case .ready:                return green
        case .loading, .downloading: return amber
        case .unloaded:             return Color(white: 1.0, opacity: 0.3)
        case .error:                return red
        }
    }
}

// MARK: - Convenience modifiers

extension View {
    /// Thin border used throughout the UI.
    func lcBorder(_ color: Color = Color(white: 1.0, opacity: 0.08), radius: CGFloat = 8) -> some View {
        self.overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(color, lineWidth: 0.5))
    }
}

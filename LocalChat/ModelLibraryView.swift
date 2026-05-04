import SwiftUI
import LocalChatKit

struct ModelLibraryView: View {
    var vm: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var search: String = ""
    @State private var customPath: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [LC.blue, Color(red: 0.749, green: 0.353, blue: 0.949)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "cpu")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 24, height: 24)

                Text("Models")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(LC.textPrimary)

                Spacer()

                Button { dismiss() } label: {
                    ZStack {
                        Circle()
                            .fill(Color(white: 1.0, opacity: 0.08))
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(LC.textSecondary)
                    }
                    .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .overlay(alignment: .bottom) {
                Rectangle().fill(LC.divider).frame(height: 0.5)
            }

            // Tabs
            HStack(spacing: 0) {
                ForEach(TabItem.allCases) { tab in
                    tabButton(tab)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .overlay(alignment: .bottom) {
                Rectangle().fill(LC.divider).frame(height: 0.5)
            }

            // Content
            switch vm.libraryTab {
            case .installed:
                modelListContent(models: allModels.filter { $0.isDownloaded })
            case .browse:
                modelListContent(models: allModels)
            case .custom:
                customPathContent
            }
        }
        .background(Color(red: 0.149, green: 0.149, blue: 0.157, opacity: 0.95))
        .background(.ultraThinMaterial)
        .preferredColorScheme(.dark)
        .frame(width: 720, height: 560)
        .lcBorder(Color(white: 1.0, opacity: 0.12), radius: 12)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Tab button

    enum TabItem: String, CaseIterable, Identifiable {
        case installed = "Installed"
        case browse    = "Browse"
        case custom    = "Load custom"

        var id: String { rawValue }
        var vmTab: ChatViewModel.LibraryTab {
            switch self {
            case .installed: return .installed
            case .browse:    return .browse
            case .custom:    return .custom
            }
        }
    }

    private func tabButton(_ tab: TabItem) -> some View {
        let isSelected = vm.libraryTab == tab.vmTab
        return Button {
            vm.libraryTab = tab.vmTab
        } label: {
            HStack(spacing: 6) {
                Text(tab.rawValue)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(isSelected ? LC.textPrimary : LC.textSecondary)
                if tab == .installed {
                    countBadge(allModels.filter { $0.isDownloaded }.count)
                }
                if tab == .browse {
                    countBadge(allModels.count)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isSelected ? LC.blue : Color.clear)
                    .frame(height: 2)
                    .offset(y: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func countBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(LC.textTertiary)
            .padding(.horizontal, 5)
            .background(
                Capsule().fill(Color(white: 1.0, opacity: 0.06))
            )
    }

    // MARK: - Model list

    private func modelListContent(models: [ModelMeta]) -> some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(LC.textTertiary)
                TextField("Search models…", text: $search)
                    .font(.system(size: 12))
                    .foregroundColor(LC.textPrimary)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(white: 0, opacity: 0.25))
            )
            .lcBorder(Color(white: 1.0, opacity: 0.08), radius: 6)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                Rectangle().fill(LC.divider).frame(height: 0.5)
            }

            // Model rows
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredModels(models)) { model in
                        ModelRowView(model: model, vm: vm, onDismiss: { dismiss() })
                    }
                }
            }
        }
    }

    private func filteredModels(_ models: [ModelMeta]) -> [ModelMeta] {
        guard !search.isEmpty else { return models }
        return models.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    // MARK: - Custom path

    private var customPathContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Load from local path")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(LC.textPrimary)
                Text("Point to a local MLX model directory. LocalChat will mmap it into the active runtime.")
                    .font(.system(size: 12))
                    .foregroundColor(LC.textSecondary)
                    .lineSpacing(3)
            }

            // Drop zone
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LC.blue.opacity(0.15))
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(Color(red: 0.392, green: 0.710, blue: 1.0))
                }
                .frame(width: 44, height: 44)
                Text("Drag a model file here, or")
                    .font(.system(size: 12.5))
                    .foregroundColor(Color(white: 1.0, opacity: 0.85))
                Button("Choose file…") {}
                    .buttonStyle(SecondaryButtonStyle())
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(white: 1.0, opacity: 0.02))
                    .lcBorder(Color(white: 1.0, opacity: 0.2), radius: 10)
            )

            // Path field
            VStack(alignment: .leading, spacing: 6) {
                Text("PATH")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(LC.textTertiary)
                    .tracking(0.3)
                HStack(spacing: 8) {
                    TextField("~/Models/my-model", text: $customPath)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(LC.textPrimary)
                        .textFieldStyle(.plain)
                    Button("Browse…") {}
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(white: 0, opacity: 0.3))
                )
                .lcBorder(Color(white: 1.0, opacity: 0.10), radius: 6)
            }

            Spacer()

            // Footer buttons
            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Load model") {}
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
    }

    // MARK: - Model data

    struct ModelMeta: Identifiable {
        let id: LocalChatKit.Model
        let name: String
        let params: String
        let quant: String
        let size: String
        let ctx: String
        let isDownloaded: Bool
        let isActive: Bool
        let isRecommended: Bool
    }

    private var allModels: [ModelMeta] {
        let isActive = vm.modelStatus == .ready
        return [
            ModelMeta(id: .gemma4_e2b,  name: "Gemma 4 E2B Instruct",   params: "2B",  quant: "Q4",   size: "~2 GB",   ctx: "8k",   isDownloaded: vm.downloadedModels.contains(.gemma4_e2b),  isActive: isActive && vm.selectedModel == .gemma4_e2b,  isRecommended: false),
            ModelMeta(id: .gemma4_e4b,  name: "Gemma 4 E4B Instruct",   params: "4B",  quant: "Q4",   size: "~4 GB",   ctx: "8k",   isDownloaded: vm.downloadedModels.contains(.gemma4_e4b),  isActive: isActive && vm.selectedModel == .gemma4_e4b,  isRecommended: true),
            ModelMeta(id: .llama3_2_1B, name: "Llama 3.2 1B Instruct",  params: "1B",  quant: "4bit", size: "~0.7 GB", ctx: "128k", isDownloaded: vm.downloadedModels.contains(.llama3_2_1B), isActive: isActive && vm.selectedModel == .llama3_2_1B, isRecommended: false),
            ModelMeta(id: .llama3_2_3B, name: "Llama 3.2 3B Instruct",  params: "3B",  quant: "4bit", size: "~2 GB",   ctx: "128k", isDownloaded: vm.downloadedModels.contains(.llama3_2_3B), isActive: isActive && vm.selectedModel == .llama3_2_3B, isRecommended: false),
        ]
    }
}

// MARK: - Model Row

struct ModelRowView: View {
    let model: ModelLibraryView.ModelMeta
    var vm: ChatViewModel
    let onDismiss: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // File icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accentColor.opacity(0.6))
                    .frame(width: 36, height: 36)
                Image(systemName: "doc.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(model.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(LC.textPrimary)
                    if model.isActive {
                        statusBadge("ACTIVE", color: LC.green)
                    }
                    if model.isRecommended {
                        statusBadge("RECOMMENDED", color: LC.blue)
                    }
                }
                HStack(spacing: 10) {
                    Text(model.params)
                    Text("·")
                    Text(model.quant)
                    Text("·")
                    Text(model.size)
                    Text("·")
                    Text(model.ctx + " ctx")
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(LC.textSecondary)
            }

            Spacer()

            actionButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHovered ? Color(white: 1.0, opacity: 0.04) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(LC.divider).frame(height: 0.5)
        }
        .onHover { isHovered = $0 }
    }

    private var accentColor: Color {
        switch model.id {
        case .gemma4_e2b:  return Color(red: 0.400, green: 0.361, blue: 0.804)
        case .gemma4_e4b:  return LC.green
        case .llama3_2_1B: return LC.blue
        case .llama3_2_3B: return LC.amber
        case .smolLM135M: return LC.red
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if model.isActive {
            Text("Loaded")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(LC.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.clear)
                )
                .lcBorder(Color(white: 1.0, opacity: 0.12), radius: 6)
        } else if model.isDownloaded {
            Button("Load") {
                vm.selectModel(model.id)
                vm.loadSelectedModel()
                onDismiss()
            }
            .buttonStyle(SecondaryButtonStyle())
        } else {
            Button {
                vm.selectModel(model.id)
                vm.loadSelectedModel()
                onDismiss()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Download")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func statusBadge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color.opacity(0.18))
            )
    }
}

// MARK: - Button styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LC.blue.opacity(configuration.isPressed ? 0.8 : 1.0))
            )
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(LC.textPrimary)
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(white: 1.0, opacity: configuration.isPressed ? 0.12 : 0.08))
            )
            .lcBorder(Color(white: 1.0, opacity: 0.10), radius: 6)
    }
}

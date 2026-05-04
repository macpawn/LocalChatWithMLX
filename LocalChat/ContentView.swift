import LocalChatKit
import SwiftUI

struct ContentView: View {
    @State private var vm = ChatViewModel()

    var body: some View {
        HStack(spacing: 0) {
            if vm.sidebarVisible {
                SidebarView(vm: vm)
                    .frame(width: 260)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            VStack(spacing: 0) {
                ToolbarView(vm: vm)
                    .frame(height: 48)
                Rectangle().fill(LC.divider).frame(height: 0.5)
                ZStack {
                    ChatAreaView(vm: vm)
                    modelOverlay
                }
            }
        }
        .background(LC.windowBg)
        .preferredColorScheme(.dark)
        .frame(minWidth: 720, minHeight: 500)
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: vm.sidebarVisible)
        .sheet(isPresented: Bindable(vm).showModelLibrary) {
            ModelLibraryView(vm: vm)
                .onAppear { vm.refreshDownloadedModels() }
        }
        .onAppear {
            // Auto-load on first launch
            vm.loadSelectedModel()
        }
    }

    @ViewBuilder
    private var modelOverlay: some View {
        switch vm.modelStatus {
        case .downloading(let progress, let speed, let totalBytes):
            ModelLoadingOverlayView(
                modelName: vm.selectedModel.displayName,
                progress: progress,
                speedMBps: speed,
                totalBytes: totalBytes,
                stage: String(format: "Downloading · %.1f MB/s", speed),
                cancel: { vm.cancelSelectedModelLoad() }
            )
        case .loading:
            ModelLoadingOverlayView(
                modelName: vm.selectedModel.displayName,
                progress: nil,
                speedMBps: 0,
                totalBytes: 0,
                stage: "Loading into memory…",
                cancel: { vm.cancelSelectedModelLoad() }
            )
        case .error(let message):
            ModelErrorOverlayView(
                modelName: vm.selectedModel.displayName,
                message: message
            ) {
                vm.showModelLibrary = true
            }
        default:
            EmptyView()
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1100, height: 720)
}

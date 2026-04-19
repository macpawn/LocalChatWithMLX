import SwiftUI
import LocalChatKit
import Combine

@MainActor
final class ChatViewModel: ObservableObject {

    // MARK: - Model state

    @Published var selectedModel: LocalChatKit.Model = .gemma4_e2b
    @Published var modelStatus: ModelStatus = .unloaded

    // MARK: - Conversations

    @Published var conversations: [Conversation] = []
    @Published var selectedConversationId: UUID?

    // MARK: - Current chat

    @Published var messages: [ChatMessage] = []
    @Published var isGenerating: Bool = false

    // MARK: - UI state

    @Published var sidebarVisible: Bool = true
    @Published var showModelLibrary: Bool = false
    @Published var libraryTab: LibraryTab = .installed

    enum LibraryTab: Equatable { case installed, browse, custom }

    // MARK: - Infrastructure

    private let manager = ModelManager()
    private var loadedModel: LoadedModel?
    private var session: ChatSession?
    private var generationTask: Task<Void, Never>?

    // MARK: - Model management

    func loadSelectedModel() {
        guard case .unloaded = modelStatus else { return }
        Task {
            do {
                let isOnDisk = await manager.isDownloaded(selectedModel)
                if !isOnDisk {
                    for try await progress in await manager.download(selectedModel) {
                        modelStatus = .downloading(
                            progress: Double(progress.percent) / 100.0,
                            speedMBps: progress.bytesPerSecond / 1_048_576
                        )
                    }
                }
                modelStatus = .loading
                let model = try await manager.load(selectedModel)
                loadedModel = model
                session = ChatSession(model: model, systemPrompt: "You are a helpful assistant.")
                modelStatus = .ready
            } catch {
                modelStatus = .error(error.localizedDescription)
            }
        }
    }

    func selectModel(_ model: LocalChatKit.Model) {
        guard model != selectedModel else { return }
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        loadedModel = nil
        session = nil
        selectedModel = model
        modelStatus = .unloaded
    }

    // MARK: - Chat

    func sendMessage(_ text: String) {
        guard case .ready = modelStatus, let session else { return }

        if selectedConversationId == nil {
            newConversation()
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(.user(trimmed))
        let assistantId = UUID()
        messages.append(ChatMessage(id: assistantId, role: .assistant, content: "", metrics: nil, isStreaming: true))
        isGenerating = true

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in await session.sendStreaming(trimmed) {
                    guard !Task.isCancelled else { break }
                    switch event {
                    case .token(let token):
                        if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                            messages[idx].content += token
                        }
                    case .completed(let stats):
                        if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                            messages[idx].isStreaming = false
                            messages[idx].metrics = MessageMetrics(
                                ttft: stats.timeToFirstToken,
                                tokPerSec: stats.tokensPerSecond,
                                promptTokens: stats.promptTokenCount,
                                responseTokens: stats.generatedTokenCount
                            )
                        }
                        isGenerating = false
                        updateConversationMeta(firstMessage: trimmed)
                    }
                }
            } catch {
                if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                    messages[idx].isStreaming = false
                }
                isGenerating = false
            }
        }
    }

    func stopGeneration() {
        generationTask?.cancel()
        generationTask = nil
        if let idx = messages.lastIndex(where: { $0.isStreaming }) {
            messages[idx].isStreaming = false
        }
        isGenerating = false
    }

    // MARK: - Conversations

    func newConversation() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        Task { await session?.clearHistory() }
        let conv = Conversation.new()
        conversations.insert(conv, at: 0)
        selectedConversationId = conv.id
        messages = []
    }

    func selectConversation(_ id: UUID) {
        guard id != selectedConversationId else { return }
        stopGeneration()
        Task { await session?.clearHistory() }
        selectedConversationId = id
        messages = []
    }

    // MARK: - Helpers

    private func updateConversationMeta(firstMessage: String) {
        guard let id = selectedConversationId,
              let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        if conversations[idx].title == "New chat" {
            conversations[idx].title = String(firstMessage.prefix(50))
        }
        conversations[idx].preview = String(firstMessage.prefix(70))
    }

    // MARK: - Conversation grouping

    enum ConversationGroup: String, Hashable {
        case pinned       = "Pinned"
        case today        = "Today"
        case yesterday    = "Yesterday"
        case previousWeek = "Previous 7 Days"
        case older        = "Older"
    }

    var groupedConversations: [(group: ConversationGroup, items: [Conversation])] {
        let pinned    = conversations.filter { $0.isPinned }
        let unpinned  = conversations.filter { !$0.isPinned }
        let calendar  = Calendar.current
        let now       = Date()
        let today     = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let weekAgo   = calendar.date(byAdding: .day, value: -7, to: today)!

        let todayItems     = unpinned.filter { $0.createdAt >= today }
        let yesterdayItems = unpinned.filter { $0.createdAt >= yesterday && $0.createdAt < today }
        let weekItems      = unpinned.filter { $0.createdAt >= weekAgo && $0.createdAt < yesterday }
        let olderItems     = unpinned.filter { $0.createdAt < weekAgo }

        return [
            (.pinned,       pinned),
            (.today,        todayItems),
            (.yesterday,    yesterdayItems),
            (.previousWeek, weekItems),
            (.older,        olderItems),
        ].filter { !$0.items.isEmpty }
    }
}

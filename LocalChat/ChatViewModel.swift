import SwiftUI
import LocalChatKit

@MainActor
@Observable
final class ChatViewModel {

    // MARK: - Dependencies

    private var settings: AppSettingsProtocol

    // MARK: - Model state

    var selectedModel: LocalChatKit.Model
    var modelStatus: ModelStatus {
        get { modelStatusStore[selectedModel] ?? .unloaded }
        set { modelStatusStore[selectedModel] = newValue }
    }

    // MARK: - Conversations

    var conversations: [Conversation] = []
    var selectedConversationId: UUID?

    // MARK: - Current chat

    var messages: [ChatMessage] = []
    var isGenerating: Bool = false

    // MARK: - UI state

    var sidebarVisible: Bool = true
    var showModelLibrary: Bool = false
    var libraryTab: LibraryTab = .installed
    var downloadedModels: Set<LocalChatKit.Model> = []

    enum LibraryTab: Equatable { case installed, browse }

    // MARK: - Infrastructure

    private let manager = ModelManager()
    private let downloader = HubDownloadManager()
    private var loadedModelStore: [LocalChatKit.Model: LoadedModel] = [:]
    private var modelStatusStore: [LocalChatKit.Model: ModelStatus] = [:]
    private var sessionStore: [UUID: ChatSession] = [:]
    private var modelLoadTasks: [LocalChatKit.Model: Task<Void, Never>] = [:]
    private var generationTask: Task<Void, Never>?
    private var messageStore: [UUID: [ChatMessage]] = [:]
    private var draftStore: [UUID: String] = [:]

    init(settings: AppSettingsProtocol = AppSettings.shared) {
        self.settings = settings
        self.selectedModel = settings.lastSelectedModel
    }

    // MARK: - Model management

    func loadSelectedModel() {
        guard case .unloaded = modelStatus else { return }
        let modelToLoad = selectedModel
        modelLoadTasks[modelToLoad]?.cancel()
        modelLoadTasks[modelToLoad] = Task { @MainActor in
            do {
                let isOnDisk = await manager.isDownloaded(modelToLoad)
                if !isOnDisk {
                    for try await progress in await downloader.download(modelToLoad) {
                        guard !Task.isCancelled else { return }
                        modelStatusStore[modelToLoad] = .downloading(
                            progress: Double(progress.percent) / 100.0,
                            speedMBps: progress.bytesPerSecond / 1_048_576
                        )
                    }
                }
                guard !Task.isCancelled else { return }
                modelStatusStore[modelToLoad] = .loading
                let model = try await manager.loadModel(modelToLoad)
                guard !Task.isCancelled else { return }
                loadedModelStore[modelToLoad] = model
                modelStatusStore[modelToLoad] = .ready
                modelLoadTasks[modelToLoad] = nil
                if modelToLoad == selectedModel {
                    createSessionForSelectedConversationIfNeeded()
                }
            } catch {
                guard !Task.isCancelled else { return }
                modelStatusStore[modelToLoad] = .error(error.localizedDescription)
                modelLoadTasks[modelToLoad] = nil
            }
        }
    }

    func cancelSelectedModelLoad() {
        cancelLoadIfNeeded(for: selectedModel)
    }

    func refreshDownloadedModels() {
        Task { @MainActor in
            var result: Set<LocalChatKit.Model> = []
            for model in LocalChatKit.Model.allCases {
                if await manager.isDownloaded(model) { result.insert(model) }
            }
            downloadedModels = result
        }
    }

    func selectModel(_ model: LocalChatKit.Model) {
        guard model != selectedModel else { return }
        guard canChangeModelForSelectedConversation else { return }
        cancelLoadIfNeeded(for: selectedModel)
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        if let selectedConversationId {
            sessionStore[selectedConversationId] = nil
            updateSelectedConversation { $0.model = model }
        }
        selectedModel = model
        synchronizeModelStatusForSelectedConversation()
        settings.lastSelectedModel = model
    }

    // MARK: - Chat

    func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if selectedConversationId == nil {
            newConversation()
        }

        guard case .ready = modelStatus,
              loadedModelStore[selectedModel] != nil,
              let convId = selectedConversationId,
              let session = sessionForSelectedConversation() else { return }

        let assistantId = UUID()

        messages.append(.user(trimmed))
        messages.append(ChatMessage(id: assistantId, role: .assistant, content: "", metrics: nil, isStreaming: true))
        messageStore[convId] = messages
        isGenerating = true

        generationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let sampling = selectedGenerationOptions
                for try await event in await session.sendStreaming(trimmed, sampling: sampling) {
                    guard !Task.isCancelled else { break }
                    switch event {
                    case .token(let token):
                        guard let idx = messageStore[convId]?.firstIndex(where: { $0.id == assistantId }) else { continue }
                        messageStore[convId]![idx].content += token
                        if selectedConversationId == convId,
                           let visibleIdx = messages.firstIndex(where: { $0.id == assistantId }) {
                            messages[visibleIdx].content += token
                        }
                    case .completed(let stats):
                        let metrics = MessageMetrics(
                            ttft: stats.timeToFirstToken,
                            tokPerSec: stats.tokensPerSecond,
                            promptTokens: stats.promptTokenCount,
                            responseTokens: stats.generatedTokenCount
                        )
                        if let idx = messageStore[convId]?.firstIndex(where: { $0.id == assistantId }) {
                            messageStore[convId]![idx].isStreaming = false
                            messageStore[convId]![idx].metrics = metrics
                        }
                        if selectedConversationId == convId,
                           let visibleIdx = messages.firstIndex(where: { $0.id == assistantId }) {
                            messages[visibleIdx].isStreaming = false
                            messages[visibleIdx].metrics = metrics
                        }
                        isGenerating = false
                        updateConversationMeta(firstMessage: trimmed, conversationId: convId)
                    }
                }
            } catch {
                if let idx = messageStore[convId]?.firstIndex(where: { $0.id == assistantId }) {
                    messageStore[convId]![idx].isStreaming = false
                }
                if selectedConversationId == convId,
                   let visibleIdx = messages.lastIndex(where: { $0.isStreaming }) {
                    messages[visibleIdx].isStreaming = false
                }
                isGenerating = false
            }
        }
    }

    func stopGeneration() {
        generationTask?.cancel()
        generationTask = nil
        if let convId = selectedConversationId,
           let idx = messageStore[convId]?.lastIndex(where: { $0.isStreaming }) {
            messageStore[convId]![idx].isStreaming = false
        }
        if let idx = messages.lastIndex(where: { $0.isStreaming }) {
            messages[idx].isStreaming = false
        }
        isGenerating = false
    }

    var selectedDraft: String {
        get {
            guard let selectedConversationId else { return "" }
            return draftStore[selectedConversationId] ?? ""
        }
        set {
            if selectedConversationId == nil {
                newConversation()
            }
            guard let selectedConversationId else { return }
            draftStore[selectedConversationId] = newValue
        }
    }

    var selectedGenerationOptions: SamplingConfig {
        get {
            guard let selectedConversationId,
                  let conversation = conversations.first(where: { $0.id == selectedConversationId }) else {
                return .init()
            }
            return conversation.generationOptions
        }
        set {
            if selectedConversationId == nil {
                newConversation()
            }
            updateSelectedConversation { $0.generationOptions = newValue }
        }
    }

    // MARK: - Conversations

    func newConversation() {
        stopGeneration()
        let conv = Conversation.new(model: settings.lastSelectedModel)
        conversations.insert(conv, at: 0)
        selectedConversationId = conv.id
        selectedModel = conv.model
        messages = []
        synchronizeModelStatusForSelectedConversation()
    }

    func selectConversation(_ id: UUID) {
        guard id != selectedConversationId else { return }
        selectedConversationId = id
        messages = messageStore[id] ?? []
        if let conversation = conversations.first(where: { $0.id == id }) {
            selectedModel = conversation.model
            synchronizeModelStatusForSelectedConversation()
        }
    }

    // MARK: - Helpers

    var canChangeModelForSelectedConversation: Bool {
        guard let selectedConversationId else { return true }
        return (messageStore[selectedConversationId] ?? messages).isEmpty
    }

    private func createSessionForSelectedConversationIfNeeded() {
        guard let selectedConversationId,
              sessionStore[selectedConversationId] == nil,
              case .ready = modelStatus,
              let loadedModel = loadedModelStore[selectedModel] else { return }
        sessionStore[selectedConversationId] = ChatSession(
            model: loadedModel,
            systemPrompt: "You are a helpful assistant."
        )
    }

    private func sessionForSelectedConversation() -> ChatSession? {
        createSessionForSelectedConversationIfNeeded()
        guard let selectedConversationId else { return nil }
        return sessionStore[selectedConversationId]
    }

    private func synchronizeModelStatusForSelectedConversation() {
        if modelStatusStore[selectedModel] == nil {
            modelStatusStore[selectedModel] = .unloaded
        }

        if case .ready = modelStatus {
            createSessionForSelectedConversationIfNeeded()
        }
    }

    private func cancelLoadIfNeeded(for model: LocalChatKit.Model) {
        guard let status = modelStatusStore[model] else { return }
        switch status {
        case .downloading, .loading:
            modelLoadTasks[model]?.cancel()
            modelLoadTasks[model] = nil
            modelStatusStore[model] = loadedModelStore[model] == nil ? .unloaded : .ready
        default:
            break
        }
    }

    private func updateSelectedConversation(_ update: (inout Conversation) -> Void) {
        guard let selectedConversationId,
              let idx = conversations.firstIndex(where: { $0.id == selectedConversationId }) else { return }
        update(&conversations[idx])
    }

    private func updateConversationMeta(firstMessage: String, conversationId: UUID) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
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

#if DEBUG
extension ChatViewModel {
    func markModelReadyForTesting(_ model: LocalChatKit.Model) {
        modelStatusStore[model] = .ready
    }

    func markModelDownloadingForTesting(_ model: LocalChatKit.Model) {
        modelStatusStore[model] = .downloading(progress: 0.25, speedMBps: 1.0)
    }
}
#endif

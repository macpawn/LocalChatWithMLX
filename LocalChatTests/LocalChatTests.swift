//
//  LocalChatTests.swift
//  LocalChatTests
//
//  Created by Dmytro on 19.04.2026.
//

import Foundation
import Testing
import LocalChatKit
@testable import LocalChat

@MainActor
struct LocalChatTests {

    @Test func appSettingsDefaultModelIsSmolLM135M() {
        let defaults = UserDefaults(suiteName: "LocalChatTests.appSettingsDefaultModelIsSmolLM135M")!
        defaults.removePersistentDomain(forName: "LocalChatTests.appSettingsDefaultModelIsSmolLM135M")
        let settings = AppSettings(defaults: defaults)

        #expect(settings.lastSelectedModel == LocalChatKit.Model.smolLM135M)
    }

    @Test func modelLibraryCatalogCoversAllSelectableModels() {
        let catalogIDs = Set(ModelLibraryView.ModelMeta.catalog.map { $0.id })

        #expect(catalogIDs == Set(LocalChatKit.Model.allCases))
    }

    @Test func newConversationUsesLastSelectedModel() {
        let settings = MockSettings(lastSelectedModel: .llama3_2_1B)
        let vm = ChatViewModel(settings: settings)

        vm.newConversation()

        #expect(vm.selectedModel == .llama3_2_1B)
        #expect(vm.conversations.first?.model == .llama3_2_1B)
    }

    @Test func newConversationStartsWithModelDefaultGenerationOptionsWithoutTokenLimit() {
        let settings = MockSettings(lastSelectedModel: .llama3_2_1B)
        let vm = ChatViewModel(settings: settings)

        vm.newConversation()

        #expect(vm.selectedGenerationOptions == .init())
        #expect(vm.selectedGenerationOptions.maxTokens == nil)
    }

    @Test func draftsAreStoredPerConversation() {
        let settings = MockSettings(lastSelectedModel: .llama3_2_1B)
        let vm = ChatViewModel(settings: settings)

        vm.newConversation()
        let firstId = vm.selectedConversationId!
        vm.selectedDraft = "First draft"

        vm.newConversation()
        let secondId = vm.selectedConversationId!
        vm.selectedDraft = "Second draft"

        vm.selectConversation(firstId)
        #expect(vm.selectedDraft == "First draft")

        vm.selectConversation(secondId)
        #expect(vm.selectedDraft == "Second draft")
    }

    @Test func generationOptionsAreStoredPerConversation() {
        let settings = MockSettings(lastSelectedModel: .llama3_2_1B)
        let vm = ChatViewModel(settings: settings)

        vm.newConversation()
        let firstId = vm.selectedConversationId!
        vm.selectedGenerationOptions = .init(temperature: 0.2, topP: 0.6, maxTokens: 48)

        vm.newConversation()
        let secondId = vm.selectedConversationId!
        vm.selectedGenerationOptions = .init(temperature: 1.1, topP: 0.8, maxTokens: nil)

        vm.selectConversation(firstId)
        #expect(vm.selectedGenerationOptions == .init(temperature: 0.2, topP: 0.6, maxTokens: 48))

        vm.selectConversation(secondId)
        #expect(vm.selectedGenerationOptions == .init(temperature: 1.1, topP: 0.8, maxTokens: nil))
    }

    @Test func tokenLimitEditorKeepsFieldEnabledWhenDigitsAreCleared() {
        var editor = TokenLimitEditorState(maxTokens: 256)

        editor.setText("")

        #expect(editor.isEnabled)
        #expect(editor.text == "")
        #expect(editor.maxTokens == nil)

        editor.setText("64")

        #expect(editor.isEnabled)
        #expect(editor.maxTokens == 64)
    }

    @Test func selectingModelUpdatesEmptyCurrentConversationAndDefaultForFutureChats() {
        let settings = MockSettings(lastSelectedModel: .gemma4_e2b)
        let vm = ChatViewModel(settings: settings)

        vm.newConversation()
        vm.selectModel(.llama3_2_3B)

        #expect(vm.selectedModel == .llama3_2_3B)
        #expect(vm.conversations.first?.model == .llama3_2_3B)
        #expect(settings.lastSelectedModel == .llama3_2_3B)
    }

    @Test func selectingModelDoesNotChangeConversationAfterMessagesExist() {
        let settings = MockSettings(lastSelectedModel: .gemma4_e2b)
        let vm = ChatViewModel(settings: settings)

        vm.newConversation()
        vm.messages = [.user("Hello")]
        vm.selectModel(.llama3_2_3B)

        #expect(vm.selectedModel == .gemma4_e2b)
        #expect(vm.conversations.first?.model == .gemma4_e2b)
        #expect(settings.lastSelectedModel == .gemma4_e2b)
    }

    @Test func newConversationUnloadsWhenDefaultModelIsNotCurrentLoadedModel() {
        let settings = MockSettings(lastSelectedModel: .llama3_2_3B)
        let vm = ChatViewModel(settings: settings)
        vm.selectedModel = .gemma4_e2b
        vm.modelStatus = .ready

        vm.newConversation()

        #expect(vm.selectedModel == .llama3_2_3B)
        #expect(vm.modelStatus == .unloaded)
    }

    @Test func switchingBackToStartedChatRestoresItsLoadedModelStatus() {
        let settings = MockSettings(lastSelectedModel: .gemma4_e2b)
        let vm = ChatViewModel(settings: settings)

        vm.newConversation()
        let gemmaChatId = vm.selectedConversationId!
        vm.markModelReadyForTesting(.gemma4_e2b)
        vm.messages = [.user("Use Gemma here")]

        settings.lastSelectedModel = .llama3_2_3B
        vm.newConversation()
        vm.markModelReadyForTesting(.llama3_2_3B)

        vm.selectConversation(gemmaChatId)

        #expect(vm.selectedModel == .gemma4_e2b)
        #expect(vm.modelStatus == .ready)
    }

    @Test func cancellingSelectedModelDownloadReturnsToUnloaded() {
        let settings = MockSettings(lastSelectedModel: .smolLM135M)
        let vm = ChatViewModel(settings: settings)
        vm.markModelDownloadingForTesting(.smolLM135M)

        vm.cancelSelectedModelLoad()

        #expect(vm.modelStatus == .unloaded)
    }
}

private final class MockSettings: AppSettingsProtocol {
    var lastSelectedModel: LocalChatKit.Model

    init(lastSelectedModel: LocalChatKit.Model) {
        self.lastSelectedModel = lastSelectedModel
    }
}

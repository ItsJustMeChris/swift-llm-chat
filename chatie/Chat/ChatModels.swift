import Foundation
import SwiftUI

enum Sender: String, Codable {
    case user
    case assistant
}

struct ChatMessageData: Codable, Identifiable {
    let id: UUID
    let sender: Sender
    var text: String
}

struct ChatSessionData: Codable, Identifiable {
    let id: UUID
    var modelId: String?
    var title: String
    var messages: [ChatMessageData]
    var lastModified: Date
}

struct ModelOption: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var description: String
    var badge: String?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(description)
        hasher.combine(badge)
    }

    init(id: String, name: String, description: String, badge: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.badge = badge
    }
}

class ChatMessageViewModel: ObservableObject, Identifiable {
    let id: UUID
    let sender: Sender

    @Published var text: String
    @Published var textBlocks: [String] = []
    @Published var openBlock: String = ""

    init(id: UUID = UUID(), sender: Sender, text: String = "") {
        self.id = id
        self.sender = sender
        self.text = text

        if !text.isEmpty {

             self.textBlocks = [text]
        }
    }

    convenience init(from data: ChatMessageData) {

        self.init(id: data.id, sender: data.sender, text: data.text)
    }

    func appendToOpenBlock(_ chunk: String) {
        self.openBlock += chunk

        self.text = (textBlocks + [openBlock]).joined()
    }

    func finalizeOpenBlock() {
        if !openBlock.isEmpty {
            textBlocks.append(openBlock)

            self.text = textBlocks.joined()
            openBlock = ""
        }
    }

    func toData() -> ChatMessageData {

        return ChatMessageData(id: self.id, sender: self.sender, text: self.text)
    }
}

class ChatSession: ObservableObject, Identifiable {
    let id: UUID
    @Published var model: ModelOption? = nil
    @Published var title: String
    @Published var messages: [ChatMessageViewModel]
    @Published var lastModified: Date

    init(id: UUID = UUID(), title: String = "New Chat", messages: [ChatMessageViewModel] = [], model: ModelOption? = nil, lastModified: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.model = model
        self.lastModified = lastModified
    }

    convenience init(from data: ChatSessionData, availableModels: [ModelOption]) {
        let messageVMs = data.messages.map { ChatMessageViewModel(from: $0) }

        let modelOption = availableModels.first { $0.id == data.modelId }
        self.init(id: data.id, title: data.title, messages: messageVMs, model: modelOption, lastModified: data.lastModified)
    }

    func toData() -> ChatSessionData {
        let messageData = messages.map { $0.toData() }
        return ChatSessionData(
            id: self.id,
            modelId: self.model?.id,
            title: self.title,
            messages: messageData,
            lastModified: self.lastModified
        )
    }

    func touch() {
        DispatchQueue.main.async {
             self.lastModified = Date()
        }
    }
}

class ChatSessionsViewModel: ObservableObject {
    @Published var chats: [ChatSession] = []
    @Published var selectedChatID: UUID?
    @Published var scrollToChatID: UUID? = nil
    @Published var refreshTrigger: Bool = false
    @Published var isLoading: Bool = true

    private var storageManager = ChatStorageManager()
    private var modelManager: ModelManager
    private var availableModels: [ModelOption] = []

    init(modelManager: ModelManager) {
        self.modelManager = modelManager
        self.availableModels = modelManager.models

        Task {
            await loadChats()
            await MainActor.run {

                if self.selectedChatID == nil {
                    self.selectedChatID = self.chats.first?.id
                }
                self.isLoading = false
            }
        }
    }

    func setAvailableModels(_ models: [ModelOption]) {
        self.availableModels = models

        DispatchQueue.main.async {
            for chat in self.chats {
                if let currentModelId = chat.model?.id,
                   let newModel = models.first(where: { $0.id == currentModelId }) {
                    if chat.model != newModel {
                        chat.model = newModel
                    }
                } else if let storedModelId = chat.toData().modelId,
                          let matchingModel = models.first(where: { $0.id == storedModelId }) {
                    chat.model = matchingModel
                }
            }
        }
    }

    func selectedChat() -> ChatSession? {
        guard let id = selectedChatID else { return nil }
        return chats.first { $0.id == id }
    }

    func addNewChat() async {
        let defaultModel = modelManager.getDefaultModel()
        let newChat = ChatSession(model: defaultModel)

        await MainActor.run {
            self.chats.insert(newChat, at: 0)
            self.selectedChatID = newChat.id
            self.scrollToChatID = newChat.id
        }

        await saveChat(newChat)
    }

    func deleteChat(chat: ChatSession) async {
        await storageManager.deleteChat(withId: chat.id)

        await MainActor.run {
            self.chats.removeAll { $0.id == chat.id }
            if self.selectedChatID == chat.id {
                self.selectedChatID = self.chats.first?.id
            }
        }
    }

    func loadChats() async {
        let loadedChatsData = await storageManager.loadAllChats()
        await MainActor.run {
            self.chats = loadedChatsData.map { ChatSession(from: $0, availableModels: self.availableModels) }
            if self.selectedChatID == nil || !self.chats.contains(where: { $0.id == self.selectedChatID }) {
                self.selectedChatID = self.chats.first?.id
            }
        }
    }

    func saveChat(_ chat: ChatSession) async {
        chat.touch()
        await storageManager.saveChat(chat.toData())
        await MainActor.run {
            self.sortChats()
        }
    }

    private func sortChats() {
        DispatchQueue.main.async {
            self.chats.sort { $0.lastModified > $1.lastModified }
        }
    }

    func chatDidChange(_ chat: ChatSession) async {
        await saveChat(chat)
    }
}

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

    @Published var textBlocks: [String] = []
    @Published var openBlock: String = ""

    var text: String {

        let combined = textBlocks + (openBlock.isEmpty ? [] : [openBlock])
        return combined.joined() 
    }

    init(id: UUID = UUID(), sender: Sender, initialText: String = "") {
        self.id = id
        self.sender = sender
        if !initialText.isEmpty {

            self.textBlocks = [initialText]
        }
    }

    convenience init(from data: ChatMessageData) {

        self.init(id: data.id, sender: data.sender, initialText: data.text)
    }

    func finalizeOpenBlock() {
        if !openBlock.isEmpty {
            textBlocks.append(openBlock)
            openBlock = ""

        }
    }

    func toData() -> ChatMessageData {

        let currentText = (textBlocks + (openBlock.isEmpty ? [] : [openBlock])).joined()
        return ChatMessageData(id: self.id, sender: self.sender, text: currentText)
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
    private var storageManager = ChatStorageManager() 
    private var availableModels: [ModelOption] = [] 

    init(availableModels: [ModelOption] = []) { 
        self.availableModels = availableModels
        loadChats() 
        if selectedChatID == nil, let firstChat = chats.first {
             selectedChatID = firstChat.id 
        } else if chats.isEmpty {

        }
    }

    func setAvailableModels(_ models: [ModelOption]) {
        self.availableModels = models

        DispatchQueue.main.async {
            for chat in self.chats {
                if let currentModelId = chat.model?.id, let newModel = models.first(where: { $0.id == currentModelId }) {
                    if chat.model != newModel { 
                         chat.model = newModel
                    }
                } else if let storedModelId = chat.toData().modelId, let matchingModel = models.first(where: { $0.id == storedModelId }) {

                     chat.model = matchingModel
                }
            }
        }
    }

    func selectedChat() -> ChatSession? {
        guard let id = selectedChatID else { return nil }
        return chats.first { $0.id == id }
    }

    func addNewChat() {

        let newChat = ChatSession() 
        DispatchQueue.main.async {
            self.chats.insert(newChat, at: 0) 
            self.selectedChatID = newChat.id
            self.saveChat(newChat) 
            self.sortChats() 
            self.scrollToChatID = newChat.id 
        }
    }

    func deleteChat(chat: ChatSession) {
        storageManager.deleteChat(withId: chat.id)
        DispatchQueue.main.async {
            let chatIndex = self.chats.firstIndex { $0.id == chat.id }
            self.chats.removeAll { $0.id == chat.id }

            if self.selectedChatID == chat.id {

                if let index = chatIndex, index > 0, self.chats.count > index - 1 {
                    self.selectedChatID = self.chats[index - 1].id
                } else {
                    self.selectedChatID = self.chats.first?.id 
                }

            }
        }
    }

    func loadChats() {
        let loadedChatsData = storageManager.loadAllChats() 
        DispatchQueue.main.async {
             self.chats = loadedChatsData.map { ChatSession(from: $0, availableModels: self.availableModels) }

             if self.selectedChatID == nil || !self.chats.contains(where: { $0.id == self.selectedChatID }) {
                 self.selectedChatID = self.chats.first?.id
             }
        }
    }

    func saveChat(_ chat: ChatSession) {
        chat.touch() 
        storageManager.saveChat(chat.toData())

         DispatchQueue.main.async {
             self.sortChats()
         }
    }

    private func sortChats() {

         DispatchQueue.main.async {
              self.chats.sort { $0.lastModified > $1.lastModified }
         }
    }

    func chatDidChange(_ chat: ChatSession) {
        saveChat(chat)
    }
}

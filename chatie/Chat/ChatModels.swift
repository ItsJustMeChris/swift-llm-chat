import Foundation
import SwiftUI

enum Sender {
    case user
    case assistant
}

class ChatMessageViewModel: ObservableObject, Identifiable {
    let id = UUID()
    let sender: Sender

    @Published var textBlocks: [String] = []

    @Published var openBlock: String = ""

    var text: String {
        let combined = textBlocks + (openBlock.isEmpty ? [] : [openBlock])
        return combined.joined(separator: "\n")
    }

    init(sender: Sender, initialText: String = "") {
        self.sender = sender
        if !initialText.isEmpty {

            self.textBlocks = [initialText]
        }
    }

    func finalizeOpenBlock() {
        if !openBlock.isEmpty {
            textBlocks.append(openBlock)
            openBlock = ""
        }
    }
}

class ChatSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published var model: ModelOption? = nil
    @Published var title: String = "Chat"
    @Published var messages: [ChatMessageViewModel] = []
}

class ChatSessionsViewModel: ObservableObject {
    @Published var chats: [ChatSession] = [ChatSession()]
    @Published var selectedChatID: UUID?

    init() {
        selectedChatID = chats.first?.id
    }

    func selectedChat() -> ChatSession? {
        if let id = selectedChatID {
            return chats.first(where: { $0.id == id })
        }
        return nil
    }

    func addNewChat() {
        let newChat = ChatSession()
        DispatchQueue.main.async {
            self.chats.append(newChat)
            self.selectedChatID = newChat.id
        }
    }
}

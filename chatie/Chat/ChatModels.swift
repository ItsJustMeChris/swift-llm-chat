import Foundation
import SwiftUI

enum Sender {
    case user
    case assistant
}

class ChatMessageViewModel: ObservableObject, Identifiable {
    let id = UUID()
    let sender: Sender
    @Published var text: String

    init(sender: Sender, text: String = "") {
        self.sender = sender
        self.text = text
    }
}

class ChatSession: ObservableObject, Identifiable {
    let id = UUID()
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

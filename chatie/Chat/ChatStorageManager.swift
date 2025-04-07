import Foundation

class ChatStorageManager {
    private let fileManager = FileManager.default
    private let chatsDirectoryName = "ChatSessions"
    private var chatsDirectory: URL?

    init() {

        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("Error: Could not find Application Support directory.")
            return
        }

        let appDirectoryURL = appSupportURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.example.chatie") 

        let directoryURL = appDirectoryURL.appendingPathComponent(chatsDirectoryName)

        do {

            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            chatsDirectory = directoryURL
            print("Chats will be stored in: \(directoryURL.path)")
        } catch {
            print("Error creating chat storage directory: \(error)")
            chatsDirectory = nil
        }
    }

    private func chatFileURL(for chatID: UUID) -> URL? {
        return chatsDirectory?.appendingPathComponent("\(chatID.uuidString).json")
    }

    func saveChat(_ chatData: ChatSessionData) {
        guard let fileURL = chatFileURL(for: chatData.id) else {
            print("Error: Could not get file URL for chat \(chatData.id)")
            return
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601 
        encoder.outputFormatting = .prettyPrinted 

        do {
            let data = try encoder.encode(chatData)
            try data.write(to: fileURL, options: .atomic) 

        } catch {
            print("Error saving chat \(chatData.id): \(error)")
        }
    }

    func loadChat(withId chatID: UUID) -> ChatSessionData? {
        guard let fileURL = chatFileURL(for: chatID) else {
            print("Error: Could not get file URL for chat \(chatID)")
            return nil
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {

            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 

        do {
            let data = try Data(contentsOf: fileURL)
            let chatData = try decoder.decode(ChatSessionData.self, from: data)

            return chatData
        } catch {
            print("Error loading chat \(chatID): \(error)")

            return nil
        }
    }

    func loadAllChats() -> [ChatSessionData] {
        guard let directoryURL = chatsDirectory else {
            print("Error: Chat storage directory not available.")
            return []
        }

        var allChats: [ChatSessionData] = []
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)

            for fileURL in fileURLs where fileURL.pathExtension == "json" {

                let filename = fileURL.deletingPathExtension().lastPathComponent
                if let chatID = UUID(uuidString: filename) {
                    if let chatData = loadChat(withId: chatID) {
                        allChats.append(chatData)
                    }
                } else {
                    print("Warning: Found non-UUID JSON file in chats directory: \(fileURL.lastPathComponent)")
                }
            }

            allChats.sort { $0.lastModified > $1.lastModified }
            return allChats

        } catch {
            print("Error loading all chats: \(error)")
            return []
        }
    }

    func deleteChat(withId chatID: UUID) {
        guard let fileURL = chatFileURL(for: chatID) else {
            print("Error: Could not get file URL for chat \(chatID) to delete.")
            return
        }

        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
                print("Successfully deleted chat file for ID: \(chatID)")
            } else {
                print("Chat file not found for deletion: \(chatID)")
            }
        } catch {
            print("Error deleting chat file \(chatID): \(error)")
        }
    }

    func deleteAllChats() {
         guard let directoryURL = chatsDirectory else {
             print("Error: Chat storage directory not available for deletion.")
             return
         }
         do {
             let fileURLs = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
             for fileURL in fileURLs where fileURL.pathExtension == "json" {
                 try fileManager.removeItem(at: fileURL)
             }
             print("Deleted all chat files.")
         } catch {
             print("Error deleting all chat files: \(error)")
         }
     }
}

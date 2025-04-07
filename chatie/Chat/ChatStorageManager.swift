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

    func saveChat(_ chatData: ChatSessionData) async {
        guard let fileURL = chatFileURL(for: chatData.id) else {
            print("Error: Could not get file URL for chat \(chatData.id)")
            return
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        await Task.detached(priority: .background) {
            do {
                let data = try encoder.encode(chatData)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                print("Error saving chat \(chatData.id) in background: \(error)")
            }
        }.value
    }

    func loadChat(withId chatID: UUID) async -> ChatSessionData? {
        guard let fileURL = chatFileURL(for: chatID) else {
            print("Error: Could not get file URL for chat \(chatID)")
            return nil
        }

        return await Task.detached(priority: .background) { () -> ChatSessionData? in
            guard self.fileManager.fileExists(atPath: fileURL.path) else {
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            do {
                let data = try Data(contentsOf: fileURL)
                let chatData = try decoder.decode(ChatSessionData.self, from: data)
                return chatData
            } catch {
                print("Error loading chat \(chatID) in background: \(error)")
                return nil
            }
        }.value
    }

    func loadAllChats() async -> [ChatSessionData] {
        guard let directoryURL = chatsDirectory else {
            print("Error: Chat storage directory not available.")
            return []
        }

        var allChats: [ChatSessionData] = []
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)

            await withTaskGroup(of: ChatSessionData?.self) { group in
                for fileURL in fileURLs where fileURL.pathExtension == "json" {
                    let filename = fileURL.deletingPathExtension().lastPathComponent
                    if let chatID = UUID(uuidString: filename) {
                        group.addTask {
                            return await self.loadChat(withId: chatID)
                        }
                    } else {
                        print("Warning: Found non-UUID JSON file in chats directory: \(fileURL.lastPathComponent)")
                    }
                }

                for await chatData in group {
                    if let data = chatData {
                        allChats.append(data)
                    }
                }
            }

            allChats.sort { $0.lastModified > $1.lastModified }
            return allChats

        } catch {
            print("Error loading all chats: \(error)")
            return []
        }
    }

    func deleteChat(withId chatID: UUID) async {
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

    func deleteAllChats() async {
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

import Foundation
// No need to import SwiftUI here anymore

func streamAssistantResponse(for chatSession: ChatSession) async throws -> AsyncThrowingStream<String, Error> {
    // Retrieve the API key directly from UserDefaults
    guard let apiKey = UserDefaults.standard.string(forKey: "openRouterApiKey"), !apiKey.isEmpty else {
        // Handle the case where the API key is not set or empty
        throw NSError(domain: "ChatAPIManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenRouter API Key not configured or is empty. Please set it in Settings."])
    }
    let client = OpenAIChat(apiKey: apiKey, baseURL: URL(string: "https://openrouter.ai/api")!)
    
    let messages = chatSession.messages.map { msg in
        ChatMessage(
            role: msg.sender == .user ? "user" : "assistant",
            content: .text(msg.text)
        )
    }
    
    let request = ChatCompletionRequest(
        model: chatSession.model?.id ?? "openrouter/quasar-alpha",
        messages: messages,
        stream: true
    )
    
    let streamChunks = try await client.createChatCompletionStream(request: request)
    
    return AsyncThrowingStream { continuation in
        Task {
            do {
                for try await chunk in streamChunks {
                    if let delta = chunk.choices?.first?.delta,
                       let content = delta.content {
                        continuation.yield(content)
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}

func streamChatName(for chatSession: ChatSession) async throws -> AsyncThrowingStream<String, Error> {
    // Retrieve the API key directly from UserDefaults
    guard let apiKey = UserDefaults.standard.string(forKey: "openRouterApiKey"), !apiKey.isEmpty else {
        // Handle the case where the API key is not set or empty
        throw NSError(domain: "ChatAPIManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenRouter API Key not configured or is empty. Please set it in Settings."])
    }
    let client = OpenAIChat(apiKey: apiKey, baseURL: URL(string: "https://openrouter.ai/api")!)
    
    let firstUserMessage = chatSession.messages.first(where: { $0.sender == .user })?.text ?? ""
    let namingPrompt = "Based on the following message, generate a short and creative title for this chat: \"\(firstUserMessage)\""
    
    let messages: [ChatMessage] = [
        ChatMessage(role: "system", content: .text("You are a chat title generator.")),
        ChatMessage(role: "user", content: .text(namingPrompt))
    ]
    
    let request = ChatCompletionRequest(
        model: chatSession.model?.id ?? "openrouter/quasar-alpha",
        messages: messages,
        stream: true
    )
    
    let streamChunks = try await client.createChatCompletionStream(request: request)
    
    return AsyncThrowingStream { continuation in
        Task {
            do {
                var titleText = ""
                for try await chunk in streamChunks {
                    if let delta = chunk.choices?.first?.delta,
                       let content = delta.content {
                        titleText += content
                        Task { @MainActor in
                            chatSession.title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        continuation.yield(content)
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}

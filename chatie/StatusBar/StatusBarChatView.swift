import SwiftUI

struct StatusBarChatView: View {
    @EnvironmentObject var chatSessionsViewModel: ChatSessionsViewModel
    @EnvironmentObject var modelManager: ModelManager
    @State private var message: String = ""
    @State private var isStreaming: Bool = false
    @State private var currentChat: ChatSession?
    @State private var streamingTask: Task<Void, Never>?

    @Namespace private var bottomID

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Circle()
                        .fill(Color.red.opacity(0.8))
                        .frame(width: 12, height: 12)
                        .shadow(radius: 0.5)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 10)

                if let currentChat = currentChat {
                    CustomModelPickerButton(
                        selectedModel: Binding<ModelOption>(
                            get: {
                                currentChat.model ?? modelManager.getDefaultModel() ??
                                ModelOption(id: "default", name: "Default", description: "Default Model")
                            },
                            set: { newModel in
                                if currentChat.model != newModel {
                                    currentChat.model = newModel
                                    Task {
                                        await chatSessionsViewModel.chatDidChange(currentChat)
                                    }
                                }
                            }
                        ),
                        options: modelManager.models
                    )
                    .frame(maxWidth: 200)
                }

                Spacer()

                Text("Quick Chat")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 12)
            }
            .padding(.vertical, 8)
            .padding(.top, 4)

            if let currentChat = currentChat {
                ScrollViewReader { scrollViewProxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(currentChat.messages) { msg in
                                ChatBubble(message: msg, parentWidth: 340)
                                    .id(msg.id)
                                    .padding(.vertical, 2)
                            }
                            Color.clear.frame(height: 1).id(bottomID)
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 4)
                        .padding(.bottom, 6)
                    }
                    .onChange(of: currentChat.messages.count) {
                        DispatchQueue.main.async {
                            withAnimation {
                                scrollViewProxy.scrollTo(bottomID, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        scrollViewProxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }

            Spacer()

            ChatInputBar(
                message: $message,
                onSend: sendMessage,
                onStop: stopStreaming,
                isStreaming: $isStreaming
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .frame(width: 400, height: 650)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sendMessage() {
        guard !message.isEmpty else { return }

        if currentChat == nil {
            Task {
                await chatSessionsViewModel.addNewChat()
                await MainActor.run {
                    currentChat = chatSessionsViewModel.selectedChat()
                    processMessage()
                }
            }
        } else {
            processMessage()
        }
    }

    private func processMessage() {
        guard let chat = currentChat else { return }
        let messageText = message
        message = ""

        let userMsg = ChatMessageViewModel(sender: .user, text: messageText)
        withAnimation {
            chat.messages.append(userMsg)
        }
        Task {
            await chatSessionsViewModel.chatDidChange(chat)
        }

        let userMessageCount = chat.messages.filter { $0.sender == .user }.count
        if userMessageCount == 1 {
            Task {
                do {
                    let namingStream = try await streamChatName(for: chat)
                    for try await _ in namingStream {}
                    await chatSessionsViewModel.chatDidChange(chat)
                } catch {
                    print("Chat naming stream error: \(error)")
                }
            }
        }

        let assistantMessage = ChatMessageViewModel(sender: .assistant)
        withAnimation {
            chat.messages.append(assistantMessage)
        }
        Task {
            await chatSessionsViewModel.chatDidChange(chat)
        }

        isStreaming = true
        streamingTask = Task {
            do {
                let stream = try await streamAssistantResponse(for: chat)
                for try await partialText in stream {
                    if Task.isCancelled { break }
                    await MainActor.run {
                        assistantMessage.appendToOpenBlock(partialText)
                    }
                    try? await Task.sleep(nanoseconds: 10_000_000)
                }
                await MainActor.run {
                    assistantMessage.finalizeOpenBlock()
                }
            } catch {
                if !(error is CancellationError) {
                    print("Streaming error: \(error)")
                    await MainActor.run {
                        assistantMessage.text += "\n\nError during streaming."
                        assistantMessage.finalizeOpenBlock()
                    }
                }
            }
            await Task { @MainActor in
                isStreaming = false
                streamingTask = nil
                await chatSessionsViewModel.chatDidChange(chat)
            }.value
        }
    }

    private func stopStreaming() {
        streamingTask?.cancel()
    }
}

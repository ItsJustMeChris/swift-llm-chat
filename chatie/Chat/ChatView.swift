import SwiftUI
import Combine

struct ChatView: View {
    @ObservedObject var chatSession: ChatSession
    @EnvironmentObject var viewModel: ChatSessionsViewModel
    @State private var message: String = ""
    @State private var isStreaming: Bool = false
    @State private var streamingTask: Task<Void, Never>? = nil

    @Namespace private var bottomID

    var body: some View {
        GeometryReader { geometry in
            HStack {
                Spacer()
                VStack(spacing: 0) {
                    ScrollViewReader { scrollViewProxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(chatSession.messages) { msg in
                                    ChatBubble(message: msg, parentWidth: min(1000, geometry.size.width - 32))
                                        .id(msg.id)
                                        .padding(.vertical, 4)
                                }
                                Color.clear.frame(height: 1).id(bottomID)
                            }
                            .padding(.horizontal)
                        }
                        .onChange(of: chatSession.messages.count) {

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

                    ChatInputBar(
                        message: $message,
                        onSend: sendMessage,
                        onStop: stopStreaming,
                        isStreaming: $isStreaming
                    )
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .padding(.horizontal)
                }
                .frame(maxWidth: 1000)
                Spacer()
            }
            .background(Color(NSColor.windowBackgroundColor).edgesIgnoringSafeArea(.all))
        }
    }

    private func sendMessage() {
        guard !message.isEmpty else { return }

        let messageText = message
        message = ""

        let userMsg = ChatMessageViewModel(sender: .user, text: messageText)

        withAnimation {
            chatSession.messages.append(userMsg)
        }

        Task {
            await viewModel.chatDidChange(chatSession)
        }

        let userMessageCount = chatSession.messages.filter { $0.sender == .user }.count
        if userMessageCount == 1 {
            Task {
                do {
                    let namingStream = try await streamChatName(for: chatSession)

                    for try await _ in namingStream {}

                    await Task { @MainActor in
                        await viewModel.chatDidChange(chatSession)
                    }.value
                } catch {
                    print("Chat naming stream error: \(error)")
                }
            }
        }

        let assistantMessage = ChatMessageViewModel(sender: .assistant)

        withAnimation {
            chatSession.messages.append(assistantMessage)
        }

        Task {
            await viewModel.chatDidChange(chatSession)
        }

        isStreaming = true
        streamingTask = Task {
            do {
                let stream = try await streamAssistantResponse(for: chatSession)

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
                await viewModel.chatDidChange(chatSession)
            }.value
        }
    }

    private func stopStreaming() {
        streamingTask?.cancel()
    }
}

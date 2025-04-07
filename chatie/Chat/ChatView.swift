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
                            withAnimation {
                                scrollViewProxy.scrollTo(bottomID, anchor: .bottom)
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

        let userMsg = ChatMessageViewModel(sender: .user, initialText: messageText)
        withAnimation {
            chatSession.messages.append(userMsg)
        }
        chatSession.lastActivity = Date()
        viewModel.refreshTrigger.toggle()

        let userMessageCount = chatSession.messages.filter { $0.sender == .user }.count
        if userMessageCount == 1 {
            Task {
                do {
                    let namingStream = try await streamChatName(for: chatSession)
                    for try await _ in namingStream {}
                } catch {
                    print("Chat naming stream error: \(error)")
                }
            }
        }

        let assistantMessage = ChatMessageViewModel(sender: .assistant)
        withAnimation {
            chatSession.messages.append(assistantMessage)
        }
        chatSession.lastActivity = Date()
        viewModel.refreshTrigger.toggle()

        isStreaming = true
        streamingTask = Task {
            do {
                let stream = try await streamAssistantResponse(for: chatSession)
                let threshold: TimeInterval = 0.1
                var lastUpdate = Date()
                var pendingChunk = ""
                var flushTask: Task<Void, Never>? = nil

                func flushPendingChunk() async {
                    await MainActor.run {
                        assistantMessage.openBlock += pendingChunk
                        if assistantMessage.openBlock.contains("\n") {
                            let components = assistantMessage.openBlock.split(separator: "\n", omittingEmptySubsequences: false)
                            if components.count > 1 {
                                for comp in components.dropLast() {
                                    assistantMessage.textBlocks.append(String(comp))
                                }
                                assistantMessage.openBlock = String(components.last ?? "")
                            }
                        }
                        pendingChunk = ""
                        chatSession.lastActivity = Date()
                        viewModel.refreshTrigger.toggle()
                    }
                }

                func scheduleFlush(after delay: TimeInterval) {
                    flushTask?.cancel()
                    flushTask = Task {
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        await flushPendingChunk()
                        lastUpdate = Date()
                    }
                }

                for try await partialText in stream {
                    if Task.isCancelled { break }
                    pendingChunk += partialText
                    let now = Date()
                    let timeSinceLast = now.timeIntervalSince(lastUpdate)
                    if timeSinceLast >= threshold {
                        flushTask?.cancel()
                        flushTask = nil
                        await flushPendingChunk()
                        lastUpdate = now
                    } else if flushTask == nil {
                        scheduleFlush(after: threshold - timeSinceLast)
                    }
                }
                flushTask?.cancel()
                flushTask = nil
                await flushPendingChunk()
                await MainActor.run {
                    assistantMessage.finalizeOpenBlock()
                }
            } catch {
                print("Streaming error: \(error)")
            }
            await MainActor.run {
                isStreaming = false
                streamingTask = nil
            }
        }
    }

    private func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
    }
}

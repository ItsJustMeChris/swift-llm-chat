import SwiftUI
import Combine

struct ChatView: View {
    @ObservedObject var chatSession: ChatSession
    @State private var message: String = ""

    @Namespace private var bottomID

    var body: some View {
        GeometryReader { geometry in
            HStack {
                Spacer() // Center the content horizontally
                VStack(spacing: 0) { // Use VStack to stack ScrollView and InputBar
                    ScrollViewReader { scrollViewProxy in
                        ScrollView {
                            LazyVStack(spacing: 0) { // Use LazyVStack for performance
                                ForEach(chatSession.messages) { msg in
                                    ChatBubble(message: msg, parentWidth: min(1000, geometry.size.width - 32))
                                        .id(msg.id)
                                        .padding(.vertical, 4) // Add some vertical padding between bubbles
                                }
                                Color.clear.frame(height: 1).id(bottomID) // Anchor for scrolling
                            }
                            .padding(.horizontal) // Add horizontal padding to the content
                        }
                        .onChange(of: chatSession.messages.count) { _ in
                            // Scroll to the bottom when message count changes
                            withAnimation {
                                scrollViewProxy.scrollTo(bottomID, anchor: .bottom)
                            }
                        }
                        .onAppear {
                            // Scroll to bottom initially
                             scrollViewProxy.scrollTo(bottomID, anchor: .bottom)
                        }
                    }

                    ChatInputBar(message: $message, onSend: sendMessage)
                        .padding(.top, 4) // Add padding above input bar
                        .padding(.bottom, 8) // Keep bottom padding
                        .padding(.horizontal) // Use consistent horizontal padding
                }
                .frame(maxWidth: 1000) // Limit the max width of the chat content
                Spacer() // Center the content horizontally
            }
            // Removed the explicit frame setting on HStack, GeometryReader handles sizing
            .background(Color(NSColor.windowBackgroundColor).edgesIgnoringSafeArea(.all)) // Apply background to the whole view
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

        Task {
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
        }
    }
}

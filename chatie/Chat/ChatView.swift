import SwiftUI
import Combine

struct ChatView: View {
    @ObservedObject var chatSession: ChatSession
    @State private var message: String = ""
    @State private var scrollToBottom: Bool = false

    @Namespace private var bottomID

    var body: some View {
        GeometryReader { geometry in
            HStack {
                Spacer()
                VStack {
                    ScrollViewReader { scrollViewProxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(chatSession.messages) { msg in
                                    ChatBubble(message: msg, parentWidth: min(1000, geometry.size.width - 32))
                                        .id(msg.id)
                                        .transition(.opacity)
                                }
                                Color.clear.frame(height: 1).id(bottomID)
                            }
                            .padding()
                        }
                        .onChange(of: scrollToBottom) { _ in
                            withAnimation {
                                scrollViewProxy.scrollTo(bottomID, anchor: .bottom)
                            }
                            scrollToBottom = false
                        }
                        .onChange(of: chatSession.messages.count) { _ in
                            scrollToBottom = true
                        }
                    }

                    ChatInputBar(message: $message, onSend: sendMessage)
                        .padding(.bottom, 8)
                        .padding(.horizontal, 8)
                }
                .frame(maxWidth: 1000)
                Spacer()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
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

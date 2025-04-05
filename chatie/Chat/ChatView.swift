import SwiftUI
import Combine

struct ChatView: View {
  @ObservedObject var chatSession: ChatSession
  @State private var message: String = ""
  @State private var scrollToBottom: Bool = false
  
  @Namespace private var bottomID
  
  private let updateThrottle: TimeInterval = 0.1
  
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
    
    let userMsg = ChatMessageViewModel(sender: .user, text: messageText)
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
    
    let assistantMessage = ChatMessageViewModel(sender: .assistant, text: "")
    withAnimation {
      chatSession.messages.append(assistantMessage)
    }
    
    Task {
      do {
        let stream = try await streamAssistantResponse(for: chatSession)
        
        var buffer = ""
        var lastUpdateTime = Date()
        var timer: Timer?
        
        timer = Timer.scheduledTimer(withTimeInterval: updateThrottle, repeats: true) { _ in
          Task { @MainActor in
            if !buffer.isEmpty {
              assistantMessage.text += buffer
              buffer = ""
              lastUpdateTime = Date()
            }
          }
        }
        
        for try await partialText in stream {
          buffer += partialText
          
          let currentTime = Date()
          if currentTime.timeIntervalSince(lastUpdateTime) >= updateThrottle || buffer.contains("\n") {
            let textToAppend = buffer
            await MainActor.run {
              assistantMessage.text += textToAppend
            }
            buffer = ""
            lastUpdateTime = currentTime
          }
        }
        
        timer?.invalidate()
        
        if !buffer.isEmpty {
          await MainActor.run {
            assistantMessage.text += buffer
          }
        }
      } catch {
        print("Streaming error: \(error)")
      }
    }
  }
}

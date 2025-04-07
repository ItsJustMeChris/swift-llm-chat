import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: ChatSessionsViewModel
    @Namespace var topID

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Color.clear.frame(height: 0).id(topID)

                ForEach(viewModel.chats) { chat in
                    ChatRow(chat: chat)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(viewModel.selectedChatID == chat.id ? Color.secondary.opacity(0.2) : Color.clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .onTapGesture {
                            viewModel.selectedChatID = chat.id
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteChat(chat: chat)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button("Delete Chat", role: .destructive) {
                                Task {
                                    await viewModel.deleteChat(chat: chat)
                                }
                            }
                        }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("All Chats")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {

                        Task {
                            await viewModel.addNewChat()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("New Chat")

                    .onChange(of: viewModel.scrollToChatID) { newID in

                        if let idToScroll = newID {
                            DispatchQueue.main.async {
                                withAnimation {
                                    proxy.scrollTo(idToScroll, anchor: .top)
                                }
                                viewModel.scrollToChatID = nil
                            }
                        }
                    }
                }
            }
        }

    }

    struct ChatRow: View {
        @ObservedObject var chat: ChatSession

        var body: some View {
            VStack(alignment: .leading) {
                Text(chat.title.isEmpty ? "New Chat" : chat.title)
                    .lineLimit(1)

                if let lastMessageText = chat.messages.last?.text, !lastMessageText.isEmpty {
                    Text(lastMessageText)
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {

                    Text("No messages yet")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
    }

    struct SidebarItem: View {
        let label: String
        let systemImage: String
        let id: String
        @Binding var selection: String?

        @State private var isHovered = false

        var isSelected: Bool {
            selection == id
        }

        var body: some View {
            Button(action: {
                DispatchQueue.main.async {
                    selection = id
                }
            }) {
                Label(label, systemImage: systemImage)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(backgroundColor)
                    }
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .onHover { hovering in
                DispatchQueue.main.async {
                    isHovered = hovering
                }
            }
        }

        private var backgroundColor: Color {
            if isSelected {
                return Color.accentColor.opacity(0.2)
            } else if isHovered {
                return Color.primary.opacity(0.05)
            } else {
                return Color.clear
            }
        }
    }
}

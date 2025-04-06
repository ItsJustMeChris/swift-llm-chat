import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: ChatSessionsViewModel

    var body: some View {
        List(selection: $viewModel.selectedChatID) {
            Section(header: Text("Chats")) {
                ForEach(viewModel.chats.sorted { $0.lastActivity > $1.lastActivity }) { chat in
                    ChatRow(chat: chat)
                        .tag(chat.id as UUID?)
                }
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("All Chats")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.addNewChat()
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Chat")
            }
        }
    }
}

struct ChatRow: View {
    @ObservedObject var chat: ChatSession
    
    var body: some View {
        Text(chat.title)
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

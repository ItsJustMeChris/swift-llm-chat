import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = ChatSessionsViewModel()
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
                .environmentObject(viewModel)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 300)
        } detail: {
            if let selectedChat = viewModel.selectedChat() {
                ChatView(chatSession: selectedChat)
                    .id(selectedChat.id)
            } else {
                ContentArea()
            }
        }
    }
    
    private func toggleSidebar() {
        #if os(macOS)
        NSApp.keyWindow?
            .firstResponder?
            .tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
        #endif
    }
}

struct ContentArea: View {
    var body: some View {
        Text("Welcome! Select or create a Chat in the sidebar.")
            .font(.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.1))
    }
}

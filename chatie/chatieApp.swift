import SwiftUI

@main
struct chatieApp: App {
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var chatSessionsViewModel = ChatSessionsViewModel.shared
    @StateObject private var statusBarManager = StatusBarManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(modelManager)
                .environmentObject(chatSessionsViewModel) 
        }

        Settings {
            ConfigurationView()
                .environmentObject(modelManager)
        }
    }
}

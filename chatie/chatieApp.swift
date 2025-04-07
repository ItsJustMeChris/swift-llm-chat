import SwiftUI

@main
struct chatieApp: App {

    @StateObject private var modelManager = ModelManager()

    @StateObject private var chatSessionsViewModel: ChatSessionsViewModel

    init() {

        let initialModelManager = ModelManager()
        _modelManager = StateObject(wrappedValue: initialModelManager)

        _chatSessionsViewModel = StateObject(wrappedValue: ChatSessionsViewModel(availableModels: initialModelManager.models))
    }

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

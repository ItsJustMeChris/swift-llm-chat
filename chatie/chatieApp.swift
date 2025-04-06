import SwiftUI

@main
struct chatieApp: App {
    // Create the ModelManager instance
    @StateObject private var modelManager = ModelManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                // Inject ModelManager into the environment
                .environmentObject(modelManager)
        }
        // Add a Settings scene
        Settings {
            ConfigurationView()
                // Inject ModelManager here as well
                .environmentObject(modelManager)
        }
    }
}

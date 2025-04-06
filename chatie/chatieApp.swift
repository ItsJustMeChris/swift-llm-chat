import SwiftUI

@main
struct chatieApp: App {

    @StateObject private var modelManager = ModelManager()

    var body: some Scene {
        WindowGroup {
            RootView()

                .environmentObject(modelManager)
        }

        Settings {
            ConfigurationView()

                .environmentObject(modelManager)
        }
    }
}

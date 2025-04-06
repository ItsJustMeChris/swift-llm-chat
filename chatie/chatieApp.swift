import SwiftUI

@main
struct sidebarifyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .windowToolbarStyle(UnifiedWindowToolbarStyle())
    }
}

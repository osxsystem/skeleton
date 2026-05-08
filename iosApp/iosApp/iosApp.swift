import SwiftUI

@main
struct iosApp: App {
    init() {
        AppKoinBridge.start()    // Initialize Koin before any ViewModel is resolved
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

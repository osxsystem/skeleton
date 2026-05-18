import SwiftUI

@main
struct iosApp: App {
    init() {
        AppKoinBridge.start()
    }

    @Environment(\.colorScheme) private var systemColorScheme
    @State private var themeOverride: ColorScheme? = nil

    var body: some Scene {
        WindowGroup {
            let effectiveScheme = themeOverride ?? systemColorScheme
            ContentView(themeOverride: $themeOverride)
                .environment(\.appTheme, AppTheme.build(isDark: effectiveScheme == .dark))
                .preferredColorScheme(themeOverride)
        }
    }
}

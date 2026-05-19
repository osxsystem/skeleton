import SwiftUI

struct ContentView: View {
    @Binding var themeOverride: ColorScheme?
    @State private var isAuthenticated: Bool = false

    var body: some View {
        NavigationStack {
            if isAuthenticated {
                DashboardPlaceholder(
                    themeOverride: $themeOverride,
                    onLogout: { isAuthenticated = false }
                )
            } else {
                LoginScreen(onSuccess: { isAuthenticated = true })
            }
        }
    }
}

import SwiftUI

struct ContentView: View {
    @Binding var themeOverride: ColorScheme?

    var body: some View {
        NavigationStack {
            GreetingScreen(themeOverride: $themeOverride)
        }
    }
}

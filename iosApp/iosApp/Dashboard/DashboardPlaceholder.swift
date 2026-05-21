import SwiftUI

struct DashboardPlaceholder: View {
    @Binding var themeOverride: ColorScheme?
    let onLogout: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.md) {
            Text("Dashboard")
                .font(theme.typography.headlineMedium)
            NavigationLink("Number Input Showcase", destination: NumberInputKitShowcaseView())
            Button("Log out", action: onLogout)
            Button(action: cycleTheme) {
                Text(themeButtonLabel)
            }
        }
        .navigationTitle("Dashboard")
    }

    private var themeButtonLabel: String {
        switch themeOverride {
        case .none:   return "Override theme"
        case .light?: return "Switch to Dark"
        case .dark?:  return "Switch to System"
        @unknown default: return "Override theme"
        }
    }

    private func cycleTheme() {
        switch themeOverride {
        case .none:   themeOverride = .light
        case .light?: themeOverride = .dark
        case .dark?:  themeOverride = nil
        @unknown default: themeOverride = nil
        }
    }
}

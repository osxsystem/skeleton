import SwiftUI
import SkeletonApp

struct GreetingScreen: View {
    @StateObject private var owner = IosViewModelStoreOwner()
    @State private var uiState: GreetingViewModelUiState = GreetingViewModelUiStateLoading.shared
    @State private var stateJob: Kotlinx_coroutines_coreJob?
    @Environment(\.appTheme) private var theme
    @Binding var themeOverride: ColorScheme?

    var body: some View {
        let vm: GreetingViewModel = GreetingViewModelHelperKt.createGreetingViewModel(
            store: owner.viewModelStore
        )
        VStack(spacing: theme.spacing.md) {
            stateContent
            Button(action: cycleTheme) {
                Text(buttonLabel)
            }
        }
        .task {
            vm.loadGreeting(id: 1)
            stateJob = GreetingViewModelHelperKt.subscribeGreetingState(vm: vm) { state in
                uiState = state
            }
        }
        .onDisappear {
            stateJob?.cancel(cause: nil)
            stateJob = nil
        }
        .navigationTitle("Greeting")
    }

    @ViewBuilder
    private var stateContent: some View {
        if let ready = uiState as? GreetingViewModelUiStateReady {
            Text(ready.message).font(.title)
        } else if let error = uiState as? GreetingViewModelUiStateError {
            Text("Error: \(error.message)")
                .foregroundColor(theme.colors.error)
        } else {
            ProgressView()
        }
    }

    private var buttonLabel: String {
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

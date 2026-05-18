import SwiftUI
import SkeletonApp

struct GreetingScreen: View {
    @StateObject private var owner = IosViewModelStoreOwner()
    @State private var uiState: GreetingViewModelUiState = GreetingViewModelUiStateLoading.shared
    @State private var stateJob: Kotlinx_coroutines_coreJob?

    var body: some View {
        let vm: GreetingViewModel = GreetingViewModelHelperKt.createGreetingViewModel(
            store: owner.viewModelStore
        )
        Group {
            if let ready = uiState as? GreetingViewModelUiStateReady {
                Text(ready.message).font(.title)
            } else if let error = uiState as? GreetingViewModelUiStateError {
                Text("Error: \(error.message)")
                    .foregroundColor(.red)
            } else {
                ProgressView()
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
}

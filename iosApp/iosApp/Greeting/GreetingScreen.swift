import SwiftUI
import SkeletonKit

struct GreetingScreen: View {
    // D-12 / Pitfall 1+2: ALWAYS @StateObject — never @ObservedObject
    @StateObject private var owner = IosViewModelStoreOwner()
    @State private var uiState: GreetingViewModelUiState = .loading

    var body: some View {
        let vm: GreetingViewModel = owner.viewModel(
            factory: GreetingViewModelFactoryKt.greetingViewModelFactory
        )
        Group {
            switch onEnum(of: uiState) {
            case .loading:
                ProgressView()
            case .ready(let s):
                Text(s.message)
                    .font(.title)
            case .error(let e):
                Text("Error: \(e.message)")
                    .foregroundColor(.red)
            }
        }
        .task {
            vm.loadGreeting(id: 1)
            for await s in vm.state {    // SKIE bridges StateFlow -> AsyncSequence
                uiState = s
            }
        }
        .navigationTitle("Greeting")
    }
}

import SkeletonApp
import Foundation

/**
 * iOS lifecycle host for shared KMP ViewModels.
 *
 * RULES (D-12 / Pitfall 1 + 2):
 * - ALWAYS declare this as @StateObject in the parent SwiftUI View.
 * - deinit MUST call viewModelStore.clear() — this cancels all viewModelScope coroutines.
 *
 * NOTE: Without SKIE, the generic `viewModel<VM>(factory:)` bridge is impractical
 * (Swift can't produce a `KotlinKClass`). Use per-ViewModel Kotlin helpers instead,
 * e.g. `GreetingViewModelHelperKt.createGreetingViewModel(store: owner.viewModelStore)`.
 */
final class IosViewModelStoreOwner: ObservableObject, ViewModelStoreOwner {
    let viewModelStore: ViewModelStore = ViewModelStore()

    deinit {
        viewModelStore.clear()
        print("[IosViewModelStoreOwner] deinit cleared store")
    }
}

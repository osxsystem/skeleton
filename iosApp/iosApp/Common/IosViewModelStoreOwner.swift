import SkeletonKit          // D-15 / Pitfall 21: use the framework umbrella name, not the module name
import Foundation

/**
 * iOS lifecycle host for shared KMP ViewModels.
 *
 * RULES (D-12 / Pitfall 1 + 2):
 * - ALWAYS declare this as @StateObject in the parent SwiftUI View.
 *   Using the observed-object variant does not own the object; SwiftUI may discard and recreate it,
 *   destroying in-flight coroutines. @StateObject guarantees ownership for the lifetime of the view.
 * - deinit MUST call viewModelStore.clear() — this cancels all viewModelScope coroutines.
 *   Without this, coroutines keep running after the view is popped (silent memory leak).
 */
final class IosViewModelStoreOwner: ObservableObject, ViewModelStoreOwner {
    let viewModelStore: ViewModelStore = ViewModelStore()

    deinit {
        viewModelStore.clear()
        print("[IosViewModelStoreOwner] deinit cleared store")   // D-12: verify this fires on navigation pop
    }
}

extension IosViewModelStoreOwner {
    /**
     * Retrieves or creates a ViewModel of the given type from this store.
     *
     * Usage:
     *   let vm: MyViewModel = owner.viewModel(factory: MyViewModelFactoryKt.myViewModelFactory)
     */
    func viewModel<VM: ViewModel>(factory: ViewModelProvider.Factory) -> VM {
        ViewModelProvider(store: viewModelStore, factory: factory).get(modelClass: VM.self)
    }
}

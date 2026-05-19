import Foundation
import SkeletonKit

/// iOS lifecycle host for NumberInputViewModel within the Swift Package.
/// Mirrors IosViewModelStoreOwner in iosApp — same pattern, package-local copy.
final class NumberInputViewModelStoreOwner: ObservableObject, ViewModelStoreOwner {
    let viewModelStore: ViewModelStore = ViewModelStore()

    deinit {
        viewModelStore.clear()
    }
}

import SwiftUI
import Combine
import SkeletonKit

/// Observable bridge between SwiftUI and the Kotlin NumberInputViewModel.
/// Uses ObservableObject (not @Observable) because it integrates with a Kotlin
/// coroutine subscription — the published updates come from a Kotlin Job callback.
final class NumberInputBridge: ObservableObject {
    @Published private(set) var displayText: String = ""
    @Published private(set) var publishedValue: Double?
    @Published private(set) var clearDisabled: Bool = true
    @Published private(set) var signDisabled: Bool = true

    private let viewModel: NumberInputViewModel
    private let storeOwner: NumberInputViewModelStoreOwner
    private var subscriptionJob: (any Kotlinx_coroutines_coreJob)?

    init(initialValue: Double?, config: NumberInputConfig) {
        let formatter = LocaleNumberFormatter_iosKt.doNewLocaleNumberFormatter()
        let owner = NumberInputViewModelStoreOwner()
        self.storeOwner = owner
        self.viewModel = NumberInputViewModelHelperKt.createNumberInputViewModel(
            store: owner.viewModelStore,
            formatter: formatter,
            initialValue: initialValue.map { KotlinDouble(value: $0) },
            config: config
        )
        self.subscriptionJob = NumberInputViewModelHelperKt.subscribeNumberInputState(vm: viewModel) { [weak self] state in
            DispatchQueue.main.async {
                self?.apply(state: state)
            }
        }
    }

    deinit {
        subscriptionJob?.cancel(cause: nil)
    }

    /// Forward a user-typed string to the Kotlin VM. The VM re-formats and the resulting
    /// `formattedText` flows back through the StateFlow subscription into `displayText`.
    func userTyped(_ newRawText: String) {
        viewModel.onTextChange(newRawText: newRawText)
    }

    func handleFocus(focused: Bool) {
        viewModel.onFocusChanged(focused: focused)
    }

    func clear() {
        viewModel.onClear()
    }

    func toggleSign() {
        viewModel.onToggleSign()
    }

    func commit() {
        viewModel.onCommit()
    }

    private func apply(state: NumberInputUiState) {
        displayText = state.formattedText
        publishedValue = state.value?.doubleValue
        clearDisabled = state.rawText.isEmpty && state.value == nil
        signDisabled = !state.allowNegative || state.value == nil
    }
}

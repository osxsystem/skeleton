import SwiftUI
import Combine
import UIKit

/// Locale-aware numeric input field with keyboard toolbar (Done / Clear / ±).
/// Self-contained SwiftUI view that owns a pure-Swift `NumberInputViewModel`.
public struct NumberInputField: View {

    @Binding private var value: Double?
    private let placeholder: String
    private let fieldDecimalSeparator: String
    @StateObject private var vm: NumberInputViewModel
    @State private var focused: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.numberInputTheme) private var theme

    public init(
        value: Binding<Double?>,
        significantDigits: Int = 2,
        locale: Locale = .current,
        allowNegative: Bool = true,
        placeholder: String = ""
    ) {
        self._value = value
        self.placeholder = placeholder
        self.fieldDecimalSeparator = locale.decimalSeparator ?? "."
        self._vm = StateObject(wrappedValue: NumberInputViewModel(
            formatter: newLocaleNumberFormatter(),
            initialValue: value.wrappedValue,
            significantDigits: significantDigits,
            locale: locale.identifier,
            allowNegative: allowNegative
        ))
    }

    public var body: some View {
        let toolbar = makeToolbar()
        NumberInputUITextField(
            text: Binding(
                get: { vm.state.payload.formattedText },
                set: { vm.onTextChange($0) }
            ),
            focused: $focused,
            placeholder: placeholder,
            textColor: .label,
            placeholderColor: .secondaryLabel,
            tintColor: UIColor(theme.primaryColor),
            font: .systemFont(ofSize: 16),
            decimalSeparator: fieldDecimalSeparator,
            inputAccessoryView: toolbar
        )
        .frame(height: 44)
        .padding(.horizontal, theme.fieldPaddingH)
        .padding(.vertical, theme.fieldPaddingV)
        .background(theme.surfaceColor)
        .clipShape(.rect(cornerRadius: theme.fieldCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.fieldCornerRadius)
                .strokeBorder(focused ? theme.primaryColor : Color.clear, lineWidth: 1.5)
        )
        .accessibilityLabel(placeholder.isEmpty ? "Number input" : placeholder)
        .accessibilityHint("Double tap to enter a number")
        .accessibilityValue(vm.state.payload.formattedText.isEmpty ? "Empty" : vm.state.payload.formattedText)
        .onChange(of: focused) { isFocused in
            vm.onFocusChanged(focused: isFocused)
        }
        .onReceive(vm.$state) { newState in
            value = newState.payload.value
        }
    }

    // MARK: - Toolbar

    private func makeToolbar() -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.sizeToFit()

        let clear = UIBarButtonItem(title: "Clear", style: .plain, target: nil, action: nil)
        clear.accessibilityIdentifier = "numberInput.toolbar.clear"
        clear.accessibilityLabel = "Clear field"
        clear.primaryAction = UIAction(title: "Clear") { [weak vm] _ in vm?.onClear() }

        let sign = UIBarButtonItem(image: UIImage(systemName: "plus.slash.minus"), style: .plain, target: nil, action: nil)
        sign.accessibilityIdentifier = "numberInput.toolbar.toggleSign"
        sign.accessibilityLabel = "Toggle sign"
        sign.primaryAction = UIAction(image: UIImage(systemName: "plus.slash.minus")) { [weak vm] _ in vm?.onToggleSign() }

        let spacer = UIBarButtonItem(systemItem: .flexibleSpace)

        let done = UIBarButtonItem(title: "Done", style: .done, target: nil, action: nil)
        done.accessibilityIdentifier = "numberInput.toolbar.done"
        done.accessibilityLabel = "Done"
        done.primaryAction = UIAction(title: "Done") { [weak vm] _ in
            vm?.onCommit()
            // The `focused` state is owned by the parent View; resign is handled by the
            // UITextField coordinator responding to resignFirstResponder from the field.
        }

        toolbar.setItems([clear, sign, spacer, done], animated: false)

        // Sync enabled states from current VM state
        let payload = vm.state.payload
        clear.isEnabled = !payload.rawText.isEmpty || payload.value != nil
        sign.isEnabled = payload.allowNegative && payload.value != nil

        return toolbar
    }
}

import SwiftUI
import Combine
import UIKit

/// Locale-aware numeric input field with keyboard toolbar (Done / Clear / ±).
/// Self-contained SwiftUI view that owns a pure-Swift `NumberInputViewModel`.
public struct NumberInputField: View {

    @Binding private var value: Double?
    private let placeholder: String
    private let fieldDecimalSeparator: String
    private let significantDigits: Int
    private let textAlignment: NSTextAlignment
    private let font: UIFont
    private let textColor: UIColor
    private let chromeless: Bool
    @StateObject private var vm: NumberInputViewModel
    @State private var focused: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.numberInputTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    public init(
        value: Binding<Double?>,
        significantDigits: Int = 3,
        locale: Locale = .current,
        allowNegative: Bool = true,
        placeholder: String = "",
        textAlignment: NSTextAlignment = .natural,
        font: UIFont = .systemFont(ofSize: 16),
        textColor: UIColor = .label,
        chromeless: Bool = false
    ) {
        self._value = value
        self.placeholder = placeholder
        self.fieldDecimalSeparator = locale.decimalSeparator ?? "."
        self.significantDigits = significantDigits
        self.textAlignment = textAlignment
        self.font = font
        self.textColor = textColor
        self.chromeless = chromeless
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
        let field = NumberInputUITextField(
            text: Binding(
                get: { vm.state.payload.formattedText },
                set: { vm.onTextChange($0) }
            ),
            focused: $focused,
            placeholder: placeholder,
            textColor: textColor,
            placeholderColor: .secondaryLabel,
            tintColor: UIColor(theme.primaryColor),
            font: font,
            textAlignment: textAlignment,
            isEnabled: isEnabled,
            maxFractionDigits: significantDigits,
            decimalSeparator: fieldDecimalSeparator,
            inputAccessoryView: toolbar
        )

        styled(field)
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

    /// Applies the built-in field chrome (background, corner, focus border, fixed height).
    /// When `chromeless` is set, the bare text field is returned so the caller can supply
    /// its own border/background and sizing.
    @ViewBuilder
    private func styled(_ field: NumberInputUITextField) -> some View {
        if chromeless {
            field
        } else {
            field
                .frame(height: 44)
                .padding(.horizontal, theme.fieldPaddingH)
                .padding(.vertical, theme.fieldPaddingV)
                .background(theme.surfaceColor)
                .clipShape(RoundedRectangle(cornerRadius: theme.fieldCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.fieldCornerRadius)
                        .strokeBorder(focused ? theme.primaryColor : Color.clear, lineWidth: 1.5)
                )
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
            // Dismiss the keyboard. Resigning first responder makes the field's coordinator
            // fire `textFieldDidEndEditing`, which flips the parent's `focused` state to false.
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        toolbar.setItems([clear, sign, spacer, done], animated: false)

        // Sync enabled states from current VM state
        let payload = vm.state.payload
        clear.isEnabled = !payload.rawText.isEmpty || payload.value != nil
        sign.isEnabled = payload.allowNegative && payload.value != nil

        return toolbar
    }
}

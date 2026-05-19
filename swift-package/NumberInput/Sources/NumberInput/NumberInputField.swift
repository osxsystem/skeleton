import SwiftUI
import Combine
import SkeletonKit

/// Locale-aware numeric input field with keyboard toolbar (Done / Clear / ±).
/// Drop-in SwiftUI view that wraps a shared KMP NumberInputViewModel.
public struct NumberInputField: View {

    @Binding private var value: Double?
    private let placeholder: String
    @StateObject private var bridge: NumberInputBridge
    @FocusState private var focused: Bool
    @Environment(\.colorScheme) private var colorScheme

    public init(
        value: Binding<Double?>,
        significantDigits: Int = 2,
        locale: Locale = .current,
        allowNegative: Bool = true,
        placeholder: String = ""
    ) {
        self._value = value
        self.placeholder = placeholder
        let config = NumberInputConfig(
            significantDigits: Int32(significantDigits),
            locale: locale.identifier,
            allowNegative: allowNegative,
            placeholder: placeholder
        )
        self._bridge = StateObject(wrappedValue: NumberInputBridge(
            initialValue: value.wrappedValue,
            config: config
        ))
    }

    public var body: some View {
        let theme = NumberInputTheme.build(isDark: colorScheme == .dark)
        TextField(placeholder, text: bridge.textBinding(focused: focused))
            .keyboardType(.decimalPad)
            .focused($focused)
            .accessibilityIdentifier("numberInput.field")
            .accessibilityLabel(placeholder.isEmpty ? "Number input" : placeholder)
            .accessibilityHint("Double tap to enter a number")
            .accessibilityValue(bridge.displayText.isEmpty ? "Empty" : bridge.displayText)
            .padding(.horizontal, theme.fieldPaddingH)
            .padding(.vertical, theme.fieldPaddingV)
            .background(theme.surfaceColor)
            .clipShape(.rect(cornerRadius: theme.fieldCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.fieldCornerRadius)
                    .strokeBorder(focused ? theme.primaryColor : Color.clear, lineWidth: 1.5)
            )
            .toolbar { KeyboardToolbar(bridge: bridge, focused: $focused) }
            .onChange(of: focused) { isFocused in
                bridge.handleFocus(focused: isFocused)
            }
            .onReceive(bridge.$publishedValue) { newValue in
                value = newValue
            }
    }
}

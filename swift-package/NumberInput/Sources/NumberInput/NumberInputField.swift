import SwiftUI
import Combine
import UIKit
import SkeletonKit

/// Locale-aware numeric input field with keyboard toolbar (Done / Clear / ±).
/// Drop-in SwiftUI view that wraps a shared KMP NumberInputViewModel.
public struct NumberInputField: View {

    @Binding private var value: Double?
    private let placeholder: String
    private let fieldDecimalSeparator: String
    @StateObject private var bridge: NumberInputBridge
    @State private var focused: Bool = false
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
        self.fieldDecimalSeparator = locale.decimalSeparator ?? "."
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
        let toolbar = UIToolbarFactory.make(bridge: bridge) { focused = false }
        NumberInputUITextField(
            text: Binding(
                get: { bridge.displayText },
                set: { bridge.userTyped($0) }
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
        .accessibilityValue(bridge.displayText.isEmpty ? "Empty" : bridge.displayText)
        .onChange(of: focused) { isFocused in
            bridge.handleFocus(focused: isFocused)
        }
        .onReceive(bridge.$publishedValue) { newValue in
            value = newValue
        }
    }
}

/// Builds the `inputAccessoryView` UIToolbar with Clear / ± / Done buttons.
enum UIToolbarFactory {
    static func make(bridge: NumberInputBridge, onDone: @escaping () -> Void) -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.sizeToFit()

        let clear = UIBarButtonItem(title: "Clear", style: .plain, target: ToolbarTargets.shared, action: nil)
        clear.accessibilityIdentifier = "numberInput.toolbar.clear"
        clear.accessibilityLabel = "Clear field"
        clear.primaryAction = UIAction(title: "Clear") { _ in
            bridge.clear()
        }

        let sign = UIBarButtonItem(image: UIImage(systemName: "plus.slash.minus"), style: .plain, target: nil, action: nil)
        sign.accessibilityIdentifier = "numberInput.toolbar.toggleSign"
        sign.accessibilityLabel = "Toggle sign"
        sign.primaryAction = UIAction(image: UIImage(systemName: "plus.slash.minus")) { _ in
            bridge.toggleSign()
        }

        let spacer = UIBarButtonItem(systemItem: .flexibleSpace)

        let done = UIBarButtonItem(title: "Done", style: .done, target: nil, action: nil)
        done.accessibilityIdentifier = "numberInput.toolbar.done"
        done.accessibilityLabel = "Done"
        done.primaryAction = UIAction(title: "Done") { _ in
            bridge.commit()
            onDone()
        }

        toolbar.setItems([clear, sign, spacer, done], animated: false)
        // Reactive disabled-state subscriptions:
        ToolbarBindings.attach(bridge: bridge, clear: clear, sign: sign)
        return toolbar
    }
}

/// Placeholder for the legacy selector-based targets; the new code uses `primaryAction`.
private enum ToolbarTargets {
    static let shared: AnyObject? = nil
}

/// Keeps Combine subscriptions alive that sync `bridge.clearDisabled` / `bridge.signDisabled`
/// onto the corresponding `UIBarButtonItem.isEnabled`.
private enum ToolbarBindings {
    private static var subscriptions: [ObjectIdentifier: [AnyCancellable]] = [:]

    static func attach(bridge: NumberInputBridge, clear: UIBarButtonItem, sign: UIBarButtonItem) {
        let id = ObjectIdentifier(bridge)
        var bag: [AnyCancellable] = []
        bag.append(bridge.$clearDisabled.sink { clear.isEnabled = !$0 })
        bag.append(bridge.$signDisabled.sink { sign.isEnabled = !$0 })
        subscriptions[id] = bag
    }
}

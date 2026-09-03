#if canImport(UIKit)
import Combine
import SwiftUI

/// Locale-aware numeric input with live grouping and either the system decimal keyboard or the
/// opt-in built-in keypad.
///
/// The field owns its ``NumberInputState``. Changes flow out through `value`; parent-driven changes
/// flow back in only while the field is idle, so they cannot overwrite an in-progress edit.
public struct NumberInputField<LeadingAccessory: View>: View {
    @Binding private var value: Double?
    private let config: NumberInputConfig
    private let style: NumberInputStyle
    private let formatter: (any LocaleNumberFormatter)?
    private let accessibilityStrings: NumberInputAccessibilityStrings
    private let leadingAccessory: AnyView?
    private let onPrevious: (() -> Void)?
    private let onNext: (() -> Void)?
    private let focused: Binding<Bool>?

    /// Creates a field whose built-in-keypad toolbar starts with consumer-supplied SwiftUI content.
    /// The content is ignored on the system-keyboard path, where the accessory remains a native
    /// `UIToolbar`.
    ///
    /// Supply `focused` when a parent coordinates Previous and Next across multiple fields. When it
    /// is `nil`, the field keeps focus state internally as before.
    public init(
        value: Binding<Double?>,
        config: NumberInputConfig = NumberInputConfig(),
        style: NumberInputStyle = NumberInputStyle(),
        formatter: (any LocaleNumberFormatter)? = nil,
        accessibilityStrings: NumberInputAccessibilityStrings = NumberInputAccessibilityStrings(),
        onPrevious: (() -> Void)? = nil,
        onNext: (() -> Void)? = nil,
        focused: Binding<Bool>? = nil,
        @ViewBuilder leadingAccessory: () -> LeadingAccessory
    ) {
        self._value = value
        self.config = config
        self.style = style
        self.formatter = formatter
        self.accessibilityStrings = accessibilityStrings
        self.leadingAccessory = AnyView(leadingAccessory())
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.focused = focused
    }

    private init(
        value: Binding<Double?>,
        config: NumberInputConfig,
        style: NumberInputStyle,
        formatter: (any LocaleNumberFormatter)?,
        accessibilityStrings: NumberInputAccessibilityStrings,
        onPrevious: (() -> Void)?,
        onNext: (() -> Void)?,
        focused: Binding<Bool>?,
        leadingAccessory: AnyView?
    ) {
        self._value = value
        self.config = config
        self.style = style
        self.formatter = formatter
        self.accessibilityStrings = accessibilityStrings
        self.leadingAccessory = leadingAccessory
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.focused = focused
    }

    public var body: some View {
        NumberInputFieldCore(
            value: $value,
            config: config,
            style: style,
            formatter: formatter,
            accessibilityStrings: accessibilityStrings,
            leadingAccessory: leadingAccessory,
            onPrevious: onPrevious,
            onNext: onNext,
            focused: focused
        )
        // A config change changes parsing rules, not merely presentation. Giving the core a new
        // identity rebuilds its state instead of leaving an old locale or digit cap alive.
        .id(NumberInputConfigurationIdentity(config))
    }
}

public extension NumberInputField where LeadingAccessory == EmptyView {
    /// Creates a field without leading toolbar content. The previous and next controls remain
    /// optional and appear only when their corresponding callback is supplied.
    /// Supply `focused` for parent-controlled focus, or leave it `nil` for internal focus state.
    init(
        value: Binding<Double?>,
        config: NumberInputConfig = NumberInputConfig(),
        style: NumberInputStyle = NumberInputStyle(),
        formatter: (any LocaleNumberFormatter)? = nil,
        accessibilityStrings: NumberInputAccessibilityStrings = NumberInputAccessibilityStrings(),
        onPrevious: (() -> Void)? = nil,
        onNext: (() -> Void)? = nil,
        focused: Binding<Bool>? = nil
    ) {
        self.init(
            value: value,
            config: config,
            style: style,
            formatter: formatter,
            accessibilityStrings: accessibilityStrings,
            onPrevious: onPrevious,
            onNext: onNext,
            focused: focused,
            leadingAccessory: nil
        )
    }
}

private struct NumberInputFieldCore: View {
    @Binding private var value: Double?
    private let style: NumberInputStyle
    private let accessibilityStrings: NumberInputAccessibilityStrings
    private let leadingAccessory: AnyView?
    private let onPrevious: (() -> Void)?
    private let onNext: (() -> Void)?
    private let focused: Binding<Bool>?

    @StateObject private var state: NumberInputState
    @State private var localFocused = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    init(
        value: Binding<Double?>,
        config: NumberInputConfig,
        style: NumberInputStyle,
        formatter: (any LocaleNumberFormatter)?,
        accessibilityStrings: NumberInputAccessibilityStrings,
        leadingAccessory: AnyView?,
        onPrevious: (() -> Void)?,
        onNext: (() -> Void)?,
        focused: Binding<Bool>?
    ) {
        self._value = value
        self.style = style
        self.accessibilityStrings = accessibilityStrings
        self.leadingAccessory = leadingAccessory
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.focused = focused

        let resolvedFormatter: any LocaleNumberFormatter
        if let formatter {
            resolvedFormatter = formatter
        } else {
            resolvedFormatter = newLocaleNumberFormatter()
        }
        self._state = StateObject(
            wrappedValue: NumberInputState(
                formatter: resolvedFormatter,
                initialValue: value.wrappedValue,
                config: config
            )
        )
    }

    var body: some View {
        let resolvedStyle = resolveThemedColors(style, dark: colorScheme == .dark)
        let focusBinding = focused ?? $localFocused

        NumberInputUITextField(
            state: state,
            value: $value,
            focused: focusBinding,
            style: resolvedStyle,
            isEnabled: isEnabled,
            leadingAccessory: leadingAccessory,
            onPrevious: onPrevious,
            onNext: onNext
        )
        // Preserve the native field's minimum tap target while allowing Dynamic Type to grow it.
        .frame(minHeight: 44)
        .accessibilityLabel(accessibilityStrings.resolvedLabel(placeholder: state.config.placeholder))
        .accessibilityHint(accessibilityStrings.hint)
        .accessibilityValue(
            state.displayText.isEmpty ? accessibilityStrings.emptyValue : state.displayText
        )
        .onChange(of: value) { newValue in
            state.syncExternalValue(newValue)
        }
        .onReceive(state.$phase) { phase in
            guard case .idle = phase else { return }
            if value != state.value { value = state.value }
        }
    }
}

private struct NumberInputConfigurationIdentity: Hashable {
    let significantDigits: Int
    let locale: String
    let allowNegative: Bool
    let placeholder: String
    let useBuiltInKeypad: Bool
    let keypadHaptics: Bool

    init(_ config: NumberInputConfig) {
        self.significantDigits = config.significantDigits
        self.locale = config.locale
        self.allowNegative = config.allowNegative
        self.placeholder = config.placeholder
        self.useBuiltInKeypad = config.useBuiltInKeypad
        self.keypadHaptics = config.keypadHaptics
    }
}
#endif

import Foundation

/// Behavioural configuration for a number input.
///
/// Mirrors `NumberInputConfig` in the Compose `number-input` library, field for field.
public struct NumberInputConfig: Equatable {

    /// Fixed digits after the decimal point, padded with trailing zeros and rounded half-to-even.
    /// `0` makes the field integer-only and rejects the decimal separator outright. Range `0...9`.
    public let significantDigits: Int

    /// BCP-47 language tag used for separators and parsing.
    public let locale: String

    /// When `false`, a negative seed is clamped to `0.0`, sign toggling is a no-op, and the ±
    /// control is omitted from the toolbar entirely rather than shown greyed.
    public let allowNegative: Bool

    /// Shown when the field is empty, which is what distinguishes "not entered" from zero.
    public let placeholder: String

    /// Opt in to the library's own keypad instead of the system keyboard.
    ///
    /// Off by default, because the system keyboard is what users expect and it brings dictation,
    /// paste and every accessibility affordance the OS provides for free. Turning this on trades
    /// those away for two things the system keyboard cannot give: a decimal key that shows *this
    /// field's* separator rather than the device region's, and identical input on both platforms.
    ///
    /// On iOS the keypad is delivered as a `UITextField.inputView`, so it rides the native keyboard
    /// presentation and needs no host wrapper — unlike the Compose implementation, which has to be
    /// laid out at the bottom of the window by `NumberInputHost`.
    public let useBuiltInKeypad: Bool

    /// Fire a light haptic on each accepted built-in-keypad press.
    ///
    /// On by default: the keypad replaces the system keyboard, and a replacement that does not
    /// respond to touch reads as broken next to the one it stands in for. Ignored on the
    /// system-keyboard path, where the OS provides its own feedback. During a held backspace it
    /// fires once, on the initial press — at the repeat interval a tick per delete is a continuous
    /// buzz rather than feedback.
    public let keypadHaptics: Bool

    public init(
        significantDigits: Int = 3,
        locale: String = "en-US",
        allowNegative: Bool = true,
        placeholder: String = "",
        useBuiltInKeypad: Bool = false,
        keypadHaptics: Bool = true
    ) {
        precondition(
            (0...9).contains(significantDigits),
            "significantDigits must be in 0...9, got \(significantDigits)"
        )
        self.significantDigits = significantDigits
        self.locale = locale
        self.allowNegative = allowNegative
        self.placeholder = placeholder
        self.useBuiltInKeypad = useBuiltInKeypad
        self.keypadHaptics = keypadHaptics
    }
}

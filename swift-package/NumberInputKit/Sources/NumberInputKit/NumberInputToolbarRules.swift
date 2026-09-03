import Foundation

/// Enable/disable rules for the toolbar, kept free of any UI type so both the built-in keypad's own
/// top row and the system keyboard's `UIToolbar` accessory derive their item states from one place.
public enum NumberInputToolbarRules {

    /// "Clear" is offered whenever there is something to clear: text being typed or a committed value.
    public static func clearEnabled(rawText: String, value: Double?) -> Bool {
        !rawText.isEmpty || value != nil
    }

    /// "±" is offered only when negatives are allowed and there is a value to negate.
    public static func signEnabled(allowNegative: Bool, value: Double?) -> Bool {
        allowNegative && value != nil
    }

    /// "±" is *shown* only when negatives are allowed at all.
    ///
    /// Distinct from ``signEnabled(allowNegative:value:)``, which asks whether it is usable right
    /// now. With `allowNegative = false` the button could never become enabled for the life of the
    /// field, so it is omitted rather than greyed. The keypad's decimal key on an integer-only field
    /// is the opposite call, deliberately: greying it says "this field takes no fraction", where
    /// hiding it would leave a hole in a fixed grid.
    public static func signVisible(allowNegative: Bool) -> Bool { allowNegative }
}

/// Enable/disable rules for the built-in keypad, kept free of any UI type for the same reason.
///
/// A key that looks pressable and does nothing is the failure this prevents. Every rule here
/// mirrors a rejection `NumberInputState.onTextChange` would apply anyway, so the keypad greys out
/// exactly the keys that would be refused.
enum NumberInputKeypadRules {

    /// Digits are offered unless the fraction is already full. With no separator in the buffer there
    /// is no fraction to fill, so digits are always offered — the integer part is uncapped.
    static func digitEnabled(rawText: String, decimalSeparator: String, significantDigits: Int) -> Bool {
        guard !decimalSeparator.isEmpty, let sep = rawText.range(of: decimalSeparator) else { return true }
        let fractionDigits = rawText[sep.upperBound...].filter { $0.isASCIIDigit }.count
        return fractionDigits < significantDigits
    }

    /// The decimal key is offered once, and not at all on an integer-only field.
    ///
    /// `significantDigits == 0` rejects any separator outright, so the key would be dead on arrival;
    /// greying it out says so rather than letting the user press it and see nothing happen.
    static func decimalEnabled(rawText: String, decimalSeparator: String, significantDigits: Int) -> Bool {
        guard significantDigits > 0, !decimalSeparator.isEmpty else { return false }
        return !rawText.contains(decimalSeparator)
    }

    /// Backspace is offered while there is anything to delete.
    static func backspaceEnabled(rawText: String) -> Bool { !rawText.isEmpty }
}

extension Character {
    /// Kotlin's `it in '0'..'9'`. `Character.isNumber` also matches Arabic-Indic and other digit
    /// sets, which would let a fraction overrun the cap by counting characters the parser cannot
    /// use.
    var isASCIIDigit: Bool { self >= "0" && self <= "9" }
}

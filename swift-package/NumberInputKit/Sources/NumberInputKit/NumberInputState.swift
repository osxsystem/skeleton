import Combine
import Foundation

public enum NumberInputPhase {
    case idle
    case editing
}

/// Observable state and event handling for a number input.
///
/// A plain observable object rather than a screen view model: the component is a field, so it
/// carries no lifecycle dependency and can be held either by the field itself (the default) or
/// hoisted into a consumer's own view model.
///
/// State updates are synchronous — there is no hop between a keystroke and the resulting text, so
/// ordering is guaranteed and tests need no scheduler control.
///
/// `rawText` is **always ungrouped**, carrying this locale's decimal separator and nothing else.
/// Grouping is applied for display only, at the field boundary, by
/// ``LocaleNumberFormatter/formatLive(_:locale:)``.
public final class NumberInputState: ObservableObject {

    public let config: NumberInputConfig
    private let formatter: any LocaleNumberFormatter

    @Published public private(set) var value: Double?
    @Published public private(set) var rawText: String
    @Published public private(set) var phase: NumberInputPhase = .idle

    public init(
        formatter: any LocaleNumberFormatter = newLocaleNumberFormatter(),
        initialValue: Double? = nil,
        config: NumberInputConfig = NumberInputConfig()
    ) {
        self.formatter = formatter
        self.config = config
        let seed: Double? = {
            if !config.allowNegative, let v = initialValue, v < 0.0 { return 0.0 }
            return initialValue
        }()
        self.value = seed
        self.rawText = NumberInputState.plain(
            seed,
            formatter: formatter,
            significantDigits: config.significantDigits,
            locale: config.locale
        )
    }

    /// Distinguishes "not entered" from zero, which is what the placeholder renders.
    public var isEmpty: Bool { value == nil && rawText.isEmpty }

    public var clearEnabled: Bool {
        NumberInputToolbarRules.clearEnabled(rawText: rawText, value: value)
    }

    public var signEnabled: Bool {
        NumberInputToolbarRules.signEnabled(allowNegative: config.allowNegative, value: value)
    }

    /// The text the field should display: `rawText` with this locale's grouping applied.
    public var displayText: String {
        formatter.formatLive(rawText, locale: config.locale)
    }

    public func onFocusChanged(_ focused: Bool) {
        if focused {
            if phase != .editing { phase = .editing }
        } else {
            commit()
        }
    }

    public func onTextChange(_ rawInput: String) {
        guard let newRawText = resolveInput(rawInput) else { return }
        if exceedsFractionCap(newRawText) { return }
        if repeatsDecimalSeparator(newRawText) { return }

        let parsed = formatter.parse(newRawText, locale: config.locale)
        let next: Double?
        if newRawText.trimmingCharacters(in: .whitespaces).isEmpty {
            next = nil
        } else if let parsed {
            next = (!config.allowNegative && parsed < 0.0) ? value : parsed
        } else {
            next = value
        }
        value = next
        rawText = newRawText
        phase = .editing
    }

    // MARK: - Built-in keypad
    //
    // Every press routes through `onTextChange` rather than assigning `rawText` directly, which is
    // the whole point: the fraction cap, the repeated-separator guard and the keystroke filter
    // already live there, and a keypad that wrote the buffer itself would have to restate all three
    // and then keep them in step. A press is a keystroke that happens to originate in-process.

    /// The character the decimal key should show — this locale's separator, not whatever "."
    /// implies.
    public var decimalKeyLabel: String { formatter.decimalSeparator(locale: config.locale) }

    /// This locale's grouping separator. Read by the native field, whose buffer *is* grouped, to
    /// convert back to the ungrouped canonical form this state keeps.
    public var groupingSeparator: String { formatter.groupingSeparator(locale: config.locale) }

    public var digitEnabled: Bool {
        NumberInputKeypadRules.digitEnabled(
            rawText: rawText,
            decimalSeparator: decimalKeyLabel,
            significantDigits: config.significantDigits
        )
    }

    public var decimalEnabled: Bool {
        NumberInputKeypadRules.decimalEnabled(
            rawText: rawText,
            decimalSeparator: decimalKeyLabel,
            significantDigits: config.significantDigits
        )
    }

    public var backspaceEnabled: Bool {
        NumberInputKeypadRules.backspaceEnabled(rawText: rawText)
    }

    /// Append a digit. Ignored when the fraction is already full.
    public func pressDigit(_ digit: Int) {
        precondition((0...9).contains(digit), "digit must be in 0...9, got \(digit)")
        onTextChange(rawText + String(digit))
    }

    /// Append this locale's decimal separator.
    ///
    /// Appends the separator itself rather than a "." for the keystroke translation to convert: the
    /// keypad is in-process and already knows the locale, so there is no device region to disagree
    /// with. The translation still runs and is a no-op, since the character already matches.
    public func pressDecimalSeparator() {
        onTextChange(rawText + formatter.decimalSeparator(locale: config.locale))
    }

    /// Delete the last character — exactly one press per visible character, including the separator,
    /// so "1.5" goes to "1." and then to "1".
    public func pressBackspace() {
        guard !rawText.isEmpty else { return }
        let decSep = formatter.decimalSeparator(locale: config.locale)
        if !decSep.isEmpty, rawText.hasSuffix(decSep) {
            onTextChange(String(rawText.dropLast(decSep.count)))
        } else {
            onTextChange(String(rawText.dropLast()))
        }
    }

    // MARK: - Toolbar actions

    public func toggleSign() {
        guard config.allowNegative, let current = value else { return }
        let toggled = -current
        value = toggled
        rawText = plain(toggled)
        phase = .editing
    }

    public func clear() {
        value = nil
        rawText = ""
        phase = .editing
    }

    /// Canonicalise `rawText` from `value` and return to Idle. The only place trailing zeros are
    /// padded to the fixed fraction width.
    public func commit() {
        rawText = plain(value)
        phase = .idle
    }

    /// Re-seed from a value pushed by the parent (a network re-fetch, say). Ignored while the user
    /// is editing so an external push never clobbers an in-progress edit, and a no-op when the value
    /// already matches — which is what breaks the outward/inward binding loop.
    public func syncExternalValue(_ newValue: Double?) {
        guard phase != .editing else { return }
        let next = clampToAllowed(newValue)
        guard next != value else { return }
        value = next
        rawText = plain(next)
        phase = .idle
    }

    // MARK: - Private

    private func clampToAllowed(_ value: Double?) -> Double? {
        if !config.allowNegative, let v = value, v < 0.0 { return 0.0 }
        return value
    }

    /// Canonical *ungrouped* text for a value: formatted to `significantDigits` with the locale's
    /// decimal separator but no grouping separators.
    private func plain(_ value: Double?) -> String {
        NumberInputState.plain(
            value,
            formatter: formatter,
            significantDigits: config.significantDigits,
            locale: config.locale
        )
    }

    private static func plain(
        _ value: Double?,
        formatter: any LocaleNumberFormatter,
        significantDigits: Int,
        locale: String
    ) -> String {
        guard let value else { return "" }
        let grouping = formatter.groupingSeparator(locale: locale)
        let formatted = formatter.format(value, significantDigits: significantDigits, locale: locale)
        return grouping.isEmpty ? formatted : formatted.replacingOccurrences(of: grouping, with: "")
    }

    /// Resolve an incoming buffer to canonical ungrouped text, or `nil` to reject the edit and leave
    /// the field untouched.
    ///
    /// One keystroke is resolved by *what* arrived; anything longer has to be resolved by *where*
    /// its separators sit, so the two take different paths. A paste, dictation result, autocomplete,
    /// or any input method that delivers a whole number at once lands on the second.
    private func resolveInput(_ rawInput: String) -> String? {
        let decSep = formatter.decimalSeparator(locale: config.locale)
        guard !decSep.isEmpty else { return rawInput }

        let inserted = insertion(rawInput, rawText)
        if let inserted, inserted.text.count > 1 {
            guard let interpreted = interpretWholeNumber(
                rawInput,
                decimalSeparator: decSep,
                groupingSeparator: formatter.groupingSeparator(locale: config.locale)
            ) else { return nil }
            return dropRedundantFractionZeros(interpreted, decSep)
        }

        if let inserted, !isNumericKeystroke(inserted.text, decSep) { return nil }
        return substituteInsertedDecimalKey(rawInput, rawText, decSep)
    }

    /// True when a single inserted character is one a number can contain: a digit, either decimal
    /// key, or the minus sign.
    ///
    /// A whole number that arrives at once is already validated by `interpretWholeNumber`, so a
    /// pasted "abc" is refused. A *typed* letter has to be too, or the two paths disagree on
    /// identical characters — and a numeric field would briefly display a letter while `rawText`
    /// held text that is not canonical numeric text.
    ///
    /// Minus is permitted anywhere rather than only at the start: where a sign is *valid* is the
    /// parser's business, and mid-buffer text is transient while the user is still typing.
    private func isNumericKeystroke(_ inserted: String, _ decimalSeparator: String) -> Bool {
        // Only a single character is judged here; anything longer took the whole-number path, and a
        // deletion has no insertion to judge.
        guard inserted.count == 1, let c = inserted.first else { return true }
        if c.isASCIIDigit || c == "-" { return true }
        return decimalKeyCandidates.contains(inserted) || inserted == decimalSeparator
    }

    /// Drop fraction digits past `significantDigits` while they are zeros, and the separator too if
    /// nothing is left after it.
    ///
    /// A number that arrives whole carries the precision of wherever it was copied from, which need
    /// not match this field's. `1.500` pasted into a two-digit field would otherwise be refused for
    /// overflowing the cap by one digit — even though `1.500` and `1.50` are the same number.
    ///
    /// Only zeros are dropped. Trimming `1.567` to `1.56` would change the value the user supplied,
    /// so that still fails the cap and is rejected, visibly.
    private func dropRedundantFractionZeros(_ text: String, _ decimalSeparator: String) -> String {
        let chars = Array(text)
        guard let decRange = text.range(of: decimalSeparator) else { return text }
        let decIdx = text.distance(from: text.startIndex, to: decRange.lowerBound)
        let fractionStart = decIdx + decimalSeparator.count

        var end = chars.count
        while end - fractionStart > config.significantDigits && chars[end - 1] == "0" { end -= 1 }
        return end == fractionStart ? String(chars[0..<decIdx]) : String(chars[0..<end])
    }

    /// True when `newRawText` carries a second decimal separator. ``exceedsFractionCap(_:)`` counts
    /// only the digits following the *first* one, so "1.2.3" clears the cap, fails to parse, and
    /// would be stored anyway — leaving `rawText` holding text that no `value` corresponds to and
    /// that `commit()` cannot round-trip. A field accepts one separator or none.
    private func repeatsDecimalSeparator(_ newRawText: String) -> Bool {
        let decSep = formatter.decimalSeparator(locale: config.locale)
        guard !decSep.isEmpty, let first = newRawText.range(of: decSep) else { return false }
        return newRawText.range(of: decSep, range: first.upperBound..<newRawText.endIndex) != nil
    }

    /// True when `newRawText` carries more fraction digits than allowed. With
    /// `significantDigits = 0` the field is integer-only, so any decimal separator is rejected
    /// outright.
    private func exceedsFractionCap(_ newRawText: String) -> Bool {
        let decSep = formatter.decimalSeparator(locale: config.locale)
        guard !decSep.isEmpty, let sep = newRawText.range(of: decSep) else { return false }
        if config.significantDigits == 0 { return true }
        let fractionDigits = newRawText[sep.upperBound...].filter { $0.isASCIIDigit }.count
        return fractionDigits > config.significantDigits
    }
}

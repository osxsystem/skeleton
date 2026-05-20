import Foundation
import Combine

/// Pure-Swift port of the Kotlin `NumberInputViewModel`.
/// Owns all state as `@Published var state: NumberInputUIState`. Methods are synchronous —
/// no coroutines. State transitions are identical to the Kotlin VM.
public final class NumberInputViewModel: ObservableObject {

    @Published public private(set) var state: NumberInputUIState

    private let formatter: any LocaleNumberFormatter
    private let significantDigits: Int
    private let locale: String
    private let allowNegative: Bool

    public init(
        formatter: any LocaleNumberFormatter = newLocaleNumberFormatter(),
        initialValue: Double? = nil,
        config: NumberInputConfig = NumberInputConfig()
    ) {
        self.formatter = formatter
        self.significantDigits = config.significantDigits
        self.locale = config.locale
        self.allowNegative = config.allowNegative

        // AC-08: clamp negative initialValue to 0.0 when allowNegative=false
        let seedValue: Double? = {
            if !config.allowNegative, let v = initialValue, v < 0.0 { return 0.0 }
            return initialValue
        }()

        let formattedText = seedValue.map { formatter.format($0, significantDigits: config.significantDigits, locale: config.locale) } ?? ""
        let rawText = formattedText
        self.state = .idle(NumberInputUIState.Payload(
            rawText: rawText,
            formattedText: formattedText,
            value: seedValue,
            significantDigits: config.significantDigits,
            locale: config.locale,
            allowNegative: config.allowNegative
        ))
    }

    /// Convenience init matching the Kotlin VM signature (individual parameters).
    public init(
        formatter: any LocaleNumberFormatter = newLocaleNumberFormatter(),
        initialValue: Double? = nil,
        significantDigits: Int = 2,
        locale: String = "en-US",
        allowNegative: Bool = true
    ) {
        self.formatter = formatter
        self.significantDigits = significantDigits
        self.locale = locale
        self.allowNegative = allowNegative

        let seedValue: Double? = {
            if !allowNegative, let v = initialValue, v < 0.0 { return 0.0 }
            return initialValue
        }()

        let formattedText = seedValue.map { formatter.format($0, significantDigits: significantDigits, locale: locale) } ?? ""
        self.state = .idle(NumberInputUIState.Payload(
            rawText: formattedText,
            formattedText: formattedText,
            value: seedValue,
            significantDigits: significantDigits,
            locale: locale,
            allowNegative: allowNegative
        ))
    }

    public func onFocusChanged(focused: Bool) {
        if focused {
            guard case .editing = state else {
                // Enter Editing, carrying the locale-correct formatted form
                let carry = state.payload.formattedText
                state = .editing(payload(rawText: carry, formattedText: carry, value: state.payload.value))
                return
            }
        } else {
            commitAndSetIdle()
        }
    }

    public func onTextChange(_ newRawText: String) {
        let current = state.payload
        let parsed = formatter.parse(newRawText, locale: locale)
        let newValue: Double?
        if newRawText.isEmpty || newRawText == "-" {
            newValue = newRawText.isEmpty ? nil : current.value
        } else if let p = parsed {
            newValue = (!allowNegative && p < 0.0) ? current.value : p
        } else {
            // parse failed on non-blank: keep prior value
            newValue = current.value
        }
        let formattedText = formatter.formatLive(newRawText, locale: locale)
        state = .editing(payload(rawText: newRawText, formattedText: formattedText, value: newValue))
    }

    public func onToggleSign() {
        guard allowNegative else { return }
        guard let currentValue = state.payload.value else { return }
        let toggled = -currentValue
        let newRawText = formatter.format(toggled, significantDigits: significantDigits, locale: locale)
        state = .editing(payload(rawText: newRawText, formattedText: newRawText, value: toggled))
    }

    public func onClear() {
        state = .editing(payload(rawText: "", formattedText: "", value: nil))
    }

    public func onCommit() {
        commitAndSetIdle()
    }

    // MARK: - Private

    private func commitAndSetIdle() {
        let current = state.payload
        let formatted = current.value.map { formatter.format($0, significantDigits: significantDigits, locale: locale) } ?? ""
        let committedPayload = NumberInputUIState.Payload(
            rawText: current.rawText,
            formattedText: formatted,
            value: current.value,
            significantDigits: significantDigits,
            locale: locale,
            allowNegative: allowNegative
        )
        // Emit Committed, then immediately Idle — matches Kotlin VM ordering.
        state = .committed(committedPayload)
        state = .idle(committedPayload)
    }

    private func payload(rawText: String, formattedText: String, value: Double?) -> NumberInputUIState.Payload {
        NumberInputUIState.Payload(
            rawText: rawText,
            formattedText: formattedText,
            value: value,
            significantDigits: significantDigits,
            locale: locale,
            allowNegative: allowNegative
        )
    }
}

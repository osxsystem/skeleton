import Foundation

/// Apple-platform implementation of ``LocaleNumberFormatter``, backed by `NumberFormatter`.
/// Two-pass parse: formatter first, then stripped-double fallback.
///
/// `NumberFormatter` is expensive to construct, so one is cached per locale and reused. Each method
/// sets the full set of properties it depends on (fraction digits, grouping) so the shared instance
/// cannot leak one operation's configuration into another. Not thread-safe; intended for
/// main-thread use behind the field's state.
public final class IosLocaleNumberFormatter: LocaleNumberFormatter {

    private var cache: [String: NumberFormatter] = [:]

    public init() {}

    private func formatter(for locale: String) -> NumberFormatter {
        if let cached = cache[locale] { return cached }
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: locale)
        nf.numberStyle = .decimal
        cache[locale] = nf
        return nf
    }

    public func format(_ value: Double, significantDigits: Int, locale: String) -> String {
        let nf = formatter(for: locale)
        nf.usesGroupingSeparator = true
        nf.minimumFractionDigits = significantDigits
        nf.maximumFractionDigits = significantDigits
        nf.roundingMode = .halfEven
        return nf.string(from: NSNumber(value: value)) ?? ""
    }

    public func parse(_ rawText: String, locale: String) -> Double? {
        let trimmed = rawText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let nf = formatter(for: locale)
        nf.usesGroupingSeparator = true
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 20

        // Pass 1: NumberFormatter, which handles grouping separators natively.
        if let n = nf.number(from: trimmed) { return n.doubleValue }

        // Pass 2: strip grouping, normalise the decimal separator, try Double parsing.
        let normalised = trimmed
            .replacingOccurrences(of: nf.groupingSeparator ?? ",", with: "")
            .replacingOccurrences(of: nf.decimalSeparator ?? ".", with: ".")
        return Double(normalised)
    }

    public func formatLive(_ rawText: String, locale: String) -> String {
        guard !rawText.isEmpty else { return "" }

        let nf = formatter(for: locale)
        nf.usesGroupingSeparator = true
        // The grouping closure only formats integer digits — suppress any fraction digits a prior
        // `format(_:significantDigits:locale:)` call may have left on the shared instance.
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 0

        let groupSep = nf.groupingSeparator ?? ","
        let decSep = nf.decimalSeparator ?? "."

        return liveFormat(rawText, groupingSeparator: groupSep, decimalSeparator: decSep) { digits in
            guard let n = Int64(digits) else { return digits }
            return nf.string(from: NSNumber(value: n)) ?? digits
        }
    }

    public func decimalSeparator(locale: String) -> String {
        formatter(for: locale).decimalSeparator ?? "."
    }

    public func groupingSeparator(locale: String) -> String {
        formatter(for: locale).groupingSeparator ?? ","
    }
}

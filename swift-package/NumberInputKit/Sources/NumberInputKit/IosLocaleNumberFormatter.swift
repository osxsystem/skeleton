import Foundation

/// iOS implementation of `LocaleNumberFormatter` backed by `Foundation.NumberFormatter`.
/// Two-pass parse: formatter first, then stripped-double fallback (matches Kotlin iOS impl).
public final class IosLocaleNumberFormatter: LocaleNumberFormatter {

    public init() {}

    public func format(_ value: Double, significantDigits: Int, locale: String) -> String {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: locale)
        nf.numberStyle = .decimal
        nf.usesGroupingSeparator = true
        nf.minimumFractionDigits = significantDigits
        nf.maximumFractionDigits = significantDigits
        nf.roundingMode = .halfEven
        return nf.string(from: NSNumber(value: value)) ?? ""
    }

    public func parse(_ rawText: String, locale: String) -> Double? {
        let trimmed = rawText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let nf = NumberFormatter()
        nf.locale = Locale(identifier: locale)
        nf.numberStyle = .decimal

        // Pass 1: use NumberFormatter (handles grouping separators natively)
        if let n = nf.number(from: trimmed) {
            return n.doubleValue
        }

        // Pass 2: strip grouping, normalise decimal, try Double parsing
        let groupSep = nf.groupingSeparator ?? ","
        let decSep = nf.decimalSeparator ?? "."
        let normalised = trimmed
            .replacingOccurrences(of: groupSep, with: "")
            .replacingOccurrences(of: decSep, with: ".")
        return Double(normalised)
    }

    public func formatLive(_ rawText: String, locale: String) -> String {
        guard !rawText.isEmpty else { return "" }

        let nf = NumberFormatter()
        nf.locale = Locale(identifier: locale)
        nf.numberStyle = .decimal
        nf.usesGroupingSeparator = true

        let groupSep = nf.groupingSeparator ?? ","
        let decSep = nf.decimalSeparator ?? "."

        return liveFormat(rawText, groupingSeparator: groupSep, decimalSeparator: decSep) { digits in
            guard let n = Int64(digits) else { return digits }
            return nf.string(from: NSNumber(value: n)) ?? digits
        }
    }
}

/// Public factory matching the Kotlin `newLocaleNumberFormatter()` pattern.
public func newLocaleNumberFormatter() -> any LocaleNumberFormatter {
    IosLocaleNumberFormatter()
}

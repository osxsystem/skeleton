import Foundation

/// Locale-aware number formatter contract. Implemented by `IosLocaleNumberFormatter`.
/// Declared as a protocol so tests can supply a `FakeLocaleNumberFormatter` trivially.
public protocol LocaleNumberFormatter {
    /// Format `value` for display with exactly `significantDigits` digits after the decimal point.
    func format(_ value: Double, significantDigits: Int, locale: String) -> String

    /// Parse a user-typed `rawText` into a `Double` using `locale`'s decimal separator.
    /// Returns `nil` if `rawText` is empty or unparseable.
    func parse(_ rawText: String, locale: String) -> Double?

    /// Live-format `rawText` during editing: group the integer portion, preserve decimal-and-after
    /// verbatim, preserve a leading "-". Idempotent.
    func formatLive(_ rawText: String, locale: String) -> String
}

/// Shared helper implementing the `formatLive` algorithm. Each formatter supplies its locale's
/// grouping and decimal separators, plus a closure that groups a pure-digit integer string.
public func liveFormat(
    _ rawText: String,
    groupingSeparator: String,
    decimalSeparator: String,
    groupIntegerDigits: (String) -> String
) -> String {
    guard !rawText.isEmpty else { return "" }

    let negative = rawText.hasPrefix("-")
    let unsigned = negative ? String(rawText.dropFirst()) : rawText
    let sign = negative ? "-" : ""

    let stripped = groupingSeparator.isEmpty ? unsigned : unsigned.replacingOccurrences(of: groupingSeparator, with: "")
    let decIdx = decimalSeparator.isEmpty ? nil : stripped.range(of: decimalSeparator)

    let intPart: String
    let decPart: String
    if let idx = decIdx {
        intPart = String(stripped[stripped.startIndex..<idx.lowerBound])
        decPart = String(stripped[idx.lowerBound...])
    } else {
        intPart = stripped
        decPart = ""
    }

    let intDigits = intPart.filter { $0.isNumber }
    let groupedInt = intDigits.isEmpty ? "" : groupIntegerDigits(intDigits)
    return sign + groupedInt + decPart
}

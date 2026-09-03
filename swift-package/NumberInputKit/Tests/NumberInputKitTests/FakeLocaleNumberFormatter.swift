import Foundation
@testable import NumberInputKit

/// Test double for `LocaleNumberFormatter`. Deterministic, no `NumberFormatter` dependency.
/// Mirrors `FakeLocaleNumberFormatter.kt` — same separator table, same grouping algorithm.
struct FakeLocaleNumberFormatter: LocaleNumberFormatter {

    private func separators(locale: String) -> (grouping: String, decimal: String) {
        switch locale {
        case "vi-VN", "de-DE": return (".", ",")
        default:                return (",", ".")
        }
    }

    func format(_ value: Double, significantDigits: Int, locale: String) -> String {
        let (groupSep, decSep) = separators(locale: locale)
        let sign = value < 0.0 ? "-" : ""
        let abs = Swift.abs(value)
        let multiplier = pow10(significantDigits)
        let rounded = (abs * multiplier).rounded() / multiplier
        let intPart = Int64(rounded)
        let groupedInt = groupDigits(String(intPart), groupSep: groupSep)
        let fracStr: String
        if significantDigits == 0 {
            fracStr = ""
        } else {
            let fracValue = Int64(((rounded - Double(intPart)) * multiplier).rounded())
            fracStr = decSep + String(fracValue).leftPadded(to: significantDigits)
        }
        return sign + groupedInt + fracStr
    }

    func parse(_ rawText: String, locale: String) -> Double? {
        let trimmed = rawText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let (groupSep, decSep) = separators(locale: locale)
        let normalised = trimmed
            .replacingOccurrences(of: groupSep, with: "")
            .replacingOccurrences(of: decSep, with: ".")
        return Double(normalised)
    }

    func decimalSeparator(locale: String) -> String { separators(locale: locale).decimal }

    func groupingSeparator(locale: String) -> String { separators(locale: locale).grouping }

    func formatLive(_ rawText: String, locale: String) -> String {
        let (groupSep, decSep) = separators(locale: locale)
        return liveFormat(rawText, groupingSeparator: groupSep, decimalSeparator: decSep) { digits in
            guard let n = Int64(digits) else { return digits }
            return groupDigits(String(n), groupSep: groupSep)
        }
    }

    // MARK: - Helpers

    private func groupDigits(_ digits: String, groupSep: String) -> String {
        guard digits.count > 3 else { return digits }
        var result = ""
        let rev = String(digits.reversed())
        for (i, ch) in rev.enumerated() {
            if i > 0 && i % 3 == 0 { result.append(groupSep) }
            result.append(ch)
        }
        return String(result.reversed())
    }

    private func pow10(_ n: Int) -> Double {
        var r = 1.0
        for _ in 0..<n { r *= 10.0 }
        return r
    }
}

private extension String {
    func leftPadded(to length: Int) -> String {
        guard count < length else { return self }
        return String(repeating: "0", count: length - count) + self
    }
}

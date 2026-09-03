import Foundation

/// Locale-aware number formatting seam.
///
/// Public and injectable on purpose: consumers with an existing locale strategy can supply their
/// own implementation rather than inheriting this library's platform formatter. That matters when a
/// codebase already renders numbers its own way — mixing two strategies in one app produces visibly
/// inconsistent separators.
public protocol LocaleNumberFormatter {
    /// Format `value` with exactly `significantDigits` digits after the decimal point, rounded
    /// half-to-even, with grouping separators.
    func format(_ value: Double, significantDigits: Int, locale: String) -> String

    /// Parse `rawText` into a `Double` using `locale`'s separators. `nil` when it is empty or
    /// unparseable.
    func parse(_ rawText: String, locale: String) -> Double?

    /// Live-format `rawText` during editing: group the integer portion, preserve decimal-and-after
    /// verbatim, preserve a leading "-". Idempotent.
    func formatLive(_ rawText: String, locale: String) -> String

    func decimalSeparator(locale: String) -> String
    func groupingSeparator(locale: String) -> String
}

/// The platform formatter. Named to match the Kotlin `newLocaleNumberFormatter()` factory.
public func newLocaleNumberFormatter() -> any LocaleNumberFormatter {
    IosLocaleNumberFormatter()
}

/// Shared live-grouping algorithm. Each formatter supplies its locale's separators and an
/// integer-grouping function; the digit/sign/decimal splitting is identical everywhere.
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

    let stripped = groupingSeparator.isEmpty
        ? unsigned
        : unsigned.replacingOccurrences(of: groupingSeparator, with: "")
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

    let intDigits = intPart.filter { $0.isASCIIDigit }
    let groupedInt = intDigits.isEmpty ? "" : groupIntegerDigits(intDigits)
    return sign + groupedInt + decPart
}

// MARK: - Keystroke resolution

/// The characters a numeric keyboard may offer as its decimal key.
///
/// Latin-only by design, covering the "." / "," disagreement that Latin-script regions produce. A
/// device region whose decimal key is neither — Arabic-Indic "٫" (U+066B), say — is *not*
/// translated; that limitation is inherited from the Compose library rather than introduced here.
let decimalKeyCandidates: Set<String> = [".", ","]

/// The characters one edit added to a buffer, and where they landed.
struct Insertion {
    let text: String
    let start: Int
    let endExclusive: Int
}

/// The part of `newText` that `previousText` does not account for — the characters just inserted.
/// `nil` when nothing was inserted, which covers both an unchanged buffer and a deletion.
///
/// Isolating the insertion by common prefix and suffix means the caret's position does not matter:
/// an edit in the middle of the buffer is located as precisely as one at the end.
func insertion(_ newText: String, _ previousText: String) -> Insertion? {
    let new = Array(newText)
    let old = Array(previousText)

    var prefix = 0
    while prefix < new.count, prefix < old.count, new[prefix] == old[prefix] { prefix += 1 }

    let maxSuffix = max(0, min(new.count, old.count) - prefix)
    var suffix = 0
    while suffix < new.count, suffix < old.count,
          new[new.count - 1 - suffix] == old[old.count - 1 - suffix] { suffix += 1 }
    suffix = min(suffix, maxSuffix)

    let end = new.count - suffix
    guard end > prefix else { return nil }
    return Insertion(text: String(new[prefix..<end]), start: prefix, endExclusive: end)
}

/// Diff `newText` against the `previousText` it replaced to isolate the characters just inserted;
/// if that insertion is a lone decimal-key character, return `newText` with it swapped for
/// `decimalSeparator`. Any other edit — a digit, a deletion, a multi-character paste — is returned
/// untouched.
///
/// The keyboard's decimal key follows the *device* region, not the field's locale, and the system
/// decimal pad offers no per-field override. So a field may be handed either of
/// ``decimalKeyCandidates`` as the decimal keystroke however it is configured, and has to translate
/// whichever arrived before it can be parsed.
func substituteInsertedDecimalKey(
    _ newText: String,
    _ previousText: String,
    _ decimalSeparator: String
) -> String {
    guard let inserted = insertion(newText, previousText) else { return newText }
    guard decimalKeyCandidates.contains(inserted.text) else { return newText }
    guard inserted.text != decimalSeparator else { return newText }
    let chars = Array(newText)
    return String(chars[0..<inserted.start]) + decimalSeparator + String(chars[inserted.endExclusive...])
}

// MARK: - Whole-number interpretation

/// Interpret a whole number that arrived at once — a paste, dictation, or an autocomplete — and
/// return it in the ungrouped canonical form `rawText` expects, or `nil` to reject it.
///
/// A keystroke can be resolved by *what* was inserted, since a single character is either a digit
/// or a separator. A multi-character insertion cannot: which of its separators is decimal and which
/// are grouping is a property of *where* they sit. `1,234` and `1,23` differ only in a trailing
/// digit, yet the first is one thousand two hundred and thirty-four and the second is one and
/// twenty-three hundredths.
///
/// There are only ever two readings: either every separator is grouping, or the last one is a
/// decimal point and the rest are grouping. Which to try first is decided by the field's own
/// convention, and the other is still tried when the preferred one does not hold up structurally.
/// Text that holds up under neither is rejected rather than coerced — refusing leaves the field
/// untouched, which the user can see and correct; the alternative is silently committing a value
/// they never supplied.
func interpretWholeNumber(
    _ text: String,
    decimalSeparator: String,
    groupingSeparator: String
) -> String? {
    // An empty buffer is a legitimately empty field. Text that is *only* whitespace is not — it is
    // unparseable, and clearing a real value because someone pasted a stray space would lose data
    // they never asked to discard.
    if text.isEmpty { return "" }
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return nil }

    let negative = trimmed.hasPrefix("-")
    let body = Array(negative ? String(trimmed.dropFirst()) : trimmed)
    if body.isEmpty { return nil }

    var separatorChars = Set<Character>()
    for candidate in decimalKeyCandidates where candidate.count == 1 {
        separatorChars.insert(candidate.first!)
    }
    if groupingSeparator.count == 1 { separatorChars.insert(groupingSeparator.first!) }

    // Anything that is neither a digit nor a known separator makes this not a number at all.
    if body.contains(where: { !$0.isASCIIDigit && !separatorChars.contains($0) }) { return nil }

    let positions = body.indices.filter { separatorChars.contains(body[$0]) }
    let sign = negative ? "-" : ""

    if positions.isEmpty { return sign + String(body) }

    let lastSeparator = positions[positions.count - 1]
    // The field's own convention decides which reading to try first: a last separator that is this
    // locale's decimal separator most likely means one.
    let preferDecimal = String(body[lastSeparator]) == decimalSeparator

    let readings: [Int?] = preferDecimal ? [lastSeparator, nil] : [nil, lastSeparator]
    for decimalAt in readings {
        if let resolved = resolveWholeNumber(
            body: body,
            positions: positions,
            decimalAt: decimalAt,
            sign: sign,
            decimalSeparator: decimalSeparator
        ) {
            return resolved
        }
    }
    return nil
}

/// Split `body` at `decimalAt` (or treat it as all integer when `nil`), validate the separators left
/// in the integer part as grouping, and assemble canonical ungrouped text. `nil` when the split does
/// not describe a number.
private func resolveWholeNumber(
    body: [Character],
    positions: [Int],
    decimalAt: Int?,
    sign: String,
    decimalSeparator: String
) -> String? {
    let integerBody = decimalAt.map { Array(body[0..<$0]) } ?? body
    let fraction = decimalAt.map { Array(body[($0 + 1)...]) } ?? []

    if fraction.contains(where: { !$0.isASCIIDigit }) { return nil }

    let groupPositions = decimalAt == nil ? positions : Array(positions.dropLast())
    // One character cannot be both the decimal point and the grouping separator in the same number.
    // This is what stops "1.234.567" being read as 1234.567 in an en-US field.
    if let decimalAt, groupPositions.contains(where: { body[$0] == body[decimalAt] }) { return nil }
    if !isValidGrouping(integerBody, groupPositions) { return nil }

    let integerDigits = String(integerBody.filter { $0.isASCIIDigit })
    if integerDigits.isEmpty && fraction.isEmpty { return nil }

    if fraction.isEmpty { return sign + integerDigits }
    return sign + integerDigits + decimalSeparator + String(fraction)
}

/// True when the separators at `positions` within `integerBody` all sit on grouping boundaries: one
/// to three digits before the first, exactly three between each pair and after the last. A single
/// unseparated run of digits is trivially valid. All of them must also be the same character —
/// `1,234.567` mixes two separators in one integer part and is malformed however it is read.
private func isValidGrouping(_ integerBody: [Character], _ positions: [Int]) -> Bool {
    if positions.isEmpty { return integerBody.allSatisfy { $0.isASCIIDigit } }
    if Set(positions.map { integerBody[$0] }).count > 1 { return false }

    var groups: [[Character]] = []
    var start = 0
    for p in positions {
        groups.append(Array(integerBody[start..<p]))
        start = p + 1
    }
    groups.append(Array(integerBody[start...]))

    if groups.contains(where: { $0.isEmpty || $0.contains { !$0.isASCIIDigit } }) { return false }
    if !(1...3).contains(groups[0].count) { return false }
    return groups.dropFirst().allSatisfy { $0.count == 3 }
}

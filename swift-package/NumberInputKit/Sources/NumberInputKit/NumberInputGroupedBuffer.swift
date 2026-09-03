import Foundation

/// Convert a native field's *grouped* buffer into the ungrouped form ``NumberInputState`` expects.
///
/// On a locale whose grouping separator is "." — de-DE, vi-VN — the "." the decimal keypad emits is
/// indistinguishable from the separators the field inserted for display, so stripping the grouping
/// separator outright also swallows a decimal point the user just typed. The fraction then merges
/// into the integer part and the value silently grows by an order of magnitude: typing `25500.8`
/// into a de-DE field yielded `255008`, redisplayed as `255.008`.
///
/// ``NumberInputState`` already translates a keypad "." into the locale separator, but it only ever
/// sees an ungrouped buffer, so on the native-field path the ambiguity has to be resolved *before*
/// ungrouping — here, against `previousDisplay`, the text the field last wrote.
func ungroupTypedText(
    grouped: String,
    previousDisplay: String,
    groupingSeparator: String,
    decimalSeparator: String
) -> String {
    guard !groupingSeparator.isEmpty else { return grouped }
    // A multi-character insertion — paste, dictation, autocomplete — is a whole number that only
    // NumberInputState can interpret, because which of its separators is decimal depends on where
    // they sit. Stripping here would destroy that evidence first: a pasted "1234,5" would arrive as
    // "12345". Hand it over untouched instead.
    if let inserted = insertion(grouped, previousDisplay), inserted.text.count > 1 { return grouped }
    // Runs for every locale: the inserted key may be this locale's grouping separator (a "," typed
    // into an en-US field on a ","-region device), which the strip below would otherwise discard.
    // Substituting before stripping is what preserves it — the order matters.
    let disambiguated = substituteInsertedDecimalKey(grouped, previousDisplay, decimalSeparator)
    return disambiguated.replacingOccurrences(of: groupingSeparator, with: "")
}

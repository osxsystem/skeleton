package dev.viethung.components.numberinput

/**
 * Locale-aware number formatter contract. Implemented per platform via [newLocaleNumberFormatter].
 * Declared as `interface` (not `expect class`) so commonTest can supply a `FakeLocaleNumberFormatter`
 * trivially — see Validation Summary decision #1 and §8.1.
 */
interface LocaleNumberFormatter {
    /**
     * Format [value] for display with exactly [significantDigits] digits after the decimal point.
     * @param locale BCP-47 tag (e.g. "en-US"). Falls back to platform default if blank.
     * @return formatted string per locale's grouping + decimal symbols + half-even rounding.
     */
    fun format(value: Double, significantDigits: Int, locale: String): String

    /**
     * Parse a user-typed [rawText] into a [Double] using [locale]'s decimal separator.
     * Grouping separators are tolerated but not required.
     * @return parsed value, or null if [rawText] is empty / unparseable.
     */
    fun parse(rawText: String, locale: String): Double?

    /**
     * Live-format a user-typed [rawText] during Editing: group the integer portion using
     * [locale]'s grouping separator, preserve the decimal-separator-and-after portion as
     * the user typed it (no significantDigits padding/rounding), preserve a leading "-".
     * Idempotent: re-formatting an already-grouped string yields the same output.
     * Defensive: strips non-digit characters from the integer portion.
     */
    fun formatLive(rawText: String, locale: String): String
}

/** Platform factory — iOS uses NSNumberFormatter; Android (future) uses java.text.DecimalFormat. */
expect fun newLocaleNumberFormatter(): LocaleNumberFormatter

/**
 * Shared helper for [LocaleNumberFormatter.formatLive] actuals. Splits [rawText] into
 * sign + integer digits + decimal-and-after, calls [groupIntegerDigits] on the digit-only
 * integer part, then reassembles. Each platform supplies [groupingSeparator] and
 * [decimalSeparator] from its native formatter.
 */
internal inline fun liveFormat(
    rawText: String,
    groupingSeparator: String,
    decimalSeparator: String,
    groupIntegerDigits: (String) -> String,
): String {
    if (rawText.isEmpty()) return ""
    val negative = rawText.startsWith("-")
    val unsigned = if (negative) rawText.drop(1) else rawText
    val sign = if (negative) "-" else ""

    val stripped = if (groupingSeparator.isEmpty()) unsigned else unsigned.replace(groupingSeparator, "")
    val decIdx = if (decimalSeparator.isEmpty()) -1 else stripped.indexOf(decimalSeparator)

    val (intPart, decPart) = if (decIdx >= 0) {
        stripped.substring(0, decIdx) to stripped.substring(decIdx)
    } else {
        stripped to ""
    }

    val intDigits = intPart.filter { it in '0'..'9' }
    val groupedInt = if (intDigits.isEmpty()) "" else groupIntegerDigits(intDigits)
    return sign + groupedInt + decPart
}

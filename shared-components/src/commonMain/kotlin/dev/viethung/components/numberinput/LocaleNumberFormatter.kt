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
}

/** Platform factory — iOS uses NSNumberFormatter; Android (future) uses java.text.DecimalFormat. */
expect fun newLocaleNumberFormatter(): LocaleNumberFormatter

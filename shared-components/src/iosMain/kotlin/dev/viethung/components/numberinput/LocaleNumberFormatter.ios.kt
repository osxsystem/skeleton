package dev.viethung.components.numberinput

import platform.Foundation.NSLocale
import platform.Foundation.NSNumber
import platform.Foundation.NSNumberFormatter
import platform.Foundation.NSNumberFormatterDecimalStyle
import platform.Foundation.NSNumberFormatterRoundHalfEven

private class IosLocaleNumberFormatter : LocaleNumberFormatter {

    override fun format(value: Double, significantDigits: Int, locale: String): String {
        val nf = NSNumberFormatter().apply {
            this.locale = NSLocale(localeIdentifier = locale)
            this.numberStyle = NSNumberFormatterDecimalStyle
            this.usesGroupingSeparator = true
            this.minimumFractionDigits = significantDigits.toULong()
            this.maximumFractionDigits = significantDigits.toULong()
            this.roundingMode = NSNumberFormatterRoundHalfEven
        }
        return nf.stringFromNumber(NSNumber(double = value)).orEmpty()
    }

    override fun parse(rawText: String, locale: String): Double? {
        if (rawText.isBlank()) return null
        val nf = NSNumberFormatter().apply {
            this.locale = NSLocale(localeIdentifier = locale)
            this.numberStyle = NSNumberFormatterDecimalStyle
        }
        // Two-pass: NumberFormatter, then String.toDouble() as fallback for "-" / "0.5" w/o grouping.
        return nf.numberFromString(rawText)?.doubleValue
            ?: rawText.replace(nf.groupingSeparator.orEmpty(), "")
                .replace(nf.decimalSeparator.orEmpty(), ".")
                .toDoubleOrNull()
    }
}

actual fun newLocaleNumberFormatter(): LocaleNumberFormatter = IosLocaleNumberFormatter()

package dev.viethung.components.numberinput

// Android actual deferred to follow-up PRD (see NUMBER-INPUT-IMPLEMENTATION-PLAN.md §13).
// Stub compiles the Android target; replace with java.text.DecimalFormat implementation in v2.
private class AndroidLocaleNumberFormatter : LocaleNumberFormatter {
    override fun format(value: Double, significantDigits: Int, locale: String): String =
        "%.${significantDigits}f".format(value)

    override fun parse(rawText: String, locale: String): Double? =
        rawText.takeIf { it.isNotBlank() }?.toDoubleOrNull()
}

actual fun newLocaleNumberFormatter(): LocaleNumberFormatter = AndroidLocaleNumberFormatter()

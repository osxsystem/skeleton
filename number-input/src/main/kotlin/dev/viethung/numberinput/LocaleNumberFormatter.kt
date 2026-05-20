package dev.viethung.numberinput

interface LocaleNumberFormatter {
    fun format(value: Double, significantDigits: Int, locale: String): String
    fun parse(rawText: String, locale: String): Double?
    fun formatLive(rawText: String, locale: String): String
}

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

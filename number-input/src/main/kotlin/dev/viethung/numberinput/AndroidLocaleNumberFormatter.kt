package dev.viethung.numberinput

internal class AndroidLocaleNumberFormatter : LocaleNumberFormatter {
    override fun format(value: Double, significantDigits: Int, locale: String): String {
        val javaLocale = java.util.Locale.forLanguageTag(locale)
        val df = java.text.DecimalFormat.getInstance(javaLocale) as java.text.DecimalFormat
        df.minimumFractionDigits = significantDigits
        df.maximumFractionDigits = significantDigits
        df.isGroupingUsed = true
        return df.format(value)
    }

    override fun parse(rawText: String, locale: String): Double? {
        if (rawText.isBlank()) return null
        val javaLocale = java.util.Locale.forLanguageTag(locale)
        val df = java.text.DecimalFormat.getInstance(javaLocale) as java.text.DecimalFormat
        return try { df.parse(rawText)?.toDouble() } catch (e: Exception) { null }
    }

    override fun formatLive(rawText: String, locale: String): String {
        if (rawText.isEmpty()) return ""
        val javaLocale = java.util.Locale.forLanguageTag(locale)
        val df = java.text.DecimalFormat.getInstance(javaLocale) as java.text.DecimalFormat
        df.isGroupingUsed = true
        val symbols = df.decimalFormatSymbols
        val groupSep = symbols.groupingSeparator.toString()
        val decSep = symbols.decimalSeparator.toString()
        return liveFormat(rawText, groupSep, decSep) { digits ->
            val n = digits.toLongOrNull() ?: return@liveFormat digits
            java.text.DecimalFormat("#,##0", symbols).format(n)
        }
    }
}

fun newLocaleNumberFormatter(): LocaleNumberFormatter = AndroidLocaleNumberFormatter()

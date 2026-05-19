package dev.viethung.components.numberinput

/**
 * Test double for [LocaleNumberFormatter]. Deterministic, no NSNumberFormatter dependency.
 * Uses simple string formatting — sufficient for VM state-machine tests.
 */
class FakeLocaleNumberFormatter : LocaleNumberFormatter {
    override fun format(value: Double, significantDigits: Int, locale: String): String {
        // Build a simple fixed-precision string without using JVM-only APIs.
        val sign = if (value < 0.0) "-" else ""
        val abs = kotlin.math.abs(value)
        val multiplier = pow10(significantDigits)
        val rounded = kotlin.math.round(abs * multiplier).toDouble() / multiplier
        val intPart = rounded.toLong()
        val fracStr = if (significantDigits == 0) {
            ""
        } else {
            val fracValue = kotlin.math.round((rounded - intPart.toDouble()) * multiplier).toLong()
            "." + fracValue.toString().padStart(significantDigits, '0')
        }
        return "$sign$intPart$fracStr"
    }

    override fun parse(rawText: String, locale: String): Double? =
        rawText.takeIf { it.isNotBlank() }?.toDoubleOrNull()

    private fun pow10(n: Int): Double {
        var result = 1.0
        repeat(n) { result *= 10.0 }
        return result
    }
}

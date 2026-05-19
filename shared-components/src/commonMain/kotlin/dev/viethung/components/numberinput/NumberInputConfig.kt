package dev.viethung.components.numberinput

/**
 * Immutable configuration for a NumberInput instance.
 * Keep this separate from UiState so the VM constructor stays short.
 *
 * @property significantDigits Fixed digits after the decimal point. Padded with trailing zeros;
 *   rounded half-to-even. Equivalent to `NSNumberFormatter.minimumFractionDigits == maximumFractionDigits`.
 *   Must be in 0..9 (enforced by `init`).
 * @property locale BCP-47 tag (e.g. "en-US", "vi-VN"). Used by [LocaleNumberFormatter].
 * @property allowNegative When `false`, [NumberInputViewModel] clamps a negative `initialValue` to
 *   `0.0` and rejects negative text input (see §4.2). The ± toolbar button is also disabled.
 *   Validation lives in the VM, not here, so this data class stays a pure value carrier.
 * @property placeholder Empty-state hint shown by the platform field.
 */
data class NumberInputConfig(
    val significantDigits: Int = 2,
    val locale: String = "en-US",
    val allowNegative: Boolean = true,
    val placeholder: String = "",
) {
    init {
        require(significantDigits in 0..9) {
            "significantDigits must be in 0..9, got $significantDigits"
        }
    }
}

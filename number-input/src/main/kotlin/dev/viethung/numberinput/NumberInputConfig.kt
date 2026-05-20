package dev.viethung.numberinput

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

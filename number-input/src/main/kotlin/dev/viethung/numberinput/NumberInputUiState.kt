package dev.viethung.numberinput

sealed interface NumberInputUiState {
    val rawText: String
    val formattedText: String
    val value: Double?
    val significantDigits: Int
    val locale: String
    val allowNegative: Boolean

    data class Idle(
        override val rawText: String,
        override val formattedText: String,
        override val value: Double?,
        override val significantDigits: Int,
        override val locale: String,
        override val allowNegative: Boolean,
    ) : NumberInputUiState

    data class Editing(
        override val rawText: String,
        override val formattedText: String,
        override val value: Double?,
        override val significantDigits: Int,
        override val locale: String,
        override val allowNegative: Boolean,
    ) : NumberInputUiState

    data class Committed(
        override val rawText: String,
        override val formattedText: String,
        override val value: Double?,
        override val significantDigits: Int,
        override val locale: String,
        override val allowNegative: Boolean,
    ) : NumberInputUiState
}

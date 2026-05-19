package dev.viethung.components.numberinput

/**
 * Sealed UI state for [NumberInputViewModel].
 * See NUMBER-INPUT-PRD.md §7 and NUMBER-INPUT-UI.md §3.
 */
sealed interface NumberInputUiState {
    val rawText: String          // unformatted, what the user is typing
    val formattedText: String    // what's shown when not focused
    val value: Double?           // parsed numeric, null if empty
    val significantDigits: Int
    val locale: String           // BCP-47, e.g. "en-US"
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
        override val formattedText: String,    // last-known formatted; not re-computed mid-edit
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

package dev.viethung.components.numberinput

/**
 * Sealed UI state for [NumberInputViewModel].
 * See NUMBER-INPUT-PRD.md §7 and NUMBER-INPUT-UI.md §3.
 */
sealed interface NumberInputUiState {
    val rawText: String          // what the user is typing (may include grouping separators)
    val formattedText: String    // grouped display string (live during Editing, full format on Idle/Committed)
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
        override val formattedText: String,    // live-grouped integer portion; recomputed each keystroke
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

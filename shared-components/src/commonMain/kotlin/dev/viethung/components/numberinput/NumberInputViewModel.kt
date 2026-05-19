package dev.viethung.components.numberinput

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class NumberInputViewModel(
    private val formatter: LocaleNumberFormatter,
    initialValue: Double? = null,
    private val significantDigits: Int = 2,
    private val locale: String = "en-US",
    private val allowNegative: Boolean = true,
) : ViewModel() {

    // Per Validation Summary decision #2 / AC-08: clamp negative initialValue to 0.0 when allowNegative=false.
    private val seedValue: Double? =
        if (!allowNegative && initialValue != null && initialValue < 0.0) 0.0 else initialValue

    private val _state: MutableStateFlow<NumberInputUiState> = MutableStateFlow(
        NumberInputUiState.Idle(
            rawText = seedValue?.toString().orEmpty(),
            formattedText = seedValue?.let { formatter.format(it, significantDigits, locale) }.orEmpty(),
            value = seedValue,
            significantDigits = significantDigits,
            locale = locale,
            allowNegative = allowNegative,
        )
    )
    val state: StateFlow<NumberInputUiState> = _state.asStateFlow()

    fun onFocusChanged(focused: Boolean) {
        viewModelScope.launch {
            val current = _state.value
            if (focused) {
                if (current !is NumberInputUiState.Editing) {
                    // Enter Editing with the locale-correct formatted form as both rawText and
                    // formattedText, so the user starts editing the grouped string they see.
                    val carry = current.formattedText
                    _state.value = NumberInputUiState.Editing(
                        rawText = carry,
                        formattedText = carry,
                        value = current.value,
                        significantDigits = significantDigits,
                        locale = locale,
                        allowNegative = allowNegative,
                    )
                }
            } else {
                commitAndSetIdle()
            }
        }
    }

    fun onTextChange(newRawText: String) {
        viewModelScope.launch {
            val current = _state.value
            val parsed = formatter.parse(newRawText, locale)
            // Per implementation notes §4.2:
            // - If rawText is blank → value is null (empty field).
            // - If parse fails on non-blank rawText: keep prior value, update rawText only.
            // - Per Validation Summary decision #2: if allowNegative=false and parsed is negative,
            //   reject the value change (keep prior value), but update rawText.
            val newValue = when {
                newRawText.isBlank() -> null
                parsed == null -> current.value
                !allowNegative && parsed < 0.0 -> current.value
                else -> parsed
            }
            _state.value = NumberInputUiState.Editing(
                rawText = newRawText,
                formattedText = formatter.formatLive(newRawText, locale),
                value = newValue,
                significantDigits = significantDigits,
                locale = locale,
                allowNegative = allowNegative,
            )
        }
    }

    fun onToggleSign() {
        // No-op if null value or allowNegative=false
        if (!allowNegative) return
        viewModelScope.launch {
            val current = _state.value
            val currentValue = current.value ?: return@launch
            val toggled = -currentValue
            // Use locale-aware formatted form as both rawText and formattedText so vi-VN/de-DE
            // get the right decimal separator (Double.toString always uses '.').
            val newRawText = formatter.format(toggled, significantDigits, locale)
            _state.value = NumberInputUiState.Editing(
                rawText = newRawText,
                formattedText = newRawText,
                value = toggled,
                significantDigits = significantDigits,
                locale = locale,
                allowNegative = allowNegative,
            )
        }
    }

    fun onClear() {
        viewModelScope.launch {
            _state.value = NumberInputUiState.Editing(
                rawText = "",
                formattedText = "",
                value = null,
                significantDigits = significantDigits,
                locale = locale,
                allowNegative = allowNegative,
            )
        }
    }

    fun onCommit() {
        viewModelScope.launch {
            commitAndSetIdle()
        }
    }

    private suspend fun commitAndSetIdle() {
        val current = _state.value
        val formatted = current.value?.let { formatter.format(it, significantDigits, locale) }.orEmpty()
        val committed = NumberInputUiState.Committed(
            rawText = current.rawText,
            formattedText = formatted,
            value = current.value,
            significantDigits = significantDigits,
            locale = locale,
            allowNegative = allowNegative,
        )
        _state.value = committed
        _state.value = NumberInputUiState.Idle(
            rawText = committed.rawText,
            formattedText = committed.formattedText,
            value = committed.value,
            significantDigits = significantDigits,
            locale = locale,
            allowNegative = allowNegative,
        )
    }
}

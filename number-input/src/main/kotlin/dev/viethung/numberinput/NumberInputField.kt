package dev.viethung.numberinput

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
fun NumberInputField(
    value: Double?,
    onValueChange: (Double?) -> Unit,
    modifier: Modifier = Modifier,
    significantDigits: Int = 2,
    locale: String = "en-US",
    allowNegative: Boolean = true,
    placeholder: String = "",
) {
    val vm: NumberInputViewModel = viewModel(
        key = "NumberInputViewModel-$locale-$significantDigits-$allowNegative",
    ) {
        NumberInputViewModel(
            formatter = newLocaleNumberFormatter(),
            initialValue = value,
            significantDigits = significantDigits,
            locale = locale,
            allowNegative = allowNegative,
        )
    }

    val state by vm.state.collectAsStateWithLifecycle()

    // Fire onValueChange only when the VM's value actually changes.
    var prevValue by remember { mutableStateOf(state.value) }
    LaunchedEffect(state.value) {
        if (state.value != prevValue) {
            prevValue = state.value
            onValueChange(state.value)
        }
    }

    val isEmpty = state.value == null && state.rawText.isEmpty()

    OutlinedTextField(
        value = state.formattedText,
        onValueChange = { vm.onTextChange(it) },
        modifier = modifier
            .testTag("numberInput.field")
            .onFocusChanged { focusState -> vm.onFocusChanged(focusState.isFocused) },
        placeholder = if (placeholder.isNotEmpty()) ({ Text(placeholder) }) else null,
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
        trailingIcon = {
            Row {
                IconButton(
                    onClick = { vm.onClear() },
                    enabled = !isEmpty,
                    modifier = Modifier.testTag("numberInput.toolbar.clear"),
                ) {
                    Text("✕")
                }
                IconButton(
                    onClick = { vm.onToggleSign() },
                    enabled = allowNegative && state.value != null,
                    modifier = Modifier.testTag("numberInput.toolbar.toggleSign"),
                ) {
                    Text("±")
                }
            }
        },
    )
}

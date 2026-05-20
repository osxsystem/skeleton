package dev.viethung.skeleton.android.showcase

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.viethung.numberinput.NumberInputField

@Composable
fun NumberInputKitShowcaseScreen(onBack: () -> Unit) {
    var enUs by remember { mutableStateOf<Double?>(1234.5) }
    var viVn by remember { mutableStateOf<Double?>(1234.5) }
    var deDe by remember { mutableStateOf<Double?>(1234.5) }
    var unsigned by remember { mutableStateOf<Double?>(42.0) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Text("Number Input — :number-input library", style = MaterialTheme.typography.titleMedium)

        Row(label = "en-US, sig=2", value = enUs) {
            NumberInputField(
                value = enUs,
                onValueChange = { enUs = it },
                modifier = Modifier.fillMaxWidth(),
                significantDigits = 2,
                locale = "en-US",
                allowNegative = true,
                placeholder = "Enter amount",
            )
        }
        Row(label = "vi-VN, sig=2", value = viVn) {
            NumberInputField(
                value = viVn,
                onValueChange = { viVn = it },
                modifier = Modifier.fillMaxWidth(),
                significantDigits = 2,
                locale = "vi-VN",
                allowNegative = true,
                placeholder = "Nhập số tiền",
            )
        }
        Row(label = "de-DE, sig=3", value = deDe) {
            NumberInputField(
                value = deDe,
                onValueChange = { deDe = it },
                modifier = Modifier.fillMaxWidth(),
                significantDigits = 3,
                locale = "de-DE",
                allowNegative = true,
                placeholder = "Betrag eingeben",
            )
        }
        Row(label = "en-US, sig=2, unsigned", value = unsigned) {
            NumberInputField(
                value = unsigned,
                onValueChange = { unsigned = it },
                modifier = Modifier.fillMaxWidth(),
                significantDigits = 2,
                locale = "en-US",
                allowNegative = false,
                placeholder = "Positive only",
            )
        }

        Button(onClick = {
            enUs = 1234.5; viVn = 1234.5; deDe = 1234.5; unsigned = 42.0
        }) { Text("Reset all") }

        Button(onClick = onBack) { Text("Back to Dashboard") }
    }
}

@Composable
private fun Row(label: String, value: Double?, field: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(label, style = MaterialTheme.typography.labelMedium)
        field()
        Text("value = $value", style = MaterialTheme.typography.bodySmall)
    }
}

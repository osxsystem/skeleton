package dev.viethung.skylog.ui.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay

/**
 * Debounced search field (200 ms, Eng Review F-4.5).
 *
 * The user types into a local [query] state; [onSearchChange] is only invoked
 * after 200 ms of inactivity, so the filtered list does not recompute on every
 * keystroke.
 */
@Composable
fun SearchField(
    search: String,
    onSearchChange: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    // Local state captures every keystroke immediately for the text field display.
    // The debounced callback fires 200 ms after the user stops typing.
    var query by remember { mutableStateOf(search) }

    LaunchedEffect(query) {
        delay(200L)
        onSearchChange(query)
    }

    OutlinedTextField(
        value = query,
        onValueChange = { query = it },
        placeholder = {
            Text(
                text = "Search…",
                style = MaterialTheme.typography.bodySmall,
            )
        },
        singleLine = true,
        textStyle = MaterialTheme.typography.bodySmall,
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp)
            .testTag("searchField"),
    )
}

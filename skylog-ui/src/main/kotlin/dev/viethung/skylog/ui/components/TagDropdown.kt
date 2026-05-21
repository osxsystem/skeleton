package dev.viethung.skylog.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag

/**
 * A dropdown chip that lets the user filter by a specific tag, or clear the tag filter.
 */
@Composable
fun TagDropdown(
    tags: List<String>,
    selectedTag: String?,
    onTagSelected: (String?) -> Unit,
    modifier: Modifier = Modifier,
) {
    var expanded by remember { mutableStateOf(false) }

    Box(modifier = modifier) {
        FilterChip(
            selected = selectedTag != null,
            onClick = { expanded = true },
            label = {
                Text(
                    text = selectedTag ?: "Tag",
                    style = MaterialTheme.typography.labelSmall,
                )
            },
            modifier = Modifier.testTag("tagDropdown.chip"),
        )

        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            DropdownMenuItem(
                text = { Text("All tags") },
                onClick = {
                    onTagSelected(null)
                    expanded = false
                },
                modifier = Modifier.testTag("tagDropdown.all"),
            )
            tags.forEach { tag ->
                DropdownMenuItem(
                    text = { Text(tag) },
                    onClick = {
                        onTagSelected(tag)
                        expanded = false
                    },
                    modifier = Modifier.testTag("tagDropdown.$tag"),
                )
            }
        }
    }
}

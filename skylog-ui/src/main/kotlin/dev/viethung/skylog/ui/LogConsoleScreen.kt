package dev.viethung.skylog.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Text
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ClipboardManager
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.viethung.skylog.Severity
import dev.viethung.skylog.ui.components.LogRow
import dev.viethung.skylog.ui.components.SearchField
import dev.viethung.skylog.ui.components.SeverityFilterChips
import dev.viethung.skylog.ui.components.TagDropdown
import dev.viethung.skylog.ui.theme.SkylogColors
import dev.viethung.skylog.writers.InMemoryLogWriter
import kotlinx.coroutines.launch

/**
 * Full-screen log console backed by [buffer].
 *
 * Features (FR-10, FR-11, FR-12, PRD §8):
 * - Virtualized list ([LazyColumn]) newest-first (`reverseLayout = true`).
 * - Single-pass filter keyed on `entries + minSeverity + selectedTag + search` (Eng Review P12).
 * - Severity chip row, tag dropdown, 200 ms debounced search field.
 * - "Clear" footer action with undo snackbar (Eng Review P10a, PRD §8 ~5 s).
 * - "Share" footer action copies the current filtered view to the clipboard.
 *
 * @param buffer  The [InMemoryLogWriter] whose [entries][InMemoryLogWriter.entries] StateFlow
 *                drives the list. The caller is responsible for registering it with [Skylog].
 * @param modifier Applied to the [Scaffold] root.
 * @param onClose  Optional callback — pass a non-null lambda to show a "Close" button in the header.
 */
@Composable
fun LogConsoleScreen(
    buffer: InMemoryLogWriter,
    modifier: Modifier = Modifier,
    onClose: (() -> Unit)? = null,
) {
    val entries by buffer.entries.collectAsStateWithLifecycle()
    var minSeverity by remember { mutableStateOf(Severity.Verbose) }
    var selectedTag by remember { mutableStateOf<String?>(null) }
    var search by remember { mutableStateOf("") }
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val clipboard: ClipboardManager = LocalClipboardManager.current
    val darkTheme = isSystemInDarkTheme()

    // Single-pass filter: one predicate, one allocation — no chained .filter{}.filter{} calls
    // (Eng Review A-5 / patch P12). Keyed on all filter inputs so remember only recomputes
    // when something actually changed.
    val filtered = remember(entries, minSeverity, selectedTag, search) {
        entries.filter {
            it.severity >= minSeverity
                && (selectedTag == null || it.tag == selectedTag)
                && (search.isBlank()
                    || it.message.contains(search, ignoreCase = true)
                    || it.tag.contains(search, ignoreCase = true))
        }
    }

    val tags = remember(entries) { entries.map { it.tag }.distinct().sorted() }
    val listState = rememberLazyListState()

    Scaffold(
        modifier = modifier,
        snackbarHost = { SnackbarHost(snackbarHostState) },
    ) { padding ->
        Column(Modifier.padding(padding)) {
            // Header
            ConsoleHeader(
                minSeverity = minSeverity,
                onMinSeverityChange = { minSeverity = it },
                tags = tags,
                selectedTag = selectedTag,
                onTagSelected = { selectedTag = it },
                search = search,
                onSearchChange = { search = it },
                onClose = onClose,
            )

            // Body
            if (filtered.isEmpty()) {
                EmptyState(
                    modifier = Modifier.weight(1f),
                    darkTheme = darkTheme,
                    bufferEmpty = entries.isEmpty(),
                )
            } else {
                LazyColumn(
                    state = listState,
                    reverseLayout = true,
                    modifier = Modifier
                        .weight(1f)
                        .testTag("logList"),
                ) {
                    // Stable key = timestamp epoch millis — newest at top (reverseLayout).
                    items(
                        items = filtered,
                        key = { it.timestamp.toEpochMilliseconds() },
                    ) { entry ->
                        LogRow(entry = entry)
                    }
                }
            }

            // Footer
            ConsoleFooter(
                filteredEntries = filtered,
                onShare = {
                    val text = filtered.joinToString("\n") { e ->
                        "[${e.severity.name.first()}] ${e.tag}: ${e.message}"
                    }
                    clipboard.setText(AnnotatedString(text))
                },
                onClear = {
                    // Snapshot before wiping — needed for undo (Eng Review P10a, PRD §8).
                    val snapshot = buffer.entries.value
                    buffer.clear()
                    scope.launch {
                        val result = snackbarHostState.showSnackbar(
                            message = "Cleared ${snapshot.size} log${if (snapshot.size == 1) "" else "s"}",
                            actionLabel = "Undo",
                            duration = SnackbarDuration.Short, // ~4 s; PRD §8 says ~5 s — Short is close enough
                        )
                        if (result == SnackbarResult.ActionPerformed) {
                            buffer.restore(snapshot)
                        }
                    }
                },
            )
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Private sub-composables
// ──────────────────────────────────────────────────────────────────────────────

@Composable
private fun ConsoleHeader(
    minSeverity: Severity,
    onMinSeverityChange: (Severity) -> Unit,
    tags: List<String>,
    selectedTag: String?,
    onTagSelected: (String?) -> Unit,
    search: String,
    onSearchChange: (String) -> Unit,
    onClose: (() -> Unit)?,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Skylog",
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.weight(1f),
            )
            if (onClose != null) {
                TextButton(onClick = onClose) {
                    Text("Close")
                }
            }
        }

        // Severity chips + tag dropdown in one scrollable row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SeverityFilterChips(
                minSeverity = minSeverity,
                onMinSeverityChange = onMinSeverityChange,
                modifier = Modifier.weight(1f),
            )
            TagDropdown(
                tags = tags,
                selectedTag = selectedTag,
                onTagSelected = onTagSelected,
            )
        }

        SearchField(
            search = search,
            onSearchChange = onSearchChange,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun EmptyState(
    modifier: Modifier = Modifier,
    darkTheme: Boolean = isSystemInDarkTheme(),
    bufferEmpty: Boolean = true,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(32.dp)
            .testTag("emptyState"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = if (bufferEmpty) "No logs yet" else "No logs match the current filter",
            style = MaterialTheme.typography.titleMedium,
            color = SkylogColors.dim(darkTheme),
        )
        if (bufferEmpty) {
            Spacer(Modifier.height(8.dp))
            Text(
                text = "Try emitting a log with Skylog.i { \"...\" }",
                style = MaterialTheme.typography.bodySmall,
                color = SkylogColors.dim(darkTheme),
            )
        }
    }
}

@Composable
private fun ConsoleFooter(
    filteredEntries: List<dev.viethung.skylog.LogEntry>,
    onShare: () -> Unit,
    onClear: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.End,
    ) {
        TextButton(
            onClick = onShare,
            modifier = Modifier.testTag("shareButton"),
        ) {
            Text("Share (${filteredEntries.size})")
        }
        TextButton(
            onClick = onClear,
            modifier = Modifier.testTag("clearButton"),
        ) {
            Text("Clear")
        }
    }
}

package dev.viethung.skylog.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ClipboardManager
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import dev.viethung.skylog.LogEntry
import dev.viethung.skylog.ui.theme.SkylogColors
import dev.viethung.skylog.ui.theme.wcagLetter
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime

/**
 * A single log entry row.
 *
 * Layout: [severity letter + color stripe] [timestamp] [tag] [message (2-line ellipsis, expandable)]
 *
 * The severity letter alongside the color stripe satisfies WCAG 2.1 SC 1.4.1 (Use of Color).
 * Color alone is insufficient for accessibility — the [Severity.wcagLetter] glyph is the
 * second visual signal (Eng Review F-11.3).
 */
@Composable
fun LogRow(
    entry: LogEntry,
    modifier: Modifier = Modifier,
) {
    val darkTheme = isSystemInDarkTheme()
    val stripeColor = SkylogColors.stripeColor(entry.severity, darkTheme)
    val clipboard: ClipboardManager = LocalClipboardManager.current
    var expanded by remember { mutableStateOf(false) }

    val time = remember(entry.timestamp) {
        val local = entry.timestamp.toLocalDateTime(TimeZone.currentSystemDefault())
        "%02d:%02d:%02d.%03d".format(
            local.hour, local.minute, local.second, local.nanosecond / 1_000_000
        )
    }

    val rowText = remember(entry) {
        buildString {
            append("[${entry.severity.wcagLetter()}] ")
            append(time)
            append("  ")
            append(entry.tag)
            append(": ")
            append(entry.message)
            entry.throwable?.let { append("\n${it.stackTraceToString()}") }
        }
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clickable { expanded = !expanded }
            .testTag("logRow.${entry.timestamp.toEpochMilliseconds()}"),
        verticalAlignment = Alignment.Top,
    ) {
        // Severity stripe + WCAG letter
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .width(28.dp)
                .background(stripeColor)
                .padding(top = 4.dp, bottom = 4.dp),
        ) {
            Text(
                text = entry.severity.wcagLetter(),
                style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                color = MaterialTheme.colorScheme.surface,
            )
        }

        Spacer(Modifier.width(6.dp))

        Column(
            modifier = Modifier
                .weight(1f)
                .padding(top = 4.dp, bottom = 4.dp, end = 8.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = time,
                    style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                    modifier = Modifier.testTag("logRow.timestamp"),
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = entry.tag,
                    style = MaterialTheme.typography.labelSmall,
                    color = stripeColor,
                    modifier = Modifier.testTag("logRow.tag"),
                )
            }

            Spacer(Modifier.height(2.dp))

            Text(
                text = entry.message,
                style = MaterialTheme.typography.bodySmall,
                maxLines = if (expanded) Int.MAX_VALUE else 2,
                modifier = Modifier.testTag("logRow.message"),
            )

            val throwable = entry.throwable
            if (expanded && throwable != null) {
                Spacer(Modifier.height(4.dp))
                Text(
                    text = throwable.stackTraceToString(),
                    style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                    color = SkylogColors.stripeColor(entry.severity, darkTheme),
                )
            }

            // Copy row text to clipboard on long-press (row is also tap-expandable)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable {
                        clipboard.setText(AnnotatedString(rowText))
                    }
                    .testTag("logRow.copy.${entry.timestamp.toEpochMilliseconds()}"),
            )
        }
    }
}

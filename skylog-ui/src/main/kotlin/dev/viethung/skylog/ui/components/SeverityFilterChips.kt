package dev.viethung.skylog.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import dev.viethung.skylog.Severity
import dev.viethung.skylog.ui.theme.SkylogColors
import dev.viethung.skylog.ui.theme.wcagLetter

/**
 * A row of [FilterChip]s representing each [Severity] level.
 *
 * Selecting a chip sets [minSeverity]; entries below that level are hidden.
 * Chip row shows labels matching the WCAG severity letters.
 */
@Composable
fun SeverityFilterChips(
    minSeverity: Severity,
    onMinSeverityChange: (Severity) -> Unit,
    modifier: Modifier = Modifier,
) {
    val darkTheme = isSystemInDarkTheme()
    Row(
        modifier = modifier.padding(horizontal = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Severity.entries.forEach { severity ->
            val selected = severity == minSeverity
            FilterChip(
                selected = selected,
                onClick = { onMinSeverityChange(severity) },
                label = {
                    Text(
                        text = severity.wcagLetter(),
                        style = MaterialTheme.typography.labelSmall,
                    )
                },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = SkylogColors.stripeColor(severity, darkTheme),
                    selectedLabelColor = MaterialTheme.colorScheme.surface,
                ),
                modifier = Modifier.testTag("severityChip.${severity.name}"),
            )
        }
    }
}

package dev.viethung.skylog.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import dev.viethung.core.theme.DesignTokens
import dev.viethung.skylog.Severity

/**
 * Maps [Severity] to themed [Color] values sourced from [DesignTokens].
 *
 * No raw `Color(0xFF...)` literals — all values come from the design token palette.
 * See CLAUDE.md §2: "No raw colors, fonts, sizes, or radii in UI code."
 */
object SkylogColors {

    /** Color stripe / glyph color per severity level. */
    @Composable
    fun stripeColor(severity: Severity, darkTheme: Boolean): Color {
        val palette = if (darkTheme) DesignTokens.DarkColors else DesignTokens.LightColors
        return when (severity) {
            Severity.Verbose -> Color(palette.onSurfaceVariant)   // dim gray
            Severity.Debug   -> Color(palette.primary)            // blue
            Severity.Info    -> Color(palette.tertiary)           // green / teal
            Severity.Warn    -> Color(palette.secondary)          // secondary (amber-ish in palette)
            Severity.Error   -> Color(palette.error)              // red
            Severity.Assert  -> Color(palette.inversePrimary)     // magenta-adjacent
        }
    }

    /** Background tint for a row — very light tint using container tokens. */
    @Composable
    fun rowBackground(severity: Severity, darkTheme: Boolean): Color {
        val palette = if (darkTheme) DesignTokens.DarkColors else DesignTokens.LightColors
        return when (severity) {
            Severity.Verbose -> Color(palette.surfaceContainerLowest)
            Severity.Debug   -> Color(palette.surfaceContainerLow)
            Severity.Info    -> Color(palette.surfaceContainer)
            Severity.Warn    -> Color(palette.secondaryContainer)
            Severity.Error   -> Color(palette.errorContainer)
            Severity.Assert  -> Color(palette.onPrimaryContainer)
        }
    }

    /**
     * Dim text color used for the empty-state hint and secondary labels.
     * Uses [DesignTokens.LightColors.onSurfaceVariant] — closest token to a "dim" semantic.
     */
    @Composable
    fun dim(darkTheme: Boolean): Color {
        val palette = if (darkTheme) DesignTokens.DarkColors else DesignTokens.LightColors
        return Color(palette.onSurfaceVariant)
    }
}

/** WCAG severity letter used alongside the color stripe (WCAG 2.1 SC 1.4.1). */
fun Severity.wcagLetter(): String = when (this) {
    Severity.Verbose -> "V"
    Severity.Debug   -> "D"
    Severity.Info    -> "I"
    Severity.Warn    -> "W"
    Severity.Error   -> "E"
    Severity.Assert  -> "A"
}

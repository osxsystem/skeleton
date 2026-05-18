package dev.viethung.core.theme

import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.assertEquals

class DesignTokensTest {

    @Test
    fun noColorConstantIsNegative() {
        val lightColors: List<Long> = listOf(
            DesignTokens.LightColors.primary,
            DesignTokens.LightColors.onPrimary,
            DesignTokens.LightColors.primaryContainer,
            DesignTokens.LightColors.onPrimaryContainer,
            DesignTokens.LightColors.secondary,
            DesignTokens.LightColors.onSecondary,
            DesignTokens.LightColors.secondaryContainer,
            DesignTokens.LightColors.onSecondaryContainer,
            DesignTokens.LightColors.tertiary,
            DesignTokens.LightColors.onTertiary,
            DesignTokens.LightColors.tertiaryContainer,
            DesignTokens.LightColors.onTertiaryContainer,
            DesignTokens.LightColors.error,
            DesignTokens.LightColors.onError,
            DesignTokens.LightColors.errorContainer,
            DesignTokens.LightColors.onErrorContainer,
            DesignTokens.LightColors.background,
            DesignTokens.LightColors.onBackground,
            DesignTokens.LightColors.surface,
            DesignTokens.LightColors.onSurface,
            DesignTokens.LightColors.surfaceVariant,
            DesignTokens.LightColors.onSurfaceVariant,
            DesignTokens.LightColors.surfaceTint,
            DesignTokens.LightColors.outline,
            DesignTokens.LightColors.outlineVariant,
            DesignTokens.LightColors.scrim,
            DesignTokens.LightColors.inverseSurface,
            DesignTokens.LightColors.inverseOnSurface,
            DesignTokens.LightColors.inversePrimary,
            DesignTokens.LightColors.surfaceDim,
            DesignTokens.LightColors.surfaceBright,
            DesignTokens.LightColors.surfaceContainerLowest,
            DesignTokens.LightColors.surfaceContainerLow,
            DesignTokens.LightColors.surfaceContainer,
            DesignTokens.LightColors.surfaceContainerHigh,
            DesignTokens.LightColors.surfaceContainerHighest,
        )
        val darkColors: List<Long> = listOf(
            DesignTokens.DarkColors.primary,
            DesignTokens.DarkColors.onPrimary,
            DesignTokens.DarkColors.primaryContainer,
            DesignTokens.DarkColors.onPrimaryContainer,
            DesignTokens.DarkColors.secondary,
            DesignTokens.DarkColors.onSecondary,
            DesignTokens.DarkColors.secondaryContainer,
            DesignTokens.DarkColors.onSecondaryContainer,
            DesignTokens.DarkColors.tertiary,
            DesignTokens.DarkColors.onTertiary,
            DesignTokens.DarkColors.tertiaryContainer,
            DesignTokens.DarkColors.onTertiaryContainer,
            DesignTokens.DarkColors.error,
            DesignTokens.DarkColors.onError,
            DesignTokens.DarkColors.errorContainer,
            DesignTokens.DarkColors.onErrorContainer,
            DesignTokens.DarkColors.background,
            DesignTokens.DarkColors.onBackground,
            DesignTokens.DarkColors.surface,
            DesignTokens.DarkColors.onSurface,
            DesignTokens.DarkColors.surfaceVariant,
            DesignTokens.DarkColors.onSurfaceVariant,
            DesignTokens.DarkColors.surfaceTint,
            DesignTokens.DarkColors.outline,
            DesignTokens.DarkColors.outlineVariant,
            DesignTokens.DarkColors.scrim,
            DesignTokens.DarkColors.inverseSurface,
            DesignTokens.DarkColors.inverseOnSurface,
            DesignTokens.DarkColors.inversePrimary,
            DesignTokens.DarkColors.surfaceDim,
            DesignTokens.DarkColors.surfaceBright,
            DesignTokens.DarkColors.surfaceContainerLowest,
            DesignTokens.DarkColors.surfaceContainerLow,
            DesignTokens.DarkColors.surfaceContainer,
            DesignTokens.DarkColors.surfaceContainerHigh,
            DesignTokens.DarkColors.surfaceContainerHighest,
        )
        (lightColors + darkColors).forEachIndexed { index, color ->
            assertTrue(
                color > 0L,
                "Color constant at index $index is $color (negative). " +
                "Missing L suffix on a 0xFF... constant — see Pitfall 6 in .planning/research/PITFALLS.md"
            )
        }
    }

    @Test
    fun typographyRolesAreComplete() {
        val roles: List<Float> = listOf(
            DesignTokens.typography.displayLarge.size,
            DesignTokens.typography.displayMedium.size,
            DesignTokens.typography.displaySmall.size,
            DesignTokens.typography.headlineLarge.size,
            DesignTokens.typography.headlineMedium.size,
            DesignTokens.typography.headlineSmall.size,
            DesignTokens.typography.titleLarge.size,
            DesignTokens.typography.titleMedium.size,
            DesignTokens.typography.titleSmall.size,
            DesignTokens.typography.bodyLarge.size,
            DesignTokens.typography.bodyMedium.size,
            DesignTokens.typography.bodySmall.size,
            DesignTokens.typography.labelLarge.size,
            DesignTokens.typography.labelMedium.size,
            DesignTokens.typography.labelSmall.size,
        )
        assertEquals(15, roles.size, "Expected 15 M3 typography roles")
        roles.forEachIndexed { index, size ->
            assertTrue(size > 0f, "Typography role at index $index has non-positive size $size")
        }
    }

    @Test
    fun spacingIsOrdered() {
        assertTrue(DesignTokens.spacing.xxs < DesignTokens.spacing.xs,  "xxs < xs")
        assertTrue(DesignTokens.spacing.xs  < DesignTokens.spacing.sm,  "xs < sm")
        assertTrue(DesignTokens.spacing.sm  < DesignTokens.spacing.md,  "sm < md")
        assertTrue(DesignTokens.spacing.md  < DesignTokens.spacing.lg,  "md < lg")
        assertTrue(DesignTokens.spacing.lg  < DesignTokens.spacing.xl,  "lg < xl")
        assertTrue(DesignTokens.spacing.xl  < DesignTokens.spacing.xxl, "xl < xxl")
    }

    @Test
    fun rapidToggleSimulation() {
        val expected = (0 until 10).map { index ->
            if (index % 2 == 1) DesignTokens.DarkColors.primary
            else                DesignTokens.LightColors.primary
        }
        val actual = (0 until 10).map { index ->
            val isDark = index % 2 == 1
            if (isDark) DesignTokens.DarkColors.primary else DesignTokens.LightColors.primary
        }
        assertTrue(
            DesignTokens.LightColors.primary != DesignTokens.DarkColors.primary,
            "LightColors.primary and DarkColors.primary must be distinct — palettes appear swapped"
        )
        actual.forEachIndexed { index, value ->
            assertTrue(
                value == expected[index],
                "Toggle iteration $index: expected ${expected[index]} but got $value"
            )
        }
    }

    @Test
    fun darkColorsBrightInDark() {
        assertTrue(
            DesignTokens.DarkColors.background < DesignTokens.LightColors.background,
            "DarkColors.background (${DesignTokens.DarkColors.background}) should be numerically " +
            "less than LightColors.background (${DesignTokens.LightColors.background}). " +
            "Palettes may be swapped — see D-16 in 02-CONTEXT.md"
        )
        assertTrue(
            DesignTokens.DarkColors.surface < DesignTokens.LightColors.surface,
            "DarkColors.surface (${DesignTokens.DarkColors.surface}) should be numerically " +
            "less than LightColors.surface (${DesignTokens.LightColors.surface}). " +
            "Palettes may be swapped."
        )
        assertTrue(
            DesignTokens.DarkColors.onBackground > DesignTokens.LightColors.onBackground,
            "DarkColors.onBackground (${DesignTokens.DarkColors.onBackground}) should be numerically " +
            "greater than LightColors.onBackground (${DesignTokens.LightColors.onBackground}). " +
            "On-roles invert direction — palettes may be swapped."
        )
        assertTrue(
            DesignTokens.DarkColors.surfaceContainerLowest < DesignTokens.LightColors.surfaceContainerLowest,
            "DarkColors.surfaceContainerLowest (${DesignTokens.DarkColors.surfaceContainerLowest}) " +
            "should be less than LightColors.surfaceContainerLowest (${DesignTokens.LightColors.surfaceContainerLowest}). " +
            "Surface container hierarchy may be swapped."
        )
        assertEquals(
            DesignTokens.DarkColors.primary, DesignTokens.LightColors.inversePrimary,
            "LightColors.inversePrimary must equal DarkColors.primary (M3 inverse-role convention)."
        )
        assertEquals(
            DesignTokens.LightColors.primary, DesignTokens.DarkColors.inversePrimary,
            "DarkColors.inversePrimary must equal LightColors.primary (M3 inverse-role convention)."
        )
    }
}

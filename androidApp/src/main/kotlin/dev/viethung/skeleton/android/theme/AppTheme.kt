package dev.viethung.skeleton.android.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.viethung.core.theme.DesignTokens
import dev.viethung.core.theme.TextStyleToken

@Composable
fun AppTheme(
    isDark: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val palette = if (isDark) DesignTokens.DarkColors else DesignTokens.LightColors

    val colorScheme = ColorScheme(
        primary                 = Color(palette.primary),
        onPrimary               = Color(palette.onPrimary),
        primaryContainer        = Color(palette.primaryContainer),
        onPrimaryContainer      = Color(palette.onPrimaryContainer),
        secondary               = Color(palette.secondary),
        onSecondary             = Color(palette.onSecondary),
        secondaryContainer      = Color(palette.secondaryContainer),
        onSecondaryContainer    = Color(palette.onSecondaryContainer),
        tertiary                = Color(palette.tertiary),
        onTertiary              = Color(palette.onTertiary),
        tertiaryContainer       = Color(palette.tertiaryContainer),
        onTertiaryContainer     = Color(palette.onTertiaryContainer),
        error                   = Color(palette.error),
        onError                 = Color(palette.onError),
        errorContainer          = Color(palette.errorContainer),
        onErrorContainer        = Color(palette.onErrorContainer),
        background              = Color(palette.background),
        onBackground            = Color(palette.onBackground),
        surface                 = Color(palette.surface),
        onSurface               = Color(palette.onSurface),
        surfaceVariant          = Color(palette.surfaceVariant),
        onSurfaceVariant        = Color(palette.onSurfaceVariant),
        surfaceTint             = Color(palette.surfaceTint),
        outline                 = Color(palette.outline),
        outlineVariant          = Color(palette.outlineVariant),
        scrim                   = Color(palette.scrim),
        inverseSurface          = Color(palette.inverseSurface),
        inverseOnSurface        = Color(palette.inverseOnSurface),
        inversePrimary          = Color(palette.inversePrimary),
        surfaceDim              = Color(palette.surfaceDim),
        surfaceBright           = Color(palette.surfaceBright),
        surfaceContainerLowest  = Color(palette.surfaceContainerLowest),
        surfaceContainerLow     = Color(palette.surfaceContainerLow),
        surfaceContainer        = Color(palette.surfaceContainer),
        surfaceContainerHigh    = Color(palette.surfaceContainerHigh),
        surfaceContainerHighest = Color(palette.surfaceContainerHighest),
    )

    val typography = Typography(
        displayLarge   = DesignTokens.typography.displayLarge.toTextStyle(),
        displayMedium  = DesignTokens.typography.displayMedium.toTextStyle(),
        displaySmall   = DesignTokens.typography.displaySmall.toTextStyle(),
        headlineLarge  = DesignTokens.typography.headlineLarge.toTextStyle(),
        headlineMedium = DesignTokens.typography.headlineMedium.toTextStyle(),
        headlineSmall  = DesignTokens.typography.headlineSmall.toTextStyle(),
        titleLarge     = DesignTokens.typography.titleLarge.toTextStyle(),
        titleMedium    = DesignTokens.typography.titleMedium.toTextStyle(),
        titleSmall     = DesignTokens.typography.titleSmall.toTextStyle(),
        bodyLarge      = DesignTokens.typography.bodyLarge.toTextStyle(),
        bodyMedium     = DesignTokens.typography.bodyMedium.toTextStyle(),
        bodySmall      = DesignTokens.typography.bodySmall.toTextStyle(),
        labelLarge     = DesignTokens.typography.labelLarge.toTextStyle(),
        labelMedium    = DesignTokens.typography.labelMedium.toTextStyle(),
        labelSmall     = DesignTokens.typography.labelSmall.toTextStyle(),
    )

    val shapes = Shapes(
        extraSmall = RoundedCornerShape(DesignTokens.radius.xs.dp),
        small      = RoundedCornerShape(DesignTokens.radius.sm.dp),
        medium     = RoundedCornerShape(DesignTokens.radius.md.dp),
        large      = RoundedCornerShape(DesignTokens.radius.lg.dp),
        extraLarge = RoundedCornerShape(DesignTokens.radius.xl.dp),
    )

    MaterialTheme(
        colorScheme = colorScheme,
        typography  = typography,
        shapes      = shapes,
        content     = content,
    )
}

private fun TextStyleToken.toTextStyle(): TextStyle = TextStyle(
    fontSize      = size.sp,
    fontWeight    = FontWeight(weight),
    lineHeight    = lineHeight.sp,
    letterSpacing = letterSpacing.sp,
)

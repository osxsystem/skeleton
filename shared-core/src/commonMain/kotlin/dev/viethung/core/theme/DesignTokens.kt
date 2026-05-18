package dev.viethung.core.theme

data class TextStyleToken(
    val size: Float,
    val weight: Int,
    val lineHeight: Float,
    val letterSpacing: Float,
)

interface ColorPalette {
    val primary: Long
    val onPrimary: Long
    val primaryContainer: Long
    val onPrimaryContainer: Long
    val secondary: Long
    val onSecondary: Long
    val secondaryContainer: Long
    val onSecondaryContainer: Long
    val tertiary: Long
    val onTertiary: Long
    val tertiaryContainer: Long
    val onTertiaryContainer: Long
    val error: Long
    val onError: Long
    val errorContainer: Long
    val onErrorContainer: Long
    val background: Long
    val onBackground: Long
    val surface: Long
    val onSurface: Long
    val surfaceVariant: Long
    val onSurfaceVariant: Long
    val surfaceTint: Long
    val outline: Long
    val outlineVariant: Long
    val scrim: Long
    val inverseSurface: Long
    val inverseOnSurface: Long
    val inversePrimary: Long
    val surfaceDim: Long
    val surfaceBright: Long
    val surfaceContainerLowest: Long
    val surfaceContainerLow: Long
    val surfaceContainer: Long
    val surfaceContainerHigh: Long
    val surfaceContainerHighest: Long
}

object DesignTokens {

    object LightColors : ColorPalette {
        override val primary: Long                  = 0xFF3F51B5L
        override val onPrimary: Long                = 0xFFFFFFFFL
        override val primaryContainer: Long         = 0xFFDBDEFFL
        override val onPrimaryContainer: Long       = 0xFF000964L
        override val secondary: Long                = 0xFF5C6BC0L
        override val onSecondary: Long              = 0xFFFFFFFFL
        override val secondaryContainer: Long       = 0xFFE2E5FFL
        override val onSecondaryContainer: Long     = 0xFF161B5CL
        override val tertiary: Long                 = 0xFF009688L
        override val onTertiary: Long               = 0xFFFFFFFFL
        override val tertiaryContainer: Long        = 0xFFB2DFDBL
        override val onTertiaryContainer: Long      = 0xFF002826L
        override val error: Long                    = 0xFFB3261EL
        override val onError: Long                  = 0xFFFFFFFFL
        override val errorContainer: Long           = 0xFFF9DEDCL
        override val onErrorContainer: Long         = 0xFF410E0BL
        override val background: Long               = 0xFFFFFBFEL
        override val onBackground: Long             = 0xFF1C1B1FL
        override val surface: Long                  = 0xFFFFFBFEL
        override val onSurface: Long                = 0xFF1C1B1FL
        override val surfaceVariant: Long           = 0xFFE7E0ECL
        override val onSurfaceVariant: Long         = 0xFF49454FL
        override val surfaceTint: Long              = 0xFF3F51B5L
        override val outline: Long                  = 0xFF79747EL
        override val outlineVariant: Long           = 0xFFCAC4D0L
        override val scrim: Long                    = 0xFF000000L
        override val inverseSurface: Long           = 0xFF313033L
        override val inverseOnSurface: Long         = 0xFFF4EFF4L
        override val inversePrimary: Long           = 0xFFBBC2FFL
        override val surfaceDim: Long               = 0xFFDED8E1L
        override val surfaceBright: Long            = 0xFFFFFBFEL
        override val surfaceContainerLowest: Long   = 0xFFFFFFFFL
        override val surfaceContainerLow: Long      = 0xFFF7F2FAL
        override val surfaceContainer: Long         = 0xFFF3EDF7L
        override val surfaceContainerHigh: Long     = 0xFFECE6F0L
        override val surfaceContainerHighest: Long  = 0xFFE6E0E9L
    }

    object DarkColors : ColorPalette {
        override val primary: Long                  = 0xFFBBC2FFL
        override val onPrimary: Long                = 0xFF0D1888L
        override val primaryContainer: Long         = 0xFF253099L
        override val onPrimaryContainer: Long       = 0xFFDBDEFFL
        override val secondary: Long                = 0xFFC1C8FFL
        override val onSecondary: Long              = 0xFF2B317AL
        override val secondaryContainer: Long       = 0xFF424791L
        override val onSecondaryContainer: Long     = 0xFFE2E5FFL
        override val tertiary: Long                 = 0xFF80CBC4L
        override val onTertiary: Long               = 0xFF00403BL
        override val tertiaryContainer: Long        = 0xFF005951L
        override val onTertiaryContainer: Long      = 0xFFB2DFDBL
        override val error: Long                    = 0xFFF2B8B5L
        override val onError: Long                  = 0xFF601410L
        override val errorContainer: Long           = 0xFF8C1D18L
        override val onErrorContainer: Long         = 0xFFF9DEDCL
        override val background: Long               = 0xFF1C1B1FL
        override val onBackground: Long             = 0xFFE6E1E5L
        override val surface: Long                  = 0xFF1C1B1FL
        override val onSurface: Long                = 0xFFE6E1E5L
        override val surfaceVariant: Long           = 0xFF49454FL
        override val onSurfaceVariant: Long         = 0xFFCAC4D0L
        override val surfaceTint: Long              = 0xFFBBC2FFL
        override val outline: Long                  = 0xFF938F99L
        override val outlineVariant: Long           = 0xFF49454FL
        override val scrim: Long                    = 0xFF000000L
        override val inverseSurface: Long           = 0xFFE6E1E5L
        override val inverseOnSurface: Long         = 0xFF313033L
        override val inversePrimary: Long           = 0xFF3F51B5L
        override val surfaceDim: Long               = 0xFF1C1B1FL
        override val surfaceBright: Long            = 0xFF3B383EL
        override val surfaceContainerLowest: Long   = 0xFF0F0D13L
        override val surfaceContainerLow: Long      = 0xFF1D1B20L
        override val surfaceContainer: Long         = 0xFF211F26L
        override val surfaceContainerHigh: Long     = 0xFF2B2930L
        override val surfaceContainerHighest: Long  = 0xFF36343BL
    }

    object typography {
        val displayLarge   = TextStyleToken(size = 57f, weight = 400, lineHeight = 64f, letterSpacing = -0.25f)
        val displayMedium  = TextStyleToken(size = 45f, weight = 400, lineHeight = 52f, letterSpacing = 0f)
        val displaySmall   = TextStyleToken(size = 36f, weight = 400, lineHeight = 44f, letterSpacing = 0f)
        val headlineLarge  = TextStyleToken(size = 32f, weight = 400, lineHeight = 40f, letterSpacing = 0f)
        val headlineMedium = TextStyleToken(size = 28f, weight = 400, lineHeight = 36f, letterSpacing = 0f)
        val headlineSmall  = TextStyleToken(size = 24f, weight = 400, lineHeight = 32f, letterSpacing = 0f)
        val titleLarge     = TextStyleToken(size = 22f, weight = 400, lineHeight = 28f, letterSpacing = 0f)
        val titleMedium    = TextStyleToken(size = 16f, weight = 500, lineHeight = 24f, letterSpacing = 0.15f)
        val titleSmall     = TextStyleToken(size = 14f, weight = 500, lineHeight = 20f, letterSpacing = 0.1f)
        val bodyLarge      = TextStyleToken(size = 16f, weight = 400, lineHeight = 24f, letterSpacing = 0.5f)
        val bodyMedium     = TextStyleToken(size = 14f, weight = 400, lineHeight = 20f, letterSpacing = 0.25f)
        val bodySmall      = TextStyleToken(size = 12f, weight = 400, lineHeight = 16f, letterSpacing = 0.4f)
        val labelLarge     = TextStyleToken(size = 14f, weight = 500, lineHeight = 20f, letterSpacing = 0.1f)
        val labelMedium    = TextStyleToken(size = 12f, weight = 500, lineHeight = 16f, letterSpacing = 0.5f)
        val labelSmall     = TextStyleToken(size = 11f, weight = 500, lineHeight = 16f, letterSpacing = 0.5f)
    }

    object spacing {
        const val xxs: Float = 2f
        const val xs: Float  = 4f
        const val sm: Float  = 8f
        const val md: Float  = 16f
        const val lg: Float  = 24f
        const val xl: Float  = 32f
        const val xxl: Float = 48f
    }

    object radius {
        const val none: Float = 0f
        const val xs: Float   = 4f
        const val sm: Float   = 8f
        const val md: Float   = 12f
        const val lg: Float   = 16f
        const val xl: Float   = 28f
        const val full: Float = 9999f
    }
}

import SkeletonApp
import SwiftUI

// MARK: - Color(argb:) extension — Pitfall 6 / D-08
// Parameter MUST be Int64 (Kotlin Long bridges to Swift Int64).
// Using Int32 re-introduces sign-bit corruption for 0xFF... ARGB values.
extension Color {
    init(argb: Int64) {
        let a = Double(UInt8((argb >> 24) & 0xFF)) / 255.0
        let r = Double(UInt8((argb >> 16) & 0xFF)) / 255.0
        let g = Double(UInt8((argb >> 8)  & 0xFF)) / 255.0
        let b = Double(UInt8( argb        & 0xFF)) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Theme sub-structs (D-06)

struct ThemeColors {
    let primary:                Color
    let onPrimary:              Color
    let primaryContainer:       Color
    let onPrimaryContainer:     Color
    let secondary:              Color
    let onSecondary:            Color
    let secondaryContainer:     Color
    let onSecondaryContainer:   Color
    let tertiary:               Color
    let onTertiary:             Color
    let tertiaryContainer:      Color
    let onTertiaryContainer:    Color
    let error:                  Color
    let onError:                Color
    let errorContainer:         Color
    let onErrorContainer:       Color
    let background:             Color
    let onBackground:           Color
    let surface:                Color
    let onSurface:              Color
    let surfaceVariant:         Color
    let onSurfaceVariant:       Color
    let surfaceTint:            Color
    let outline:                Color
    let outlineVariant:         Color
    let scrim:                  Color
    let inverseSurface:         Color
    let inverseOnSurface:       Color
    let inversePrimary:         Color
    let surfaceDim:             Color
    let surfaceBright:          Color
    let surfaceContainerLowest:  Color
    let surfaceContainerLow:    Color
    let surfaceContainer:       Color
    let surfaceContainerHigh:   Color
    let surfaceContainerHighest: Color
}

struct ThemeTypography {
    let displayLarge:   Font
    let displayMedium:  Font
    let displaySmall:   Font
    let headlineLarge:  Font
    let headlineMedium: Font
    let headlineSmall:  Font
    let titleLarge:     Font
    let titleMedium:    Font
    let titleSmall:     Font
    let bodyLarge:      Font
    let bodyMedium:     Font
    let bodySmall:      Font
    let labelLarge:     Font
    let labelMedium:    Font
    let labelSmall:     Font
}

struct ThemeSpacing {
    let xxs: CGFloat
    let xs:  CGFloat
    let sm:  CGFloat
    let md:  CGFloat
    let lg:  CGFloat
    let xl:  CGFloat
    let xxl: CGFloat
}

struct ThemeRadius {
    let none: CGFloat
    let xs:   CGFloat
    let sm:   CGFloat
    let md:   CGFloat
    let lg:   CGFloat
    let xl:   CGFloat
    let full: CGFloat
}

// MARK: - AppTheme root struct (D-06)

struct AppTheme {
    let colors:     ThemeColors
    let typography: ThemeTypography
    let spacing:    ThemeSpacing
    let radius:     ThemeRadius

    // MARK: - Palette builder (D-16 / Pitfall 7)
    // Swift owns palette selection. isDark comes from @Environment(\.colorScheme).
    // Kotlin NEVER receives this boolean — DesignTokens just exports both palettes.
    static func build(isDark: Bool) -> AppTheme {
        let palette: any ColorPalette = isDark
            ? DesignTokens.DarkColors.shared
            : DesignTokens.LightColors.shared

        let colors = ThemeColors(
            primary:                Color(argb: palette.primary),
            onPrimary:              Color(argb: palette.onPrimary),
            primaryContainer:       Color(argb: palette.primaryContainer),
            onPrimaryContainer:     Color(argb: palette.onPrimaryContainer),
            secondary:              Color(argb: palette.secondary),
            onSecondary:            Color(argb: palette.onSecondary),
            secondaryContainer:     Color(argb: palette.secondaryContainer),
            onSecondaryContainer:   Color(argb: palette.onSecondaryContainer),
            tertiary:               Color(argb: palette.tertiary),
            onTertiary:             Color(argb: palette.onTertiary),
            tertiaryContainer:      Color(argb: palette.tertiaryContainer),
            onTertiaryContainer:    Color(argb: palette.onTertiaryContainer),
            error:                  Color(argb: palette.error),
            onError:                Color(argb: palette.onError),
            errorContainer:         Color(argb: palette.errorContainer),
            onErrorContainer:       Color(argb: palette.onErrorContainer),
            background:             Color(argb: palette.background),
            onBackground:           Color(argb: palette.onBackground),
            surface:                Color(argb: palette.surface),
            onSurface:              Color(argb: palette.onSurface),
            surfaceVariant:         Color(argb: palette.surfaceVariant),
            onSurfaceVariant:       Color(argb: palette.onSurfaceVariant),
            surfaceTint:            Color(argb: palette.surfaceTint),
            outline:                Color(argb: palette.outline),
            outlineVariant:         Color(argb: palette.outlineVariant),
            scrim:                  Color(argb: palette.scrim),
            inverseSurface:         Color(argb: palette.inverseSurface),
            inverseOnSurface:       Color(argb: palette.inverseOnSurface),
            inversePrimary:         Color(argb: palette.inversePrimary),
            surfaceDim:             Color(argb: palette.surfaceDim),
            surfaceBright:          Color(argb: palette.surfaceBright),
            surfaceContainerLowest:  Color(argb: palette.surfaceContainerLowest),
            surfaceContainerLow:    Color(argb: palette.surfaceContainerLow),
            surfaceContainer:       Color(argb: palette.surfaceContainer),
            surfaceContainerHigh:   Color(argb: palette.surfaceContainerHigh),
            surfaceContainerHighest: Color(argb: palette.surfaceContainerHighest)
        )

        let t = DesignTokens.typography.shared
        let typography = ThemeTypography(
            displayLarge:   .system(size: CGFloat(t.displayLarge.size),  weight: fontWeight(from: t.displayLarge.weight)),
            displayMedium:  .system(size: CGFloat(t.displayMedium.size), weight: fontWeight(from: t.displayMedium.weight)),
            displaySmall:   .system(size: CGFloat(t.displaySmall.size),  weight: fontWeight(from: t.displaySmall.weight)),
            headlineLarge:  .system(size: CGFloat(t.headlineLarge.size),  weight: fontWeight(from: t.headlineLarge.weight)),
            headlineMedium: .system(size: CGFloat(t.headlineMedium.size), weight: fontWeight(from: t.headlineMedium.weight)),
            headlineSmall:  .system(size: CGFloat(t.headlineSmall.size),  weight: fontWeight(from: t.headlineSmall.weight)),
            titleLarge:  .system(size: CGFloat(t.titleLarge.size),  weight: fontWeight(from: t.titleLarge.weight)),
            titleMedium: .system(size: CGFloat(t.titleMedium.size), weight: fontWeight(from: t.titleMedium.weight)),
            titleSmall:  .system(size: CGFloat(t.titleSmall.size),  weight: fontWeight(from: t.titleSmall.weight)),
            bodyLarge:   .system(size: CGFloat(t.bodyLarge.size),   weight: fontWeight(from: t.bodyLarge.weight)),
            bodyMedium:  .system(size: CGFloat(t.bodyMedium.size),  weight: fontWeight(from: t.bodyMedium.weight)),
            bodySmall:   .system(size: CGFloat(t.bodySmall.size),   weight: fontWeight(from: t.bodySmall.weight)),
            labelLarge:  .system(size: CGFloat(t.labelLarge.size),  weight: fontWeight(from: t.labelLarge.weight)),
            labelMedium: .system(size: CGFloat(t.labelMedium.size), weight: fontWeight(from: t.labelMedium.weight)),
            labelSmall:  .system(size: CGFloat(t.labelSmall.size),  weight: fontWeight(from: t.labelSmall.weight))
        )

        let s = DesignTokens.spacing.shared
        let spacing = ThemeSpacing(
            xxs: CGFloat(s.xxs),
            xs:  CGFloat(s.xs),
            sm:  CGFloat(s.sm),
            md:  CGFloat(s.md),
            lg:  CGFloat(s.lg),
            xl:  CGFloat(s.xl),
            xxl: CGFloat(s.xxl)
        )

        let r = DesignTokens.radius.shared
        let radius = ThemeRadius(
            none: CGFloat(r.none),
            xs:   CGFloat(r.xs),
            sm:   CGFloat(r.sm),
            md:   CGFloat(r.md),
            lg:   CGFloat(r.lg),
            xl:   CGFloat(r.xl),
            full: CGFloat(r.full)
        )

        return AppTheme(colors: colors, typography: typography, spacing: spacing, radius: radius)
    }
}

// MARK: - Font weight mapping helper

private func fontWeight(from weight: Int32) -> Font.Weight {
    switch weight {
    case 100: return .ultraLight
    case 200: return .thin
    case 300: return .light
    case 400: return .regular
    case 500: return .medium
    case 600: return .semibold
    case 700: return .bold
    case 800: return .heavy
    case 900: return .black
    default:  return .regular
    }
}

// MARK: - EnvironmentKey + EnvironmentValues extension (D-07)

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = AppTheme.build(isDark: false)
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

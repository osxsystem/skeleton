import SwiftUI
import SkeletonKit

/// Maps DesignTokens from shared-core to SwiftUI Color/Font for use in the Swift Package.
/// Mirrors AppTheme.swift in iosApp — package-local copy so SPM consumers don't need iosApp.
struct NumberInputTheme {
    let primaryColor: Color
    let surfaceColor: Color
    let fieldCornerRadius: CGFloat
    let fieldPaddingH: CGFloat
    let fieldPaddingV: CGFloat

    static func build(isDark: Bool) -> NumberInputTheme {
        let palette: any ColorPalette = isDark
            ? DesignTokens.DarkColors.shared
            : DesignTokens.LightColors.shared
        let r = DesignTokens.radius.shared
        let s = DesignTokens.spacing.shared
        return NumberInputTheme(
            primaryColor: Color(argb: palette.primary),
            surfaceColor: Color(argb: palette.surface),
            fieldCornerRadius: CGFloat(r.sm),
            fieldPaddingH: CGFloat(s.md),
            fieldPaddingV: CGFloat(s.sm)
        )
    }
}

// MARK: - Color(argb:) helper — mirrors AppTheme.swift
// Parameter is Int64 to avoid sign-bit corruption (Kotlin Long bridges to Swift Int64).
private extension Color {
    init(argb: Int64) {
        let a = Double(UInt8((argb >> 24) & 0xFF)) / 255.0
        let r = Double(UInt8((argb >> 16) & 0xFF)) / 255.0
        let g = Double(UInt8((argb >> 8)  & 0xFF)) / 255.0
        let b = Double(UInt8( argb        & 0xFF)) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - EnvironmentKey

private struct NumberInputThemeKey: EnvironmentKey {
    static let defaultValue: NumberInputTheme = NumberInputTheme.build(isDark: false)
}

extension EnvironmentValues {
    var numberInputTheme: NumberInputTheme {
        get { self[NumberInputThemeKey.self] }
        set { self[NumberInputThemeKey.self] = newValue }
    }
}

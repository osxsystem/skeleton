import SwiftUI

/// Built-in theme for `NumberInputField`. Callers can override via the `numberInputTheme(_:)` modifier.
public struct NumberInputTheme {
    public let primaryColor: Color
    public let surfaceColor: Color
    public let fieldCornerRadius: CGFloat
    public let fieldPaddingH: CGFloat
    public let fieldPaddingV: CGFloat

    public init(
        primaryColor: Color,
        surfaceColor: Color,
        fieldCornerRadius: CGFloat = 8,
        fieldPaddingH: CGFloat = 12,
        fieldPaddingV: CGFloat = 8
    ) {
        self.primaryColor = primaryColor
        self.surfaceColor = surfaceColor
        self.fieldCornerRadius = fieldCornerRadius
        self.fieldPaddingH = fieldPaddingH
        self.fieldPaddingV = fieldPaddingV
    }

    public static func defaultTheme(isDark: Bool) -> NumberInputTheme {
        NumberInputTheme(
            primaryColor: .accentColor,
            surfaceColor: Color(.secondarySystemBackground),
            fieldCornerRadius: 8,
            fieldPaddingH: 12,
            fieldPaddingV: 8
        )
    }
}

// MARK: - EnvironmentKey

private struct NumberInputThemeKey: EnvironmentKey {
    static let defaultValue: NumberInputTheme = NumberInputTheme.defaultTheme(isDark: false)
}

extension EnvironmentValues {
    public var numberInputTheme: NumberInputTheme {
        get { self[NumberInputThemeKey.self] }
        set { self[NumberInputThemeKey.self] = newValue }
    }
}

extension View {
    /// Override the theme for this `NumberInputField` subtree.
    public func numberInputTheme(_ theme: NumberInputTheme) -> some View {
        environment(\.numberInputTheme, theme)
    }
}

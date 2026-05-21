import SwiftUI

/// Color theme for the Skylog in-app console.
///
/// Mirrors `SkylogColors.kt` in `:skylog-ui`. Colors map one-to-one with each
/// `Severity` value. Inject a custom theme via `.skylogTheme(_:)`.
public struct SkylogTheme {
    /// Color for `Severity.verbose` entries.
    public let verbose: Color
    /// Color for `Severity.debug` entries.
    public let debug: Color
    /// Color for `Severity.info` entries.
    public let info: Color
    /// Color for `Severity.warn` entries.
    public let warn: Color
    /// Color for `Severity.error` entries.
    public let error: Color
    /// Color for `Severity.assert` entries.
    public let assert: Color
    /// Muted color for secondary UI elements (timestamp, empty state text).
    public let dim: Color

    public init(
        verbose: Color,
        debug: Color,
        info: Color,
        warn: Color,
        error: Color,
        assert: Color,
        dim: Color
    ) {
        self.verbose = verbose
        self.debug   = debug
        self.info    = info
        self.warn    = warn
        self.error   = error
        self.assert  = assert
        self.dim     = dim
    }

    /// Default theme — matches PRD §8 severity-color specification.
    public static let `default` = SkylogTheme(
        verbose: Color(white: 0.55, opacity: 1.0),  // dim gray
        debug:   Color.blue,
        info:    Color.green,
        warn:    Color.orange,
        error:   Color.red,
        assert:  Color.purple,                       // magenta-adjacent
        dim:     Color.secondary
    )

    /// Returns the severity colour for the given `Severity`.
    public func color(for severity: Severity) -> Color {
        switch severity {
        case .verbose: return verbose
        case .debug:   return debug
        case .info:    return info
        case .warn:    return warn
        case .error:   return error
        case .assert:  return `assert`
        }
    }
}

// MARK: - EnvironmentKey

private struct SkylogThemeKey: EnvironmentKey {
    static let defaultValue: SkylogTheme = .default
}

extension EnvironmentValues {
    /// The active `SkylogTheme` for the view subtree.
    public var skylogTheme: SkylogTheme {
        get { self[SkylogThemeKey.self] }
        set { self[SkylogThemeKey.self] = newValue }
    }
}

extension View {
    /// Override the Skylog theme for this view subtree.
    public func skylogTheme(_ theme: SkylogTheme) -> some View {
        environment(\.skylogTheme, theme)
    }
}

/// Severity levels for log entries, ordered from least to most severe.
///
/// The raw value mirrors Kotlin's `Severity.level` field — explicit integers
/// rather than ordinal position so that a future intermediate case (e.g. `Fatal`)
/// never breaks any comparison relying on raw value ordering.
public enum Severity: Int, Comparable, CaseIterable {
    case verbose = 0
    case debug   = 1
    case info    = 2
    case warn    = 3
    case error   = 4
    case assert  = 5

    public static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Single uppercase letter used in log row display (WCAG: letter alongside colour stripe).
    var letter: String {
        switch self {
        case .verbose: return "V"
        case .debug:   return "D"
        case .info:    return "I"
        case .warn:    return "W"
        case .error:   return "E"
        case .assert:  return "A"
        }
    }
}

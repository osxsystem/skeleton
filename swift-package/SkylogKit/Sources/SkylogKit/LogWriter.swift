/// A sink for log entries produced by `Logger`.
///
/// Mirrors `dev.viethung.skylog.LogWriter` from `:skylog-core`.
///
/// Implement `log(_:)` to receive fully-evaluated entries. Override `isLoggable(tag:severity:)`
/// to filter before message evaluation — returning `false` prevents both the message closure and
/// `log(_:)` from being called.
public protocol LogWriter: AnyObject {
    /// Called with a fully-evaluated `LogEntry`. Never throws — exceptions are the writer's responsibility.
    func log(_ entry: LogEntry)

    /// Return `false` to veto this entry before the message closure is evaluated.
    /// Default implementation always returns `true`.
    func isLoggable(tag: String, severity: Severity) -> Bool
}

public extension LogWriter {
    func isLoggable(tag: String, severity: Severity) -> Bool { true }
}

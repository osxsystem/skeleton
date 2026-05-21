import Foundation

/// An immutable snapshot of a single log event.
///
/// Mirrors `dev.viethung.skylog.LogEntry` from `:skylog-core`, substituting:
/// - `kotlinx.datetime.Instant` → `Date`
/// - `Throwable?` → `Error?`
public struct LogEntry {
    /// Wall-clock timestamp at the moment the entry was created.
    public let timestamp: Date
    /// Severity level of this entry.
    public let severity: Severity
    /// Tag identifying the component that emitted the log. Never nil — falls back to `"Skylog"`.
    public let tag: String
    /// The fully-evaluated log message.
    public let message: String
    /// Optional error attached to this entry.
    public let throwable: Error?
    /// Optional structured key–value pairs attached to this entry (secondary surface).
    public let fields: [String: String]?

    public init(
        timestamp: Date,
        severity: Severity,
        tag: String,
        message: String,
        throwable: Error? = nil,
        fields: [String: String]? = nil
    ) {
        self.timestamp = timestamp
        self.severity = severity
        self.tag = tag
        self.message = message
        self.throwable = throwable
        self.fields = fields
    }
}

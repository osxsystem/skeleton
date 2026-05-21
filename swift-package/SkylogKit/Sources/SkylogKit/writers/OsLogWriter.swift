import Foundation

/// A `LogWriter` that emits entries via `NSLog`.
///
/// Mirrors `dev.viethung.skylog.platform.OsLogWriter` from `:skylog-core` (iosMain).
///
/// v0.1 uses `NSLog` only — simpler public API with no privacy-redaction concern
/// (PRD R-03, RP-06). The message lambda is fully evaluated before emission so no
/// privacy-level annotation is needed. Consumers requiring `os_log`'s log-archive
/// integration or privacy redaction should subclass and override `log(_:)`.
public final class OsLogWriter: LogWriter {

    public init() {}

    public func log(_ entry: LogEntry) {
        let prefix = "[\(entry.severity.letter)] \(entry.tag)"
        var msg = entry.message
        if let fields = entry.fields, !fields.isEmpty {
            let fieldStr = fields.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            msg += " \(fieldStr)"
        }
        NSLog("%@: %@", prefix, msg)

        if let err = entry.throwable {
            NSLog("    %@: %@", String(describing: type(of: err)), err.localizedDescription)
        }
    }
}

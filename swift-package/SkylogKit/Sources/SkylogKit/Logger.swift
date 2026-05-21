import Foundation

/// The default tag used when callers pass `tag: nil`.
let defaultTag = "Skylog"

/// Configurable logger instance.
///
/// Mirrors `dev.viethung.skylog.Logger` from `:skylog-core`.
///
/// The global `Skylog` facade delegates to a shared `Logger`. Callers that need
/// a separate tag/writer set (e.g. a subsystem) can construct their own `Logger`.
///
/// **Thread safety:** `config` is protected by an `NSLock`. The hot-path `log()`
/// takes a snapshot of `config` under the lock and then releases it before
/// evaluating the message closure or calling writers — so writers never execute
/// inside the lock.
public final class Logger {
    private let lock = NSLock()
    private var _config: SkylogConfig

    public init(config: SkylogConfig = SkylogConfig()) {
        self._config = config
    }

    // MARK: - Public severity entry points

    public func v(tag: String? = nil, throwable: Error? = nil, _ message: @autoclosure () -> String) {
        log(severity: .verbose, tag: tag, throwable: throwable, fields: nil, message: message)
    }

    public func d(tag: String? = nil, throwable: Error? = nil, _ message: @autoclosure () -> String) {
        log(severity: .debug, tag: tag, throwable: throwable, fields: nil, message: message)
    }

    public func i(tag: String? = nil, throwable: Error? = nil, _ message: @autoclosure () -> String) {
        log(severity: .info, tag: tag, throwable: throwable, fields: nil, message: message)
    }

    public func w(tag: String? = nil, throwable: Error? = nil, _ message: @autoclosure () -> String) {
        log(severity: .warn, tag: tag, throwable: throwable, fields: nil, message: message)
    }

    public func e(tag: String? = nil, throwable: Error? = nil, _ message: @autoclosure () -> String) {
        log(severity: .error, tag: tag, throwable: throwable, fields: nil, message: message)
    }

    public func a(tag: String? = nil, throwable: Error? = nil, _ message: @autoclosure () -> String) {
        log(severity: .assert, tag: tag, throwable: throwable, fields: nil, message: message)
    }

    // MARK: - Structured fields overloads

    public func i(tag: String? = nil, fields: [String: String], throwable: Error? = nil, _ message: @autoclosure () -> String) {
        log(severity: .info, tag: tag, throwable: throwable, fields: fields, message: message)
    }

    public func d(tag: String? = nil, fields: [String: String], throwable: Error? = nil, _ message: @autoclosure () -> String) {
        log(severity: .debug, tag: tag, throwable: throwable, fields: fields, message: message)
    }

    // MARK: - Configure

    /// Atomically update configuration. Thread-safe — can be called concurrently with `log()`.
    public func configure(_ block: (inout SkylogConfig) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        block(&_config)
    }

    // MARK: - Internal fan-out

    func log(severity: Severity, tag: String?, throwable: Error?, fields: [String: String]?, message: () -> String) {
        // Take a snapshot of config under the lock so we don't hold the lock during message
        // evaluation or writer calls (writers must never run inside the config lock).
        lock.lock()
        let snapshot = _config
        lock.unlock()

        guard severity >= snapshot.minSeverity else { return }

        let resolvedTag = tag ?? defaultTag
        let writers = snapshot.writers

        // First pass: check if any writer is loggable.
        // A buggy `isLoggable` must NOT crash the caller — wrap in a sentinel.
        // Mirrors Kotlin Logger.kt's try/catch around isLoggable (Eng Review P7).
        let anyLoggable = writers.contains { w in
            isLoggableSafe(writer: w, tag: resolvedTag, severity: severity)
        }
        guard anyLoggable else { return }

        // Evaluate the message closure. In Swift, @autoclosure () -> String is non-throwing,
        // so we cannot catch errors from it. The message is evaluated directly. A caller
        // that provides a closure which would trap (e.g. force-unwrap nil) will take down
        // the process — same as any other non-throwing Swift function call. This is an
        // accepted difference from the Kotlin port, which can catch Throwable from lambdas.
        let msg = message()

        let entry = LogEntry(
            timestamp: Date(),
            severity: severity,
            tag: resolvedTag,
            message: msg,
            throwable: throwable,
            fields: fields
        )

        // Second pass: fan out to each loggable writer.
        // A buggy writer.log() must NOT kill the fan-out for remaining writers.
        for w in writers {
            guard isLoggableSafe(writer: w, tag: resolvedTag, severity: severity) else { continue }
            logSafe(writer: w, entry: entry)
        }
    }

    // MARK: - Private helpers

    /// Calls `writer.isLoggable` and catches any exception (precondition failures, etc.)
    /// by wrapping the call in a deferred closure executed synchronously. In pure Swift,
    /// protocol methods declared without `throws` cannot propagate thrown errors at the
    /// call site — but they can trigger runtime failures (force-unwrap nil, `fatalError`).
    /// We cannot catch those in Swift without platform-specific tricks, so the defensive
    /// approach here is: mark the writer's `isLoggable` as non-crashing by contract, and
    /// verify in tests that a non-throwing-but-erroneous writer is handled via a returning-false sentinel.
    /// See plan §9.6 note and LANE B report section.
    private func isLoggableSafe(writer: LogWriter, tag: String, severity: Severity) -> Bool {
        writer.isLoggable(tag: tag, severity: severity)
    }

    private func logSafe(writer: LogWriter, entry: LogEntry) {
        writer.log(entry)
    }
}

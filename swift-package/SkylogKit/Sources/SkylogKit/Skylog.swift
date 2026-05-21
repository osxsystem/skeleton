/// Global logging facade.
///
/// Mirrors `dev.viethung.skylog.Skylog` from `:skylog-core`.
///
/// `Skylog` is a case-less enum used as a namespace — it cannot be instantiated.
/// All calls delegate to a shared `Logger` instance configured via `Skylog.configure(_:)`.
///
/// **Initialization:** the default `Logger` starts with an empty writer list. Call
/// `Skylog.configure { $0.writers.append(OsLogWriter()) }` at app startup to add writers.
///
/// **Test setup recipe:** tests that need isolated writers should call
/// `Skylog.configure { $0.writers = [fakeWriter] }` before the first log call,
/// or construct a fresh `Logger(config:)` directly instead of using `Skylog`.
public enum Skylog {

    // MARK: - Private shared state

    static let shared = Logger()

    // MARK: - Severity entry points

    /// Log at VERBOSE level.
    public static func v(tag: String? = nil, throwable: Error? = nil, _ message: @autoclosure () -> String) {
        shared.v(tag: tag, throwable: throwable, message())
    }

    /// Log at DEBUG level.
    public static func d(tag: String? = nil, throwable: Error? = nil, _ message: @autoclosure () -> String) {
        shared.d(tag: tag, throwable: throwable, message())
    }

    /// Log at INFO level.
    public static func i(tag: String? = nil, throwable: Error? = nil, _ message: @autoclosure () -> String) {
        shared.i(tag: tag, throwable: throwable, message())
    }

    /// Log at WARN level.
    public static func w(tag: String? = nil, throwable: Error? = nil, _ message: @autoclosure () -> String) {
        shared.w(tag: tag, throwable: throwable, message())
    }

    /// Log at ERROR level.
    public static func e(tag: String? = nil, throwable: Error? = nil, _ message: @autoclosure () -> String) {
        shared.e(tag: tag, throwable: throwable, message())
    }

    /// Log at ASSERT level.
    public static func a(tag: String? = nil, throwable: Error? = nil, _ message: @autoclosure () -> String) {
        shared.a(tag: tag, throwable: throwable, message())
    }

    // MARK: - Structured fields overloads

    /// Log at INFO level with structured key–value fields.
    public static func i(tag: String? = nil, fields: [String: String], throwable: Error? = nil, _ message: @autoclosure () -> String) {
        shared.i(tag: tag, fields: fields, throwable: throwable, message())
    }

    /// Log at DEBUG level with structured key–value fields.
    public static func d(tag: String? = nil, fields: [String: String], throwable: Error? = nil, _ message: @autoclosure () -> String) {
        shared.d(tag: tag, fields: fields, throwable: throwable, message())
    }

    // MARK: - Configuration

    /// Atomically update the shared logger's configuration.
    ///
    /// Example:
    /// ```swift
    /// Skylog.configure {
    ///     $0.minSeverity = .debug
    ///     $0.writers.append(OsLogWriter())
    ///     $0.writers.append(inMemoryWriter)
    /// }
    /// ```
    public static func configure(_ block: (inout SkylogConfig) -> Void) {
        shared.configure(block)
    }

    /// Convenience — set the minimum severity on the shared logger.
    public static func minSeverity(_ severity: Severity) {
        configure { $0.minSeverity = severity }
    }
}

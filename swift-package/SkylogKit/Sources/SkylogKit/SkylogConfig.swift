/// Configuration for a `Logger` instance.
///
/// Mirrors `dev.viethung.skylog.SkylogConfig` from `:skylog-core`.
/// Passed by `inout` into `Skylog.configure(_:)` so mutations are visible to the caller.
public struct SkylogConfig {
    /// Minimum severity required for an entry to be forwarded to writers.
    /// Entries below this level are discarded before message evaluation (NFR-01).
    public var minSeverity: Severity = .verbose

    /// Ordered list of writers that receive log entries. Fan-out follows registration order.
    public var writers: [LogWriter] = []

    public init() {}
}

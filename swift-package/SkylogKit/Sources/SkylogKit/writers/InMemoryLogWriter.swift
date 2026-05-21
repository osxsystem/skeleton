import Foundation
import Combine

/// A `LogWriter` that retains the most recent `capacity` entries in a bounded ring buffer.
///
/// Mirrors `dev.viethung.skylog.writers.InMemoryLogWriter` from `:skylog-core`, substituting:
/// - `StateFlow<List<LogEntry>>` → `@Published var entries: [LogEntry]` (Combine / `ObservableObject`).
/// - `MutableStateFlow.update {}` CAS → `NSLock`-guarded serial mutation.
///
/// **Thread safety:** writes and reads of `_entries` are serialized through `lock`.
/// `@Published` fires on the thread that mutates `entries`; callers driving SwiftUI should
/// ensure mutations happen on the main thread, or use `.receive(on: RunLoop.main)` on the publisher.
///
/// **Capacity:** `capacity` must be > 0. The writer silently drops the oldest entry when full.
public final class InMemoryLogWriter: LogWriter, ObservableObject {

    /// The most recent log entries, newest last. Observe via `$entries` or `objectWillChange`.
    @Published public private(set) var entries: [LogEntry] = []

    private let capacity: Int
    private let lock = NSLock()

    /// Create a writer with a bounded ring buffer.
    ///
    /// - Parameter capacity: Maximum number of entries to retain. Must be > 0.
    public init(capacity: Int = 1000) {
        precondition(capacity > 0, "InMemoryLogWriter capacity must be > 0, was \(capacity)")
        self.capacity = capacity
    }

    // MARK: - LogWriter

    public func log(_ entry: LogEntry) {
        lock.lock()
        defer { lock.unlock() }
        if entries.count < capacity {
            entries.append(entry)
        } else {
            entries.removeFirst()
            entries.append(entry)
        }
    }

    // MARK: - Housekeeping

    /// Remove all retained entries.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        entries = []
    }

    /// Restore a previously captured snapshot — supports the console's 5-second undo flow.
    ///
    /// The snapshot is clamped to `capacity` (newest `capacity` entries) to preserve the
    /// ring-buffer invariant. Mirrors `InMemoryLogWriter.restore()` in `:skylog-core` §4.7.
    public func restore(snapshot: [LogEntry]) {
        lock.lock()
        defer { lock.unlock() }
        entries = Array(snapshot.suffix(capacity))
    }
}

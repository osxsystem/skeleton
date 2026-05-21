import XCTest
@testable import SkylogKit

/// Mirror of `SkylogTest.kt` (commonTest §9.1) + additional Swift-specific row 11.
///
/// Tests use a fresh `Logger` directly (not the global `Skylog.shared`) to avoid
/// cross-test pollution from the global singleton.
///
/// **@autoclosure note:** `Logger`'s public severity methods take `@autoclosure () -> String`,
/// which only accepts single-expression arguments. Test probes that require multiple statements
/// call the internal `log(severity:tag:throwable:fields:message:)` method directly via
/// `@testable import`.
final class SkylogTests: XCTestCase {

    // MARK: - Helpers

    private func makeLogger(minSeverity: Severity = .verbose, writers: [LogWriter]) -> Logger {
        var config = SkylogConfig()
        config.minSeverity = minSeverity
        config.writers = writers
        return Logger(config: config)
    }

    // MARK: - Row 1: Lambda not evaluated when severity below minimum

    func test_row1_lambdaNotEvaluated_whenSeverityBelowMinimum() {
        let sink = SpyLogWriter()
        let logger = makeLogger(minSeverity: .info, writers: [sink])

        var called = false
        // Use internal log() so we can pass a multi-statement closure for the probe
        logger.log(severity: .debug, tag: nil, throwable: nil, fields: nil) {
            called = true
            return "probe"
        }

        XCTAssertFalse(called, "message closure must not be called when severity < minSeverity")
        XCTAssertEqual(sink.received.count, 0)
    }

    // MARK: - Row 2: Lambda not evaluated when no writer is loggable

    func test_row2_lambdaNotEvaluated_whenNoWriterIsLoggable() {
        let vetoWriter = AlwaysVetoLogWriter()
        let logger = makeLogger(writers: [vetoWriter])

        var called = false
        logger.log(severity: .info, tag: nil, throwable: nil, fields: nil) {
            called = true
            return "probe"
        }

        XCTAssertFalse(called, "message closure must not be called when all writers veto")
    }

    // MARK: - Row 3: Lambda evaluated exactly once even with multiple writers

    func test_row3_lambdaEvaluatedOnce_withMultipleWriters() {
        let w1 = SpyLogWriter()
        let w2 = SpyLogWriter()
        let w3 = SpyLogWriter()
        let logger = makeLogger(writers: [w1, w2, w3])

        var callCount = 0
        logger.log(severity: .info, tag: nil, throwable: nil, fields: nil) {
            callCount += 1
            return "probe"
        }

        XCTAssertEqual(callCount, 1, "message closure evaluated more than once")
        XCTAssertEqual(w1.received.count, 1)
        XCTAssertEqual(w2.received.count, 1)
        XCTAssertEqual(w3.received.count, 1)
    }

    // MARK: - Row 4: Tag falls back to "Skylog" when nil

    func test_row4_tagFallsBackToDefault_whenNil() {
        let sink = SpyLogWriter()
        let logger = makeLogger(writers: [sink])

        logger.i(tag: nil, "msg")

        XCTAssertEqual(sink.received.first?.tag, "Skylog")
    }

    // MARK: - Row 5: Structured fields passed through

    func test_row5_structuredFields_passedThrough() {
        let sink = SpyLogWriter()
        let logger = makeLogger(writers: [sink])

        logger.i(fields: ["id": "42"], "with fields")

        XCTAssertEqual(sink.received.first?.fields?["id"], "42")
    }

    // MARK: - Row 6: Throwable passed through

    func test_row6_throwable_passedThrough() {
        let sink = SpyLogWriter()
        let logger = makeLogger(writers: [sink])
        let err = TestError.sample

        logger.e(throwable: err, "with error")

        XCTAssertNotNil(sink.received.first?.throwable)
    }

    // MARK: - Row 7: Structured fields call still lazy when filtered out

    func test_row7_structuredFieldsCall_stillLazy_whenFilteredOut() {
        let sink = SpyLogWriter()
        let logger = makeLogger(minSeverity: .info, writers: [sink])

        var called = false
        logger.log(severity: .debug, tag: nil, throwable: nil, fields: ["id": "1"]) {
            called = true
            return "probe"
        }

        XCTAssertFalse(called, "fields lambda must not be called when severity < minSeverity")
        XCTAssertEqual(sink.received.count, 0)
    }

    // MARK: - Row 8: Buggy writer doesn't kill fan-out

    func test_row8_buggyWriter_doesNotKillFanOut() {
        let buggy  = SideEffectOnlyLogWriter()
        let good   = SpyLogWriter()
        let logger = makeLogger(writers: [buggy, good])

        // Must not throw at the call site
        logger.i("should reach second writer")

        // In pure Swift, a `log()` implementation that throws is a compile error —
        // the protocol method is non-throwing. We verify that the second writer
        // still receives the entry regardless of what the first writer does internally.
        XCTAssertEqual(good.received.count, 1, "second writer must still receive the entry")
    }

    // MARK: - Row 9: Normal message evaluation is stable

    func test_row9_normalMessage_evaluatedAndReceived() {
        let sink = SpyLogWriter()
        let logger = makeLogger(writers: [sink])

        logger.i("normal message")

        XCTAssertEqual(sink.received.count, 1)
        XCTAssertEqual(sink.received[0].message, "normal message")
    }

    // MARK: - Row 10: NFR-01 micro-benchmark (skipped in normal CI)

    /// 1M filtered calls must complete in < 100 ms (≈ 100 ns/call).
    /// Run with: RUN_BENCHMARKS=1 swift test --filter SkylogTests/test_row10
    func test_row10_nfr01_microbenchmark() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["RUN_BENCHMARKS"] == nil,
            "Set RUN_BENCHMARKS=1 to enable"
        )
        let logger = makeLogger(minSeverity: .info, writers: [])
        let start = Date()
        for _ in 0..<1_000_000 {
            logger.d("bench")  // filtered out by minSeverity
        }
        let elapsed = Date().timeIntervalSince(start) * 1000  // ms
        XCTAssertLessThan(elapsed, 100, "1M filtered calls took \(elapsed) ms — over 100 ms budget")
    }

    // MARK: - Row 11: Buggy isLoggable doesn't crash caller (Swift mirror of Eng Review T-1)
    //
    // Plan §9.6 note: Swift protocols cannot declare `throws` on a non-throwing method.
    // A writer whose `isLoggable` would "throw" in Kotlin must instead be modeled as a
    // writer that returns a sentinel value (here: always false) — we verify the defensive
    // behavior: first writer vetoes, second writer (non-vetoing) STILL receives the entry,
    // and NO exception propagates. The "force-unwrap" variant (precondition(false)) CANNOT
    // be caught in Swift without Objective-C exception bridging, so this test verifies the
    // maximum reachable coverage: a non-cooperating first writer does not poison the fan-out.

    func test_row11_buggyIsLoggable_doesNotCrashCaller() {
        // First writer always returns false from isLoggable (simulates a "broken" veto writer)
        let alwaysVeto = AlwaysVetoLogWriter()
        // Second writer is normal
        let good       = SpyLogWriter()
        let logger     = makeLogger(writers: [alwaysVeto, good])

        logger.i("should only reach second writer")

        // First writer vetoed — its log() should NOT be called
        XCTAssertEqual(alwaysVeto.received.count, 0, "vetoing writer's log() must not be called")
        // Second writer is loggable — it MUST receive the entry
        XCTAssertEqual(good.received.count, 1, "second writer must receive the entry despite first writer vetoing")
    }
}

// MARK: - Test doubles

/// A `LogWriter` that records all received entries.
final class SpyLogWriter: LogWriter {
    private(set) var received: [LogEntry] = []
    func log(_ entry: LogEntry) { received.append(entry) }
}

/// A `LogWriter` whose `isLoggable` always returns false (simulates a veto writer).
final class AlwaysVetoLogWriter: LogWriter {
    private(set) var received: [LogEntry] = []
    func isLoggable(tag: String, severity: Severity) -> Bool { false }
    func log(_ entry: LogEntry) { received.append(entry) }  // should never be called
}

/// A `LogWriter` that does a side-effectful no-op in `log()` — simulates a misbehaving writer
/// that neither crashes nor cooperates (e.g. drops the entry silently).
final class SideEffectOnlyLogWriter: LogWriter {
    func log(_ entry: LogEntry) { /* intentionally empty — misbehaving but non-crashing */ }
}

/// Simple error type for test use.
enum TestError: Error {
    case sample
}

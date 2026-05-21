import XCTest
@testable import SkylogKit

/// Mirror of `LogWriterCompositionTest.kt` (commonTest §9.3).
final class LogWriterCompositionTests: XCTestCase {

    // MARK: - Helpers

    private func makeLogger(writers: [LogWriter]) -> Logger {
        var config = SkylogConfig()
        config.writers = writers
        return Logger(config: config)
    }

    // MARK: - Row 1: Two writers, both loggable → both receive entry

    func test_row1_twoWriters_bothLoggable_bothReceiveEntry() {
        let w1 = SpyWriter()
        let w2 = SpyWriter()
        let logger = makeLogger(writers: [w1, w2])

        logger.i("broadcast")

        XCTAssertEqual(w1.callCount, 1, "w1 must receive the entry")
        XCTAssertEqual(w2.callCount, 1, "w2 must receive the entry")
    }

    // MARK: - Row 2: Two writers, one vetoes via isLoggable=false → only one receives

    func test_row2_oneVetoes_onlyTheOtherReceives() {
        let vetoing = VetoWriter()
        let normal  = SpyWriter()
        let logger  = makeLogger(writers: [vetoing, normal])

        logger.i("partial broadcast")

        XCTAssertEqual(vetoing.logCallCount, 0, "vetoing writer's log() must not be called")
        XCTAssertEqual(normal.callCount, 1, "non-vetoing writer must receive the entry")
    }

    // MARK: - Row 3: All writers veto → message lambda not evaluated

    func test_row3_allVeto_lambdaNotEvaluated() {
        let v1 = VetoWriter()
        let v2 = VetoWriter()
        let logger = makeLogger(writers: [v1, v2])

        var called = false
        logger.log(severity: .info, tag: nil, throwable: nil, fields: nil) {
            called = true
            return "probe"
        }

        XCTAssertFalse(called, "message closure must not be called when all writers veto")
    }
}

// MARK: - Test doubles

/// Records call count for `log()`.
private final class SpyWriter: LogWriter {
    private(set) var callCount = 0
    func log(_ entry: LogEntry) { callCount += 1 }
}

/// Always returns false from `isLoggable`; records whether `log()` was called (it should not be).
private final class VetoWriter: LogWriter {
    private(set) var logCallCount = 0
    func isLoggable(tag: String, severity: Severity) -> Bool { false }
    func log(_ entry: LogEntry) { logCallCount += 1 }
}

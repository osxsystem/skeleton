import XCTest
@testable import SkylogKit

final class LogConsoleViewTests: XCTestCase {

    func test_emptyStateCopy_bufferEmpty_showsEmptyBufferHint() {
        let copy = LogConsoleView.emptyStateCopy(bufferEmpty: true)
        XCTAssertEqual(copy.title, "No logs yet")
        XCTAssertEqual(copy.subtitle, "Try emitting a log with Skylog.i(\"...\")")
    }

    func test_emptyStateCopy_filterReturnsZero_showsFilterHint() {
        let copy = LogConsoleView.emptyStateCopy(bufferEmpty: false)
        XCTAssertEqual(copy.title, "No logs match the current filter")
        XCTAssertNil(copy.subtitle)
    }
}

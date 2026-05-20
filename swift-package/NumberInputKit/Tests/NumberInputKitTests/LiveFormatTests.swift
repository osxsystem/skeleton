import XCTest
@testable import NumberInputKit

/// Exercises `IosLocaleNumberFormatter.formatLive` with real `NumberFormatter` (no fakes).
/// Covers en-US, vi-VN, and de-DE grouping + decimal-separator rules.
final class LiveFormatTests: XCTestCase {

    private let formatter = IosLocaleNumberFormatter()

    // MARK: - en-US (grouping ",", decimal ".")

    func testEnUSNoGroupingBelow1000() {
        XCTAssertEqual(formatter.formatLive("100", locale: "en-US"), "100")
    }

    func testEnUSGroupsAt1000() {
        XCTAssertEqual(formatter.formatLive("1000", locale: "en-US"), "1,000")
    }

    func testEnUSGroupsAt1Million() {
        XCTAssertEqual(formatter.formatLive("1000000", locale: "en-US"), "1,000,000")
    }

    func testEnUSPreservesDecimalPortion() {
        XCTAssertEqual(formatter.formatLive("1000.5", locale: "en-US"), "1,000.5")
    }

    func testEnUSPreservesTrailingDecimalSeparator() {
        XCTAssertEqual(formatter.formatLive("1000.", locale: "en-US"), "1,000.")
    }

    func testEnUSReGroupsAlreadyGroupedInput() {
        // User typed at end of "1,000" → "1,0009" → should become "10,009"
        XCTAssertEqual(formatter.formatLive("1,0009", locale: "en-US"), "10,009")
    }

    func testEnUSNegativeInteger() {
        XCTAssertEqual(formatter.formatLive("-1000", locale: "en-US"), "-1,000")
    }

    func testEnUSMinusAlonePassesThrough() {
        XCTAssertEqual(formatter.formatLive("-", locale: "en-US"), "-")
    }

    func testEnUSEmptyInput() {
        XCTAssertEqual(formatter.formatLive("", locale: "en-US"), "")
    }

    // MARK: - vi-VN (grouping ".", decimal ",")

    func testViVNGroupsAt1000() {
        XCTAssertEqual(formatter.formatLive("1000", locale: "vi-VN"), "1.000")
    }

    func testViVNGroupsAt1Million() {
        XCTAssertEqual(formatter.formatLive("1000000", locale: "vi-VN"), "1.000.000")
    }

    func testViVNPreservesDecimalPortion() {
        // In vi-VN the decimal separator is ","
        XCTAssertEqual(formatter.formatLive("1000,5", locale: "vi-VN"), "1.000,5")
    }

    func testViVNNegativeInteger() {
        XCTAssertEqual(formatter.formatLive("-1000", locale: "vi-VN"), "-1.000")
    }

    // MARK: - de-DE (grouping ".", decimal ",")

    func testDeDeGroupsAt1000() {
        XCTAssertEqual(formatter.formatLive("1000", locale: "de-DE"), "1.000")
    }

    func testDeDePreservesDecimalPortion() {
        XCTAssertEqual(formatter.formatLive("1000,5", locale: "de-DE"), "1.000,5")
    }

    // MARK: - format + parse round-trip

    func testEnUSFormatRoundTrip() {
        let formatted = formatter.format(1234.5, significantDigits: 2, locale: "en-US")
        XCTAssertEqual(formatted, "1,234.50")
        XCTAssertEqual(formatter.parse(formatted, locale: "en-US"), 1234.5)
    }

    func testViVNFormatRoundTrip() {
        let formatted = formatter.format(1234.5, significantDigits: 2, locale: "vi-VN")
        let parsed = formatter.parse(formatted, locale: "vi-VN")
        XCTAssertEqual(parsed, 1234.5)
    }

    func testDeDEFormatRoundTrip() {
        let formatted = formatter.format(1234.5, significantDigits: 2, locale: "de-DE")
        let parsed = formatter.parse(formatted, locale: "de-DE")
        XCTAssertEqual(parsed, 1234.5)
    }
}

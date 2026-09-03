import XCTest
@testable import NumberInputKit

/// Guards the per-locale formatter caching (skeleton-lu5): interleaving locales must not leak
/// one locale's separators into another — the failure mode of a single shared `NumberFormatter`.
final class IosLocaleNumberFormatterCacheTests: XCTestCase {

    private let f = IosLocaleNumberFormatter()

    func testFormatStaysLocaleCorrectWhenLocalesInterleave() {
        XCTAssertEqual(f.format(1234.5, significantDigits: 1, locale: "en-US"), "1,234.5")
        XCTAssertEqual(f.format(1234.5, significantDigits: 1, locale: "de-DE"), "1.234,5")
        // Re-query en-US after de-DE: a shared mutable formatter would now return de-DE separators.
        XCTAssertEqual(f.format(1234.5, significantDigits: 1, locale: "en-US"), "1,234.5")
    }

    func testParseStaysLocaleCorrectWhenLocalesInterleave() {
        XCTAssertEqual(f.parse("1,234.5", locale: "en-US"), 1234.5)
        XCTAssertEqual(f.parse("1.234,5", locale: "de-DE"), 1234.5)
        XCTAssertEqual(f.parse("1,234.5", locale: "en-US"), 1234.5)
    }

    func testFormatLiveStaysLocaleCorrectWhenLocalesInterleave() {
        XCTAssertEqual(f.formatLive("1234", locale: "en-US"), "1,234")
        XCTAssertEqual(f.formatLive("1234", locale: "de-DE"), "1.234")
        XCTAssertEqual(f.formatLive("1234", locale: "en-US"), "1,234")
    }

    /// Differing significantDigits for the same locale must not be cross-contaminated by caching.
    func testFormatRespectsSignificantDigitsAcrossCalls() {
        XCTAssertEqual(f.format(1.5, significantDigits: 1, locale: "en-US"), "1.5")
        XCTAssertEqual(f.format(1.5, significantDigits: 3, locale: "en-US"), "1.500")
        XCTAssertEqual(f.format(1.5, significantDigits: 1, locale: "en-US"), "1.5")
    }
}

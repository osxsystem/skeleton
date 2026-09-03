import XCTest
@testable import NumberInputKit

/// Pins the toolbar enable/disable rules so both the built-in keypad's top row and the system
/// keyboard's `UIToolbar` accessory derive their item states from one place.
///
/// Port of `NumberInputToolbarRulesTest.kt`; the Kotlin file was itself ported from this one, so
/// this closes the loop.
final class NumberInputToolbarRulesTests: XCTestCase {

    // MARK: - Clear: enabled when there is something to clear.

    func testClearDisabledWhenTextEmptyAndValueNil() {
        XCTAssertFalse(NumberInputToolbarRules.clearEnabled(rawText: "", value: nil))
    }

    func testClearEnabledWhenRawTextNonEmpty() {
        XCTAssertTrue(NumberInputToolbarRules.clearEnabled(rawText: "1", value: nil))
    }

    func testClearEnabledWhenValuePresentEvenIfTextEmpty() {
        XCTAssertTrue(NumberInputToolbarRules.clearEnabled(rawText: "", value: 5))
    }

    // MARK: - Sign: enabled only when negatives are allowed AND a value exists to negate.

    func testSignDisabledWhenAllowNegativeFalse() {
        XCTAssertFalse(NumberInputToolbarRules.signEnabled(allowNegative: false, value: 5))
    }

    func testSignDisabledWhenValueNil() {
        XCTAssertFalse(NumberInputToolbarRules.signEnabled(allowNegative: true, value: nil))
    }

    func testSignEnabledWhenAllowNegativeAndValuePresent() {
        XCTAssertTrue(NumberInputToolbarRules.signEnabled(allowNegative: true, value: 5))
    }

    // MARK: - Sign visibility is a separate question from usability.

    /// With `allowNegative = false` the button could never become enabled for the life of the field,
    /// so it is omitted rather than greyed. The keypad's decimal key on an integer-only field is the
    /// opposite call, deliberately: greying it says "this field takes no fraction", where hiding it
    /// would leave a hole in a fixed grid.
    func testSignHiddenEntirelyWhenNegativesAreDisallowed() {
        XCTAssertFalse(NumberInputToolbarRules.signVisible(allowNegative: false))
        XCTAssertTrue(NumberInputToolbarRules.signVisible(allowNegative: true))
    }
}

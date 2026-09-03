import XCTest
@testable import NumberInputKit

/// Port of `NumberInputStateTest.kt`.
///
/// `rawText` is always *ungrouped* on both platforms; thousands grouping is applied for display
/// only, by `formatLive` at the field boundary.
///
/// Two Kotlin tests have no Swift counterpart: `config_rejects_significantDigits_below_range` and
/// `..._above_range` assert an `IllegalArgumentException`, and the Swift guard is a `precondition`,
/// which traps rather than throwing. The valid bounds are pinned in `NumberInputEdgeCaseTests`
/// instead.
final class NumberInputStateTests: XCTestCase {

    private let fake = FakeLocaleNumberFormatter()

    private func makeState(
        initialValue: Double? = nil,
        significantDigits: Int = 2,
        locale: String = "en-US",
        allowNegative: Bool = true
    ) -> NumberInputState {
        NumberInputState(
            formatter: fake,
            initialValue: initialValue,
            config: NumberInputConfig(
                significantDigits: significantDigits,
                locale: locale,
                allowNegative: allowNegative
            )
        )
    }

    func testInitialStateIsIdleWithCanonicalUngroupedInitialValue() {
        let s = makeState(initialValue: 1234.5, significantDigits: 2)
        XCTAssertEqual(s.phase, .idle)
        XCTAssertEqual(s.rawText, "1234.50")
        XCTAssertEqual(s.value, 1234.5)
    }

    func testOnFocusChangedTrueTransitionsIdleToEditing() {
        let s = makeState(initialValue: 1.0)
        s.onFocusChanged(true)
        XCTAssertEqual(s.phase, .editing)
    }

    func testOnTextChangeParsesToValueAndStaysEditing() {
        let s = makeState()
        s.onFocusChanged(true)
        s.onTextChange("42.5")
        XCTAssertEqual(s.phase, .editing)
        XCTAssertEqual(s.value, 42.5)
        XCTAssertEqual(s.rawText, "42.5")
    }

    /// Non-numeric text arriving at once is rejected outright, so neither `value` nor `rawText` moves.
    func testOnTextChangeWithInvalidTextKeepsLastValue() {
        let s = makeState(initialValue: 10.0)
        s.onFocusChanged(true)
        s.onTextChange("abc")
        XCTAssertEqual(s.value, 10.0)
        XCTAssertEqual(s.rawText, "10.00")
    }

    /// A typed character a number cannot contain is refused, so the two input paths agree.
    func testOnTextChangeRefusesATypedCharacterANumberCannotContain() {
        let s = makeState()
        s.onFocusChanged(true)
        for ch in "12" { s.onTextChange(s.rawText + String(ch)) }

        s.onTextChange("12a")

        XCTAssertEqual(s.rawText, "12")
        XCTAssertEqual(s.value, 12.0)
    }

    func testOnTextChangeStillAcceptsDigitsSignsAndEitherDecimalKey() {
        for key in ["5", "-", ".", ","] {
            let s = makeState()
            s.onFocusChanged(true)
            s.onTextChange(key)
            XCTAssertEqual(s.rawText.count, 1, "'\(key)' should reach the buffer")
        }
    }

    func testToggleSignFlipsValue() {
        let s = makeState(initialValue: 42.5)
        s.onFocusChanged(true)
        s.toggleSign()
        XCTAssertEqual(s.value, -42.5)
    }

    func testToggleSignOnNilValueIsNoOp() {
        let s = makeState(initialValue: nil)
        s.onFocusChanged(true)
        s.toggleSign()
        XCTAssertNil(s.value)
    }

    func testToggleSignWithAllowNegativeFalseIsNoOp() {
        let s = makeState(initialValue: 42.5, allowNegative: false)
        s.onFocusChanged(true)
        s.toggleSign()
        XCTAssertEqual(s.value, 42.5)
    }

    func testClearSetsValueToNilAndStaysEditing() {
        let s = makeState(initialValue: 42.5)
        s.onFocusChanged(true)
        s.clear()
        XCTAssertEqual(s.phase, .editing)
        XCTAssertNil(s.value)
        XCTAssertEqual(s.rawText, "")
    }

    func testCommitCanonicalisesRawTextAndReturnsToIdle() {
        let s = makeState(initialValue: 5.0)
        s.onFocusChanged(true)
        s.onTextChange("7")
        s.commit()
        XCTAssertEqual(s.phase, .idle)
        XCTAssertEqual(s.value, 7.0)
        XCTAssertEqual(s.rawText, "7.00")
    }

    func testOnFocusChangedFalseActsAsCommit() {
        let s = makeState(initialValue: 5.0)
        s.onFocusChanged(true)
        s.onTextChange("7")
        s.onFocusChanged(false)
        XCTAssertEqual(s.phase, .idle)
        XCTAssertEqual(s.rawText, "7.00")
    }

    func testSignificantDigitsIsReflectedInIdleRawText() {
        let s = makeState(initialValue: 0.1, significantDigits: 3)
        XCTAssertEqual(s.rawText, "0.100")
    }

    func testAllowNegativeFalseClampsNegativeInitialValueToZero() {
        let s = makeState(initialValue: -5.0, allowNegative: false)
        XCTAssertEqual(s.value, 0.0)
        XCTAssertEqual(s.rawText, "0.00")
    }

    func testOnTextChangeWithNegativeValueIsRejectedWhenAllowNegativeFalse() {
        let s = makeState(initialValue: 10.0, allowNegative: false)
        s.onFocusChanged(true)
        s.onTextChange("-3")
        XCTAssertEqual(s.value, 10.0, "value unchanged")
        XCTAssertEqual(s.rawText, "-3", "rawText updated")
    }

    func testOnTextChangeMinusAloneKeepsMinus() {
        let s = makeState(locale: "en-US")
        s.onFocusChanged(true)
        s.onTextChange("-")
        XCTAssertEqual(s.rawText, "-")
    }

    func testOnTextChangeEmptyClearsRawText() {
        let s = makeState(initialValue: 1234.5, locale: "en-US")
        s.onFocusChanged(true)
        s.onTextChange("")
        XCTAssertEqual(s.rawText, "")
        XCTAssertNil(s.value)
    }

    func testOnFocusChangedTrueCarriesRawTextIntoEditing() {
        let s = makeState(initialValue: 1234.5, locale: "en-US")
        XCTAssertEqual(s.rawText, "1234.50")
        s.onFocusChanged(true)
        XCTAssertEqual(s.phase, .editing)
        XCTAssertEqual(s.rawText, "1234.50")
    }

    func testToggleSignProducesLocaleAwareRawTextViVN() {
        let s = makeState(initialValue: 42.5, locale: "vi-VN")
        s.onFocusChanged(true)
        s.toggleSign()
        XCTAssertEqual(s.value, -42.5)
        XCTAssertEqual(s.rawText, "-42,50")
    }

    func testOnTextChangeRejectsFractionDigitsBeyondSignificantDigits() {
        let s = makeState(significantDigits: 3, locale: "en-US")
        s.onFocusChanged(true)
        s.onTextChange("1.234")
        XCTAssertEqual(s.rawText, "1.234")
        s.onTextChange("1.2345")
        XCTAssertEqual(s.rawText, "1.234")
    }

    /// Two separators never describe a number, and `value` must not stop tracking `rawText`.
    func testOnTextChangeRejectsASecondDecimalSeparator() {
        let s = makeState(significantDigits: 3, locale: "en-US")
        s.onFocusChanged(true)

        s.onTextChange("1.2")
        XCTAssertEqual(s.rawText, "1.2")

        s.onTextChange("1.2.")
        XCTAssertEqual(s.rawText, "1.2", "a second separator is rejected")

        s.onTextChange("1.2.3")
        XCTAssertEqual(s.rawText, "1.2")
        XCTAssertEqual(s.value, 1.2, "value still tracks rawText")
    }

    func testOnTextChangeRejectsASecondDecimalSeparatorDeDE() {
        let s = makeState(significantDigits: 3, locale: "de-DE")
        s.onFocusChanged(true)

        s.onTextChange("7500,25")
        XCTAssertEqual(s.rawText, "7500,25")

        s.onTextChange("7500,25,")
        XCTAssertEqual(s.rawText, "7500,25")
        XCTAssertEqual(s.value, 7_500.25)
    }

    func testOnTextChangeWithZeroSignificantDigitsRejectsDecimalSeparator() {
        let s = makeState(significantDigits: 0, locale: "en-US")
        s.onFocusChanged(true)
        s.onTextChange("12")
        XCTAssertEqual(s.rawText, "12")
        s.onTextChange("12.")
        XCTAssertEqual(s.rawText, "12", "separator rejected")
    }

    /// The VND Whole-Amount Rule: a vi-VN money field is configured `significantDigits = 0`.
    func testVietnameseDongConfigIsIntegerOnly() {
        let s = makeState(significantDigits: 0, locale: "vi-VN")
        s.onFocusChanged(true)

        s.onTextChange("2500000")
        XCTAssertEqual(s.rawText, "2500000")
        XCTAssertEqual(s.value, 2_500_000.0)

        s.onTextChange("2500000,")
        XCTAssertEqual(s.rawText, "2500000", "comma separator rejected")
        s.onTextChange("2500000,5")
        XCTAssertEqual(s.rawText, "2500000", "and so is a fraction digit")
    }

    func testVietnameseDongCommitsWithoutTrailingDecimals() {
        let s = makeState(significantDigits: 0, locale: "vi-VN")
        s.onFocusChanged(true)
        s.onTextChange("150000")
        s.onFocusChanged(false)

        XCTAssertEqual(s.value, 150_000.0)
        XCTAssertEqual(s.rawText, "150000", "no ',00' padding")
    }

    func testSyncExternalValueIsIgnoredWhileEditing() {
        let s = makeState(initialValue: 1.0, locale: "en-US")
        s.onFocusChanged(true)
        s.onTextChange("7")
        s.syncExternalValue(99.0)
        XCTAssertEqual(s.value, 7.0, "external push did not clobber the edit")
    }

    func testSyncExternalValueReseedsWhenIdle() {
        let s = makeState(initialValue: 1.0, significantDigits: 2, locale: "en-US")
        s.syncExternalValue(99.0)
        XCTAssertEqual(s.phase, .idle)
        XCTAssertEqual(s.value, 99.0)
        XCTAssertEqual(s.rawText, "99.00")
    }

    func testSyncExternalValueWithEqualValueIsNoOp() {
        let s = makeState(initialValue: 5.0, locale: "en-US")
        let textBefore = s.rawText
        s.syncExternalValue(5.0)
        XCTAssertEqual(s.value, 5.0)
        XCTAssertEqual(s.rawText, textBefore)
        XCTAssertEqual(s.phase, .idle)
    }

    func testOnTextChangeSubstitutesTypedPeriodForDecimalDeDE() {
        let s = makeState(significantDigits: 3, locale: "de-DE")
        s.onFocusChanged(true)
        s.onTextChange("1234")
        XCTAssertEqual(s.rawText, "1234")
        s.onTextChange("1234.")
        XCTAssertEqual(s.rawText, "1234,")
        s.onTextChange("1234,5")
        XCTAssertEqual(s.rawText, "1234,5")
        XCTAssertEqual(s.value, 1234.5)
    }

    func testOnTextChangeKeepsPeriodDecimalForEnUS() {
        let s = makeState(significantDigits: 2, locale: "en-US")
        s.onFocusChanged(true)
        s.onTextChange("12")
        s.onTextChange("12.")
        XCTAssertEqual(s.rawText, "12.")
    }

    func testOnTextChangeKeepsBufferUngrouped() {
        let s = makeState(locale: "en-US")
        s.onFocusChanged(true)
        s.onTextChange("12345")
        XCTAssertEqual(s.rawText, "12345")
        XCTAssertEqual(s.value, 12345.0)
    }

    func testToolbarRulesTrackState() {
        let s = makeState(initialValue: nil, allowNegative: true)
        XCTAssertFalse(s.clearEnabled)
        XCTAssertFalse(s.signEnabled)

        s.onFocusChanged(true)
        s.onTextChange("5")
        XCTAssertTrue(s.clearEnabled)
        XCTAssertTrue(s.signEnabled)

        s.clear()
        XCTAssertFalse(s.clearEnabled)
        XCTAssertFalse(s.signEnabled)
    }

    func testToolbarSignRuleRespectsAllowNegative() {
        let s = makeState(initialValue: 5.0, allowNegative: false)
        XCTAssertTrue(s.clearEnabled)
        XCTAssertFalse(s.signEnabled)
    }
}

import XCTest
@testable import NumberInputKit

/// Port of `WholeNumberInputTest.kt` — input that arrives as a whole number rather than one
/// keystroke at a time: paste, dictation, autocomplete, or any input method that commits at once.
///
/// A keystroke can be resolved by *what* arrived. A whole number cannot: it carries its own
/// separators, and which is decimal depends on *where* they sit. Text that holds up under neither
/// reading is rejected rather than coerced.
final class WholeNumberInputTests: XCTestCase {

    private let fake = FakeLocaleNumberFormatter()

    private func makeState(_ locale: String, significantDigits: Int = 2) -> NumberInputState {
        let s = NumberInputState(
            formatter: fake,
            initialValue: nil,
            config: NumberInputConfig(significantDigits: significantDigits, locale: locale)
        )
        s.onFocusChanged(true)
        return s
    }

    // MARK: - the reported defect, both directions

    func testPastingAForeignSeparatorIntoAnEnUSFieldCommitsThePastedNumber() {
        let s = makeState("en-US")

        s.onTextChange("1234,5")

        XCTAssertEqual(s.rawText, "1234.5")
        XCTAssertEqual(s.value, 1234.5, "was 12345.0 - a silent factor of ten")
    }

    func testPastingAForeignSeparatorIntoADeDEFieldCommitsThePastedNumber() {
        let s = makeState("de-DE", significantDigits: 3)

        s.onTextChange("1234.5")

        XCTAssertEqual(s.rawText, "1234,5")
        XCTAssertEqual(s.value, 1234.5, "was 12345.0")
    }

    func testAPastedNegativeKeepsItsSignAndItsFraction() {
        let s = makeState("en-US")

        s.onTextChange("-1234,5")

        XCTAssertEqual(s.rawText, "-1234.5")
        XCTAssertEqual(s.value, -1234.5, "was -12345.0")
    }

    // MARK: - position, not character, decides

    func testThreeTrailingDigitsReadAsGrouping() {
        let s = makeState("en-US")

        s.onTextChange("1,234")

        XCTAssertEqual(s.rawText, "1234")
        XCTAssertEqual(s.value, 1234.0)
    }

    func testFewerThanThreeTrailingDigitsReadAsADecimalPoint() {
        let s = makeState("en-US")

        s.onTextChange("1,23")

        XCTAssertEqual(s.rawText, "1.23")
        XCTAssertEqual(s.value, 1.23, "was 123.0 - ',23' cannot be a group")
    }

    func testCorrectlyGroupedTextPastesAsTheNumberItShows() {
        let s = makeState("en-US")

        s.onTextChange("1,234.5")

        XCTAssertEqual(s.rawText, "1234.5", "grouping dropped, decimal kept")
        XCTAssertEqual(s.value, 1234.5)
    }

    func testForeignGroupingConventionStillResolves() {
        let s = makeState("en-US")

        s.onTextChange("1.234.567")

        XCTAssertEqual(s.rawText, "1234567")
        XCTAssertEqual(s.value, 1234567.0)
    }

    func testGroupingThatFailsValidationIsRetriedAsADecimalPoint() {
        let s = makeState("en-US", significantDigits: 3)

        s.onTextChange("1234,500")

        XCTAssertEqual(s.rawText, "1234.500")
        XCTAssertEqual(s.value, 1234.5)
    }

    // MARK: - rejection

    func testTextThatIsANumberUnderNeitherReadingIsRejected() {
        let s = makeState("en-US")

        s.onTextChange("12,34,56")

        XCTAssertEqual(s.rawText, "", "groups of two are not a number - the field is left untouched")
        XCTAssertNil(s.value)
    }

    func testNonNumericPasteIsRejectedRatherThanStored() {
        let s = makeState("en-US")

        s.onTextChange("abc")

        XCTAssertEqual(s.rawText, "", "previously stored 'abc' verbatim until commit")
        XCTAssertNil(s.value)
    }

    func testARejectedPasteLeavesExistingContentIntact() {
        let s = makeState("en-US")
        s.onTextChange("500")

        s.onTextChange("12,34,56")

        XCTAssertEqual(s.rawText, "500")
        XCTAssertEqual(s.value, 500.0)
    }

    func testAPastePastTheFractionCapIsRejected() {
        let s = makeState("en-US", significantDigits: 2)

        s.onTextChange("1234,567")

        XCTAssertEqual(s.rawText, "", "trimming to 1234.56 would change the pasted value")
        XCTAssertNil(s.value)
    }

    /// `1.500` and `1.50` are the same number, so redundant zeros are dropped rather than refused.
    func testRedundantTrailingZerosPastTheCapAreDroppedRatherThanRefused() {
        let s = makeState("en-US", significantDigits: 2)

        s.onTextChange("1.500")

        XCTAssertEqual(s.rawText, "1.50")
        XCTAssertEqual(s.value, 1.5)
    }

    func testDroppingRedundantZerosAgreesWithTypingTheSameCharacters() {
        let pasted = makeState("en-US", significantDigits: 2)
        pasted.onTextChange("1.500")

        let typed = makeState("en-US", significantDigits: 2)
        for ch in "1.500" { typed.onTextChange(typed.rawText + String(ch)) }

        XCTAssertEqual(typed.rawText, pasted.rawText, "paste and typing must not disagree")
        XCTAssertEqual(typed.value, pasted.value)
    }

    func testAnIntegerOnlyFieldAcceptsAPastedZeroFraction() {
        let s = makeState("vi-VN", significantDigits: 0)

        s.onTextChange("1234,0")

        XCTAssertEqual(s.rawText, "1234", "the separator goes too once nothing follows it")
        XCTAssertEqual(s.value, 1234.0)
    }

    func testAnIntegerOnlyFieldRejectsAPastedFraction() {
        let s = makeState("vi-VN", significantDigits: 0)

        s.onTextChange("1234,5")

        XCTAssertEqual(s.rawText, "")
        XCTAssertNil(s.value)
    }

    // MARK: - surrounding whitespace

    func testSurroundingWhitespaceIsTolerated() {
        let s = makeState("en-US")

        s.onTextChange("  1234,5  ")

        XCTAssertEqual(s.rawText, "1234.5", "copied text often carries whitespace")
        XCTAssertEqual(s.value, 1234.5)
    }

    func testAWhitespaceOnlyPasteDoesNotClearAnExistingValue() {
        let s = makeState("en-US")
        s.onTextChange("500")

        s.onTextChange("   ")

        XCTAssertEqual(s.rawText, "500")
        XCTAssertEqual(s.value, 500.0)
    }

    // MARK: - paste into existing content

    func testAppendingAWholeNumberToExistingDigitsResolvesTheResult() {
        let s = makeState("en-US")
        s.onTextChange("9")

        s.onTextChange("988,7")

        XCTAssertEqual(s.rawText, "988.7")
        XCTAssertEqual(s.value, 988.7)
    }

    func testReplacingTheWholeBufferByPasteResolvesTheNewContent() {
        let s = makeState("en-US")
        s.onTextChange("12")

        s.onTextChange("1234,5")

        XCTAssertEqual(s.rawText, "1234.5")
        XCTAssertEqual(s.value, 1234.5)
    }

    // MARK: - the keystroke path is untouched

    func testSingleKeystrokesStillResolveByCharacter() {
        let s = makeState("en-US")

        for ch in "2500,8" { s.onTextChange(s.rawText + String(ch)) }

        XCTAssertEqual(s.rawText, "2500.8")
        XCTAssertEqual(s.value, 2500.8)
    }

    func testADeletionIsNotTreatedAsAWholeNumber() {
        let s = makeState("en-US")
        s.onTextChange("1234,5")

        s.onTextChange("1234.")
        s.onTextChange("1234")

        XCTAssertEqual(s.rawText, "1234")
        XCTAssertEqual(s.value, 1234.0)
    }
}

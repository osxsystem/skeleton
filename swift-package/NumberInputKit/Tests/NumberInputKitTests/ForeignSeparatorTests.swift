import XCTest
@testable import NumberInputKit

/// Port of `ForeignSeparatorTest.kt`.
///
/// The keyboard's separator key follows the *device* region, not the field's locale, and there is
/// no per-field override for the system decimal pad. So a field can be handed either "." or "," as
/// the decimal keystroke however it is configured, and must read whichever arrives as decimal
/// intent.
final class ForeignSeparatorTests: XCTestCase {

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

    /// Types `keys` one at a time against an ungrouped buffer, as the shared logic sees them.
    private func typeUngrouped(_ state: NumberInputState, _ keys: String) {
        for key in keys { state.onTextChange(state.rawText + String(key)) }
    }

    func testEnUSFieldAcceptsACommaAsTheDecimalSeparator() {
        let s = makeState("en-US")

        typeUngrouped(s, "2500,8")

        XCTAssertEqual(s.rawText, "2500.8", "the comma is read as decimal intent, not grouping")
        XCTAssertEqual(s.value, 2500.8)
    }

    func testEnUSFieldStillAcceptsAPeriodAsTheDecimalSeparator() {
        let s = makeState("en-US")

        typeUngrouped(s, "2500.8")

        XCTAssertEqual(s.rawText, "2500.8")
        XCTAssertEqual(s.value, 2500.8)
    }

    func testDeDEFieldAcceptsAPeriodAsTheDecimalSeparator() {
        let s = makeState("de-DE", significantDigits: 3)

        typeUngrouped(s, "2500.25")

        XCTAssertEqual(s.rawText, "2500,25")
        XCTAssertEqual(s.value, 2500.25)
    }

    func testDeDEFieldAcceptsACommaAsTheDecimalSeparator() {
        let s = makeState("de-DE", significantDigits: 3)

        typeUngrouped(s, "2500,25")

        XCTAssertEqual(s.rawText, "2500,25")
        XCTAssertEqual(s.value, 2500.25)
    }

    func testAForeignSecondSeparatorIsRejected() {
        let s = makeState("en-US")

        typeUngrouped(s, "1,2,")

        XCTAssertEqual(s.rawText, "1.2", "the second separator never lands")
        XCTAssertEqual(s.value, 1.2)
    }

    func testIntegerOnlyFieldRejectsAForeignSeparator() {
        let s = makeState("vi-VN", significantDigits: 0)

        typeUngrouped(s, "2500000.")

        XCTAssertEqual(s.rawText, "2500000")
        XCTAssertEqual(s.value, 2_500_000.0)
    }

    func testIntegerOnlyEnUSFieldRejectsAComma() {
        let s = makeState("en-US", significantDigits: 0)

        typeUngrouped(s, "2500000,")

        XCTAssertEqual(s.rawText, "2500000")
        XCTAssertEqual(s.value, 2_500_000.0)
    }

    func testFractionCapAppliesAfterTranslatingAForeignSeparator() {
        let s = makeState("en-US", significantDigits: 2)

        typeUngrouped(s, "1234,567")

        XCTAssertEqual(s.rawText, "1234.56")
        XCTAssertEqual(s.value, 1234.56)
    }

    func testAForeignSeparatorInsideAMultiCharacterPasteResolvesToo() {
        let s = makeState("en-US")

        s.onTextChange("1234,5")

        XCTAssertEqual(s.rawText, "1234.5")
        XCTAssertEqual(s.value, 1234.5)
    }

    // MARK: - the grouped-buffer boundary the native field crosses

    /// Replays `keys` one at a time through the loop the field's coordinator runs: the native buffer
    /// is *grouped*, `ungroupTypedText` converts it on the way in, and `formatLive` re-groups it on
    /// the way out. Uses the real formatter, so these fail if the disambiguation is removed.
    private func replayKeystrokes(
        _ keys: String,
        locale: String,
        significantDigits: Int
    ) -> (state: NumberInputState, display: String) {
        let formatter = IosLocaleNumberFormatter()
        let state = NumberInputState(
            formatter: formatter,
            initialValue: nil,
            config: NumberInputConfig(significantDigits: significantDigits, locale: locale)
        )
        state.onFocusChanged(true)

        let group = formatter.groupingSeparator(locale: locale)
        let decimal = formatter.decimalSeparator(locale: locale)
        var lastWritten = ""

        for key in keys {
            let grouped = lastWritten + String(key)
            state.onTextChange(
                ungroupTypedText(
                    grouped: grouped,
                    previousDisplay: lastWritten,
                    groupingSeparator: group,
                    decimalSeparator: decimal
                )
            )
            lastWritten = formatter.formatLive(state.rawText, locale: locale)
        }
        return (state, lastWritten)
    }

    /// The defect this boundary exists for: on de-DE the grouping separator is "." — the very
    /// character the decimal pad emits — and a blanket strip used to swallow a typed decimal point,
    /// merging the fraction into the integer part.
    func testATypedSeparatorSurvivesADotGroupingLocale() {
        let (state, display) = replayKeystrokes("7500.25", locale: "de-DE", significantDigits: 2)

        XCTAssertEqual(state.rawText, "7500,25", "was '750025' - a silent factor of a hundred")
        XCTAssertEqual(state.value, 7_500.25)
        XCTAssertEqual(display, "7.500,25")
    }

    func testATypedSeparatorSurvivesViVN() {
        let (state, display) = replayKeystrokes("25500,8", locale: "vi-VN", significantDigits: 1)

        XCTAssertEqual(state.rawText, "25500,8")
        XCTAssertEqual(state.value, 25_500.8)
        XCTAssertEqual(display, "25.500,8")
    }

    func testGroupingIsStrippedFromAnOrdinaryDigitKeystroke() {
        let (state, display) = replayKeystrokes("12345", locale: "en-US", significantDigits: 2)

        XCTAssertEqual(state.rawText, "12345", "the buffer stays ungrouped")
        XCTAssertEqual(display, "12,345")
    }

    /// A multi-character insertion is a whole number only `NumberInputState` can interpret, so it is
    /// handed over untouched rather than having its separators stripped first.
    func testUngroupTypedTextHandsAPasteOverUntouched() {
        let result = ungroupTypedText(
            grouped: "1234,5",
            previousDisplay: "",
            groupingSeparator: ",",
            decimalSeparator: "."
        )

        XCTAssertEqual(result, "1234,5")
    }
}

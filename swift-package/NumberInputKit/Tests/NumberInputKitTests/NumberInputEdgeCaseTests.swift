import XCTest
@testable import NumberInputKit

/// Edge cases derived from the ck:scenario analysis in
/// docs/qa/scenarios/number-input-library.md, retargeted at `NumberInputState`.
///
/// Covers: config bounds, `IosLocaleNumberFormatter` extremes, and state edges the ported Kotlin
/// suites do not reach.
final class NumberInputEdgeCaseTests: XCTestCase {

    private let fake = FakeLocaleNumberFormatter()
    private let ios = IosLocaleNumberFormatter()

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

    // MARK: - Config bounds
    //
    // The out-of-range guard is a `precondition`, which traps rather than throwing, so only the
    // valid bounds are assertable from a test.

    func testNumberInputConfigAcceptsZeroSignificantDigits() {
        XCTAssertEqual(NumberInputConfig(significantDigits: 0).significantDigits, 0)
    }

    func testNumberInputConfigAcceptsNineSignificantDigits() {
        XCTAssertEqual(NumberInputConfig(significantDigits: 9).significantDigits, 9)
    }

    func testNumberInputConfigDefaultsMatchTheKotlinLibrary() {
        let config = NumberInputConfig()
        XCTAssertEqual(config.significantDigits, 3)
        XCTAssertEqual(config.locale, "en-US")
        XCTAssertTrue(config.allowNegative)
        XCTAssertEqual(config.placeholder, "")
        XCTAssertFalse(config.useBuiltInKeypad, "the system keyboard stays the default")
        XCTAssertTrue(config.keypadHaptics)
    }

    func testAccessibilityStringsAcceptLocalizedCopyOutsideParityConfig() {
        let strings = NumberInputAccessibilityStrings(
            label: "Số tiền",
            hint: "Chạm hai lần để nhập số",
            emptyValue: "Trống"
        )

        XCTAssertEqual(strings.label, "Số tiền")
        XCTAssertEqual(strings.hint, "Chạm hai lần để nhập số")
        XCTAssertEqual(strings.emptyValue, "Trống")
        XCTAssertEqual(strings.resolvedLabel(placeholder: "Enter amount"), "Số tiền")
        XCTAssertEqual(
            NumberInputAccessibilityStrings().resolvedLabel(placeholder: "Enter amount"),
            "Enter amount"
        )
        XCTAssertEqual(
            NumberInputAccessibilityStrings().resolvedLabel(placeholder: ""),
            "Number input"
        )
    }

    // MARK: - IosLocaleNumberFormatter edge cases

    func testIosFormatterFormatNaNReturnsAString() {
        XCTAssertNotNil(ios.format(.nan, significantDigits: 2, locale: "en-US"))
    }

    func testIosFormatterFormatPositiveInfinityReturnsAString() {
        XCTAssertNotNil(ios.format(.infinity, significantDigits: 2, locale: "en-US"))
    }

    func testIosFormatterFormatDoubleMaxReturnsAString() {
        let result = ios.format(.greatestFiniteMagnitude, significantDigits: 2, locale: "en-US")
        XCTAssertFalse(result.isEmpty)
    }

    /// Pins Apple's permissive behaviour: `NumberFormatter` accepts U+2212 MINUS SIGN in en-US.
    func testIosFormatterParseUnicodeMinusPinsApplePermissiveBehaviour() {
        XCTAssertEqual(ios.parse("\u{2212}42.5", locale: "en-US"), -42.5)
    }

    /// Pins Apple's permissive behaviour: Arabic-Indic digits parse even under en-US.
    func testIosFormatterParseArabicIndicDigitsPinsApplePermissiveBehaviour() {
        let arabicIndic = "\u{0661}\u{0662}\u{0663}\u{0664}.\u{0665}"
        XCTAssertEqual(ios.parse(arabicIndic, locale: "en-US"), 1234.5)
    }

    func testIosFormatterFormatSignificantDigitsZeroOmitsDecimalSeparator() {
        let result = ios.format(1234.5, significantDigits: 0, locale: "en-US")
        XCTAssertFalse(result.contains("."), "got: \(result)")
    }

    func testIosFormatterFormatSignificantDigitsZeroOmitsDecimalSeparatorViVN() {
        let result = ios.format(1234.5, significantDigits: 0, locale: "vi-VN")
        XCTAssertFalse(result.contains(","), "got: \(result)")
    }

    func testIosFormatterFormatHalfEvenRounding() {
        XCTAssertEqual(ios.format(1.234567, significantDigits: 5, locale: "en-US"), "1.23457")
    }

    func testIosFormatterFormatLiveHugeIntegerStringDoesNotCrash() {
        XCTAssertNotNil(ios.formatLive(String(repeating: "9", count: 25), locale: "en-US"))
    }

    func testIosFormatterParseWithWhitespacePadding() {
        XCTAssertEqual(ios.parse(" 1234.5 ", locale: "en-US"), 1234.5)
    }

    func testIosFormatterReportsItsLocaleSeparators() {
        XCTAssertEqual(ios.decimalSeparator(locale: "en-US"), ".")
        XCTAssertEqual(ios.groupingSeparator(locale: "en-US"), ",")
        XCTAssertEqual(ios.decimalSeparator(locale: "de-DE"), ",")
        XCTAssertEqual(ios.groupingSeparator(locale: "de-DE"), ".")
    }

    // MARK: - state edges

    /// Uses the real iOS formatter: the deterministic fake calls `Int64(rounded)`, which traps on
    /// NaN. The production formatter maps it through `?? ""` instead.
    func testStateInitWithNaNInitialValueDoesNotCrash() {
        let s = NumberInputState(formatter: ios, initialValue: .nan, config: NumberInputConfig(significantDigits: 2))
        XCTAssertEqual(s.phase, .idle)
    }

    func testStateInitWithInfinityInitialValueDoesNotCrash() {
        let s = NumberInputState(formatter: ios, initialValue: .infinity, config: NumberInputConfig(significantDigits: 2))
        XCTAssertEqual(s.phase, .idle)
    }

    /// `clear()` from Idle moves straight to Editing, matching the Kotlin state machine.
    func testClearWhileIdleTransitionsToEditing() {
        let s = makeState(initialValue: 5.0)
        s.clear()
        XCTAssertEqual(s.phase, .editing)
        XCTAssertNil(s.value)
    }

    func testToggleSignWhileIdleTransitionsToEditingWithNegatedValue() {
        let s = makeState(initialValue: 5.0)
        s.toggleSign()
        XCTAssertEqual(s.phase, .editing)
        XCTAssertEqual(s.value, -5.0)
    }

    /// ± on exactly 0.0 produces -0.0 at the bit level.
    func testToggleSignOnZeroValueProducesNegativeZero() {
        let s = makeState(initialValue: 0.0)
        s.onFocusChanged(true)
        s.toggleSign()
        XCTAssertEqual(s.value?.bitPattern, (-0.0).bitPattern)
    }

    func testOnTextChangeHugeIntegerDoesNotCrash() {
        let s = makeState()
        s.onFocusChanged(true)
        s.onTextChange(String(repeating: "9", count: 25))
        XCTAssertEqual(s.phase, .editing)
    }

    /// A negative typed into an `allowNegative = false` field never reaches `value`, so committing
    /// restores the previous one.
    func testNegativeTypedThenCommitKeepsPriorValueWhenAllowNegativeFalse() {
        let s = makeState(initialValue: 10.0, allowNegative: false)
        s.onFocusChanged(true)
        s.onTextChange("-3")
        s.commit()
        XCTAssertEqual(s.phase, .idle)
        XCTAssertEqual(s.value, 10.0)
        XCTAssertEqual(s.rawText, "10.00")
    }

    /// `isEmpty` distinguishes "not entered" from zero, which is what the placeholder renders.
    func testIsEmptyDistinguishesAnUnenteredFieldFromZero() {
        XCTAssertTrue(makeState(initialValue: nil).isEmpty)
        XCTAssertFalse(makeState(initialValue: 0.0).isEmpty)
    }

    // MARK: - whole-number interpretation, asked directly

    func testInterpretWholeNumberReturnsNilForTextThatIsNotANumber() {
        XCTAssertNil(interpretWholeNumber("12,34,56", decimalSeparator: ".", groupingSeparator: ","))
        XCTAssertNil(interpretWholeNumber("abc", decimalSeparator: ".", groupingSeparator: ","))
        XCTAssertNil(interpretWholeNumber("   ", decimalSeparator: ".", groupingSeparator: ","))
    }

    func testInterpretWholeNumberPassesAnEmptyBufferThrough() {
        XCTAssertEqual(interpretWholeNumber("", decimalSeparator: ".", groupingSeparator: ","), "")
    }

    /// The field's own convention decides which reading is tried first, which is how the same text
    /// resolves in opposite directions on two locales.
    func testInterpretWholeNumberPrefersTheFieldsOwnConvention() {
        XCTAssertEqual(interpretWholeNumber("1.234", decimalSeparator: ".", groupingSeparator: ","), "1.234")
        XCTAssertEqual(interpretWholeNumber("1.234", decimalSeparator: ",", groupingSeparator: "."), "1234")
    }

    func testInsertionIsolatesTheCharactersJustAdded() {
        let ins = insertion("1234", "134")
        XCTAssertEqual(ins?.text, "2")
        XCTAssertEqual(ins?.start, 1)
        XCTAssertNil(insertion("134", "1234"), "a deletion has no insertion")
        XCTAssertNil(insertion("134", "134"), "an unchanged buffer has none either")
    }
}

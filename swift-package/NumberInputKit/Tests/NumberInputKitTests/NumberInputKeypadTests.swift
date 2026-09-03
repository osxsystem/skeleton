import XCTest
@testable import NumberInputKit

/// Port of `NumberInputKeypadTest.kt` — the built-in keypad's press handlers and enablement rules.
///
/// Every press routes through `onTextChange`, so what these really pin is that the keypad inherits
/// the existing validation rather than restating it: the fraction cap, the one-separator rule and
/// the canonical-`rawText` invariant are enforced in one place and the keypad only asks about them.
///
/// `a_digit_outside_zero_to_nine_is_a_programming_error` has no counterpart: the Swift guard is a
/// `precondition`, which traps rather than throwing, so it cannot be asserted from a test.
final class NumberInputKeypadTests: XCTestCase {

    private let fake = FakeLocaleNumberFormatter()

    private func makeState(
        locale: String = "en-US",
        significantDigits: Int = 2,
        initialValue: Double? = nil,
        allowNegative: Bool = true
    ) -> NumberInputState {
        let s = NumberInputState(
            formatter: fake,
            initialValue: initialValue,
            config: NumberInputConfig(
                significantDigits: significantDigits,
                locale: locale,
                allowNegative: allowNegative,
                useBuiltInKeypad: true
            )
        )
        s.onFocusChanged(true)
        return s
    }

    // MARK: - digits

    func testDigitsAppendInOrder() {
        let s = makeState()

        [1, 2, 3].forEach(s.pressDigit)

        XCTAssertEqual(s.rawText, "123")
        XCTAssertEqual(s.value, 123.0)
    }

    func testTheIntegerPartIsUncapped() {
        let s = makeState(significantDigits: 2)

        for _ in 0..<9 { s.pressDigit(9) }

        XCTAssertEqual(s.rawText, "999999999", "significantDigits caps the fraction, not the integer")
        XCTAssertTrue(s.digitEnabled)
    }

    // MARK: - the decimal key

    /// The reason the keypad exists: the key is labelled from the field's own locale, so it never
    /// disagrees with the text it produces.
    func testTheDecimalKeyShowsTheFieldsOwnSeparator() {
        XCTAssertEqual(makeState(locale: "en-US").decimalKeyLabel, ".")
        XCTAssertEqual(makeState(locale: "de-DE").decimalKeyLabel, ",")
        XCTAssertEqual(makeState(locale: "vi-VN").decimalKeyLabel, ",")
    }

    func testTheDecimalKeyInsertsThatSeparator() {
        let s = makeState(locale: "de-DE", significantDigits: 2)

        s.pressDigit(1)
        s.pressDecimalSeparator()
        s.pressDigit(5)

        XCTAssertEqual(s.rawText, "1,5")
        XCTAssertEqual(s.value, 1.5)
    }

    func testTheDecimalKeyIsOfferedOnce() {
        let s = makeState()
        XCTAssertTrue(s.decimalEnabled)

        s.pressDigit(1)
        s.pressDecimalSeparator()

        XCTAssertFalse(s.decimalEnabled, "a second separator would be refused")
        s.pressDecimalSeparator()
        XCTAssertEqual(s.rawText, "1.", "and pressing anyway changes nothing")
    }

    /// An integer-only field rejects any separator, so the key is dead and says so.
    func testTheDecimalKeyIsDisabledOnAnIntegerOnlyField() {
        let s = makeState(significantDigits: 0)

        XCTAssertFalse(s.decimalEnabled)
        s.pressDecimalSeparator()

        XCTAssertEqual(s.rawText, "")
    }

    // MARK: - the fraction cap

    func testDigitsAreRefusedOnceTheFractionIsFull() {
        let s = makeState(significantDigits: 2)
        s.pressDigit(1)
        s.pressDecimalSeparator()
        s.pressDigit(2)
        s.pressDigit(5)

        XCTAssertFalse(s.digitEnabled, "the fraction is full")
        s.pressDigit(7)

        XCTAssertEqual(s.rawText, "1.25", "the extra digit is refused, not appended")
        XCTAssertEqual(s.value, 1.25)
    }

    /// The keypad asks `NumberInputKeypadRules` and the state enforces the same condition in
    /// `onTextChange`. If those ever disagreed a key would look pressable and do nothing.
    func testADisabledDigitKeyAndARefusedPressAgree() {
        let s = makeState(significantDigits: 3)
        s.pressDigit(9)
        s.pressDecimalSeparator()

        for _ in 0..<5 {
            let enabledBefore = s.digitEnabled
            let before = s.rawText
            s.pressDigit(1)
            let changed = s.rawText != before
            XCTAssertEqual(enabledBefore, changed, "digitEnabled disagreed with the press at '\(before)'")
        }

        XCTAssertEqual(s.rawText, "9.111")
    }

    // MARK: - backspace

    func testBackspaceRemovesOneCharacterAtATime() {
        let s = makeState()
        [1, 2, 3].forEach(s.pressDigit)

        s.pressBackspace()
        XCTAssertEqual(s.rawText, "12")
        s.pressBackspace()
        XCTAssertEqual(s.rawText, "1")
        s.pressBackspace()
        XCTAssertEqual(s.rawText, "")
        XCTAssertNil(s.value)
    }

    /// One press per visible character, including the separator: "1.5" to "1." to "1".
    func testBackspaceOverTheSeparatorTakesOnePress() {
        let s = makeState()
        s.pressDigit(1)
        s.pressDecimalSeparator()
        s.pressDigit(5)
        XCTAssertEqual(s.rawText, "1.5")

        s.pressBackspace()
        XCTAssertEqual(s.rawText, "1.")

        s.pressBackspace()
        XCTAssertEqual(s.rawText, "1")
        XCTAssertEqual(s.value, 1.0)
    }

    func testBackspaceOnAnEmptyBufferIsANoOp() {
        let s = makeState()

        XCTAssertFalse(s.backspaceEnabled)
        s.pressBackspace()

        XCTAssertEqual(s.rawText, "")
        XCTAssertNil(s.value)
    }

    func testBackspaceIsOfferedWheneverThereIsSomethingToDelete() {
        let s = makeState()
        XCTAssertFalse(s.backspaceEnabled)

        s.pressDigit(5)

        XCTAssertTrue(s.backspaceEnabled)
    }

    func testClearingByBackspaceEmptiesTheValue() {
        let s = makeState(initialValue: 42.0)
        s.onFocusChanged(true)
        let length = s.rawText.count

        for _ in 0..<length { s.pressBackspace() }

        XCTAssertEqual(s.rawText, "")
        XCTAssertNil(s.value)
    }

    // MARK: - interaction with the rest of the field

    func testAKeypadEntryCommitsLikeAnyOther() {
        let s = makeState()
        [4, 2].forEach(s.pressDigit)

        s.onFocusChanged(false)

        XCTAssertEqual(s.phase, .idle)
        XCTAssertEqual(s.value, 42.0)
        XCTAssertEqual(s.rawText, "42.00", "canonicalised on commit")
    }

    func testTheToolbarActionsStillApplyWithTheKeypad() {
        let s = makeState()
        [1, 2].forEach(s.pressDigit)

        s.toggleSign()
        XCTAssertEqual(s.value, -12.0)

        s.clear()
        XCTAssertEqual(s.rawText, "")
        XCTAssertNil(s.value)
    }

    func testSignIsUnavailableWhenNegativesAreDisallowed() {
        let s = makeState(allowNegative: false)
        s.pressDigit(5)

        XCTAssertFalse(s.signEnabled)
        s.toggleSign()

        XCTAssertEqual(s.value, 5.0)
    }

    /// `rawText` is ungrouped on every platform, and the keypad must not be the thing that breaks it.
    func testKeypadEntryKeepsRawTextUngrouped() {
        let s = makeState(locale: "en-US", significantDigits: 1)

        [1, 2, 3, 4, 5, 6, 7].forEach(s.pressDigit)

        XCTAssertEqual(s.rawText, "1234567")
        XCTAssertEqual(s.value, 1234567.0)
    }

    // MARK: - the rules, asked directly

    func testDigitEnabledIsTrueWithNoSeparatorInTheBuffer() {
        XCTAssertTrue(NumberInputKeypadRules.digitEnabled(rawText: "12345", decimalSeparator: ".", significantDigits: 2))
    }

    func testDigitEnabledCountsOnlyFractionDigits() {
        XCTAssertTrue(NumberInputKeypadRules.digitEnabled(rawText: "1.2", decimalSeparator: ".", significantDigits: 2))
        XCTAssertFalse(NumberInputKeypadRules.digitEnabled(rawText: "1.23", decimalSeparator: ".", significantDigits: 2))
    }

    func testDecimalEnabledIsFalseOnAnIntegerOnlyField() {
        XCTAssertFalse(NumberInputKeypadRules.decimalEnabled(rawText: "", decimalSeparator: ".", significantDigits: 0))
    }

    func testDecimalEnabledIsFalseOnceASeparatorIsPresent() {
        XCTAssertTrue(NumberInputKeypadRules.decimalEnabled(rawText: "1", decimalSeparator: ".", significantDigits: 2))
        XCTAssertFalse(NumberInputKeypadRules.decimalEnabled(rawText: "1.", decimalSeparator: ".", significantDigits: 2))
    }

    func testBackspaceEnabledFollowsTheBuffer() {
        XCTAssertFalse(NumberInputKeypadRules.backspaceEnabled(rawText: ""))
        XCTAssertTrue(NumberInputKeypadRules.backspaceEnabled(rawText: "1"))
    }
}

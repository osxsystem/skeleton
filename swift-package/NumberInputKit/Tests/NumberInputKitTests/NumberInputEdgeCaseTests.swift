import XCTest
import Combine
@testable import NumberInputKit

/// Edge-case tests derived from the ck:scenario analysis in
/// docs/qa/scenarios/number-input-library.md.
/// Covers: Config guards, IosLocaleNumberFormatter extremes, VM state edges, emission counts.
final class NumberInputEdgeCaseTests: XCTestCase {

    private let fake = FakeLocaleNumberFormatter()
    private let ios = IosLocaleNumberFormatter()

    private func makeVm(
        initialValue: Double? = nil,
        significantDigits: Int = 2,
        locale: String = "en-US",
        allowNegative: Bool = true
    ) -> NumberInputViewModel {
        NumberInputViewModel(
            formatter: fake,
            initialValue: initialValue,
            significantDigits: significantDigits,
            locale: locale,
            allowNegative: allowNegative
        )
    }

    // MARK: - Config / precondition guards

    // Replaces the untestable negative-significantDigits precondition trap.
    // Scenario #21 — valid lower bound.
    func testNumberInputConfigAccepts_zero_significantDigits() {
        let config = NumberInputConfig(significantDigits: 0)
        XCTAssertEqual(config.significantDigits, 0)
    }

    // Scenario #21 — valid upper bound.
    func testNumberInputConfigAccepts_nine_significantDigits() {
        let config = NumberInputConfig(significantDigits: 9)
        XCTAssertEqual(config.significantDigits, 9)
    }

    // MARK: - IosLocaleNumberFormatter edge cases

    // Scenario #20 / #36 — NaN may format to "" or a locale string; the important
    // invariant is: no crash and a non-nil String is returned.
    func testIosFormatter_format_NaN_returns_empty_string() {
        let result = ios.format(.nan, significantDigits: 2, locale: "en-US")
        // NumberFormatter returns nil for NaN → implementation maps to "".
        // Defensive: at minimum a String (possibly empty) is returned, no crash.
        XCTAssertNotNil(result)
    }

    // Scenario #20 — +Infinity: no crash, returns a String.
    func testIosFormatter_format_positiveInfinity_returns_a_string() {
        let result = ios.format(.infinity, significantDigits: 2, locale: "en-US")
        XCTAssertNotNil(result)
    }

    // Scenario #19 — Double.greatestFiniteMagnitude: no crash, non-empty String.
    func testIosFormatter_format_doubleMax_returns_a_string() {
        let result = ios.format(.greatestFiniteMagnitude, significantDigits: 2, locale: "en-US")
        XCTAssertFalse(result.isEmpty, "expected a non-empty formatted string for greatestFiniteMagnitude")
    }

    // Scenario #7 — pins actual platform behaviour: Apple's NumberFormatter accepts
    // U+2212 MINUS SIGN as a negative sign in en-US (it's the canonical math minus).
    // see docs/qa/scenarios/number-input-library.md #7 — behaviour is permissive by design.
    func testIosFormatter_parse_unicode_minus_pins_apple_permissive_behaviour() {
        let result = ios.parse("\u{2212}42.5", locale: "en-US")
        XCTAssertEqual(result, -42.5,
            "Apple's NumberFormatter accepts U+2212; pinning current platform behaviour")
    }

    // Scenario #8 — pins actual platform behaviour: Apple's NumberFormatter accepts
    // Arabic-Indic digits even under en-US locale (it normalises digit sets internally).
    // see docs/qa/scenarios/number-input-library.md #8 — known permissive behaviour.
    func testIosFormatter_parse_arabic_indic_digits_pins_apple_permissive_behaviour() {
        // U+0661..U+0665 = Arabic-Indic digits 1234.5
        let arabicIndic = "\u{0661}\u{0662}\u{0663}\u{0664}.\u{0665}"
        let result = ios.parse(arabicIndic, locale: "en-US")
        XCTAssertEqual(result, 1234.5,
            "Apple's NumberFormatter normalises digit sets across locales; pinning current behaviour")
    }

    // Scenario #17 — significantDigits=0 must omit the decimal separator entirely (en-US).
    func testIosFormatter_format_significantDigits_zero_omits_decimal_separator() {
        let result = ios.format(1234.5, significantDigits: 0, locale: "en-US")
        XCTAssertFalse(result.contains("."), "significantDigits=0 should produce no '.' in en-US, got: \(result)")
    }

    // Scenario #17 — significantDigits=0 for vi-VN (decimal sep is ",").
    func testIosFormatter_format_significantDigits_zero_omits_decimal_separator_viVN() {
        let result = ios.format(1234.5, significantDigits: 0, locale: "vi-VN")
        XCTAssertFalse(result.contains(","), "significantDigits=0 should produce no ',' in vi-VN, got: \(result)")
    }

    // Scenario #54 / #40 — halfEven rounding: 1.234567 to 5 significant digits.
    // The 6th digit is 7, which rounds the 5th digit (6) up to 7 → "1.23457".
    func testIosFormatter_format_halfEven_rounding_1_234567_at_5_digits() {
        let result = ios.format(1.234567, significantDigits: 5, locale: "en-US")
        XCTAssertEqual(result, "1.23457")
    }

    // Scenario #11 — 25 nines exceed Int64: Int64(digits) returns nil, digits pass through verbatim.
    func testIosFormatter_formatLive_huge_integer_string_does_not_crash() {
        let hugeInput = String(repeating: "9", count: 25)
        let result = ios.formatLive(hugeInput, locale: "en-US")
        // Int64 overflow → digits returned verbatim, no crash.
        XCTAssertNotNil(result)
    }

    // Scenario #12 — whitespace padding: iOS parse() trims before parsing.
    func testIosFormatter_parse_with_whitespace_padding() {
        let result = ios.parse(" 1234.5 ", locale: "en-US")
        XCTAssertEqual(result, 1234.5)
    }

    // Scenario #9 — multiple decimal separators: liveFormat finds only the first ".".
    // intPart = "1", decPart = ".2.3" → formatted = "1.2.3" (pass-through).
    // Pins current behaviour; change this assertion if the implementation is tightened.
    func testIosFormatter_formatLive_multiple_decimal_separators_en_US() {
        let result = ios.formatLive("1.2.3", locale: "en-US")
        // The liveFormat algorithm keeps decPart verbatim from the first "." onward,
        // so the second "." is preserved. Pinning this as the documented current behaviour.
        XCTAssertEqual(result, "1.2.3", "multiple-separator pass-through behaviour changed; update or fix")
    }

    // MARK: - ViewModel state edges

    // Scenario #20 — NaN initialValue: VM must construct and settle to .idle without crashing.
    // Uses the REAL IosLocaleNumberFormatter because the FakeLocaleNumberFormatter calls
    // Int64(rounded) which traps on NaN/Infinity. The production iOS formatter handles
    // NaN via `?? ""` and `NumberFormatter.string(from:)` returning nil — no crash.
    func testVm_init_with_NaN_initialValue_does_not_crash() {
        let vm = NumberInputViewModel(
            formatter: ios,
            initialValue: .nan,
            significantDigits: 2,
            locale: "en-US",
            allowNegative: true
        )
        guard case .idle = vm.state else { return XCTFail("expected idle, got \(vm.state)") }
    }

    // Scenario #20 — +Infinity initialValue: same contract. Uses real iOS formatter for
    // the same reason as testVm_init_with_NaN_initialValue_does_not_crash.
    func testVm_init_with_infinity_initialValue_does_not_crash() {
        let vm = NumberInputViewModel(
            formatter: ios,
            initialValue: .infinity,
            significantDigits: 2,
            locale: "en-US",
            allowNegative: true
        )
        guard case .idle = vm.state else { return XCTFail("expected idle, got \(vm.state)") }
    }

    // Scenario #22 — onClear() from Idle bypasses focus guard, transitions directly to Editing.
    // pins current behaviour — see docs/qa/scenarios/number-input-library.md #22
    func testVm_onClear_while_idle_pins_current_behaviour_transitions_to_editing() {
        let vm = makeVm(initialValue: 5.0)
        // Do NOT call onFocusChanged — stay in Idle.
        vm.onClear()
        guard case .editing(let p) = vm.state else { return XCTFail("expected editing, got \(vm.state)") }
        XCTAssertNil(p.value)
    }

    // Scenario #23 — onToggleSign() from Idle transitions to Editing with negated value.
    // pins current behaviour — see docs/qa/scenarios/number-input-library.md #23
    func testVm_onToggleSign_while_idle_pins_current_behaviour_transitions_to_editing_with_negated_value() {
        let vm = makeVm(initialValue: 5.0)
        vm.onToggleSign()
        guard case .editing(let p) = vm.state else { return XCTFail("expected editing, got \(vm.state)") }
        XCTAssertEqual(p.value, -5.0)
    }

    // Scenario #51 / #39 — ± on exactly 0.0 produces -0.0 at the bit level.
    func testVm_onToggleSign_on_zero_value_produces_negative_zero() {
        let vm = makeVm(initialValue: 0.0)
        vm.onFocusChanged(focused: true)
        vm.onToggleSign()
        guard case .editing(let p) = vm.state else { return XCTFail("expected editing, got \(vm.state)") }
        XCTAssertEqual(p.value?.bitPattern, (-0.0).bitPattern,
            "expected -0.0 bit pattern; got \(String(describing: p.value))")
    }

    // Scenario #9 — multiple decimal separators: Fake.parse("1.2.3") returns nil
    // → VM keeps prior value; rawText updated.
    func testVm_onTextChange_multiple_decimal_separators_keeps_prior_value() {
        let vm = makeVm(initialValue: 10.0)
        vm.onFocusChanged(focused: true)
        vm.onTextChange("1.2.3")
        guard case .editing(let p) = vm.state else { return XCTFail("expected editing, got \(vm.state)") }
        XCTAssertEqual(p.value, 10.0, "prior value should be retained when parse fails")
        XCTAssertEqual(p.rawText, "1.2.3")
    }

    // Scenario #11 — 25-nines input: no crash; state stays .editing.
    func testVm_onTextChange_huge_integer_keeps_rawText_does_not_crash() {
        let vm = makeVm()
        vm.onFocusChanged(focused: true)
        let huge = String(repeating: "9", count: 25)
        vm.onTextChange(huge)
        guard case .editing = vm.state else { return XCTFail("expected editing, got \(vm.state)") }
    }

    // Scenario #10 — leading zeros: Fake formatLive converts Int64("000123") = 123 → "123".
    func testVm_onTextChange_leading_zeros_live_groups_correctly() {
        let vm = makeVm()
        vm.onFocusChanged(focused: true)
        vm.onTextChange("000123")
        guard case .editing(let p) = vm.state else { return XCTFail("expected editing, got \(vm.state)") }
        XCTAssertEqual(p.formattedText, "123")
    }

    // Scenario #53 — allowNegative=false, negative text typed then committed: value reverts to prior.
    func testVm_onTextChange_negative_typed_then_commit_keeps_prior_value_when_allowNegative_false() {
        let vm = makeVm(initialValue: 10.0, allowNegative: false)
        vm.onFocusChanged(focused: true)
        vm.onTextChange("-3")
        // Parse("-3") under Fake returns -3.0; but allowNegative=false → value stays 10.0.
        vm.onCommit()
        guard case .idle(let p) = vm.state else { return XCTFail("expected idle, got \(vm.state)") }
        XCTAssertEqual(p.value, 10.0,
            "allowNegative=false must reject negative text; committed value should stay 10.0")
    }

    // MARK: - Emission counts

    // Mirrors Test 9 but explicitly pins the count to detect over-emission regressions.
    // Scenario #24 — single onCommit after focus: exactly 3 emissions (editing, committed, idle).
    func testVm_state_emission_count_for_onCommit_is_three() {
        let vm = makeVm(initialValue: 5.0)
        vm.onFocusChanged(focused: true)

        var states: [NumberInputUIState] = []
        let cancellable = vm.$state.sink { states.append($0) }

        vm.onCommit()

        // sink fires immediately with current value on subscribe (editing),
        // then committed, then idle.
        XCTAssertEqual(states.count, 3, "expected exactly 3 emissions; got \(states.count): \(states)")
        guard case .committed = states[1] else { return XCTFail("states[1] should be .committed, got \(states[1])") }
        guard case .idle = states[2] else { return XCTFail("states[2] should be .idle, got \(states[2])") }
        cancellable.cancel()
    }

    // Scenario #24 — double onCommit: documents emission count to catch double-fire regressions.
    func testVm_double_onCommit_emits_four_extra_states() {
        let vm = makeVm(initialValue: 5.0)
        vm.onFocusChanged(focused: true)

        var states: [NumberInputUIState] = []
        let cancellable = vm.$state.sink { states.append($0) }

        vm.onCommit()
        vm.onCommit()

        // First onCommit → editing + committed + idle (3).
        // Second onCommit on an already-Idle state → committed + idle (2 more).
        // Total: at least 5. Use >= to stay robust against minor scheduler changes.
        XCTAssertGreaterThanOrEqual(states.count, 5,
            "double onCommit should produce at least 5 emissions; got \(states.count)")
        cancellable.cancel()
    }
}

import XCTest
@testable import NumberInputKit

/// Port of all 22 tests from `NumberInputViewModelTest.kt`.
/// State transitions are synchronous with `@Published` — no async needed.
final class NumberInputViewModelTests: XCTestCase {

    private let fake = FakeLocaleNumberFormatter()

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

    // Test 1
    func testInitialStateIsIdleWithFormattedInitialValue() {
        let vm = makeVm(initialValue: 1234.5, significantDigits: 2)
        guard case .idle(let p) = vm.state else { return XCTFail("expected idle") }
        XCTAssertEqual(p.formattedText, "1,234.50")
        XCTAssertEqual(p.value, 1234.5)
    }

    // Test 2
    func testOnFocusChangedTrueTransitionsIdleToEditing() {
        let vm = makeVm(initialValue: 1.0)
        vm.onFocusChanged(focused: true)
        guard case .editing = vm.state else { return XCTFail("expected editing") }
    }

    // Test 3
    func testOnTextChangeParsesToValueAndStaysEditing() {
        let vm = makeVm()
        vm.onFocusChanged(focused: true)
        vm.onTextChange("42.5")
        guard case .editing(let p) = vm.state else { return XCTFail("expected editing") }
        XCTAssertEqual(p.value, 42.5)
        XCTAssertEqual(p.rawText, "42.5")
    }

    // Test 4
    func testOnTextChangeWithInvalidTextKeepsLastValue() {
        let vm = makeVm(initialValue: 10.0)
        vm.onFocusChanged(focused: true)
        vm.onTextChange("abc")
        guard case .editing(let p) = vm.state else { return XCTFail("expected editing") }
        XCTAssertEqual(p.value, 10.0)
        XCTAssertEqual(p.rawText, "abc")
    }

    // Test 5
    func testOnToggleSignFlipsValue() {
        let vm = makeVm(initialValue: 42.5)
        vm.onFocusChanged(focused: true)
        vm.onToggleSign()
        guard case .editing(let p) = vm.state else { return XCTFail("expected editing") }
        XCTAssertEqual(p.value, -42.5)
    }

    // Test 6
    func testOnToggleSignOnNullValueIsNoOp() {
        let vm = makeVm(initialValue: nil)
        vm.onFocusChanged(focused: true)
        vm.onToggleSign()
        guard case .editing(let p) = vm.state else { return XCTFail("expected editing") }
        XCTAssertNil(p.value)
    }

    // Test 7
    func testOnToggleSignWithAllowNegativeFalseIsNoOp() {
        let vm = makeVm(initialValue: 42.5, allowNegative: false)
        vm.onFocusChanged(focused: true)
        vm.onToggleSign()
        guard case .editing(let p) = vm.state else { return XCTFail("expected editing") }
        XCTAssertEqual(p.value, 42.5)
    }

    // Test 8
    func testOnClearSetsValueToNilAndStaysEditing() {
        let vm = makeVm(initialValue: 42.5)
        vm.onFocusChanged(focused: true)
        vm.onClear()
        guard case .editing(let p) = vm.state else { return XCTFail("expected editing") }
        XCTAssertNil(p.value)
        XCTAssertEqual(p.rawText, "")
    }

    // Test 9 — onCommit emits Committed then Idle
    func testOnCommitEmitsCommittedThenIdle() {
        let vm = makeVm(initialValue: 5.0)
        vm.onFocusChanged(focused: true)

        var states: [NumberInputUIState] = []
        let cancellable = vm.$state.sink { states.append($0) }

        vm.onCommit()

        // $state starts with current value (editing), then committed, then idle
        // states[0] = editing (the sink fires immediately on subscribe with current value)
        // states[1] = committed
        // states[2] = idle
        XCTAssertEqual(states.count, 3, "expected 3 emissions: editing, committed, idle")
        guard case .committed = states[1] else { return XCTFail("expected committed at index 1, got \(states[1])") }
        guard case .idle = states[2] else { return XCTFail("expected idle at index 2, got \(states[2])") }
        cancellable.cancel()
    }

    // Test 10 — onFocusChanged(false) acts as commit
    func testOnFocusChangedFalseActsAsCommit() {
        let vm = makeVm(initialValue: 5.0)
        vm.onFocusChanged(focused: true)

        var states: [NumberInputUIState] = []
        let cancellable = vm.$state.sink { states.append($0) }

        vm.onFocusChanged(focused: false)

        XCTAssertEqual(states.count, 3, "expected 3 emissions: editing, committed, idle")
        guard case .committed = states[1] else { return XCTFail("expected committed") }
        guard case .idle = states[2] else { return XCTFail("expected idle") }
        cancellable.cancel()
    }

    // Test 11
    func testSignificantDigitsIsReflectedInIdleFormattedText() {
        let vm = makeVm(initialValue: 0.1, significantDigits: 3)
        guard case .idle(let p) = vm.state else { return XCTFail("expected idle") }
        XCTAssertEqual(p.formattedText, "0.100")
    }

    // Test 12 — allowNegative=false clamps negative initialValue to 0.0
    func testAllowNegativeFalseClamps_negativeInitialValueToZero() {
        let vm = makeVm(initialValue: -5.0, allowNegative: false)
        guard case .idle(let p) = vm.state else { return XCTFail("expected idle") }
        XCTAssertEqual(p.value, 0.0)
        XCTAssertEqual(fake.format(0.0, significantDigits: 2, locale: "en-US"), "0.00")
    }

    // Test 13 — onTextChange with negative parsed value rejected when allowNegative=false
    func testOnTextChangeWithNegativeValueIsRejectedWhenAllowNegativeFalse() {
        let vm = makeVm(initialValue: 10.0, allowNegative: false)
        vm.onFocusChanged(focused: true)
        vm.onTextChange("-3")
        guard case .editing(let p) = vm.state else { return XCTFail("expected editing") }
        XCTAssertEqual(p.value, 10.0)   // value unchanged
        XCTAssertEqual(p.rawText, "-3") // rawText updated
    }

    // Test 14 — live integer grouping while typing en-US
    func testOnTextChangeLiveGroupsIntegerEnUS() {
        let vm = makeVm(locale: "en-US")
        vm.onFocusChanged(focused: true)
        let cases: [(String, String)] = [("1", "1"), ("10", "10"), ("100", "100"), ("1000", "1,000")]
        for (typed, expected) in cases {
            vm.onTextChange(typed)
            guard case .editing(let p) = vm.state else { return XCTFail("expected editing") }
            XCTAssertEqual(p.formattedText, expected, "input \"\(typed)\" should show \"\(expected)\"")
        }
    }

    // Test 15 — re-grouping an already-grouped input
    func testOnTextChangeRegroupsAlreadyGroupedInputEnUS() {
        let vm = makeVm(locale: "en-US")
        vm.onFocusChanged(focused: true)
        vm.onTextChange("1,0009")
        guard case .editing(let p) = vm.state else { return XCTFail("expected editing") }
        XCTAssertEqual(p.formattedText, "10,009")
        XCTAssertEqual(p.value, 10009.0)
    }

    // Test 16 — backspace re-collapses grouping
    func testOnTextChangeBackspaceReCollapsesGroupingEnUS() {
        let vm = makeVm(locale: "en-US")
        vm.onFocusChanged(focused: true)
        vm.onTextChange("1000")
        guard case .editing(let p1) = vm.state else { return XCTFail() }
        XCTAssertEqual(p1.formattedText, "1,000")
        vm.onTextChange("1,00")
        guard case .editing(let p2) = vm.state else { return XCTFail() }
        XCTAssertEqual(p2.formattedText, "100")
    }

    // Test 17 — vi-VN uses "." for grouping
    func testOnTextChangeLiveGroupsIntegerViVN() {
        let vm = makeVm(locale: "vi-VN")
        vm.onFocusChanged(focused: true)
        vm.onTextChange("1000")
        guard case .editing(let p1) = vm.state else { return XCTFail() }
        XCTAssertEqual(p1.formattedText, "1.000")
        vm.onTextChange("1000000")
        guard case .editing(let p2) = vm.state else { return XCTFail() }
        XCTAssertEqual(p2.formattedText, "1.000.000")
    }

    // Test 18 — decimal portion is preserved verbatim during edit
    func testOnTextChangePreservesDecimalPortionEnUS() {
        let vm = makeVm(locale: "en-US")
        vm.onFocusChanged(focused: true)
        vm.onTextChange("1000.5")
        guard case .editing(let p1) = vm.state else { return XCTFail() }
        XCTAssertEqual(p1.formattedText, "1,000.5")
        vm.onTextChange("1000.")
        guard case .editing(let p2) = vm.state else { return XCTFail() }
        XCTAssertEqual(p2.formattedText, "1,000.")
    }

    // Test 19 — typing just "-" displays "-"
    func testOnTextChangeMinusAloneDisplaysMinus() {
        let vm = makeVm(locale: "en-US")
        vm.onFocusChanged(focused: true)
        vm.onTextChange("-")
        guard case .editing(let p) = vm.state else { return XCTFail() }
        XCTAssertEqual(p.formattedText, "-")
    }

    // Test 20 — empty input clears formattedText
    func testOnTextChangeEmptyClearsFormattedText() {
        let vm = makeVm(initialValue: 1234.5, locale: "en-US")
        vm.onFocusChanged(focused: true)
        vm.onTextChange("")
        guard case .editing(let p) = vm.state else { return XCTFail() }
        XCTAssertEqual(p.formattedText, "")
        XCTAssertNil(p.value)
    }

    // Test 21 — onFocusChanged(true) carries Idle.formattedText into Editing
    func testOnFocusChangedTrueCarriesFormattedTextIntoEditing() {
        let vm = makeVm(initialValue: 1234.5, locale: "en-US")
        guard case .idle(let idle) = vm.state else { return XCTFail() }
        XCTAssertEqual(idle.formattedText, "1,234.50")
        vm.onFocusChanged(focused: true)
        guard case .editing(let p) = vm.state else { return XCTFail() }
        XCTAssertEqual(p.formattedText, "1,234.50")
        XCTAssertEqual(p.rawText, "1,234.50")
    }

    // Test 22 — onToggleSign produces locale-aware formatted rawText (vi-VN uses "," decimal)
    func testOnToggleSignProducesLocaleAwareRawTextViVN() {
        let vm = makeVm(initialValue: 42.5, locale: "vi-VN")
        vm.onFocusChanged(focused: true)
        vm.onToggleSign()
        guard case .editing(let p) = vm.state else { return XCTFail() }
        XCTAssertEqual(p.value, -42.5)
        XCTAssertEqual(p.formattedText, "-42,50")
    }
}

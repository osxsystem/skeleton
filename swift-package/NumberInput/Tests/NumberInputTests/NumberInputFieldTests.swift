import XCTest
@testable import NumberInput

/// Unit tests for NumberInputBridge — tests the VM bridging logic without UI.
/// Full XCUITest integration tests require the iosApp target and are run separately.
final class NumberInputFieldTests: XCTestCase {

    private func makeBridge(
        initialValue: Double? = nil,
        significantDigits: Int = 2,
        locale: String = "en-US",
        allowNegative: Bool = true
    ) -> NumberInputBridge {
        let config = NumberInputConfig(
            significantDigits: Int32(significantDigits),
            locale: locale,
            allowNegative: allowNegative,
            placeholder: ""
        )
        return NumberInputBridge(initialValue: initialValue, config: config)
    }

    // Test 1: field displays formatted value when idle
    func testFieldDisplaysFormattedValueWhenIdle() {
        let bridge = makeBridge(initialValue: 1234.5, significantDigits: 2, locale: "en-US")
        // After init the bridge should show formattedText (idle state)
        let expectation = XCTestExpectation(description: "displayText updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(bridge.displayText, "1,234.50")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // Test 2: toolbar clear disabled when value is nil and rawText is empty
    func testClearDisabledWhenEmpty() {
        let bridge = makeBridge(initialValue: nil)
        let expectation = XCTestExpectation(description: "clearDisabled state")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(bridge.clearDisabled)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // Test 3: clear action empties value
    func testClearEmptiesValue() {
        let bridge = makeBridge(initialValue: 42.0)
        bridge.handleFocus(focused: true)
        let expectation = XCTestExpectation(description: "value cleared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            bridge.clear()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertNil(bridge.publishedValue)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    // Test 4: toggleSign flips sign
    func testToggleSignFlipsSign() {
        let bridge = makeBridge(initialValue: 42.0)
        bridge.handleFocus(focused: true)
        let expectation = XCTestExpectation(description: "sign toggled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            bridge.toggleSign()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertEqual(bridge.publishedValue, -42.0)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    // Test 5: commit triggers focus loss (displayText becomes formatted)
    func testCommitFormatsDisplayText() {
        let bridge = makeBridge(initialValue: 1234.5, significantDigits: 2, locale: "en-US")
        bridge.handleFocus(focused: true)
        let expectation = XCTestExpectation(description: "committed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            bridge.commit()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertEqual(bridge.displayText, "1,234.50")
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }

    // Test 6: signDisabled when allowNegative is false
    func testSignButtonDisabledWhenAllowNegativeFalse() {
        let bridge = makeBridge(initialValue: 42.0, allowNegative: false)
        let expectation = XCTestExpectation(description: "sign disabled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(bridge.signDisabled)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

#if canImport(UIKit)
import SwiftUI
import UIKit
import XCTest
@testable import NumberInputKit

@MainActor
final class NumberInputUIKitPresentationAndBindingRegressionTests: XCTestCase {
    func testBuiltInKeypadPresentsPublishesLiveAndCommitsOnFocusLoss() {
        let harness = mountField(useBuiltInKeypad: true)
        defer { unmount(harness) }

        XCTAssertTrue(harness.textField.becomeFirstResponder())
        waitForNextMainQueueTurn()

        XCTAssertTrue(harness.textField.isFirstResponder)
        let inputView = try? XCTUnwrap(harness.textField.inputView as? NumberInputKeypadView)
        XCTAssertNotNil(inputView)
        XCTAssertGreaterThan(
            inputView?.intrinsicContentSize.height ?? 0,
            0,
            "A zero-height custom input view reproduces the missing keypad and toolbar"
        )
        XCTAssertGreaterThan(
            inputView?.frame.height ?? 0,
            0,
            "UIKit receives a zero-height input-view frame and presents no keypad or toolbar"
        )

        harness.textField.text = "42.5"
        guard let coordinator = harness.textField.delegate as? NumberInputUITextField.Coordinator else {
            XCTFail("NumberInputField did not retain its coordinator as the text-field delegate")
            return
        }
        coordinator.textChanged(harness.textField)
        waitForNextMainQueueTurn()

        XCTAssertTrue(harness.textField.isFirstResponder)
        XCTAssertEqual(harness.textField.text, "42.5")
        XCTAssertEqual(harness.value.value, 42.5)

        harness.textField.text = "7"
        coordinator.textChanged(harness.textField)
        XCTAssertEqual(harness.value.value, 7)

        XCTAssertTrue(harness.textField.resignFirstResponder())
        waitForNextMainQueueTurn()

        XCTAssertFalse(harness.textField.isFirstResponder)
        XCTAssertEqual(harness.textField.text, "7.00")
        XCTAssertEqual(harness.value.value, 7)
    }

    func testBuiltInKeypadActionsPublishExternalBindingImmediately() {
        let harness = mountField(useBuiltInKeypad: true)
        defer { unmount(harness) }
        guard let coordinator = harness.textField.delegate as? NumberInputUITextField.Coordinator else {
            XCTFail("NumberInputField did not retain its coordinator as the text-field delegate")
            return
        }

        coordinator.parent.state.pressDigit(4)
        coordinator.parent.state.pressDigit(2)
        XCTAssertEqual(harness.value.value, 42)

        coordinator.parent.state.clear()
        XCTAssertNil(harness.value.value)
    }

    func testSystemKeyboardRemainsTheDefaultInputPath() {
        let harness = mountField(useBuiltInKeypad: false)
        defer { unmount(harness) }

        XCTAssertNil(harness.textField.inputView)
        XCTAssertTrue(harness.textField.inputAccessoryView is UIToolbar)

    }

    private func mountField(useBuiltInKeypad: Bool) -> Harness {
        let value = ValueBox()
        let field = NumberInputField(
            value: Binding(
                get: { value.value },
                set: { value.value = $0 }
            ),
            config: NumberInputConfig(
                significantDigits: 2,
                locale: "en-US",
                useBuiltInKeypad: useBuiltInKeypad,
                keypadHaptics: false
            )
        )
        let host = UIHostingController(rootView: field)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        waitForNextMainQueueTurn()

        guard let textField = findTextField(in: host.view) else {
            XCTFail("NumberInputField did not install its UIKit text field")
            fatalError("NumberInputField did not install its UIKit text field")
        }
        return Harness(value: value, window: window, host: host, textField: textField)
    }

    private func findTextField(in view: UIView) -> NumberInputNativeTextField? {
        if let field = view as? NumberInputNativeTextField { return field }
        for child in view.subviews {
            if let field = findTextField(in: child) { return field }
        }
        return nil
    }

    private func unmount(_ harness: Harness) {
        harness.textField.resignFirstResponder()
        harness.window.isHidden = true
        harness.window.rootViewController = nil
        waitForNextMainQueueTurn()
    }

    private func waitForNextMainQueueTurn() {
        let completed = expectation(description: "next main queue turn")
        DispatchQueue.main.async { completed.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [completed], timeout: 1), .completed)
    }
}

private final class ValueBox {
    var value: Double?
}

@MainActor
private struct Harness {
    let value: ValueBox
    let window: UIWindow
    let host: UIHostingController<NumberInputField<EmptyView>>
    let textField: NumberInputNativeTextField
}
#endif

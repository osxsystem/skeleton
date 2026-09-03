#if canImport(UIKit)
import SwiftUI
import UIKit
import XCTest
@testable import NumberInputKit

@MainActor
final class NumberInputToolbarActionDispatchRegressionTests: XCTestCase {
    func testExternalFocusBindingRequestsAndResignsFirstResponder() throws {
        let focus = FocusBox()
        let root = FocusControlledField(focus: focus)
        let host = UIHostingController(rootView: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        drainMainRunLoop()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            drainMainRunLoop()
        }

        let textField = try XCTUnwrap(findTextField(in: host.view))
        XCTAssertFalse(textField.isFirstResponder)

        focus.focused = true
        drainMainRunLoop()
        XCTAssertTrue(textField.isFirstResponder)

        focus.focused = false
        drainMainRunLoop()
        XCTAssertFalse(textField.isFirstResponder)

        XCTAssertTrue(textField.becomeFirstResponder())
        drainMainRunLoop()
        XCTAssertTrue(focus.focused)

        XCTAssertTrue(textField.resignFirstResponder())
        drainMainRunLoop()
        XCTAssertFalse(focus.focused)
    }

    func testMountedBuiltInToolbarDispatchesEveryAction() throws {
        let harness = mountField(initialValue: 12.5)
        defer { unmount(harness) }

        XCTAssertTrue(harness.textField.becomeFirstResponder())
        drainMainRunLoop()

        let keypad = try XCTUnwrap(harness.textField.inputView as? NumberInputKeypadView)

        for identifier in [
            NumberInputTags.toolbarPrevious,
            NumberInputTags.toolbarNext,
            NumberInputTags.toolbarSign,
            NumberInputTags.toolbarClear,
            NumberInputTags.toolbarDone
        ] {
            let matches = buttons(withIdentifier: identifier, in: keypad)
            XCTAssertEqual(matches.count, 1, "Toolbar exposes exactly one control for \(identifier)")
            let button = try XCTUnwrap(matches.first)
            XCTAssertTrue(button.isAccessibilityElement)
            XCTAssertTrue(button.accessibilityTraits.contains(.button))
            XCTAssertGreaterThan(button.bounds.width, 0)
            XCTAssertGreaterThan(button.bounds.height, 0)
        }

        try activate(NumberInputTags.toolbarPrevious, in: keypad)
        try activate(NumberInputTags.toolbarNext, in: keypad)
        XCTAssertEqual(harness.previousCount, 1)
        XCTAssertEqual(harness.nextCount, 1)

        try activate(NumberInputTags.toolbarSign, in: keypad)
        drainMainRunLoop()
        XCTAssertEqual(harness.value.value, -12.5)

        try activate(NumberInputTags.toolbarClear, in: keypad)
        drainMainRunLoop()
        XCTAssertNil(harness.value.value)

        harness.textField.text = "7.1"
        let coordinator = try XCTUnwrap(
            harness.textField.delegate as? NumberInputUITextField.Coordinator
        )
        coordinator.textChanged(harness.textField)
        try activate(NumberInputTags.toolbarDone, in: keypad)
        drainMainRunLoop()

        XCTAssertEqual(harness.value.value, 7.1)
        XCTAssertEqual(harness.textField.text, "7.10")
        XCTAssertFalse(harness.textField.isFirstResponder)
    }

    func testMountedBuiltInToolbarIsInsideInputViewHitTestBounds() throws {
        let harness = mountField(initialValue: 12.5)
        defer { unmount(harness) }

        XCTAssertTrue(harness.textField.becomeFirstResponder())
        drainMainRunLoop()

        let keypad = try XCTUnwrap(harness.textField.inputView as? NumberInputKeypadView)
        XCTAssertLessThan(keypad.bounds.height, UIScreen.main.bounds.height / 2)
        for identifier in [
            NumberInputTags.toolbarPrevious,
            NumberInputTags.toolbarNext,
            NumberInputTags.toolbarSign,
            NumberInputTags.toolbarClear,
            NumberInputTags.toolbarDone
        ] {
            let button = try XCTUnwrap(button(withIdentifier: identifier, in: keypad))
            let frame = button.convert(button.bounds, to: keypad)
            let center = CGPoint(x: frame.midX, y: frame.midY)
            XCTAssertTrue(
                keypad.bounds.contains(center),
                "Toolbar control \(identifier) is visible outside the input view hit-test bounds: "
                    + "button=\(frame), input=\(keypad.bounds)"
            )
            let hit = keypad.hitTest(center, with: nil)
            XCTAssertTrue(
                hit === button || (hit?.isDescendant(of: button) ?? false),
                "Toolbar control \(identifier) is not the input view hit-test result"
            )
        }
    }

    func testBuiltInKeypadKeepsItsAssigned320PointWidthDuringHeightSynchronization() {
        let state = NumberInputState(
            formatter: FakeLocaleNumberFormatter(),
            initialValue: 12.5,
            config: NumberInputConfig(useBuiltInKeypad: true)
        )
        let keypad = NumberInputKeypadView(
            state: state,
            style: NumberInputStyle(),
            leadingAccessory: nil,
            onPrevious: {},
            onNext: {},
            hostWidth: 320,
            onDone: {}
        )
        keypad.frame = CGRect(x: 0, y: 0, width: 320, height: 1)
        keypad.layoutIfNeeded()
        drainMainRunLoop()

        XCTAssertEqual(keypad.bounds.width, 320, accuracy: 0.5)
        XCTAssertGreaterThan(keypad.bounds.height, 1)
    }

    func testMountedBuiltInToolbarOmitsSignWhenNegativesAreDisallowed() throws {
        let harness = mountField(initialValue: 12.5, allowNegative: false)
        defer { unmount(harness) }

        XCTAssertTrue(harness.textField.becomeFirstResponder())
        drainMainRunLoop()

        let keypad = try XCTUnwrap(harness.textField.inputView as? NumberInputKeypadView)
        XCTAssertNil(button(withIdentifier: NumberInputTags.toolbarSign, in: keypad))
    }

    func testMountedBuiltInToolbarOmitsUnavailableNavigationActions() throws {
        let harness = mountField(initialValue: 12.5, includeNavigation: false)
        defer { unmount(harness) }

        XCTAssertTrue(harness.textField.becomeFirstResponder())
        drainMainRunLoop()

        let keypad = try XCTUnwrap(harness.textField.inputView as? NumberInputKeypadView)
        XCTAssertNil(button(withIdentifier: NumberInputTags.toolbarPrevious, in: keypad))
        XCTAssertNil(button(withIdentifier: NumberInputTags.toolbarNext, in: keypad))
        XCTAssertNotNil(button(withIdentifier: NumberInputTags.toolbarDone, in: keypad))
    }

    private func activate(_ identifier: String, in root: UIView) throws {
        if let button = button(withIdentifier: identifier, in: root) {
            XCTAssertTrue(
                dispatchTouchUpInside(button),
                "Mounted UIKit control \(identifier) has no touch-up action target"
            )
            drainMainRunLoop()
            return
        }
        let activate = try XCTUnwrap(
            accessibilityElement(withIdentifier: identifier, in: root),
            "Missing mounted toolbar element \(identifier)"
        )
        XCTAssertTrue(
            activate(),
            "Mounted toolbar element \(identifier) did not dispatch its action"
        )
        drainMainRunLoop()
    }

    private func dispatchTouchUpInside(_ button: UIButton) -> Bool {
        var dispatched = false
        for target in button.allTargets {
            guard let object = target.base as? NSObject else { continue }
            for action in button.actions(forTarget: object, forControlEvent: .touchUpInside) ?? [] {
                guard object.responds(to: NSSelectorFromString(action)) else { continue }
                _ = object.perform(NSSelectorFromString(action), with: button)
                dispatched = true
            }
        }
        return dispatched
    }

    private func button(withIdentifier identifier: String, in root: UIView) -> UIButton? {
        if let button = root as? UIButton,
           button.accessibilityIdentifier == identifier {
            return button
        }
        for child in root.subviews {
            if let button = button(withIdentifier: identifier, in: child) { return button }
        }
        return nil
    }

    private func buttons(withIdentifier identifier: String, in root: UIView) -> [UIButton] {
        var matches: [UIButton] = []
        if let button = root as? UIButton,
           button.accessibilityIdentifier == identifier {
            matches.append(button)
        }
        for child in root.subviews {
            matches.append(contentsOf: buttons(withIdentifier: identifier, in: child))
        }
        return matches
    }

    private func accessibilityElement(
        withIdentifier identifier: String,
        in root: UIView
    ) -> (() -> Bool)? {
        if root.accessibilityIdentifier == identifier {
            return { root.accessibilityActivate() }
        }
        for element in root.accessibilityElements ?? [] {
            if let view = element as? UIView,
               view.accessibilityIdentifier == identifier {
                return { view.accessibilityActivate() }
            }
            if let accessibilityElement = element as? UIAccessibilityElement,
               accessibilityElement.accessibilityIdentifier == identifier {
                return { accessibilityElement.accessibilityActivate() }
            }
        }
        let elementCount = root.accessibilityElementCount()
        if elementCount > 0 {
            for index in 0..<elementCount {
                guard let element = root.accessibilityElement(at: index) else { continue }
                if let view = element as? UIView,
                   view.accessibilityIdentifier == identifier {
                    return { view.accessibilityActivate() }
                }
                if let accessibilityElement = element as? UIAccessibilityElement,
                   accessibilityElement.accessibilityIdentifier == identifier {
                    return { accessibilityElement.accessibilityActivate() }
                }
            }
        }
        for child in root.subviews {
            if let match = accessibilityElement(withIdentifier: identifier, in: child) {
                return match
            }
        }
        return nil
    }

    private func mountField(
        initialValue: Double?,
        allowNegative: Bool = true,
        includeNavigation: Bool = true
    ) -> Harness {
        let value = ValueBox(initialValue)
        let counts = ActionCounts()
        let onPrevious: (() -> Void)? = includeNavigation ? { counts.previous += 1 } : nil
        let onNext: (() -> Void)? = includeNavigation ? { counts.next += 1 } : nil
        let field = NumberInputField(
            value: Binding(
                get: { value.value },
                set: { value.value = $0 }
            ),
            config: NumberInputConfig(
                significantDigits: 2,
                locale: "en-US",
                allowNegative: allowNegative,
                useBuiltInKeypad: true,
                keypadHaptics: false
            ),
            onPrevious: onPrevious,
            onNext: onNext
        )
        let host = UIHostingController(rootView: field)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        drainMainRunLoop()

        guard let textField = findTextField(in: host.view) else {
            XCTFail("NumberInputField did not install its UIKit text field")
            fatalError("NumberInputField did not install its UIKit text field")
        }
        return Harness(
            value: value,
            counts: counts,
            window: window,
            host: host,
            textField: textField
        )
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
        drainMainRunLoop()
    }

    private func drainMainRunLoop() {
        var completed = false
        Task { @MainActor in
            for _ in 0..<5 { await Task.yield() }
            completed = true
        }
        let deadline = Date(timeIntervalSinceNow: 1)
        while !completed, Date() < deadline {
            _ = RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        }
        XCTAssertTrue(completed, "Timed out draining pending main-queue updates")
    }
}

private final class ValueBox {
    var value: Double?

    init(_ value: Double?) {
        self.value = value
    }
}

private final class ActionCounts {
    var previous = 0
    var next = 0
}

private final class FocusBox: ObservableObject {
    @Published var focused = false
    var value: Double? = 12.5
}

private struct FocusControlledField: View {
    @ObservedObject var focus: FocusBox

    var body: some View {
        NumberInputField(
            value: Binding(
                get: { focus.value },
                set: { focus.value = $0 }
            ),
            config: NumberInputConfig(
                significantDigits: 2,
                locale: "en-US",
                useBuiltInKeypad: true,
                keypadHaptics: false
            ),
            focused: $focus.focused
        )
    }
}

@MainActor
private struct Harness {
    let value: ValueBox
    let counts: ActionCounts
    let window: UIWindow
    let host: UIHostingController<NumberInputField<EmptyView>>
    let textField: NumberInputNativeTextField

    var previousCount: Int { counts.previous }
    var nextCount: Int { counts.next }
}
#endif

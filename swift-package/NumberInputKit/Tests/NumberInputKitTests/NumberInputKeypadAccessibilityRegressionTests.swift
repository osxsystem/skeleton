#if canImport(UIKit)
import UIKit
import XCTest
@testable import NumberInputKit

@MainActor
final class NumberInputKeypadAccessibilityRegressionTests: XCTestCase {

    func testDisabledKeyKeepsButtonIdentityAndRejectsAccessibilityPress() {
        let accessibility = NumberInputKeyAccessibility(enabled: false)
        var presses = 0

        XCTAssertTrue(accessibility.traits.contains(.button))
        XCTAssertTrue(accessibility.isDisabled)
        XCTAssertFalse(accessibility.perform { presses += 1 })
        XCTAssertEqual(presses, 0)
    }

    func testEnabledKeyKeepsButtonIdentityAndAcceptsAccessibilityPress() {
        let accessibility = NumberInputKeyAccessibility(enabled: true)
        var presses = 0

        XCTAssertTrue(accessibility.traits.contains(.button))
        XCTAssertFalse(accessibility.isDisabled)
        XCTAssertTrue(accessibility.perform { presses += 1 })
        XCTAssertEqual(presses, 1)
    }
}
#endif

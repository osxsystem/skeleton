import SwiftUI
import XCTest
@testable import NumberInputKit

/// Port of `NumberInputKeyStyleMergeTest.kt` — the two rules that decide what a key looks like.
///
/// *Role fallback* runs once, at resolution: anything the utility key leaves unset comes from the
/// rest key. *State merge* runs at draw time and contributes **colours only** — geometry always
/// stays with the role, because an integer-only field disables its decimal key permanently and a
/// disabled state carrying geometry would strand that one key at the digit size and alignment.
final class NumberInputKeyStyleMergeTests: XCTestCase {

    private let role = NumberInputKeyStyle(
        backgroundColor: .white,
        contentColor: .black,
        shadowColor: .gray,
        textSize: 26,
        fontWeight: .semibold,
        contentAlignment: .bottom,
        contentBottomPadding: 10
    )

    func testRoleFallbackFillsOnlyTheUnsetValues() {
        let base = NumberInputKeyStyle(backgroundColor: .white, contentColor: .black, textSize: 24)
        let utility = NumberInputKeyStyle(backgroundColor: .red)

        let resolved = utility.fallingBack(to: base)

        XCTAssertEqual(resolved.backgroundColor, .red)
        XCTAssertEqual(resolved.contentColor, .black)
        XCTAssertEqual(resolved.textSize, 24)
    }

    func testStateMergeReplacesColours() {
        let pressed = NumberInputKeyStyle(backgroundColor: .yellow, contentColor: .blue)

        let merged = role.merged(withState: pressed)

        XCTAssertEqual(merged.backgroundColor, .yellow)
        XCTAssertEqual(merged.contentColor, .blue)
    }

    func testStateMergeKeepsTheRolesGeometry() {
        let pressed = NumberInputKeyStyle(backgroundColor: .yellow)

        let merged = role.merged(withState: pressed)

        XCTAssertEqual(merged.textSize, 26)
        XCTAssertEqual(merged.fontWeight, .semibold)
        XCTAssertEqual(merged.contentAlignment, .bottom)
        XCTAssertEqual(merged.contentBottomPadding, 10)
    }

    func testAnUnsetStateColourLeavesTheRolesColourAlone() {
        let merged = role.merged(withState: NumberInputKeyStyle())

        XCTAssertEqual(merged.backgroundColor, .white)
        XCTAssertEqual(merged.contentColor, .black)
    }

    /// Border width follows border colour, so a state without a border cannot erase the role's.
    func testBorderWidthTravelsWithBorderColour() {
        var bordered = role
        bordered.borderColor = .green
        bordered.borderWidth = 2

        let withStateBorder = bordered.merged(
            withState: NumberInputKeyStyle(borderColor: .purple, borderWidth: 5)
        )
        XCTAssertEqual(withStateBorder.borderColor, .purple)
        XCTAssertEqual(withStateBorder.borderWidth, 5)

        let withoutStateBorder = bordered.merged(withState: NumberInputKeyStyle(backgroundColor: .yellow))
        XCTAssertEqual(withoutStateBorder.borderColor, .green)
        XCTAssertEqual(withoutStateBorder.borderWidth, 2)
    }

    /// The lip is a resting affordance; a pressed key that still has one does not look pressed.
    func testTheShadowLipBelongsToTheRoleAndIsNeverMergedFromAState() {
        let merged = role.merged(
            withState: NumberInputKeyStyle(backgroundColor: .yellow, shadowColor: .cyan)
        )

        XCTAssertEqual(merged.shadowColor, .gray)
    }

    /// Role fallback carries geometry too, unlike the state merge.
    func testRoleFallbackCarriesGeometryAsWellAsColour() {
        let base = NumberInputKeyStyle(shadowColor: .gray, shadowHeight: 3, textSize: 24, fontWeight: .medium)
        let utility = NumberInputKeyStyle()

        let resolved = utility.fallingBack(to: base)

        XCTAssertEqual(resolved.shadowColor, .gray)
        XCTAssertEqual(resolved.shadowHeight, 3)
        XCTAssertEqual(resolved.textSize, 24)
        XCTAssertEqual(resolved.fontWeight, .medium)
    }
}

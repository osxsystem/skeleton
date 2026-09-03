import SwiftUI
import XCTest
@testable import NumberInputKit

/// Port of `NumberInputStyleResolveTest.kt` — appearance resolution of the keypad and toolbar
/// colours.
///
/// The colours the library draws itself default to `nil` (Compose's `Color.Unspecified`) and
/// `resolveThemedColors` substitutes a light or dark palette for whichever were left unset. What
/// these pin is the substitution *rule*: a colour a consumer actually set has to survive both
/// appearances untouched, or their design system silently loses to the device setting.
final class NumberInputStyleResolveTests: XCTestCase {

    /// A colour no palette uses, so an assertion that finds it can only have got it from the caller.
    private let sentinelOverride = Color(numberInputHex: 0x00FF00)

    // MARK: - unset colours take the palette

    func testUnsetColoursResolveToTheLightPalette() {
        let resolved = resolveThemedColors(NumberInputStyle(), dark: false)

        XCTAssertEqual(resolved.keypad.backgroundColor, Color(numberInputHex: 0xD1D3D9))
        XCTAssertEqual(resolved.keypad.restKey.backgroundColor, Color(numberInputHex: 0xFFFFFF))
        XCTAssertEqual(resolved.keypad.restKey.contentColor, Color(numberInputHex: 0x000000))
        XCTAssertEqual(resolved.toolbar.backgroundColor, Color(numberInputHex: 0xF2F2F7))
        XCTAssertEqual(resolved.toolbar.tint, Color(numberInputHex: 0x007AFF))
    }

    func testUnsetColoursResolveToTheDarkPalette() {
        let resolved = resolveThemedColors(NumberInputStyle(), dark: true)

        XCTAssertEqual(resolved.keypad.backgroundColor, Color(numberInputHex: 0x2C2C2E))
        XCTAssertEqual(resolved.keypad.restKey.backgroundColor, Color(numberInputHex: 0x6B6B6E))
        XCTAssertEqual(resolved.keypad.restKey.contentColor, Color(numberInputHex: 0xFFFFFF))
        XCTAssertEqual(resolved.toolbar.backgroundColor, Color(numberInputHex: 0x1C1C1E))
        XCTAssertEqual(resolved.toolbar.tint, Color(numberInputHex: 0x0A84FF))
    }

    func testTheTwoPalettesDifferOnEveryThemedColour() {
        let light = resolveThemedColors(NumberInputStyle(), dark: false)
        let dark = resolveThemedColors(NumberInputStyle(), dark: true)

        XCTAssertNotEqual(light.keypad.backgroundColor, dark.keypad.backgroundColor)
        XCTAssertNotEqual(light.keypad.restKey.backgroundColor, dark.keypad.restKey.backgroundColor)
        XCTAssertNotEqual(light.keypad.restKey.contentColor, dark.keypad.restKey.contentColor)
        XCTAssertNotEqual(light.toolbar.backgroundColor, dark.toolbar.backgroundColor)
        XCTAssertNotEqual(light.toolbar.tint, dark.toolbar.tint)
    }

    // MARK: - an explicit colour outranks the appearance

    func testAnExplicitColourSurvivesTheLightPalette() {
        assertEveryThemedColourIs(sentinelOverride, resolveThemedColors(styleWithEveryThemedColourSet(), dark: false))
    }

    func testAnExplicitColourSurvivesTheDarkPalette() {
        assertEveryThemedColourIs(sentinelOverride, resolveThemedColors(styleWithEveryThemedColourSet(), dark: true))
    }

    func testAPartialOverrideLeavesTheRestToThePalette() {
        var style = NumberInputStyle()
        style.keypad.restKey = NumberInputKeyStyle(contentColor: sentinelOverride)

        let resolved = resolveThemedColors(style, dark: true)

        XCTAssertEqual(resolved.keypad.restKey.contentColor, sentinelOverride)
        XCTAssertEqual(resolved.keypad.backgroundColor, Color(numberInputHex: 0x2C2C2E))
        XCTAssertEqual(resolved.keypad.restKey.backgroundColor, Color(numberInputHex: 0x6B6B6E))
    }

    /// `Color.clear` is a *set* colour, and a consumer asking for a transparent keypad means it.
    /// Distinguishing "unset" from "set to something invisible" is why the default is `nil`.
    func testAnExplicitTransparentIsAChoiceNotAnAbsence() {
        var style = NumberInputStyle()
        style.keypad.backgroundColor = .clear

        let resolved = resolveThemedColors(style, dark: true)

        XCTAssertEqual(resolved.keypad.backgroundColor, .clear)
    }

    // MARK: - the role fallback and the deliberately-unset disabled key

    func testAnUnsetUtilityKeyIsIdenticalToTheRestKey() {
        for dark in [false, true] {
            let resolved = resolveThemedColors(NumberInputStyle(), dark: dark)

            XCTAssertEqual(resolved.keypad.restKey, resolved.keypad.utilityKey)
        }
    }

    /// Unset means "multiply the content colour by `disabledAlpha`", so giving the disabled key a
    /// palette entry here would change how every existing consumer's keypad renders on upgrade.
    func testDisabledKeyColoursAreNotSubstitutedByEitherPalette() {
        for dark in [false, true] {
            let resolved = resolveThemedColors(NumberInputStyle(), dark: dark)

            XCTAssertNil(resolved.keypad.disabledKey.backgroundColor)
            XCTAssertNil(resolved.keypad.disabledKey.contentColor)
        }
    }

    /// The pressed state is the one colour that *does* get a palette entry: a replacement keyboard
    /// that does not respond to touch reads as broken next to the one it stands in for.
    func testThePressedKeyTakesAThemedFillInBothAppearances() {
        let light = resolveThemedColors(NumberInputStyle(), dark: false)
        let dark = resolveThemedColors(NumberInputStyle(), dark: true)

        XCTAssertEqual(light.keypad.pressedKey.backgroundColor, Color(numberInputHex: 0xD8D8DD))
        XCTAssertEqual(dark.keypad.pressedKey.backgroundColor, Color(numberInputHex: 0x8A8A8E))
    }

    // MARK: - everything else is passed through

    func testTheFieldsOwnColoursAreLeftAlone() {
        let style = NumberInputStyle()
        let resolved = resolveThemedColors(style, dark: true)

        XCTAssertEqual(resolved.textColor, style.textColor)
        XCTAssertEqual(resolved.cursorColor, style.cursorColor)
        XCTAssertEqual(resolved.placeholderColor, style.placeholderColor)
        XCTAssertEqual(resolved.borderColor, style.borderColor)
        XCTAssertEqual(resolved.backgroundColor, style.backgroundColor)
    }

    func testNonColourPropertiesAreLeftAlone() {
        var style = NumberInputStyle()
        style.toolbar.clearLabel = "Xoá"
        style.toolbar.doneLabel = "Xong"
        style.keypad.backspaceContentDescription = "Xoá ký tự"

        let resolved = resolveThemedColors(style, dark: true)

        XCTAssertEqual(resolved.toolbar.clearLabel, "Xoá")
        XCTAssertEqual(resolved.toolbar.doneLabel, "Xong")
        XCTAssertEqual(resolved.keypad.backspaceContentDescription, "Xoá ký tự")
        XCTAssertEqual(resolved.keypad.keyHeight, style.keypad.keyHeight)
        XCTAssertEqual(resolved.keypad.keyCornerRadius, style.keypad.keyCornerRadius)
        XCTAssertEqual(resolved.disabledAlpha, style.disabledAlpha)
    }

    /// Resolving twice must be a no-op rather than a re-substitution.
    func testResolvingAnAlreadyResolvedStyleChangesNothing() {
        let once = resolveThemedColors(NumberInputStyle(), dark: true)
        let twice = resolveThemedColors(once, dark: true)

        XCTAssertEqual(once, twice)
    }

    /// A style resolved for one appearance is *set*, so re-resolving keeps the first palette. Which
    /// is why resolution happens once, above the draw calls.
    func testAResolvedStyleNoLongerFollowsTheAppearance() {
        let light = resolveThemedColors(NumberInputStyle(), dark: false)
        let relit = resolveThemedColors(light, dark: true)

        XCTAssertEqual(light, relit)
    }

    // MARK: - helpers

    private func styleWithEveryThemedColourSet() -> NumberInputStyle {
        var style = NumberInputStyle()
        style.keypad.backgroundColor = sentinelOverride
        style.keypad.restKey = NumberInputKeyStyle(
            backgroundColor: sentinelOverride,
            contentColor: sentinelOverride
        )
        style.toolbar.backgroundColor = sentinelOverride
        style.toolbar.tint = sentinelOverride
        return style
    }

    private func assertEveryThemedColourIs(_ expected: Color, _ resolved: NumberInputStyle) {
        XCTAssertEqual(resolved.keypad.backgroundColor, expected)
        XCTAssertEqual(resolved.keypad.restKey.backgroundColor, expected)
        XCTAssertEqual(resolved.keypad.restKey.contentColor, expected)
        XCTAssertEqual(resolved.toolbar.backgroundColor, expected)
        XCTAssertEqual(resolved.toolbar.tint, expected)
    }
}

import SwiftUI

/// Substitutes a light or dark default for whichever of the colours this library draws itself — the
/// keypad's and its toolbar row's — were left `nil`, leaving every other property untouched,
/// including an explicitly-set one of those.
///
/// A plain function rather than living only behind the appearance lookup so the substitution rule
/// can be tested directly, with no view involved.
///
/// Optionality is what makes an explicit `Color.clear` a real choice rather than another "unset" —
/// only `nil` falls back to the palette.
///
/// Two things here are not substitution and are easy to mistake for it. The **role fallback** fills
/// the utility key from the resolved rest key, so an unstyled utility key is indistinguishable from
/// a digit key. And the **disabled key is deliberately left unset**: unset means "multiply the
/// content colour by ``NumberInputStyle/disabledAlpha``", so giving it a palette entry here would
/// change how every existing consumer's keypad looks on upgrade.
public func resolveThemedColors(_ style: NumberInputStyle, dark: Bool) -> NumberInputStyle {
    var resolved = style

    let restKey = style.keypad.restKey.fallingBack(
        to: NumberInputKeyStyle(
            backgroundColor: dark ? Color(numberInputHex: 0x6B6B6E) : Color(numberInputHex: 0xFFFFFF),
            contentColor: dark ? Color(numberInputHex: 0xFFFFFF) : Color(numberInputHex: 0x000000),
            textSize: 22
        )
    )

    resolved.toolbar.backgroundColor = style.toolbar.backgroundColor
        ?? (dark ? Color(numberInputHex: 0x1C1C1E) : Color(numberInputHex: 0xF2F2F7))
    resolved.toolbar.tint = style.toolbar.tint
        ?? (dark ? Color(numberInputHex: 0x0A84FF) : Color(numberInputHex: 0x007AFF))

    resolved.keypad.backgroundColor = style.keypad.backgroundColor
        ?? (dark ? Color(numberInputHex: 0x2C2C2E) : Color(numberInputHex: 0xD1D3D9))
    resolved.keypad.restKey = restKey
    resolved.keypad.utilityKey = style.keypad.utilityKey.fallingBack(to: restKey)
    // The one token with a themed default rather than a "render as before" fallback: a replacement
    // keyboard that does not respond to touch reads as broken next to the system one it stands in
    // for.
    resolved.keypad.pressedKey.backgroundColor = style.keypad.pressedKey.backgroundColor
        ?? (dark ? Color(numberInputHex: 0x8A8A8E) : Color(numberInputHex: 0xD8D8DD))
    resolved.keypad.disabledKey = style.keypad.disabledKey

    return resolved
}

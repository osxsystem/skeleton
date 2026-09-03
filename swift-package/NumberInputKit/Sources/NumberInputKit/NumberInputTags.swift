import Foundation

/// The `accessibilityIdentifier`s this library puts on the elements it draws.
///
/// The values match `NumberInputTags` in the Compose `number-input` library exactly, so UI tests
/// written against either implementation address the same elements.
///
/// They identify the **component, not the instance**, so a screen with several fields addresses
/// them by index. In an iOS accessibility dump they surface as `AXUniqueId`, not `AXIdentifier`.
public enum NumberInputTags {
    public static let field = "numberInput.field"

    public static let toolbarClear = "numberInput.toolbar.clear"
    public static let toolbarSign = "numberInput.toolbar.toggleSign"
    public static let toolbarDone = "numberInput.toolbar.done"
    public static let toolbarHint = "numberInput.toolbar.hint"
    public static let toolbarLogo = "numberInput.toolbar.logo"
    public static let toolbarPrevious = "numberInput.toolbar.previous"
    public static let toolbarNext = "numberInput.toolbar.next"

    public static let keypad = "numberInput.keypad"
    public static let keypadDecimal = "numberInput.keypad.decimal"
    public static let keypadBackspace = "numberInput.keypad.backspace"

    /// Per-digit identifier, so a test can address one key rather than searching by label.
    public static func keypadDigit(_ digit: Int) -> String { "numberInput.keypad.\(digit)" }
}

import SwiftUI

/// How one key of the built-in keypad is drawn.
///
/// Four of these make up a keypad — ``NumberInputKeypadStyle/restKey``, `utilityKey`, `pressedKey`
/// and `disabledKey` — which is one per swatch in a design spec rather than a role-by-state matrix,
/// because pressed and disabled look the same whichever key is in them.
///
/// Two rules decide the value actually drawn, and they do different jobs:
///
/// - **Role fallback** (``fallingBack(to:)``) runs once, during theme resolution: `utilityKey` takes
///   anything it left unset from `restKey`. Restyling only the decimal key's fill should not require
///   restating its glyph size.
/// - **State merge** (``merged(withState:)``) runs at draw time and contributes **colours only**.
///   Geometry always stays with the role. An integer-only field disables its decimal key for the
///   field's whole life, so a disabled state that carried geometry would strand that one key at the
///   digit size and alignment while every neighbour kept the utility treatment.
///
/// ``shadowColor`` is deliberately outside the state merge: the lip is a resting affordance, and a
/// pressed key that still has one does not read as pressed.
public struct NumberInputKeyStyle: Equatable {
    public var backgroundColor: Color?
    public var contentColor: Color?
    public var borderColor: Color?
    public var borderWidth: CGFloat
    /// A hard lip under the key, not an elevation shadow. `nil` draws no lip at all.
    public var shadowColor: Color?
    public var shadowHeight: CGFloat
    /// Point size at the Large content-size category. The built-in keypad scales it relative to
    /// Title 2 through Accessibility 2, then caps it to protect the bounded keyboard geometry.
    public var textSize: CGFloat?
    public var fontWeight: Font.Weight?
    public var contentAlignment: Alignment
    /// Only meaningful with a bottom-ish ``contentAlignment``; the OFNumpad decimal key sits 10pt up.
    public var contentBottomPadding: CGFloat

    public init(
        backgroundColor: Color? = nil,
        contentColor: Color? = nil,
        borderColor: Color? = nil,
        borderWidth: CGFloat = 0,
        shadowColor: Color? = nil,
        shadowHeight: CGFloat = 1,
        textSize: CGFloat? = nil,
        fontWeight: Font.Weight? = nil,
        contentAlignment: Alignment = .center,
        contentBottomPadding: CGFloat = 0
    ) {
        self.backgroundColor = backgroundColor
        self.contentColor = contentColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.shadowColor = shadowColor
        self.shadowHeight = shadowHeight
        self.textSize = textSize
        self.fontWeight = fontWeight
        self.contentAlignment = contentAlignment
        self.contentBottomPadding = contentBottomPadding
    }

    /// Role fallback: anything unset here comes from `base`. Resolution-time, colours *and* geometry.
    public func fallingBack(to base: NumberInputKeyStyle) -> NumberInputKeyStyle {
        var merged = self
        merged.backgroundColor = backgroundColor ?? base.backgroundColor
        merged.contentColor = contentColor ?? base.contentColor
        merged.borderColor = borderColor ?? base.borderColor
        merged.borderWidth = borderColor != nil ? borderWidth : base.borderWidth
        merged.shadowColor = shadowColor ?? base.shadowColor
        merged.shadowHeight = shadowColor != nil ? shadowHeight : base.shadowHeight
        merged.textSize = textSize ?? base.textSize
        merged.fontWeight = fontWeight ?? base.fontWeight
        return merged
    }

    /// State merge: `state`'s colours win, this role's geometry is kept. Border width travels with
    /// border colour so a state that specifies no border cannot erase the role's.
    public func merged(withState state: NumberInputKeyStyle) -> NumberInputKeyStyle {
        var merged = self
        merged.backgroundColor = state.backgroundColor ?? backgroundColor
        merged.contentColor = state.contentColor ?? contentColor
        merged.borderColor = state.borderColor ?? borderColor
        merged.borderWidth = state.borderColor != nil ? state.borderWidth : borderWidth
        return merged
    }
}

/// Styling for the built-in keypad. Only read when ``NumberInputConfig/useBuiltInKeypad`` is on.
///
/// Separate from the field's own colours because the keypad stands in for the system keyboard: it
/// should look like a keyboard sitting under the content, not a larger version of the field.
///
/// ``backgroundColor`` and the four key styles' colours default to `nil` and are resolved against
/// the device appearance — see ``resolveThemedColors(_:dark:)``.
public struct NumberInputKeypadStyle: Equatable {
    public var backgroundColor: Color?
    public var keyHeight: CGFloat
    public var keyCornerRadius: CGFloat
    /// Horizontal padding around the key grid.
    public var contentPadding: CGFloat
    /// Gap between keys, horizontally and vertically.
    public var keySpacing: CGFloat
    /// PostScript name for every key glyph; `nil` keeps the system font. Custom faces follow the
    /// same Dynamic Type scaling policy as the system face.
    public var fontName: String?
    /// Fixed-width figures. Off by default because it changes the metrics of every existing
    /// consumer's keypad; a design that shows a grid of digits almost always wants it on.
    public var tabularFigures: Bool

    /// Drawn instead of ``backspaceLabel`` when set, tinted with the key's resolved content colour.
    ///
    /// Worth setting alongside ``fontName``: `⌫` is U+232B, which brand fonts frequently omit, and a
    /// missing glyph renders as a blank box rather than failing loudly.
    public var backspaceSystemImage: String?
    public var backspaceIconWidth: CGFloat
    public var backspaceIconHeight: CGFloat
    public var backspaceLabel: String
    /// Localise: a symbol has no spoken name of its own.
    public var backspaceContentDescription: String
    /// Localise: "." and "," sound identical read aloud even when a reader announces them at all.
    public var decimalContentDescription: String

    /// Digit keys, and the base every other key style falls back to.
    public var restKey: NumberInputKeyStyle
    /// Decimal and backspace keys. Anything left unset here comes from ``restKey``.
    public var utilityKey: NumberInputKeyStyle
    /// Colours applied while a key is held. Geometry is ignored.
    public var pressedKey: NumberInputKeyStyle
    /// Colours applied while a key is refused. Left unset, the key falls back to multiplying its
    /// content colour by ``NumberInputStyle/disabledAlpha``.
    public var disabledKey: NumberInputKeyStyle

    public init(
        backgroundColor: Color? = nil,
        keyHeight: CGFloat = 48,
        keyCornerRadius: CGFloat = 5,
        contentPadding: CGFloat = 3,
        keySpacing: CGFloat = 6,
        fontName: String? = nil,
        tabularFigures: Bool = false,
        backspaceSystemImage: String? = nil,
        backspaceIconWidth: CGFloat = 26,
        backspaceIconHeight: CGFloat = 20,
        backspaceLabel: String = "⌫",
        backspaceContentDescription: String = "Delete",
        decimalContentDescription: String = "Decimal separator",
        restKey: NumberInputKeyStyle = NumberInputKeyStyle(),
        utilityKey: NumberInputKeyStyle = NumberInputKeyStyle(),
        pressedKey: NumberInputKeyStyle = NumberInputKeyStyle(),
        disabledKey: NumberInputKeyStyle = NumberInputKeyStyle()
    ) {
        self.backgroundColor = backgroundColor
        self.keyHeight = keyHeight
        self.keyCornerRadius = keyCornerRadius
        self.contentPadding = contentPadding
        self.keySpacing = keySpacing
        self.fontName = fontName
        self.tabularFigures = tabularFigures
        self.backspaceSystemImage = backspaceSystemImage
        self.backspaceIconWidth = backspaceIconWidth
        self.backspaceIconHeight = backspaceIconHeight
        self.backspaceLabel = backspaceLabel
        self.backspaceContentDescription = backspaceContentDescription
        self.decimalContentDescription = decimalContentDescription
        self.restKey = restKey
        self.utilityKey = utilityKey
        self.pressedKey = pressedKey
        self.disabledKey = disabledKey
    }
}

import SwiftUI

/// Horizontal alignment of the field's text. Mirrors Compose's `TextAlign` rather than exposing
/// `NSTextAlignment`, so the style layer carries no UIKit type and stays testable off-device.
public enum NumberInputTextAlign: Equatable {
    case start
    case center
    case end
    case left
    case right
}

/// Space between the field's edge and its text.
public struct NumberInputPadding: Equatable {
    public var leading: CGFloat
    public var top: CGFloat
    public var trailing: CGFloat
    public var bottom: CGFloat

    public init(leading: CGFloat = 0, top: CGFloat = 0, trailing: CGFloat = 0, bottom: CGFloat = 0) {
        self.leading = leading
        self.top = top
        self.trailing = trailing
        self.bottom = bottom
    }

    public init(horizontal: CGFloat, vertical: CGFloat) {
        self.init(leading: horizontal, top: vertical, trailing: horizontal, bottom: vertical)
    }

    public static let zero = NumberInputPadding()
}

/// Styling for a number input.
///
/// The top-level properties are the *field's*. The colours this library draws **itself** — inside
/// ``keypad`` and ``toolbar`` — default to `nil` and are resolved against the device's light/dark
/// appearance, since there is no design system a consumer can bring for a stand-in system keyboard.
/// Set any of them explicitly to opt out and pin one colour in both appearances. See
/// ``resolveThemedColors(_:dark:)``.
///
/// Field defaults are neutral rather than themed — this library has no theme to read. Pass your own
/// design system's values.
public struct NumberInputStyle: Equatable {

    public var textColor: Color
    public var textSize: CGFloat
    public var textWeight: Font.Weight
    public var textAlign: NumberInputTextAlign
    /// Space between the field's edge and its text.
    public var contentPadding: NumberInputPadding
    /// Typeface for the field, as a **PostScript name** (`"BeVietnamPro-SemiBold"`), not a family
    /// name or a file name. The font has to be registered with the consuming app — added to the
    /// Xcode target and listed under `UIAppFonts`.
    ///
    /// A name UIKit cannot resolve falls back to the system font rather than failing, which is the
    /// same outcome as forgetting to register it: silent. The name selects the *face*, so
    /// ``textWeight`` no longer picks one when this is set; it still applies on the fallback path.
    public var fontName: String?
    public var placeholderColor: Color
    public var backgroundColor: Color
    public var borderColor: Color
    public var borderWidth: CGFloat
    public var cornerRadius: CGFloat
    public var cursorColor: Color
    /// Multiplied into a disabled element's content colour. Still the fallback for a disabled key
    /// when ``NumberInputKeypadStyle/disabledKey`` leaves its colours unset.
    public var disabledAlpha: Double
    public var toolbar: NumberInputToolbarStyle
    public var keypad: NumberInputKeypadStyle

    public init(
        textColor: Color = .black,
        textSize: CGFloat = 16,
        textWeight: Font.Weight = .regular,
        textAlign: NumberInputTextAlign = .start,
        contentPadding: NumberInputPadding = NumberInputPadding(horizontal: 12, vertical: 10),
        fontName: String? = nil,
        placeholderColor: Color = Color(numberInputHex: 0x9E9E9E),
        backgroundColor: Color = .clear,
        borderColor: Color = Color(numberInputHex: 0x9E9E9E),
        borderWidth: CGFloat = 1,
        cornerRadius: CGFloat = 4,
        cursorColor: Color = .black,
        disabledAlpha: Double = 0.38,
        toolbar: NumberInputToolbarStyle = NumberInputToolbarStyle(),
        keypad: NumberInputKeypadStyle = NumberInputKeypadStyle()
    ) {
        self.textColor = textColor
        self.textSize = textSize
        self.textWeight = textWeight
        self.textAlign = textAlign
        self.contentPadding = contentPadding
        self.fontName = fontName
        self.placeholderColor = placeholderColor
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.cursorColor = cursorColor
        self.disabledAlpha = disabledAlpha
        self.toolbar = toolbar
        self.keypad = keypad
    }
}

// MARK: - Colour helper

extension Color {
    /// A 24-bit RGB literal, opaque. Used for every palette entry so two colours built from the same
    /// hex compare equal — which is what makes ``resolveThemedColors(_:dark:)`` assertable.
    public init(numberInputHex hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

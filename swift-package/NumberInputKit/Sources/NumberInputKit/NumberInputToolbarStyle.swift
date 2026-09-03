import SwiftUI

/// Styling for the ± / Clear / Done row.
///
/// Drawn as the built-in keypad's own top row. The system-keyboard path builds a native `UIToolbar`
/// instead, which reads ``backgroundColor``, ``tint`` and the three labels and nothing else: that
/// accessory is the system's, and it should look like one. The one structural rule it *does* share
/// is ``NumberInputToolbarRules/signVisible(allowNegative:)``, since dropping a `UIBarButtonItem`
/// needs no custom view.
///
/// ``backgroundColor`` and ``tint`` default to `nil` and follow the device appearance; see
/// ``resolveThemedColors(_:dark:)``. Every chrome token below defaults to "no chrome".
public struct NumberInputToolbarStyle: Equatable {

    public var backgroundColor: Color?
    public var tint: Color?

    /// Localise these — the defaults are English and will otherwise ship to every user.
    public var clearLabel: String
    public var signLabel: String
    public var doneLabel: String

    /// `nil` wraps the tallest item.
    public var height: CGFloat?
    public var contentPadding: CGFloat
    public var itemSpacing: CGFloat
    /// Point size at the Large content-size category. Built-in-keypad labels scale relative to
    /// Body through Accessibility 2, then cap to protect the bounded keyboard geometry.
    public var labelTextSize: CGFloat
    public var labelFontWeight: Font.Weight?
    /// PostScript name for the row's labels; `nil` keeps the system font. Custom faces follow the
    /// same Dynamic Type scaling policy as the system face.
    public var fontName: String?

    /// Optional caption centred in the bar — a unit or a field name, e.g. "Chargeable weight · KG".
    ///
    /// Per-field, so it lives on the style: the row is drawn from whichever field holds focus, and
    /// the caption belongs to that field.
    public var hint: String?
    /// Point size at Large. The hint scales relative to Caption 1 through Accessibility 2.
    public var hintTextSize: CGFloat
    public var hintFontWeight: Font.Weight?
    /// `nil` falls back to ``tint``.
    public var hintColor: Color?

    public var bottomBorderColor: Color?
    public var bottomBorderWidth: CGFloat

    /// Chrome for Clear and ±.
    public var action: NumberInputToolbarActionStyle
    /// Chrome for Done.
    public var done: NumberInputToolbarActionStyle
    /// Chrome for the prev/next buttons, when the field supplies their callbacks.
    public var navigation: NumberInputToolbarActionStyle
    public var previousLabel: String
    public var nextLabel: String
    /// Localise: a chevron has no useful spoken form of its own.
    public var previousContentDescription: String
    public var nextContentDescription: String

    public init(
        backgroundColor: Color? = nil,
        tint: Color? = nil,
        clearLabel: String = "Clear",
        signLabel: String = "±",
        doneLabel: String = "Done",
        height: CGFloat? = nil,
        contentPadding: CGFloat = 4,
        itemSpacing: CGFloat = 4,
        labelTextSize: CGFloat = 16,
        labelFontWeight: Font.Weight? = nil,
        fontName: String? = nil,
        hint: String? = nil,
        hintTextSize: CGFloat = 12,
        hintFontWeight: Font.Weight? = nil,
        hintColor: Color? = nil,
        bottomBorderColor: Color? = nil,
        bottomBorderWidth: CGFloat = 1,
        action: NumberInputToolbarActionStyle = NumberInputToolbarActionStyle(),
        done: NumberInputToolbarActionStyle = NumberInputToolbarActionStyle(),
        navigation: NumberInputToolbarActionStyle = NumberInputToolbarActionStyle(),
        previousLabel: String = "‹",
        nextLabel: String = "›",
        previousContentDescription: String = "Previous field",
        nextContentDescription: String = "Next field"
    ) {
        self.backgroundColor = backgroundColor
        self.tint = tint
        self.clearLabel = clearLabel
        self.signLabel = signLabel
        self.doneLabel = doneLabel
        self.height = height
        self.contentPadding = contentPadding
        self.itemSpacing = itemSpacing
        self.labelTextSize = labelTextSize
        self.labelFontWeight = labelFontWeight
        self.fontName = fontName
        self.hint = hint
        self.hintTextSize = hintTextSize
        self.hintFontWeight = hintFontWeight
        self.hintColor = hintColor
        self.bottomBorderColor = bottomBorderColor
        self.bottomBorderWidth = bottomBorderWidth
        self.action = action
        self.done = done
        self.navigation = navigation
        self.previousLabel = previousLabel
        self.nextLabel = nextLabel
        self.previousContentDescription = previousContentDescription
        self.nextContentDescription = nextContentDescription
    }
}

/// Chrome for one toolbar button.
///
/// Every default is "no chrome" — no fill, no border, no radius — so an unstyled bar draws bare
/// tinted text. A design giving Clear and ± a bordered pill and Done a filled block sets two of
/// these.
public struct NumberInputToolbarActionStyle: Equatable {
    public var backgroundColor: Color?
    /// `nil` falls back to ``NumberInputToolbarStyle/tint``.
    public var contentColor: Color?
    public var borderColor: Color?
    public var borderWidth: CGFloat
    public var cornerRadius: CGFloat
    /// `nil` wraps the label.
    public var height: CGFloat?
    public var horizontalPadding: CGFloat
    public var verticalPadding: CGFloat

    public init(
        backgroundColor: Color? = nil,
        contentColor: Color? = nil,
        borderColor: Color? = nil,
        borderWidth: CGFloat = 0,
        cornerRadius: CGFloat = 0,
        height: CGFloat? = nil,
        horizontalPadding: CGFloat = 12,
        verticalPadding: CGFloat = 10
    ) {
        self.backgroundColor = backgroundColor
        self.contentColor = contentColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.height = height
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }
}

import Foundation

/// Localizable VoiceOver copy for ``NumberInputField``.
///
/// Accessibility presentation stays separate from ``NumberInputConfig`` so the behavioral config
/// remains field-for-field compatible with the Compose `number-input` library.
public struct NumberInputAccessibilityStrings: Equatable {
    /// Field label. When `nil`, the field uses its placeholder or the English default.
    public let label: String?

    /// Guidance announced when VoiceOver focuses the field.
    public let hint: String

    /// Value announced when the field has no entered value.
    public let emptyValue: String

    public init(
        label: String? = nil,
        hint: String = "Double tap to enter a number",
        emptyValue: String = "Empty"
    ) {
        self.label = label
        self.hint = hint
        self.emptyValue = emptyValue
    }

    func resolvedLabel(placeholder: String) -> String {
        label ?? (placeholder.isEmpty ? "Number input" : placeholder)
    }
}

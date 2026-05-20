import Foundation

/// Immutable configuration for a `NumberInputViewModel` instance.
public struct NumberInputConfig {
    /// Fixed digits after the decimal point. Must be in 0...9.
    public let significantDigits: Int
    /// BCP-47 locale tag (e.g. "en-US", "vi-VN").
    public let locale: String
    /// When `false`, negative initial values are clamped to 0 and negative typed values are rejected.
    public let allowNegative: Bool
    /// Empty-state hint shown by the platform field.
    public let placeholder: String

    public init(
        significantDigits: Int = 2,
        locale: String = "en-US",
        allowNegative: Bool = true,
        placeholder: String = ""
    ) {
        precondition(significantDigits >= 0 && significantDigits <= 9,
            "significantDigits must be in 0...9, got \(significantDigits)")
        self.significantDigits = significantDigits
        self.locale = locale
        self.allowNegative = allowNegative
        self.placeholder = placeholder
    }
}

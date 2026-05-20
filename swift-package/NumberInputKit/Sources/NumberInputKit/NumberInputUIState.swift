import Foundation

/// Mirrors the Kotlin sealed interface `NumberInputUiState`.
/// Note: Swift naming convention uses `UI` uppercase — this type is `NumberInputUIState`
/// (not `UiState`) per Apple SDK conventions.
public enum NumberInputUIState: Equatable {
    case idle(Payload)
    case editing(Payload)
    case committed(Payload)

    public struct Payload: Equatable {
        public let rawText: String
        public let formattedText: String
        public let value: Double?
        public let significantDigits: Int
        public let locale: String
        public let allowNegative: Bool

        public init(
            rawText: String,
            formattedText: String,
            value: Double?,
            significantDigits: Int,
            locale: String,
            allowNegative: Bool
        ) {
            self.rawText = rawText
            self.formattedText = formattedText
            self.value = value
            self.significantDigits = significantDigits
            self.locale = locale
            self.allowNegative = allowNegative
        }
    }

    public var payload: Payload {
        switch self {
        case .idle(let p), .editing(let p), .committed(let p): return p
        }
    }
}

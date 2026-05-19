import SwiftUI

/// Xcode previews for the NumberInput Swift Package.
/// Visible to external SPM consumers browsing the package.
#Preview("en-US (default)") {
    VStack(spacing: 24) {
        PreviewField(locale: Locale(identifier: "en-US"), sigDigits: 2, label: "en-US · 2 decimal places")
        PreviewField(locale: Locale(identifier: "vi-VN"), sigDigits: 2, label: "vi-VN · 2 decimal places")
        PreviewField(locale: Locale(identifier: "de-DE"), sigDigits: 3, label: "de-DE · 3 decimal places")
        PreviewField(locale: Locale(identifier: "en-US"), sigDigits: 2, label: "Unsigned", allowNegative: false)
    }
    .padding()
}

private struct PreviewField: View {
    let locale: Locale
    let sigDigits: Int
    let label: String
    var allowNegative: Bool = true
    @State private var value: Double? = 1234.5

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            NumberInputField(
                value: $value,
                significantDigits: sigDigits,
                locale: locale,
                allowNegative: allowNegative,
                placeholder: "Enter amount"
            )
        }
    }
}

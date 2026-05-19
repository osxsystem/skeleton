import SwiftUI
import NumberInput

struct NumberInputShowcaseView: View {
    @State private var enUsValue: Double? = 1234.5
    @State private var viVnValue: Double? = 1234.5
    @State private var deDeValue: Double? = 1234.5
    @State private var unsignedValue: Double? = 42.0
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                showcaseRow(
                    label: "Default (locale = en-US, sigDigits = 2)",
                    field: NumberInputField(
                        value: $enUsValue,
                        significantDigits: 2,
                        locale: Locale(identifier: "en-US"),
                        allowNegative: true,
                        placeholder: "Enter amount"
                    )
                )
                showcaseRow(
                    label: "Vietnamese locale (vi-VN, sigDigits = 2)",
                    field: NumberInputField(
                        value: $viVnValue,
                        significantDigits: 2,
                        locale: Locale(identifier: "vi-VN"),
                        allowNegative: true,
                        placeholder: "Nhập số tiền"
                    )
                )
                showcaseRow(
                    label: "German locale (de-DE, sigDigits = 3)",
                    field: NumberInputField(
                        value: $deDeValue,
                        significantDigits: 3,
                        locale: Locale(identifier: "de-DE"),
                        allowNegative: true,
                        placeholder: "Betrag eingeben"
                    )
                )
                showcaseRow(
                    label: "Unsigned (allowNegative = false)",
                    field: NumberInputField(
                        value: $unsignedValue,
                        significantDigits: 2,
                        locale: Locale(identifier: "en-US"),
                        allowNegative: false,
                        placeholder: "Positive only"
                    )
                )

                Button("Reset all") {
                    enUsValue = 1234.5
                    viVnValue = 1234.5
                    deDeValue = 1234.5
                    unsignedValue = 42.0
                }
                .padding(.top, theme.spacing.sm)
            }
            .padding(theme.spacing.md)
        }
        .navigationTitle("Number Input Showcase")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func showcaseRow(label: String, field: some View) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(label)
                .font(theme.typography.labelMedium)
                .foregroundStyle(.secondary)
            field
        }
    }
}

#Preview {
    NavigationStack {
        NumberInputShowcaseView()
    }
}

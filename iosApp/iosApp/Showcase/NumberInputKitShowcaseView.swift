import SwiftUI
import NumberInputKit

struct NumberInputKitShowcaseView: View {
    @State private var enUsValue: Double? = 1234.5
    @State private var viVnValue: Double? = 1234.5
    @State private var deDeValue: Double? = 1234.5
    @State private var unsignedValue: Double? = 42.0
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                Text("Pure-Swift NumberInputKit — no Kotlin/Native dependency")
                    .font(theme.typography.labelSmall)
                    .foregroundStyle(.secondary)

                row(label: "en-US, sig=2, value = \(format(enUsValue))",
                    field: NumberInputField(
                        value: $enUsValue,
                        significantDigits: 2,
                        locale: Locale(identifier: "en-US"),
                        allowNegative: true,
                        placeholder: "Enter amount"
                    ))
                row(label: "vi-VN, sig=2, value = \(format(viVnValue))",
                    field: NumberInputField(
                        value: $viVnValue,
                        significantDigits: 2,
                        locale: Locale(identifier: "vi-VN"),
                        allowNegative: true,
                        placeholder: "Nhập số tiền"
                    ))
                row(label: "de-DE, sig=3, value = \(format(deDeValue))",
                    field: NumberInputField(
                        value: $deDeValue,
                        significantDigits: 3,
                        locale: Locale(identifier: "de-DE"),
                        allowNegative: true,
                        placeholder: "Betrag eingeben"
                    ))
                row(label: "en-US, sig=2, unsigned, value = \(format(unsignedValue))",
                    field: NumberInputField(
                        value: $unsignedValue,
                        significantDigits: 2,
                        locale: Locale(identifier: "en-US"),
                        allowNegative: false,
                        placeholder: "Positive only"
                    ))

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
        .navigationTitle("NumberInputKit Showcase")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func row(label: String, field: some View) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(label)
                .font(theme.typography.labelMedium)
                .foregroundStyle(.secondary)
            field
        }
    }

    private func format(_ v: Double?) -> String {
        v.map { String($0) } ?? "nil"
    }
}

#Preview {
    NavigationStack {
        NumberInputKitShowcaseView()
    }
}

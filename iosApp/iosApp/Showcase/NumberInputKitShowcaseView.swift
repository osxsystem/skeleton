import SwiftUI
import NumberInputKit

struct NumberInputKitShowcaseView: View {
    @State private var usdValue: Double?
    @State private var enUsValue: Double? = 1234.5
    @State private var viVnValue: Double? = 1234.5
    @State private var deDeValue: Double? = 1234.5
    @State private var unsignedValue: Double? = 42.0
    @State private var logText = ""
    @State private var showLog = false
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                Text("Pure-Swift NumberInputKit — no Kotlin/Native dependency")
                    .font(theme.typography.labelSmall)
                    .foregroundStyle(.secondary)

                row(label: "USD (non-VND), en-US, sig=2, value = \(format(usdValue))",
                    field: NumberInputField(
                        value: $usdValue,
                        config: NumberInputConfig(
                            significantDigits: 2,
                            locale: "en-US",
                            allowNegative: true,
                            placeholder: "Enter USD amount",
                            useBuiltInKeypad: true
                        )
                    ))
                row(label: "en-US, sig=2, value = \(format(enUsValue))",
                    field: NumberInputField(
                        value: $enUsValue,
                        config: NumberInputConfig(
                            significantDigits: 2,
                            locale: "en-US",
                            allowNegative: true,
                            placeholder: "Enter amount"
                        )
                    ))
                row(label: "vi-VN, sig=2, value = \(format(viVnValue))",
                    field: NumberInputField(
                        value: $viVnValue,
                        config: NumberInputConfig(
                            significantDigits: 2,
                            locale: "vi-VN",
                            allowNegative: true,
                            placeholder: "Nhập số tiền"
                        )
                    ))
                row(label: "de-DE, sig=3, value = \(format(deDeValue))",
                    field: NumberInputField(
                        value: $deDeValue,
                        config: NumberInputConfig(
                            significantDigits: 3,
                            locale: "de-DE",
                            allowNegative: true,
                            placeholder: "Betrag eingeben"
                        )
                    ))
                row(label: "en-US, sig=2, unsigned, value = \(format(unsignedValue))",
                    field: NumberInputField(
                        value: $unsignedValue,
                        config: NumberInputConfig(
                            significantDigits: 2,
                            locale: "en-US",
                            allowNegative: false,
                            placeholder: "Positive only"
                        )
                    ))

                HStack(spacing: theme.spacing.lg) {
                    Button("Reset all") {
                        usdValue = nil
                        enUsValue = 1234.5
                        viVnValue = 1234.5
                        deDeValue = 1234.5
                        unsignedValue = 42.0
                    }
                    Button("Log") {
                        logText = buildLog()
                        showLog = true
                    }
                }
                .padding(.top, theme.spacing.sm)
            }
            .padding(theme.spacing.md)
        }
        .navigationTitle("NumberInputKit Showcase")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Input values", isPresented: $showLog) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(logText)
        }
    }

    private func buildLog() -> String {
        [
            describe("USD", usdValue),
            describe("en-US", enUsValue),
            describe("vi-VN", viVnValue),
            describe("de-DE", deDeValue),
            describe("en-US unsigned", unsignedValue),
        ].joined(separator: "\n")
    }

    private func describe(_ label: String, _ v: Double?) -> String {
        if let v {
            return "\(label): \(v) (\(type(of: v)))"
        } else {
            return "\(label): nil (\(type(of: v)))"
        }
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

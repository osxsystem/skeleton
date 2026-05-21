import SwiftUI

/// A single row in the log console list.
///
/// Layout (left → right):
/// ```
/// [V]  13:47:02.341  Auth  User 42 signed in
///  ^    ^             ^     ^
///  |    timestamp     tag   message (2-line ellipsis, expandable on tap)
///  severity letter + color stripe (both signals — WCAG 2.1 SC 1.4.1)
/// ```
///
/// Tap the row to expand the full message and, if present, the throwable description.
struct LogRowView: View {
    let entry: LogEntry
    @Environment(\.skylogTheme) private var theme
    @State private var isExpanded = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                // Severity stripe: letter + color (WCAG: both visual cues present)
                Text(entry.severity.letter)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(theme.color(for: entry.severity))
                    .frame(width: 16)
                    .accessibilityLabel(severityAccessibilityLabel)

                VStack(alignment: .leading, spacing: 2) {
                    // Header row: timestamp + tag
                    HStack(spacing: 6) {
                        Text(Self.timeFormatter.string(from: entry.timestamp))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(theme.dim)

                        Text(entry.tag)
                            .font(.caption2.smallCaps().bold())
                            .foregroundStyle(theme.dim)

                        Spacer()
                    }

                    // Message body
                    Text(entry.message)
                        .font(.callout)
                        .lineLimit(isExpanded ? nil : 2)
                        .foregroundStyle(.primary)

                    // Throwable (visible only when expanded)
                    if isExpanded, let err = entry.throwable {
                        Text(String(describing: type(of: err)) + ": " + err.localizedDescription)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(theme.error)
                            .padding(.top, 2)
                    }

                    // Fields (visible only when expanded)
                    if isExpanded, let fields = entry.fields, !fields.isEmpty {
                        let pairs = fields.map { "\($0.key)=\($0.value)" }.joined(separator: "  ")
                        Text(pairs)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(theme.dim)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityHint(isExpanded ? "Double-tap to collapse" : "Double-tap to expand")
    }

    private var severityAccessibilityLabel: String {
        switch entry.severity {
        case .verbose: return "Verbose"
        case .debug:   return "Debug"
        case .info:    return "Info"
        case .warn:    return "Warning"
        case .error:   return "Error"
        case .assert:  return "Assert"
        }
    }
}

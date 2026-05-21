import SwiftUI

/// An in-app log console backed by an `InMemoryLogWriter`.
///
/// Mirrors `LogConsoleScreen` from `:skylog-ui`. Provides:
/// - Severity filter chips (multi-select minimum severity)
/// - Tag picker
/// - Free-text search (matches tag + message)
/// - Virtualized `List` for ≥1 000 entries at 60 fps
/// - "Clear" footer with 5-second undo
///
/// Usage:
/// ```swift
/// LogConsoleView(buffer: myInMemoryWriter)
/// ```
public struct LogConsoleView: View {
    @ObservedObject private var buffer: InMemoryLogWriter
    @Environment(\.skylogTheme) private var theme

    @State private var minSeverity: Severity = .verbose
    @State private var selectedTag: String?   = nil
    @State private var search: String         = ""
    @State private var clearedSnapshot: [LogEntry]? = nil
    @State private var showUndoBanner         = false

    public init(buffer: InMemoryLogWriter) {
        self.buffer = buffer
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            contentArea
            Divider()
            footerBar
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        VStack(spacing: 8) {
            // Severity chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Severity.allCases, id: \.self) { sev in
                        Button {
                            withAnimation { minSeverity = sev }
                        } label: {
                            Text(sev.letter)
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    minSeverity <= sev
                                    ? theme.color(for: sev).opacity(0.2)
                                    : Color.clear
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(theme.color(for: sev), lineWidth: minSeverity <= sev ? 1.5 : 0.5)
                                )
                                .foregroundStyle(theme.color(for: sev))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .accessibilityLabel("\(severityName(sev)) filter")
                        .accessibilityAddTraits(minSeverity <= sev ? .isSelected : [])
                    }
                }
                .padding(.horizontal)
            }

            // Tag picker + search field
            HStack(spacing: 8) {
                tagPicker
                searchField
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    private var tagPicker: some View {
        let tags = Array(Set(buffer.entries.map(\.tag))).sorted()
        return Menu {
            Button("All tags") { selectedTag = nil }
            Divider()
            ForEach(tags, id: \.self) { tag in
                Button(tag) { selectedTag = tag }
            }
        } label: {
            Label(selectedTag ?? "All tags", systemImage: "tag")
                .font(.caption)
                .lineLimit(1)
        }
        .accessibilityLabel("Tag filter, currently \(selectedTag ?? "all tags")")
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $search)
                .font(.callout)
                .autocorrectionDisabled()
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Content

    private var contentArea: some View {
        let filtered = filteredEntries
        return Group {
            if filtered.isEmpty {
                emptyState
            } else {
                List(filtered, id: \.timestamp) { entry in
                    LogRowView(entry: entry)
                        .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                }
                .listStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        let copy = Self.emptyStateCopy(bufferEmpty: buffer.entries.isEmpty)
        return VStack(spacing: 8) {
            Spacer()
            Text(copy.title)
                .font(.title3)
                .foregroundStyle(theme.dim)
            if let subtitle = copy.subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(theme.dim)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    static func emptyStateCopy(bufferEmpty: Bool) -> (title: String, subtitle: String?) {
        if bufferEmpty {
            return ("No logs yet", "Try emitting a log with Skylog.i(\"...\")")
        } else {
            return ("No logs match the current filter", nil)
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            // Undo banner (appears after clear for 5 s)
            if showUndoBanner {
                HStack {
                    Text("Buffer cleared")
                        .font(.callout)
                    Spacer()
                    Button("Undo") {
                        if let snap = clearedSnapshot {
                            buffer.restore(snapshot: snap)
                        }
                        withAnimation { showUndoBanner = false }
                    }
                    .font(.callout.bold())
                }
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Spacer()
                Button {
                    let snap = buffer.entries
                    buffer.clear()
                    clearedSnapshot = snap
                    withAnimation { showUndoBanner = true }
                    // Auto-dismiss after 5 s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation { showUndoBanner = false }
                    }
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.callout)
                }
                .disabled(buffer.entries.isEmpty)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Filtering

    /// Single-pass filter: severity AND tag AND search (AND semantics, FR-11).
    private var filteredEntries: [LogEntry] {
        buffer.entries.filter { entry in
            entry.severity >= minSeverity
            && (selectedTag == nil || entry.tag == selectedTag)
            && (search.isEmpty
                || entry.message.localizedCaseInsensitiveContains(search)
                || entry.tag.localizedCaseInsensitiveContains(search))
        }
    }

    // MARK: - Helpers

    private func severityName(_ s: Severity) -> String {
        switch s {
        case .verbose: return "Verbose"
        case .debug:   return "Debug"
        case .info:    return "Info"
        case .warn:    return "Warning"
        case .error:   return "Error"
        case .assert:  return "Assert"
        }
    }
}

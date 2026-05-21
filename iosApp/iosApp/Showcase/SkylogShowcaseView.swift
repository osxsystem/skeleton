import SwiftUI
import SkylogKit

struct SkylogShowcaseView: View {
    @StateObject private var buffer = InMemoryLogWriter(capacity: 1000)
    @State private var configured = false

    var body: some View {
        LogConsoleView(buffer: buffer)
            .navigationTitle("Skylog Showcase")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !configured else { return }
                configured = true
                Skylog.configure {
                    $0.writers.append(buffer)
                    $0.writers.append(OsLogWriter())
                }
                Skylog.v(tag: "Showcase", "Verbose — app started")
                Skylog.d(tag: "Showcase", "Debug — configuration loaded")
                Skylog.i(tag: "Showcase", "Info — user signed in")
                Skylog.w(tag: "Showcase", "Warn — slow network detected")
                Skylog.e(
                    tag: "Showcase",
                    throwable: NSError(domain: "demo", code: 1, userInfo: [NSLocalizedDescriptionKey: "demo error"]),
                    "Error — request failed"
                )
                Skylog.a(tag: "Showcase", "Assert — invariant violated")
                Skylog.i(
                    tag: "Showcase",
                    fields: ["userId": "42", "screen": "dashboard"],
                    "Info with structured fields"
                )
            }
    }
}

#Preview {
    NavigationStack {
        SkylogShowcaseView()
    }
}

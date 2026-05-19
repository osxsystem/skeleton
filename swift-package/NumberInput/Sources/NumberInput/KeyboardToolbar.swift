import SwiftUI

/// Keyboard accessory toolbar with three buttons: [Clear] [±] [···flex···] [Done].
/// Conforms to ToolbarContent for use with .toolbar { } modifier.
struct KeyboardToolbar: ToolbarContent {
    @ObservedObject var bridge: NumberInputBridge
    @FocusState.Binding var focused: Bool

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Button("Clear", action: clearAction)
                .accessibilityIdentifier("numberInput.toolbar.clear")
                .accessibilityLabel("Clear field")
                .disabled(bridge.clearDisabled)

            Button(action: toggleSignAction) {
                Label("Toggle sign", systemImage: "plus.slash.minus")
                    .labelStyle(.iconOnly)
            }
            .accessibilityIdentifier("numberInput.toolbar.toggleSign")
            .accessibilityLabel("Toggle sign")
            .disabled(bridge.signDisabled)

            Spacer()

            Button(action: doneAction) {
                Text("Done").bold()
            }
            .accessibilityIdentifier("numberInput.toolbar.done")
            .accessibilityLabel("Done")
        }
    }

    private func clearAction() {
        bridge.clear()
    }

    private func toggleSignAction() {
        bridge.toggleSign()
    }

    private func doneAction() {
        bridge.commit()
        focused = false
    }
}

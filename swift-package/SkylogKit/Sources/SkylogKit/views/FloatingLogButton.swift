import SwiftUI

/// A draggable circular button that opens the log console from anywhere.
///
/// Mirrors `FloatingLogButton` from `:skylog-ui` (Compose). Position is kept in `@State`
/// and clamped to the `GeometryReader`-provided viewport on every drag delta so the
/// button can never be dragged offscreen (Eng Review F-4.4 — regression covered by
/// viewport-clamp test).
///
/// Usage:
/// ```swift
/// ZStack(alignment: .bottomTrailing) {
///     content
///     FloatingLogButton(onOpen: { showConsole = true }, unreadCount: count)
/// }
/// ```
public struct FloatingLogButton: View {
    /// Called when the user taps the button.
    public let onOpen: () -> Void
    /// Badge count — displays on the button when > 0.
    public var unreadCount: Int

    @State private var offset: CGSize = .zero
    @Environment(\.skylogTheme) private var theme

    private let buttonSize: CGFloat = 56

    public init(onOpen: @escaping () -> Void, unreadCount: Int = 0) {
        self.onOpen     = onOpen
        self.unreadCount = unreadCount
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomTrailing) {
                Color.clear  // fills the GeometryReader so we get full viewport dimensions

                ZStack(alignment: .topTrailing) {
                    // Button circle
                    Circle()
                        .fill(theme.error.opacity(0.9))
                        .frame(width: buttonSize, height: buttonSize)
                        .overlay(
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundStyle(.white)
                                .font(.system(size: 20, weight: .medium))
                        )
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

                    // Badge
                    if unreadCount > 0 {
                        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color(.systemRed))
                            .clipShape(Capsule())
                            .offset(x: 4, y: -4)
                    }
                }
                .offset(offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let proposed = CGSize(
                                width:  offset.width  + value.translation.width,
                                height: offset.height + value.translation.height
                            )
                            offset = clamped(proposed, in: geo.size)
                        }
                )
                .onTapGesture { onOpen() }
                .accessibilityLabel("Open log console")
                .accessibilityHint(unreadCount > 0 ? "\(unreadCount) unread entries" : "")
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    // MARK: - Clamp helper

    /// Clamp `proposed` so the button stays fully within `viewport`.
    ///
    /// The button starts at `.bottomTrailing` of the `GeometryReader`, so offset (0, 0)
    /// puts it at the trailing-bottom corner. Negative offsets move it up/left.
    /// We clamp to `[-(viewport.width - buttonSize) ... 0]` on width and
    /// `[-(viewport.height - buttonSize) ... 0]` on height.
    private func clamped(_ proposed: CGSize, in viewport: CGSize) -> CGSize {
        let minX = -(viewport.width  - buttonSize)
        let minY = -(viewport.height - buttonSize)
        return CGSize(
            width:  min(0, max(minX, proposed.width)),
            height: min(0, max(minY, proposed.height))
        )
    }
}

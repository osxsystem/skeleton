#if canImport(UIKit)
import SwiftUI
import UIKit

/// How long backspace must be held before it starts repeating.
let backspaceRepeatDelay: TimeInterval = 0.400

/// How often it deletes once it is repeating.
let backspaceRepeatInterval: TimeInterval = 0.080

@MainActor
protocol NumberInputRepeatCancellation: AnyObject {
    func cancel()
}

@MainActor
protocol NumberInputRepeatScheduling {
    func schedule(
        after delay: TimeInterval,
        repeatingEvery interval: TimeInterval?,
        action: @escaping () -> Void
    ) -> NumberInputRepeatCancellation
}

@MainActor
final class NumberInputBackspaceRepeater {
    private let scheduler: NumberInputRepeatScheduling
    private var scheduled: [NumberInputRepeatCancellation] = []
    private(set) var didRepeat = false

    init(scheduler: NumberInputRepeatScheduling) {
        self.scheduler = scheduler
    }

    convenience init() {
        self.init(scheduler: MainRunLoopRepeatScheduler())
    }

    func begin(
        isEnabled: @escaping () -> Bool,
        onRepeatStart: @escaping () -> Void = {},
        action: @escaping () -> Void
    ) {
        cancel()
        guard isEnabled() else { return }

        scheduled = [scheduler.schedule(after: backspaceRepeatDelay, repeatingEvery: nil) { [weak self] in
            guard let self, isEnabled() else {
                self?.cancel()
                return
            }
            self.didRepeat = true
            onRepeatStart()
            action()
            self.scheduled.append(
                self.scheduler.schedule(
                    after: backspaceRepeatInterval,
                    repeatingEvery: backspaceRepeatInterval
                ) { [weak self] in
                    guard let self, isEnabled() else {
                        self?.cancel()
                        return
                    }
                    self.didRepeat = true
                    action()
                }
            )
        }]
    }

    @discardableResult
    func end() -> Bool {
        let repeated = didRepeat
        cancel()
        return repeated
    }

    func cancel() {
        scheduled.forEach { $0.cancel() }
        scheduled = []
        didRepeat = false
    }
}

@MainActor
private final class MainRunLoopRepeatScheduler: NumberInputRepeatScheduling {
    func schedule(
        after delay: TimeInterval,
        repeatingEvery interval: TimeInterval?,
        action: @escaping () -> Void
    ) -> NumberInputRepeatCancellation {
        let timer = Timer(
            fire: Date(timeIntervalSinceNow: delay),
            interval: interval ?? 0,
            repeats: interval != nil
        ) { _ in action() }
        RunLoop.main.add(timer, forMode: .common)
        return TimerRepeatCancellation(timer: timer)
    }
}

@MainActor
private final class TimerRepeatCancellation: NumberInputRepeatCancellation {
    private let timer: Timer

    init(timer: Timer) {
        self.timer = timer
    }

    func cancel() {
        timer.invalidate()
    }
}

struct NumberInputKeyAccessibility {
    let enabled: Bool

    var traits: UIAccessibilityTraits { .button }
    var swiftUITraits: AccessibilityTraits { .isButton }
    var isDisabled: Bool { !enabled }

    @discardableResult
    func perform(_ action: () -> Void) -> Bool {
        guard enabled else { return false }
        action()
        return true
    }
}

/// Dynamic Type policy shared by the built-in keypad and its toolbar.
///
/// Consumer point sizes remain the baseline at Large and scale relative to the semantic role.
/// Scaling is capped at Accessibility 2 because this component occupies the system keyboard's
/// bounded input-view geometry. The cap keeps labels legible without clipping fixed-height keys;
/// the field itself continues to follow the app's unrestricted Dynamic Type preference.
enum NumberInputDynamicType {
    static let maximumSupportedSize: DynamicTypeSize = .accessibility2

    static func pointSize(
        baseSize: CGFloat,
        relativeTo textStyle: UIFont.TextStyle,
        dynamicTypeSize: DynamicTypeSize
    ) -> CGFloat {
        let supportedSize = min(dynamicTypeSize, maximumSupportedSize)
        let traits = UITraitCollection(preferredContentSizeCategory: contentSizeCategory(for: supportedSize))
        return UIFontMetrics(forTextStyle: textStyle).scaledValue(for: baseSize, compatibleWith: traits)
    }

    static func font(
        baseSize: CGFloat,
        fontName: String?,
        weight: Font.Weight?,
        relativeTo textStyle: UIFont.TextStyle,
        dynamicTypeSize: DynamicTypeSize
    ) -> Font {
        let size = pointSize(
            baseSize: baseSize,
            relativeTo: textStyle,
            dynamicTypeSize: dynamicTypeSize
        )
        if let fontName { return .custom(fontName, size: size) }
        return .system(size: size, weight: weight ?? .regular)
    }

    private static func contentSizeCategory(for size: DynamicTypeSize) -> UIContentSizeCategory {
        switch size {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}

/// The library's own keypad.
///
/// Opted into with ``NumberInputConfig/useBuiltInKeypad``, where it is delivered as the field's
/// `inputView` and so replaces the system keyboard outright, riding the native keyboard
/// presentation and content avoidance.
///
/// The decimal key shows the *field's* separator, read from the locale. That is the point of the
/// keypad: the system decimal pad follows the device region, so a de-DE field on a US phone offers
/// a "." that has to be translated after the fact, and the user sees a key that disagrees with the
/// text it produces.
///
/// Keys grey out exactly when a press would be refused, using `NumberInputKeypadRules` — the same
/// conditions ``NumberInputState/onTextChange(_:)`` enforces, asked in advance so no key is
/// pressable and inert.
public struct NumberInputKeypad: View {

    @ObservedObject private var state: NumberInputState
    private let style: NumberInputStyle
    private let bottomInset: CGFloat
    private let leadingAccessory: AnyView?
    private let onPrevious: (() -> Void)?
    private let onNext: (() -> Void)?
    private let onDone: () -> Void
    private let availableWidth: CGFloat?

    /// - Parameters:
    ///   - style: an **already resolved** style — see ``resolveThemedColors(_:dark:)``. Resolution
    ///     happens once, above this view, so nothing downstream has an unset colour left to handle.
    ///   - bottomInset: space held clear below the keys for the home indicator. The background still
    ///     runs to the physical bottom edge, which is what a real soft keyboard does.
    public init(
        state: NumberInputState,
        style: NumberInputStyle,
        bottomInset: CGFloat = 0,
        leadingAccessory: AnyView? = nil,
        onPrevious: (() -> Void)? = nil,
        onNext: (() -> Void)? = nil,
        availableWidth: CGFloat? = nil,
        onDone: @escaping () -> Void
    ) {
        self.state = state
        self.style = style
        self.bottomInset = bottomInset
        self.leadingAccessory = leadingAccessory
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.availableWidth = availableWidth
        self.onDone = onDone
    }

    public var body: some View {
        VStack(spacing: 0) {
            NumberInputToolbarRow(
                state: state,
                style: style,
                leadingAccessory: leadingAccessory,
                onPrevious: onPrevious,
                onNext: onNext,
                availableWidth: availableWidth,
                onDone: onDone
            )

            // Rows of the standard phone arrangement: 1-2-3 at the top, separator / 0 / backspace
            // last.
            VStack(spacing: style.keypad.keySpacing) {
                ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                    HStack(spacing: style.keypad.keySpacing) {
                        ForEach(row, id: \.self) { digit in digitKey(digit) }
                    }
                }
                HStack(spacing: style.keypad.keySpacing) {
                    decimalKey
                    digitKey(0)
                    backspaceKey
                }
            }
            .padding(.horizontal, style.keypad.contentPadding)
            .padding(.vertical, style.keypad.keySpacing / 2)
            // Held clear of the home indicator. The background below covers this too, so the fill
            // still reaches the physical bottom edge.
            .padding(.bottom, bottomInset)
        }
        .frame(maxWidth: .infinity)
        .background(style.keypad.backgroundColor ?? .clear)
        .accessibilityIdentifier(NumberInputTags.keypad)
    }

    private func digitKey(_ digit: Int) -> some View {
        NumberInputKey(
            label: String(digit),
            enabled: state.digitEnabled,
            role: style.keypad.restKey,
            style: style,
            hapticsEnabled: state.config.keypadHaptics,
            identifier: NumberInputTags.keypadDigit(digit),
            contentDescription: String(digit),
            action: { state.pressDigit(digit) }
        )
    }

    private var decimalKey: some View {
        NumberInputKey(
            // The locale's separator, so the key never disagrees with the text it produces.
            label: state.decimalKeyLabel,
            enabled: state.decimalEnabled,
            role: style.keypad.utilityKey,
            style: style,
            hapticsEnabled: state.config.keypadHaptics,
            identifier: NumberInputTags.keypadDecimal,
            // "." and "," are punctuation: a screen reader may announce the glyph as nothing at
            // all, and the two are indistinguishable spoken even when it does.
            contentDescription: style.keypad.decimalContentDescription,
            action: { state.pressDecimalSeparator() }
        )
    }

    private var backspaceKey: some View {
        NumberInputKey(
            label: style.keypad.backspaceLabel,
            systemImage: style.keypad.backspaceSystemImage,
            iconWidth: style.keypad.backspaceIconWidth,
            iconHeight: style.keypad.backspaceIconHeight,
            enabled: state.backspaceEnabled,
            role: style.keypad.utilityKey,
            style: style,
            hapticsEnabled: state.config.keypadHaptics,
            identifier: NumberInputTags.keypadBackspace,
            contentDescription: style.keypad.backspaceContentDescription,
            repeatsOnHold: true,
            action: { state.pressBackspace() }
        )
    }
}

// MARK: - One key

/// One key of the grid.
///
/// Width comes from the row so three columns fill any screen; the height is fixed so the grid does
/// not stretch on a tablet.
///
/// The press is driven by a zero-distance drag rather than a `Button` for two reasons: the pressed
/// styling has to be readable from the gesture, and backspace needs a press-down hook for
/// hold-to-repeat. Releasing outside the key cancels rather than types, which is what a `Button`
/// would have given for free.
///
/// The lip under the key is drawn as an offset silhouette rather than a shadow: a design's
/// `0 1px 0` is a hard edge with no blur and no spread. It is suppressed while pressed or disabled
/// — a key that keeps its lip reads as neither.
struct NumberInputKey: View {

    let label: String
    var systemImage: String?
    var iconWidth: CGFloat = 0
    var iconHeight: CGFloat = 0
    let enabled: Bool
    let role: NumberInputKeyStyle
    let style: NumberInputStyle
    let hapticsEnabled: Bool
    let identifier: String
    let contentDescription: String
    var repeatsOnHold: Bool = false
    let action: () -> Void

    @State private var pressed = false
    @State private var inside = true
    @State private var size: CGSize = .zero
    @State private var backspaceRepeater = NumberInputBackspaceRepeater()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var drawn: NumberInputKeyStyle {
        if !enabled { return role.merged(withState: style.keypad.disabledKey) }
        if pressed { return role.merged(withState: style.keypad.pressedKey) }
        return role
    }

    /// An unset disabled colour means "multiply by `disabledAlpha`". A colour a consumer actually
    /// set is used as-is, so a design naming an explicit disabled fill is not dimmed on top of it.
    private var contentOpacity: Double {
        (!enabled && style.keypad.disabledKey.contentColor == nil) ? style.disabledAlpha : 1
    }

    private var lipVisible: Bool { enabled && !pressed && drawn.shadowColor != nil }
    private var accessibility: NumberInputKeyAccessibility {
        NumberInputKeyAccessibility(enabled: enabled)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: style.keypad.keyCornerRadius, style: .continuous)
        let lipHeight = lipVisible ? drawn.shadowHeight : 0

        ZStack(alignment: .top) {
            if lipVisible, let lip = drawn.shadowColor {
                shape
                    .fill(lip)
                    .frame(height: style.keypad.keyHeight)
                    .offset(y: drawn.shadowHeight)
            }
            face(shape)
        }
        .frame(height: style.keypad.keyHeight + lipHeight)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .background(sizeReader)
        .gesture(pressGesture)
        .disabled(accessibility.isDisabled)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(contentDescription)
        .accessibilityAddTraits(accessibility.swiftUITraits)
        .accessibilityHidden(false)
        .accessibilityAction {
            accessibility.perform {
                fireHaptic()
                action()
            }
        }
        .onDisappear(perform: cancelRepeat)
    }

    private func face(_ shape: RoundedRectangle) -> some View {
        ZStack(alignment: drawn.contentAlignment) {
            shape.fill(drawn.backgroundColor ?? .clear)
            if let border = drawn.borderColor, drawn.borderWidth > 0 {
                shape.strokeBorder(border, lineWidth: drawn.borderWidth)
            }
            glyph
                .padding(.bottom, drawn.contentBottomPadding)
        }
        .frame(height: style.keypad.keyHeight)
    }

    @ViewBuilder
    private var glyph: some View {
        let tint = (drawn.contentColor ?? .primary).opacity(contentOpacity)
        if let systemImage {
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .frame(width: iconWidth, height: iconHeight)
                .foregroundColor(tint)
        } else {
            Text(label)
                .font(keyFont)
                .modifier(TabularFigures(enabled: style.keypad.tabularFigures))
                .foregroundColor(tint)
        }
    }

    private var keyFont: Font {
        NumberInputDynamicType.font(
            baseSize: drawn.textSize ?? 22,
            fontName: style.keypad.fontName,
            weight: drawn.fontWeight,
            relativeTo: .title2,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    private var sizeReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: NumberInputKeySizeKey.self, value: proxy.size)
        }
        .onPreferenceChange(NumberInputKeySizeKey.self) { size = $0 }
    }

    // MARK: - Press handling

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let within = contains(value.location)
                if !pressed { beginPress() }
                if inside != within { inside = within }
            }
            .onEnded { value in endPress(inside: contains(value.location)) }
    }

    private func contains(_ point: CGPoint) -> Bool {
        guard size != .zero else { return true }
        return point.x >= 0 && point.y >= 0 && point.x <= size.width && point.y <= size.height
    }

    private func beginPress() {
        guard enabled else { return }
        pressed = true
        inside = true
        guard repeatsOnHold else { return }

        backspaceRepeater.begin(
            isEnabled: { enabled },
            onRepeatStart: fireHaptic,
            action: action
        )
    }

    private func endPress(inside within: Bool) {
        let repeatFired = backspaceRepeater.end()
        let wasPressed = pressed
        pressed = false
        inside = true
        guard enabled, wasPressed, within else { return }
        // `repeatFired` stops the release landing one more delete on top of the repeats.
        guard !repeatFired else {
            return
        }
        fireHaptic()
        action()
    }

    private func cancelRepeat() {
        backspaceRepeater.cancel()
    }

    private func fireHaptic() {
        guard hapticsEnabled else { return }
        NumberInputHaptics.tap()
    }
}

private struct NumberInputKeySizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

/// `monospacedDigit()` is iOS 15 on `Font`, but only from 16 as a view modifier, so the fallback
/// keeps proportional figures rather than failing to build.
private struct TabularFigures: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled, #available(iOS 16.0, macOS 13.0, *) {
            content.monospacedDigit()
        } else {
            content
        }
    }
}

/// A light tick on an accepted press.
///
/// The generator is held rather than rebuilt per press: constructing one costs a Taptic Engine
/// warm-up, and a keypad that ticks late is worse than one that does not tick.
enum NumberInputHaptics {
    private static let generator = UIImpactFeedbackGenerator(style: .light)

    static func tap() {
        generator.impactOccurred()
    }
}
#endif

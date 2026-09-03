#if canImport(UIKit)
import Combine
import SwiftUI
import UIKit

/// UIKit-backed field used at the SwiftUI boundary. Its coordinator owns the input views so neither
/// the native toolbar nor the hosted keypad is rebuilt as SwiftUI refreshes the representable.
struct NumberInputUITextField: UIViewRepresentable {
    let state: NumberInputState
    @Binding var value: Double?
    @Binding var focused: Bool
    let style: NumberInputStyle
    let isEnabled: Bool
    let leadingAccessory: AnyView?
    let onPrevious: (() -> Void)?
    let onNext: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> NumberInputNativeTextField {
        let textField = NumberInputNativeTextField()
        textField.delegate = context.coordinator
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textChanged(_:)),
            for: .editingChanged
        )
        context.coordinator.textField = textField
        context.coordinator.configure(textField)
        context.coordinator.installInputViews(on: textField)
        return textField
    }

    func updateUIView(_ uiView: NumberInputNativeTextField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.configure(uiView)
        context.coordinator.installInputViews(on: uiView)
        context.coordinator.renderState(in: uiView)

        context.coordinator.requestFocusUpdate(focused && isEnabled, for: uiView)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NumberInputUITextField
        weak var textField: NumberInputNativeTextField?

        private var toolbar: UIToolbar?
        private var clearItem: UIBarButtonItem?
        private var signItem: UIBarButtonItem?
        private var doneItem: UIBarButtonItem?
        private var keypadView: NumberInputKeypadView?
        private var valueSubscription: AnyCancellable?
        private var pendingFocusUpdate: Bool?

        init(_ parent: NumberInputUITextField) {
            self.parent = parent
            super.init()
            valueSubscription = parent.state.$value
                .dropFirst()
                .sink { [weak self] newValue in
                    guard let self, self.parent.value != newValue else { return }
                    self.parent.value = newValue
                }
        }

        func configure(_ textField: NumberInputNativeTextField) {
            textField.keyboardType = .decimalPad
            textField.isEnabled = parent.isEnabled
            textField.alpha = parent.isEnabled ? 1 : parent.style.disabledAlpha
            textField.adjustsFontForContentSizeCategory = true
            textField.font = Self.scaledFont(for: parent.style)
            textField.textAlignment = Self.textAlignment(parent.style.textAlign, in: textField)
            textField.textColor = UIColor(parent.style.textColor)
            textField.tintColor = UIColor(parent.style.cursorColor)
            textField.backgroundColor = UIColor(parent.style.backgroundColor)
            textField.contentInsets = UIEdgeInsets(
                top: parent.style.contentPadding.top,
                left: parent.style.contentPadding.leading,
                bottom: parent.style.contentPadding.bottom,
                right: parent.style.contentPadding.trailing
            )
            textField.layer.borderColor = UIColor(parent.style.borderColor).cgColor
            textField.layer.borderWidth = parent.style.borderWidth
            textField.layer.cornerRadius = parent.style.cornerRadius
            textField.layer.masksToBounds = parent.style.cornerRadius > 0
            textField.attributedPlaceholder = NSAttributedString(
                string: parent.state.config.placeholder,
                attributes: [
                    .foregroundColor: UIColor(parent.style.placeholderColor),
                    .font: textField.font as Any
                ]
            )
            textField.accessibilityIdentifier = NumberInputTags.field
        }

        func requestFocusUpdate(_ shouldFocus: Bool, for textField: NumberInputNativeTextField) {
            guard textField.isFirstResponder != shouldFocus else {
                pendingFocusUpdate = nil
                return
            }
            guard pendingFocusUpdate != shouldFocus else { return }
            pendingFocusUpdate = shouldFocus

            DispatchQueue.main.async { [weak self, weak textField] in
                guard let self, let textField, self.pendingFocusUpdate == shouldFocus else { return }
                self.pendingFocusUpdate = nil
                guard textField.window != nil else { return }
                if shouldFocus {
                    self.installInputViews(on: textField)
                    textField.becomeFirstResponder()
                } else {
                    textField.resignFirstResponder()
                }
            }
        }

        func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
            guard let textField = textField as? NumberInputNativeTextField else {
                return parent.isEnabled
            }
            installInputViews(on: textField)
            return parent.isEnabled
        }

        func installInputViews(on textField: NumberInputNativeTextField) {
            if parent.state.config.useBuiltInKeypad {
                let keypad: NumberInputKeypadView
                let sizingChanged: Bool
                if let existing = keypadView {
                    keypad = existing
                    sizingChanged = existing.update(
                        style: parent.style,
                        leadingAccessory: parent.leadingAccessory,
                        onPrevious: parent.onPrevious == nil ? nil : { [weak self] in
                            self?.parent.onPrevious?()
                        },
                        onNext: parent.onNext == nil ? nil : { [weak self] in
                            self?.parent.onNext?()
                        },
                        hostWidth: textField.window?.bounds.width
                    )
                } else {
                    let created = NumberInputKeypadView(
                        state: parent.state,
                        style: parent.style,
                        leadingAccessory: parent.leadingAccessory,
                        onPrevious: parent.onPrevious == nil ? nil : { [weak self] in
                            self?.parent.onPrevious?()
                        },
                        onNext: parent.onNext == nil ? nil : { [weak self] in
                            self?.parent.onNext?()
                        },
                        hostWidth: textField.window?.bounds.width,
                        onDone: { [weak self] in self?.finishEditing() }
                    )
                    keypadView = created
                    keypad = created
                    sizingChanged = true
                }

                let inputChanged = textField.inputView !== keypad || textField.inputAccessoryView != nil
                textField.inputView = keypad
                textField.inputAccessoryView = nil
                if textField.isFirstResponder, inputChanged || sizingChanged {
                    textField.reloadInputViews()
                }
            } else {
                let nativeToolbar = toolbar ?? makeToolbar()
                let inputChanged = textField.inputView != nil || textField.inputAccessoryView !== nativeToolbar
                textField.inputView = nil
                textField.inputAccessoryView = nativeToolbar
                syncToolbar()
                if textField.isFirstResponder, inputChanged { textField.reloadInputViews() }
            }
        }

        func renderState(in textField: UITextField, moveCaretToEnd: Bool = true) {
            let display = parent.state.displayText
            guard textField.text != display else {
                syncToolbar()
                return
            }
            textField.text = display
            if moveCaretToEnd {
                let end = textField.endOfDocument
                textField.selectedTextRange = textField.textRange(from: end, to: end)
            }
            syncToolbar()
        }

        @objc func textChanged(_ sender: UITextField) {
            let grouped = sender.text ?? ""
            let raw = ungroupTypedText(
                grouped: grouped,
                previousDisplay: parent.state.displayText,
                groupingSeparator: parent.state.groupingSeparator,
                decimalSeparator: parent.state.decimalKeyLabel
            )
            parent.state.onTextChange(raw)
            // Accepted edits are immediately regrouped; rejected edits restore the previous buffer.
            // Assigning `text` programmatically does not emit another `.editingChanged` event.
            renderState(in: sender)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.state.onFocusChanged(true)
            if !parent.focused { parent.focused = true }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.state.onFocusChanged(false)
            renderState(in: textField)
            if parent.focused { parent.focused = false }
        }

        // MARK: Native system-keyboard toolbar

        private func makeToolbar() -> UIToolbar {
            let toolbar = UIToolbar()

            let clear = UIBarButtonItem(
                title: parent.style.toolbar.clearLabel,
                style: .plain,
                target: self,
                action: #selector(clearPressed)
            )
            clear.accessibilityIdentifier = NumberInputTags.toolbarClear
            clear.accessibilityLabel = parent.style.toolbar.clearLabel

            let sign = UIBarButtonItem(
                title: parent.style.toolbar.signLabel,
                style: .plain,
                target: self,
                action: #selector(signPressed)
            )
            sign.accessibilityIdentifier = NumberInputTags.toolbarSign
            sign.accessibilityLabel = parent.style.toolbar.signLabel

            let done = UIBarButtonItem(
                title: parent.style.toolbar.doneLabel,
                style: .done,
                target: self,
                action: #selector(donePressed)
            )
            done.accessibilityIdentifier = NumberInputTags.toolbarDone
            done.accessibilityLabel = parent.style.toolbar.doneLabel

            var items = [clear]
            if NumberInputToolbarRules.signVisible(allowNegative: parent.state.config.allowNegative) {
                items.append(sign)
            }
            items.append(UIBarButtonItem(systemItem: .flexibleSpace))
            items.append(done)
            toolbar.setItems(items, animated: false)
            toolbar.sizeToFit()

            self.toolbar = toolbar
            self.clearItem = clear
            self.signItem = sign
            self.doneItem = done
            syncToolbar()
            return toolbar
        }

        private func syncToolbar() {
            guard let toolbar else { return }
            let toolbarStyle = parent.style.toolbar
            toolbar.barTintColor = toolbarStyle.backgroundColor.map(UIColor.init)
            toolbar.tintColor = toolbarStyle.tint.map(UIColor.init)

            clearItem?.title = toolbarStyle.clearLabel
            clearItem?.accessibilityLabel = toolbarStyle.clearLabel
            clearItem?.isEnabled = parent.state.clearEnabled
            clearItem?.tintColor = toolbarStyle.tint.map(UIColor.init)

            signItem?.title = toolbarStyle.signLabel
            signItem?.accessibilityLabel = toolbarStyle.signLabel
            signItem?.isEnabled = parent.state.signEnabled
            signItem?.tintColor = toolbarStyle.tint.map(UIColor.init)

            doneItem?.title = toolbarStyle.doneLabel
            doneItem?.accessibilityLabel = toolbarStyle.doneLabel
            doneItem?.tintColor = toolbarStyle.tint.map(UIColor.init)
        }

        @objc private func clearPressed() {
            guard parent.state.clearEnabled else { return }
            parent.state.clear()
            if let textField { renderState(in: textField) }
        }

        @objc private func signPressed() {
            guard parent.state.signEnabled else { return }
            parent.state.toggleSign()
            if let textField { renderState(in: textField) }
        }

        @objc private func donePressed() { finishEditing() }

        private func finishEditing() {
            // Commit before resignation so Done has deterministic semantics even if UIKit delays the
            // end-editing delegate callback. Focus loss commits again harmlessly.
            parent.state.commit()
            if let textField {
                renderState(in: textField)
                textField.resignFirstResponder()
            }
        }

        // MARK: UIKit conversions

        private static func scaledFont(for style: NumberInputStyle) -> UIFont {
            let base = style.fontName.flatMap { UIFont(name: $0, size: style.textSize) }
                ?? UIFont.systemFont(ofSize: style.textSize, weight: uiFontWeight(style.textWeight))
            return UIFontMetrics(forTextStyle: .body).scaledFont(for: base)
        }

        private static func uiFontWeight(_ weight: Font.Weight) -> UIFont.Weight {
            switch weight {
            case .ultraLight: return .ultraLight
            case .thin: return .thin
            case .light: return .light
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            case .heavy: return .heavy
            case .black: return .black
            default: return .regular
            }
        }

        private static func textAlignment(
            _ alignment: NumberInputTextAlign,
            in textField: UITextField
        ) -> NSTextAlignment {
            switch alignment {
            case .center: return .center
            case .left: return .left
            case .right: return .right
            case .start:
                return textField.effectiveUserInterfaceLayoutDirection == .rightToLeft ? .right : .left
            case .end:
                return textField.effectiveUserInterfaceLayoutDirection == .rightToLeft ? .left : .right
            }
        }
    }
}

/// A text field whose content insets are part of its intrinsic size rather than SwiftUI decoration.
/// Keeping them inside UIKit gives editing text and placeholder exactly the same geometry.
final class NumberInputNativeTextField: UITextField {
    var contentInsets: UIEdgeInsets = .zero {
        didSet { invalidateIntrinsicContentSize() }
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: contentInsets) }
    override func editingRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: contentInsets) }
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: contentInsets) }

    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        return CGSize(
            width: base.width + contentInsets.left + contentInsets.right,
            height: max(44, base.height + contentInsets.top + contentInsets.bottom)
        )
    }

}

/// Self-sizing UIKit input view hosting the SwiftUI keypad. Because this is a real `inputView`, UIKit
/// supplies the native keyboard transition and scroll avoidance without a host overlay.
final class NumberInputKeypadView: UIInputView {
    private let state: NumberInputState
    private var style: NumberInputStyle
    private var leadingAccessory: AnyView?
    private var onPrevious: (() -> Void)?
    private var onNext: (() -> Void)?
    private let onDone: () -> Void
    private var bottomInset: CGFloat = 0
    private var observedBottomSafeArea: CGFloat = 0
    private var hostWidth: CGFloat

    private let hostingController: UIHostingController<AnyView>
    private var frameSynchronizationScheduled = false
    private var renderedWidth: CGFloat = 0

    init(
        state: NumberInputState,
        style: NumberInputStyle,
        leadingAccessory: AnyView?,
        onPrevious: (() -> Void)?,
        onNext: (() -> Void)?,
        hostWidth: CGFloat?,
        onDone: @escaping () -> Void
    ) {
        self.state = state
        self.style = style
        self.leadingAccessory = leadingAccessory
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.hostWidth = hostWidth ?? 0
        self.onDone = onDone
        self.hostingController = UIHostingController(rootView: AnyView(EmptyView()))
        super.init(frame: .zero, inputViewStyle: .keyboard)

        allowsSelfSizing = true
        if #available(iOS 16.4, *) {
            hostingController.safeAreaRegions = []
        }
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(hostingController.view)
        rebuildRoot()
        synchronizeFrameHeight()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Returns whether the keypad's fitting size changed and the first responder should reload it.
    @discardableResult
    func update(
        style: NumberInputStyle,
        leadingAccessory: AnyView?,
        onPrevious: (() -> Void)?,
        onNext: (() -> Void)?,
        hostWidth: CGFloat?
    ) -> Bool {
        let styleChanged = self.style != style
        let navigationChanged = (self.onPrevious == nil) != (onPrevious == nil)
            || (self.onNext == nil) != (onNext == nil)
        self.style = style
        self.leadingAccessory = leadingAccessory
        self.onPrevious = onPrevious
        self.onNext = onNext
        let nextHostWidth = hostWidth ?? 0
        let hostWidthChanged = nextHostWidth > 0 && abs(self.hostWidth - nextHostWidth) > 0.5
        if hostWidthChanged { self.hostWidth = nextHostWidth }
        rebuildRoot()
        if styleChanged || navigationChanged || hostWidthChanged {
            invalidateIntrinsicContentSize()
            synchronizeFrameHeight()
        }
        return styleChanged || navigationChanged || hostWidthChanged
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        let next = safeAreaInsets.bottom
        guard abs(next - observedBottomSafeArea) > 0.5 else { return }
        observedBottomSafeArea = next
        if #available(iOS 16.4, *) {
            // The hosted SwiftUI safe area is disabled, so reserve the home-indicator inset in the
            // keypad content itself.
            bottomInset = next
        } else {
            // Older UIHostingController versions apply this inset automatically. The input view's
            // frame grows by the same amount below so that automatic inset cannot push the toolbar
            // above its hit-test bounds.
            bottomInset = 0
        }
        rebuildRoot()
        invalidateIntrinsicContentSize()
        synchronizeFrameHeight()
    }

    override var intrinsicContentSize: CGSize {
        let width = availableLayoutWidth
        guard width > 0 else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
        let target = CGSize(width: width, height: UIView.layoutFittingExpandedSize.height)
        let fitted: CGSize
        if #available(iOS 16.0, *) {
            fitted = hostingController.sizeThatFits(in: target)
        } else {
            fitted = hostingController.view.sizeThatFits(target)
        }
        let automaticSafeAreaHeight: CGFloat
        if #available(iOS 16.4, *) {
            automaticSafeAreaHeight = 0
        } else {
            automaticSafeAreaHeight = observedBottomSafeArea
        }
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: ceil(fitted.height + automaticSafeAreaHeight)
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hostingController.view.frame = bounds
        let width = availableLayoutWidth
        if width > 0, abs(width - renderedWidth) > 0.5 {
            renderedWidth = width
            rebuildRoot()
            invalidateIntrinsicContentSize()
        }
    }

    private var availableLayoutWidth: CGFloat {
        if bounds.width > 0 { return bounds.width }
        if let superview, superview.bounds.width > 0 { return superview.bounds.width }
        if let window, window.bounds.width > 0 { return window.bounds.width }
        return hostWidth
    }

    private func rebuildRoot() {
        hostingController.rootView = AnyView(
            NumberInputKeypad(
                state: state,
                style: style,
                bottomInset: bottomInset,
                leadingAccessory: leadingAccessory,
                onPrevious: onPrevious,
                onNext: onNext,
                availableWidth: availableLayoutWidth > 0 ? availableLayoutWidth : nil,
                onDone: onDone
            )
            .ignoresSafeArea()
        )
        hostingController.view.setNeedsLayout()
        scheduleFrameHeightSynchronization()
    }

    private func scheduleFrameHeightSynchronization() {
        guard !frameSynchronizationScheduled else { return }
        frameSynchronizationScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.frameSynchronizationScheduled = false
            self.hostingController.view.layoutIfNeeded()
            self.invalidateIntrinsicContentSize()
            self.synchronizeFrameHeight()
        }
    }

    private func synchronizeFrameHeight() {
        let fittedHeight = intrinsicContentSize.height
        guard fittedHeight > 0,
              fittedHeight != UIView.noIntrinsicMetric,
              abs(frame.height - fittedHeight) > 0.5 else { return }
        frame.size.height = fittedHeight
    }
}

// MARK: - Built-in keypad toolbar row

struct NumberInputToolbarRow: View {
    @ObservedObject var state: NumberInputState
    let style: NumberInputStyle
    let leadingAccessory: AnyView?
    let onPrevious: (() -> Void)?
    let onNext: (() -> Void)?
    var availableWidth: CGFloat? = nil
    let onDone: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var compact: Bool { (availableWidth ?? .infinity) < 360 }
    private var itemSpacing: CGFloat { compact ? min(style.toolbar.itemSpacing, 2) : style.toolbar.itemSpacing }
    private var contentPadding: CGFloat { compact ? min(style.toolbar.contentPadding, 4) : style.toolbar.contentPadding }

    var body: some View {
        ZStack {
            HStack(spacing: itemSpacing) {
                if let leadingAccessory {
                    leadingAccessory
                        .accessibilityIdentifier(NumberInputTags.toolbarLogo)
                }
                if let onPrevious {
                    toolbarButton(
                        label: style.toolbar.previousLabel,
                        contentDescription: style.toolbar.previousContentDescription,
                        identifier: NumberInputTags.toolbarPrevious,
                        enabled: true,
                        role: style.toolbar.navigation,
                        action: onPrevious
                    )
                }
                if let onNext {
                    toolbarButton(
                        label: style.toolbar.nextLabel,
                        contentDescription: style.toolbar.nextContentDescription,
                        identifier: NumberInputTags.toolbarNext,
                        enabled: true,
                        role: style.toolbar.navigation,
                        action: onNext
                    )
                }

                Spacer(minLength: 0)

                if NumberInputToolbarRules.signVisible(allowNegative: state.config.allowNegative) {
                    toolbarButton(
                        label: style.toolbar.signLabel,
                        contentDescription: style.toolbar.signLabel,
                        identifier: NumberInputTags.toolbarSign,
                        enabled: state.signEnabled,
                        role: style.toolbar.action,
                        action: state.toggleSign
                    )
                }
                toolbarButton(
                    label: style.toolbar.clearLabel,
                    contentDescription: style.toolbar.clearLabel,
                    identifier: NumberInputTags.toolbarClear,
                    enabled: state.clearEnabled,
                    role: style.toolbar.action,
                    action: state.clear
                )
                toolbarButton(
                    label: style.toolbar.doneLabel,
                    contentDescription: style.toolbar.doneLabel,
                    identifier: NumberInputTags.toolbarDone,
                    enabled: true,
                    role: style.toolbar.done,
                    action: onDone
                )
            }

            if let hint = style.toolbar.hint, !hint.isEmpty {
                Text(hint)
                    .font(NumberInputDynamicType.font(
                        baseSize: style.toolbar.hintTextSize,
                        fontName: style.toolbar.fontName,
                        weight: style.toolbar.hintFontWeight,
                        relativeTo: .caption1,
                        dynamicTypeSize: dynamicTypeSize
                    ))
                    .foregroundColor(style.toolbar.hintColor ?? style.toolbar.tint ?? .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier(NumberInputTags.toolbarHint)
            }
        }
        .padding(contentPadding)
        .frame(minHeight: style.toolbar.height)
        .frame(maxWidth: .infinity)
        .background(style.toolbar.backgroundColor ?? .clear)
        .overlay(alignment: .bottom) {
            if let color = style.toolbar.bottomBorderColor, style.toolbar.bottomBorderWidth > 0 {
                Rectangle()
                    .fill(color)
                    .frame(height: style.toolbar.bottomBorderWidth)
            }
        }
    }

    private func toolbarButton(
        label: String,
        contentDescription: String,
        identifier: String,
        enabled: Bool,
        role: NumberInputToolbarActionStyle,
        action: @escaping () -> Void
    ) -> some View {
        Text(label)
            .font(NumberInputDynamicType.font(
                baseSize: style.toolbar.labelTextSize,
                fontName: style.toolbar.fontName,
                weight: style.toolbar.labelFontWeight,
                relativeTo: .body,
                dynamicTypeSize: dynamicTypeSize
            ))
            .foregroundColor(role.contentColor ?? style.toolbar.tint ?? .primary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, horizontalPadding(for: identifier, role: role))
            .padding(.vertical, role.verticalPadding)
            .frame(minHeight: role.height)
            .fixedSize(horizontal: true, vertical: false)
            .background(role.backgroundColor ?? .clear)
            .clipShape(RoundedRectangle(cornerRadius: role.cornerRadius, style: .continuous))
            .overlay {
                if let border = role.borderColor, role.borderWidth > 0 {
                    RoundedRectangle(cornerRadius: role.cornerRadius, style: .continuous)
                        .strokeBorder(border, lineWidth: role.borderWidth)
                }
            }
            // Keep the visual chrome consumer-configurable while reserving a standard UIKit
            // touch target for the transparent native control layered above it.
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityHidden(true)
            .overlay {
                NumberInputToolbarActionControl(
                    identifier: identifier,
                    accessibilityLabel: contentDescription,
                    enabled: enabled,
                    action: action
                )
            }
            .opacity(enabled ? 1 : style.disabledAlpha)
    }

    private func horizontalPadding(
        for identifier: String,
        role: NumberInputToolbarActionStyle
    ) -> CGFloat {
        guard compact else { return role.horizontalPadding }
        if identifier == NumberInputTags.toolbarDone {
            return min(role.horizontalPadding, 6)
        }
        return min(role.horizontalPadding, 4)
    }
}

/// A real UIKit control is required here because the toolbar is hosted inside a `UIInputView`.
/// SwiftUI `Button` gestures in that compatibility-controller hierarchy can render while never
/// entering UIKit's action-dispatch tree, which makes every visible toolbar action inert.
private struct NumberInputToolbarActionControl: UIViewRepresentable {
    let identifier: String
    let accessibilityLabel: String
    let enabled: Bool
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> NumberInputToolbarButton {
        let button = NumberInputToolbarButton(type: .custom)
        button.backgroundColor = .clear
        button.isAccessibilityElement = true
        button.accessibilityTraits.insert(.button)
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.activate),
            for: .touchUpInside
        )
        return button
    }

    func updateUIView(_ button: NumberInputToolbarButton, context: Context) {
        context.coordinator.action = action
        button.isEnabled = enabled
        button.accessibilityIdentifier = identifier
        button.accessibilityLabel = accessibilityLabel
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func activate() { action() }
    }
}

private final class NumberInputToolbarButton: UIButton {
    override var intrinsicContentSize: CGSize { .zero }

    override func sizeThatFits(_ size: CGSize) -> CGSize { size }
}
#endif

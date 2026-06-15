import SwiftUI
import UIKit

/// UIKit-backed text field that respects external text updates mid-edit.
///
/// SwiftUI's `TextField` keeps an internal buffer for keystrokes and ignores mid-edit binding
/// writes — live formatting like "1000" → "1,000" fails to render. Wrapping `UITextField` in
/// `UIViewRepresentable` lets us set `textField.text` directly and adjust the cursor.
struct NumberInputUITextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    let placeholder: String
    let textColor: UIColor
    let placeholderColor: UIColor
    let tintColor: UIColor
    let font: UIFont
    var textAlignment: NSTextAlignment = .natural
    var isEnabled: Bool = true
    /// Maximum number of digits allowed after the decimal separator while typing.
    /// Negative means no cap. Driven by the field's `significantDigits`.
    var maxFractionDigits: Int = -1
    /// The field's locale decimal separator. The `.decimalPad` keyboard offers only the device's
    /// locale decimal — if it differs, the delegate substitutes on keypress so vi-VN/de-DE
    /// fields can accept decimals on an en-US device.
    let decimalSeparator: String
    var onEditingChanged: ((Bool) -> Void)?
    var inputAccessoryView: UIView?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.keyboardType = .decimalPad
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        tf.font = font
        tf.textAlignment = textAlignment
        tf.isEnabled = isEnabled
        tf.tintColor = tintColor
        tf.textColor = textColor
        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: placeholderColor]
        )
        tf.inputAccessoryView = inputAccessoryView
        tf.accessibilityIdentifier = "numberInput.field"
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.isEnabled != isEnabled { uiView.isEnabled = isEnabled }
        if uiView.textAlignment != textAlignment { uiView.textAlignment = textAlignment }
        if uiView.text != text {
            uiView.text = text
            if let end = uiView.position(from: uiView.beginningOfDocument, offset: text.count) {
                uiView.selectedTextRange = uiView.textRange(from: end, to: end)
            }
        }
        if focused && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !focused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NumberInputUITextField

        init(_ parent: NumberInputUITextField) {
            self.parent = parent
        }

        @objc func textChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let fieldDec = parent.decimalSeparator

            // Cap the number of fractional digits. Deletions (empty replacement) always pass.
            if !string.isEmpty, parent.maxFractionDigits >= 0 {
                let current = textField.text ?? ""
                if let r = Range(range, in: current) {
                    let prospective = current.replacingCharacters(in: r, with: string)
                    if let sep = prospective.range(of: fieldDec) {
                        let fraction = prospective[sep.upperBound...]
                        if fraction.count > parent.maxFractionDigits { return false }
                    }
                }
            }

            guard string.count == 1 else { return true }
            let isDigit = string.allSatisfy { $0.isNumber }
            if !isDigit && string != fieldDec && (string == "." || string == ",") {
                let current = textField.text ?? ""
                guard let swiftRange = Range(range, in: current) else { return true }
                let updated = current.replacingCharacters(in: swiftRange, with: fieldDec)
                textField.text = updated
                let insertedEnd = current.distance(from: current.startIndex, to: swiftRange.lowerBound) + fieldDec.count
                if let pos = textField.position(from: textField.beginningOfDocument, offset: insertedEnd) {
                    textField.selectedTextRange = textField.textRange(from: pos, to: pos)
                }
                parent.text = updated
                return false
            }
            return true
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.focused { parent.focused = true }
            parent.onEditingChanged?(true)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.focused { parent.focused = false }
            parent.onEditingChanged?(false)
        }
    }
}

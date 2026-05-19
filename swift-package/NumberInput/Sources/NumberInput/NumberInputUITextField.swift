import SwiftUI
import UIKit

/// UIKit-backed text field that respects external text updates mid-edit.
///
/// SwiftUI's `TextField` keeps an internal buffer for the keystrokes the user just typed
/// and ignores mid-edit binding writes — which means live formatting like "1000" → "1,000"
/// fails to show on screen even though the bound value is correct. Wrapping `UITextField`
/// in `UIViewRepresentable` lets us set `textField.text` directly in `updateUIView`,
/// adjust the cursor, and forward focus/edit events to SwiftUI.
struct NumberInputUITextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    let placeholder: String
    let textColor: UIColor
    let placeholderColor: UIColor
    let tintColor: UIColor
    let font: UIFont
    /// The field's locale decimal separator. The .decimalPad keyboard offers only the device's
    /// locale decimal — if it differs from the field's, the delegate substitutes on keypress so
    /// vi-VN/de-DE fields can accept decimals on an en-US device.
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
        if uiView.text != text {
            // Preserve cursor at end (matches the .decimalPad UX expectation).
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

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // Only intercept single-character insertions. Deletions (empty replacement) and
            // multi-character paste fall through to default handling.
            guard string.count == 1 else { return true }
            let fieldDec = parent.decimalSeparator
            // .decimalPad keystrokes are digits, "-" (never on this keyboard), or the device
            // locale's decimal char. If the user typed a non-digit and it doesn't match the
            // field's decimal separator, treat it as a decimal-separator press and substitute.
            let isDigit = string.allSatisfy { $0.isNumber }
            if !isDigit && string != fieldDec && (string == "." || string == ",") {
                let current = textField.text ?? ""
                guard let swiftRange = Range(range, in: current) else { return true }
                let updated = current.replacingCharacters(in: swiftRange, with: fieldDec)
                textField.text = updated
                // Place cursor right after the inserted separator.
                let insertedEnd = current.distance(from: current.startIndex, to: swiftRange.lowerBound) + fieldDec.count
                if let pos = textField.position(from: textField.beginningOfDocument, offset: insertedEnd) {
                    textField.selectedTextRange = textField.textRange(from: pos, to: pos)
                }
                // Manually publish the change since shouldChange returning false skips editingChanged.
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

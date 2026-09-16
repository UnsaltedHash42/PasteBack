import AppKit
import SwiftUI

/// NSSearchField wrapper: gives reliable programmatic focus in the popover
/// without SwiftUI focus-state machinery.
struct SearchFieldView: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    final class FocusableSearchField: NSSearchField {
        var onFocusChange: ((Bool) -> Void)?

        override func becomeFirstResponder() -> Bool {
            let ok = super.becomeFirstResponder()
            if ok { onFocusChange?(true) }
            return ok
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = FocusableSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.textChanged(_:))
        context.coordinator.field = field
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
        field.placeholderString = placeholder
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchFieldView
        weak var field: NSSearchField?

        init(_ parent: SearchFieldView) {
            self.parent = parent
        }

        @objc func textChanged(_ sender: NSSearchField) {
            parent.text = sender.stringValue
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }
    }
}

enum Alert {
    /// Blocking confirmation; runs the action only on the destructive choice.
    static func confirmDestructive(messageText: String, informativeText: String, buttonTitle: String, action: @escaping () -> Void) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: buttonTitle)
        if alert.runModal() == .alertSecondButtonReturn {
            action()
        }
    }
}

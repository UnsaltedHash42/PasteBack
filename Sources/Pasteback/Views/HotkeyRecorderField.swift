import AppKit
import SwiftUI
import Carbon.HIToolbox
import PastebackCore

/// Records a global-shortcut key combination with a real key event,
/// no Accessibility permission involved.
struct HotkeyRecorderField: NSViewRepresentable {
    let current: Hotkey
    let onChange: (Hotkey) -> Void

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.update(current: current, recording: false)
        view.onRecord = { hotkey in onChange(hotkey) }
        return view
    }

    func updateNSView(_ view: RecorderView, context: Context) {
        view.update(current: current, recording: view.isRecording)
    }

    final class RecorderView: NSView {
        var onRecord: ((Hotkey) -> Void)?

        private let shortcutLabel = NSTextField(labelWithString: "")
        private let recordButton = NSButton(title: "Record", target: nil, action: #selector(toggleRecording))
        private let hintLabel = NSTextField(labelWithString: "")
        private(set) var isRecording = false
        private var current: Hotkey?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            setup()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setup()
        }

        private func setup() {
            shortcutLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
            shortcutLabel.alignment = .center
            shortcutLabel.wantsLayer = true
            shortcutLabel.layer?.cornerRadius = 5
            shortcutLabel.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
            shortcutLabel.layer?.masksToBounds = true

            recordButton.controlSize = .small
            recordButton.bezelStyle = .roundRect
            recordButton.target = self

            hintLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            hintLabel.textColor = .secondaryLabelColor

            addSubview(shortcutLabel)
            addSubview(recordButton)
            addSubview(hintLabel)
        }

        func update(current: Hotkey, recording: Bool) {
            self.current = current
            isRecording = recording
            shortcutLabel.stringValue = current.label
            recordButton.isHidden = recording
            hintLabel.stringValue = recording ? "Press shortcut…  (Esc to cancel)" : ""
            needsLayout = true
        }

        override var intrinsicContentSize: NSSize {
            layoutSize()
        }

        private func layoutSize() -> NSSize {
            NSSize(width: 320, height: max(24, shortcutLabel.fittingSize.height + 4))
        }

        override func layout() {
            super.layout()
            let height = bounds.height
            let labelWidth = max(56, shortcutLabel.attributedStringValue.size().width + 20)
            shortcutLabel.frame = NSRect(x: 0, y: (height - 20) / 2, width: labelWidth, height: 20)
            let buttonX = labelWidth + 8
            recordButton.frame = NSRect(x: buttonX, y: (height - 20) / 2, width: 70, height: 20)
            hintLabel.frame = NSRect(x: buttonX + 78, y: (height - 14) / 2, width: 200, height: 14)
        }

        override var acceptsFirstResponder: Bool { true }

        @objc private func toggleRecording() {
            setRecording(!isRecording)
        }

        private func setRecording(_ recording: Bool) {
            guard let current else { return }
            isRecording = recording
            update(current: current, recording: recording)
            if recording {
                window?.makeFirstResponder(self)
            }
        }

        override func keyDown(with event: NSEvent) {
            guard isRecording else {
                super.keyDown(with: event)
                return
            }
            if event.keyCode == UInt16(kVK_Escape) {
                setRecording(false)
                return
            }
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                hintLabel.stringValue = "Add ⌘, ⌥, ⌃ or ⇧"
                return
            }
            let hotkey = Hotkey(
                keyCode: UInt32(event.keyCode),
                modifiers: event.modifierFlags.pastebackCarbonFlags,
                label: Self.label(for: event)
            )
            setRecording(false)
            onRecord?(hotkey)
        }

        private static func label(for event: NSEvent) -> String {
            var symbols = ""
            let modifiers = event.modifierFlags
            if modifiers.contains(.control) { symbols += "⌃" }
            if modifiers.contains(.option) { symbols += "⌥" }
            if modifiers.contains(.shift) { symbols += "⇧" }
            if modifiers.contains(.command) { symbols += "⌘" }
            let characters = event.charactersIgnoringModifiers ?? ""
            let key = characters.uppercased()
            return symbols + (key.isEmpty ? "Key \(event.keyCode)" : key)
        }
    }
}

extension NSEvent.ModifierFlags {
    var pastebackCarbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= UInt32(cmdKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.control) { flags |= UInt32(controlKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }
}

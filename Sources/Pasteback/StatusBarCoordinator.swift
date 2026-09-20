import AppKit
import SwiftUI

/// Owns the menu bar status item and the popover panel.
///
/// Implemented with NSStatusItem + NSPopover rather than SwiftUI MenuBarExtra
/// because the global hotkey must open the panel programmatically, which
/// MenuBarExtra does not support.
final class StatusBarCoordinator {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()

    init<Content: View>(@ViewBuilder content: () -> Content) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: content())
        if let button = statusItem.button {
            button.image = MenuBarIcon.image()
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(StatusBarCoordinator.togglePanel)
        }
    }

    @objc func togglePanel() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            focusSearchField()
        }
    }

    func dismissPanel() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    private func focusSearchField() {
        DispatchQueue.main.async { [weak self] in
            guard let contentView = self?.popover.contentViewController?.view,
                  let window = contentView.window else { return }
            if let field = Self.findSearchField(in: contentView) {
                window.makeFirstResponder(field)
            }
        }
    }

    private static func findSearchField(in view: NSView) -> NSSearchField? {
        if let field = view as? NSSearchField {
            return field
        }
        for subview in view.subviews {
            if let found = findSearchField(in: subview) {
                return found
            }
        }
        return nil
    }
}

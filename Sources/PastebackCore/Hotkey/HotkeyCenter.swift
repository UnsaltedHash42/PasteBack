import Foundation
import Combine
import Carbon.HIToolbox

/// A global shortcut: Carbon virtual key code + Carbon modifier flags,
/// plus a display label captured at record time.
public struct Hotkey: Equatable, Codable, Sendable {
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let label: String

    public init(keyCode: UInt32, modifiers: UInt32, label: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.label = label
    }

    /// Control-Command-Shift-C
    public static func defaultHotkey() -> Hotkey {
        Hotkey(
            keyCode: UInt32(kVK_ANSI_C),
            modifiers: UInt32(cmdKey | shiftKey | controlKey),
            label: "⌃⇧⌘C"
        )
    }
}

public protocol HotkeyRegistering: AnyObject {
    @discardableResult
    func register(_ hotkey: Hotkey, id: UInt32, handler: @escaping () -> Void) -> Bool
    func unregister(id: UInt32)
}

/// Owns the active hotkey and reports registration status. Registration uses
/// two alternating slots so a new hotkey is registered before the old one is
/// released — a failed swap never leaves the user without a working hotkey.
public final class HotkeyCenter: ObservableObject {
    @Published public private(set) var isRegistered = false
    @Published public private(set) var activeHotkey: Hotkey?
    /// True when the most recent activation attempt failed; the previously
    /// active hotkey (if any) keeps working in that case.
    @Published public private(set) var registrationFailed = false

    public var onTrigger: (() -> Void)?

    private let registrar: HotkeyRegistering
    private let slotIDs: [UInt32] = [1, 2]
    private var nextSlot = 0
    private var activeID: UInt32?

    public init(registrar: HotkeyRegistering) {
        self.registrar = registrar
    }

    @discardableResult
    public func activate(_ hotkey: Hotkey) -> Bool {
        if activeHotkey == hotkey, activeID != nil {
            isRegistered = true
            registrationFailed = false
            return true
        }

        let id = slotIDs[nextSlot % slotIDs.count]
        nextSlot += 1
        let ok = registrar.register(hotkey, id: id) { [weak self] in
            self?.onTrigger?()
        }

        if ok {
            if let previous = activeID, previous != id {
                registrar.unregister(id: previous)
            }
            activeID = id
            activeHotkey = hotkey
            isRegistered = true
            registrationFailed = false
            AppLog.hotkey.info("Hotkey \(hotkey.label, privacy: .public) registered")
        } else {
            isRegistered = activeID != nil
            registrationFailed = true
            AppLog.hotkey.error(
                "Hotkey registration failed for \(hotkey.label, privacy: .public); keeping previous hotkey"
            )
        }
        return ok
    }

    public func deactivate() {
        if let id = activeID {
            registrar.unregister(id: id)
        }
        activeID = nil
        activeHotkey = nil
        isRegistered = false
        registrationFailed = false
    }
}

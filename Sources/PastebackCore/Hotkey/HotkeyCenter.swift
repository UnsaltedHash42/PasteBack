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

/// Owns the single active hotkey and reports registration status.
public final class HotkeyCenter: ObservableObject {
    @Published public private(set) var isRegistered = false
    @Published public private(set) var activeHotkey: Hotkey?

    public var onTrigger: (() -> Void)?

    private let registrar: HotkeyRegistering
    private let hotkeyID: UInt32 = 1
    private var activeID: UInt32?

    public init(registrar: HotkeyRegistering) {
        self.registrar = registrar
    }

    @discardableResult
    public func activate(_ hotkey: Hotkey) -> Bool {
        deactivate()
        let ok = registrar.register(hotkey, id: hotkeyID) { [weak self] in
            self?.onTrigger?()
        }
        isRegistered = ok
        if ok {
            activeHotkey = hotkey
            activeID = hotkeyID
        } else {
            AppLog.hotkey.error("Hotkey registration failed for \(hotkey.label, privacy: .public)")
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
    }
}

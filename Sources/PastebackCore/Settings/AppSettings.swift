import Foundation
import Combine

/// Expiration values are seconds; 0 means "never expire".
public protocol SettingsStoring: AnyObject {
    var maxItems: Int { get }
    var textExpiration: TimeInterval { get }
    var imageExpiration: TimeInterval { get }
    var fileExpiration: TimeInterval { get }
    var sensitiveExpiration: TimeInterval { get }
}

public final class AppSettings: ObservableObject, SettingsStoring {
    public static let defaultMaxItems = 20
    public static let defaultTextExpiration: TimeInterval = 60 * 60
    public static let defaultImageExpiration: TimeInterval = 24 * 60 * 60
    public static let defaultFileExpiration: TimeInterval = 24 * 60 * 60
    public static let defaultSensitiveExpiration: TimeInterval = 30

    private enum Key {
        static let launchAtLogin = "pasteback.launchAtLogin"
        static let hotkeyCode = "pasteback.hotkey.keyCode"
        static let hotkeyEnabled = "pasteback.hotkey.enabled"
        static let hotkeyModifiers = "pasteback.hotkey.modifiers"
        static let hotkeyLabel = "pasteback.hotkey.label"
        static let maxItems = "pasteback.maxItems"
        static let textExpiration = "pasteback.expiration.text"
        static let imageExpiration = "pasteback.expiration.image"
        static let fileExpiration = "pasteback.expiration.file"
        static let sensitiveExpiration = "pasteback.expiration.sensitive"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        let hotkey: Hotkey
        if defaults.object(forKey: Key.hotkeyCode) != nil {
            hotkey = Hotkey(
                keyCode: UInt32(clamping: defaults.integer(forKey: Key.hotkeyCode)),
                modifiers: UInt32(clamping: defaults.integer(forKey: Key.hotkeyModifiers)),
                label: defaults.string(forKey: Key.hotkeyLabel) ?? Hotkey.defaultHotkey().label
            )
        } else {
            hotkey = Hotkey.defaultHotkey()
        }
        let maxItems = defaults.object(forKey: Key.maxItems) as? Int ?? AppSettings.defaultMaxItems
        let text = defaults.object(forKey: Key.textExpiration) as? TimeInterval ?? AppSettings.defaultTextExpiration
        let image = defaults.object(forKey: Key.imageExpiration) as? TimeInterval ?? AppSettings.defaultImageExpiration
        let file = defaults.object(forKey: Key.fileExpiration) as? TimeInterval ?? AppSettings.defaultFileExpiration
        let sensitive = defaults.object(forKey: Key.sensitiveExpiration) as? TimeInterval ?? AppSettings.defaultSensitiveExpiration
        let hotkeyEnabled = defaults.object(forKey: Key.hotkeyEnabled) as? Bool ?? true

        self.launchAtLogin = launchAtLogin
        self.hotkey = hotkey
        self.hotkeyEnabled = hotkeyEnabled
        self.maxItems = maxItems
        self.textExpiration = text
        self.imageExpiration = image
        self.fileExpiration = file
        self.sensitiveExpiration = sensitive
    }

    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }

    @Published public var hotkey: Hotkey {
        didSet {
            defaults.set(Int(hotkey.keyCode), forKey: Key.hotkeyCode)
            defaults.set(Int(hotkey.modifiers), forKey: Key.hotkeyModifiers)
            defaults.set(hotkey.label, forKey: Key.hotkeyLabel)
        }
    }

    @Published public var hotkeyEnabled: Bool {
        didSet { defaults.set(hotkeyEnabled, forKey: Key.hotkeyEnabled) }
    }

    @Published public var maxItems: Int {
        didSet { defaults.set(maxItems, forKey: Key.maxItems) }
    }

    @Published public var textExpiration: TimeInterval {
        didSet { defaults.set(textExpiration, forKey: Key.textExpiration) }
    }

    @Published public var imageExpiration: TimeInterval {
        didSet { defaults.set(imageExpiration, forKey: Key.imageExpiration) }
    }

    @Published public var fileExpiration: TimeInterval {
        didSet { defaults.set(fileExpiration, forKey: Key.fileExpiration) }
    }

    @Published public var sensitiveExpiration: TimeInterval {
        didSet { defaults.set(sensitiveExpiration, forKey: Key.sensitiveExpiration) }
    }
}

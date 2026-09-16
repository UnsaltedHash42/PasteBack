import Foundation
import Combine
import PastebackCore

final class SettingsViewModel: ObservableObject {
    @Published var loginItemMessage: String?

    private let loginItem: LoginItemRegistering

    init(loginItem: LoginItemRegistering) {
        self.loginItem = loginItem
    }

    /// Applies the launch-at-login toggle to SMAppService, reverting the
    /// setting and surfacing a message when registration is not possible
    /// (e.g. running a bare binary instead of Pasteback.app).
    func setLaunchAtLogin(_ enabled: Bool, on settings: AppSettings) {
        do {
            if enabled {
                try loginItem.register()
            } else {
                try loginItem.unregister()
            }
            loginItemMessage = nil
        } catch {
            settings.launchAtLogin = loginItem.isRegistered
            loginItemMessage = "Launch at login requires running from Pasteback.app."
        }
    }
}

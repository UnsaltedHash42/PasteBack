import SwiftUI
import PastebackCore

private struct ExpirationOption: Identifiable {
    let value: TimeInterval
    let label: String
    var id: TimeInterval { value }
}

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var model: SettingsViewModel
    @ObservedObject var hotkeyCenter: HotkeyCenter

    let storageFolder: URL
    let onClearAll: () -> Void
    let onCheckForUpdates: () -> Void

    private static let expirations: [ExpirationOption] = [
        ExpirationOption(value: 10 * 60, label: "10 Minutes"),
        ExpirationOption(value: 60 * 60, label: "1 Hour"),
        ExpirationOption(value: 6 * 60 * 60, label: "6 Hours"),
        ExpirationOption(value: 12 * 60 * 60, label: "12 Hours"),
        ExpirationOption(value: 24 * 60 * 60, label: "1 Day"),
        ExpirationOption(value: 7 * 24 * 60 * 60, label: "7 Days"),
        ExpirationOption(value: 0, label: "Never"),
    ]

    private static let sensitiveOptions: [ExpirationOption] = [
        ExpirationOption(value: 10, label: "10 Seconds"),
        ExpirationOption(value: 30, label: "30 Seconds"),
        ExpirationOption(value: 60, label: "1 Minute"),
        ExpirationOption(value: 5 * 60, label: "5 Minutes"),
        ExpirationOption(value: 60 * 60, label: "1 Hour"),
    ]

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _, enabled in
                        model.setLaunchAtLogin(enabled, on: settings)
                    }
                if let message = model.loginItemMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Picker("Maximum stored items", selection: $settings.maxItems) {
                    ForEach([10, 20, 50, 100], id: \.self) { Text("\($0)") }
                }
            }

            Section("Global Hotkey") {
                Toggle("Enable global hotkey", isOn: $settings.hotkeyEnabled)
                if settings.hotkeyEnabled {
                    HotkeyRecorderField(current: settings.hotkey) { settings.hotkey = $0 }
                    if hotkeyCenter.registrationFailed {
                        Label("Shortcut unavailable — previous hotkey kept", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if hotkeyCenter.isRegistered {
                        Label("Hotkey active", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("Shortcut unavailable — choose another combination", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("Expiration") {
                Picker("Text", selection: $settings.textExpiration) {
                    ForEach(Self.expirations) { Text($0.label).tag($0.value) }
                }
                Picker("Images", selection: $settings.imageExpiration) {
                    ForEach(Self.expirations) { Text($0.label).tag($0.value) }
                }
                Picker("File references", selection: $settings.fileExpiration) {
                    ForEach(Self.expirations) { Text($0.label).tag($0.value) }
                }
                Picker("Sensitive items", selection: $settings.sensitiveExpiration) {
                    ForEach(Self.sensitiveOptions) { Text($0.label).tag($0.value) }
                }
                Text("Likely secrets — tokens, API keys, card numbers — are removed after the sensitive interval.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Storage & Updates") {
                Button("Open Storage Folder") {
                    NSWorkspace.shared.open(storageFolder)
                }
                Button("Check for Updates…") {
                    onCheckForUpdates()
                }
                Button("Clear All Items", role: .destructive) {
                    Alert.confirmDestructive(
                        messageText: "Clear all clipboard items?",
                        informativeText: "Pinned items are also removed.",
                        buttonTitle: "Clear All"
                    ) {
                        onClearAll()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 470, minHeight: 540)
    }
}

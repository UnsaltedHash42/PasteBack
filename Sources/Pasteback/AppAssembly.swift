import AppKit
import Combine
import Sparkle
import PastebackCore

/// Composition root: builds services and wires them to the UI.
final class AppAssembly {
    private let settings: AppSettings
    private let history: ClipboardHistory
    private let pasteboard: SystemPasteboard
    private let monitor: ClipboardMonitor
    private let retention: RetentionService
    private let hotkeyCenter: HotkeyCenter
    private let loginItem: SMLoginItem
    private let updaterController: SPUStandardUpdaterController
    private let storeDirectory: URL
    private let ipcServer: ClipboardIpcServer

    private var statusBar: StatusBarCoordinator?
    private var settingsWindow: SettingsWindowController?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        settings = AppSettings()
        loginItem = SMLoginItem()

        let storeURL = EncryptedHistoryStore.defaultURL()
        storeDirectory = storeURL.deletingLastPathComponent()
        do {
            let crypto = try AESGCMEncryptionService(keychain: SystemKeychain())
            let store = EncryptedHistoryStore(url: storeURL, crypto: crypto, files: DiskFileStore())
            history = ClipboardHistory(store: store, settings: settings, dates: SystemDateProvider())
        } catch {
            AppLog.crypto.error("Keychain unavailable (\(String(describing: error))); history will not be persisted")
            history = ClipboardHistory(store: InMemoryHistoryStore(), settings: settings, dates: SystemDateProvider())
        }

        pasteboard = SystemPasteboard()
        monitor = ClipboardMonitor(pasteboard: pasteboard)
        retention = RetentionService(history: history, dates: SystemDateProvider())
        hotkeyCenter = HotkeyCenter(registrar: CarbonHotkeyRegistrar())
        ipcServer = ClipboardIpcServer(history: history)
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func start() {
        monitor.onCapture = { [weak history] content in
            history?.capture(content)
        }

        let viewModel = HistoryViewModel(history: history, pasteboard: pasteboard)
        viewModel.onDismiss = { [weak self] in self?.statusBar?.dismissPanel() }
        viewModel.onOpenSettings = { [weak self] in self?.showSettings() }
        viewModel.onQuit = { NSApp.terminate(nil) }

        statusBar = StatusBarCoordinator {
            PanelView()
                .environmentObject(viewModel)
        }

        hotkeyCenter.onTrigger = { [weak self] in
            self?.statusBar?.togglePanel()
        }
        if settings.hotkeyEnabled {
            hotkeyCenter.activate(settings.hotkey)
        }

        settings.$hotkey
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] hotkey in
                guard let self, self.settings.hotkeyEnabled else { return }
                _ = self.hotkeyCenter.activate(hotkey)
            }
            .store(in: &cancellables)

        settings.$hotkeyEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    _ = self.hotkeyCenter.activate(self.settings.hotkey)
                } else {
                    self.hotkeyCenter.deactivate()
                }
            }
            .store(in: &cancellables)

        settings.$maxItems
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.history.applySettings()
            }
            .store(in: &cancellables)

        monitor.start()
        retention.start()
        ipcServer.start()
    }

    private func showSettings() {
        if settingsWindow == nil {
            let hotkey = hotkeyCenter
            let loginItem = self.loginItem
            let folder = storeDirectory
            let history = self.history
            let updater = updaterController
            let settingsModel = SettingsViewModel(loginItem: loginItem)
            settingsWindow = SettingsWindowController {
                SettingsView(
                    model: settingsModel,
                    hotkeyCenter: hotkey,
                    storageFolder: folder,
                    onClearAll: { history.clearAll() },
                    onCheckForUpdates: { updater.checkForUpdates(nil) }
                )
                .environmentObject(self.settings)
            }
        }
        settingsWindow?.show()
    }
}

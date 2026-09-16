import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var assembly: AppAssembly?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        assembly = AppAssembly()
        assembly?.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

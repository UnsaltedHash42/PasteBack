import Foundation

/// Polls the pasteboard change count. Polling is the standard approach for
/// clipboard monitoring on macOS and needs no special permissions.
public final class ClipboardMonitor {
    public static let defaultPollInterval: TimeInterval = 0.35

    public var pollInterval: TimeInterval = ClipboardMonitor.defaultPollInterval
    public var onCapture: ((CapturedContent) -> Void)?

    public private(set) var isRunning = false

    private let pasteboard: Pasteboarding
    private var timer: Timer?
    /// `Int.min` so the content already on the pasteboard at start is captured
    /// exactly once on the first check.
    private var lastCount = Int.min

    public init(pasteboard: Pasteboarding) {
        self.pasteboard = pasteboard
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        checkForChanges()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    public func checkForChanges() {
        let count = pasteboard.changeCount
        guard count != lastCount else { return }
        lastCount = count
        guard !pasteboard.isSelfWrite(changeCount: count) else { return }
        guard let content = pasteboard.capture() else {
            AppLog.pasteboard.info("Ignored unsupported pasteboard content")
            return
        }
        onCapture?(content)
    }
}

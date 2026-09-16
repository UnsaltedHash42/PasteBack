import Foundation

/// Periodically sweeps expired items.
public final class RetentionService {
    public static let defaultSweepInterval: TimeInterval = 30

    public var sweepInterval: TimeInterval = RetentionService.defaultSweepInterval
    public private(set) var isRunning = false

    private let history: ClipboardHistory
    private let dates: DateProviding
    private var timer: Timer?

    public init(history: ClipboardHistory, dates: DateProviding) {
        self.history = history
        self.dates = dates
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        sweep()
        let timer = Timer(timeInterval: sweepInterval, repeats: true) { [weak self] _ in
            self?.sweep()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    public func sweep() {
        if history.removeExpired(now: dates.now) {
            AppLog.retention.info("Expired items removed")
        }
    }
}

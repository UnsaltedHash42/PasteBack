import Foundation

/// Injectable clock so retention and capture logic can be tested deterministically.
public protocol DateProviding: AnyObject {
    var now: Date { get }
}

public final class SystemDateProvider: DateProviding {
    public init() {}
    public var now: Date { Date() }
}

public final class ManualDateProvider: DateProviding {
    public var now: Date

    public init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.now = now
    }

    public func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}

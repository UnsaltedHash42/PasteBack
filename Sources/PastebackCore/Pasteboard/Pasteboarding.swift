import Foundation

/// Abstraction over the system pasteboard so capture/restore logic is testable.
public protocol Pasteboarding: AnyObject {
    var changeCount: Int { get }
    /// True when the given change count was produced by our own `write`.
    func isSelfWrite(changeCount: Int) -> Bool
    /// Classifies current pasteboard content. Nil when nothing supported is present.
    func capture() -> CapturedContent?
    /// Writes a payload back to the pasteboard (restore).
    func write(_ payload: ItemPayload)
}

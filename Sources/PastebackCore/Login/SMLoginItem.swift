import Foundation
import ServiceManagement

public protocol LoginItemRegistering: AnyObject {
    func register() throws
    func unregister() throws
    var isRegistered: Bool { get }
}

/// SMAppService-based launch-at-login. Requires the app to run from a bundle;
/// a bare `swift run` binary cannot register and will throw.
public final class SMLoginItem: LoginItemRegistering {
    private let service: SMAppService

    public init() {
        service = .mainApp
    }

    public func register() throws {
        try service.register()
    }

    public func unregister() throws {
        try service.unregister()
    }

    public var isRegistered: Bool {
        service.status == .enabled
    }
}

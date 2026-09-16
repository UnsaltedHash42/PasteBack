import Foundation
import os

public enum AppLog {
    private static let subsystem = "com.pasteback.app"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let pasteboard = Logger(subsystem: subsystem, category: "pasteboard")
    public static let storage = Logger(subsystem: subsystem, category: "storage")
    public static let crypto = Logger(subsystem: subsystem, category: "crypto")
    public static let retention = Logger(subsystem: subsystem, category: "retention")
    public static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    public static let loginItem = Logger(subsystem: subsystem, category: "login-item")
}

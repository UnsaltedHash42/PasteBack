import Foundation
import Network

/// Local IPC endpoint shared by the app and the CLI. The CLI never reads the
/// encrypted store or the Keychain; it asks the running app over this socket.
public enum ClipboardIpc {
    public static func socketURL() -> URL {
        EncryptedHistoryStore.defaultURL().deletingLastPathComponent()
            .appendingPathComponent("ipc.sock")
    }
}

public struct IpcRequest: Codable {
    public enum Action: String, Codable {
        case list
        case get
    }

    public let action: Action
    public var count: Int?
    public var index: Int?

    public init(action: Action, count: Int? = nil, index: Int? = nil) {
        self.action = action
        self.count = count
        self.index = index
    }
}

public struct IpcListEntry: Codable {
    public let index: Int
    public let kind: String
    public let preview: String
    public let createdAt: Date
    public let isPinned: Bool

    public init(index: Int, kind: String, preview: String, createdAt: Date, isPinned: Bool) {
        self.index = index
        self.kind = kind
        self.preview = preview
        self.createdAt = createdAt
        self.isPinned = isPinned
    }
}

public struct IpcItemList: Codable {
    public let items: [IpcListEntry]

    public init(items: [IpcListEntry]) {
        self.items = items
    }
}

public struct IpcItemContent: Codable {
    public let kind: String
    public var text: String?
    public var imageData: Data?
    public var imageFormat: String?
    public var files: [String]?

    public init(kind: String, text: String? = nil, imageData: Data? = nil, imageFormat: String? = nil, files: [String]? = nil) {
        self.kind = kind
        self.text = text
        self.imageData = imageData
        self.imageFormat = imageFormat
        self.files = files
    }
}

public struct IpcResponse: Codable {
    public let ok: Bool
    public var items: [IpcListEntry]?
    public var content: IpcItemContent?
    public var error: String?

    public static func list(_ entries: [IpcListEntry]) -> IpcResponse {
        IpcResponse(ok: true, items: entries, content: nil, error: nil)
    }

    public static func content(_ content: IpcItemContent) -> IpcResponse {
        IpcResponse(ok: true, items: nil, content: content, error: nil)
    }

    public static func failure(_ message: String) -> IpcResponse {
        IpcResponse(ok: false, items: nil, content: nil, error: message)
    }
}

enum IpcJson {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

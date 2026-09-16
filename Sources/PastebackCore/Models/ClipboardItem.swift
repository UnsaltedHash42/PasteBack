import Foundation

public enum ItemKind: String, Codable, CaseIterable, Sendable {
    case text
    case url
    case image
    case file

    public var label: String {
        switch self {
        case .text: return "Text"
        case .url: return "Link"
        case .image: return "Image"
        case .file: return "File"
        }
    }
}

public enum ImageFormat: String, Codable, Sendable {
    case png
    case tiff
}

/// The full clipboard content captured for one item. Everything needed to
/// restore the item later; `preview` is the human-readable summary.
public enum ItemPayload: Equatable, Sendable {
    case text(String)
    case url(String)
    case image(data: Data, format: ImageFormat)
    case files([String])
}

public struct CapturedContent: Equatable, Sendable {
    public let kind: ItemKind
    public let preview: String
    public let payload: ItemPayload

    public init(kind: ItemKind, preview: String, payload: ItemPayload) {
        self.kind = kind
        self.preview = preview
        self.payload = payload
    }
}

public struct ClipboardItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    /// Ignored while `isPinned` is true.
    public var expiresAt: Date
    public var isPinned: Bool
    public let kind: ItemKind
    public let preview: String
    public let payload: ItemPayload

    public init(
        id: UUID = UUID(),
        createdAt: Date,
        expiresAt: Date,
        isPinned: Bool = false,
        kind: ItemKind,
        preview: String,
        payload: ItemPayload
    ) {
        self.id = id
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.isPinned = isPinned
        self.kind = kind
        self.preview = preview
        self.payload = payload
    }
}

extension ItemPayload: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, text, url, imageData, imageFormat, files
    }

    private enum KindTag: String, Codable {
        case text, url, image, files
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(KindTag.self, forKey: .kind) {
        case .text:
            self = .text(try container.decode(String.self, forKey: .text))
        case .url:
            self = .url(try container.decode(String.self, forKey: .url))
        case .image:
            self = .image(
                data: try container.decode(Data.self, forKey: .imageData),
                format: try container.decode(ImageFormat.self, forKey: .imageFormat)
            )
        case .files:
            self = .files(try container.decode([String].self, forKey: .files))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let string):
            try container.encode(KindTag.text, forKey: .kind)
            try container.encode(string, forKey: .text)
        case .url(let string):
            try container.encode(KindTag.url, forKey: .kind)
            try container.encode(string, forKey: .url)
        case .image(let data, let format):
            try container.encode(KindTag.image, forKey: .kind)
            try container.encode(data, forKey: .imageData)
            try container.encode(format, forKey: .imageFormat)
        case .files(let paths):
            try container.encode(KindTag.files, forKey: .kind)
            try container.encode(paths, forKey: .files)
        }
    }
}

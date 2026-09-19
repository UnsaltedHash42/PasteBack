import Foundation

/// Pure output formatting for the CLI, kept in Core so it is tested.
public enum CliFormat {
    public static func listText(_ list: IpcItemList, now: Date = Date()) -> String {
        guard !list.items.isEmpty else { return "" }
        let formatter = RelativeDateTimeFormatter()
        let indexWidth = String(list.items.count - 1).count
        var lines: [String] = []
        for entry in list.items {
            let pin = entry.isPinned ? "*" : " "
            let index = String(entry.index).leftPad(toWidth: indexWidth)
            let kind = kindLabel(entry.kind).leftPad(toWidth: 5)
            let time = formatter.localizedString(for: entry.createdAt, relativeTo: now)
            let preview = truncate(entry.preview, to: 60)
            lines.append("\(index)\(pin) \(kind) \(time)  \(preview)")
        }
        return lines.joined(separator: "\n")
    }

    public static func listJson(_ list: IpcItemList) -> String {
        guard let data = try? IpcJson.encoder.encode(list) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    /// stdout bytes for `get`: exact text, paths one per line, or raw image data.
    public static func contentBytes(_ content: IpcItemContent) -> Data? {
        if let text = content.text {
            return Data(text.utf8)
        }
        if let files = content.files {
            return Data(files.joined(separator: "\n").utf8)
        }
        return content.imageData
    }

    private static func kindLabel(_ raw: String) -> String {
        switch raw {
        case "text": return "Text"
        case "url": return "Link"
        case "image": return "Image"
        case "file": return "File"
        default: return raw
        }
    }

    private static func truncate(_ text: String, to limit: Int) -> String {
        text.count <= limit ? text : "\(text.prefix(limit))…"
    }
}

extension String {
    fileprivate func leftPad(toWidth width: Int) -> String {
        let padding = max(0, width - count)
        return String(repeating: " ", count: padding) + self
    }
}

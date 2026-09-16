import AppKit

public enum CaptureLimits {
    public static let maxImageBytes = 10 * 1024 * 1024
    public static let maxTextBytes = 1024 * 1024
    public static let previewLength = 120
}

public final class SystemPasteboard: Pasteboarding {
    private let nsPasteboard: NSPasteboard
    private var selfWriteCount = Int.min

    public init(nsPasteboard: NSPasteboard = .general) {
        self.nsPasteboard = nsPasteboard
    }

    public var changeCount: Int { nsPasteboard.changeCount }

    public func isSelfWrite(changeCount: Int) -> Bool {
        changeCount == selfWriteCount
    }

    public func capture() -> CapturedContent? {
        PasteboardReader.read(from: nsPasteboard)
    }

    public func write(_ payload: ItemPayload) {
        nsPasteboard.clearContents()
        switch payload {
        case .text(let string):
            nsPasteboard.setString(string, forType: .string)
        case .url(let string):
            nsPasteboard.declareTypes([.URL, .string], owner: nil)
            nsPasteboard.setString(string, forType: .URL)
            nsPasteboard.setString(string, forType: .string)
        case .image(let data, let format):
            nsPasteboard.setData(data, forType: format == .png ? .png : .tiff)
        case .files(let paths):
            let urls = paths.compactMap { URL(fileURLWithPath: $0) as NSURL }
            if !urls.isEmpty {
                nsPasteboard.writeObjects(urls)
            }
        }
        selfWriteCount = nsPasteboard.changeCount
    }
}

enum PasteboardReader {
    static func read(from pb: NSPasteboard) -> CapturedContent? {
        let types = pb.types ?? []

        if let files = readFileReferences(from: pb, types: types) {
            return files
        }
        if let image = readImage(from: pb, types: types) {
            return image
        }
        if let url = readURL(from: pb, types: types) {
            return url
        }
        if let text = readText(from: pb, types: types) {
            return text
        }
        return nil
    }

    private static func readFileReferences(from pb: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> CapturedContent? {
        guard types.contains(.fileURL),
              let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !urls.isEmpty else {
            return nil
        }
        let paths = urls.map(\.path)
        let preview: String
        if paths.count == 1 {
            let name = urls[0].lastPathComponent
            preview = name.isEmpty ? paths[0] : name
        } else {
            preview = "\(urls[0].lastPathComponent) + \(paths.count - 1) more"
        }
        return CapturedContent(kind: .file, preview: preview, payload: .files(paths))
    }

    private static func readImage(from pb: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> CapturedContent? {
        let format: ImageFormat
        let type: NSPasteboard.PasteboardType
        if types.contains(.png) {
            format = .png
            type = .png
        } else if types.contains(.tiff) {
            format = .tiff
            type = .tiff
        } else {
            return nil
        }
        guard let data = pb.data(forType: type), !data.isEmpty,
              data.count <= CaptureLimits.maxImageBytes else {
            return nil
        }
        let dimensions: String
        if let rep = NSBitmapImageRep(data: data), rep.pixelsWide > 0, rep.pixelsHigh > 0 {
            dimensions = " · \(rep.pixelsWide)×\(rep.pixelsHigh)"
        } else {
            dimensions = ""
        }
        return CapturedContent(kind: .image, preview: "Image\(dimensions)", payload: .image(data: data, format: format))
    }

    private static func readURL(from pb: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> CapturedContent? {
        guard types.contains(.URL),
              let urls = pb.readObjects(forClasses: [NSURL.self], options: [:]) as? [URL],
              let url = urls.first(where: { !$0.isFileURL }) else {
            return nil
        }
        let string = url.absoluteString
        return CapturedContent(kind: .url, preview: previewText(from: string), payload: .url(string))
    }

    private static func readText(from pb: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> CapturedContent? {
        var string = pb.string(forType: .string)
        if (string ?? "").isEmpty, types.contains(.rtf), let data = pb.data(forType: .rtf),
           let attributed = NSAttributedString(rtf: data, documentAttributes: nil) {
            string = attributed.string
        }
        guard let text = string, !text.isEmpty, text.utf8.count <= CaptureLimits.maxTextBytes else {
            return nil
        }
        return CapturedContent(kind: .text, preview: previewText(from: text), payload: .text(text))
    }

    public static func previewText(from text: String) -> String {
        let singleSpaced = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        if singleSpaced.count > CaptureLimits.previewLength {
            let prefix = singleSpaced.prefix(CaptureLimits.previewLength)
            return "\(prefix)…"
        }
        return singleSpaced
    }
}

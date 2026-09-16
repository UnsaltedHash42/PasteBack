import AppKit
import Foundation
import PastebackCore

final class FakePasteboard: Pasteboarding {
    var storedContent: CapturedContent?
    var count = 0
    var lastWritten: ItemPayload?
    private var selfWriteCount = Int.min

    var changeCount: Int { count }

    func isSelfWrite(changeCount: Int) -> Bool {
        changeCount == selfWriteCount
    }

    func capture() -> CapturedContent? {
        storedContent
    }

    func write(_ payload: ItemPayload) {
        lastWritten = payload
        storedContent = FakePasteboard.content(for: payload)
        count += 1
        selfWriteCount = count
    }

    func simulateExternalCopy(_ content: CapturedContent?) {
        storedContent = content
        count += 1
    }

    private static func content(for payload: ItemPayload) -> CapturedContent {
        switch payload {
        case .text(let string):
            return CapturedContent(kind: .text, preview: String(string.prefix(40)), payload: payload)
        case .url(let string):
            return CapturedContent(kind: .url, preview: string, payload: payload)
        case .image:
            return CapturedContent(kind: .image, preview: "Image", payload: payload)
        case .files(let paths):
            let name = (paths.first as NSString?)?.lastPathComponent ?? "File"
            return CapturedContent(kind: .file, preview: name, payload: payload)
        }
    }
}

final class InMemoryKeychain: KeychainStoring {
    var storage: [String: Data] = [:]

    private func key(_ service: String, _ account: String) -> String {
        "\(service)|\(account)"
    }

    func readData(service: String, account: String) throws -> Data? {
        storage[key(service, account)]
    }

    func setData(_ data: Data, service: String, account: String) throws {
        storage[key(service, account)] = data
    }

    func deleteData(service: String, account: String) throws {
        storage.removeValue(forKey: key(service, account))
    }
}

final class InMemoryFileStore: DataFileStoring {
    var files: [URL: Data] = [:]
    var writeCount = 0

    func read(at url: URL) throws -> Data {
        guard let data = files[url] else {
            throw CocoaError(.fileNoSuchFile)
        }
        return data
    }

    func write(_ data: Data, to url: URL) throws {
        writeCount += 1
        files[url] = data
    }

    func remove(at url: URL) throws {
        files.removeValue(forKey: url)
    }
}

final class FixedSettings: SettingsStoring {
    var maxItems = 20
    var textExpiration: TimeInterval = 3600
    var imageExpiration: TimeInterval = 86400
    var fileExpiration: TimeInterval = 86400
    var sensitiveExpiration: TimeInterval = 30
}

enum TestFixtures {
    static func text(_ string: String) -> CapturedContent {
        CapturedContent(kind: .text, preview: String(string.prefix(120)), payload: .text(string))
    }

    static func url(_ string: String) -> CapturedContent {
        CapturedContent(kind: .url, preview: string, payload: .url(string))
    }

    static func imageFixture() -> CapturedContent {
        CapturedContent(kind: .image, preview: "Image · 2×2", payload: .image(data: pngData(), format: .png))
    }

    static func files(_ paths: [String]) -> CapturedContent {
        let preview = paths.count == 1
            ? (paths[0] as NSString).lastPathComponent
            : "\((paths[0] as NSString).lastPathComponent) + \(paths.count - 1) more"
        return CapturedContent(kind: .file, preview: preview, payload: .files(paths))
    }

    static func pngData() -> Data {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 2, height: 2)).fill()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            preconditionFailure("Could not create fixture PNG")
        }
        return png
    }
}

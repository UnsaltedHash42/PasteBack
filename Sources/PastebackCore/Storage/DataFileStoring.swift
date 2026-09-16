import Foundation

public protocol DataFileStoring: AnyObject {
    func read(at url: URL) throws -> Data
    func write(_ data: Data, to url: URL) throws
    func remove(at url: URL) throws
}

public final class DiskFileStore: DataFileStoring {
    public init() {}

    public func read(at url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    public func remove(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

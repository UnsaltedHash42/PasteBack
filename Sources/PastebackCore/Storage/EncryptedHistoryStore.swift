import Foundation

public protocol HistoryPersisting: AnyObject {
    func load() throws -> [ClipboardItem]
    func save(_ items: [ClipboardItem]) throws
    func wipe() throws
}

public enum HistoryStoreError: Error {
    case unreadableStore
}

/// Persists the whole history as one AES-GCM-encrypted JSON file:
/// `PBST` magic + 1-byte version + sealed box (ciphertext || GCM tag).
public final class EncryptedHistoryStore: HistoryPersisting {
    private static let magic = Data("PBST".utf8)
    private static let version: UInt8 = 1

    private let url: URL
    private let crypto: EncryptionServicing
    private let files: DataFileStoring

    public init(url: URL, crypto: EncryptionServicing, files: DataFileStoring) {
        self.url = url
        self.crypto = crypto
        self.files = files
    }

    public static func defaultURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Pasteback", isDirectory: true)
            .appendingPathComponent("History.store")
    }

    public func load() throws -> [ClipboardItem] {
        let raw: Data
        do {
            raw = try files.read(at: url)
        } catch {
            return []
        }
        guard raw.count > 5, raw.prefix(4) == EncryptedHistoryStore.magic,
              raw[4] == EncryptedHistoryStore.version else {
            throw HistoryStoreError.unreadableStore
        }
        let plain = try crypto.decrypt(Data(raw.dropFirst(5)))
        return try JSONDecoder().decode([ClipboardItem].self, from: plain)
    }

    public func save(_ items: [ClipboardItem]) throws {
        let plain = try JSONEncoder().encode(items)
        let cipher = try crypto.encrypt(plain)
        try files.write(EncryptedHistoryStore.magic
            + Data([EncryptedHistoryStore.version])
            + cipher, to: url)
    }

    public func wipe() throws {
        try files.remove(at: url)
    }
}

/// Session-only fallback used when the Keychain is unavailable: history works
/// but nothing is written to disk.
public final class InMemoryHistoryStore: HistoryPersisting {
    private var items: [ClipboardItem] = []
    private let lock = NSLock()

    public init() {}

    public func load() throws -> [ClipboardItem] {
        lock.lock(); defer { lock.unlock() }
        return items
    }

    public func save(_ items: [ClipboardItem]) throws {
        lock.lock(); defer { lock.unlock() }
        self.items = items
    }

    public func wipe() throws {
        lock.lock(); defer { lock.unlock() }
        items = []
    }
}

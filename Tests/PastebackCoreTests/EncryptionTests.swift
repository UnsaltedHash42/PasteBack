import CryptoKit
import Foundation
import Testing
import PastebackCore

@Suite("Encryption")
struct EncryptionTests {
    private let files = InMemoryFileStore()
    private let storeURL = URL(fileURLWithPath: "/tmp/PastebackTests/Encryption.store")

    private func item(_ text: String) -> ClipboardItem {
        ClipboardItem(
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            expiresAt: .distantFuture,
            kind: .text,
            preview: text,
            payload: .text(text)
        )
    }

    @Test func storedPayloadIsEncryptedOnDisk() throws {
        let keychain = InMemoryKeychain()
        let crypto = try AESGCMEncryptionService(keychain: keychain)
        let store = EncryptedHistoryStore(url: storeURL, crypto: crypto, files: files)

        try store.save([item("topsecret-pasteback-payload")])

        let raw = try #require(files.files[storeURL])
        #expect(raw.prefix(4) == Data("PBST".utf8))
        #expect(!raw.contains(Data("topsecret-pasteback-payload".utf8)))
    }

    @Test func payloadDecryptsWithCorrectKey() throws {
        let keychain = InMemoryKeychain()
        let crypto = try AESGCMEncryptionService(keychain: keychain)
        let store = EncryptedHistoryStore(url: storeURL, crypto: crypto, files: files)
        try store.save([item("round trip secret")])

        let loaded = try EncryptedHistoryStore(url: storeURL, crypto: crypto, files: files).load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.payload == .text("round trip secret"))
    }

    @Test func decryptionFailsWithWrongKey() throws {
        let rightCrypto = AESGCMEncryptionService(key: SymmetricKey(size: .bits256))
        let store = EncryptedHistoryStore(url: storeURL, crypto: rightCrypto, files: files)
        try store.save([item("wrong key secret")])

        let wrongCrypto = AESGCMEncryptionService(key: SymmetricKey(size: .bits256))
        #expect(throws: EncryptionError.self) {
            _ = try EncryptedHistoryStore(url: storeURL, crypto: wrongCrypto, files: files).load()
        }
    }

    @Test func keyIsStoredInKeychain() throws {
        let keychain = InMemoryKeychain()
        _ = try AESGCMEncryptionService(keychain: keychain)

        let keyData = try #require(
            try keychain.readData(
                service: AESGCMEncryptionService.keychainService,
                account: AESGCMEncryptionService.keychainAccount
            )
        )
        #expect(keyData.count == AESGCMEncryptionService.keyByteLength)

        // Same key is reused on next init.
        let again = try AESGCMEncryptionService(keychain: keychain)
        let first = try AESGCMEncryptionService(keychain: keychain)
        let plain = Data("identity check".utf8)
        #expect(try again.decrypt(try first.encrypt(plain)) == plain)
    }

    @Test func corruptStoreHeaderIsRejected() throws {
        files.files[storeURL] = Data("not a pasteback store at all".utf8)
        let crypto = AESGCMEncryptionService(key: SymmetricKey(size: .bits256))
        #expect(throws: HistoryStoreError.self) {
            _ = try EncryptedHistoryStore(url: storeURL, crypto: crypto, files: files).load()
        }
    }

    @Test func systemKeychainRoundTrip() throws {
        let keychain = SystemKeychain()
        let service = "com.pasteback.tests.\(UUID().uuidString)"
        defer { try? keychain.deleteData(service: service, account: "test") }

        let payload = Data("keychain round trip".utf8)
        try keychain.setData(payload, service: service, account: "test")
        #expect(try keychain.readData(service: service, account: "test") == payload)

        try keychain.setData(Data("updated".utf8), service: service, account: "test")
        #expect(try keychain.readData(service: service, account: "test") == Data("updated".utf8))

        try keychain.deleteData(service: service, account: "test")
        #expect(try keychain.readData(service: service, account: "test") == nil)
    }
}

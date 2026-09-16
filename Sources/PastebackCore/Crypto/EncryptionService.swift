import Foundation
import CryptoKit

public enum EncryptionError: Error {
    case sealFailed
    case openFailed
}

public protocol EncryptionServicing {
    func encrypt(_ plaintext: Data) throws -> Data
    func decrypt(_ ciphertext: Data) throws -> Data
}

/// AES-256-GCM (authenticated). The key is created once and stored in the
/// Keychain; payloads are never written to disk without this encryption.
public final class AESGCMEncryptionService: EncryptionServicing {
    public static let keychainService = "com.pasteback.encryption"
    public static let keychainAccount = "history-key"
    public static let keyByteLength = 32

    private let key: SymmetricKey

    public convenience init(
        keychain: KeychainStoring,
        service: String = AESGCMEncryptionService.keychainService,
        account: String = AESGCMEncryptionService.keychainAccount
    ) throws {
        if let data = try keychain.readData(service: service, account: account) {
            guard data.count == AESGCMEncryptionService.keyByteLength else {
                throw EncryptionError.openFailed
            }
            self.init(key: SymmetricKey(data: data))
            return
        }
        let fresh = SymmetricKey(size: .bits256)
        try keychain.setData(
            fresh.withUnsafeBytes { Data($0) },
            service: service,
            account: account
        )
        self.init(key: fresh)
    }

    public init(key: SymmetricKey) {
        self.key = key
    }

    public func encrypt(_ plaintext: Data) throws -> Data {
        guard let sealed = try? AES.GCM.seal(plaintext, using: key).combined else {
            throw EncryptionError.sealFailed
        }
        return sealed
    }

    public func decrypt(_ ciphertext: Data) throws -> Data {
        let box: AES.GCM.SealedBox
        let plain: Data
        do {
            box = try AES.GCM.SealedBox(combined: ciphertext)
            plain = try AES.GCM.open(box, using: key)
        } catch {
            throw EncryptionError.openFailed
        }
        return plain
    }
}

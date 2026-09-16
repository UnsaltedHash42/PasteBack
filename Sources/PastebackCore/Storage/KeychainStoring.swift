import Foundation
import Security

public enum KeychainError: Error {
    case unhandled(OSStatus)
}

public protocol KeychainStoring: AnyObject {
    func readData(service: String, account: String) throws -> Data?
    func setData(_ data: Data, service: String, account: String) throws
    func deleteData(service: String, account: String) throws
}

/// Generic-password items in the user's login keychain.
public final class SystemKeychain: KeychainStoring {
    public init() {}

    private func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public func readData(service: String, account: String) throws -> Data? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandled(status)
        }
    }

    public func setData(_ data: Data, service: String, account: String) throws {
        let query = baseQuery(service: service, account: account)
        let update: [String: Any] = [kSecValueData as String: data]
        var status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        } else if status == errSecItemNotFound {
            var add = query
            add.merge(update) { current, _ in current }
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }

    public func deleteData(service: String, account: String) throws {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }
}

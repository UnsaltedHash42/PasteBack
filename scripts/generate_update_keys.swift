#!/usr/bin/env swift

import CryptoKit
import Foundation
import Security

// Generates or reuses an ed25519 key pair for signing Sparkle appcasts.
// Mirrors Sparkle's own `generate_keys` tool: the private key (seed || public,
// 64 bytes, base64) is stored in the login keychain under the same service and
// account so Sparkle's `sign_update` can use it. Prints SUPublicEDKey.

let service = "https://sparkle-project.org"
let account = "ed25519"
let label = "Private key for signing Sparkle updates"

func baseQuery() -> [String: Any] {
    [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecAttrProtocol as String: kSecAttrProtocolSSH,
    ]
}

func readPrivateKey() -> Data? {
    var query = baseQuery()
    query[kSecReturnData as String] = true
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else { return nil }
    return Data(base64Encoded: data)
}

func storePrivateKey(_ secret: Data, publicKey: Data) {
    var add = baseQuery()
    add[kSecValueData as String] = secret.base64EncodedString()
    add[kSecAttrLabel as String] = label
    add[kSecAttrComment as String] = "Public key (SUPublicEDKey value) for this key is:\n\n\(publicKey.base64EncodedString())"
    add[kSecAttrIsSensitive as String] = true
    add[kSecAttrIsPermanent as String] = true
    let status = SecItemAdd(add as CFDictionary, nil)
    guard status == errSecSuccess else {
        FileHandle.standardError.write("Keychain store failed: \(status)\n".data(using: .utf8)!)
        exit(1)
    }
}

var publicKey: Data
if let existing = readPrivateKey() {
    publicKey = existing.suffix(32)
} else {
    let privateKey = Curve25519.Signing.PrivateKey()
    let seed = privateKey.rawRepresentation
    publicKey = privateKey.publicKey.rawRepresentation
    storePrivateKey(seed + publicKey, publicKey: publicKey)
}

print(publicKey.base64EncodedString())

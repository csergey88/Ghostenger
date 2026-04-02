import Foundation
import CryptoKit
import Security

/// All private key material is stored exclusively in the iOS Keychain.
/// This class is the single point of contact for Keychain I/O.
final class KeychainService {
    private enum Keys {
        static let identityPrivateKey = "ghost.identity.private.key"
        static let signedPrekeyPrivateKey = "ghost.spk.private.key"
        static let oneTimePrekeyPrivateKeys = "ghost.opk.private.keys"
        static let session = "ghost.user.session"
    }

    // MARK: - Identity Key

    func saveIdentityPrivateKey(_ key: Curve25519.Signing.PrivateKey) throws {
        try save(key.rawRepresentation, for: Keys.identityPrivateKey)
    }

    func loadIdentityPrivateKey() throws -> Curve25519.Signing.PrivateKey? {
        guard let data = try load(for: Keys.identityPrivateKey) else { return nil }
        return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
    }

    // MARK: - Signed Prekey

    func saveSignedPrekeyPrivateKey(_ key: Curve25519.KeyAgreement.PrivateKey) throws {
        try save(key.rawRepresentation, for: Keys.signedPrekeyPrivateKey)
    }

    func loadSignedPrekeyPrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey? {
        guard let data = try load(for: Keys.signedPrekeyPrivateKey) else { return nil }
        return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }

    // MARK: - One-Time Prekeys

    func saveOneTimePrekeyPrivateKeys(_ keys: [Curve25519.KeyAgreement.PrivateKey]) throws {
        let rawKeys = keys.map(\.rawRepresentation)
        let data = try JSONEncoder().encode(rawKeys.map(\.base64EncodedString))
        try save(data, for: Keys.oneTimePrekeyPrivateKeys)
    }

    func consumeOneTimePrekeyPrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey? {
        guard let data = try load(for: Keys.oneTimePrekeyPrivateKeys),
              var b64Keys = try? JSONDecoder().decode([String].self, from: data),
              let firstB64 = b64Keys.first,
              let keyData = Data(base64Encoded: firstB64)
        else { return nil }

        b64Keys.removeFirst()
        let updatedData = try JSONEncoder().encode(b64Keys)
        try save(updatedData, for: Keys.oneTimePrekeyPrivateKeys)

        return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: keyData)
    }

    // MARK: - Session

    func saveSession(_ session: UserSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        try? save(data, for: Keys.session)
    }

    func loadSession() -> UserSession? {
        guard let data = try? load(for: Keys.session) else { return nil }
        return try? JSONDecoder().decode(UserSession.self, from: data)
    }

    func clearSession() {
        try? delete(for: Keys.session)
    }

    // MARK: - Private Keychain I/O

    private func save(_ data: Data, for key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update: [CFString: Any] = [kSecValueData: data]
            let searchQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: key
            ]
            let updateStatus = SecItemUpdate(searchQuery as CFDictionary, update as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.saveFailed(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.saveFailed(status)
        }
    }

    private func load(for key: String) throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.loadFailed(status) }
        return result as? Data
    }

    private func delete(for key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status): return "Keychain save failed: \(status)"
        case .loadFailed(let status): return "Keychain load failed: \(status)"
        }
    }
}

private extension Data {
    var base64EncodedString: String { base64EncodedString() }
}

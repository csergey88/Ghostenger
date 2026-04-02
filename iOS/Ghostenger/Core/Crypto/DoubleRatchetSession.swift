import Foundation
import CryptoKit

/// Simplified Double Ratchet session.
/// Provides per-message forward secrecy via symmetric ratchet.
/// Full implementation should follow the Signal Double Ratchet spec:
/// https://signal.org/docs/specifications/doubleratchet/
final class DoubleRatchetSession {
    let conversationID: UUID
    let recipientDeviceIDs: [String]

    private var rootKey: SymmetricKey
    private var sendingChainKey: SymmetricKey
    private var receivingChainKey: SymmetricKey
    private var sendMessageIndex: UInt32 = 0
    private var receiveMessageIndex: UInt32 = 0

    // Skipped message keys (for out-of-order delivery)
    private var skippedMessageKeys: [MessageKeyIndex: SymmetricKey] = [:]

    init(conversationID: UUID, rootKey: SymmetricKey, recipientDeviceIDs: [String]) {
        self.conversationID = conversationID
        self.recipientDeviceIDs = recipientDeviceIDs
        self.rootKey = rootKey
        // Derive initial chain keys from root key
        self.sendingChainKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: rootKey,
            info: Data("sending".utf8),
            outputByteCount: 32
        )
        self.receivingChainKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: rootKey,
            info: Data("receiving".utf8),
            outputByteCount: 32
        )
    }

    // MARK: - Encrypt

    func encrypt(plaintext: String) throws -> (ciphertext: String, header: String) {
        let messageKey = deriveMessageKey(from: &sendingChainKey)
        let index = sendMessageIndex
        sendMessageIndex += 1

        let nonce = AES.GCM.Nonce()
        guard let plainData = plaintext.data(using: .utf8) else {
            throw DoubleRatchetError.encryptionFailed
        }
        let sealed = try AES.GCM.seal(plainData, using: messageKey, nonce: nonce)
        let ciphertext = sealed.combined!.base64EncodedString()

        let header = RatchetHeader(messageIndex: index, previousChainLength: 0)
        let headerData = try JSONEncoder().encode(header)

        return (ciphertext, headerData.base64EncodedString())
    }

    // MARK: - Decrypt

    func decrypt(ciphertext: String, header headerB64: String) throws -> String {
        guard let headerData = Data(base64Encoded: headerB64),
              let header = try? JSONDecoder().decode(RatchetHeader.self, from: headerData)
        else { throw DoubleRatchetError.invalidHeader }

        // Check skipped message keys first
        let keyIndex = MessageKeyIndex(index: header.messageIndex)
        if let skippedKey = skippedMessageKeys[keyIndex] {
            skippedMessageKeys.removeValue(forKey: keyIndex)
            return try decryptWithKey(skippedKey, ciphertext: ciphertext)
        }

        // Skip ahead if needed, storing skipped keys
        while receiveMessageIndex < header.messageIndex {
            let skippedKey = deriveMessageKey(from: &receivingChainKey)
            skippedMessageKeys[MessageKeyIndex(index: receiveMessageIndex)] = skippedKey
            receiveMessageIndex += 1
        }

        // Decrypt with current key
        let messageKey = deriveMessageKey(from: &receivingChainKey)
        receiveMessageIndex += 1
        return try decryptWithKey(messageKey, ciphertext: ciphertext)
    }

    // MARK: - Chain ratchet

    private func deriveMessageKey(from chainKey: inout SymmetricKey) -> SymmetricKey {
        let messageKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: chainKey,
            info: Data("message".utf8),
            outputByteCount: 32
        )
        // Advance chain key
        chainKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: chainKey,
            info: Data("chain".utf8),
            outputByteCount: 32
        )
        return messageKey
    }

    private func decryptWithKey(_ key: SymmetricKey, ciphertext: String) throws -> String {
        guard let data = Data(base64Encoded: ciphertext),
              let sealed = try? AES.GCM.SealedBox(combined: data)
        else { throw DoubleRatchetError.decryptionFailed }

        let plainData = try AES.GCM.open(sealed, using: key)
        guard let plaintext = String(data: plainData, encoding: .utf8) else {
            throw DoubleRatchetError.decryptionFailed
        }
        return plaintext
    }
}

// MARK: - Supporting Types

struct RatchetHeader: Codable {
    let messageIndex: UInt32
    let previousChainLength: UInt32
}

struct MessageKeyIndex: Hashable {
    let index: UInt32
}

enum DoubleRatchetError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidHeader

    var errorDescription: String? {
        switch self {
        case .encryptionFailed: return "Message encryption failed"
        case .decryptionFailed: return "Message decryption failed"
        case .invalidHeader: return "Invalid ratchet header"
        }
    }
}

// MARK: - Session Store

/// In-memory session store. In production, persist sessions encrypted in CoreData.
final class DoubleRatchetSessionStore {
    static let shared = DoubleRatchetSessionStore()
    private var sessions: [UUID: DoubleRatchetSession] = [:]
    private let queue = DispatchQueue(label: "ghost.ratchet.store", attributes: .concurrent)

    func session(for conversationID: UUID) -> DoubleRatchetSession? {
        queue.sync { sessions[conversationID] }
    }

    func save(_ session: DoubleRatchetSession) {
        queue.async(flags: .barrier) { self.sessions[session.conversationID] = session }
    }

    func create(conversationID: UUID, rootKey: SymmetricKey, recipientDeviceIDs: [String]) -> DoubleRatchetSession {
        let session = DoubleRatchetSession(
            conversationID: conversationID,
            rootKey: rootKey,
            recipientDeviceIDs: recipientDeviceIDs
        )
        save(session)
        return session
    }
}

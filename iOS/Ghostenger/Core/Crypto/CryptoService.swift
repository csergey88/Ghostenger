import Foundation
import CryptoKit
import Security

/// Facade for all E2EE operations.
/// Private keys are kept in the Keychain and never exposed outside this class.
final class CryptoService {
    private let keychain = KeychainService()

    // MARK: - Key Generation

    /// Generates an Ed25519 identity key pair and stores the private key in Keychain.
    func generateIdentityKeyPair() throws -> KeyPair {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKeyB64 = privateKey.publicKey.rawRepresentation.base64EncodedString()
        try keychain.saveIdentityPrivateKey(privateKey)
        return KeyPair(publicKey: publicKeyB64, privateKey: nil) // private key ref stays in Keychain
    }

    /// Generates a signed prekey (X25519) and signs it with the identity key.
    func generateSignedPrekey(identityPrivateKey: String?) throws -> SignedKeyPair {
        let signedPrekey = Curve25519.KeyAgreement.PrivateKey()
        let publicKeyData = signedPrekey.publicKey.rawRepresentation

        guard let identityKey = try keychain.loadIdentityPrivateKey() else {
            throw CryptoError.keyNotFound("Identity private key not in Keychain")
        }

        let signature = try identityKey.signature(for: publicKeyData)
        try keychain.saveSignedPrekeyPrivateKey(signedPrekey)

        return SignedKeyPair(
            publicKey: publicKeyData.base64EncodedString(),
            signature: signature.base64EncodedString()
        )
    }

    /// Generates `count` one-time prekeys (X25519). Returns public keys only.
    func generateOneTimePrekeys(count: Int) throws -> [String] {
        var publicKeys: [String] = []
        var privateKeys: [Curve25519.KeyAgreement.PrivateKey] = []

        for _ in 0..<count {
            let key = Curve25519.KeyAgreement.PrivateKey()
            publicKeys.append(key.publicKey.rawRepresentation.base64EncodedString())
            privateKeys.append(key)
        }

        try keychain.saveOneTimePrekeyPrivateKeys(privateKeys)
        return publicKeys
    }

    // MARK: - X3DH Session Establishment (initiator side)

    /// Performs X3DH key agreement using a fetched prekey bundle.
    /// Returns a shared secret and the ephemeral public key to send to the recipient.
    func x3dhInitiate(bundle: PrekeyBundleDTO) throws -> X3DHResult {
        // Load our identity key
        guard let identityKey = try keychain.loadIdentityPrivateKey() else {
            throw CryptoError.keyNotFound("Identity key missing")
        }

        // Parse recipient's public keys
        guard let ikBData = Data(base64Encoded: bundle.identityPublicKey),
              let spkBData = Data(base64Encoded: bundle.signedPrekey)
        else { throw CryptoError.invalidKey }

        let recipientIK = try Curve25519.Signing.PublicKey(rawRepresentation: ikBData)
        let recipientSPK = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: spkBData)

        // Verify SPK signature
        guard let sigData = Data(base64Encoded: bundle.signedPrekeySignature),
              recipientIK.isValidSignature(sigData, for: spkBData)
        else { throw CryptoError.signatureVerificationFailed }

        // Generate ephemeral key (EK)
        let ephemeralKey = Curve25519.KeyAgreement.PrivateKey()

        // Convert identity signing key to key agreement key (simplified — use separate key in prod)
        // DH1 = DH(IKA, SPKB)
        let ikAgreement = Curve25519.KeyAgreement.PrivateKey()  // In production derive from signing key
        let dh1 = try ikAgreement.sharedSecretFromKeyAgreement(with: recipientSPK)

        // DH2 = DH(EKA, IKB converted to agreement key)
        let ikBAgreement = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ikBData)
        let dh2 = try ephemeralKey.sharedSecretFromKeyAgreement(with: ikBAgreement)

        // DH3 = DH(EKA, SPKB)
        let dh3 = try ephemeralKey.sharedSecretFromKeyAgreement(with: recipientSPK)

        // DH4 = DH(EKA, OPKB) if OPK available
        var masterKeyMaterial = dh1.withUnsafeBytes(Array.init) +
                                 dh2.withUnsafeBytes(Array.init) +
                                 dh3.withUnsafeBytes(Array.init)

        if let opkB64 = bundle.oneTimePrekey,
           let opkData = Data(base64Encoded: opkB64),
           let recipientOPK = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: opkData),
           let dh4 = try? ephemeralKey.sharedSecretFromKeyAgreement(with: recipientOPK) {
            masterKeyMaterial += dh4.withUnsafeBytes(Array.init)
        }

        // Derive root key via HKDF
        let rootKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: masterKeyMaterial),
            salt: Data("Ghostenger-X3DH-v1".utf8),
            info: Data("root".utf8),
            outputByteCount: 32
        )

        return X3DHResult(
            rootKey: rootKey,
            ephemeralPublicKey: ephemeralKey.publicKey.rawRepresentation.base64EncodedString()
        )
    }

    // MARK: - Message Encryption / Decryption (Double Ratchet stub)

    func encrypt(plaintext: String, conversationID: UUID, senderID: UUID) throws -> MessageEnvelopeDTO {
        guard let session = DoubleRatchetSessionStore.shared.session(for: conversationID) else {
            throw CryptoError.noSession(conversationID)
        }

        let (ciphertext, header) = try session.encrypt(plaintext: plaintext)

        return MessageEnvelopeDTO(
            conversationID: conversationID,
            ciphertext: ciphertext,
            ratchetHeader: header,
            recipientDeviceIDs: session.recipientDeviceIDs,
            messageType: "text"
        )
    }

    func decrypt(envelope: MessageEnvelopeServerDTO, sessionOwnerID: UUID) throws -> DecryptedMessage {
        guard let session = DoubleRatchetSessionStore.shared.session(for: envelope.conversationID) else {
            throw CryptoError.noSession(envelope.conversationID)
        }

        let plaintext = try session.decrypt(ciphertext: envelope.ciphertext, header: envelope.ratchetHeader)

        return DecryptedMessage(
            id: envelope.id,
            senderID: envelope.senderID,
            plaintext: plaintext,
            sentAt: envelope.sentAt
        )
    }

    // MARK: - Public key access

    func publicIdentityKey() throws -> String {
        guard let key = try keychain.loadIdentityPrivateKey() else {
            throw CryptoError.keyNotFound("Identity key not found")
        }
        return key.publicKey.rawRepresentation.base64EncodedString()
    }
}

// MARK: - Supporting Types

struct KeyPair {
    let publicKey: String
    let privateKey: String?
}

struct SignedKeyPair {
    let publicKey: String
    let signature: String
}

struct X3DHResult {
    let rootKey: SymmetricKey
    let ephemeralPublicKey: String
}

enum CryptoError: LocalizedError {
    case keyNotFound(String)
    case invalidKey
    case signatureVerificationFailed
    case noSession(UUID)
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .keyNotFound(let msg): return "Key not found: \(msg)"
        case .invalidKey: return "Invalid key format"
        case .signatureVerificationFailed: return "Signature verification failed"
        case .noSession(let id): return "No E2EE session for conversation \(id)"
        case .decryptionFailed: return "Message decryption failed"
        }
    }
}

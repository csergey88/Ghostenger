import Foundation
import CryptoKit

/// Generates cryptographic key material for the Signal Protocol (X3DH).
/// All private keys are generated and stored on-device only.
enum KeyGenerator {
    struct IdentityKeyPair {
        let privateKey: Curve25519.Signing.PrivateKey
        let publicKey: Curve25519.Signing.PublicKey

        var publicKeyBase64: String {
            publicKey.rawRepresentation.base64EncodedString()
        }

        /// Serialize private key to Data for Keychain storage.
        var privateKeyData: Data {
            privateKey.rawRepresentation
        }
    }

    struct EphemeralKeyPair {
        let privateKey: Curve25519.KeyAgreement.PrivateKey
        let publicKey: Curve25519.KeyAgreement.PublicKey

        var publicKeyBase64: String {
            publicKey.rawRepresentation.base64EncodedString()
        }
    }

    /// Generates a new Ed25519 identity key pair for signing.
    static func generateIdentityKeyPair() -> IdentityKeyPair {
        let privateKey = Curve25519.Signing.PrivateKey()
        return IdentityKeyPair(privateKey: privateKey, publicKey: privateKey.publicKey)
    }

    /// Generates a new X25519 key pair for key agreement.
    static func generateEphemeralKeyPair() -> EphemeralKeyPair {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        return EphemeralKeyPair(privateKey: privateKey, publicKey: privateKey.publicKey)
    }

    /// Signs a public key with the identity key (for signed prekeys).
    static func sign(_ data: Data, with identityKey: Curve25519.Signing.PrivateKey) throws -> Data {
        try identityKey.signature(for: data)
    }
}

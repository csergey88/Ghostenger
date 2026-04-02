import Fluent
import Vapor

/// One-time or signed prekey stored for X3DH key agreement.
/// The server stores ONLY public keys — private keys never leave the device.
final class PrekeyBundle: Model, @unchecked Sendable {
    static let schema = "prekey_bundles"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    /// Client-assigned prekey ID (for the client to track which key was used).
    @Field(key: "prekey_id")
    var prekeyId: Int

    /// Base64-encoded public key.
    @Field(key: "public_key")
    var publicKey: String

    /// true = signed prekey (semi-permanent), false = one-time prekey (consumed on use).
    @Field(key: "is_signed")
    var isSigned: Bool

    /// For signed prekeys: Ed25519 signature over the public key, Base64-encoded.
    @OptionalField(key: "signature")
    var signature: String?

    /// Marks one-time prekeys as consumed after delivery.
    @Field(key: "consumed")
    var consumed: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userID: UUID,
        prekeyId: Int,
        publicKey: String,
        isSigned: Bool,
        signature: String? = nil
    ) {
        self.id = id
        self.$user.id = userID
        self.prekeyId = prekeyId
        self.publicKey = publicKey
        self.isSigned = isSigned
        self.signature = signature
        self.consumed = false
    }
}

// MARK: - DTOs

struct SignedPrekeyBundleDTO: Content {
    let prekeyId: Int
    let publicKey: String
    let signature: String
}

struct OnetimePrekeyDTO: Content {
    let prekeyId: Int
    let publicKey: String
}

struct UploadPrekeysDTO: Content {
    let signedPrekey: SignedPrekeyBundleDTO?
    let onetimePrekeys: [OnetimePrekeyDTO]
}

struct PrekeyBundleResponse: Content {
    let userId: UUID
    let identityKeyPublic: String
    let signedPrekey: SignedPrekeyBundleDTO
    let onetimePrekey: OnetimePrekeyDTO?
}

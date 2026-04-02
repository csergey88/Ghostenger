import Fluent
import Vapor

/// Stores one-time prekeys (OPKs) and signed prekeys (SPKs) for X3DH key agreement.
/// Private keys NEVER reach the server — only public keys are stored here.
final class PrekeyBundle: Model, Content, @unchecked Sendable {
    static let schema = "prekey_bundles"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "device_id")
    var deviceID: String

    /// X25519 signed prekey (base64 public key)
    @Field(key: "signed_prekey")
    var signedPrekey: String

    /// Ed25519 signature of the signed prekey, made with the identity key
    @Field(key: "signed_prekey_signature")
    var signedPrekeySignature: String

    /// One-time prekey (base64 public key). Null once consumed.
    @OptionalField(key: "one_time_prekey")
    var oneTimePrekey: String?

    @Field(key: "is_consumed")
    var isConsumed: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userID: UUID,
        deviceID: String,
        signedPrekey: String,
        signedPrekeySignature: String,
        oneTimePrekey: String? = nil
    ) {
        self.id = id
        self.$user.id = userID
        self.deviceID = deviceID
        self.signedPrekey = signedPrekey
        self.signedPrekeySignature = signedPrekeySignature
        self.oneTimePrekey = oneTimePrekey
        self.isConsumed = false
    }
}

// MARK: - DTO

extension PrekeyBundle {
    struct PublicBundle: Content {
        let userID: UUID
        let deviceID: String
        let identityPublicKey: String
        let signedPrekey: String
        let signedPrekeySignature: String
        let oneTimePrekey: String?
    }
}

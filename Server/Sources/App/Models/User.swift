import Fluent
import Vapor

final class User: Model, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    @Field(key: "password_hash")
    var passwordHash: String

    /// Public Ed25519 identity key (Base64-encoded).
    /// The private key NEVER leaves the client device.
    @Field(key: "identity_key_public")
    var identityKeyPublic: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Children(for: \.$user)
    var devices: [Device]

    @Children(for: \.$user)
    var prekeyBundles: [PrekeyBundle]

    init() {}

    init(
        id: UUID? = nil,
        username: String,
        passwordHash: String,
        identityKeyPublic: String
    ) {
        self.id = id
        self.username = username
        self.passwordHash = passwordHash
        self.identityKeyPublic = identityKeyPublic
    }
}

extension User: Authenticatable {}

// MARK: - DTOs

struct RegisterDTO: Content {
    let username: String
    let password: String
    /// Public identity key (Base64 DER/raw Ed25519)
    let identityKeyPublic: String
    /// Initial signed prekey bundle to upload during registration
    let signedPrekeyBundle: SignedPrekeyBundleDTO
}

struct LoginDTO: Content {
    let username: String
    let password: String
}

struct UserPublicResponse: Content {
    let id: UUID
    let username: String
    let identityKeyPublic: String
    let createdAt: Date?
}

extension User {
    func toPublicResponse() throws -> UserPublicResponse {
        UserPublicResponse(
            id: try requireID(),
            username: username,
            identityKeyPublic: identityKeyPublic,
            createdAt: createdAt
        )
    }
}

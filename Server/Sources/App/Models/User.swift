import Fluent
import Vapor

final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    @Field(key: "phone_hash")
    var phoneHash: String

    @Field(key: "password_hash")
    var passwordHash: String

    /// Base64-encoded Ed25519 public identity key
    @Field(key: "identity_public_key")
    var identityPublicKey: String

    @Field(key: "display_name")
    var displayName: String

    @OptionalField(key: "avatar_url")
    var avatarURL: String?

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
        phoneHash: String,
        passwordHash: String,
        identityPublicKey: String,
        displayName: String
    ) {
        self.id = id
        self.username = username
        self.phoneHash = phoneHash
        self.passwordHash = passwordHash
        self.identityPublicKey = identityPublicKey
        self.displayName = displayName
    }
}

// MARK: - DTO

extension User {
    struct PublicProfile: Content {
        let id: UUID
        let username: String
        let displayName: String
        let identityPublicKey: String
        let avatarURL: String?
    }

    var publicProfile: PublicProfile {
        .init(
            id: id!,
            username: username,
            displayName: displayName,
            identityPublicKey: identityPublicKey,
            avatarURL: avatarURL
        )
    }
}

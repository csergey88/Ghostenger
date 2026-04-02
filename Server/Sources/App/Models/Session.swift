import Fluent
import Vapor
import JWT

/// Server-side session metadata (NOT a crypto session — crypto state stays on device).
final class Session: Model, @unchecked Sendable {
    static let schema = "sessions"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "user_id")
    var userId: UUID

    @Field(key: "device_id")
    var deviceId: UUID

    @Field(key: "revoked")
    var revoked: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "expires_at", on: .none)
    var expiresAt: Date?

    init() {}

    init(id: UUID? = nil, userId: UUID, deviceId: UUID, expiresAt: Date) {
        self.id = id
        self.userId = userId
        self.deviceId = deviceId
        self.revoked = false
        self.expiresAt = expiresAt
    }
}

// MARK: - JWT Payload

struct AuthPayload: JWTPayload {
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case deviceId = "did"
        case sessionId = "sid"
        case expiration = "exp"
        case issuedAt = "iat"
    }

    var subject: SubjectClaim
    var deviceId: UUID
    var sessionId: UUID
    var expiration: ExpirationClaim
    var issuedAt: IssuedAtClaim

    func verify(using _: some JWTAlgorithm) async throws {
        try expiration.verifyNotExpired()
    }

    var userId: UUID {
        get throws { try UUID(uuidString: subject.value) ?? { throw JWTError.claimVerificationFailure(failedClaim: subject, reason: "invalid UUID") }() }
    }
}

struct TokenResponse: Content {
    let token: String
    let expiresAt: Date
    let userId: UUID
    let deviceId: UUID
}

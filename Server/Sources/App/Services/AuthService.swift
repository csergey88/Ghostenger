import Vapor
import Fluent
import JWT
import Crypto

struct AuthService {
    let db: Database
    let jwt: Request.JWT

    private static let tokenLifetime: TimeInterval = 30 * 24 * 60 * 60 // 30 days

    func register(_ dto: RegisterDTO) async throws -> TokenResponse {
        guard dto.username.count >= 3, dto.username.count <= 32 else {
            throw Abort(.badRequest, reason: "Username must be 3–32 characters")
        }
        guard dto.password.count >= 8 else {
            throw Abort(.badRequest, reason: "Password must be at least 8 characters")
        }

        let existing = try await User.query(on: db)
            .filter(\.$username == dto.username)
            .first()
        guard existing == nil else {
            throw Abort(.conflict, reason: "Username already taken")
        }

        let hash = try Bcrypt.hash(dto.password)
        let user = User(username: dto.username, passwordHash: hash, identityKeyPublic: dto.identityKeyPublic)
        try await user.save(on: db)

        let device = Device(userID: try user.requireID(), deviceName: "Primary")
        try await device.save(on: db)

        // Upload initial signed prekey
        let sp = dto.signedPrekeyBundle
        let signedKey = PrekeyBundle(
            userID: try user.requireID(),
            prekeyId: sp.prekeyId,
            publicKey: sp.publicKey,
            isSigned: true,
            signature: sp.signature
        )
        try await signedKey.save(on: db)

        return try await issueToken(userId: user.requireID(), deviceId: device.requireID())
    }

    func login(_ dto: LoginDTO) async throws -> TokenResponse {
        guard let user = try await User.query(on: db)
            .filter(\.$username == dto.username)
            .first()
        else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }

        guard try Bcrypt.verify(dto.password, created: user.passwordHash) else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }

        let device = Device(userID: try user.requireID(), deviceName: "Unknown")
        try await device.save(on: db)

        return try await issueToken(userId: user.requireID(), deviceId: device.requireID())
    }

    private func issueToken(userId: UUID, deviceId: UUID) async throws -> TokenResponse {
        let expiresAt = Date(timeIntervalSinceNow: Self.tokenLifetime)
        let session = Session(userId: userId, deviceId: deviceId, expiresAt: expiresAt)
        try await session.save(on: db)

        let payload = AuthPayload(
            subject: .init(value: userId.uuidString),
            deviceId: deviceId,
            sessionId: try session.requireID(),
            expiration: .init(value: expiresAt),
            issuedAt: .init(value: Date())
        )
        let token = try await jwt.sign(payload)
        return TokenResponse(token: token, expiresAt: expiresAt, userId: userId, deviceId: deviceId)
    }
}

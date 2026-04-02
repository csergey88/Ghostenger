import Vapor
import JWT
import Crypto

struct AuthService {
    let db: Database
    let jwt: Request.JWT

    // MARK: - Register

    struct RegisterRequest: Content {
        let username: String
        let phoneHash: String
        let password: String
        let identityPublicKey: String
        let displayName: String
        let deviceID: String
        let signedPrekey: String
        let signedPrekeySignature: String
        let oneTimePrekeys: [String]
    }

    struct AuthResponse: Content {
        let token: String
        let user: User.PublicProfile
    }

    func register(_ req: RegisterRequest) async throws -> AuthResponse {
        // Check uniqueness
        let existingUser = try await User.query(on: db)
            .filter(\.$username == req.username)
            .first()
        guard existingUser == nil else {
            throw Abort(.conflict, reason: "Username already taken")
        }

        // Hash password with bcrypt
        let passwordHash = try Bcrypt.hash(req.password)

        let user = User(
            username: req.username,
            phoneHash: req.phoneHash,
            passwordHash: passwordHash,
            identityPublicKey: req.identityPublicKey,
            displayName: req.displayName
        )
        try await user.save(on: db)

        guard let userID = user.id else { throw Abort(.internalServerError) }

        // Register device
        let device = Device(userID: userID, deviceID: req.deviceID, platform: "ios")
        try await device.save(on: db)

        // Upload initial prekey bundle
        let bundle = PrekeyBundle(
            userID: userID,
            deviceID: req.deviceID,
            signedPrekey: req.signedPrekey,
            signedPrekeySignature: req.signedPrekeySignature,
            oneTimePrekey: req.oneTimePrekeys.first
        )
        try await bundle.save(on: db)

        // Upload remaining OPKs
        for opk in req.oneTimePrekeys.dropFirst() {
            let opkBundle = PrekeyBundle(
                userID: userID,
                deviceID: req.deviceID,
                signedPrekey: req.signedPrekey,
                signedPrekeySignature: req.signedPrekeySignature,
                oneTimePrekey: opk
            )
            try await opkBundle.save(on: db)
        }

        let token = try await issueToken(userID: userID, deviceID: req.deviceID)
        return AuthResponse(token: token, user: user.publicProfile)
    }

    // MARK: - Login

    struct LoginRequest: Content {
        let username: String
        let password: String
        let deviceID: String
    }

    func login(_ req: LoginRequest) async throws -> AuthResponse {
        guard let user = try await User.query(on: db)
            .filter(\.$username == req.username)
            .first()
        else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }

        guard try Bcrypt.verify(req.password, created: user.passwordHash) else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }

        guard let userID = user.id else { throw Abort(.internalServerError) }

        // Upsert device
        if try await Device.query(on: db)
            .filter(\.$user.$id == userID)
            .filter(\.$deviceID == req.deviceID)
            .first() == nil
        {
            let device = Device(userID: userID, deviceID: req.deviceID, platform: "ios")
            try await device.save(on: db)
        }

        let token = try await issueToken(userID: userID, deviceID: req.deviceID)
        return AuthResponse(token: token, user: user.publicProfile)
    }

    // MARK: - Token

    private func issueToken(userID: UUID, deviceID: String) async throws -> String {
        let payload = JWTPayload(
            subject: .init(value: userID.uuidString),
            expiration: .init(value: Date().addingTimeInterval(60 * 60 * 24 * 30)), // 30 days
            userID: userID,
            deviceID: deviceID
        )
        return try await jwt.sign(payload)
    }
}

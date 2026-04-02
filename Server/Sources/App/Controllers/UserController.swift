import Vapor

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes.grouped("users")
        users.get("me", use: me)
        users.get(":username", use: profile)
        users.patch("me", use: updateProfile)
        users.put("me", "push-token", use: updatePushToken)
    }

    func me(req: Request) async throws -> User.PublicProfile {
        try req.auth.require(User.self).publicProfile
    }

    func profile(req: Request) async throws -> User.PublicProfile {
        guard let username = req.parameters.get("username") else { throw Abort(.badRequest) }
        guard let user = try await User.query(on: req.db)
            .filter(\.$username == username)
            .first()
        else { throw Abort(.notFound) }
        return user.publicProfile
    }

    func updateProfile(req: Request) async throws -> User.PublicProfile {
        struct UpdateProfileRequest: Content {
            let displayName: String?
            let avatarURL: String?
        }
        let user = try req.auth.require(User.self)
        let body = try req.content.decode(UpdateProfileRequest.self)
        if let name = body.displayName { user.displayName = name }
        if let url = body.avatarURL { user.avatarURL = url }
        try await user.save(on: req.db)
        return user.publicProfile
    }

    func updatePushToken(req: Request) async throws -> HTTPStatus {
        struct PushTokenRequest: Content {
            let deviceID: String
            let pushToken: String
        }
        let user = try req.auth.require(User.self)
        let body = try req.content.decode(PushTokenRequest.self)
        guard let userID = user.id else { throw Abort(.internalServerError) }
        guard let device = try await Device.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$deviceID == body.deviceID)
            .first()
        else { throw Abort(.notFound) }
        device.pushToken = body.pushToken
        try await device.save(on: req.db)
        return .ok
    }
}

import Vapor
import JWT

struct JWTPayload: JWTPayload {
    var subject: SubjectClaim
    var expiration: ExpirationClaim
    var userID: UUID
    var deviceID: String

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try expiration.verifyNotExpired()
    }
}

struct JWTAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let payload = try await request.jwt.verify(as: JWTPayload.self)
        guard let user = try await User.find(payload.userID, on: request.db) else {
            throw Abort(.unauthorized)
        }
        request.auth.login(user)
        return try await next.respond(to: request)
    }
}

extension User: Authenticatable {}

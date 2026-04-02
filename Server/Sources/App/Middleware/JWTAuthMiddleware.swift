import Vapor
import JWT

struct JWTAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let payload = try await request.jwt.verify(as: AuthPayload.self)

        // Validate the session hasn't been revoked
        let session = try await Session.find(payload.sessionId, on: request.db)
        guard let session, !session.revoked else {
            throw Abort(.unauthorized, reason: "Session revoked or not found")
        }
        guard let expiresAt = session.expiresAt, expiresAt > Date() else {
            throw Abort(.unauthorized, reason: "Session expired")
        }

        request.storage[AuthPayloadKey.self] = payload
        return try await next.respond(to: request)
    }
}

private struct AuthPayloadKey: StorageKey {
    typealias Value = AuthPayload
}

extension Request {
    var authPayload: AuthPayload {
        get throws {
            guard let payload = storage[AuthPayloadKey.self] else {
                throw Abort(.unauthorized)
            }
            return payload
        }
    }
}

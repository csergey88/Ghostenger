import Vapor
import Fluent

struct MessageController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let messages = routes.grouped("messages")
        messages.post(use: send)
        messages.get(":conversationId", use: list)
    }

    /// POST /api/v1/messages
    func send(req: Request) async throws -> MessageResponse {
        let dto = try req.content.decode(SendMessageDTO.self)
        let payload = try req.authPayload
        let userId = try payload.userId
        return try await MessageService(db: req.db, redis: req.redis).send(dto, from: userId)
    }

    /// GET /api/v1/messages/:conversationId
    func list(req: Request) async throws -> [MessageResponse] {
        guard let conversationId = req.parameters.get("conversationId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid conversation ID")
        }
        let payload = try req.authPayload
        let userId = try payload.userId
        return try await MessageService(db: req.db, redis: req.redis).list(
            conversationId: conversationId,
            requestingUserId: userId
        )
    }
}

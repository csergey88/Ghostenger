import Vapor
import Fluent

struct ContactController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let contacts = routes.grouped("contacts")
        contacts.get("search", use: search)
        contacts.post("conversations", use: createConversation)
        contacts.get("conversations", use: listConversations)
    }

    /// GET /api/v1/contacts/search?username=alice
    func search(req: Request) async throws -> [UserPublicResponse] {
        guard let query = req.query[String.self, at: "username"], !query.isEmpty else {
            throw Abort(.badRequest, reason: "username query parameter is required")
        }
        let users = try await User.query(on: req.db)
            .filter(\.$username ~~ query)
            .limit(20)
            .all()
        return try users.map { try $0.toPublicResponse() }
    }

    /// POST /api/v1/contacts/conversations
    func createConversation(req: Request) async throws -> ConversationResponse {
        struct CreateConversationDTO: Content { let recipientId: UUID }
        let dto = try req.content.decode(CreateConversationDTO.self)
        let payload = try req.authPayload
        let userId = try payload.userId
        return try await ConversationService(db: req.db).getOrCreate(
            between: userId,
            and: dto.recipientId
        )
    }

    /// GET /api/v1/contacts/conversations
    func listConversations(req: Request) async throws -> [ConversationResponse] {
        let payload = try req.authPayload
        let userId = try payload.userId
        return try await ConversationService(db: req.db).list(for: userId)
    }
}

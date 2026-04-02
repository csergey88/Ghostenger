import Vapor

struct ConversationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let convs = routes.grouped("conversations")
        convs.get(use: list)
        convs.post(use: create)
        convs.get(":conversationID", "messages", use: messages)
    }

    func list(req: Request) async throws -> [ConversationSummary] {
        let user = try req.auth.require(User.self)
        guard let userID = user.id else { throw Abort(.internalServerError) }

        let participantRows = try await ConversationParticipant.query(on: req.db)
            .filter(\.$user.$id == userID)
            .with(\.$conversation)
            .all()

        return try participantRows.map { row in
            ConversationSummary(
                id: try row.conversation.requireID(),
                type: row.conversation.type,
                name: row.conversation.name,
                updatedAt: row.conversation.updatedAt
            )
        }
    }

    func create(req: Request) async throws -> ConversationSummary {
        struct CreateRequest: Content {
            let participantIDs: [UUID]
            let name: String?
        }
        let user = try req.auth.require(User.self)
        guard let userID = user.id else { throw Abort(.internalServerError) }

        let body = try req.content.decode(CreateRequest.self)
        let allParticipants = ([userID] + body.participantIDs).uniqued()

        let type = allParticipants.count == 2 ? "direct" : "group"
        let conversation = Conversation(type: type, name: body.name)
        try await conversation.save(on: req.db)
        guard let convID = conversation.id else { throw Abort(.internalServerError) }

        for pid in allParticipants {
            let p = ConversationParticipant(conversationID: convID, userID: pid)
            try await p.save(on: req.db)
        }

        return ConversationSummary(
            id: convID,
            type: type,
            name: body.name,
            updatedAt: conversation.updatedAt
        )
    }

    func messages(req: Request) async throws -> [Message.Envelope] {
        guard let convIDString = req.parameters.get("conversationID"),
              let convID = UUID(uuidString: convIDString)
        else { throw Abort(.badRequest) }

        let user = try req.auth.require(User.self)
        guard let userID = user.id else { throw Abort(.internalServerError) }

        // Verify participant
        guard try await ConversationParticipant.query(on: req.db)
            .filter(\.$conversation.$id == convID)
            .filter(\.$user.$id == userID)
            .first() != nil
        else { throw Abort(.forbidden) }

        struct QueryParams: Content {
            var before: Date?
            var limit: Int?
        }
        let params = try req.query.decode(QueryParams.self)
        let limit = min(params.limit ?? 50, 100)

        var query = Message.query(on: req.db)
            .filter(\.$conversation.$id == convID)
            .sort(\.$sentAt, .descending)
            .limit(limit)

        if let before = params.before {
            query = query.filter(\.$sentAt < before)
        }

        let msgs = try await query.all()
        return msgs.map(\.envelope)
    }
}

// MARK: - Helpers

struct ConversationSummary: Content {
    let id: UUID
    let type: String
    let name: String?
    let updatedAt: Date?
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

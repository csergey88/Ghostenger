import Vapor
import Fluent

struct ConversationService {
    let db: Database

    /// Returns an existing direct conversation between two users, or creates one.
    func getOrCreateDirect(between userID: UUID, and recipientID: UUID) async throws -> ConversationSummary {
        // Look for an existing direct conversation that contains both users
        let userConvIDs = try await ConversationParticipant.query(on: db)
            .filter(\.$user.$id == userID)
            .all()
            .map { $0.$conversation.id }

        let recipientConvIDs = try await ConversationParticipant.query(on: db)
            .filter(\.$user.$id == recipientID)
            .all()
            .map { $0.$conversation.id }

        let sharedConvIDs = Set(userConvIDs).intersection(Set(recipientConvIDs))

        for convID in sharedConvIDs {
            if let conversation = try await Conversation.find(convID, on: db),
               conversation.type == "direct" {
                return ConversationSummary(
                    id: convID,
                    type: "direct",
                    name: conversation.name,
                    updatedAt: conversation.updatedAt
                )
            }
        }

        // Create a new direct conversation
        let conversation = Conversation(type: "direct")
        try await conversation.save(on: db)
        guard let convID = conversation.id else { throw Abort(.internalServerError) }

        try await ConversationParticipant(conversationID: convID, userID: userID).save(on: db)
        try await ConversationParticipant(conversationID: convID, userID: recipientID).save(on: db)

        return ConversationSummary(
            id: convID,
            type: "direct",
            name: nil,
            updatedAt: nil
        )
    }

    /// Lists all conversations a user participates in.
    func list(for userID: UUID) async throws -> [ConversationSummary] {
        let rows = try await ConversationParticipant.query(on: db)
            .filter(\.$user.$id == userID)
            .with(\.$conversation)
            .all()

        return try rows.map { row in
            ConversationSummary(
                id: try row.conversation.requireID(),
                type: row.conversation.type,
                name: row.conversation.name,
                updatedAt: row.conversation.updatedAt
            )
        }
    }
}

import Vapor
import Fluent

struct ConversationService {
    let db: Database

    func getOrCreate(between userId: UUID, and recipientId: UUID) async throws -> ConversationResponse {
        let key = [userId, recipientId].map(\.uuidString).sorted().joined(separator: ",")

        if let existing = try await Conversation.query(on: db)
            .filter(\.$participantIds == key)
            .first()
        {
            return try existing.toResponse()
        }

        let conversation = Conversation(participantIds: [userId, recipientId])
        try await conversation.save(on: db)
        return try conversation.toResponse()
    }

    func list(for userId: UUID) async throws -> [ConversationResponse] {
        let conversations = try await Conversation.query(on: db)
            .filter(\.$participantIds ~~ userId.uuidString)
            .sort(\.$createdAt, .descending)
            .all()
        return try conversations.map { try $0.toResponse() }
    }
}

import Fluent
import Vapor

final class Conversation: Model, @unchecked Sendable {
    static let schema = "conversations"

    @ID(key: .id)
    var id: UUID?

    /// Sorted, comma-separated participant user IDs for deduplication.
    @Field(key: "participant_ids")
    var participantIds: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Children(for: \.$conversation)
    var messages: [Message]

    init() {}

    init(id: UUID? = nil, participantIds: [UUID]) {
        self.id = id
        self.participantIds = participantIds
            .map(\.uuidString)
            .sorted()
            .joined(separator: ",")
    }

    func containsUser(_ userID: UUID) -> Bool {
        participantIds.contains(userID.uuidString)
    }
}

struct ConversationResponse: Content {
    let id: UUID
    let participantIds: [String]
    let createdAt: Date?
}

extension Conversation {
    func toResponse() throws -> ConversationResponse {
        ConversationResponse(
            id: try requireID(),
            participantIds: participantIds.split(separator: ",").map(String.init),
            createdAt: createdAt
        )
    }
}

import Fluent
import Vapor

final class Conversation: Model, Content, @unchecked Sendable {
    static let schema = "conversations"

    @ID(key: .id)
    var id: UUID?

    /// "direct" or "group"
    @Field(key: "type")
    var type: String

    @OptionalField(key: "name")
    var name: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Children(for: \.$conversation)
    var participants: [ConversationParticipant]

    @Children(for: \.$conversation)
    var messages: [Message]

    init() {}

    init(id: UUID? = nil, type: String, name: String? = nil) {
        self.id = id
        self.type = type
        self.name = name
    }
}

// MARK: - Pivot

final class ConversationParticipant: Model, @unchecked Sendable {
    static let schema = "conversation_participants"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "conversation_id")
    var conversation: Conversation

    @Parent(key: "user_id")
    var user: User

    @Timestamp(key: "joined_at", on: .create)
    var joinedAt: Date?

    init() {}

    init(conversationID: UUID, userID: UUID) {
        self.$conversation.id = conversationID
        self.$user.id = userID
    }
}

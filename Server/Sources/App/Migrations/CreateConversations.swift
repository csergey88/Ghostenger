import Fluent

struct CreateConversations: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("conversations")
            .id()
            .field("type", .string, .required)
            .field("name", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("conversations").delete()
    }
}

struct CreateConversationParticipants: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("conversation_participants")
            .id()
            .field("conversation_id", .uuid, .required, .references("conversations", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("joined_at", .datetime)
            .unique(on: "conversation_id", "user_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("conversation_participants").delete()
    }
}

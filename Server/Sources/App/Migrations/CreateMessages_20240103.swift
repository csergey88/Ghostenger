import Fluent

struct CreateMessages_20240103: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("messages")
            .id()
            .field("conversation_id", .uuid, .required, .references("conversations", "id", onDelete: .cascade))
            .field("sender_id", .uuid, .required)
            .field("ciphertext", .string, .required)
            .field("message_type", .int, .required, .sql(.default(0)))
            .field("delivered", .bool, .required, .sql(.default(false)))
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("messages").delete()
    }
}

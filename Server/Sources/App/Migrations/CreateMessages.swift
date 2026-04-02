import Fluent

struct CreateMessages: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("messages")
            .id()
            .field("conversation_id", .uuid, .required, .references("conversations", "id", onDelete: .cascade))
            .field("sender_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("ciphertext", .string, .required)
            .field("ratchet_header", .string, .required)
            .field("recipient_device_ids", .array(of: .string), .required)
            .field("message_type", .string, .required)
            .field("is_delivered", .bool, .required)
            .field("is_read", .bool, .required)
            .field("sent_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("messages").delete()
    }
}

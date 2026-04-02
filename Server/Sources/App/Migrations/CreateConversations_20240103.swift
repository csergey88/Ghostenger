import Fluent

struct CreateConversations_20240103: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("conversations")
            .id()
            .field("participant_ids", .string, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("conversations").delete()
    }
}

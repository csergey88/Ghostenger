import Fluent

struct CreateSessions_20240104: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("sessions")
            .id()
            .field("user_id", .uuid, .required)
            .field("device_id", .uuid, .required)
            .field("revoked", .bool, .required, .sql(.default(false)))
            .field("created_at", .datetime)
            .field("expires_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("sessions").delete()
    }
}

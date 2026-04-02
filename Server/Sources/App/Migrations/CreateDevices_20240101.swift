import Fluent

struct CreateDevices_20240101: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("devices")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("device_name", .string, .required)
            .field("push_token", .string)
            .field("created_at", .datetime)
            .field("last_seen_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("devices").delete()
    }
}

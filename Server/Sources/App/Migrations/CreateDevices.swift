import Fluent

struct CreateDevices: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("devices")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("device_id", .string, .required)
            .field("push_token", .string)
            .field("platform", .string, .required)
            .field("last_seen_at", .datetime)
            .field("created_at", .datetime)
            .unique(on: "user_id", "device_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("devices").delete()
    }
}

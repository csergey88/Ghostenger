import Fluent

struct CreatePrekeyBundles: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("prekey_bundles")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("device_id", .string, .required)
            .field("signed_prekey", .string, .required)
            .field("signed_prekey_signature", .string, .required)
            .field("one_time_prekey", .string)
            .field("is_consumed", .bool, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("prekey_bundles").delete()
    }
}

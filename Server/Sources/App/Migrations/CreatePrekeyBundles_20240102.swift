import Fluent

struct CreatePrekeyBundles_20240102: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("prekey_bundles")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("prekey_id", .int, .required)
            .field("public_key", .string, .required)
            .field("is_signed", .bool, .required)
            .field("signature", .string)
            .field("consumed", .bool, .required, .sql(.default(false)))
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("prekey_bundles").delete()
    }
}

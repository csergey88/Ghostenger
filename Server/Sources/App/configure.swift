import Vapor
import Fluent
import FluentPostgresDriver
import Redis
import JWT

public func configure(_ app: Application) async throws {
    // MARK: - Database
    let dbURL = Environment.get("DATABASE_URL")
        ?? "postgres://ghost:ghost@localhost:5432/ghostenger"
    try app.databases.use(.postgres(url: dbURL), as: .psql)

    // MARK: - Redis
    let redisURLString = Environment.get("REDIS_URL") ?? "redis://localhost:6379"
    guard let redisURL = URL(string: redisURLString) else {
        throw Abort(.internalServerError, reason: "Invalid REDIS_URL")
    }
    app.redis.configuration = try RedisConfiguration(url: redisURL)

    // MARK: - JWT
    let jwtSecret = Environment.get("JWT_SECRET") ?? "ghostenger-dev-secret-change-in-production"
    await app.jwt.keys.add(hmac: .init(from: jwtSecret), digestAlgorithm: .sha256)

    // MARK: - Middleware
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    // MARK: - Migrations
    app.migrations.add(CreateUsers())
    app.migrations.add(CreateDevices())
    app.migrations.add(CreatePrekeyBundles())
    app.migrations.add(CreateConversations())
    app.migrations.add(CreateConversationParticipants())
    app.migrations.add(CreateMessages())

    try await app.autoMigrate()

    // MARK: - Routes
    try routes(app)
}

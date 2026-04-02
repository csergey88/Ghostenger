import Vapor
import Fluent
import FluentPostgresDriver
import Redis
import JWT

public func configure(_ app: Application) async throws {
    // MARK: - Database
    let databaseURL = Environment.get("DATABASE_URL")
        ?? "postgres://ghost:ghost@localhost:5432/ghostenger"
    try app.databases.use(.postgres(url: databaseURL), as: .psql)

    // MARK: - Redis
    let redisURL = Environment.get("REDIS_URL") ?? "redis://localhost:6379"
    app.redis.configuration = try RedisConfiguration(url: redisURL)

    // MARK: - JWT
    let jwtSecret = Environment.get("JWT_SECRET") ?? {
        if app.environment == .production {
            fatalError("JWT_SECRET environment variable is required in production")
        }
        return "dev-secret-do-not-use-in-production"
    }()
    await app.jwt.keys.add(hmac: .init(from: jwtSecret), digestAlgorithm: .sha256)

    // MARK: - Content
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    ContentConfiguration.global.use(encoder: encoder, for: .json)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    ContentConfiguration.global.use(decoder: decoder, for: .json)

    // MARK: - Migrations
    app.migrations.add(CreateUsers_20240101())
    app.migrations.add(CreateDevices_20240101())
    app.migrations.add(CreatePrekeyBundles_20240102())
    app.migrations.add(CreateConversations_20240103())
    app.migrations.add(CreateMessages_20240103())
    app.migrations.add(CreateSessions_20240104())

    if app.environment == .development {
        try await app.autoMigrate()
    }

    // MARK: - Middleware
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    // MARK: - Routes
    try routes(app)
}

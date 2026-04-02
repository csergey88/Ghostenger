import Vapor
import Fluent

struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("register", use: register)
        auth.post("login", use: login)
    }

    /// POST /api/v1/auth/register
    func register(req: Request) async throws -> TokenResponse {
        let dto = try req.content.decode(RegisterDTO.self)
        return try await AuthService(db: req.db, jwt: req.jwt).register(dto)
    }

    /// POST /api/v1/auth/login
    func login(req: Request) async throws -> TokenResponse {
        let dto = try req.content.decode(LoginDTO.self)
        return try await AuthService(db: req.db, jwt: req.jwt).login(dto)
    }
}

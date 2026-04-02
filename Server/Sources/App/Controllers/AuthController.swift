import Vapor

struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("register", use: register)
        auth.post("login", use: login)
    }

    func register(req: Request) async throws -> AuthService.AuthResponse {
        try AuthService.RegisterRequest.validate(content: req)
        let body = try req.content.decode(AuthService.RegisterRequest.self)
        let service = AuthService(db: req.db, jwt: req.jwt)
        return try await service.register(body)
    }

    func login(req: Request) async throws -> AuthService.AuthResponse {
        let body = try req.content.decode(AuthService.LoginRequest.self)
        let service = AuthService(db: req.db, jwt: req.jwt)
        return try await service.login(body)
    }
}

// MARK: - Validation

extension AuthService.RegisterRequest: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("username", as: String.self, is: .alphanumeric && .count(3...32))
        validations.add("password", as: String.self, is: .count(8...))
        validations.add("displayName", as: String.self, is: .count(1...64))
        validations.add("identityPublicKey", as: String.self, is: !.empty)
        validations.add("deviceID", as: String.self, is: !.empty)
        validations.add("signedPrekey", as: String.self, is: !.empty)
        validations.add("signedPrekeySignature", as: String.self, is: !.empty)
    }
}

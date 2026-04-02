import Vapor
import Fluent

struct PrekeyController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let prekeys = routes.grouped("prekeys")
        prekeys.post(use: upload)
        prekeys.get(":userId", use: fetch)
    }

    /// POST /api/v1/prekeys — upload new prekeys
    func upload(req: Request) async throws -> HTTPStatus {
        let dto = try req.content.decode(UploadPrekeysDTO.self)
        let payload = try req.authPayload
        let userId = try payload.userId
        try await PrekeyService(db: req.db).upload(dto, for: userId)
        return .noContent
    }

    /// GET /api/v1/prekeys/:userId — fetch a prekey bundle for X3DH session setup
    func fetch(req: Request) async throws -> PrekeyBundleResponse {
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        return try await PrekeyService(db: req.db).fetchBundle(for: userId)
    }
}

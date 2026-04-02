import Vapor

struct PrekeyController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let prekeys = routes.grouped("prekeys")
        prekeys.post("upload", use: upload)
        prekeys.get(":userID", use: fetchBundle)
    }

    /// Client uploads fresh one-time prekeys when the server's supply runs low.
    func upload(req: Request) async throws -> HTTPStatus {
        struct UploadRequest: Content {
            let deviceID: String
            let signedPrekey: String
            let signedPrekeySignature: String
            let oneTimePrekeys: [String]
        }
        let user = try req.auth.require(User.self)
        let body = try req.content.decode(UploadRequest.self)
        guard let userID = user.id else { throw Abort(.internalServerError) }

        for opk in body.oneTimePrekeys {
            let bundle = PrekeyBundle(
                userID: userID,
                deviceID: body.deviceID,
                signedPrekey: body.signedPrekey,
                signedPrekeySignature: body.signedPrekeySignature,
                oneTimePrekey: opk
            )
            try await bundle.save(on: req.db)
        }
        return .created
    }

    /// Returns a prekey bundle for initiating X3DH with a target user.
    /// Consumes one OPK atomically if available.
    func fetchBundle(req: Request) async throws -> PrekeyBundle.PublicBundle {
        guard let userIDString = req.parameters.get("userID"),
              let userID = UUID(uuidString: userIDString)
        else { throw Abort(.badRequest) }

        guard let targetUser = try await User.find(userID, on: req.db) else {
            throw Abort(.notFound)
        }

        // Fetch and consume one available OPK
        let bundle = try await req.db.transaction { db in
            guard let b = try await PrekeyBundle.query(on: db)
                .filter(\.$user.$id == userID)
                .filter(\.$isConsumed == false)
                .filter(\.$oneTimePrekey != nil)
                .sort(\.$createdAt)
                .first()
            else {
                // Fall back to signed prekey only (no OPK)
                guard let spk = try await PrekeyBundle.query(on: db)
                    .filter(\.$user.$id == userID)
                    .sort(\.$createdAt, .descending)
                    .first()
                else { throw Abort(.notFound, reason: "No prekeys available") }
                return spk
            }
            b.isConsumed = true
            try await b.save(on: db)
            return b
        }

        return PrekeyBundle.PublicBundle(
            userID: userID,
            deviceID: bundle.deviceID,
            identityPublicKey: targetUser.identityPublicKey,
            signedPrekey: bundle.signedPrekey,
            signedPrekeySignature: bundle.signedPrekeySignature,
            oneTimePrekey: bundle.oneTimePrekey
        )
    }
}

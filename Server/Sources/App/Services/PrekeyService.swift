import Vapor
import Fluent

struct PrekeyService {
    let db: Database

    func upload(_ dto: UploadPrekeysDTO, for userId: UUID) async throws {
        // Update signed prekey if provided
        if let sp = dto.signedPrekey {
            try await PrekeyBundle.query(on: db)
                .filter(\.$user.$id == userId)
                .filter(\.$isSigned == true)
                .delete()

            let signedKey = PrekeyBundle(
                userID: userId,
                prekeyId: sp.prekeyId,
                publicKey: sp.publicKey,
                isSigned: true,
                signature: sp.signature
            )
            try await signedKey.save(on: db)
        }

        // Add one-time prekeys
        for otk in dto.onetimePrekeys {
            let key = PrekeyBundle(
                userID: userId,
                prekeyId: otk.prekeyId,
                publicKey: otk.publicKey,
                isSigned: false
            )
            try await key.save(on: db)
        }
    }

    func fetchBundle(for userId: UUID) async throws -> PrekeyBundleResponse {
        guard let user = try await User.find(userId, on: db) else {
            throw Abort(.notFound, reason: "User not found")
        }

        guard let signedPrekey = try await PrekeyBundle.query(on: db)
            .filter(\.$user.$id == userId)
            .filter(\.$isSigned == true)
            .first()
        else {
            throw Abort(.serviceUnavailable, reason: "No signed prekey available for this user")
        }

        // Fetch and consume a one-time prekey if available
        let onetimePrekey = try await PrekeyBundle.query(on: db)
            .filter(\.$user.$id == userId)
            .filter(\.$isSigned == false)
            .filter(\.$consumed == false)
            .first()

        if let otk = onetimePrekey {
            otk.consumed = true
            try await otk.save(on: db)
        }

        return PrekeyBundleResponse(
            userId: try user.requireID(),
            identityKeyPublic: user.identityKeyPublic,
            signedPrekey: SignedPrekeyBundleDTO(
                prekeyId: signedPrekey.prekeyId,
                publicKey: signedPrekey.publicKey,
                signature: signedPrekey.signature ?? ""
            ),
            onetimePrekey: onetimePrekey.map {
                OnetimePrekeyDTO(prekeyId: $0.prekeyId, publicKey: $0.publicKey)
            }
        )
    }
}

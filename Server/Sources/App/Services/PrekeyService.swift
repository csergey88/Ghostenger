import Vapor
import Fluent

struct PrekeyService {
    let db: Database

    // MARK: - Upload

    struct UploadDTO: Content {
        let deviceID: String
        let signedPrekey: String
        let signedPrekeySignature: String
        let oneTimePrekeys: [String]
    }

    func upload(_ dto: UploadDTO, for userID: UUID) async throws {
        for opk in dto.oneTimePrekeys {
            let bundle = PrekeyBundle(
                userID: userID,
                deviceID: dto.deviceID,
                signedPrekey: dto.signedPrekey,
                signedPrekeySignature: dto.signedPrekeySignature,
                oneTimePrekey: opk
            )
            try await bundle.save(on: db)
        }
    }

    // MARK: - Fetch bundle

    func fetchBundle(for userID: UUID) async throws -> PrekeyBundle.PublicBundle {
        guard let targetUser = try await User.find(userID, on: db) else {
            throw Abort(.notFound, reason: "User not found")
        }

        // Atomically fetch and consume one OPK, fall back to signed-prekey-only bundle
        let bundle = try await db.transaction { txDb in
            if let opkBundle = try await PrekeyBundle.query(on: txDb)
                .filter(\.$user.$id == userID)
                .filter(\.$isConsumed == false)
                .filter(\.$oneTimePrekey != nil)
                .sort(\.$createdAt)
                .first()
            {
                opkBundle.isConsumed = true
                try await opkBundle.save(on: txDb)
                return opkBundle
            }

            // No OPK — return the most recent signed prekey
            guard let spk = try await PrekeyBundle.query(on: txDb)
                .filter(\.$user.$id == userID)
                .sort(\.$createdAt, .descending)
                .first()
            else {
                throw Abort(.serviceUnavailable, reason: "No prekeys available for this user")
            }
            return spk
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

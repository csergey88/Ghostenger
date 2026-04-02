import Foundation

final class UserService {
    private let api = APIClient.shared

    func fetchProfile(username: String, token: String) async throws -> UserProfile {
        try await api.get("users/\(username)", token: token)
    }

    func fetchPrekeyBundle(userID: UUID, token: String) async throws -> PrekeyBundleDTO {
        try await api.get("prekeys/\(userID.uuidString)", token: token)
    }

    func uploadPrekeys(
        deviceID: String,
        signedPrekey: String,
        signedPrekeySignature: String,
        oneTimePrekeys: [String],
        token: String
    ) async throws {
        struct UploadBody: Encodable {
            let deviceID: String
            let signedPrekey: String
            let signedPrekeySignature: String
            let oneTimePrekeys: [String]
        }
        try await api.put(
            "prekeys/upload",
            body: UploadBody(
                deviceID: deviceID,
                signedPrekey: signedPrekey,
                signedPrekeySignature: signedPrekeySignature,
                oneTimePrekeys: oneTimePrekeys
            ),
            token: token
        )
    }
}

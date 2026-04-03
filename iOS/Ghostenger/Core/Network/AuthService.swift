import Foundation
import CryptoKit

/// iOS-side auth service — communicates with the Vapor backend.
final class AuthService {
    private let api = APIClient.shared

    struct RegisterResponse: Codable {
        let token: String
        let user: UserProfile
    }

    func register(
        username: String,
        displayName: String,
        password: String,
        identityKeyPair: KeyPair,
        signedPrekeyPair: SignedKeyPair,
        oneTimePrekeys: [String]
    ) async throws -> UserSession {
        struct RegisterBody: Encodable {
            let username: String
            let phoneHash: String
            let password: String
            let identityPublicKey: String
            let displayName: String
            let deviceID: String
            let signedPrekey: String
            let signedPrekeySignature: String
            let oneTimePrekeys: [String]
        }

        let body = RegisterBody(
            username: username,
            phoneHash: sha256Hash(username), // placeholder — use real phone hash
            password: password,
            identityPublicKey: identityKeyPair.publicKey,
            displayName: displayName,
            deviceID: DeviceID.current,
            signedPrekey: signedPrekeyPair.publicKey,
            signedPrekeySignature: signedPrekeyPair.signature,
            oneTimePrekeys: oneTimePrekeys
        )

        let response: RegisterResponse = try await api.post("auth/register", body: body)
        return UserSession(
            userID: response.user.id,
            username: response.user.username,
            displayName: response.user.displayName,
            token: response.token,
            deviceID: DeviceID.current
        )
    }

    func login(username: String, password: String) async throws -> UserSession {
        struct LoginBody: Encodable {
            let username: String
            let password: String
            let deviceID: String
        }

        let body = LoginBody(username: username, password: password, deviceID: DeviceID.current)
        let response: RegisterResponse = try await api.post("auth/login", body: body)

        return UserSession(
            userID: response.user.id,
            username: response.user.username,
            displayName: response.user.displayName,
            token: response.token,
            deviceID: DeviceID.current
        )
    }

    private func sha256Hash(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct UserProfile: Codable {
    let id: UUID
    let username: String
    let displayName: String
    let identityPublicKey: String
    let avatarURL: String?
}

/// Stable per-device identifier stored in Keychain.
enum DeviceID {
    static var current: String {
        if let stored = UserDefaults.standard.string(forKey: "ghost.device.id") {
            return stored
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: "ghost.device.id")
        return new
    }
}

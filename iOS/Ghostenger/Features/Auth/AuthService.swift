import Foundation
import CryptoKit

struct RegisterRequest: Encodable {
    let username: String
    let password: String
    let identityKeyPublic: String
    let signedPrekeyBundle: SignedPrekeyBundleRequest
}

struct SignedPrekeyBundleRequest: Encodable {
    let prekeyId: Int
    let publicKey: String
    let signature: String
}

struct AuthResponse: Decodable {
    let token: String
    let expiresAt: Date
    let userId: String
    let deviceId: String
}

final class AuthService {
    private let api = APIClient.shared

    func register(username: String, password: String) async throws {
        // Generate identity key pair — private key stays on device
        let identityPair = KeyGenerator.generateIdentityKeyPair()
        KeychainStorage.saveString(
            identityPair.privateKeyData.base64EncodedString(),
            for: .identityPrivateKey
        )

        // Generate signed prekey
        let signedPrekeyPair = KeyGenerator.generateEphemeralKeyPair()
        let signature = try KeyGenerator.sign(
            signedPrekeyPair.publicKey.rawRepresentation,
            with: identityPair.privateKey
        )

        let request = RegisterRequest(
            username: username,
            password: password,
            identityKeyPublic: identityPair.publicKeyBase64,
            signedPrekeyBundle: SignedPrekeyBundleRequest(
                prekeyId: 1,
                publicKey: signedPrekeyPair.publicKeyBase64,
                signature: signature.base64EncodedString()
            )
        )

        let response: AuthResponse = try await api.post(path: "auth/register", body: request)
        persistSession(response)
    }

    func login(username: String, password: String) async throws {
        struct LoginRequest: Encodable { let username: String; let password: String }
        let request = LoginRequest(username: username, password: password)
        let response: AuthResponse = try await api.post(path: "auth/login", body: request)
        persistSession(response)
    }

    private func persistSession(_ response: AuthResponse) {
        KeychainStorage.saveString(response.token, for: .authToken)
        APIClient.shared.setAuthToken(response.token)

        // Notify AppState via notification so views update
        NotificationCenter.default.post(
            name: .didSignIn,
            object: nil,
            userInfo: ["token": response.token, "userId": response.userId]
        )
    }
}

extension Notification.Name {
    static let didSignIn = Notification.Name("GhostengerDidSignIn")
    static let didSignOut = Notification.Name("GhostengerDidSignOut")
}

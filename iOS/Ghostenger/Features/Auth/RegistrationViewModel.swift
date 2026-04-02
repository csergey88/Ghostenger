import Foundation

@MainActor
final class RegistrationViewModel: ObservableObject {
    @Published var username = ""
    @Published var displayName = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService = AuthService()
    private let cryptoService = CryptoService()

    func register(appState: AppState) async {
        guard validate() else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Generate identity key pair on device — private key stored in Keychain
            let identityKeyPair = try cryptoService.generateIdentityKeyPair()
            let signedPrekeyPair = try cryptoService.generateSignedPrekey(identityPrivateKey: identityKeyPair.privateKey)
            let oneTimePrekeys = try cryptoService.generateOneTimePrekeys(count: 10)

            let session = try await authService.register(
                username: username,
                displayName: displayName,
                password: password,
                identityKeyPair: identityKeyPair,
                signedPrekeyPair: signedPrekeyPair,
                oneTimePrekeys: oneTimePrekeys
            )
            appState.signIn(session: session)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Registration failed. Please try again."
        }
    }

    private func validate() -> Bool {
        if username.count < 3 {
            errorMessage = "Username must be at least 3 characters"
            return false
        }
        if displayName.isEmpty {
            errorMessage = "Display name is required"
            return false
        }
        if password.count < 8 {
            errorMessage = "Password must be at least 8 characters"
            return false
        }
        if password != confirmPassword {
            errorMessage = "Passwords do not match"
            return false
        }
        return true
    }
}

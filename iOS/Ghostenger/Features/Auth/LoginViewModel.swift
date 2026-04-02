import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService = AuthService()

    func login(appState: AppState) async {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter username and password"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await authService.login(username: username, password: password)
            appState.signIn(session: session)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Login failed. Please try again."
        }
    }
}

import SwiftUI

@Observable
final class LoginViewModel {
    var username = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?

    private let authService = AuthService()

    @MainActor
    func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authService.login(username: username, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

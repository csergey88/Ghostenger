import SwiftUI

@Observable
final class RegisterViewModel {
    var username = ""
    var password = ""
    var confirmPassword = ""
    var isLoading = false
    var errorMessage: String?

    var isValid: Bool {
        username.count >= 3 && password.count >= 8 && password == confirmPassword
    }

    private let authService = AuthService()

    @MainActor
    func register() async {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authService.register(username: username, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

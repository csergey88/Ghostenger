import Foundation
import Combine

/// Global app state — authentication and session lifecycle.
@MainActor
final class AppState: ObservableObject {
    @Published var session: UserSession?
    @Published var isLoading = false

    var isAuthenticated: Bool { session != nil }

    private let keychainService = KeychainService()

    init() {
        restoreSession()
    }

    func signIn(session: UserSession) {
        self.session = session
        keychainService.saveSession(session)
    }

    func signOut() {
        session = nil
        keychainService.clearSession()
    }

    private func restoreSession() {
        session = keychainService.loadSession()
    }
}

struct UserSession: Codable {
    let userID: UUID
    let username: String
    let displayName: String
    let token: String
    let deviceID: String
}

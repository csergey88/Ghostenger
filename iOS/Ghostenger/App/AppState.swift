import SwiftUI

@Observable
final class AppState {
    var isAuthenticated: Bool = false
    var currentUserId: String?
    var authToken: String?

    func signIn(token: String, userId: String) {
        authToken = token
        currentUserId = userId
        isAuthenticated = true
    }

    func signOut() {
        authToken = nil
        currentUserId = nil
        isAuthenticated = false
    }
}

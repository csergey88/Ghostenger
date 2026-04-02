import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
            } else {
                AuthFlow()
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
    }
}

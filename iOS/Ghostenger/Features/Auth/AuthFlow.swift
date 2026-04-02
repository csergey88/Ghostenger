import SwiftUI

struct AuthFlow: View {
    @State private var showingRegistration = false

    var body: some View {
        NavigationStack {
            LoginView(onRegister: { showingRegistration = true })
                .navigationDestination(isPresented: $showingRegistration) {
                    RegistrationView()
                }
        }
    }
}

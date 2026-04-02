import SwiftUI

struct RegistrationView: View {
    @StateObject private var viewModel = RegistrationViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Create Account")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Your keys are generated on this device. The server never sees your private keys.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Group {
                    TextField("Username (3–32 characters)", text: $viewModel.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField("Display Name", text: $viewModel.displayName)

                    SecureField("Password (8+ characters)", text: $viewModel.password)

                    SecureField("Confirm Password", text: $viewModel.confirmPassword)
                }
                .textFieldStyle(.roundedBorder)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task { await viewModel.register(appState: appState) }
                } label: {
                    if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Create Account").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isLoading)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(viewModel.isLoading)
    }
}

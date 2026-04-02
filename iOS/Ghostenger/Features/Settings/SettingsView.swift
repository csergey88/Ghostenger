import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSignOutAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if let session = appState.session {
                        LabeledContent("Username", value: "@\(session.username)")
                        LabeledContent("Display Name", value: session.displayName)
                    }
                }

                Section("Security") {
                    NavigationLink("Encryption Keys") {
                        EncryptionKeysView()
                    }
                    NavigationLink("Active Sessions") {
                        ActiveSessionsView()
                    }
                }

                Section("About") {
                    LabeledContent("Encryption", value: "Signal Protocol (E2EE)")
                    LabeledContent("Transport", value: "TLS 1.3")
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        showingSignOutAlert = true
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Sign Out", role: .destructive) { appState.signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign in again to access your messages.")
            }
        }
    }
}

struct EncryptionKeysView: View {
    @State private var identityKey: String = ""

    var body: some View {
        Form {
            Section("Identity Key (Public)") {
                Text(identityKey.isEmpty ? "Loading..." : identityKey)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Section {
                Text("Your private key is stored securely in the device Keychain and never leaves this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Encryption Keys")
        .task {
            identityKey = (try? CryptoService().publicIdentityKey()) ?? "Unavailable"
        }
    }
}

struct ActiveSessionsView: View {
    var body: some View {
        Form {
            Section {
                Text("Session management coming soon.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Active Sessions")
    }
}

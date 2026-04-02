import SwiftUI

struct ContactsView: View {
    @StateObject private var viewModel = ContactsViewModel()
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.filteredContacts(query: searchText)) { contact in
                    ContactRow(contact: contact) {
                        Task { await viewModel.startConversation(with: contact, session: appState.session) }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search by username")
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "person.badge.plus") {
                        viewModel.showingAdd = true
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAdd) {
                AddContactView(onAdd: { username in
                    Task { await viewModel.addContact(username: username, session: appState.session) }
                })
            }
            .task { await viewModel.load(session: appState.session) }
        }
    }
}

struct ContactRow: View {
    let contact: ContactProfile
    let onMessage: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title)
                .foregroundStyle(.teal)

            VStack(alignment: .leading) {
                Text(contact.displayName).font(.headline)
                Text("@\(contact.username)").font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onMessage) {
                Image(systemName: "message")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

struct AddContactView: View {
    let onAdd: (String) -> Void
    @State private var username = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Username") {
                    TextField("@username", text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(username)
                        dismiss()
                    }
                    .disabled(username.isEmpty)
                }
            }
        }
    }
}

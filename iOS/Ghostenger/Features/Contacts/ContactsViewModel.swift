import Foundation

@MainActor
final class ContactsViewModel: ObservableObject {
    @Published var contacts: [ContactProfile] = []
    @Published var showingAdd = false
    @Published var errorMessage: String?

    private let userService = UserService()
    private let chatService = ChatService()

    func load(session: UserSession?) async {
        // Contacts are stored locally after being looked up by username
        contacts = LocalContactStore.shared.all()
    }

    func addContact(username: String, session: UserSession?) async {
        guard let session else { return }
        do {
            let profile = try await userService.fetchProfile(username: username, token: session.token)
            let contact = ContactProfile(
                id: profile.id,
                username: profile.username,
                displayName: profile.displayName,
                identityPublicKey: profile.identityPublicKey
            )
            LocalContactStore.shared.save(contact)
            contacts = LocalContactStore.shared.all()
        } catch {
            errorMessage = "User not found"
        }
    }

    func startConversation(with contact: ContactProfile, session: UserSession?) async {
        guard let session else { return }
        do {
            _ = try await chatService.createConversation(
                participantIDs: [contact.id],
                token: session.token
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func filteredContacts(query: String) -> [ContactProfile] {
        guard !query.isEmpty else { return contacts }
        return contacts.filter {
            $0.username.localizedCaseInsensitiveContains(query) ||
            $0.displayName.localizedCaseInsensitiveContains(query)
        }
    }
}

struct ContactProfile: Identifiable, Codable {
    let id: UUID
    let username: String
    let displayName: String
    let identityPublicKey: String
}

/// Simple on-device contact store backed by UserDefaults.
/// In production, replace with CoreData for larger contact lists.
final class LocalContactStore {
    static let shared = LocalContactStore()
    private let key = "ghost.contacts"

    func all() -> [ContactProfile] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let contacts = try? JSONDecoder().decode([ContactProfile].self, from: data)
        else { return [] }
        return contacts
    }

    func save(_ contact: ContactProfile) {
        var current = all()
        if !current.contains(where: { $0.id == contact.id }) {
            current.append(contact)
            if let data = try? JSONEncoder().encode(current) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
}

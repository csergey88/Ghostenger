import SwiftUI

struct ConversationItem: Identifiable, Hashable {
    let id: String
    let participantIds: [String]
    let lastMessage: String?
    let createdAt: Date?

    var displayName: String {
        participantIds.first ?? "Unknown"
    }
}

@Observable
final class ChatListViewModel {
    var conversations: [ConversationItem] = []
    var errorMessage: String?

    private let api = APIClient.shared

    func load() async {
        do {
            struct ConversationResponse: Decodable {
                let id: String
                let participantIds: [String]
                let createdAt: Date?
            }
            let list: [ConversationResponse] = try await api.get(path: "contacts/conversations")
            await MainActor.run {
                conversations = list.map {
                    ConversationItem(
                        id: $0.id,
                        participantIds: $0.participantIds,
                        lastMessage: nil,
                        createdAt: $0.createdAt
                    )
                }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

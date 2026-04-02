import Foundation

@MainActor
final class ConversationListViewModel: ObservableObject {
    @Published var conversations: [ConversationSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let chatService = ChatService()

    func load(session: UserSession?) async {
        guard let session else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            conversations = try await chatService.fetchConversations(token: session.token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

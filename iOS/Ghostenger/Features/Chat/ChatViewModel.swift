import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [DecryptedMessage] = []
    @Published var isLoading = false
    @Published var isTyping = false

    private let conversation: ConversationSummary
    private let chatService = ChatService()
    private let cryptoService = CryptoService()
    private var typingTask: Task<Void, Never>?

    init(conversation: ConversationSummary) {
        self.conversation = conversation
    }

    func load(session: UserSession?) async {
        guard let session else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let envelopes = try await chatService.fetchMessages(
                conversationID: conversation.id,
                token: session.token
            )
            messages = envelopes.compactMap { envelope in
                try? cryptoService.decrypt(envelope: envelope, sessionOwnerID: session.userID)
            }
        } catch {
            // Errors surface via UI state in future iteration
        }
    }

    func sendMessage(text: String, session: UserSession?) async {
        guard let session else { return }
        do {
            let envelope = try cryptoService.encrypt(
                plaintext: text,
                conversationID: conversation.id,
                senderID: session.userID
            )
            let sent = try await chatService.sendMessage(envelope: envelope, token: session.token)
            let decrypted = DecryptedMessage(
                id: sent.id,
                senderID: sent.senderID,
                plaintext: text,
                sentAt: sent.sentAt
            )
            messages.append(decrypted)
        } catch {
            // Surface error to user in future iteration
        }
    }

    func sendTypingIndicator(session: UserSession?) {
        typingTask?.cancel()
        typingTask = Task {
            chatService.sendTypingIndicator(conversationID: conversation.id)
        }
    }
}

struct DecryptedMessage: Identifiable {
    let id: UUID
    let senderID: UUID
    let plaintext: String
    let sentAt: Date
}

import SwiftUI

struct MessageItem: Identifiable {
    let id: String
    let senderId: String
    let ciphertext: String
    let isOutgoing: Bool
    let createdAt: Date?
}

@Observable
final class ChatViewModel {
    let conversationId: String
    var messages: [MessageItem] = []
    var draftText = ""
    var errorMessage: String?

    private let api = APIClient.shared

    init(conversationId: String) {
        self.conversationId = conversationId
    }

    func load() async {
        do {
            struct MessageResponse: Decodable {
                let id: String
                let senderId: String
                let ciphertext: String
                let createdAt: Date?
            }
            let list: [MessageResponse] = try await api.get(path: "messages/\(conversationId)")
            await MainActor.run {
                messages = list.map {
                    MessageItem(
                        id: $0.id,
                        senderId: $0.senderId,
                        ciphertext: $0.ciphertext,
                        isOutgoing: false, // TODO: compare with current user ID
                        createdAt: $0.createdAt
                    )
                }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    func send() async {
        let text = draftText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        // TODO: encrypt with Double Ratchet before sending
        // For now, send a placeholder to validate the flow
        let ciphertext = Data(text.utf8).base64EncodedString()

        struct SendDTO: Encodable {
            let conversationId: String
            let ciphertext: String
            let messageType: Int
        }

        do {
            let dto = SendDTO(conversationId: conversationId, ciphertext: ciphertext, messageType: 0)
            let _: MessageItem = try await {
                struct MessageResponse: Decodable {
                    let id: String; let senderId: String; let ciphertext: String; let createdAt: Date?
                }
                let resp: MessageResponse = try await api.post(path: "messages", body: dto, authenticated: true)
                return MessageItem(id: resp.id, senderId: resp.senderId, ciphertext: resp.ciphertext, isOutgoing: true, createdAt: resp.createdAt)
            }()
            await MainActor.run { draftText = "" }
            await load()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

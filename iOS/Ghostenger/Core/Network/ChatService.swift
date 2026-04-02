import Foundation

final class ChatService {
    private let api = APIClient.shared
    private let ws = WebSocketClient.shared

    // MARK: - Conversations

    func fetchConversations(token: String) async throws -> [ConversationSummary] {
        try await api.get("conversations", token: token)
    }

    func createConversation(participantIDs: [UUID], name: String? = nil, token: String) async throws -> ConversationSummary {
        struct CreateBody: Encodable {
            let participantIDs: [UUID]
            let name: String?
        }
        return try await api.post("conversations", body: CreateBody(participantIDs: participantIDs, name: name), token: token)
    }

    // MARK: - Messages

    func fetchMessages(conversationID: UUID, before: Date? = nil, token: String) async throws -> [MessageEnvelopeServerDTO] {
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: "50")]
        if let before {
            let iso = ISO8601DateFormatter().string(from: before)
            items.append(URLQueryItem(name: "before", value: iso))
        }
        return try await api.get("conversations/\(conversationID.uuidString)/messages", token: token, queryItems: items)
    }

    func sendMessage(envelope: MessageEnvelopeDTO, token: String) async throws -> MessageEnvelopeServerDTO {
        try await api.post("messages", body: envelope, token: token)
    }

    // MARK: - Real-time

    func sendTypingIndicator(conversationID: UUID) {
        ws.send(WSOutgoing(type: "typing", payload: ["conversationID": conversationID.uuidString]))
    }
}

// MARK: - DTOs

struct ConversationSummary: Codable, Identifiable, Hashable {
    let id: UUID
    let type: String
    let name: String?
    let updatedAt: Date?
}

struct MessageEnvelopeDTO: Encodable {
    let conversationID: UUID
    let ciphertext: String
    let ratchetHeader: String
    let recipientDeviceIDs: [String]
    let messageType: String
}

struct MessageEnvelopeServerDTO: Decodable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    let ciphertext: String
    let ratchetHeader: String
    let messageType: String
    let sentAt: Date
}

struct PrekeyBundleDTO: Decodable {
    let userID: UUID
    let deviceID: String
    let identityPublicKey: String
    let signedPrekey: String
    let signedPrekeySignature: String
    let oneTimePrekey: String?
}

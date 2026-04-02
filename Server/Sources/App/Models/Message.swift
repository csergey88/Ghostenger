import Fluent
import Vapor

/// Server stores ONLY ciphertext — the plaintext is never accessible to the server.
final class Message: Model, @unchecked Sendable {
    static let schema = "messages"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "conversation_id")
    var conversation: Conversation

    @Field(key: "sender_id")
    var senderId: UUID

    /// Base64-encoded Double Ratchet ciphertext.
    @Field(key: "ciphertext")
    var ciphertext: String

    /// Ratchet message type: 0 = normal, 1 = prekey message (first message in session).
    @Field(key: "message_type")
    var messageType: Int

    @Field(key: "delivered")
    var delivered: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        conversationID: UUID,
        senderId: UUID,
        ciphertext: String,
        messageType: Int = 0
    ) {
        self.id = id
        self.$conversation.id = conversationID
        self.senderId = senderId
        self.ciphertext = ciphertext
        self.messageType = messageType
        self.delivered = false
    }
}

// MARK: - DTOs

struct SendMessageDTO: Content {
    let conversationId: UUID
    let ciphertext: String
    let messageType: Int
}

struct MessageResponse: Content {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    let ciphertext: String
    let messageType: Int
    let delivered: Bool
    let createdAt: Date?
}

extension Message {
    func toResponse() throws -> MessageResponse {
        MessageResponse(
            id: try requireID(),
            conversationId: $conversation.id,
            senderId: senderId,
            ciphertext: ciphertext,
            messageType: messageType,
            delivered: delivered,
            createdAt: createdAt
        )
    }
}

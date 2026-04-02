import Fluent
import Vapor

/// Stores only ciphertext — the server cannot decrypt message content.
final class Message: Model, Content, @unchecked Sendable {
    static let schema = "messages"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "conversation_id")
    var conversation: Conversation

    @Parent(key: "sender_id")
    var sender: User

    /// Double Ratchet ciphertext (base64)
    @Field(key: "ciphertext")
    var ciphertext: String

    /// Ratchet header containing the ratchet public key and message index (base64)
    @Field(key: "ratchet_header")
    var ratchetHeader: String

    /// Recipient device IDs this message was encrypted for
    @Field(key: "recipient_device_ids")
    var recipientDeviceIDs: [String]

    @Field(key: "message_type")
    var messageType: String  // "text", "image", "file", "key_exchange"

    @Field(key: "is_delivered")
    var isDelivered: Bool

    @Field(key: "is_read")
    var isRead: Bool

    @Timestamp(key: "sent_at", on: .create)
    var sentAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        conversationID: UUID,
        senderID: UUID,
        ciphertext: String,
        ratchetHeader: String,
        recipientDeviceIDs: [String],
        messageType: String = "text"
    ) {
        self.id = id
        self.$conversation.id = conversationID
        self.$sender.id = senderID
        self.ciphertext = ciphertext
        self.ratchetHeader = ratchetHeader
        self.recipientDeviceIDs = recipientDeviceIDs
        self.messageType = messageType
        self.isDelivered = false
        self.isRead = false
    }
}

// MARK: - DTO

extension Message {
    struct Envelope: Content {
        let id: UUID
        let conversationID: UUID
        let senderID: UUID
        let ciphertext: String
        let ratchetHeader: String
        let messageType: String
        let sentAt: Date
    }

    var envelope: Envelope {
        .init(
            id: id!,
            conversationID: $conversation.id,
            senderID: $sender.id,
            ciphertext: ciphertext,
            ratchetHeader: ratchetHeader,
            messageType: messageType,
            sentAt: sentAt ?? Date()
        )
    }
}

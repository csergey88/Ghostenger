import Vapor
import Fluent
import Redis

struct MessageService {
    let db: Database
    let redis: RedisClient

    // MARK: - DTOs

    struct SendMessageDTO: Content {
        let conversationID: UUID
        let ciphertext: String
        let ratchetHeader: String
        let recipientDeviceIDs: [String]
        let messageType: String?
    }

    // MARK: - Send

    func send(_ dto: SendMessageDTO, from senderID: UUID) async throws -> Message.Envelope {
        // Verify sender is a participant
        guard try await ConversationParticipant.query(on: db)
            .filter(\.$conversation.$id == dto.conversationID)
            .filter(\.$user.$id == senderID)
            .first() != nil
        else {
            throw Abort(.forbidden, reason: "You are not a participant in this conversation")
        }

        let message = Message(
            conversationID: dto.conversationID,
            senderID: senderID,
            ciphertext: dto.ciphertext,
            ratchetHeader: dto.ratchetHeader,
            recipientDeviceIDs: dto.recipientDeviceIDs,
            messageType: dto.messageType ?? "text"
        )
        try await message.save(on: db)

        // Fan out to recipients via Redis pubsub
        let fanout = MessageFanoutService(redis: redis)
        await fanout.fanout(message: message.envelope, to: dto.conversationID, on: db)

        return message.envelope
    }

    // MARK: - List

    func list(conversationID: UUID, requestingUserID: UUID, before: Date? = nil, limit: Int = 50) async throws -> [Message.Envelope] {
        guard try await ConversationParticipant.query(on: db)
            .filter(\.$conversation.$id == conversationID)
            .filter(\.$user.$id == requestingUserID)
            .first() != nil
        else {
            throw Abort(.forbidden)
        }

        var query = Message.query(on: db)
            .filter(\.$conversation.$id == conversationID)
            .sort(\.$sentAt, .descending)
            .limit(min(limit, 100))

        if let before {
            query = query.filter(\.$sentAt < before)
        }

        let messages = try await query.all()
        return messages.map(\.envelope)
    }
}

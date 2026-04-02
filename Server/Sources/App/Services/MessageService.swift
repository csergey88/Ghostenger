import Vapor
import Fluent
import Redis

struct MessageService {
    let db: Database
    let redis: RedisClient

    func send(_ dto: SendMessageDTO, from senderId: UUID) async throws -> MessageResponse {
        // Verify sender is a participant
        guard let conversation = try await Conversation.find(dto.conversationId, on: db) else {
            throw Abort(.notFound, reason: "Conversation not found")
        }
        guard conversation.containsUser(senderId) else {
            throw Abort(.forbidden, reason: "You are not a participant in this conversation")
        }

        let message = Message(
            conversationID: dto.conversationId,
            senderId: senderId,
            ciphertext: dto.ciphertext,
            messageType: dto.messageType
        )
        try await message.save(on: db)

        // Fan out to recipient(s) via Redis pubsub
        let response = try message.toResponse()
        try await fanout(message: response, in: conversation, from: senderId)

        return response
    }

    func list(conversationId: UUID, requestingUserId: UUID) async throws -> [MessageResponse] {
        guard let conversation = try await Conversation.find(conversationId, on: db) else {
            throw Abort(.notFound, reason: "Conversation not found")
        }
        guard conversation.containsUser(requestingUserId) else {
            throw Abort(.forbidden)
        }

        let messages = try await Message.query(on: db)
            .filter(\.$conversation.$id == conversationId)
            .sort(\.$createdAt, .ascending)
            .all()

        return try messages.map { try $0.toResponse() }
    }

    private func fanout(message: MessageResponse, in conversation: Conversation, from senderId: UUID) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)
        let json = String(data: data, encoding: .utf8) ?? "{}"

        let envelope = #"{"type":"message.new","payload":\#(json)}"#

        let recipientIds = conversation.participantIds
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }
            .filter { $0 != senderId }

        for recipientId in recipientIds {
            let channel = RedisChannelName("ghost:pubsub:user:\(recipientId.uuidString)")
            _ = try await redis.publish(envelope, to: channel)
        }
    }
}

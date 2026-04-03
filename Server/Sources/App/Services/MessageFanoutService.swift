import Vapor
import Redis

/// Fans out a message envelope to all conversation participants via Redis PubSub.
/// WebSocket connections subscribed to `ghost:pubsub:user:{userID}` will receive it.
struct MessageFanoutService {
    let redis: RedisClient

    func fanout(message: Message.Envelope, to conversationID: UUID, on db: Database) async {
        do {
            let participants = try await ConversationParticipant.query(on: db)
                .filter(\.$conversation.$id == conversationID)
                .all()

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(message)
            let json = String(data: data, encoding: .utf8) ?? ""

            let envelope = #"{"type":"message.new","payload":\#(json)}"#

            for participant in participants {
                let channel = RedisChannelName("ghost:pubsub:user:\(participant.$user.id.uuidString)")
                _ = try await redis.publish(RESPValue(from: envelope), to: channel)
            }
        } catch {
            // Fanout failures are non-fatal — client will fetch via REST on reconnect
        }
    }
}

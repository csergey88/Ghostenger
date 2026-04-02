import Vapor
import Redis

/// Handles a single authenticated WebSocket connection.
/// Subscribes to the user's Redis pubsub channel and forwards incoming server events.
actor WebSocketHandler {
    func handle(req: Request, ws: WebSocket) async {
        guard let payload = try? req.authPayload,
              let userId = try? payload.userId
        else {
            try? await ws.close(code: .policyViolation)
            return
        }

        let channelName = "ghost:pubsub:user:\(userId.uuidString)"

        // Update presence
        await updatePresence(userId: userId, online: true, redis: req.redis)

        // Subscribe to Redis pubsub and forward messages to WebSocket
        do {
            try await req.redis.subscribe(
                to: RedisChannelName(channelName),
                messageReceiver: { _, message in
                    guard case .bulkString(let bytes) = message,
                          let text = bytes.flatMap({ String(bytes: $0, encoding: .utf8) })
                    else { return }
                    ws.send(text)
                },
                onSubscribe: nil,
                onUnsubscribe: nil
            )
        } catch {
            req.logger.error("WebSocket Redis subscribe failed: \(error)")
        }

        ws.onText { [weak self] _, text in
            await self?.handleIncoming(text: text, userId: userId, req: req, ws: ws)
        }

        ws.onClose.whenComplete { [weak self] _ in
            Task {
                await self?.updatePresence(userId: userId, online: false, redis: req.redis)
                try? await req.redis.unsubscribe(from: RedisChannelName(channelName))
            }
        }
    }

    private func handleIncoming(text: String, userId: UUID, req: Request, ws: WebSocket) async {
        struct Envelope: Decodable {
            let type: String
            let id: String?
        }
        guard let data = text.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data)
        else {
            ws.send(#"{"type":"error","payload":{"message":"Invalid JSON"}}"#)
            return
        }

        switch envelope.type {
        case "ping":
            ws.send(#"{"type":"pong"}"#)
        case "presence.update":
            await updatePresence(userId: userId, online: true, redis: req.redis)
        default:
            req.logger.debug("Unhandled WS message type: \(envelope.type)")
        }
    }

    private func updatePresence(userId: UUID, online: Bool, redis: RedisClient) async {
        let key = RedisKey("ghost:presence:\(userId.uuidString)")
        let value = online ? "online" : "offline"
        _ = try? await redis.set(key, to: value)
        if online {
            _ = try? await redis.expire(key, after: .init(.seconds(300)))
        }
    }
}

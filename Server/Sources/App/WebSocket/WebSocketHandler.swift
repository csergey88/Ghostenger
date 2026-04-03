import Vapor
import Redis

/// Manages persistent WebSocket connections.
/// Each authenticated client maintains one connection.
/// Incoming Redis PubSub messages for the user are forwarded over the socket.
actor WebSocketHandler {
    // userID -> [WebSocket]
    private var connections: [UUID: [WebSocket]] = [:]

    func handle(req: Request, ws: WebSocket) async {
        let user = try? req.auth.require(User.self)
        guard let userID = user?.id else {
            try? await ws.close(code: .policyViolation)
            return
        }

        await registerConnection(ws, for: userID)

        // Subscribe to this user's Redis channel
        Task {
            await subscribeToRedis(userID: userID, ws: ws, redis: req.application.redis)
        }

        ws.onText { [weak self] ws, text in
            await self?.handleIncoming(text: text, from: userID, ws: ws, req: req)
        }

        ws.onClose.whenComplete { [weak self] _ in
            Task { await self?.removeConnection(ws, for: userID) }
        }

        // Send connected ack
        let ack = WSEnvelope(type: "connected", payload: ["userID": userID.uuidString])
        if let data = try? JSONEncoder().encode(ack),
           let json = String(data: data, encoding: .utf8) {
            try? await ws.send(json)
        }
    }

    // MARK: - Connection registry

    private func registerConnection(_ ws: WebSocket, for userID: UUID) {
        connections[userID, default: []].append(ws)
    }

    private func removeConnection(_ ws: WebSocket, for userID: UUID) {
        connections[userID]?.removeAll { $0 === ws }
        if connections[userID]?.isEmpty == true {
            connections.removeValue(forKey: userID)
        }
    }

    // MARK: - Redis subscription

    private func subscribeToRedis(userID: UUID, ws: WebSocket, redis: Application.Redis) async {
        let channel = RedisChannelName("ghost:pubsub:user:\(userID.uuidString)")
        do {
            try await redis.subscribe(
                to: [channel],
                messageReceiver: { _, message in
                    guard case .bulkString(let buffer) = message,
                          let text = buffer.map({ String(buffer: $0) }) else { return }
                    Task {
                        try? await ws.send(text)
                    }
                },
                onSubscribe: nil,
                onUnsubscribe: nil
            )
        } catch {
            // Redis subscription failed — client will poll REST on reconnect
        }
    }

    // MARK: - Incoming messages

    private func handleIncoming(text: String, from userID: UUID, ws: WebSocket, req: Request) async {
        guard let data = text.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(WSEnvelope.self, from: data)
        else { return }

        switch envelope.type {
        case "ping":
            let pong = WSEnvelope(type: "pong", payload: [:])
            if let d = try? JSONEncoder().encode(pong),
               let json = String(d, encoding: .utf8) {
                try? await ws.send(json)
            }

        case "typing":
            await broadcastTyping(from: userID, payload: envelope.payload, req: req)

        case "message.ack":
            if let msgIDString = envelope.payload["messageID"],
               let msgID = UUID(uuidString: msgIDString),
               let message = try? await Message.find(msgID, on: req.db) {
                message.isDelivered = true
                try? await message.save(on: req.db)
            }

        default:
            break
        }
    }

    private func broadcastTyping(from userID: UUID, payload: [String: String], req: Request) async {
        guard let convIDString = payload["conversationID"],
              let convID = UUID(uuidString: convIDString)
        else { return }

        // Set typing indicator in Redis with 5s TTL
        let key = RedisKey("ghost:typing:\(convID.uuidString):\(userID.uuidString)")
        _ = try? await req.redis.set(key, to: "1")
        _ = try? await req.redis.expire(key, after: .seconds(5))

        // Broadcast typing event to other participants
        let typingEnvelope = TypingEnvelope(
            type: "typing",
            conversationID: convIDString,
            userID: userID.uuidString
        )
        guard let data = try? JSONEncoder().encode(typingEnvelope),
              let json = String(data: data, encoding: .utf8)
        else { return }

        do {
            let participants = try await ConversationParticipant.query(on: req.db)
                .filter(\.$conversation.$id == convID)
                .all()
            for p in participants where p.$user.id != userID {
                let channel = RedisChannelName("ghost:pubsub:user:\(p.$user.id.uuidString)")
                _ = try? await req.redis.publish(RESPValue(from: json), to: channel)
            }
        } catch {}
    }
}

// MARK: - Wire types

struct WSEnvelope: Codable {
    let type: String
    let payload: [String: String]
}

struct TypingEnvelope: Codable {
    let type: String
    let conversationID: String
    let userID: String
}

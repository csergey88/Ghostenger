import Vapor

struct MessageController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let msgs = routes.grouped("messages")
        msgs.post(use: send)
        msgs.put(":messageID", "delivered", use: markDelivered)
        msgs.put(":messageID", "read", use: markRead)
    }

    func send(req: Request) async throws -> Message.Envelope {
        struct SendRequest: Content {
            let conversationID: UUID
            let ciphertext: String
            let ratchetHeader: String
            let recipientDeviceIDs: [String]
            let messageType: String?
        }
        let user = try req.auth.require(User.self)
        guard let senderID = user.id else { throw Abort(.internalServerError) }

        let body = try req.content.decode(SendRequest.self)

        // Verify sender is participant
        guard try await ConversationParticipant.query(on: req.db)
            .filter(\.$conversation.$id == body.conversationID)
            .filter(\.$user.$id == senderID)
            .first() != nil
        else { throw Abort(.forbidden) }

        let message = Message(
            conversationID: body.conversationID,
            senderID: senderID,
            ciphertext: body.ciphertext,
            ratchetHeader: body.ratchetHeader,
            recipientDeviceIDs: body.recipientDeviceIDs,
            messageType: body.messageType ?? "text"
        )
        try await message.save(on: req.db)

        // Fan out via Redis pubsub
        let service = MessageFanoutService(redis: req.redis)
        await service.fanout(message: message.envelope, to: body.conversationID, on: req.db)

        return message.envelope
    }

    func markDelivered(req: Request) async throws -> HTTPStatus {
        try await updateStatus(req: req, delivered: true, read: nil)
    }

    func markRead(req: Request) async throws -> HTTPStatus {
        try await updateStatus(req: req, delivered: nil, read: true)
    }

    private func updateStatus(req: Request, delivered: Bool?, read: Bool?) async throws -> HTTPStatus {
        guard let msgIDString = req.parameters.get("messageID"),
              let msgID = UUID(uuidString: msgIDString)
        else { throw Abort(.badRequest) }

        guard let message = try await Message.find(msgID, on: req.db) else {
            throw Abort(.notFound)
        }
        if let d = delivered { message.isDelivered = d }
        if let r = read { message.isRead = r }
        try await message.save(on: req.db)
        return .ok
    }
}

import XCTVapor
@testable import App

final class ConversationTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    // MARK: - Helpers

    private func registerUser(username: String, displayName: String = "Test") async throws -> String {
        let body: [String: Any] = [
            "username": username,
            "phoneHash": "\(username)hash",
            "password": "SecurePass123",
            "identityPublicKey": "aGVsbG8gd29ybGQ=",
            "displayName": displayName,
            "deviceID": "device-\(username)",
            "signedPrekey": "c2lnbmVkUHJla2V5",
            "signedPrekeySignature": "c2lnbmF0dXJl",
            "oneTimePrekeys": ["b3RrMQ==", "b3RrMg=="]
        ]
        var token = ""
        try await app.test(.POST, "/api/v1/auth/register") { req in
            try req.content.encode(body)
        } afterResponse: { res async in
            let response = try? res.content.decode(AuthService.AuthResponse.self)
            token = response?.token ?? ""
        }
        return token
    }

    // MARK: - Tests

    func testListConversationsEmpty() async throws {
        let token = try await registerUser(username: "convuser1")

        try await app.test(.GET, "/api/v1/conversations") { req in
            req.headers.bearerAuthorization = .init(token: token)
        } afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            let conversations = try? res.content.decode([ConversationSummary].self)
            XCTAssertEqual(conversations?.count, 0)
        }
    }

    func testCreateConversation() async throws {
        let token1 = try await registerUser(username: "convuser2a")
        let token2 = try await registerUser(username: "convuser2b")

        // Get user2's ID
        var user2ID: UUID?
        try await app.test(.GET, "/api/v1/users/convuser2b") { req in
            req.headers.bearerAuthorization = .init(token: token1)
        } afterResponse: { res async in
            let profile = try? res.content.decode(User.PublicProfile.self)
            user2ID = profile?.id
        }

        guard let participantID = user2ID else {
            XCTFail("Could not fetch user2 profile")
            return
        }

        let createBody: [String: Any] = ["participantIDs": [participantID.uuidString]]
        try await app.test(.POST, "/api/v1/conversations") { req in
            req.headers.bearerAuthorization = .init(token: token1)
            try req.content.encode(createBody)
        } afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            let conv = try? res.content.decode(ConversationSummary.self)
            XCTAssertNotNil(conv?.id)
            XCTAssertEqual(conv?.type, "direct")
        }
    }

    func testSendAndListMessages() async throws {
        let token1 = try await registerUser(username: "msguser1")
        let token2 = try await registerUser(username: "msguser2")

        var user2ID: UUID?
        try await app.test(.GET, "/api/v1/users/msguser2") { req in
            req.headers.bearerAuthorization = .init(token: token1)
        } afterResponse: { res async in
            let profile = try? res.content.decode(User.PublicProfile.self)
            user2ID = profile?.id
        }
        guard let participantID = user2ID else {
            XCTFail("Could not fetch user2 profile")
            return
        }

        // Create conversation
        var convID: UUID?
        let createBody: [String: Any] = ["participantIDs": [participantID.uuidString]]
        try await app.test(.POST, "/api/v1/conversations") { req in
            req.headers.bearerAuthorization = .init(token: token1)
            try req.content.encode(createBody)
        } afterResponse: { res async in
            let conv = try? res.content.decode(ConversationSummary.self)
            convID = conv?.id
        }

        guard let conversationID = convID else {
            XCTFail("Conversation not created")
            return
        }

        // Send message
        let msgBody: [String: Any] = [
            "conversationID": conversationID.uuidString,
            "ciphertext": "dGVzdGNpcGhlcg==",
            "ratchetHeader": "cmF0Y2hldEhlYWRlcg==",
            "recipientDeviceIDs": ["device-msguser2"],
            "messageType": "text"
        ]
        try await app.test(.POST, "/api/v1/messages") { req in
            req.headers.bearerAuthorization = .init(token: token1)
            try req.content.encode(msgBody)
        } afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            let envelope = try? res.content.decode(Message.Envelope.self)
            XCTAssertEqual(envelope?.ciphertext, "dGVzdGNpcGhlcg==")
        }

        // List messages
        try await app.test(.GET, "/api/v1/conversations/\(conversationID.uuidString)/messages") { req in
            req.headers.bearerAuthorization = .init(token: token1)
        } afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            let messages = try? res.content.decode([Message.Envelope].self)
            XCTAssertEqual(messages?.count, 1)
        }
    }

    func testForbiddenMessageToNonParticipant() async throws {
        let token1 = try await registerUser(username: "nonpart1")
        let token2 = try await registerUser(username: "nonpart2")
        let token3 = try await registerUser(username: "nonpart3")

        var user2ID: UUID?
        try await app.test(.GET, "/api/v1/users/nonpart2") { req in
            req.headers.bearerAuthorization = .init(token: token1)
        } afterResponse: { res async in
            user2ID = (try? res.content.decode(User.PublicProfile.self))?.id
        }
        guard let participantID = user2ID else { XCTFail(); return }

        var convID: UUID?
        let createBody: [String: Any] = ["participantIDs": [participantID.uuidString]]
        try await app.test(.POST, "/api/v1/conversations") { req in
            req.headers.bearerAuthorization = .init(token: token1)
            try req.content.encode(createBody)
        } afterResponse: { res async in
            convID = (try? res.content.decode(ConversationSummary.self))?.id
        }
        guard let conversationID = convID else { XCTFail(); return }

        // User3 tries to send to a conversation they're not in
        let msgBody: [String: Any] = [
            "conversationID": conversationID.uuidString,
            "ciphertext": "aGFja2Vy",
            "ratchetHeader": "cmF0Y2hldA==",
            "recipientDeviceIDs": ["device-nonpart2"],
            "messageType": "text"
        ]
        try await app.test(.POST, "/api/v1/messages") { req in
            req.headers.bearerAuthorization = .init(token: token3)
            try req.content.encode(msgBody)
        } afterResponse: { res async in
            XCTAssertEqual(res.status, .forbidden)
        }
    }
}

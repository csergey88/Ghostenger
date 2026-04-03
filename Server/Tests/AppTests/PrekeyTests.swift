import XCTVapor
@testable import App

final class PrekeyTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    private func registerUser(username: String) async throws -> (token: String, userID: UUID) {
        let body: [String: Any] = [
            "username": username,
            "phoneHash": "\(username)hash",
            "password": "SecurePass123",
            "identityPublicKey": "aWRlbnRpdHlLZXk=",
            "displayName": "Test User",
            "deviceID": "device-\(username)",
            "signedPrekey": "c2lnbmVkUHJla2V5",
            "signedPrekeySignature": "c2lnbmF0dXJl",
            "oneTimePrekeys": ["b3RrMQ==", "b3RrMg==", "b3RrMw=="]
        ]
        var token = ""
        var userID = UUID()
        try await app.test(.POST, "/api/v1/auth/register") { req in
            try req.content.encode(body)
        } afterResponse: { res async in
            let response = try? res.content.decode(AuthService.AuthResponse.self)
            token = response?.token ?? ""
            userID = response?.user.id ?? UUID()
        }
        return (token, userID)
    }

    func testFetchPrekeyBundle() async throws {
        let (token1, _) = try await registerUser(username: "prekeyuser1")
        let (_, user2ID) = try await registerUser(username: "prekeyuser2")

        try await app.test(.GET, "/api/v1/prekeys/\(user2ID.uuidString)") { req in
            req.headers.bearerAuthorization = .init(token: token1)
        } afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            let bundle = try? res.content.decode(PrekeyBundle.PublicBundle.self)
            XCTAssertEqual(bundle?.userID, user2ID)
            XCTAssertFalse(bundle?.signedPrekey.isEmpty ?? true)
            XCTAssertFalse(bundle?.identityPublicKey.isEmpty ?? true)
        }
    }

    func testUploadPrekeys() async throws {
        let (token, _) = try await registerUser(username: "prekeyupload1")

        let uploadBody: [String: Any] = [
            "deviceID": "device-prekeyupload1",
            "signedPrekey": "bmV3U2lnbmVkUHJla2V5",
            "signedPrekeySignature": "bmV3U2lnbmF0dXJl",
            "oneTimePrekeys": ["bmV3T1BLMQ==", "bmV3T1BLMg=="]
        ]
        try await app.test(.POST, "/api/v1/prekeys/upload") { req in
            req.headers.bearerAuthorization = .init(token: token)
            try req.content.encode(uploadBody)
        } afterResponse: { res async in
            XCTAssertEqual(res.status, .created)
        }
    }

    func testFetchNonExistentUser() async throws {
        let (token, _) = try await registerUser(username: "prekeyuser3")
        let fakeID = UUID()

        try await app.test(.GET, "/api/v1/prekeys/\(fakeID.uuidString)") { req in
            req.headers.bearerAuthorization = .init(token: token)
        } afterResponse: { res async in
            XCTAssertEqual(res.status, .notFound)
        }
    }
}

import XCTVapor
@testable import App

final class AuthTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func testRegisterAndLogin() async throws {
        let registerBody: [String: Any] = [
            "username": "testuser",
            "phoneHash": "abc123hash",
            "password": "SecurePass123",
            "identityPublicKey": "base64encodedpublickey==",
            "displayName": "Test User",
            "deviceID": "device-uuid-001",
            "signedPrekey": "base64signedprekey==",
            "signedPrekeySignature": "base64signature==",
            "oneTimePrekeys": ["opk1==", "opk2=="]
        ]

        try await app.test(.POST, "/api/v1/auth/register") { req in
            try req.content.encode(registerBody)
        } afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            let body = try? res.content.decode(AuthService.AuthResponse.self)
            XCTAssertNotNil(body?.token)
            XCTAssertEqual(body?.user.username, "testuser")
        }
    }
}

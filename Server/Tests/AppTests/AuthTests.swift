import XCTVapor
@testable import App

final class AuthTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = Application(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.autoRevert()
        app.shutdown()
    }

    func testRegisterAndLogin() async throws {
        let registerBody = RegisterDTO(
            username: "testuser",
            password: "password123",
            identityKeyPublic: "dGVzdGtleQ==",
            signedPrekeyBundle: SignedPrekeyBundleDTO(
                prekeyId: 1,
                publicKey: "cHVibGlja2V5",
                signature: "c2lnbmF0dXJl"
            )
        )

        try app.test(.POST, "/api/v1/auth/register", beforeRequest: { req in
            try req.content.encode(registerBody)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let token = try res.content.decode(TokenResponse.self)
            XCTAssertFalse(token.token.isEmpty)
        })

        let loginBody = LoginDTO(username: "testuser", password: "password123")
        try app.test(.POST, "/api/v1/auth/login", beforeRequest: { req in
            try req.content.encode(loginBody)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
        })
    }

    func testLoginWithWrongPassword() async throws {
        try app.test(.POST, "/api/v1/auth/login", beforeRequest: { req in
            try req.content.encode(LoginDTO(username: "nobody", password: "wrong"))
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .unauthorized)
        })
    }
}

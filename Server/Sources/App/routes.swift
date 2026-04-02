import Vapor

func routes(_ app: Application) throws {
    // Health check
    app.get("health") { _ in ["status": "ok"] }

    // API v1
    let api = app.grouped("api", "v1")

    // Auth — no JWT required
    let authController = AuthController()
    try api.register(collection: authController)

    // Authenticated routes
    let protected = api.grouped(JWTAuthMiddleware())

    let messageController = MessageController()
    try protected.register(collection: messageController)

    let contactController = ContactController()
    try protected.register(collection: contactController)

    let prekeyController = PrekeyController()
    try protected.register(collection: prekeyController)

    // WebSocket
    let wsHandler = WebSocketHandler()
    protected.webSocket("ws") { req, ws in
        await wsHandler.handle(req: req, ws: ws)
    }
}

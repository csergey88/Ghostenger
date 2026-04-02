import Vapor

func routes(_ app: Application) throws {
    // Health check
    app.get("health") { _ in ["status": "ok"] }

    // API v1
    let api = app.grouped("api", "v1")

    // Auth — public
    let authController = AuthController()
    try api.register(collection: authController)

    // Authenticated routes
    let protected = api.grouped(JWTAuthMiddleware())

    let userController = UserController()
    try protected.register(collection: userController)

    let conversationController = ConversationController()
    try protected.register(collection: conversationController)

    let messageController = MessageController()
    try protected.register(collection: messageController)

    let prekeyController = PrekeyController()
    try protected.register(collection: prekeyController)

    // WebSocket
    let wsHandler = WebSocketHandler()
    protected.webSocket("ws") { req, ws in
        await wsHandler.handle(req: req, ws: ws)
    }
}

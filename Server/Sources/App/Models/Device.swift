import Fluent
import Vapor

final class Device: Model, Content, @unchecked Sendable {
    static let schema = "devices"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    /// Unique device identifier generated client-side
    @Field(key: "device_id")
    var deviceID: String

    /// APNs push token (optional)
    @OptionalField(key: "push_token")
    var pushToken: String?

    @Field(key: "platform")
    var platform: String  // "ios"

    @Timestamp(key: "last_seen_at", on: .update)
    var lastSeenAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, userID: UUID, deviceID: String, platform: String, pushToken: String? = nil) {
        self.id = id
        self.$user.id = userID
        self.deviceID = deviceID
        self.platform = platform
        self.pushToken = pushToken
    }
}

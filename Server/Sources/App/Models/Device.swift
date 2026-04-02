import Fluent
import Vapor

final class Device: Model, @unchecked Sendable {
    static let schema = "devices"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "device_name")
    var deviceName: String

    /// APNs push notification token (optional).
    @OptionalField(key: "push_token")
    var pushToken: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "last_seen_at", on: .update)
    var lastSeenAt: Date?

    init() {}

    init(id: UUID? = nil, userID: UUID, deviceName: String, pushToken: String? = nil) {
        self.id = id
        self.$user.id = userID
        self.deviceName = deviceName
        self.pushToken = pushToken
    }
}

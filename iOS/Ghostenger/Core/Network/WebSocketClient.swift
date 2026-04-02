import Foundation

enum WebSocketEvent {
    case message(type: String, payload: [String: Any])
    case connected
    case disconnected(Error?)
}

final class WebSocketClient {
    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)

    #if DEBUG
    private let wsURL = URL(string: "ws://localhost:8080/api/v1/ws")!
    #else
    private let wsURL = URL(string: "wss://api.ghostenger.app/api/v1/ws")!
    #endif

    var onEvent: ((WebSocketEvent) -> Void)?

    func connect(authToken: String) {
        var request = URLRequest(url: wsURL)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        task = session.webSocketTask(with: request)
        task?.resume()
        onEvent?(.connected)
        listen()
    }

    func disconnect() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }

    func send(type: String, payload: [String: Any]) {
        var dict: [String: Any] = ["type": type, "id": UUID().uuidString]
        dict["payload"] = payload
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8)
        else { return }
        task?.send(.string(text)) { _ in }
    }

    private func listen() {
        task?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                self?.onEvent?(.disconnected(error))
            case .success(let message):
                if case .string(let text) = message,
                   let data = text.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let type = json["type"] as? String
                {
                    let payload = json["payload"] as? [String: Any] ?? [:]
                    self?.onEvent?(.message(type: type, payload: payload))
                }
                self?.listen()
            }
        }
    }
}

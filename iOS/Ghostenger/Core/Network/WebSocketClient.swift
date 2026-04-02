import Foundation

/// Manages the persistent WebSocket connection to the Ghostenger server.
/// Reconnects automatically with exponential backoff on failure.
@MainActor
final class WebSocketClient: ObservableObject {
    static let shared = WebSocketClient()

    @Published var isConnected = false

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var token: String?
    private var reconnectDelay: TimeInterval = 1.0
    private var isClosed = false

    private var messageHandlers: [(WSMessage) -> Void] = []

    #if DEBUG
    private let wsURL = URL(string: "wss://localhost:8080/api/v1/ws")!
    #else
    private let wsURL = URL(string: "wss://api.ghostenger.app/api/v1/ws")!
    #endif

    // MARK: - Connect / Disconnect

    func connect(token: String) {
        self.token = token
        isClosed = false
        openConnection(token: token)
    }

    func disconnect() {
        isClosed = true
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
    }

    // MARK: - Send

    func send(_ message: WSOutgoing) {
        guard let task, isConnected else { return }
        guard let data = try? JSONEncoder().encode(message),
              let json = String(data: data, encoding: .utf8)
        else { return }
        task.send(.string(json)) { _ in }
    }

    func onMessage(_ handler: @escaping (WSMessage) -> Void) {
        messageHandlers.append(handler)
    }

    // MARK: - Private

    private func openConnection(token: String) {
        var request = URLRequest(url: wsURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
        task = session?.webSocketTask(with: request)
        task?.resume()
        isConnected = true
        reconnectDelay = 1.0
        receive()
        startPingLoop()
    }

    private func receive() {
        task?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let msg):
                    self.handleMessage(msg)
                    self.receive()
                case .failure:
                    self.isConnected = false
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let text: String
        switch message {
        case .string(let s): text = s
        case .data(let d): text = String(data: d, encoding: .utf8) ?? ""
        @unknown default: return
        }

        guard let data = text.data(using: .utf8),
              let wsMsg = try? JSONDecoder().decode(WSMessage.self, from: data)
        else { return }

        for handler in messageHandlers {
            handler(wsMsg)
        }
    }

    private func scheduleReconnect() {
        guard !isClosed, let token else { return }
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, 30)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !self.isClosed else { return }
            self.openConnection(token: token)
        }
    }

    private func startPingLoop() {
        Task { @MainActor in
            while isConnected && !isClosed {
                try? await Task.sleep(for: .seconds(25))
                self.send(WSOutgoing(type: "ping", payload: [:]))
            }
        }
    }
}

// MARK: - Wire types

struct WSMessage: Codable {
    let type: String
    let payload: [String: String]
}

struct WSOutgoing: Codable {
    let type: String
    let payload: [String: String]
}

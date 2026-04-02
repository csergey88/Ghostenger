import Foundation

/// Base HTTP client for all REST API calls.
final class APIClient {
    static let shared = APIClient()

    #if DEBUG
    private let baseURL = URL(string: "https://localhost:8080/api/v1")!
    #else
    private let baseURL = URL(string: "https://api.ghostenger.app/api/v1")!
    #endif

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Request builders

    func get<T: Decodable>(_ path: String, token: String? = nil, queryItems: [URLQueryItem]? = nil) async throws -> T {
        let request = try buildRequest(method: "GET", path: path, token: token, queryItems: queryItems, body: nil as Empty?)
        return try await perform(request)
    }

    func post<Body: Encodable, T: Decodable>(_ path: String, body: Body, token: String? = nil) async throws -> T {
        let request = try buildRequest(method: "POST", path: path, token: token, body: body)
        return try await perform(request)
    }

    func put<Body: Encodable>(_ path: String, body: Body, token: String) async throws {
        let request = try buildRequest(method: "PUT", path: path, token: token, body: body)
        let _: Empty = try await perform(request)
    }

    func patch<Body: Encodable, T: Decodable>(_ path: String, body: Body, token: String) async throws -> T {
        let request = try buildRequest(method: "PATCH", path: path, token: token, body: body)
        return try await perform(request)
    }

    // MARK: - Core

    private func buildRequest<Body: Encodable>(
        method: String,
        path: String,
        token: String? = nil,
        queryItems: [URLQueryItem]? = nil,
        body: Body?
    ) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body, method != "GET" {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }

        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200..<300 ~= http.statusCode else {
            let apiError = try? JSONDecoder().decode(VaporError.self, from: data)
            throw APIError.httpError(statusCode: http.statusCode, reason: apiError?.reason)
        }

        if T.self == Empty.self {
            return Empty() as! T
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Supporting Types

struct Empty: Codable {}

struct VaporError: Codable {
    let error: Bool
    let reason: String
}

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, reason: String?)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code, let reason):
            return reason ?? "Request failed with status \(code)"
        case .decodingFailed:
            return "Failed to parse server response"
        }
    }
}

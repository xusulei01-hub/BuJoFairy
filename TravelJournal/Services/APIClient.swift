import Foundation

enum APIError: Error {
    case invalidURL
    case noToken
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, String)
}

class APIClient {
    static let shared = APIClient()

    // 开发环境使用 localhost，生产环境替换为服务器地址
    private let baseURL: String = {
        #if DEBUG
        return "http://localhost:3001/api"
        #else
        return "http://8.136.157.93:8080/api"
        #endif
    }()

    private var token: String?

    private init() {
        token = KeychainManager.shared.get(key: "auth_token")
    }

    func setToken(_ token: String?) {
        self.token = token
        if let token = token {
            KeychainManager.shared.save(key: "auth_token", value: token)
        } else {
            KeychainManager.shared.delete(key: "auth_token")
        }
    }

    func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        guard let token = token else {
            throw APIError.noToken
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, msg)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

// Helper to encode arbitrary Encodable
struct AnyEncodable: Encodable {
    let value: any Encodable
    init(_ value: any Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

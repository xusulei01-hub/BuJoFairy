import Foundation

struct DeepSeekMessage: Codable {
    let role: String
    let content: String
}

struct DeepSeekRequest: Codable {
    let model: String
    let messages: [DeepSeekMessage]
    let max_tokens: Int
}

struct DeepSeekChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

class DeepSeekService {
    static let shared = DeepSeekService()
    private let baseURL = "https://api.deepseek.com/v1"

    private init() {}

    func getAPIKey() -> String? {
        KeychainManager.shared.get(key: "deepseek_api_key")
    }

    func chat(messages: [DeepSeekMessage], maxTokens: Int = 4096) async throws -> String {
        guard let apiKey = getAPIKey() else {
            throw NSError(
                domain: "DeepSeek",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未设置 DeepSeek API Key，请在「我的」页面中设置"]
            )
        }

        let request = DeepSeekRequest(
            model: "deepseek-chat",
            messages: messages,
            max_tokens: maxTokens
        )
        let body = try JSONEncoder().encode(request)

        var urlRequest = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = body
        urlRequest.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "DeepSeek",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "DeepSeek API 错误: \(errorMsg)"]
            )
        }

        let chatResponse = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
        return chatResponse.choices.first?.message.content ?? ""
    }
}

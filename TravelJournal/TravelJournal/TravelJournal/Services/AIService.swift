import Foundation

struct GeminiPart: Codable {
    let text: String
}

struct GeminiContent: Codable {
    let role: String?
    let parts: [GeminiPart]
}

struct GeminiRequest: Codable {
    let systemInstruction: GeminiContent
    let contents: [GeminiContent]
    let generationConfig: GenerationConfig

    struct GenerationConfig: Codable {
        let maxOutputTokens: Int
    }
}

struct GeminiResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

class AIService {
    static let shared = AIService()
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    private init() {}

    func getAPIKey() -> String? {
        KeychainManager.shared.get(key: "gemini_api_key")
    }

    func chat(systemPrompt: String, userMessage: String, maxTokens: Int = 4096) async throws -> String {
        guard let apiKey = getAPIKey() else {
            throw NSError(
                domain: "Gemini",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未设置 Gemini API Key，请在「我的」页面中设置"]
            )
        }

        let request = GeminiRequest(
            systemInstruction: GeminiContent(role: nil, parts: [GeminiPart(text: systemPrompt)]),
            contents: [GeminiContent(role: "user", parts: [GeminiPart(text: userMessage)])],
            generationConfig: GeminiRequest.GenerationConfig(maxOutputTokens: maxTokens)
        )

        let body = try JSONEncoder().encode(request)

        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw NSError(domain: "Gemini", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 API 地址"])
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = body
        urlRequest.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "Gemini",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Gemini API 错误: \(errorMsg)"]
            )
        }

        let chatResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        return chatResponse.candidates.first?.content.parts.first?.text ?? ""
    }
}

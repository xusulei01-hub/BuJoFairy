import Foundation
import AppKit

// MARK: - Request/Response Models

struct GeminiPart: Codable {
    let text: String?
    let inlineData: InlineData?

    struct InlineData: Codable {
        let mimeType: String
        let data: String
    }

    init(text: String) {
        self.text = text
        self.inlineData = nil
    }

    init(inlineData: InlineData) {
        self.text = nil
        self.inlineData = inlineData
    }
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
                let text: String?
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

// MARK: - AIService

class AIService {
    static let shared = AIService()
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    private init() {}

    func getAPIKey() -> String? {
        KeychainManager.shared.get(key: "gemini_api_key")
    }

    // MARK: - Text-only chat (fallback)
    func chat(systemPrompt: String, userMessage: String, maxTokens: Int = 4096) async throws -> String {
        guard let apiKey = getAPIKey() else {
            throw AIServiceError.noAPIKey
        }

        let request = GeminiRequest(
            systemInstruction: GeminiContent(role: nil, parts: [GeminiPart(text: systemPrompt)]),
            contents: [GeminiContent(role: "user", parts: [GeminiPart(text: userMessage)])],
            generationConfig: GeminiRequest.GenerationConfig(maxOutputTokens: maxTokens)
        )

        return try await sendRequest(request, apiKey: apiKey)
    }

    // MARK: - Multimodal chat with images
    func generateJournalWithPhotos(
        systemPrompt: String,
        userPrompt: String,
        photos: [PhotoItem],
        maxTokens: Int = 4096
    ) async throws -> String {
        guard let apiKey = getAPIKey() else {
            throw AIServiceError.noAPIKey
        }

        // Build parts: text + images
        var parts: [GeminiPart] = [GeminiPart(text: userPrompt)]

        // Load and compress selected photos
        let selectedPhotos = selectRepresentativePhotos(from: photos, maxCount: 5)
        for photo in selectedPhotos {
            if let imageData = await prepareImageData(for: photo) {
                parts.append(GeminiPart(inlineData: imageData))
            }
        }

        let request = GeminiRequest(
            systemInstruction: GeminiContent(role: nil, parts: [GeminiPart(text: systemPrompt)]),
            contents: [GeminiContent(role: "user", parts: parts)],
            generationConfig: GeminiRequest.GenerationConfig(maxOutputTokens: maxTokens)
        )

        return try await sendRequest(request, apiKey: apiKey)
    }

    // MARK: - Private Helpers

    private func sendRequest(_ request: GeminiRequest, apiKey: String) async throws -> String {
        let body = try JSONEncoder().encode(request)

        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw AIServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = body
        urlRequest.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.apiError(httpResponse.statusCode, errorMsg)
        }

        let chatResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        return chatResponse.candidates.first?.content.parts.first?.text ?? ""
    }

    /// Select representative photos distributed across time
    private func selectRepresentativePhotos(from photos: [PhotoItem], maxCount: Int) -> [PhotoItem] {
        let sorted = photos.sorted { $0.timestamp < $1.timestamp }
        guard sorted.count > maxCount else { return sorted }

        var selected: [PhotoItem] = []
        let step = Double(sorted.count - 1) / Double(maxCount - 1)
        for i in 0..<maxCount {
            let index = min(Int(round(Double(i) * step)), sorted.count - 1)
            selected.append(sorted[index])
        }
        return selected
    }

    /// Load and compress image to base64 for Gemini API
    private func prepareImageData(for photoItem: PhotoItem) async -> GeminiPart.InlineData? {
        guard let nsImage = await photoItem.imageProvider.loadImage(for: photoItem) else {
            return nil
        }

        // Compress: resize to max 1024px width, JPEG quality 0.8
        let maxDimension: CGFloat = 1024
        let compressedData = compressImage(nsImage, maxDimension: maxDimension, quality: 0.8)

        guard let data = compressedData else { return nil }
        let base64String = data.base64EncodedString()
        return GeminiPart.InlineData(mimeType: "image/jpeg", data: base64String)
    }

    private func compressImage(_ image: NSImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let originalSize = image.size
        let scale = min(maxDimension / originalSize.width, maxDimension / originalSize.height, 1.0)
        let newSize = NSSize(width: originalSize.width * scale, height: originalSize.height * scale)

        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(newSize.width),
            pixelsHigh: Int(newSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        bitmapRep.size = newSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        image.draw(in: NSRect(origin: .zero, size: newSize))
        NSGraphicsContext.restoreGraphicsState()

        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case noAPIKey
    case invalidURL
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "未设置 Gemini API Key，请在设置中配置"
        case .invalidURL:
            return "无效的 API 地址"
        case .apiError(let code, let msg):
            return "Gemini API 错误 (\(code)): \(msg)"
        }
    }
}

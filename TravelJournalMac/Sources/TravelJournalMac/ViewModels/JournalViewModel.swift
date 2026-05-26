import Combine
import Foundation
import SwiftData

@MainActor
class JournalViewModel: ObservableObject {
    @Published var journals: [JournalEntry] = []
    @Published var isGenerating = false
    @Published var generatedContent: JournalContent?
    @Published var selectedTemplateID = "auto"
    @Published var generationError: String?
    @Published var errorMessage: String?

    struct TemplateInfo: Identifiable {
        let id: String
        let name: String
        let category: String
        let description: String
    }

    func loadJournals(modelContext: ModelContext) {
        do {
            let descriptor = FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            journals = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "加载手帐失败"
        }
    }

    func save(modelContext: ModelContext) {
        do {
            try modelContext.save()
            loadJournals(modelContext: modelContext)
        } catch {
            errorMessage = "保存失败"
        }
    }

    func getBuiltInTemplates() -> [TemplateInfo] {
        [
            TemplateInfo(id: "auto", name: "✨ 自动匹配", category: "", description: "AI 自动选择最适合的模板"),
            TemplateInfo(id: "city_walk", name: "城市漫步", category: "城市", description: "适合城市街拍与建筑主题"),
            TemplateInfo(id: "neon_city", name: "霓虹都市", category: "城市", description: "现代都市夜景风格"),
            TemplateInfo(id: "mountain_sea", name: "山海之间", category: "自然", description: "自然风光与户外旅行"),
            TemplateInfo(id: "forest_tale", name: "森林物语", category: "自然", description: "清新自然风格"),
            TemplateInfo(id: "taste_map", name: "味蕾地图", category: "美食", description: "美食探店记录"),
            TemplateInfo(id: "night_canteen", name: "深夜食堂", category: "美食", description: "温暖治愈系美食"),
            TemplateInfo(id: "old_days", name: "旧时光", category: "复古", description: "复古胶片风格"),
            TemplateInfo(id: "film_diary", name: "胶片日记", category: "复古", description: "文艺人文游记"),
        ]
    }

    func generateJournal(for trip: Trip, enableWebSearch: Bool = false, modelContext: ModelContext) async {
        guard AIService.shared.getAPIKey() != nil else {
            generationError = "请先在设置中配置 Gemini API Key"
            return
        }

        isGenerating = true
        generationError = nil
        defer { isGenerating = false }

        let photos = trip.photos ?? []
        let locationNames = Array(Set(photos.compactMap(\.locationName)))

        let templateName = selectedTemplateID == "auto"
            ? "城市漫步"
            : getBuiltInTemplates().first { $0.id == selectedTemplateID }?.name ?? "城市漫步"

        let systemPrompt = JournalPromptBuilder.buildGenerationPrompt(
            tripName: trip.name,
            startDate: trip.startDate,
            locations: locationNames,
            templateName: templateName,
            enableWebSearch: enableWebSearch
        ).system

        let userPrompt = JournalPromptBuilder.buildMultimodalPrompt(
            tripName: trip.name,
            startDate: trip.startDate,
            locations: locationNames,
            templateName: templateName
        )

        do {
            let rawContent: String
            if photos.isEmpty {
                // Fallback to text-only if no photos
                rawContent = try await AIService.shared.chat(
                    systemPrompt: systemPrompt,
                    userMessage: userPrompt
                )
            } else {
                // Multimodal with photos
                rawContent = try await AIService.shared.generateJournalWithPhotos(
                    systemPrompt: systemPrompt,
                    userPrompt: userPrompt,
                    photos: photos
                )
            }

            guard let jsonData = JournalPromptBuilder.extractJSON(from: rawContent) else {
                generationError = "AI 返回内容中未找到有效的 JSON 数据"
                return
            }

            do {
                let content = try JSONDecoder().decode(JournalContent.self, from: jsonData)
                generatedContent = content
            } catch let decodeError as DecodingError {
                let detail: String
                switch decodeError {
                case .keyNotFound(let key, let context):
                    detail = "缺少字段 '\(key.stringValue)'（在 \(context.codingPath.map { $0.stringValue }.joined(separator: ".") )）"
                case .typeMismatch(let type, let context):
                    detail = "类型不匹配：期望 \(type)（在 \(context.codingPath.map { $0.stringValue }.joined(separator: ".") )）"
                case .valueNotFound(let type, let context):
                    detail = "缺少值：期望 \(type)（在 \(context.codingPath.map { $0.stringValue }.joined(separator: ".") )）"
                case .dataCorrupted(let context):
                    detail = "数据损坏：\(context.debugDescription)"
                @unknown default:
                    detail = "JSON 解析失败"
                }
                generationError = "AI 返回格式异常：\(detail)"
                return
            } catch {
                generationError = "AI 返回格式异常：\(error.localizedDescription)"
                return
            }

            let journal = JournalEntry(
                title: "\(trip.name) · 旅行手帐",
                templateID: selectedTemplateID,
                contentJSON: jsonData
            )
            journal.trip = trip
            modelContext.insert(journal)
            do {
                try modelContext.save()
                loadJournals(modelContext: modelContext)
            } catch {
                errorMessage = "保存手帐失败"
            }
        } catch {
            generationError = error.localizedDescription
        }
    }
}

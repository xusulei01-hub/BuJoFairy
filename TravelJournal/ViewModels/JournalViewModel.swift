import Foundation
import SwiftData

@MainActor
class JournalViewModel: ObservableObject {
    @Published var journals: [JournalEntry] = []
    @Published var isGenerating = false
    @Published var generatedContent: JournalContent?
    @Published var selectedTemplateID = "auto"
    @Published var generationError: String?

    struct TemplateInfo: Identifiable {
        let id: String
        let name: String
        let category: String
        let description: String
    }

    func loadJournals(modelContext: ModelContext) {
        var descriptor = FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        journals = (try? modelContext.fetch(descriptor)) ?? []
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
        guard DeepSeekService.shared.getAPIKey() != nil else {
            generationError = "请先在「我的」页面设置 DeepSeek API Key"
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

        let messages = JournalPromptBuilder.buildGenerationPrompt(
            tripName: trip.name,
            startDate: trip.startDate,
            locations: locationNames,
            templateName: templateName,
            enableWebSearch: enableWebSearch
        )

        do {
            let rawContent = try await DeepSeekService.shared.chat(messages: messages)

            guard let jsonData = extractJSON(from: rawContent),
                  let content = try? JSONDecoder().decode(JournalContent.self, from: jsonData) else {
                generationError = "AI 返回格式异常，请重试"
                return
            }

            generatedContent = content

            let journal = JournalEntry(
                title: "\(trip.name) · 旅行手帐",
                templateID: selectedTemplateID,
                contentJSON: jsonData
            )
            journal.trip = trip
            modelContext.insert(journal)
            try? modelContext.save()
            loadJournals(modelContext: modelContext)
        } catch {
            generationError = error.localizedDescription
        }
    }

    private func extractJSON(from text: String) -> Data? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 尝试去除 markdown 代码块
        if cleaned.hasPrefix("```") {
            let lines = cleaned.components(separatedBy: "\n")
            let inner = lines.dropFirst().dropLast().joined(separator: "\n")
            return inner.data(using: .utf8)
        }
        return cleaned.data(using: .utf8)
    }
}

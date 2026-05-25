import Foundation

struct JournalPage: Codable, Identifiable {
    var id: String { "\(type)-\(title ?? "")-\(text ?? "")" }
    let type: String
    let layout: String
    let title: String?
    let text: String?
    let photoIndices: [Int]?
    let caption: String?
}

struct JournalContent: Codable {
    let pages: [JournalPage]
}

enum JournalPromptBuilder {
    static func buildGenerationPrompt(
        tripName: String,
        startDate: Date,
        locations: [String],
        templateName: String,
        enableWebSearch: Bool
    ) -> [DeepSeekMessage] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy 年 MM 月 dd 日"

        let locationsText = locations.isEmpty ? "未知地点" : locations.joined(separator: "、")

        let systemPrompt = """
        你是一个旅行手帐创作助手。用户会提供旅行信息，请按照指定的模板结构生成手帐内容。

        模板页面结构说明：
        - cover: 封面页，布局 full_photo_title_overlay
        - daily: 日记页，布局 photo_left_text_right / text_left_photo_right / photo_top_text_bottom / text_top_photo_bottom
        - gallery: 照片集，布局 two_grid / three_grid
        - highlight: 亮点页，布局 full_width_photo_quote
        - ending: 尾页，布局 summary_stats

        要求：
        1. 按指定模板结构生成每个页面的内容
        2. 文字风格温暖、有旅行感，每个 daily 页面 80-150 字
        3. 封面标题要吸引人
        4. gallery 页面填充照片索引（数字 0 开始），photoIndices 数组
        5. 返回严格 JSON，格式为 { "pages": [...] }，不要包含 markdown 代码块标记
        \(enableWebSearch ? "6. 请在内容中融入地点的背景知识、历史故事、旅行小贴士" : "")
        """

        let userPrompt = """
        旅行名称：\(tripName)
        出发日期：\(dateFormatter.string(from: startDate))
        访问地点：\(locationsText)
        模板名称：\(templateName)
        """

        return [
            DeepSeekMessage(role: "system", content: systemPrompt),
            DeepSeekMessage(role: "user", content: userPrompt),
        ]
    }
}

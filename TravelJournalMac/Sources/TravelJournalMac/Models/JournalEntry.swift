import Foundation
import SwiftData

@Model
final class JournalEntry {
    @Attribute(.unique) var id: UUID
    var title: String
    var templateID: String
    var contentJSON: Data
    var coverURL: String?
    var createdAt: Date
    var updatedAt: Date

    var trip: Trip?

    init(title: String, templateID: String, contentJSON: Data) {
        self.id = UUID()
        self.title = title
        self.templateID = templateID
        self.contentJSON = contentJSON
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

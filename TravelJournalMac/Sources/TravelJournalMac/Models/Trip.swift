import Foundation
import SwiftData

@Model
final class Trip {
    @Attribute(.unique) var id: UUID
    var name: String
    var startDate: Date
    var createdAt: Date
    var sourceFolderURL: String?

    @Relationship(deleteRule: .cascade, inverse: \PhotoItem.trip)
    var photos: [PhotoItem]?

    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.trip)
    var journals: [JournalEntry]?

    init(name: String, startDate: Date) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.createdAt = Date()
    }
}

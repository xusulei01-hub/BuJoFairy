import Foundation
import SwiftData

@Model
final class Trip {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date?
    var coverPhotoLocalID: String?
    var serverID: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PhotoItem.trip)
    var photos: [PhotoItem]?

    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.trip)
    var journals: [JournalEntry]?

    init(name: String, startDate: Date, coverPhotoLocalID: String? = nil) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.coverPhotoLocalID = coverPhotoLocalID
        self.createdAt = Date()
    }
}

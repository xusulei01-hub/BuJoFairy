import Foundation
import SwiftData

enum PhotoSource: String, Codable {
    case photosLibrary
    case fileURL
}

@Model
final class PhotoItem {
    @Attribute(.unique) var id: UUID
    var source: PhotoSource
    var sourceIdentifier: String?
    var timestamp: Date
    var gpsLatitude: Double?
    var gpsLongitude: Double?
    var locationName: String?

    var trip: Trip?

    init(source: PhotoSource, sourceIdentifier: String?, timestamp: Date) {
        self.id = UUID()
        self.source = source
        self.sourceIdentifier = sourceIdentifier
        self.timestamp = timestamp
    }
}

import Foundation
import SwiftData

@Model
final class PhotoItem {
    var id: UUID
    var localAssetID: String
    var gpsLatitude: Double?
    var gpsLongitude: Double?
    var timestamp: Date
    var locationName: String?
    var serverID: String?

    @Relationship(inverse: \Trip.photos)
    var trip: Trip?

    init(localAssetID: String, timestamp: Date, gpsLatitude: Double? = nil, gpsLongitude: Double? = nil) {
        self.id = UUID()
        self.localAssetID = localAssetID
        self.timestamp = timestamp
        self.gpsLatitude = gpsLatitude
        self.gpsLongitude = gpsLongitude
    }
}

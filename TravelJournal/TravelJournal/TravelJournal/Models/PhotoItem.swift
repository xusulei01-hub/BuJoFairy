import Foundation
import SwiftData

@Model
final class PhotoItem {
    var id: UUID
    var localAssetID: String?
    var localFileName: String?
    var gpsLatitude: Double?
    var gpsLongitude: Double?
    var timestamp: Date
    var locationName: String?
    var serverID: String?

    var trip: Trip?

    init(localAssetID: String? = nil, localFileName: String? = nil, timestamp: Date = Date(), gpsLatitude: Double? = nil, gpsLongitude: Double? = nil) {
        self.id = UUID()
        self.localAssetID = localAssetID
        self.localFileName = localFileName
        self.timestamp = timestamp
        self.gpsLatitude = gpsLatitude
        self.gpsLongitude = gpsLongitude
    }
}

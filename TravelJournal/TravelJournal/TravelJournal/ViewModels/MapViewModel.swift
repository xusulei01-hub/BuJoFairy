import Combine
import Foundation
import MapKit
import SwiftData

@MainActor
class MapViewModel: ObservableObject {
    @Published var locations: [MapLocation] = []
    @Published var selectedLocation: MapLocation?
    @Published var errorMessage: String?

    struct MapLocation: Identifiable {
        let id: String
        let name: String
        let coordinate: CLLocationCoordinate2D
        let photoCount: Int
        let tripName: String
    }

    func loadLocations(modelContext: ModelContext) {
        do {
            let descriptor = FetchDescriptor<Trip>()
            let trips = try modelContext.fetch(descriptor)

            var mapLocations: [MapLocation] = []
            for trip in trips {
                guard let photos = trip.photos else { continue }
                let withGPS = photos.filter { $0.gpsLatitude != nil && $0.gpsLongitude != nil }

                let grouped = Dictionary(grouping: withGPS) { $0.locationName ?? "未知地点" }
                for (name, group) in grouped {
                    let avgLat = group.compactMap(\.gpsLatitude).reduce(0, +) / Double(group.count)
                    let avgLon = group.compactMap(\.gpsLongitude).reduce(0, +) / Double(group.count)
                    mapLocations.append(MapLocation(
                        id: "\(trip.id.uuidString)-\(name)",
                        name: name,
                        coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                        photoCount: group.count,
                        tripName: trip.name
                    ))
                }
            }
            locations = mapLocations
        } catch {
            errorMessage = "加载地图数据失败"
        }
    }
}

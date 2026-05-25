import Foundation
import PhotosUI
import SwiftData
import CoreLocation
import Photos

@MainActor
class PhotosViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var selectedTrip: Trip?

    func loadTrips(modelContext: ModelContext) {
        var descriptor = FetchDescriptor<Trip>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        trips = (try? modelContext.fetch(descriptor)) ?? []
    }

    func createTrip(name: String, startDate: Date, modelContext: ModelContext) -> Trip {
        let trip = Trip(name: name, startDate: startDate)
        modelContext.insert(trip)
        try? modelContext.save()
        loadTrips(modelContext: modelContext)
        return trip
    }

    func importPhotos(_ items: [PhotosPickerItem], to trip: Trip, modelContext: ModelContext) async {
        for item in items {
            guard let assetID = item.itemIdentifier else { continue }

            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
            guard let asset = fetchResult.firstObject else { continue }

            let lat = asset.location?.coordinate.latitude
            let lon = asset.location?.coordinate.longitude
            let timestamp = asset.creationDate ?? Date()

            let photo = PhotoItem(
                localAssetID: assetID,
                timestamp: timestamp,
                gpsLatitude: lat,
                gpsLongitude: lon
            )

            // 反向地理编码
            if let lat = lat, let lon = lon {
                let geocoder = CLGeocoder()
                if let placemarks = try? await geocoder.reverseGeocodeLocation(
                    CLLocation(latitude: lat, longitude: lon)
                ), let placemark = placemarks.first {
                    photo.locationName = [
                        placemark.locality,
                        placemark.administrativeArea,
                        placemark.country,
                    ]
                    .compactMap { $0 }
                    .joined(separator: "、")
                }
            }

            photo.trip = trip
            modelContext.insert(photo)
        }
        try? modelContext.save()
        loadTrips(modelContext: modelContext)
    }
}

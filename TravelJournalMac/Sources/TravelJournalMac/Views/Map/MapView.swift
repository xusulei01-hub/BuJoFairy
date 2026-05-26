import SwiftUI
import MapKit
import SwiftData

struct MapView: View {
    @Query private var trips: [Trip]
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0),
        span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 40)
    )
    @State private var selectedTrip: Trip?

    private var annotations: [PhotoAnnotation] {
        var result: [PhotoAnnotation] = []
        for trip in trips {
            for photo in trip.photos ?? [] {
                if let lat = photo.gpsLatitude, let lon = photo.gpsLongitude {
                    result.append(PhotoAnnotation(
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        title: trip.name,
                        subtitle: photo.locationName
                    ))
                }
            }
        }
        return result
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: annotations) { annotation in
            MapMarker(coordinate: annotation.coordinate, tint: .red)
        }
        .navigationTitle("地图")
    }
}

struct PhotoAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    let subtitle: String?
}

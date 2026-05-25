import SwiftUI
import MapKit
import SwiftData

struct MapView: View {
    @StateObject private var viewModel = MapViewModel()
    @Environment(\.modelContext) private var modelContext

    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0),
        span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 40)
    ))

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition) {
                    ForEach(viewModel.locations) { location in
                        Annotation(location.name, coordinate: location.coordinate) {
                            VStack(spacing: 2) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.red)
                                Text(location.name)
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .onTapGesture {
                                viewModel.selectedLocation = location
                            }
                        }
                    }
                }
                .mapStyle(.standard)

                if viewModel.locations.isEmpty {
                    ContentUnavailableView(
                        "还没有旅行足迹",
                        systemImage: "map",
                        description: Text("添加照片后，地点会自动标注在地图上")
                    )
                }
            }
            .navigationTitle("旅行地图")
            .onAppear {
                viewModel.loadLocations(modelContext: modelContext)
            }
            .sheet(item: $viewModel.selectedLocation) { location in
                NavigationStack {
                    LocationDetailView(location: location)
                }
            }
        }
    }
}

struct LocationDetailView: View {
    let location: MapViewModel.MapLocation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("地点信息") {
                LabeledContent("名称", value: location.name)
                LabeledContent("照片数量", value: "\(location.photoCount) 张")
                LabeledContent("所属旅行", value: location.tripName)
            }
        }
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            }
        }
    }
}

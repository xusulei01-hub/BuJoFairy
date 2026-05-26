import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct TripDetailView: View {
    let trip: Trip
    let onBack: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var showGenerateJournal = false
    @State private var showImportPanel = false
    @State private var photosPickerItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var importProgress: (completed: Int, total: Int)?
    @State private var errorMessage: String?

    var sortedPhotos: [PhotoItem] {
        (trip.photos ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 200), spacing: 4)
    ]

    var body: some View {
        ScrollView {
            if sortedPhotos.isEmpty {
                ContentUnavailableView(
                    "还没有照片",
                    systemImage: "photo.badge.plus",
                    description: Text("点击导入按钮添加照片")
                )
                .padding(.top, 80)
            } else {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(sortedPhotos) { photo in
                        PhotoThumbnailView(photo: photo)
                            .aspectRatio(1, contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(8)
            }
        }
        .navigationTitle(trip.name)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("返回") { onBack() }
            }

            ToolbarItem {
                HStack(spacing: 8) {
                    if !sortedPhotos.isEmpty {
                        Button {
                            showGenerateJournal = true
                        } label: {
                            Label("生成手帐", systemImage: "wand.and.stars")
                        }
                    }

                    Button {
                        showImportPanel = true
                    } label: {
                        Label("导入", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showImportPanel) {
            ImportPanelView(trip: trip) { source in
                showImportPanel = false
                handleImport(source: source)
            }
        }
        .sheet(isPresented: $showGenerateJournal) {
            GenerateJournalView(trip: trip)
        }
        .overlay {
            if isImporting, let progress = importProgress {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 12) {
                            ProgressView(value: Double(progress.completed), total: Double(progress.total))
                                .tint(.white)
                                .frame(width: 200)
                            Text("正在导入照片 \(progress.completed)/\(progress.total)...")
                                .foregroundStyle(.white)
                        }
                    }
            }
        }
        .alert("导入错误", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func handleImport(source: ImportSource) {
        switch source {
        case .finder(let urls):
            importFromFinder(urls: urls)
        case .photos(let items):
            importFromPhotos(items: items)
        }
    }

    private func importFromFinder(urls: [URL]) {
        isImporting = true
        let total = urls.count
        var completed = 0

        Task {
            for url in urls {
                defer {
                    completed += 1
                    importProgress = (completed, total)
                }

                guard let imageData = try? Data(contentsOf: url) else { continue }

                var timestamp = Date()
                var lat: Double?
                var lon: Double?

                // Extract EXIF
                if let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                   let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                    if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
                       let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                        if let date = formatter.date(from: dateString) {
                            timestamp = date
                        }
                    }
                    if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
                       let latVal = gps[kCGImagePropertyGPSLatitude as String] as? Double,
                       let lonVal = gps[kCGImagePropertyGPSLongitude as String] as? Double {
                        let latRef = (gps[kCGImagePropertyGPSLatitudeRef as String] as? String) ?? "N"
                        let lonRef = (gps[kCGImagePropertyGPSLongitudeRef as String] as? String) ?? "E"
                        lat = latRef == "S" ? -latVal : latVal
                        lon = lonRef == "W" ? -lonVal : lonVal
                    }
                }

                let photo = PhotoItem(
                    source: .fileURL,
                    sourceIdentifier: url.absoluteString,
                    timestamp: timestamp
                )
                photo.gpsLatitude = lat
                photo.gpsLongitude = lon
                photo.trip = trip

                // Reverse geocode
                if let lat = lat, let lon = lon {
                    let geocoder = CLGeocoder()
                    if let placemarks = try? await geocoder.reverseGeocodeLocation(
                        CLLocation(latitude: lat, longitude: lon)
                    ), let placemark = placemarks.first {
                        photo.locationName = [
                            placemark.locality,
                            placemark.subLocality,
                            placemark.administrativeArea,
                        ].compactMap { $0 }.joined(separator: "、")
                    }
                }

                modelContext.insert(photo)
            }

            try? modelContext.save()
            isImporting = false
            importProgress = nil
        }
    }

    private func importFromPhotos(items: [PhotosPickerItem]) {
        isImporting = true
        let total = items.count
        var completed = 0

        Task {
            for item in items {
                defer {
                    completed += 1
                    importProgress = (completed, total)
                }

                guard let imageData = try? await item.loadTransferable(type: Data.self),
                      let assetID = item.itemIdentifier else { continue }

                var timestamp = Date()
                var lat: Double?
                var lon: Double?

                // Extract EXIF from data
                if let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                   let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                    if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
                       let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                        if let date = formatter.date(from: dateString) {
                            timestamp = date
                        }
                    }
                    if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
                       let latVal = gps[kCGImagePropertyGPSLatitude as String] as? Double,
                       let lonVal = gps[kCGImagePropertyGPSLongitude as String] as? Double {
                        let latRef = (gps[kCGImagePropertyGPSLatitudeRef as String] as? String) ?? "N"
                        let lonRef = (gps[kCGImagePropertyGPSLongitudeRef as String] as? String) ?? "E"
                        lat = latRef == "S" ? -latVal : latVal
                        lon = lonRef == "W" ? -lonVal : lonVal
                    }
                }

                // Supplement from PHAsset
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
                if let asset = fetchResult.firstObject {
                    if lat == nil { lat = asset.location?.coordinate.latitude }
                    if lon == nil { lon = asset.location?.coordinate.longitude }
                    timestamp = asset.creationDate ?? timestamp
                }

                let photo = PhotoItem(
                    source: .photosLibrary,
                    sourceIdentifier: assetID,
                    timestamp: timestamp
                )
                photo.gpsLatitude = lat
                photo.gpsLongitude = lon
                photo.trip = trip

                // Reverse geocode
                if let lat = lat, let lon = lon {
                    let geocoder = CLGeocoder()
                    if let placemarks = try? await geocoder.reverseGeocodeLocation(
                        CLLocation(latitude: lat, longitude: lon)
                    ), let placemark = placemarks.first {
                        photo.locationName = [
                            placemark.locality,
                            placemark.subLocality,
                            placemark.administrativeArea,
                        ].compactMap { $0 }.joined(separator: "、")
                    }
                }

                modelContext.insert(photo)
            }

            try? modelContext.save()
            isImporting = false
            importProgress = nil
        }
    }
}

enum ImportSource {
    case finder(urls: [URL])
    case photos(items: [PhotosPickerItem])
}

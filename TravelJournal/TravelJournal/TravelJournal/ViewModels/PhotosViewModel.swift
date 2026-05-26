import Combine
import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import CoreLocation
import ImageIO
import UniformTypeIdentifiers

@MainActor
class PhotosViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var selectedTrip: Trip?
    @Published var errorMessage: String?
    @Published var importProgress: (completed: Int, total: Int)?

    func loadTrips(modelContext: ModelContext) {
        do {
            let descriptor = FetchDescriptor<Trip>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
            trips = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "加载旅行记录失败"
        }
    }

    func createTrip(name: String, startDate: Date, modelContext: ModelContext) -> Trip {
        let trip = Trip(name: name, startDate: startDate)
        modelContext.insert(trip)
        do {
            try modelContext.save()
            loadTrips(modelContext: modelContext)
        } catch {
            errorMessage = "创建旅行失败"
        }
        return trip
    }

    func save(modelContext: ModelContext) {
        do {
            try modelContext.save()
            loadTrips(modelContext: modelContext)
        } catch {
            errorMessage = "保存失败"
        }
    }

    func importPhotos(_ items: [PhotosPickerItem], to trip: Trip, modelContext: ModelContext) async {
        // 确保 sandbox Photos 目录存在
        let photosDir = photosDirectory()
        if !FileManager.default.fileExists(atPath: photosDir.path) {
            try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        }

        let total = items.count
        var completed = 0
        var successCount = 0

        for item in items {
            defer {
                completed += 1
                importProgress = (completed, total)
            }

            // 1. 加载图片数据（不依赖 itemIdentifier）
            guard let imageData = try? await item.loadTransferable(type: Data.self) else { continue }

            // 2. 保存到 sandbox
            let fileName = "\(UUID().uuidString).jpg"
            let fileURL = photosDir.appendingPathComponent(fileName)
            do {
                try imageData.write(to: fileURL, options: .atomic)
            } catch {
                continue
            }

            // 3. 从图片数据提取 EXIF/GPS
            var timestamp = Date()
            var lat: Double?
            var lon: Double?
            var assetID: String? = item.itemIdentifier

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

            // 4. 如果有 assetID，尝试 PHAsset 获取时间/GPS 作为补充
            if let aid = assetID {
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [aid], options: nil)
                if let asset = fetchResult.firstObject {
                    if lat == nil { lat = asset.location?.coordinate.latitude }
                    if lon == nil { lon = asset.location?.coordinate.longitude }
                    timestamp = asset.creationDate ?? timestamp
                }
            }

            // 5. 创建 PhotoItem
            let photo = PhotoItem(
                localAssetID: assetID,
                localFileName: fileName,
                timestamp: timestamp,
                gpsLatitude: lat,
                gpsLongitude: lon
            )

            // 6. 反向地理编码
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
            successCount += 1
        }
        importProgress = nil

        if successCount > 0 {
            do {
                try modelContext.save()
                loadTrips(modelContext: modelContext)
            } catch {
                errorMessage = "保存失败，请重试"
            }
        } else {
            errorMessage = "未能导入照片，请重试或选择本地照片"
        }
    }

    private func photosDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Photos", isDirectory: true)
    }
}

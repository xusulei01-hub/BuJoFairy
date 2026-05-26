import Combine
import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import CoreLocation
import ImageIO

@MainActor
class PhotosViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var selectedTrip: Trip?
    @Published var errorMessage: String?
    @Published var importProgress: (completed: Int, total: Int)?

    func loadTrips(modelContext: ModelContext) {
        do {
            let descriptor = FetchDescriptor<Trip>(sortBy: [SortDescriptor(\Trip.startDate, order: .reverse)])
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
}

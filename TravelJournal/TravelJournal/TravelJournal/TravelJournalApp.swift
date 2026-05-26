import SwiftUI
import SwiftData

@main
struct TravelJournalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Trip.self, PhotoItem.self, JournalEntry.self])
    }
}

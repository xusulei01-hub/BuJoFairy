import SwiftUI
import SwiftData

@main
struct TravelJournalMacApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(for: [Trip.self, PhotoItem.self, JournalEntry.self])
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentSize)
    }
}

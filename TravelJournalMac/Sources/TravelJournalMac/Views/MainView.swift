import SwiftUI
import SwiftData

struct MainView: View {
    @State private var selectedTab: SidebarTab = .photos
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var journals: [JournalEntry]

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedTab)
        } detail: {
            switch selectedTab {
            case .map:
                MapView()
            case .photos:
                PhotosLibraryView()
            case .journal:
                JournalListView()
            case .settings:
                SettingsView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

enum SidebarTab: String, CaseIterable, Identifiable {
    case map = "地图"
    case photos = "照片库"
    case journal = "手帐库"
    case settings = "设置"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .map: return "map.fill"
        case .photos: return "photo.on.rectangle.fill"
        case .journal: return "book.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

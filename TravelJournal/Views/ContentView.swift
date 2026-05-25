import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MapView()
                .tabItem {
                    Label("地图", systemImage: "map.fill")
                }
                .tag(0)

            PhotosView()
                .tabItem {
                    Label("照片库", systemImage: "photo.on.rectangle.fill")
                }
                .tag(1)

            JournalListView()
                .tabItem {
                    Label("手帐库", systemImage: "book.fill")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(3)
        }
        .tint(.blue)
    }
}

#Preview {
    ContentView()
}

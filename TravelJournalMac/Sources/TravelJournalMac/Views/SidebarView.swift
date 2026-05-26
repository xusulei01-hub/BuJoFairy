import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarTab

    var body: some View {
        List(SidebarTab.allCases, selection: $selection) { tab in
            Label(tab.rawValue, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
        .frame(minWidth: 160)
    }
}

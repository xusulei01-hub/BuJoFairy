import SwiftUI

struct JournalReaderView: View {
    let journal: JournalEntry
    @State private var currentPage = 0
    @State private var viewMode: ViewMode = .magazine

    enum ViewMode: String, CaseIterable {
        case magazine = "翻页"
        case scroll = "长图"
    }

    var pages: [JournalPage] {
        guard let data = try? JSONDecoder().decode(JournalContent.self, from: journal.contentJSON) else {
            return []
        }
        return data.pages
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("显示模式", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            switch viewMode {
            case .magazine:
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        JournalPageView(page: page, trip: journal.trip)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))

            case .scroll:
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { _, page in
                            JournalPageView(page: page, trip: journal.trip)
                                .frame(minHeight: UIScreen.main.bounds.height * 0.85)
                        }
                    }
                }
            }
        }
        .navigationTitle(journal.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct JournalPageView: View {
    let page: JournalPage
    let trip: Trip?

    var body: some View {
        GeometryReader { geo in
            switch page.type {
            case "cover":
                coverPage(size: geo.size)
            case "daily":
                dailyPage(size: geo.size)
            case "gallery":
                galleryPage(size: geo.size)
            case "highlight":
                highlightPage(size: geo.size)
            case "ending":
                endingPage(size: geo.size)
            default:
                dailyPage(size: geo.size)
            }
        }
    }

    func coverPage(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.6), .purple.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 20) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.8))
                Text(page.title ?? "旅行手帐")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                if let subtitle = page.text {
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(16)
    }

    func dailyPage(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = page.title {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            Text(page.text ?? "")
                .font(.body)
                .lineSpacing(8)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func galleryPage(size: CGSize) -> some View {
        VStack(spacing: 8) {
            if let caption = page.caption {
                Text(caption)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2),
                spacing: 4
            ) {
                ForEach(0 ..< 4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))
                        .aspectRatio(1, contentMode: .fill)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.gray.opacity(0.5))
                        }
                }
            }
        }
        .padding(32)
    }

    func highlightPage(size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.08))
            VStack(spacing: 12) {
                Text("\u{201C}")
                    .font(.system(size: 64, design: .serif))
                    .foregroundStyle(.secondary)
                Text(page.text ?? "")
                    .font(.title3)
                    .italic()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }
            .padding(40)
        }
        .padding(32)
    }

    func endingPage(size: CGSize) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text(page.title ?? "旅途未完待续")
                .font(.title)
                .fontWeight(.bold)
            Text(page.text ?? "每一段旅程，都是独一无二的记忆")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

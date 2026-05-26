import SwiftUI
import Photos
import UIKit

struct JournalReaderView: View {
    let journal: JournalEntry
    @State private var currentPage = 0
    @State private var viewMode: ViewMode = .magazine
    @State private var pages: [JournalPage] = []
    @State private var decodeError: String?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportedImage: UIImage?
    @State private var exportMessage: String?

    enum ViewMode: String, CaseIterable {
        case magazine = "翻页"
        case scroll = "长图"
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

            if let error = decodeError {
                ContentUnavailableView(
                    "无法显示手帐",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if pages.isEmpty {
                ContentUnavailableView(
                    "手帐内容为空",
                    systemImage: "book.pages",
                    description: Text("该手帐没有可显示的页面")
                )
            } else {
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
        }
        .navigationTitle(journal.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        exportLongImage(saveToAlbum: true)
                    } label: {
                        Label("保存到相册", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        exportLongImage(saveToAlbum: false)
                    } label: {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(isExporting || pages.isEmpty)
            }
        }
        .overlay {
            if isExporting {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("正在生成长图...")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .alert("导出", isPresented: .init(
            get: { exportMessage != nil },
            set: { if !$0 { exportMessage = nil } }
        )) {
            Button("确定") {}
        } message: {
            Text(exportMessage ?? "")
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = exportedImage {
                ShareSheet(activityItems: [image])
            }
        }
        .task {
            decodeContent()
        }
    }

    private func decodeContent() {
        do {
            let content = try JSONDecoder().decode(JournalContent.self, from: journal.contentJSON)
            pages = content.pages
            decodeError = nil
        } catch {
            decodeError = "内容格式异常，无法显示手帐"
            pages = []
        }
    }

    private func exportLongImage(saveToAlbum: Bool) {
        guard !pages.isEmpty else { return }
        isExporting = true

        Task {
            let image = await renderLongImage(pages: pages, trip: journal.trip)
            isExporting = false

            guard let image = image else {
                exportMessage = "生成图片失败"
                return
            }

            exportedImage = image

            if saveToAlbum {
                saveToPhotoLibrary(image)
            } else {
                showShareSheet = true
            }
        }
    }

    private func saveToPhotoLibrary(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    exportMessage = "没有相册访问权限，请在设置中开启"
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            exportMessage = "已保存到相册"
                        } else {
                            exportMessage = "保存失败: \(error?.localizedDescription ?? "未知错误")"
                        }
                    }
                }
            }
        }
    }
}

@MainActor
private func renderLongImage(pages: [JournalPage], trip: Trip?) async -> UIImage? {
    let pageWidth: CGFloat = 390
    var pageImages: [UIImage] = []

    for page in pages {
        let renderer = ImageRenderer(
            content: JournalPageView(page: page, trip: trip)
        )
        renderer.proposedSize = ProposedViewSize(width: pageWidth, height: nil)
        renderer.scale = UIScreen.main.scale

        if let image = renderer.uiImage {
            pageImages.append(image)
        }
    }

    guard !pageImages.isEmpty else { return nil }

    let totalHeight = pageImages.reduce(0) { $0 + $1.size.height }
    let format = UIGraphicsImageRendererFormat()
    format.scale = UIScreen.main.scale

    let renderer = UIGraphicsImageRenderer(
        size: CGSize(width: pageWidth, height: totalHeight),
        format: format
    )

    return renderer.image { _ in
        var y: CGFloat = 0
        for image in pageImages {
            image.draw(at: CGPoint(x: 0, y: y))
            y += image.size.height
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct JournalPageView: View {
    let page: JournalPage
    let trip: Trip?

    private var photos: [PhotoItem] {
        (trip?.photos ?? [])
            .sorted { $0.timestamp < $1.timestamp }
    }

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
            if let firstPhoto = photo(at: page.photoIndices?.first) {
                firstPhoto
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.4))
            } else {
                LinearGradient(
                    colors: [.blue.opacity(0.6), .purple.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
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
    }

    func dailyPage(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = page.title {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            if let photo = photo(at: page.photoIndices?.first) {
                photo
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
            let indices = page.photoIndices ?? []
            let count = max(1, min(indices.count, 4))
            let columns = count <= 2 ? 1 : 2
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns),
                spacing: 4
            ) {
                ForEach(0..<count, id: \.self) { i in
                    if let photo = photo(at: indices[safe: i]) {
                        photo
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .aspectRatio(1, contentMode: .fill)
                    } else {
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
        }
        .padding(32)
    }

    func highlightPage(size: CGSize) -> some View {
        ZStack {
            if let photo = photo(at: page.photoIndices?.first) {
                photo
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.3))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.08))
            }
            VStack(spacing: 12) {
                Text("\u{201C}")
                    .font(.system(size: 64, design: .serif))
                    .foregroundStyle(.white.opacity(0.8))
                Text(page.text ?? "")
                    .font(.title3)
                    .italic()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
            }
            .padding(40)
        }
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

    private func photo(at index: Int?) -> Image? {
        guard let index = index, photos.indices.contains(index) else { return nil }
        return loadPhotoImage(from: photos[index])
    }

    private var photosDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Photos", isDirectory: true)
    }

    private func loadPhotoImage(from photoItem: PhotoItem) -> Image? {
        // 1. 优先从本地文件加载
        if let fileName = photoItem.localFileName {
            let fileURL = photosDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: fileURL.path),
               let data = try? Data(contentsOf: fileURL),
               let uiImage = UIImage(data: data) {
                return Image(uiImage: uiImage)
            }
        }

        // 2. Fallback: PHAsset
        if let assetID = photoItem.localAssetID {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
            guard let asset = fetchResult.firstObject else { return nil }
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.isSynchronous = true
            var resultImage: UIImage?
            manager.requestImage(
                for: asset,
                targetSize: CGSize(width: 400, height: 400),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                resultImage = image
            }
            guard let uiImage = resultImage else { return nil }
            return Image(uiImage: uiImage)
        }

        return nil
    }
}

private extension Array {
    subscript(safe index: Int?) -> Element? {
        guard let index = index, indices.contains(index) else { return nil }
        return self[index]
    }
}

import SwiftUI

struct JournalPageView: View {
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

    private func loadPhotoImage(from photoItem: PhotoItem) -> Image? {
        // Use synchronous load for rendering (may need optimization)
        guard let nsImage = loadNSImageSync(for: photoItem) else { return nil }
        return Image(nsImage: nsImage)
    }

    private func loadNSImageSync(for photoItem: PhotoItem) -> NSImage? {
        switch photoItem.source {
        case .fileURL:
            guard let identifier = photoItem.sourceIdentifier,
                  let url = URL(string: identifier),
                  FileManager.default.fileExists(atPath: url.path) else { return nil }
            return NSImage(contentsOf: url)
        case .photosLibrary:
            // For rendering, we'll use a placeholder if async load is needed
            // In practice, JournalPageView should receive pre-loaded images
            return nil
        }
    }
}

private extension Array {
    subscript(safe index: Int?) -> Element? {
        guard let index = index, indices.contains(index) else { return nil }
        return self[index]
    }
}

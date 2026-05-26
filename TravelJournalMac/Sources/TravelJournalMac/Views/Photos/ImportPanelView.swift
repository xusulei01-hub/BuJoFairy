import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ImportPanelView: View {
    let trip: Trip
    let onImport: (ImportSource) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showFileImporter = false

    var body: some View {
        VStack(spacing: 20) {
            Text("导入照片到 \(trip.name)")
                .font(.headline)

            VStack(spacing: 12) {
                Button {
                    showFileImporter = true
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text("从 Finder 文件夹导入")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 100,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("从 Photos 导入")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .frame(width: 260)

            Button("取消") {
                dismiss()
            }
        }
        .padding()
        .frame(width: 320, height: 200)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let folderURL = urls.first else { return }
                let imageURLs = scanImages(in: folderURL)
                onImport(.finder(urls: imageURLs))
            case .failure:
                break
            }
        }
        .onChange(of: selectedPhotos) { _, newItems in
            guard !newItems.isEmpty else { return }
            onImport(.photos(items: newItems))
        }
    }

    private func scanImages(in folder: URL) -> [URL] {
        let fileManager = FileManager.default
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "webp"]

        guard let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var imageURLs: [URL] = []
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if imageExtensions.contains(ext) {
                imageURLs.append(fileURL)
            }
        }
        return imageURLs.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

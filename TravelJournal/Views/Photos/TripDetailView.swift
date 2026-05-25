import SwiftUI
import PhotosUI
import SwiftData

struct TripDetailView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = PhotosViewModel()
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var showGenerateJournal = false

    var sortedPhotos: [PhotoItem] {
        (trip.photos ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    var body: some View {
        ScrollView {
            if sortedPhotos.isEmpty {
                ContentUnavailableView(
                    "还没有照片",
                    systemImage: "photo.badge.plus",
                    description: Text("点击右上角 + 导入照片")
                )
                .padding(.top, 80)
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(sortedPhotos) { photo in
                        PhotoThumbnailView(assetID: photo.localAssetID)
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                            .overlay(alignment: .bottomLeading) {
                                if let loc = photo.locationName {
                                    Text(loc.components(separatedBy: "、").first ?? loc)
                                        .font(.system(size: 9))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(.ultraThinMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                        .padding(4)
                                }
                            }
                    }
                }
                .padding(2)
            }
        }
        .navigationTitle(trip.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                PhotosPicker(selection: $selectedItems, matching: .images) {
                    Image(systemName: "plus")
                }
            }
            if !sortedPhotos.isEmpty {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showGenerateJournal = true
                    } label: {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("生成手帐")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .onChange(of: selectedItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                isImporting = true
                await viewModel.importPhotos(newItems, to: trip, modelContext: modelContext)
                selectedItems = []
                isImporting = false
            }
        }
        .overlay {
            if isImporting {
                Color.black.opacity(0.3)
                    .overlay {
                        VStack {
                            ProgressView()
                            Text("正在导入照片...")
                                .foregroundStyle(.white)
                        }
                    }
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showGenerateJournal) {
            GenerateJournalView(trip: trip)
        }
    }
}

struct PhotoThumbnailView: View {
    let assetID: String
    @State private var image: Image?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let image = image {
                image
                    .resizable()
                    .scaledToFill()
            } else if loadFailed {
                Color.gray.opacity(0.2)
                    .overlay(Image(systemName: "photo.badge.exclamationmark"))
            } else {
                Color.gray.opacity(0.1)
                    .overlay(ProgressView())
            }
        }
        .task {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
            guard let asset = fetchResult.firstObject else {
                loadFailed = true
                return
            }
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isSynchronous = false

            let size = CGSize(width: 200, height: 200)
            manager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { result, _ in
                if let result = result {
                    image = Image(uiImage: result)
                } else {
                    loadFailed = true
                }
            }
        }
    }
}

import SwiftUI

struct PhotoThumbnailView: View {
    let photo: PhotoItem
    @State private var nsImage: NSImage?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let image = nsImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else if loadFailed {
                Color.gray.opacity(0.2)
                    .overlay(
                        Image(systemName: "photo.badge.exclamationmark")
                            .foregroundStyle(.gray)
                    )
            } else {
                Color.gray.opacity(0.1)
                    .overlay(ProgressView().scaleEffect(0.8))
            }
        }
        .task {
            if let image = await photo.imageProvider.loadImage(for: photo) {
                nsImage = image
            } else {
                loadFailed = true
            }
        }
    }
}

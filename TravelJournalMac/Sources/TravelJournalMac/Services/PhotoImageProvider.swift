import Foundation
import AppKit
import Photos

protocol PhotoImageProvider {
    func loadImage(for photoItem: PhotoItem) async -> NSImage?
}

struct FileURLImageProvider: PhotoImageProvider {
    func loadImage(for photoItem: PhotoItem) async -> NSImage? {
        guard let identifier = photoItem.sourceIdentifier,
              let url = URL(string: identifier),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

struct PhotosLibraryImageProvider: PhotoImageProvider {
    func loadImage(for photoItem: PhotoItem) async -> NSImage? {
        guard let identifier = photoItem.sourceIdentifier else { return nil }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }

        return await withCheckedContinuation { continuation in
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.resizeMode = .fast

            let size = CGSize(width: 800, height: 800)
            manager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

extension PhotoItem {
    var imageProvider: PhotoImageProvider {
        switch source {
        case .fileURL:
            return FileURLImageProvider()
        case .photosLibrary:
            return PhotosLibraryImageProvider()
        }
    }
}

import SwiftUI

// MARK: - Cross-Platform Image
// UIImage exists only on iOS; NSImage is the macOS equivalent.
// `PlatformImage` + `Image(platformImage:)` let Shared views compile on both.

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #elseif os(macOS)
        self.init(nsImage: platformImage)
        #endif
    }
}

extension PlatformImage {
    /// JPEG bytes for upload. Downscales to `maxDimension` first — a modern
    /// iPhone photo is 4000px wide and the server re-encodes anyway, so
    /// sending the original just costs the user cellular data.
    func jpegDataForUpload(maxDimension: CGFloat = 1600, quality: CGFloat = 0.8) -> Data? {
        #if os(iOS)
        let scale = min(1, maxDimension / max(size.width, size.height))
        guard scale < 1 else { return jpegData(compressionQuality: quality) }
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: quality)
        #elseif os(macOS)
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        #endif
    }
}

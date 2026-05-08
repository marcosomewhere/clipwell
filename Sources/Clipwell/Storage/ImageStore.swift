// Storage/ImageStore.swift
// Clipwell — Handles image normalization and thumbnail generation.

import AppKit
import CoreGraphics
import Foundation

enum ImageStore {

    /// Maximum dimension (width or height) for a stored image in pixels.
    private static let maxStoredDimension: CGFloat = 2048
    /// Thumbnail longest side in pixels.
    private static let thumbnailDimension: CGFloat = 120
    /// JPEG compression quality for thumbnails (0–1).
    private static let thumbnailQuality: CGFloat = 0.75

    // MARK: - Public API

    /// Converts an NSImage into normalized PNG data and a JPEG thumbnail.
    /// Returns nil if the image cannot be rasterized.
    static func prepareImageContent(from image: NSImage) -> ClipboardContent? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
        let targetSize = scaledSize(originalSize, maxDimension: maxStoredDimension)

        guard
            let pngData = rasterize(cgImage, to: targetSize, format: .png),
            let thumbData = rasterize(cgImage, to: scaledSize(originalSize, maxDimension: thumbnailDimension), format: .jpeg)
        else {
            return nil
        }

        return .image(pngData: pngData, thumbnailData: thumbData)
    }

    // MARK: - Private

    private enum OutputFormat { case png, jpeg }

    private static func rasterize(_ cgImage: CGImage, to size: CGSize, format: OutputFormat) -> Data? {
        let width = Int(size.width)
        let height = Int(size.height)
        guard width > 0, height > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        guard let resultCGImage = context.makeImage() else { return nil }

        let nsImage = NSImage(cgImage: resultCGImage, size: size)
        switch format {
        case .png:
            return nsImage.pngData()
        case .jpeg:
            return nsImage.jpegData(compressionFactor: thumbnailQuality)
        }
    }

    private static func scaledSize(_ original: CGSize, maxDimension: CGFloat) -> CGSize {
        let longest = max(original.width, original.height)
        guard longest > maxDimension else { return original }
        let scale = maxDimension / longest
        return CGSize(width: (original.width * scale).rounded(), height: (original.height * scale).rounded())
    }
}

// MARK: - NSImage helpers

private extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    func jpegData(compressionFactor: CGFloat) -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor])
    }
}

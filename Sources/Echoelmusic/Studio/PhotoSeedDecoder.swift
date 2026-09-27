// PhotoSeedDecoder.swift
// Echoel — MS3 (founder order 2026-09-27): the ONE impure step between a picked photo and its
// `MediaSeed`. ImageIO reads the file, makes two bounded thumbnails, and hands the small one's
// pixels to the pure analysis (`Core/MediaSeed.swift`).
//
// ⭐ BOUNDED BEFORE ANYTHING IS DECODED. `CGImageSourceCreateThumbnailAtIndex` with a maximum
// pixel size decodes straight to that size — a 48-megapixel photo is never held at full
// resolution. Two thumbnails: `previewSide` for the screen and `MediaSeedAnalysis.maxAnalysisSide`
// for the numbers. The pixel buffer is `maxAnalysisSide² × 4` bytes at most.
//
// ⭐ OFF THE MAIN ACTOR, NEVER ON THE AUDIO THREAD. `decode(url:)` is synchronous and
// nonisolated; the card calls it from a detached task. Nothing here touches the audio engine,
// the bus or the transport. The decode is not interrupted mid-way — it is two thumbnails and
// short — but a cancelled pick discards its result (`PhotoSeedCard`).
//
// ⚠️ ORIENTATION IS APPLIED (`kCGImageSourceCreateThumbnailWithTransform`), so the preview stands
// the way the photo was taken. Colour statistics do not depend on it.

#if canImport(ImageIO) && canImport(CoreGraphics)
import Foundation
import ImageIO
import CoreGraphics

enum PhotoSeedDecoder {

    /// The longest side of the on-screen preview.
    static let previewSide = 512

    /// A decoded photo: its seed and a small preview. `CGImage` is immutable once made, so
    /// handing it from the decoding task to the main actor shares nothing that can change.
    struct Decoded: @unchecked Sendable {
        let seed: MediaSeed
        let preview: CGImage
    }

    /// The seed and preview of an image file, or `nil` when ImageIO cannot read it.
    static func decode(url: URL) -> Decoded? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              CGImageSourceGetCount(source) > 0,
              let preview = thumbnail(of: source, maxSide: previewSide),
              let small = thumbnail(of: source, maxSide: MediaSeedAnalysis.maxAnalysisSide),
              let pixels = rgba8(small),
              let seed = MediaSeedAnalysis.analyzeRGBA8(pixels.bytes, width: pixels.width,
                                                        height: pixels.height,
                                                        bytesPerRow: pixels.bytesPerRow) else {
            return nil
        }
        return Decoded(seed: seed, preview: preview)
    }

    /// A thumbnail no longer than `maxSide` on either side, oriented upright.
    static func thumbnail(of source: CGImageSource, maxSide: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// The image drawn into a tightly packed sRGB RGBA8 buffer (alpha skipped). Refuses an image
    /// over the analysis limit rather than drawing it — the thumbnail step should have shrunk it.
    static func rgba8(_ image: CGImage) -> (bytes: [UInt8], width: Int, height: Int, bytesPerRow: Int)? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0,
              width <= MediaSeedAnalysis.maxAnalysisSide,
              height <= MediaSeedAnalysis.maxAnalysisSide,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: space,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? (bytes, width, height, bytesPerRow) : nil
    }
}
#endif

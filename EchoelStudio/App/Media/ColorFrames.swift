import AVFoundation
import CoreGraphics
import EchoelCore
import Foundation

/// A few small frames of a video part as pixels, for Auto Enhance and Match Color (COLOR). Read
/// off the main thread; the file is only read.
enum ColorFrames {
    /// Frames read from a part, evenly across it.
    nonisolated static let frameCount = 5
    /// The longest edge a frame is read at: enough for a histogram, cheap to read.
    nonisolated static let edge = 96

    /// The pixels of `frameCount` frames of `url` between `fromSeconds` and `fromSeconds + seconds`,
    /// upright, encoded sRGB. Empty when nothing could be read.
    nonisolated static func pixels(of url: URL, fromSeconds start: Double, seconds: Double) async -> [ColorSample] {
        guard start.isFinite, seconds.isFinite, seconds > 0 else { return [] }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: edge, height: edge)
        let slack = CMTime(seconds: Swift.min(0.5, seconds / Double(frameCount * 2)), preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = slack
        generator.requestedTimeToleranceAfter = slack
        var pixels: [ColorSample] = []
        for index in 0..<frameCount {
            let moment = Swift.max(0, start) + seconds * (Double(index) + 0.5) / Double(frameCount)
            guard let frame = try? await generator.image(at: CMTime(seconds: moment, preferredTimescale: 600)) else { continue }
            pixels += samples(of: frame.image)
        }
        return pixels
    }

    /// Every pixel of `image`, drawn into sRGB.
    nonisolated static func samples(of image: CGImage) -> [ColorSample] {
        let width = image.width, height = image.height
        guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return [] }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = bytes.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return [] }
        return stride(from: 0, to: bytes.count, by: 4).map { index in
            ColorSample(red: Double(bytes[index]) / 255, green: Double(bytes[index + 1]) / 255, blue: Double(bytes[index + 2]) / 255)
        }
    }
}

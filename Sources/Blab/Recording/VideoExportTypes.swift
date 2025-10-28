import Foundation
import AVFoundation
import CoreGraphics

/// Video export format and resolution types
/// Supports multiple platforms: Instagram, TikTok, YouTube, etc.

// MARK: - Video Resolution

enum VideoResolution {
    case hd720          // 1280x720 (HD)
    case hd1080         // 1920x1080 (Full HD)
    case hd4K           // 3840x2160 (4K UHD)
    case vertical1080   // 1080x1920 (Stories/Reels/TikTok)
    case square1080     // 1080x1080 (Instagram Feed)
    case custom(width: Int, height: Int)

    var size: CGSize {
        switch self {
        case .hd720:
            return CGSize(width: 1280, height: 720)
        case .hd1080:
            return CGSize(width: 1920, height: 1080)
        case .hd4K:
            return CGSize(width: 3840, height: 2160)
        case .vertical1080:
            return CGSize(width: 1080, height: 1920)
        case .square1080:
            return CGSize(width: 1080, height: 1080)
        case .custom(let width, let height):
            return CGSize(width: width, height: height)
        }
    }

    var aspectRatio: String {
        switch self {
        case .hd720, .hd1080, .hd4K:
            return "16:9"
        case .vertical1080:
            return "9:16"
        case .square1080:
            return "1:1"
        case .custom(let width, let height):
            let gcd = greatestCommonDivisor(width, height)
            return "\(width/gcd):\(height/gcd)"
        }
    }

    private func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        return b == 0 ? a : greatestCommonDivisor(b, a % b)
    }
}

// MARK: - Video Format

enum VideoFormat {
    case mp4        // H.264, most compatible
    case mov        // ProRes, highest quality
    case hevc       // H.265, better compression

    var fileExtension: String {
        switch self {
        case .mp4: return "mp4"
        case .mov: return "mov"
        case .hevc: return "mp4"  // HEVC in MP4 container
        }
    }

    var fileType: AVFileType {
        switch self {
        case .mp4: return .mp4
        case .mov: return .mov
        case .hevc: return .mp4
        }
    }

    var codec: AVVideoCodecType {
        switch self {
        case .mp4: return .h264
        case .mov: return .h264  // Can use ProRes on supported devices
        case .hevc: return .hevc
        }
    }
}

// MARK: - Video Quality

enum VideoQuality {
    case low        // 2 Mbps
    case medium     // 5 Mbps
    case high       // 10 Mbps
    case veryHigh   // 20 Mbps
    case maximum    // 40 Mbps (4K)

    var bitrate: Int {
        switch self {
        case .low: return 2_000_000
        case .medium: return 5_000_000
        case .high: return 10_000_000
        case .veryHigh: return 20_000_000
        case .maximum: return 40_000_000
        }
    }

    /// Recommended quality for resolution
    static func recommended(for resolution: VideoResolution) -> VideoQuality {
        switch resolution {
        case .hd720:
            return .medium
        case .hd1080, .vertical1080, .square1080:
            return .high
        case .hd4K:
            return .maximum
        case .custom(let width, _):
            if width >= 3840 {
                return .maximum
            } else if width >= 1920 {
                return .high
            } else {
                return .medium
            }
        }
    }
}

// MARK: - Video Frame Rate

enum VideoFrameRate: Int {
    case fps24 = 24
    case fps30 = 30
    case fps60 = 60
    case fps120 = 120  // iPhone ProMotion

    var displayName: String {
        return "\(rawValue) fps"
    }
}

// MARK: - Platform Preset

enum PlatformPreset {
    case instagramReels
    case instagramStory
    case instagramFeed
    case tiktok
    case youtubeShorts
    case youtubeVideo
    case snapchatSpotlight
    case twitter

    var resolution: VideoResolution {
        switch self {
        case .instagramReels, .instagramStory, .tiktok, .youtubeShorts, .snapchatSpotlight:
            return .vertical1080
        case .instagramFeed:
            return .square1080
        case .youtubeVideo, .twitter:
            return .hd1080
        }
    }

    var maxDuration: TimeInterval {
        switch self {
        case .instagramReels:
            return 90.0  // 90 seconds
        case .instagramStory:
            return 15.0  // 15 seconds
        case .instagramFeed:
            return 60.0  // 60 seconds
        case .tiktok:
            return 180.0  // 3 minutes
        case .youtubeShorts:
            return 60.0  // 60 seconds
        case .youtubeVideo:
            return 3600.0  // 1 hour (practical limit)
        case .snapchatSpotlight:
            return 60.0  // 60 seconds
        case .twitter:
            return 140.0  // 2:20 minutes
        }
    }

    var displayName: String {
        switch self {
        case .instagramReels: return "Instagram Reels"
        case .instagramStory: return "Instagram Story"
        case .instagramFeed: return "Instagram Feed"
        case .tiktok: return "TikTok"
        case .youtubeShorts: return "YouTube Shorts"
        case .youtubeVideo: return "YouTube Video"
        case .snapchatSpotlight: return "Snapchat Spotlight"
        case .twitter: return "Twitter/X"
        }
    }
}

// MARK: - Video Export Configuration

struct VideoExportConfiguration {
    let resolution: VideoResolution
    let format: VideoFormat
    let quality: VideoQuality
    let frameRate: VideoFrameRate
    let includeAudio: Bool
    let outputURL: URL?

    init(
        resolution: VideoResolution = .hd1080,
        format: VideoFormat = .mp4,
        quality: VideoQuality? = nil,
        frameRate: VideoFrameRate = .fps60,
        includeAudio: Bool = true,
        outputURL: URL? = nil
    ) {
        self.resolution = resolution
        self.format = format
        self.quality = quality ?? VideoQuality.recommended(for: resolution)
        self.frameRate = frameRate
        self.includeAudio = includeAudio
        self.outputURL = outputURL
    }

    /// Create configuration from platform preset
    static func forPlatform(_ platform: PlatformPreset) -> VideoExportConfiguration {
        return VideoExportConfiguration(
            resolution: platform.resolution,
            format: .mp4,
            quality: .high,
            frameRate: .fps30,  // Most platforms prefer 30fps
            includeAudio: true,
            outputURL: nil
        )
    }

    /// Video settings dictionary for AVAssetWriter
    var videoSettings: [String: Any] {
        let width = Int(resolution.size.width)
        let height = Int(resolution.size.height)

        return [
            AVVideoCodecKey: format.codec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: quality.bitrate,
                AVVideoMaxKeyFrameIntervalKey: frameRate.rawValue,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ] as [String: Any]
        ]
    }

    /// Audio settings dictionary for AVAssetWriter
    var audioSettings: [String: Any] {
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100.0,
            AVEncoderBitRateKey: 128_000
        ]
    }
}

// MARK: - Video Export Error

enum VideoExportError: LocalizedError {
    case assetWriterCreationFailed
    case assetWriterNotReady
    case videoInputCreationFailed
    case audioInputCreationFailed
    case pixelBufferCreationFailed
    case writingFailed(String)
    case encodingFailed(String)
    case invalidDuration
    case fileAlreadyExists
    case insufficientStorage
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .assetWriterCreationFailed:
            return "Failed to create video writer"
        case .assetWriterNotReady:
            return "Video writer is not ready"
        case .videoInputCreationFailed:
            return "Failed to create video input"
        case .audioInputCreationFailed:
            return "Failed to create audio input"
        case .pixelBufferCreationFailed:
            return "Failed to create pixel buffer"
        case .writingFailed(let message):
            return "Video writing failed: \(message)"
        case .encodingFailed(let message):
            return "Video encoding failed: \(message)"
        case .invalidDuration:
            return "Invalid video duration"
        case .fileAlreadyExists:
            return "Output file already exists"
        case .insufficientStorage:
            return "Insufficient storage space"
        case .unsupportedFormat:
            return "Unsupported video format"
        }
    }
}

// MARK: - Video Export Progress

struct VideoExportProgress {
    let currentFrame: Int
    let totalFrames: Int
    let currentTime: TimeInterval
    let totalDuration: TimeInterval
    let bytesWritten: Int64

    var percentage: Double {
        guard totalFrames > 0 else { return 0.0 }
        return Double(currentFrame) / Double(totalFrames) * 100.0
    }

    var timeRemaining: TimeInterval {
        guard currentFrame > 0 else { return 0.0 }
        let framesRemaining = totalFrames - currentFrame
        let timePerFrame = currentTime / Double(currentFrame)
        return timePerFrame * Double(framesRemaining)
    }
}

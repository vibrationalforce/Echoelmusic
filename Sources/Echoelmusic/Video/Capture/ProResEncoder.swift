import Foundation
import AVFoundation
import VideoToolbox

/// Professional ProRes Encoder for Cinema-Grade Video
///
/// Supported ProRes Variants:
/// - ProRes 422 Proxy (low bandwidth, proxy editing)
/// - ProRes 422 LT (light, ~100 Mbps @ 1080p)
/// - ProRes 422 (standard, ~150 Mbps @ 1080p)
/// - ProRes 422 HQ (high quality, ~220 Mbps @ 1080p) 🔥 PRIMARY
/// - ProRes 4444 (with alpha channel, ~330 Mbps @ 1080p)
/// - ProRes 4444 XQ (extreme quality, ~500 Mbps @ 1080p)
/// - ProRes RAW (iPhone 15 Pro+, requires special handling)
///
/// Use Cases:
/// - Professional film production
/// - Broadcast television
/// - Post-production workflows
/// - Archive/mastering
@MainActor
class ProResEncoder: ObservableObject {

    // MARK: - ProRes Codec Types

    enum ProResCodec: String, CaseIterable {
        case proxy = "ProRes 422 Proxy"
        case lt = "ProRes 422 LT"
        case standard = "ProRes 422"
        case hq = "ProRes 422 HQ"      // 🔥 Most commonly used
        case fourFourFour = "ProRes 4444"
        case fourFourFourXQ = "ProRes 4444 XQ"

        var codecType: AVVideoCodecType {
            switch self {
            case .proxy: return AVVideoCodecType(rawValue: "apcn")  // ProRes 422 Proxy
            case .lt: return AVVideoCodecType(rawValue: "apcs")     // ProRes 422 LT
            case .standard: return AVVideoCodecType(rawValue: "apcn") // ProRes 422
            case .hq: return AVVideoCodecType(rawValue: "apch")     // ProRes 422 HQ
            case .fourFourFour: return AVVideoCodecType(rawValue: "ap4h") // ProRes 4444
            case .fourFourFourXQ: return AVVideoCodecType(rawValue: "ap4x") // ProRes 4444 XQ
            }
        }

        var fourCC: String {
            switch self {
            case .proxy: return "apco"     // 'apco' = ProRes Proxy
            case .lt: return "apcs"        // 'apcs' = ProRes 422 LT
            case .standard: return "apcn"  // 'apcn' = ProRes 422
            case .hq: return "apch"        // 'apch' = ProRes 422 HQ
            case .fourFourFour: return "ap4h"  // 'ap4h' = ProRes 4444
            case .fourFourFourXQ: return "ap4x" // 'ap4x' = ProRes 4444 XQ
            }
        }

        var bitrate: Int {
            // Approximate bitrates for 1920x1080 @ 24fps (Mbps)
            switch self {
            case .proxy: return 45
            case .lt: return 100
            case .standard: return 150
            case .hq: return 220
            case .fourFourFour: return 330
            case .fourFourFourXQ: return 500
            }
        }

        var description: String {
            switch self {
            case .proxy:
                return "Lightweight proxy for offline editing (~45 Mbps)"
            case .lt:
                return "High-quality, smaller file size (~100 Mbps)"
            case .standard:
                return "Standard quality for most workflows (~150 Mbps)"
            case .hq:
                return "High quality for professional production (~220 Mbps) 🔥"
            case .fourFourFour:
                return "Highest quality with alpha channel (~330 Mbps)"
            case .fourFourFourXQ:
                return "Extreme quality for mastering (~500 Mbps)"
            }
        }

        var supportsAlpha: Bool {
            return self == .fourFourFour || self == .fourFourFourXQ
        }
    }


    // MARK: - Encoding Configuration

    struct EncodingConfig {
        var codec: ProResCodec = .hq  // Default: ProRes 422 HQ
        var resolution: VideoResolution = .uhd4k
        var frameRate: Int = 24  // Cinema standard
        var colorSpace: ColorSpace = .rec709
        var includeAudio: Bool = true

        enum VideoResolution {
            case hd720p      // 1280x720
            case hd1080p     // 1920x1080
            case uhd4k       // 3840x2160 (UHD)
            case dci4k       // 4096x2160 (DCI 4K)
            case uhd8k       // 7680x4320

            var size: CGSize {
                switch self {
                case .hd720p: return CGSize(width: 1280, height: 720)
                case .hd1080p: return CGSize(width: 1920, height: 1080)
                case .uhd4k: return CGSize(width: 3840, height: 2160)
                case .dci4k: return CGSize(width: 4096, height: 2160)
                case .uhd8k: return CGSize(width: 7680, height: 4320)
                }
            }

            var displayName: String {
                switch self {
                case .hd720p: return "HD 720p"
                case .hd1080p: return "Full HD 1080p"
                case .uhd4k: return "4K UHD"
                case .dci4k: return "4K DCI"
                case .uhd8k: return "8K UHD"
                }
            }
        }

        enum ColorSpace {
            case rec709      // HD/SDR standard
            case rec2020     // HDR/wide gamut
            case displayP3   // Apple displays

            var name: String {
                switch self {
                case .rec709: return kCVImageBufferYCbCrMatrix_ITU_R_709_2 as String
                case .rec2020: return kCVImageBufferYCbCrMatrix_ITU_R_2020 as String
                case .displayP3: return "Display P3"
                }
            }
        }
    }


    // MARK: - State

    @Published var isEncoding: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentConfig: EncodingConfig = EncodingConfig()

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?


    // MARK: - Initialization

    init() {
        print("✅ ProResEncoder initialized")
        print("   Default codec: \(currentConfig.codec.rawValue)")
    }


    // MARK: - Public API

    /// Start ProRes encoding session
    func startEncoding(outputURL: URL, config: EncodingConfig = EncodingConfig()) throws {
        guard !isEncoding else {
            throw EncodingError.alreadyEncoding
        }

        currentConfig = config

        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)

        // Create asset writer
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        // Setup video input
        try setupVideoInput()

        // Setup audio input (if enabled)
        if config.includeAudio {
            try setupAudioInput()
        }

        // Start writing
        guard assetWriter?.startWriting() == true else {
            throw EncodingError.failedToStartWriting
        }

        assetWriter?.startSession(atSourceTime: .zero)
        isEncoding = true

        print("🎬 ProRes encoding started")
        print("   Codec: \(config.codec.rawValue)")
        print("   Resolution: \(config.resolution.displayName)")
        print("   Frame Rate: \(config.frameRate) fps")
        print("   Est. Bitrate: ~\(config.codec.bitrate) Mbps")
    }

    /// Stop encoding and finalize file
    func stopEncoding() async throws -> URL? {
        guard isEncoding else { return nil }

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        await assetWriter?.finishWriting()

        isEncoding = false
        let outputURL = assetWriter?.outputURL

        if let error = assetWriter?.error {
            throw EncodingError.encodingFailed(error.localizedDescription)
        }

        print("🎬 ProRes encoding complete")
        print("   Output: \(outputURL?.lastPathComponent ?? "unknown")")

        return outputURL
    }

    /// Append video frame
    func appendVideoFrame(_ pixelBuffer: CVPixelBuffer, at time: CMTime) throws {
        guard isEncoding,
              let videoInput = videoInput,
              videoInput.isReadyForMoreMediaData else {
            throw EncodingError.notReadyForData
        }

        guard videoInput.append(pixelBuffer, withPresentationTime: time) else {
            throw EncodingError.appendFailed
        }
    }

    /// Append audio sample
    func appendAudioSample(_ sampleBuffer: CMSampleBuffer) throws {
        guard isEncoding,
              let audioInput = audioInput,
              audioInput.isReadyForMoreMediaData else {
            throw EncodingError.notReadyForData
        }

        guard audioInput.append(sampleBuffer) else {
            throw EncodingError.appendFailed
        }
    }


    // MARK: - Setup

    private func setupVideoInput() throws {
        let resolution = currentConfig.resolution.size

        // ProRes video settings
        var videoSettings: [String: Any] = [
            AVVideoCodecKey: currentConfig.codec.fourCC,
            AVVideoWidthKey: Int(resolution.width),
            AVVideoHeightKey: Int(resolution.height)
        ]

        // Color properties
        var compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: currentConfig.codec.bitrate * 1_000_000,
            AVVideoExpectedSourceFrameRateKey: currentConfig.frameRate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        ]

        // Add color space
        compressionProperties[AVVideoColorPropertiesKey] = [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: currentConfig.colorSpace.name
        ]

        videoSettings[AVVideoCompressionPropertiesKey] = compressionProperties

        // Create video input
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        guard let videoInput = videoInput,
              assetWriter?.canAdd(videoInput) == true else {
            throw EncodingError.cannotAddVideoInput
        }

        assetWriter?.add(videoInput)

        print("✅ ProRes video input configured")
    }

    private func setupAudioInput() throws {
        // Audio settings (PCM for ProRes)
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48000,  // Professional standard
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = true

        guard let audioInput = audioInput,
              assetWriter?.canAdd(audioInput) == true else {
            throw EncodingError.cannotAddAudioInput
        }

        assetWriter?.add(audioInput)

        print("✅ ProRes audio input configured")
    }


    // MARK: - Errors

    enum EncodingError: Error {
        case alreadyEncoding
        case failedToStartWriting
        case notReadyForData
        case appendFailed
        case encodingFailed(String)
        case cannotAddVideoInput
        case cannotAddAudioInput
    }


    // MARK: - Utility

    /// Calculate file size estimate
    func estimatedFileSize(durationSeconds: Double) -> Int64 {
        let bitrate = Int64(currentConfig.codec.bitrate) * 1_000_000  // Convert to bps
        let bytes = Int64(durationSeconds) * bitrate / 8
        return bytes
    }

    /// Format file size for display
    func formattedFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}


// MARK: - Helper Extensions

extension AVAssetWriterInput {
    func append(_ pixelBuffer: CVPixelBuffer, withPresentationTime time: CMTime) -> Bool {
        let sampleBuffer = createSampleBuffer(from: pixelBuffer, presentationTime: time)
        guard let sampleBuffer = sampleBuffer else { return false }
        return append(sampleBuffer)
    }

    private func createSampleBuffer(from pixelBuffer: CVPixelBuffer, presentationTime: CMTime) -> CMSampleBuffer? {
        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: createFormatDescription(from: pixelBuffer),
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )

        return status == noErr ? sampleBuffer : nil
    }

    private func createFormatDescription(from pixelBuffer: CVPixelBuffer) -> CMFormatDescription? {
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        return formatDescription
    }
}

import Foundation
import AVFoundation
import Metal
import MetalKit
import CoreMedia
import Combine

/// Core video recording engine using AVAssetWriter
/// Handles real-time encoding of Metal textures + audio to video file
@MainActor
class VideoRecordingEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0.0
    @Published var progress: VideoExportProgress?
    @Published var errorMessage: String?

    // MARK: - Configuration

    private let configuration: VideoExportConfiguration
    private let outputURL: URL

    // MARK: - AVAssetWriter Components

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    // MARK: - Recording State

    private var startTime: CMTime?
    private var frameCount: Int = 0
    private var isFinishing: Bool = false

    // MARK: - Metal Components

    private let device: MTLDevice
    private let textureCache: CVMetalTextureCache

    // MARK: - Performance Tracking

    private var bytesWritten: Int64 = 0
    private var lastProgressUpdate: Date = Date()


    // MARK: - Initialization

    init(configuration: VideoExportConfiguration, device: MTLDevice) throws {
        self.configuration = configuration
        self.device = device

        // Generate output URL if not provided
        if let providedURL = configuration.outputURL {
            self.outputURL = providedURL
        } else {
            self.outputURL = Self.generateOutputURL(format: configuration.format)
        }

        // Remove existing file if needed
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        // Create texture cache
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        guard let textureCache = cache else {
            throw VideoExportError.pixelBufferCreationFailed
        }
        self.textureCache = textureCache

        print("🎬 VideoRecordingEngine initialized")
        print("   Output: \(outputURL.lastPathComponent)")
        print("   Resolution: \(configuration.resolution.size)")
        print("   Format: \(configuration.format.fileExtension)")
        print("   Quality: \(configuration.quality.bitrate / 1_000_000) Mbps")
    }


    // MARK: - Recording Control

    /// Start video recording
    func startRecording() throws {
        guard !isRecording else {
            print("⚠️ Already recording")
            return
        }

        // Create asset writer
        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: configuration.format.fileType)
        } catch {
            throw VideoExportError.assetWriterCreationFailed
        }

        guard let assetWriter = assetWriter else {
            throw VideoExportError.assetWriterCreationFailed
        }

        // Setup video input
        try setupVideoInput(assetWriter: assetWriter)

        // Setup audio input (if enabled)
        if configuration.includeAudio {
            try setupAudioInput(assetWriter: assetWriter)
        }

        // Start writing
        guard assetWriter.startWriting() else {
            throw VideoExportError.writingFailed("Could not start writing")
        }

        assetWriter.startSession(atSourceTime: .zero)

        // Reset state
        startTime = .zero
        frameCount = 0
        recordingDuration = 0.0
        bytesWritten = 0
        isRecording = true
        isFinishing = false

        print("▶️ Video recording started")
    }

    /// Stop video recording and finalize file
    func stopRecording() async throws -> URL {
        guard isRecording, !isFinishing else {
            throw VideoExportError.assetWriterNotReady
        }

        isFinishing = true
        isRecording = false

        // Mark inputs as finished
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        // Finish writing
        guard let assetWriter = assetWriter else {
            throw VideoExportError.assetWriterNotReady
        }

        await assetWriter.finishWriting()

        if assetWriter.status == .failed {
            if let error = assetWriter.error {
                throw VideoExportError.encodingFailed(error.localizedDescription)
            } else {
                throw VideoExportError.encodingFailed("Unknown error")
            }
        }

        print("⏹️ Video recording stopped")
        print("   Duration: \(String(format: "%.2f", recordingDuration))s")
        print("   Frames: \(frameCount)")
        print("   Size: \(bytesWritten / 1_000_000) MB")

        return outputURL
    }

    /// Cancel recording without saving
    func cancelRecording() {
        guard isRecording else { return }

        isRecording = false
        isFinishing = false

        assetWriter?.cancelWriting()

        // Remove partial file
        try? FileManager.default.removeItem(at: outputURL)

        print("❌ Video recording cancelled")
    }


    // MARK: - Frame Appending

    /// Append video frame from Metal texture
    /// - Parameters:
    ///   - texture: Metal texture containing the frame
    ///   - presentationTime: Time at which to present this frame
    func appendVideoFrame(texture: MTLTexture, at presentationTime: CMTime) throws {
        guard isRecording, !isFinishing else { return }
        guard let videoInput = videoInput, videoInput.isReadyForMoreMediaData else { return }

        // Create pixel buffer from Metal texture
        guard let pixelBuffer = try? createPixelBuffer(from: texture) else {
            throw VideoExportError.pixelBufferCreationFailed
        }

        // Append to video
        guard pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: presentationTime) == true else {
            throw VideoExportError.writingFailed("Failed to append video frame")
        }

        frameCount += 1
        recordingDuration = CMTimeGetSeconds(presentationTime)

        // Update progress periodically (every 0.5 seconds)
        let now = Date()
        if now.timeIntervalSince(lastProgressUpdate) >= 0.5 {
            updateProgress()
            lastProgressUpdate = now
        }
    }

    /// Append audio sample buffer
    /// - Parameter sampleBuffer: Audio sample buffer from microphone/audio engine
    func appendAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording, !isFinishing else { return }
        guard configuration.includeAudio else { return }
        guard let audioInput = audioInput, audioInput.isReadyForMoreMediaData else { return }

        audioInput.append(sampleBuffer)
    }


    // MARK: - Setup Methods

    private func setupVideoInput(assetWriter: AVAssetWriter) throws {
        let videoSettings = configuration.videoSettings

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        guard let videoInput = videoInput else {
            throw VideoExportError.videoInputCreationFailed
        }

        videoInput.expectsMediaDataInRealTime = true

        // Setup pixel buffer adaptor
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: Int(configuration.resolution.size.width),
            kCVPixelBufferHeightKey as String: Int(configuration.resolution.size.height),
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        guard assetWriter.canAdd(videoInput) else {
            throw VideoExportError.videoInputCreationFailed
        }

        assetWriter.add(videoInput)
    }

    private func setupAudioInput(assetWriter: AVAssetWriter) throws {
        let audioSettings = configuration.audioSettings

        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        guard let audioInput = audioInput else {
            throw VideoExportError.audioInputCreationFailed
        }

        audioInput.expectsMediaDataInRealTime = true

        guard assetWriter.canAdd(audioInput) else {
            throw VideoExportError.audioInputCreationFailed
        }

        assetWriter.add(audioInput)
    }


    // MARK: - Pixel Buffer Creation

    /// Create CVPixelBuffer from Metal texture
    private func createPixelBuffer(from texture: MTLTexture) throws -> CVPixelBuffer {
        let width = texture.width
        let height = texture.height

        // Create pixel buffer
        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw VideoExportError.pixelBufferCreationFailed
        }

        // Lock pixel buffer
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        // Get pixel buffer base address
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            throw VideoExportError.pixelBufferCreationFailed
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        // Copy texture data to pixel buffer
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.getBytes(
            baseAddress,
            bytesPerRow: bytesPerRow,
            from: region,
            mipmapLevel: 0
        )

        return buffer
    }


    // MARK: - Progress Tracking

    private func updateProgress() {
        let estimatedTotalFrames = Int(recordingDuration * Double(configuration.frameRate.rawValue))

        // Estimate file size (very rough)
        let estimatedBytesPerSecond = Int64(configuration.quality.bitrate / 8)
        bytesWritten = Int64(recordingDuration) * estimatedBytesPerSecond

        progress = VideoExportProgress(
            currentFrame: frameCount,
            totalFrames: max(frameCount, estimatedTotalFrames),
            currentTime: recordingDuration,
            totalDuration: recordingDuration,  // Unknown during recording
            bytesWritten: bytesWritten
        )
    }


    // MARK: - URL Generation

    private static func generateOutputURL(format: VideoFormat) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDir = documentsPath.appendingPathComponent("Videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ".", with: "-")

        let filename = "BLAB_\(timestamp).\(format.fileExtension)"
        return videosDir.appendingPathComponent(filename)
    }


    // MARK: - Storage Check

    /// Check if there's enough storage space for recording
    static func hasEnoughStorage(estimatedDuration: TimeInterval, quality: VideoQuality) -> Bool {
        let estimatedSize = Int64(estimatedDuration) * Int64(quality.bitrate / 8)
        let requiredSpace = estimatedSize * 2  // 2x buffer for safety

        do {
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let availableSpace = values.volumeAvailableCapacity {
                return Int64(availableSpace) > requiredSpace
            }
        } catch {
            print("⚠️ Could not check storage: \(error)")
        }

        return false  // Assume not enough space if we can't check
    }
}


// MARK: - Recording State Extension

extension VideoRecordingEngine {
    var recordingInfo: String {
        guard isRecording else {
            return "Not recording"
        }

        return """
        Recording: \(String(format: "%.1f", recordingDuration))s
        Frames: \(frameCount)
        FPS: \(frameCount > 0 ? Int(Double(frameCount) / recordingDuration) : 0)
        Size: ~\(bytesWritten / 1_000_000) MB
        """
    }
}

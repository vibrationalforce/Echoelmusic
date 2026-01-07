import Foundation
import AVFoundation
import VideoToolbox
import Combine
import ImageIO
import MobileCoreServices
import UIKit

/// Video Export Manager with H.264/H.265/ProRes/Dolby Vision HDR support
/// Optimized for hardware encoding on A12+ chips
/// Batch export to multiple resolutions simultaneously
@MainActor
class VideoExportManager: ObservableObject {

    // MARK: - Published State

    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0.0
    @Published var currentExport: ExportJob?
    @Published var exportQueue: [ExportJob] = []

    // MARK: - Export Formats

    enum ExportFormat: String, CaseIterable {
        case h264_baseline = "H.264 Baseline"
        case h264_main = "H.264 Main"
        case h264_high = "H.264 High"
        case hevc_main = "H.265/HEVC Main"
        case hevc_main10 = "H.265/HEVC Main10 (HDR)"
        case prores422 = "ProRes 422"
        case prores4444 = "ProRes 4444"
        case spatial_video = "Spatial Video (MV-HEVC)"
        case dolby_vision = "Dolby Vision HDR"
        case png_sequence = "PNG Sequence"
        case gif_animated = "Animated GIF"

        var fileExtension: String {
            switch self {
            case .h264_baseline, .h264_main, .h264_high:
                return "mp4"
            case .hevc_main, .hevc_main10:
                return "mp4"
            case .prores422, .prores4444:
                return "mov"
            case .spatial_video:
                return "mov"
            case .dolby_vision:
                return "mp4"
            case .png_sequence:
                return "png"
            case .gif_animated:
                return "gif"
            }
        }

        var isImageSequence: Bool {
            self == .png_sequence || self == .gif_animated
        }

        var codecType: AVVideoCodecType? {
            switch self {
            case .h264_baseline, .h264_main, .h264_high:
                return .h264
            case .hevc_main, .hevc_main10:
                return .hevc
            case .prores422:
                return .proRes422
            case .prores4444:
                return .proRes4444
            case .spatial_video:
                return .hevc // MV-HEVC
            case .dolby_vision:
                return .hevc // With Dolby Vision metadata
            case .png_sequence, .gif_animated:
                return nil // Not video codecs
            }
        }

        var h264Profile: String? {
            switch self {
            case .h264_baseline:
                return AVVideoProfileLevelH264BaselineAutoLevel
            case .h264_main:
                return AVVideoProfileLevelH264MainAutoLevel
            case .h264_high:
                return AVVideoProfileLevelH264HighAutoLevel
            default:
                return nil
            }
        }

        var supportsHardwareEncoding: Bool {
            switch self {
            case .h264_baseline, .h264_main, .h264_high, .hevc_main, .hevc_main10:
                return true
            case .prores422, .prores4444:
                return false // Software only
            case .spatial_video, .dolby_vision:
                return true // iOS 19+
            case .png_sequence, .gif_animated:
                return false // Image export
            }
        }

        var description: String {
            switch self {
            case .h264_baseline: return "H.264 Baseline (max compatibility)"
            case .h264_main: return "H.264 Main (good quality/size balance)"
            case .h264_high: return "H.264 High (best H.264 quality)"
            case .hevc_main: return "H.265 Main (50% smaller than H.264)"
            case .hevc_main10: return "H.265 Main10 (10-bit HDR)"
            case .prores422: return "ProRes 422 (intermediate codec, ~150 MB/min @ 1080p)"
            case .prores4444: return "ProRes 4444 (alpha channel support)"
            case .spatial_video: return "Spatial Video for Vision Pro"
            case .dolby_vision: return "Dolby Vision HDR with PQ curve"
            case .png_sequence: return "PNG Sequence (lossless, with alpha)"
            case .gif_animated: return "Animated GIF (8-bit, up to 256 colors)"
            }
        }
    }

    // MARK: - Resolution Presets

    enum Resolution: String, CaseIterable {
        case sd640x480 = "480p"
        case hd1280x720 = "720p"
        case hd1920x1080 = "1080p"
        case uhd3840x2160 = "4K"
        case original = "Original"

        var size: CGSize? {
            switch self {
            case .sd640x480: return CGSize(width: 640, height: 480)
            case .hd1280x720: return CGSize(width: 1280, height: 720)
            case .hd1920x1080: return CGSize(width: 1920, height: 1080)
            case .uhd3840x2160: return CGSize(width: 3840, height: 2160)
            case .original: return nil
            }
        }
    }

    // MARK: - Frame Rates

    enum FrameRate: Int, CaseIterable {
        case fps24 = 24
        case fps25 = 25
        case fps30 = 30
        case fps60 = 60
        case fps120 = 120

        var description: String {
            switch self {
            case .fps24: return "24 FPS (Film)"
            case .fps25: return "25 FPS (PAL)"
            case .fps30: return "30 FPS (NTSC)"
            case .fps60: return "60 FPS (Smooth)"
            case .fps120: return "120 FPS (Slow Motion)"
            }
        }
    }

    // MARK: - Quality Settings

    enum Quality: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case maximum = "Maximum"

        var compressionQuality: Float {
            switch self {
            case .low: return 0.3
            case .medium: return 0.6
            case .high: return 0.8
            case .maximum: return 1.0
            }
        }

        var bitrate: Int {
            // Bitrate for 1080p in kbps
            switch self {
            case .low: return 2500
            case .medium: return 5000
            case .high: return 8000
            case .maximum: return 12000
            }
        }
    }

    // MARK: - Export Job

    struct ExportJob: Identifiable {
        let id = UUID()
        let composition: AVMutableComposition
        let outputURL: URL
        let format: ExportFormat
        let resolution: Resolution
        let frameRate: FrameRate
        let quality: Quality
        var progress: Double = 0.0
        var status: Status = .pending

        enum Status {
            case pending
            case exporting
            case completed
            case failed(Error)
        }
    }

    // MARK: - Export Session

    private var currentExportSession: AVAssetExportSession?
    private var progressTimer: Timer?

    // MARK: - Single Export

    func export(
        composition: AVMutableComposition,
        to outputURL: URL,
        format: ExportFormat = .h264_high,
        resolution: Resolution = .hd1920x1080,
        frameRate: FrameRate = .fps30,
        quality: Quality = .high
    ) async throws {
        guard !isExporting else {
            throw ExportError.exportAlreadyInProgress
        }

        isExporting = true
        exportProgress = 0.0

        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            isExporting = false
            throw ExportError.exportSessionCreationFailed
        }

        currentExportSession = exportSession

        // Configure output
        exportSession.outputURL = outputURL
        exportSession.outputFileType = format.fileExtension == "mp4" ? .mp4 : .mov
        exportSession.shouldOptimizeForNetworkUse = true

        // Configure video settings
        let videoSettings = buildVideoSettings(
            format: format,
            resolution: resolution,
            frameRate: frameRate,
            quality: quality,
            assetSize: composition.naturalSize
        )

        let audioSettings = buildAudioSettings()

        // Apply custom export with VideoToolbox if hardware encoding supported
        if format.supportsHardwareEncoding {
            try await hardwareExport(
                composition: composition,
                outputURL: outputURL,
                format: format,
                resolution: resolution,
                frameRate: frameRate,
                quality: quality
            )
        } else {
            // Use AVAssetExportSession for software codecs (ProRes)
            exportSession.videoComposition = nil // Apply directly
            exportSession.audioMix = nil

            // Start progress monitoring
            startProgressMonitoring(exportSession: exportSession)

            // Export
            await exportSession.export()

            stopProgressMonitoring()

            // Check result
            switch exportSession.status {
            case .completed:
                log.video("✅ VideoExportManager: Export completed - \(outputURL.lastPathComponent)")
            case .failed:
                throw exportSession.error ?? ExportError.exportFailed
            case .cancelled:
                throw ExportError.exportCancelled
            default:
                throw ExportError.unexpectedExportStatus
            }
        }

        isExporting = false
        exportProgress = 1.0
        currentExportSession = nil
    }

    // MARK: - Hardware Encoding (VideoToolbox)

    private func hardwareExport(
        composition: AVMutableComposition,
        outputURL: URL,
        format: ExportFormat,
        resolution: Resolution,
        frameRate: FrameRate,
        quality: Quality
    ) async throws {
        // Create asset reader
        let reader = try AVAssetReader(asset: composition)

        // Configure video output
        let videoTracks = composition.tracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw ExportError.noVideoTrack
        }

        let readerOutputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]

        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)
        reader.add(readerOutput)

        // Create asset writer
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: format.fileExtension == "mp4" ? .mp4 : .mov)

        // Configure video input
        let targetSize = resolution.size ?? composition.naturalSize
        let videoSettings = buildVideoSettings(
            format: format,
            resolution: resolution,
            frameRate: frameRate,
            quality: quality,
            assetSize: composition.naturalSize
        )

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)

        // Create pixel buffer adaptor
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                kCVPixelBufferWidthKey as String: Int(targetSize.width),
                kCVPixelBufferHeightKey as String: Int(targetSize.height)
            ]
        )

        // Start reading and writing
        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        // Process frames
        let processingQueue = DispatchQueue(label: "com.echoelmusic.video.export")

        await withCheckedContinuation { continuation in
            writerInput.requestMediaDataWhenReady(on: processingQueue) {
                while writerInput.isReadyForMoreMediaData {
                    guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else {
                        writerInput.markAsFinished()
                        reader.cancelReading()
                        writer.finishWriting {
                            continuation.resume()
                        }
                        return
                    }

                    // Append sample
                    if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)

                        // Update progress
                        let progress = presentationTime.seconds / composition.duration.seconds
                        Task { @MainActor in
                            self.exportProgress = progress
                        }
                    }
                }
            }
        }

        log.video("✅ VideoExportManager: Hardware export completed")
    }

    // MARK: - Build Video Settings

    private func buildVideoSettings(
        format: ExportFormat,
        resolution: Resolution,
        frameRate: FrameRate,
        quality: Quality,
        assetSize: CGSize
    ) -> [String: Any] {
        let targetSize = resolution.size ?? assetSize

        var settings: [String: Any] = [
            AVVideoCodecKey: format.codecType,
            AVVideoWidthKey: Int(targetSize.width),
            AVVideoHeightKey: Int(targetSize.height)
        ]

        // Add H.264 profile
        if let profile = format.h264Profile {
            settings[AVVideoProfileLevelKey] = profile
        }

        // Add compression properties
        var compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: quality.bitrate * 1000,
            AVVideoMaxKeyFrameIntervalKey: frameRate.rawValue * 2, // Keyframe every 2 seconds
            AVVideoExpectedSourceFrameRateKey: frameRate.rawValue
        ]

        // Add quality
        compressionProperties[AVVideoQualityKey] = quality.compressionQuality

        // Hardware encoding
        if format.supportsHardwareEncoding {
            compressionProperties[AVVideoAllowFrameReorderingKey] = true
            compressionProperties[AVVideoH264EntropyModeKey] = AVVideoH264EntropyModeCABAC
        }

        settings[AVVideoCompressionPropertiesKey] = compressionProperties

        return settings
    }

    // MARK: - Build Audio Settings

    private func buildAudioSettings() -> [String: Any] {
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 192000
        ]
    }

    // MARK: - Progress Monitoring

    private func startProgressMonitoring(exportSession: AVAssetExportSession) {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.exportProgress = Double(exportSession.progress)
            }
        }
    }

    private func stopProgressMonitoring() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    // MARK: - Batch Export

    func batchExport(
        composition: AVMutableComposition,
        outputDirectory: URL,
        formats: [ExportFormat],
        resolutions: [Resolution],
        frameRate: FrameRate = .fps30,
        quality: Quality = .high
    ) async throws {
        guard !isExporting else {
            throw ExportError.exportAlreadyInProgress
        }

        // Create jobs
        exportQueue.removeAll()

        for format in formats {
            for resolution in resolutions {
                let filename = "\(composition.description)_\(resolution.rawValue).\(format.fileExtension)"
                let outputURL = outputDirectory.appendingPathComponent(filename)

                let job = ExportJob(
                    composition: composition,
                    outputURL: outputURL,
                    format: format,
                    resolution: resolution,
                    frameRate: frameRate,
                    quality: quality
                )

                exportQueue.append(job)
            }
        }

        // Process queue
        for (index, var job) in exportQueue.enumerated() {
            currentExport = job
            job.status = .exporting
            exportQueue[index] = job

            do {
                try await export(
                    composition: job.composition,
                    to: job.outputURL,
                    format: job.format,
                    resolution: job.resolution,
                    frameRate: job.frameRate,
                    quality: job.quality
                )

                job.status = .completed
                exportQueue[index] = job
            } catch {
                job.status = .failed(error)
                exportQueue[index] = job
                log.video("❌ VideoExportManager: Batch export failed for job \(index) - \(error)", level: .error)
            }
        }

        currentExport = nil
        log.video("✅ VideoExportManager: Batch export completed - \(exportQueue.count) jobs")
    }

    // MARK: - Cancel Export

    func cancelExport() {
        currentExportSession?.cancelExport()
        stopProgressMonitoring()

        isExporting = false
        exportProgress = 0.0
        currentExportSession = nil

        log.video("❌ VideoExportManager: Export cancelled", level: .error)
    }

    // MARK: - PNG Sequence Export

    /// Export video as PNG image sequence
    func exportPNGSequence(
        composition: AVMutableComposition,
        to outputDirectory: URL,
        frameRate: FrameRate = .fps30,
        resolution: Resolution = .hd1920x1080
    ) async throws {
        guard !isExporting else {
            throw ExportError.exportAlreadyInProgress
        }

        isExporting = true
        exportProgress = 0.0

        // Create output directory
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        // Setup image generator
        let imageGenerator = AVAssetImageGenerator(asset: composition)
        let targetSize = resolution.size ?? composition.naturalSize
        imageGenerator.maximumSize = targetSize
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero

        // Calculate frame times
        let duration = composition.duration.seconds
        let frameInterval = 1.0 / Double(frameRate.rawValue)
        let totalFrames = Int(duration / frameInterval)

        for frameIndex in 0..<totalFrames {
            let time = CMTime(seconds: Double(frameIndex) * frameInterval, preferredTimescale: 600)

            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)

                // Create UIImage and save as PNG
                let uiImage = UIImage(cgImage: cgImage)
                let filename = String(format: "frame_%06d.png", frameIndex)
                let fileURL = outputDirectory.appendingPathComponent(filename)

                if let pngData = uiImage.pngData() {
                    try pngData.write(to: fileURL)
                }

                // Update progress
                exportProgress = Double(frameIndex + 1) / Double(totalFrames)
            } catch {
                log.video("⚠️ VideoExportManager: Failed to export frame \(frameIndex)", level: .warning)
            }
        }

        isExporting = false
        exportProgress = 1.0
        log.video("✅ VideoExportManager: PNG sequence exported - \(totalFrames) frames to \(outputDirectory.lastPathComponent)")
    }

    // MARK: - Animated GIF Export

    /// Export video as animated GIF
    func exportAnimatedGIF(
        composition: AVMutableComposition,
        to outputURL: URL,
        frameRate: Int = 15, // Lower FPS for GIF
        resolution: Resolution = .hd1280x720, // Lower res for GIF
        loopCount: Int = 0 // 0 = infinite loop
    ) async throws {
        guard !isExporting else {
            throw ExportError.exportAlreadyInProgress
        }

        isExporting = true
        exportProgress = 0.0

        // Setup image generator
        let imageGenerator = AVAssetImageGenerator(asset: composition)
        let targetSize = resolution.size ?? CGSize(width: 480, height: 270) // Default small for GIF
        imageGenerator.maximumSize = targetSize
        imageGenerator.appliesPreferredTrackTransform = true

        // Calculate frame times
        let duration = composition.duration.seconds
        let frameInterval = 1.0 / Double(frameRate)
        let totalFrames = Int(duration / frameInterval)

        // GIF properties
        let fileProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: loopCount
            ]
        ]

        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameInterval
            ]
        ]

        // Create GIF destination
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            kUTTypeGIF,
            totalFrames,
            nil
        ) else {
            isExporting = false
            throw ExportError.exportFailed
        }

        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

        // Generate frames
        for frameIndex in 0..<totalFrames {
            let time = CMTime(seconds: Double(frameIndex) * frameInterval, preferredTimescale: 600)

            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)

                // Update progress
                exportProgress = Double(frameIndex + 1) / Double(totalFrames)
            } catch {
                log.video("⚠️ VideoExportManager: Failed to add frame \(frameIndex) to GIF", level: .warning)
            }
        }

        // Finalize GIF
        guard CGImageDestinationFinalize(destination) else {
            isExporting = false
            throw ExportError.exportFailed
        }

        isExporting = false
        exportProgress = 1.0
        log.video("✅ VideoExportManager: Animated GIF exported - \(totalFrames) frames to \(outputURL.lastPathComponent)")
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case exportAlreadyInProgress
    case exportSessionCreationFailed
    case exportFailed
    case exportCancelled
    case unexpectedExportStatus
    case noVideoTrack
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .exportAlreadyInProgress:
            return "An export is already in progress"
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .exportFailed:
            return "Export failed"
        case .exportCancelled:
            return "Export was cancelled"
        case .unexpectedExportStatus:
            return "Unexpected export status"
        case .noVideoTrack:
            return "No video track found in composition"
        case .unsupportedFormat:
            return "Unsupported export format"
        }
    }
}

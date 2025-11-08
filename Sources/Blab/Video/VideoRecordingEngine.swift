import Foundation
import AVFoundation
import UIKit
import CoreImage

/// Video Recording Engine with Audio Sync
///
/// Features:
/// - Record visualizations to video
/// - Sync with multi-track audio
/// - Bio-data overlay (HRV graphs, heart rate)
/// - Export to MP4/MOV
/// - Social media optimized (1080p, 4K)
@MainActor
class VideoRecordingEngine: NSObject, ObservableObject {

    // MARK: - Published State

    /// Whether recording is active
    @Published var isRecording: Bool = false

    /// Recording duration
    @Published var recordingDuration: TimeInterval = 0.0

    /// Export progress (0-1)
    @Published var exportProgress: Double = 0.0

    /// Last recorded video URL
    @Published var lastVideoURL: URL?

    // MARK: - Configuration

    struct RecordingConfiguration {
        var resolution: VideoResolution = .hd1080p
        var frameRate: Int32 = 60
        var codec: AVVideoCodecType = .h264
        var includeAudio: Bool = true
        var includeBioOverlay: Bool = true
        var includeWaveformOverlay: Bool = true
    }

    enum VideoResolution {
        case hd720p      // 1280x720
        case hd1080p     // 1920x1080
        case uhd4k       // 3840x2160

        var size: CGSize {
            switch self {
            case .hd720p: return CGSize(width: 1280, height: 720)
            case .hd1080p: return CGSize(width: 1920, height: 1080)
            case .uhd4k: return CGSize(width: 3840, height: 2160)
            }
        }
    }

    var configuration = RecordingConfiguration()

    // MARK: - AVFoundation Components

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    // MARK: - Recording State

    private var startTime: Date?
    private var frameCount: Int = 0
    private var recordingTimer: Timer?

    // MARK: - Dependencies

    private var healthKitManager: HealthKitManager?
    private var audioEngine: AudioEngine?

    // MARK: - Bio Data Buffer

    private var hrvData: [(time: TimeInterval, value: Double)] = []
    private var heartRateData: [(time: TimeInterval, value: Double)] = []

    // MARK: - Initialization

    override init() {
        super.init()
        print("🎥 VideoRecordingEngine initialized")
    }

    // MARK: - Public API

    /// Start video recording
    func startRecording(visualizationView: UIView) throws {
        guard !isRecording else { return }

        // Create output URL
        let fileName = "BLAB_\(Date().timeIntervalSince1970).mp4"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsPath.appendingPathComponent(fileName)

        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)

        // Setup asset writer
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        // Setup video input
        setupVideoInput()

        // Setup audio input (if enabled)
        if configuration.includeAudio {
            setupAudioInput()
        }

        // Start writing
        guard assetWriter?.startWriting() == true else {
            throw VideoRecordingError.failedToStartWriting
        }

        assetWriter?.startSession(atSourceTime: .zero)

        isRecording = true
        startTime = Date()
        frameCount = 0
        hrvData.removeAll()
        heartRateData.removeAll()

        // Start recording timer
        startRecordingTimer()

        print("🎥 Video recording started: \(outputURL.lastPathComponent)")
        lastVideoURL = outputURL
    }

    /// Stop video recording
    func stopRecording() async throws -> URL? {
        guard isRecording else { return nil }

        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil

        // Finish writing
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        await assetWriter?.finishWriting()

        let url = lastVideoURL
        print("🎥 Video recording stopped: \(frameCount) frames, \(String(format: "%.1f", recordingDuration))s")

        // Reset state
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil

        return url
    }

    /// Append video frame
    func appendVideoFrame(_ image: UIImage) {
        guard isRecording,
              let videoInput = videoInput,
              let pixelBufferAdaptor = pixelBufferAdaptor,
              videoInput.isReadyForMoreMediaData else {
            return
        }

        let timestamp = CMTime(seconds: recordingDuration, preferredTimescale: 600)

        // Convert UIImage to CVPixelBuffer
        if let pixelBuffer = image.toPixelBuffer(size: configuration.resolution.size) {
            // Add overlays if enabled
            let overlayedBuffer = addOverlays(to: pixelBuffer, at: recordingDuration)

            pixelBufferAdaptor.append(overlayedBuffer, withPresentationTime: timestamp)
            frameCount += 1
        }
    }

    /// Append audio buffer
    func appendAudioBuffer(_ buffer: CMSampleBuffer) {
        guard isRecording,
              configuration.includeAudio,
              let audioInput = audioInput,
              audioInput.isReadyForMoreMediaData else {
            return
        }

        audioInput.append(buffer)
    }

    /// Update bio data for overlay
    func updateBioData(hrv: Double, heartRate: Double) {
        guard isRecording else { return }

        hrvData.append((time: recordingDuration, value: hrv))
        heartRateData.append((time: recordingDuration, value: heartRate))

        // Keep last 60 seconds
        let cutoff = recordingDuration - 60.0
        hrvData.removeAll { $0.time < cutoff }
        heartRateData.removeAll { $0.time < cutoff }
    }

    /// Export video with custom settings
    func exportVideo(from url: URL, configuration: ExportConfiguration) async throws -> URL {
        let asset = AVAsset(url: url)

        // Create export session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: configuration.preset) else {
            throw VideoRecordingError.exportFailed
        }

        // Output URL
        let fileName = "BLAB_Export_\(Date().timeIntervalSince1970).mp4"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsPath.appendingPathComponent(fileName)

        // Remove existing
        try? FileManager.default.removeItem(at: outputURL)

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        // Monitor progress
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.exportProgress = Double(exportSession.progress)
            }
        }

        await exportSession.export()
        timer.invalidate()

        guard exportSession.status == .completed else {
            throw VideoRecordingError.exportFailed
        }

        print("🎥 Video exported: \(outputURL.lastPathComponent)")
        return outputURL
    }

    // MARK: - Private Methods

    private func setupVideoInput() {
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: configuration.codec,
            AVVideoWidthKey: configuration.resolution.size.width,
            AVVideoHeightKey: configuration.resolution.size.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000,  // 10 Mbps
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: configuration.frameRate
            ]
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        // Pixel buffer attributes
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: configuration.resolution.size.width,
            kCVPixelBufferHeightKey as String: configuration.resolution.size.height
        ]

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        if let videoInput = videoInput {
            assetWriter?.add(videoInput)
        }
    }

    private func setupAudioInput() {
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]

        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = true

        if let audioInput = audioInput {
            assetWriter?.add(audioInput)
        }
    }

    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            self.recordingDuration = Date().timeIntervalSince(startTime)
        }
    }

    private func addOverlays(to pixelBuffer: CVPixelBuffer, at time: TimeInterval) -> CVPixelBuffer {
        guard configuration.includeBioOverlay || configuration.includeWaveformOverlay else {
            return pixelBuffer
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        var outputImage = ciImage

        // Add HRV graph overlay
        if configuration.includeBioOverlay, !hrvData.isEmpty {
            outputImage = addBioGraph(to: outputImage, data: hrvData, color: .green, position: .topLeft)
        }

        // Add heart rate overlay
        if configuration.includeBioOverlay, !heartRateData.isEmpty {
            outputImage = addBioGraph(to: outputImage, data: heartRateData, color: .red, position: .topRight)
        }

        // Add timestamp
        outputImage = addTimestamp(to: outputImage, time: time)

        // Render back to pixel buffer
        let context = CIContext()
        context.render(outputImage, to: pixelBuffer)

        return pixelBuffer
    }

    private func addBioGraph(to image: CIImage, data: [(time: TimeInterval, value: Double)], color: UIColor, position: OverlayPosition) -> CIImage {
        // Create graph image
        let graphSize = CGSize(width: 300, height: 100)
        let renderer = UIGraphicsImageRenderer(size: graphSize)

        let graphImage = renderer.image { context in
            // Background
            UIColor.black.withAlphaComponent(0.5).setFill()
            context.fill(CGRect(origin: .zero, size: graphSize))

            // Draw graph
            guard data.count > 1 else { return }

            let path = UIBezierPath()
            let minValue = data.map { $0.value }.min() ?? 0
            let maxValue = data.map { $0.value }.max() ?? 100
            let valueRange = maxValue - minValue

            for (index, point) in data.enumerated() {
                let x = CGFloat(index) / CGFloat(data.count - 1) * graphSize.width
                let normalizedValue = (point.value - minValue) / valueRange
                let y = graphSize.height - (CGFloat(normalizedValue) * graphSize.height)

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            color.setStroke()
            path.lineWidth = 2
            path.stroke()

            // Value label
            let value = data.last?.value ?? 0
            let label = String(format: "%.1f", value)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            label.draw(at: CGPoint(x: 10, y: 10), withAttributes: attributes)
        }

        // Overlay on image
        let graphCIImage = CIImage(image: graphImage)!
        let x: CGFloat
        let y: CGFloat = 50

        switch position {
        case .topLeft:
            x = 50
        case .topRight:
            x = image.extent.width - graphSize.width - 50
        case .bottomLeft:
            x = 50
        case .bottomRight:
            x = image.extent.width - graphSize.width - 50
        }

        let transform = CGAffineTransform(translationX: x, y: y)
        let overlayImage = graphCIImage.transformed(by: transform)

        return overlayImage.composited(over: image)
    }

    private func addTimestamp(to image: CIImage, time: TimeInterval) -> CIImage {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        let timestamp = String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)

        let size = CGSize(width: 200, height: 50)
        let renderer = UIGraphicsImageRenderer(size: size)

        let timestampImage = renderer.image { context in
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.white,
                .strokeColor: UIColor.black,
                .strokeWidth: -2
            ]
            timestamp.draw(at: CGPoint(x: 10, y: 10), withAttributes: attributes)
        }

        let ciTimestamp = CIImage(image: timestampImage)!
        let x = (image.extent.width - size.width) / 2
        let y = image.extent.height - size.height - 50

        let transform = CGAffineTransform(translationX: x, y: y)
        let overlayImage = ciTimestamp.transformed(by: transform)

        return overlayImage.composited(over: image)
    }

    enum OverlayPosition {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    // MARK: - Export Configuration

    struct ExportConfiguration {
        var preset: String = AVAssetExportPresetHighestQuality
        var includeMetadata: Bool = true

        static let instagram = ExportConfiguration(preset: AVAssetExportPreset1920x1080)
        static let youtube = ExportConfiguration(preset: AVAssetExportPresetHEVC3840x2160)
        static let twitter = ExportConfiguration(preset: AVAssetExportPreset1280x720)
    }

    // MARK: - Errors

    enum VideoRecordingError: Error, LocalizedError {
        case failedToStartWriting
        case exportFailed
        case invalidConfiguration

        var errorDescription: String? {
            switch self {
            case .failedToStartWriting:
                return "Failed to start video writing"
            case .exportFailed:
                return "Video export failed"
            case .invalidConfiguration:
                return "Invalid recording configuration"
            }
        }
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    func toPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )

        guard let ctx = context, let cgImage = self.cgImage else {
            return nil
        }

        ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))

        return buffer
    }
}

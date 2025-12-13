import Foundation
import AVFoundation
import CoreImage

#if canImport(UIKit)
import UIKit
#endif

/// Manages video export with visualization overlay
/// Combines audio with rendered visualization frames
@MainActor
class VideoExportManager {

    // MARK: - Video Export Configuration

    struct VideoExportConfig {
        var width: Int = 1920
        var height: Int = 1080
        var frameRate: Float = 30
        var videoBitRate: Int = 8_000_000  // 8 Mbps
        var audioBitRate: Int = 256_000    // 256 kbps
        var videoCodec: AVVideoCodecType = .h264
        var includeVisualization: Bool = true
        var visualizationMode: VisualizationMode = .mandala

        enum VisualizationMode: String, CaseIterable {
            case mandala = "Mandala"
            case cymatics = "Cymatics"
            case waveform = "Waveform"
            case spectral = "Spectral"
            case particles = "Particles"
            case sacredGeometry = "Sacred Geometry"
            case brainwave = "Brainwave"
            case heartCoherence = "Heart Coherence"
        }

        /// Preset configurations
        static var hd720p: VideoExportConfig {
            var config = VideoExportConfig()
            config.width = 1280
            config.height = 720
            config.videoBitRate = 5_000_000
            return config
        }

        static var hd1080p: VideoExportConfig {
            VideoExportConfig()
        }

        static var uhd4k: VideoExportConfig {
            var config = VideoExportConfig()
            config.width = 3840
            config.height = 2160
            config.videoBitRate = 25_000_000
            config.videoCodec = .hevc
            return config
        }

        static var socialMedia: VideoExportConfig {
            var config = VideoExportConfig()
            config.width = 1080
            config.height = 1080  // Square for Instagram
            config.videoBitRate = 4_000_000
            return config
        }
    }

    // MARK: - Export Progress

    enum ExportState {
        case idle
        case preparing
        case rendering(progress: Float)
        case encoding
        case complete
        case failed(Error)
    }

    @Published var exportState: ExportState = .idle
    @Published var progress: Float = 0

    // MARK: - Properties

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private let ciContext = CIContext()

    // MARK: - Export Methods

    /// Export session as video with visualization
    func exportVideo(
        session: Session,
        config: VideoExportConfig = .hd1080p,
        outputURL: URL? = nil
    ) async throws -> URL {
        exportState = .preparing

        let exportURL = outputURL ?? defaultVideoURL(for: session)

        // Remove existing file if needed
        try? FileManager.default.removeItem(at: exportURL)

        // Create asset writer
        assetWriter = try AVAssetWriter(outputURL: exportURL, fileType: .mp4)

        guard let assetWriter = assetWriter else {
            throw VideoExportError.writerCreationFailed
        }

        // Configure video input
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: config.videoCodec,
            AVVideoWidthKey: config.width,
            AVVideoHeightKey: config.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: config.videoBitRate,
                AVVideoMaxKeyFrameIntervalKey: Int(config.frameRate * 2)
            ]
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = false

        // Configure pixel buffer adaptor
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: config.width,
            kCVPixelBufferHeightKey as String: config.height
        ]

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        // Configure audio input
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: config.audioBitRate
        ]

        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = false

        // Add inputs to writer
        if assetWriter.canAdd(videoInput!) {
            assetWriter.add(videoInput!)
        }

        if assetWriter.canAdd(audioInput!) {
            assetWriter.add(audioInput!)
        }

        // Start writing
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)

        // Render frames
        exportState = .rendering(progress: 0)
        try await renderVisualizationFrames(session: session, config: config)

        // Encode audio
        exportState = .encoding
        try await encodeAudio(session: session, config: config)

        // Finish writing
        await finishWriting()

        exportState = .complete
        progress = 1.0

        print("🎬 Video exported: \(exportURL.path)")
        return exportURL
    }

    // MARK: - Frame Rendering

    private func renderVisualizationFrames(session: Session, config: VideoExportConfig) async throws {
        guard let adaptor = pixelBufferAdaptor,
              let videoInput = videoInput else {
            throw VideoExportError.invalidConfiguration
        }

        let duration = session.duration > 0 ? session.duration : 60.0  // Default 60 seconds
        let totalFrames = Int(duration * Double(config.frameRate))
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(config.frameRate))

        for frameIndex in 0..<totalFrames {
            // Wait for input to be ready
            while !videoInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
            }

            // Calculate time for this frame
            let frameTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(config.frameRate))
            let timestamp = CMTimeGetSeconds(frameTime)

            // Get bio data at this timestamp (interpolated)
            let bioData = interpolateBioData(session: session, at: timestamp)

            // Create pixel buffer
            guard let pixelBuffer = createPixelBuffer(
                width: config.width,
                height: config.height,
                bioData: bioData,
                mode: config.visualizationMode,
                time: timestamp
            ) else {
                continue
            }

            // Append pixel buffer
            adaptor.append(pixelBuffer, withPresentationTime: frameTime)

            // Update progress
            progress = Float(frameIndex) / Float(totalFrames)
            exportState = .rendering(progress: progress)
        }
    }

    private func createPixelBuffer(
        width: Int,
        height: Int,
        bioData: BioDataPoint,
        mode: VideoExportConfig.VisualizationMode,
        time: TimeInterval
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?

        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        // Draw visualization based on mode
        drawVisualization(
            context: context,
            width: width,
            height: height,
            bioData: bioData,
            mode: mode,
            time: time
        )

        return buffer
    }

    private func drawVisualization(
        context: CGContext,
        width: Int,
        height: Int,
        bioData: BioDataPoint,
        mode: VideoExportConfig.VisualizationMode,
        time: TimeInterval
    ) {
        // Background
        context.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let center = CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
        let radius = min(CGFloat(width), CGFloat(height)) * 0.4

        // Color based on HRV coherence
        let hue = CGFloat(bioData.coherence / 100.0 * 0.5)
        let color = CGColor(
            red: cos(hue * .pi * 2) * 0.5 + 0.5,
            green: cos((hue + 0.33) * .pi * 2) * 0.5 + 0.5,
            blue: cos((hue + 0.66) * .pi * 2) * 0.5 + 0.5,
            alpha: 1.0
        )

        switch mode {
        case .mandala, .heartCoherence:
            drawMandalaFrame(context: context, center: center, radius: radius, color: color, bioData: bioData, time: time)
        case .waveform:
            drawWaveformFrame(context: context, width: width, height: height, color: color, bioData: bioData, time: time)
        case .spectral:
            drawSpectralFrame(context: context, width: width, height: height, color: color, bioData: bioData, time: time)
        case .particles:
            drawParticlesFrame(context: context, center: center, radius: radius, color: color, bioData: bioData, time: time)
        case .cymatics:
            drawCymaticsFrame(context: context, center: center, radius: radius, color: color, bioData: bioData, time: time)
        case .sacredGeometry:
            drawSacredGeometryFrame(context: context, center: center, radius: radius, color: color, time: time)
        case .brainwave:
            drawBrainwaveFrame(context: context, width: width, height: height, color: color, bioData: bioData, time: time)
        }
    }

    private func drawMandalaFrame(context: CGContext, center: CGPoint, radius: CGFloat, color: CGColor, bioData: BioDataPoint, time: TimeInterval) {
        let petalCount = 6 + Int(bioData.frequency / 100) % 6
        let rotation = time * Double(bioData.heartRate) / 60.0

        context.setStrokeColor(color)
        context.setLineWidth(2)

        for layer in 0..<5 {
            let layerRadius = radius * CGFloat(5 - layer) / 5.0
            let layerRotation = rotation + Double(layer) * 0.5

            for i in 0..<petalCount {
                let angle = CGFloat(layerRotation) + CGFloat(i) / CGFloat(petalCount) * .pi * 2
                let x = center.x + cos(angle) * layerRadius
                let y = center.y + sin(angle) * layerRadius
                let petalSize = 20.0 + CGFloat(bioData.audioLevel) * 30.0

                context.strokeEllipse(in: CGRect(
                    x: x - petalSize / 2,
                    y: y - petalSize / 2,
                    width: petalSize,
                    height: petalSize
                ))
            }
        }
    }

    private func drawWaveformFrame(context: CGContext, width: Int, height: Int, color: CGColor, bioData: BioDataPoint, time: TimeInterval) {
        context.setStrokeColor(color)
        context.setLineWidth(2)

        let midY = CGFloat(height) / 2
        let amplitude = CGFloat(bioData.audioLevel) * CGFloat(height) * 0.3

        context.beginPath()
        for x in 0..<width {
            let phase = Double(x) / 50.0 + time * Double(bioData.frequency) / 100.0
            let y = midY + sin(phase) * amplitude

            if x == 0 {
                context.move(to: CGPoint(x: CGFloat(x), y: y))
            } else {
                context.addLine(to: CGPoint(x: CGFloat(x), y: y))
            }
        }
        context.strokePath()
    }

    private func drawSpectralFrame(context: CGContext, width: Int, height: Int, color: CGColor, bioData: BioDataPoint, time: TimeInterval) {
        let barCount = 64
        let barWidth = CGFloat(width) / CGFloat(barCount)

        for i in 0..<barCount {
            let freq = Double(i) / Double(barCount)
            let amplitude = sin(freq * .pi + time * 2) * 0.5 + 0.5
            let barHeight = CGFloat(amplitude) * CGFloat(height) * 0.8 * CGFloat(bioData.audioLevel + 0.2)

            let hue = CGFloat(i) / CGFloat(barCount) * 0.7
            context.setFillColor(CGColor(
                red: cos(hue * .pi * 2) * 0.5 + 0.5,
                green: cos((hue + 0.33) * .pi * 2) * 0.5 + 0.5,
                blue: cos((hue + 0.66) * .pi * 2) * 0.5 + 0.5,
                alpha: 0.8
            ))

            context.fill(CGRect(
                x: CGFloat(i) * barWidth,
                y: CGFloat(height) - barHeight,
                width: barWidth - 1,
                height: barHeight
            ))
        }
    }

    private func drawParticlesFrame(context: CGContext, center: CGPoint, radius: CGFloat, color: CGColor, bioData: BioDataPoint, time: TimeInterval) {
        let particleCount = 100 + Int(bioData.audioLevel * 200)

        for i in 0..<particleCount {
            let seed = Double(i) * 0.618033988749895
            let angle = seed * .pi * 2 + time * 0.5
            let dist = (seed.truncatingRemainder(dividingBy: 1.0)) * Double(radius)

            let x = center.x + CGFloat(cos(angle) * dist)
            let y = center.y + CGFloat(sin(angle) * dist)
            let size = 2.0 + CGFloat(bioData.audioLevel) * 4.0

            context.setFillColor(color)
            context.fillEllipse(in: CGRect(x: x - size/2, y: y - size/2, width: size, height: size))
        }
    }

    private func drawCymaticsFrame(context: CGContext, center: CGPoint, radius: CGFloat, color: CGColor, bioData: BioDataPoint, time: TimeInterval) {
        let nodeCount = 8 + Int(bioData.frequency / 100)
        let rings = 6

        context.setStrokeColor(color)
        context.setLineWidth(1.5)

        for ring in 1...rings {
            let ringRadius = radius * CGFloat(ring) / CGFloat(rings)

            context.beginPath()
            for i in 0...360 {
                let angle = CGFloat(i) * .pi / 180
                let modulation = sin(CGFloat(nodeCount) * angle + CGFloat(time * 2)) * CGFloat(bioData.audioLevel) * 20

                let x = center.x + cos(angle) * (ringRadius + modulation)
                let y = center.y + sin(angle) * (ringRadius + modulation)

                if i == 0 {
                    context.move(to: CGPoint(x: x, y: y))
                } else {
                    context.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.closePath()
            context.strokePath()
        }
    }

    private func drawSacredGeometryFrame(context: CGContext, center: CGPoint, radius: CGFloat, color: CGColor, time: TimeInterval) {
        context.setStrokeColor(color)
        context.setLineWidth(1)

        // Flower of Life
        let circleRadius = radius / 3
        let rotation = time * 0.1

        // Center circle
        context.strokeEllipse(in: CGRect(
            x: center.x - circleRadius,
            y: center.y - circleRadius,
            width: circleRadius * 2,
            height: circleRadius * 2
        ))

        // 6 surrounding circles
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 + CGFloat(rotation)
            let x = center.x + cos(angle) * circleRadius
            let y = center.y + sin(angle) * circleRadius

            context.strokeEllipse(in: CGRect(
                x: x - circleRadius,
                y: y - circleRadius,
                width: circleRadius * 2,
                height: circleRadius * 2
            ))
        }
    }

    private func drawBrainwaveFrame(context: CGContext, width: Int, height: Int, color: CGColor, bioData: BioDataPoint, time: TimeInterval) {
        let channels = 8
        let channelHeight = CGFloat(height) / CGFloat(channels)

        context.setStrokeColor(color)
        context.setLineWidth(1.5)

        for channel in 0..<channels {
            let yCenter = CGFloat(channel) * channelHeight + channelHeight / 2
            let frequency = Double(channel + 1) * 2.0  // 2-16 Hz range

            context.beginPath()
            for x in 0..<width {
                let phase = Double(x) / 100.0 + time * frequency
                let amplitude = sin(phase) * Double(channelHeight) * 0.3 * Double(bioData.audioLevel + 0.3)
                let y = yCenter + CGFloat(amplitude)

                if x == 0 {
                    context.move(to: CGPoint(x: CGFloat(x), y: y))
                } else {
                    context.addLine(to: CGPoint(x: CGFloat(x), y: y))
                }
            }
            context.strokePath()
        }
    }

    // MARK: - Audio Encoding

    private func encodeAudio(session: Session, config: VideoExportConfig) async throws {
        guard let audioInput = audioInput else {
            throw VideoExportError.invalidConfiguration
        }

        // If session has audio tracks, encode them
        for track in session.tracks where !track.isMuted {
            guard let trackURL = track.url else { continue }

            let asset = AVURLAsset(url: trackURL)
            guard let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first else { continue }

            let reader = try AVAssetReader(asset: asset)
            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2
            ]

            let trackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
            reader.add(trackOutput)
            reader.startReading()

            while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
                while !audioInput.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 10_000_000)
                }
                audioInput.append(sampleBuffer)
            }
        }

        audioInput.markAsFinished()
    }

    // MARK: - Helpers

    private func interpolateBioData(session: Session, at timestamp: TimeInterval) -> BioDataPoint {
        guard !session.bioData.isEmpty else {
            return BioDataPoint(
                timestamp: timestamp,
                hrv: 50,
                heartRate: 70,
                coherence: 50,
                audioLevel: 0.5,
                frequency: 440
            )
        }

        // Find surrounding data points
        var before: BioDataPoint?
        var after: BioDataPoint?

        for point in session.bioData {
            if point.timestamp <= timestamp {
                before = point
            }
            if point.timestamp > timestamp && after == nil {
                after = point
            }
        }

        guard let b = before else { return session.bioData.first! }
        guard let a = after else { return session.bioData.last! }

        // Linear interpolation
        let t = (timestamp - b.timestamp) / (a.timestamp - b.timestamp)

        return BioDataPoint(
            timestamp: timestamp,
            hrv: b.hrv + (a.hrv - b.hrv) * t,
            heartRate: b.heartRate + (a.heartRate - b.heartRate) * t,
            coherence: b.coherence + (a.coherence - b.coherence) * t,
            audioLevel: b.audioLevel + (a.audioLevel - b.audioLevel) * Float(t),
            frequency: b.frequency + (a.frequency - b.frequency) * Float(t)
        )
    }

    private func finishWriting() async {
        videoInput?.markAsFinished()

        await withCheckedContinuation { continuation in
            assetWriter?.finishWriting {
                continuation.resume()
            }
        }
    }

    private func defaultVideoURL(for session: Session) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportsDir = documentsPath.appendingPathComponent("VideoExports", isDirectory: true)
        try? FileManager.default.createDirectory(at: exportsDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "\(session.name)_\(formatter.string(from: Date())).mp4"

        return exportsDir.appendingPathComponent(filename)
    }
}

// MARK: - Errors

enum VideoExportError: LocalizedError {
    case writerCreationFailed
    case invalidConfiguration
    case encodingFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .writerCreationFailed: return "Failed to create video writer"
        case .invalidConfiguration: return "Invalid export configuration"
        case .encodingFailed: return "Video encoding failed"
        case .cancelled: return "Export was cancelled"
        }
    }
}

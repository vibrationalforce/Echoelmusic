import Foundation
import AVFoundation
import Metal
import Combine

/// Orchestrates video composition: synchronizes audio, visuals, and bio-data
/// Manages the complete video export workflow from Session to final video file
@MainActor
class VideoCompositionEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0.0
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let device: MTLDevice
    private var visualRenderer: VisualizationVideoRenderer?
    private var videoRecorder: VideoRecordingEngine?

    // MARK: - Export State

    private var cancellables = Set<AnyCancellable>()


    // MARK: - Initialization

    init(device: MTLDevice) {
        self.device = device
    }


    // MARK: - Export from Session

    /// Export a recorded session to video file
    /// - Parameters:
    ///   - session: The recording session to export
    ///   - visualizationMode: Which visualization to use
    ///   - configuration: Video export settings
    /// - Returns: URL of exported video file
    func exportSessionToVideo(
        session: Session,
        visualizationMode: VisualizationMode,
        configuration: VideoExportConfiguration
    ) async throws -> URL {
        guard !isExporting else {
            throw VideoExportError.assetWriterNotReady
        }

        isExporting = true
        exportProgress = 0.0
        defer { isExporting = false }

        print("📹 Starting session video export...")
        print("   Session: \(session.name)")
        print("   Duration: \(String(format: "%.2f", session.duration))s")
        print("   Mode: \(visualizationMode.rawValue)")

        // Create visualization renderer
        visualRenderer = try VisualizationVideoRenderer(
            device: device,
            size: configuration.resolution.size
        )

        // Create video recorder
        videoRecorder = try VideoRecordingEngine(
            configuration: configuration,
            device: device
        )

        // Start recording
        try videoRecorder?.startRecording()

        // Process session data frame by frame
        try await processSessionFrames(
            session: session,
            visualizationMode: visualizationMode,
            configuration: configuration
        )

        // Finalize video
        guard let outputURL = try await videoRecorder?.stopRecording() else {
            throw VideoExportError.writingFailed("Could not finalize video")
        }

        print("✅ Video export complete: \(outputURL.lastPathComponent)")

        return outputURL
    }


    // MARK: - Frame Processing

    private func processSessionFrames(
        session: Session,
        visualizationMode: VisualizationMode,
        configuration: VideoExportConfiguration
    ) async throws {
        let frameRate = configuration.frameRate.rawValue
        let frameDuration = 1.0 / Double(frameRate)
        let totalFrames = Int(session.duration * Double(frameRate))

        print("   Processing \(totalFrames) frames at \(frameRate) fps...")

        for frameIndex in 0..<totalFrames {
            let currentTime = Double(frameIndex) * frameDuration

            // Update progress
            exportProgress = Double(frameIndex) / Double(totalFrames)

            // Get audio and bio data for this frame
            let audioData = getAudioData(for: session, at: currentTime)
            let bioData = getBioData(for: session, at: currentTime)

            // Render visualization frame
            guard let texture = try visualRenderer?.renderFrame(
                mode: visualizationMode,
                audioData: audioData,
                bioData: bioData,
                time: currentTime
            ) else {
                throw VideoExportError.encodingFailed("Could not render frame \(frameIndex)")
            }

            // Create presentation time
            let presentationTime = CMTime(
                seconds: currentTime,
                preferredTimescale: CMTimeScale(frameRate)
            )

            // Append video frame
            try videoRecorder?.appendVideoFrame(texture: texture, at: presentationTime)

            // Progress logging every 10%
            if frameIndex % (totalFrames / 10) == 0 {
                print("   Progress: \(Int(exportProgress * 100))% (\(frameIndex)/\(totalFrames) frames)")
            }
        }

        exportProgress = 1.0
        print("   All frames processed")
    }


    // MARK: - Data Extraction

    /// Get audio FFT data for specific time
    private func getAudioData(for session: Session, at time: TimeInterval) -> [Float] {
        // TODO: Extract actual audio FFT data from session
        // For now, return mock data
        return VisualizationVideoRenderer.mockAudioData(frequency: 440.0, sampleCount: 512)
    }

    /// Get bio-feedback data for specific time
    private func getBioData(for session: Session, at time: TimeInterval) -> BioRenderData {
        // Find closest bio data point
        let dataPoints = session.bioData.filter { abs($0.timestamp - time) < 0.5 }

        if let closest = dataPoints.first {
            return BioRenderData(
                hrvCoherence: closest.coherence,
                heartRate: closest.heartRate,
                breathingRate: 6.0,  // TODO: Calculate from HRV
                audioLevel: Float(closest.audioLevel)
            )
        } else {
            // Return default values if no data point found
            return BioRenderData()
        }
    }


    // MARK: - Platform-Specific Export

    /// Export optimized for specific social media platform
    func exportForPlatform(
        session: Session,
        platform: PlatformPreset,
        visualizationMode: VisualizationMode
    ) async throws -> URL {
        // Get platform-specific configuration
        var configuration = VideoExportConfiguration.forPlatform(platform)

        // Check duration limit
        if session.duration > platform.maxDuration {
            print("⚠️ Session duration (\(session.duration)s) exceeds platform limit (\(platform.maxDuration)s)")
            print("   Video will be trimmed to \(platform.maxDuration)s")
            // TODO: Implement trimming logic
        }

        print("📱 Exporting for \(platform.displayName)")

        return try await exportSessionToVideo(
            session: session,
            visualizationMode: visualizationMode,
            configuration: configuration
        )
    }


    // MARK: - Batch Export

    /// Export session to multiple platforms simultaneously
    func exportToMultiplePlatforms(
        session: Session,
        platforms: [PlatformPreset],
        visualizationMode: VisualizationMode
    ) async throws -> [PlatformPreset: URL] {
        var results: [PlatformPreset: URL] = [:]

        for platform in platforms {
            print("📦 Exporting to \(platform.displayName)...")

            do {
                let url = try await exportForPlatform(
                    session: session,
                    platform: platform,
                    visualizationMode: visualizationMode
                )
                results[platform] = url
            } catch {
                print("❌ Failed to export for \(platform.displayName): \(error)")
                throw error
            }
        }

        print("✅ Batch export complete: \(results.count)/\(platforms.count) platforms")

        return results
    }


    // MARK: - Live Recording

    /// Start live video recording (real-time capture during performance)
    func startLiveRecording(
        configuration: VideoExportConfiguration
    ) throws {
        guard !isExporting else {
            throw VideoExportError.assetWriterNotReady
        }

        // Create visualization renderer
        visualRenderer = try VisualizationVideoRenderer(
            device: device,
            size: configuration.resolution.size
        )

        // Create video recorder
        videoRecorder = try VideoRecordingEngine(
            configuration: configuration,
            device: device
        )

        // Start recording
        try videoRecorder?.startRecording()

        isExporting = true
        print("🔴 Live video recording started")
    }

    /// Capture current frame during live recording
    func captureLiveFrame(
        visualizationMode: VisualizationMode,
        audioData: [Float],
        bioData: BioRenderData,
        time: TimeInterval
    ) throws {
        guard isExporting else { return }

        // Render current frame
        guard let texture = try visualRenderer?.renderFrame(
            mode: visualizationMode,
            audioData: audioData,
            bioData: bioData,
            time: time
        ) else {
            throw VideoExportError.encodingFailed("Could not render live frame")
        }

        // Create presentation time
        let presentationTime = CMTime(
            seconds: time,
            preferredTimescale: 600  // Standard video timescale
        )

        // Append to video
        try videoRecorder?.appendVideoFrame(texture: texture, at: presentationTime)
    }

    /// Stop live recording and save video
    func stopLiveRecording() async throws -> URL {
        guard isExporting else {
            throw VideoExportError.assetWriterNotReady
        }

        defer { isExporting = false }

        guard let outputURL = try await videoRecorder?.stopRecording() else {
            throw VideoExportError.writingFailed("Could not finalize live recording")
        }

        print("⏹️ Live recording stopped")
        print("   Saved to: \(outputURL.lastPathComponent)")

        return outputURL
    }


    // MARK: - Utility Methods

    /// Estimate export duration
    func estimateExportDuration(session: Session, configuration: VideoExportConfiguration) -> TimeInterval {
        // Rough estimate: 2-3x real-time for software encoding
        let encodingFactor = 2.5
        return session.duration * encodingFactor
    }

    /// Check if session can be exported
    func canExport(session: Session) -> (canExport: Bool, reason: String?) {
        // Check if session has tracks
        guard !session.tracks.isEmpty else {
            return (false, "Session has no audio tracks")
        }

        // Check duration
        guard session.duration > 0 else {
            return (false, "Session duration is zero")
        }

        // Check storage space
        let estimatedSize = Int64(session.duration) * 10_000_000  // ~10 MB/s
        if !VideoRecordingEngine.hasEnoughStorage(
            estimatedDuration: session.duration,
            quality: .high
        ) {
            return (false, "Insufficient storage space")
        }

        return (true, nil)
    }
}


// MARK: - Export Presets

extension VideoCompositionEngine {
    /// Quick export presets for common use cases
    enum ExportPreset {
        case instagramReels
        case tiktok
        case youtubeShorts
        case highQuality

        var configuration: VideoExportConfiguration {
            switch self {
            case .instagramReels:
                return VideoExportConfiguration.forPlatform(.instagramReels)
            case .tiktok:
                return VideoExportConfiguration.forPlatform(.tiktok)
            case .youtubeShorts:
                return VideoExportConfiguration.forPlatform(.youtubeShorts)
            case .highQuality:
                return VideoExportConfiguration(
                    resolution: .hd4K,
                    format: .hevc,
                    quality: .maximum,
                    frameRate: .fps60
                )
            }
        }
    }
}

import Foundation
import AVFoundation
import Metal

/// Extension to ExportManager for video export functionality
/// Adds video export capabilities to the existing audio/bio-data export system
extension ExportManager {

    // MARK: - Video Export

    /// Export session as video with visualization
    /// - Parameters:
    ///   - session: Session to export
    ///   - visualizationMode: Which visualization to render
    ///   - configuration: Video export settings
    /// - Returns: URL of exported video file
    func exportVideo(
        session: Session,
        visualizationMode: VisualizationMode,
        configuration: VideoExportConfiguration = VideoExportConfiguration()
    ) async throws -> URL {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw VideoExportError.unsupportedFormat
        }

        let compositionEngine = VideoCompositionEngine(device: device)

        print("📹 Starting video export...")
        print("   Session: \(session.name)")
        print("   Mode: \(visualizationMode.rawValue)")
        print("   Resolution: \(configuration.resolution.size)")
        print("   Format: \(configuration.format.fileExtension)")

        let videoURL = try await compositionEngine.exportSessionToVideo(
            session: session,
            visualizationMode: visualizationMode,
            configuration: configuration
        )

        print("✅ Video exported: \(videoURL.lastPathComponent)")

        return videoURL
    }

    /// Export video optimized for specific platform
    /// - Parameters:
    ///   - session: Session to export
    ///   - platform: Target social media platform
    ///   - visualizationMode: Which visualization to render
    /// - Returns: URL of exported video file
    func exportVideoForPlatform(
        session: Session,
        platform: PlatformPreset,
        visualizationMode: VisualizationMode
    ) async throws -> URL {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw VideoExportError.unsupportedFormat
        }

        let compositionEngine = VideoCompositionEngine(device: device)

        print("📱 Exporting for \(platform.displayName)...")

        let videoURL = try await compositionEngine.exportForPlatform(
            session: session,
            platform: platform,
            visualizationMode: visualizationMode
        )

        print("✅ Platform video exported: \(videoURL.lastPathComponent)")

        return videoURL
    }

    /// Export video to multiple platforms simultaneously
    /// - Parameters:
    ///   - session: Session to export
    ///   - platforms: List of target platforms
    ///   - visualizationMode: Which visualization to render
    /// - Returns: Dictionary mapping platforms to video URLs
    func exportVideoToMultiplePlatforms(
        session: Session,
        platforms: [PlatformPreset],
        visualizationMode: VisualizationMode
    ) async throws -> [PlatformPreset: URL] {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw VideoExportError.unsupportedFormat
        }

        let compositionEngine = VideoCompositionEngine(device: device)

        print("📦 Batch exporting to \(platforms.count) platforms...")

        let results = try await compositionEngine.exportToMultiplePlatforms(
            session: session,
            platforms: platforms,
            visualizationMode: visualizationMode
        )

        print("✅ Batch export complete: \(results.count) videos")

        return results
    }

    /// Export complete video package (video + audio + bio-data + metadata)
    /// - Parameters:
    ///   - session: Session to export
    ///   - visualizationMode: Which visualization to render
    ///   - configuration: Video export settings
    ///   - outputDirectory: Destination directory (optional)
    /// - Returns: URL of exported package directory
    func exportCompleteVideoPackage(
        session: Session,
        visualizationMode: VisualizationMode,
        configuration: VideoExportConfiguration = VideoExportConfiguration(),
        outputDirectory: URL? = nil
    ) async throws -> URL {
        let packageURL = outputDirectory ?? defaultVideoPackageURL(for: session)

        // Create package directory
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)

        print("📦 Creating complete video package...")

        // Export video
        let videoURL = packageURL.appendingPathComponent("video.\(configuration.format.fileExtension)")
        let videoConfig = VideoExportConfiguration(
            resolution: configuration.resolution,
            format: configuration.format,
            quality: configuration.quality,
            frameRate: configuration.frameRate,
            includeAudio: configuration.includeAudio,
            outputURL: videoURL
        )

        _ = try await exportVideo(
            session: session,
            visualizationMode: visualizationMode,
            configuration: videoConfig
        )

        // Export audio-only version
        let audioURL = packageURL.appendingPathComponent("audio.wav")
        _ = try await exportAudio(session: session, format: .wav, outputURL: audioURL)

        // Export bio-data
        let bioDataURL = packageURL.appendingPathComponent("biodata.json")
        _ = try exportBioData(session: session, format: .json, outputURL: bioDataURL)

        // Export session metadata
        let metadataURL = packageURL.appendingPathComponent("session.json")
        try exportSessionMetadata(session: session, outputURL: metadataURL)

        // Create README
        let readmeURL = packageURL.appendingPathComponent("README.txt")
        try createPackageReadme(session: session, configuration: configuration, outputURL: readmeURL)

        print("✅ Complete package exported: \(packageURL.lastPathComponent)")

        return packageURL
    }


    // MARK: - Quick Export Presets

    /// Quick export for Instagram Reels (9:16, 90s max)
    func exportInstagramReels(
        session: Session,
        visualizationMode: VisualizationMode
    ) async throws -> URL {
        return try await exportVideoForPlatform(
            session: session,
            platform: .instagramReels,
            visualizationMode: visualizationMode
        )
    }

    /// Quick export for TikTok (9:16, 3min max)
    func exportTikTok(
        session: Session,
        visualizationMode: VisualizationMode
    ) async throws -> URL {
        return try await exportVideoForPlatform(
            session: session,
            platform: .tiktok,
            visualizationMode: visualizationMode
        )
    }

    /// Quick export for YouTube Shorts (9:16, 60s max)
    func exportYouTubeShorts(
        session: Session,
        visualizationMode: VisualizationMode
    ) async throws -> URL {
        return try await exportVideoForPlatform(
            session: session,
            platform: .youtubeShorts,
            visualizationMode: visualizationMode
        )
    }

    /// Quick export for Instagram Feed (1:1 square)
    func exportInstagramFeed(
        session: Session,
        visualizationMode: VisualizationMode
    ) async throws -> URL {
        return try await exportVideoForPlatform(
            session: session,
            platform: .instagramFeed,
            visualizationMode: visualizationMode
        )
    }


    // MARK: - Helper Methods

    /// Generate default video package URL
    private func defaultVideoPackageURL(for session: Session) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportsDir = documentsPath.appendingPathComponent("VideoExports", isDirectory: true)
        try? FileManager.default.createDirectory(at: exportsDir, withIntermediateDirectories: true)

        let packageName = "\(session.name)_\(dateString())_Package"
        return exportsDir.appendingPathComponent(packageName, isDirectory: true)
    }

    /// Create README file for video package
    private func createPackageReadme(
        session: Session,
        configuration: VideoExportConfiguration,
        outputURL: URL
    ) throws {
        let readme = """
        BLAB VIDEO EXPORT PACKAGE
        =========================

        Session Information:
        - Name: \(session.name)
        - Duration: \(String(format: "%.2f", session.duration)) seconds
        - Tracks: \(session.tracks.count)
        - Bio Data Points: \(session.bioData.count)

        Video Settings:
        - Resolution: \(configuration.resolution.size.width)x\(configuration.resolution.size.height) (\(configuration.resolution.aspectRatio))
        - Format: \(configuration.format.fileExtension.uppercased())
        - Quality: \(configuration.quality.bitrate / 1_000_000) Mbps
        - Frame Rate: \(configuration.frameRate.rawValue) fps

        Package Contents:
        - video.\(configuration.format.fileExtension) - Complete video with audio and visuals
        - audio.wav - Audio-only track (lossless)
        - biodata.json - Bio-feedback data (HRV, heart rate, etc.)
        - session.json - Session metadata
        - README.txt - This file

        Generated by BLAB iOS App
        Date: \(ISO8601DateFormatter().string(from: Date()))
        """

        try readme.write(to: outputURL, atomically: true, encoding: .utf8)
    }
}


// MARK: - Video Export Validation

extension ExportManager {
    /// Validate session can be exported to video
    func validateVideoExport(session: Session) -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []

        // Check session has audio tracks
        if session.tracks.isEmpty {
            errors.append("Session has no audio tracks")
        }

        // Check duration
        if session.duration <= 0 {
            errors.append("Session duration is zero or negative")
        }

        // Check storage space
        let estimatedSize = Int64(session.duration) * 10_000_000  // ~10 MB/s
        let requiredSpace = estimatedSize * 2  // 2x buffer

        do {
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let availableSpace = values.volumeAvailableCapacity,
               Int64(availableSpace) < requiredSpace {
                errors.append("Insufficient storage space (need ~\(requiredSpace / 1_000_000) MB)")
            }
        } catch {
            errors.append("Could not check storage space")
        }

        return (errors.isEmpty, errors)
    }

    /// Estimate video export file size
    func estimateVideoFileSize(
        session: Session,
        configuration: VideoExportConfiguration
    ) -> Int64 {
        // Rough estimate based on bitrate and duration
        let videoBitrate = Int64(configuration.quality.bitrate)
        let audioBitrate: Int64 = configuration.includeAudio ? 128_000 : 0
        let totalBitrate = videoBitrate + audioBitrate

        let durationSeconds = Int64(session.duration)
        let estimatedBytes = (totalBitrate / 8) * durationSeconds

        return estimatedBytes
    }

    /// Estimate video export duration
    func estimateVideoExportDuration(
        session: Session,
        configuration: VideoExportConfiguration
    ) -> TimeInterval {
        // Software encoding is typically 2-3x real-time
        // Higher resolutions take longer
        let encodingFactor: Double

        switch configuration.resolution {
        case .hd720:
            encodingFactor = 2.0
        case .hd1080, .vertical1080, .square1080:
            encodingFactor = 2.5
        case .hd4K:
            encodingFactor = 4.0
        case .custom:
            encodingFactor = 3.0
        }

        return session.duration * encodingFactor
    }
}


// MARK: - Platform Utilities

extension ExportManager {
    /// Get recommended platforms for session
    func recommendedPlatforms(for session: Session) -> [PlatformPreset] {
        var platforms: [PlatformPreset] = []

        // Recommend based on duration
        if session.duration <= 15 {
            platforms.append(.instagramStory)
        }

        if session.duration <= 60 {
            platforms.append(.youtubeShorts)
            platforms.append(.snapchatSpotlight)
            platforms.append(.instagramFeed)
        }

        if session.duration <= 90 {
            platforms.append(.instagramReels)
        }

        if session.duration <= 180 {
            platforms.append(.tiktok)
        }

        // Always include standard options
        platforms.append(.youtubeVideo)
        platforms.append(.twitter)

        return platforms
    }

    /// Get platform limitations
    func platformLimitations(for platform: PlatformPreset) -> String {
        return """
        Platform: \(platform.displayName)
        Max Duration: \(Int(platform.maxDuration))s
        Resolution: \(platform.resolution.size.width)x\(platform.resolution.size.height)
        Aspect Ratio: \(platform.resolution.aspectRatio)
        """
    }
}

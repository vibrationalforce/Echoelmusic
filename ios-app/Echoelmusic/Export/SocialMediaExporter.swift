import Foundation
import AVFoundation
import CoreImage
import Photos
import UIKit

// MARK: - Social Media Exporter
/// One-click export to all major social media platforms
/// Phase 11: TikTok, Instagram, YouTube, Twitter, Facebook
class SocialMediaExporter: ObservableObject {

    // MARK: - Published Properties
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0.0
    @Published var lastExportedURL: URL?
    @Published var exportError: Error?

    // MARK: - Properties
    private let timeline: Timeline
    private let videoEngine: VideoPlaybackEngine?

    // Export queue
    private let exportQueue = DispatchQueue(label: "com.echoelmusic.export", qos: .userInitiated)

    // MARK: - Initialization
    init(timeline: Timeline, videoEngine: VideoPlaybackEngine? = nil) {
        self.timeline = timeline
        self.videoEngine = videoEngine
    }

    // MARK: - Platform Presets

    /// All available platform presets
    static let allPresets: [SocialMediaPreset] = [
        // TikTok
        .tikTok15sec,
        .tikTok30sec,
        .tikTok60sec,
        .tikTok3min,

        // Instagram
        .instagramReel,
        .instagramStory,
        .instagramFeed,
        .instagramIGTV,

        // YouTube
        .youtubeShort,
        .youtubeStandard,
        .youtube4K,

        // Twitter
        .twitter,

        // Facebook
        .facebookFeed,
        .facebookStory
    ]

    // MARK: - Export Methods

    /// Export to social media platform with preset
    func export(
        preset: SocialMediaPreset,
        outputURL: URL? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard !isExporting else {
            completion(.failure(ExportError.alreadyExporting))
            return
        }

        DispatchQueue.main.async {
            self.isExporting = true
            self.exportProgress = 0.0
            self.exportError = nil
        }

        exportQueue.async {
            do {
                // Determine output URL
                let finalURL = outputURL ?? self.defaultOutputURL(for: preset)

                // Create composition
                let composition = try self.createComposition(for: preset)

                // Apply preset settings
                let videoComposition = try self.createVideoComposition(for: preset, composition: composition)

                // Export with AVAssetExportSession
                try self.performExport(
                    composition: composition,
                    videoComposition: videoComposition,
                    preset: preset,
                    outputURL: finalURL,
                    completion: completion
                )

            } catch {
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.exportError = error
                }
                completion(.failure(error))
            }
        }
    }

    /// Quick export to multiple platforms simultaneously
    func exportToMultiplePlatforms(
        presets: [SocialMediaPreset],
        completion: @escaping (Result<[URL], Error>) -> Void
    ) {
        var exportedURLs: [URL] = []
        var exportErrors: [Error] = []
        let group = DispatchGroup()

        for preset in presets {
            group.enter()
            export(preset: preset) { result in
                switch result {
                case .success(let url):
                    exportedURLs.append(url)
                case .failure(let error):
                    exportErrors.append(error)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if exportedURLs.isEmpty {
                completion(.failure(exportErrors.first ?? ExportError.unknownError))
            } else {
                completion(.success(exportedURLs))
            }
        }
    }

    // MARK: - Private Export Implementation

    private func createComposition(for preset: SocialMediaPreset) throws -> AVMutableComposition {
        let composition = AVMutableComposition()

        // Calculate timeline duration
        let timelineEndSample = timeline.tracks.flatMap { $0.clips }.map { $0.endPosition }.max() ?? 0
        let timelineDuration = CMTime(value: timelineEndSample, timescale: CMTimeScale(timeline.sampleRate))

        // Constrain to preset max duration
        let exportDuration: CMTime
        if let maxDuration = preset.maxDuration, timelineDuration > maxDuration {
            exportDuration = maxDuration
        } else {
            exportDuration = timelineDuration
        }

        // Add audio tracks
        let audioTracks = timeline.tracks.filter { $0.type == .audio || $0.type == .master }
        for (index, track) in audioTracks.enumerated() {
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid)
            ) else { continue }

            // Add clips from this track
            for clip in track.clips {
                guard clip.type == .audio, let sourceURL = clip.sourceURL else { continue }

                let asset = AVURLAsset(url: sourceURL)
                guard let audioTrack = asset.tracks(withMediaType: .audio).first else { continue }

                let startTime = CMTime(value: clip.startPosition, timescale: CMTimeScale(timeline.sampleRate))
                let duration = CMTime(value: clip.duration, timescale: CMTimeScale(timeline.sampleRate))
                let sourceStart = CMTime(value: clip.sourceOffset, timescale: CMTimeScale(timeline.sampleRate))

                // Don't exceed export duration
                if startTime >= exportDuration { break }

                do {
                    try compositionTrack.insertTimeRange(
                        CMTimeRange(start: sourceStart, duration: duration),
                        of: audioTrack,
                        at: startTime
                    )
                } catch {
                    print("Warning: Could not insert audio clip \(clip.name): \(error)")
                }
            }
        }

        // Add video tracks if video engine available
        if videoEngine != nil {
            let videoTracks = timeline.tracks.filter { $0.type == .video || $0.clips.contains { $0.type == .video } }

            for track in videoTracks {
                guard let compositionTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid)
                ) else { continue }

                for clip in track.clips {
                    guard clip.type == .video, let sourceURL = clip.sourceURL else { continue }

                    let asset = AVURLAsset(url: sourceURL)
                    guard let videoTrack = asset.tracks(withMediaType: .video).first else { continue }

                    let startTime = CMTime(value: clip.startPosition, timescale: CMTimeScale(timeline.sampleRate))
                    let duration = CMTime(value: clip.duration, timescale: CMTimeScale(timeline.sampleRate))
                    let sourceStart = CMTime(value: clip.sourceOffset, timescale: CMTimeScale(timeline.sampleRate))

                    if startTime >= exportDuration { break }

                    do {
                        try compositionTrack.insertTimeRange(
                            CMTimeRange(start: sourceStart, duration: duration),
                            of: videoTrack,
                            at: startTime
                        )
                    } catch {
                        print("Warning: Could not insert video clip \(clip.name): \(error)")
                    }
                }
            }
        }

        return composition
    }

    private func createVideoComposition(for preset: SocialMediaPreset, composition: AVComposition) throws -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = preset.resolution
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(preset.frameRate))

        // Create layer instructions for each video track
        var layerInstructions: [AVMutableVideoCompositionLayerInstruction] = []

        for track in composition.tracks(withMediaType: .video) {
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)

            // Apply transform for aspect ratio adjustment
            if let transform = calculateTransform(for: track, targetSize: preset.resolution, cropMode: preset.cropMode) {
                layerInstruction.setTransform(transform, at: .zero)
            }

            layerInstructions.append(layerInstruction)
        }

        // Create instruction for entire timeline
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        instruction.layerInstructions = layerInstructions

        videoComposition.instructions = [instruction]

        return videoComposition
    }

    private func calculateTransform(for track: AVAssetTrack, targetSize: CGSize, cropMode: CropMode) -> CGAffineTransform? {
        let sourceSize = track.naturalSize
        let sourceAspect = sourceSize.width / sourceSize.height
        let targetAspect = targetSize.width / targetSize.height

        var transform = track.preferredTransform

        switch cropMode {
        case .fill:
            // Scale to fill, may crop edges
            let scale: CGFloat
            if sourceAspect > targetAspect {
                // Source is wider, scale to height
                scale = targetSize.height / sourceSize.height
            } else {
                // Source is taller, scale to width
                scale = targetSize.width / sourceSize.width
            }
            transform = transform.scaledBy(x: scale, y: scale)

            // Center
            let scaledWidth = sourceSize.width * scale
            let scaledHeight = sourceSize.height * scale
            let dx = (targetSize.width - scaledWidth) / 2
            let dy = (targetSize.height - scaledHeight) / 2
            transform = transform.translatedBy(x: dx, y: dy)

        case .fit:
            // Scale to fit, may have letterboxing
            let scale: CGFloat
            if sourceAspect > targetAspect {
                // Source is wider, scale to width
                scale = targetSize.width / sourceSize.width
            } else {
                // Source is taller, scale to height
                scale = targetSize.height / sourceSize.height
            }
            transform = transform.scaledBy(x: scale, y: scale)

            // Center
            let scaledWidth = sourceSize.width * scale
            let scaledHeight = sourceSize.height * scale
            let dx = (targetSize.width - scaledWidth) / 2
            let dy = (targetSize.height - scaledHeight) / 2
            transform = transform.translatedBy(x: dx, y: dy)

        case .stretch:
            // Stretch to fill (distorts image)
            let scaleX = targetSize.width / sourceSize.width
            let scaleY = targetSize.height / sourceSize.height
            transform = transform.scaledBy(x: scaleX, y: scaleY)
        }

        return transform
    }

    private func performExport(
        composition: AVComposition,
        videoComposition: AVMutableVideoComposition,
        preset: SocialMediaPreset,
        outputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) throws {
        // Delete existing file if present
        try? FileManager.default.removeItem(at: outputURL)

        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: preset.exportQuality.avPreset
        ) else {
            throw ExportError.cannotCreateExportSession
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = preset.fileFormat
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true

        // Apply audio settings
        exportSession.audioTimePitchAlgorithm = .spectral

        // Audio mix if needed (for volume/pan automation)
        if let audioMix = createAudioMix(for: composition) {
            exportSession.audioMix = audioMix
        }

        // Apply metadata
        exportSession.metadata = createMetadata(for: preset)

        // Progress tracking
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.exportProgress = Double(exportSession.progress)
            }
        }

        // Export asynchronously
        exportSession.exportAsynchronously {
            progressTimer.invalidate()

            DispatchQueue.main.async {
                self.isExporting = false
                self.exportProgress = 1.0

                switch exportSession.status {
                case .completed:
                    self.lastExportedURL = outputURL

                    // Optimize for platform
                    if preset.shouldOptimize {
                        self.optimizeForPlatform(url: outputURL, preset: preset) { optimizedURL in
                            completion(.success(optimizedURL ?? outputURL))
                        }
                    } else {
                        completion(.success(outputURL))
                    }

                case .failed:
                    let error = exportSession.error ?? ExportError.unknownError
                    self.exportError = error
                    completion(.failure(error))

                case .cancelled:
                    completion(.failure(ExportError.cancelled))

                default:
                    completion(.failure(ExportError.unknownError))
                }
            }
        }
    }

    // MARK: - Audio Mix

    private func createAudioMix(for composition: AVComposition) -> AVMutableAudioMix? {
        let audioMix = AVMutableAudioMix()
        var inputParameters: [AVMutableAudioMixInputParameters] = []

        for track in composition.tracks(withMediaType: .audio) {
            let params = AVMutableAudioMixInputParameters(track: track)

            // Apply volume automation if available
            // (This would use timeline automation data)
            params.setVolume(1.0, at: .zero)

            inputParameters.append(params)
        }

        if inputParameters.isEmpty {
            return nil
        }

        audioMix.inputParameters = inputParameters
        return audioMix
    }

    // MARK: - Metadata

    private func createMetadata(for preset: SocialMediaPreset) -> [AVMetadataItem] {
        var metadata: [AVMetadataItem] = []

        // Creator
        let creatorItem = AVMutableMetadataItem()
        creatorItem.identifier = .commonIdentifierCreator
        creatorItem.value = "Echoelmusic" as NSString
        metadata.append(creatorItem)

        // Software
        let softwareItem = AVMutableMetadataItem()
        softwareItem.identifier = .commonIdentifierSoftware
        softwareItem.value = "Echoelmusic v1.0" as NSString
        metadata.append(softwareItem)

        // Platform-specific tags
        if preset.platform == .tikTok || preset.platform == .instagram {
            let descriptionItem = AVMutableMetadataItem()
            descriptionItem.identifier = .commonIdentifierDescription
            descriptionItem.value = "#echoelmusic #music #creative" as NSString
            metadata.append(descriptionItem)
        }

        return metadata
    }

    // MARK: - Platform Optimization

    private func optimizeForPlatform(url: URL, preset: SocialMediaPreset, completion: @escaping (URL?) -> Void) {
        // Platform-specific optimization (bitrate, audio normalization, etc.)
        // For now, just return original URL
        // TODO: Implement loudness normalization (LUFS targeting)
        completion(url)
    }

    // MARK: - Utility

    private func defaultOutputURL(for preset: SocialMediaPreset) -> URL {
        let filename = "\(preset.platform.rawValue)_\(Date().timeIntervalSince1970).mp4"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent(filename)
    }

    // MARK: - Save to Photos

    func saveToPhotos(_ url: URL, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                completion(false, ExportError.photoLibraryAccessDenied)
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    completion(success, error)
                }
            }
        }
    }
}

// MARK: - Social Media Preset

struct SocialMediaPreset {
    let platform: Platform
    let name: String
    let resolution: CGSize
    let aspectRatio: AspectRatio
    let frameRate: Int
    let maxDuration: CMTime?
    let fileFormat: AVFileType
    let exportQuality: ExportQuality
    let cropMode: CropMode
    let shouldOptimize: Bool
    let suggestedHashtags: [String]

    enum Platform: String {
        case tikTok = "TikTok"
        case instagram = "Instagram"
        case youtube = "YouTube"
        case twitter = "Twitter"
        case facebook = "Facebook"
    }

    enum AspectRatio {
        case vertical       // 9:16
        case square         // 1:1
        case horizontal     // 16:9
        case fourFive       // 4:5

        var ratio: CGFloat {
            switch self {
            case .vertical:     return 9.0 / 16.0
            case .square:       return 1.0
            case .horizontal:   return 16.0 / 9.0
            case .fourFive:     return 4.0 / 5.0
            }
        }
    }

    // MARK: - TikTok Presets
    static let tikTok15sec = SocialMediaPreset(
        platform: .tikTok,
        name: "TikTok 15s",
        resolution: CGSize(width: 1080, height: 1920),
        aspectRatio: .vertical,
        frameRate: 30,
        maxDuration: CMTime(seconds: 15, preferredTimescale: 600),
        fileFormat: .mp4,
        exportQuality: .high,
        cropMode: .fill,
        shouldOptimize: true,
        suggestedHashtags: ["#tikTok", "#fyp", "#music"]
    )

    static let tikTok30sec = SocialMediaPreset(
        platform: .tikTok,
        name: "TikTok 30s",
        resolution: CGSize(width: 1080, height: 1920),
        aspectRatio: .vertical,
        frameRate: 30,
        maxDuration: CMTime(seconds: 30, preferredTimescale: 600),
        fileFormat: .mp4,
        exportQuality: .high,
        cropMode: .fill,
        shouldOptimize: true,
        suggestedHashtags: ["#tikTok", "#fyp", "#music"]
    )

    static let tikTok60sec = SocialMediaPreset(
        platform: .tikTok,
        name: "TikTok 60s",
        resolution: CGSize(width: 1080, height: 1920),
        aspectRatio: .vertical,
        frameRate: 30,
        maxDuration: CMTime(seconds: 60, preferredTimescale: 600),
        fileFormat: .mp4,
        exportQuality: .high,
        cropMode: .fill,
        shouldOptimize: true,
        suggestedHashtags: ["#tikTok", "#fyp", "#music"]
    )

    static let tikTok3min = SocialMediaPreset(
        platform: .tikTok,
        name: "TikTok 3min",
        resolution: CGSize(width: 1080, height: 1920),
        aspectRatio: .vertical,
        frameRate: 30,
        maxDuration: CMTime(seconds: 180, preferredTimescale: 600),
        fileFormat: .mp4,
        exportQuality: .high,
        cropMode: .fill,
        shouldOptimize: true,
        suggestedHashtags: ["#tikTok", "#fyp", "#music"]
    )

    // MARK: - Instagram Presets
    static let instagramReel = SocialMediaPreset(
        platform: .instagram,
        name: "Instagram Reel",
        resolution: CGSize(width: 1080, height: 1920),
        aspectRatio: .vertical,
        frameRate: 30,
        maxDuration: CMTime(seconds: 90, preferredTimescale: 600),
        fileFormat: .mp4,
        exportQuality: .high,
        cropMode: .fill,
        shouldOptimize: true,
        suggestedHashtags: ["#reels", "#instagram", "#music"]
    )

    static let instagramStory = SocialMediaPreset(
        platform: .instagram,
        name: "Instagram Story",
        resolution: CGSize(width: 1080, height: 1920),
        aspectRatio: .vertical,
        frameRate: 30,
        maxDuration: CMTime(seconds: 60, preferredTimescale: 600),
        fileFormat: .mp4,
        exportQuality: .high,
        cropMode: .fill,
        shouldOptimize: true,
        suggestedHashtags: []
    )

    static let instagramFeed = SocialMediaPreset(
        platform: .instagram,
        name: "Instagram Feed",
        resolution: CGSize(width: 1080, height: 1350),
        aspectRatio: .fourFive,
        frameRate: 30,
        maxDuration: CMTime(seconds: 60, preferredTimescale: 600),
        fileFormat: .mp4,
        exportQuality: .high,
        cropMode: .fill,
        shouldOptimize: true,
        suggestedHashtags: ["#instagram", "#music"]
    )

    static let instagramIGTV = SocialMediaPreset(
        platform: .instagram,
        name: "Instagram IGTV",
        resolution: CGSize(width: 1080, height: 1920),
        aspectRatio: .vertical,
        frameRate: 30,
        maxDuration: nil, // No limit
        fileFormat: .mp4,
        exportQuality: .high,
        cropMode: .fill,
        shouldOptimize: true,
        suggestedHashtags: ["#igtv", "#music"]
    )

    // MARK: - YouTube Presets
    static let youtubeShort = SocialMediaPreset(
        platform: .youtube,
        name: "YouTube Short",
        resolution: CGSize(width: 1080, height: 1920),
        aspectRatio: .vertical,
        frameRate: 60,
        maxDuration: CMTime(seconds: 60, preferredTimescale: 600),
        fileFormat: .mp4,
        exportQuality: .highest,
        cropMode: .fill,
        shouldOptimize: true,
        suggestedHashtags: ["#shorts", "#youtube"]
    )

    static let youtubeStandard = SocialMediaPreset(
        platform: .youtube,
        name: "YouTube 1080p",
        resolution: CGSize(width: 1920, height: 1080),
        aspectRatio: .horizontal,
        frameRate: 60,
        maxDuration: nil,
        fileFormat: .mp4,
        exportQuality: .highest,
        cropMode: .fit,
        shouldOptimize: true,
        suggestedHashtags: []
    )

    static let youtube4K = SocialMediaPreset(
        platform: .youtube,
        name: "YouTube 4K",
        resolution: CGSize(width: 3840, height: 2160),
        aspectRatio: .horizontal,
        frameRate: 60,
        maxDuration: nil,
        fileFormat: .mp4,
        exportQuality: .highest,
        cropMode: .fit,
        shouldOptimize: false, // Keep max quality
        suggestedHashtags: []
    )

    // MARK: - Twitter Preset
    static let twitter = SocialMediaPreset(
        platform: .twitter,
        name: "Twitter",
        resolution: CGSize(width: 1280, height: 720),
        aspectRatio: .horizontal,
        frameRate: 30,
        maxDuration: CMTime(seconds: 140, preferredTimescale: 600),
        fileFormat: .mp4,
        exportQuality: .medium,
        cropMode: .fit,
        shouldOptimize: true,
        suggestedHashtags: ["#twitter"]
    )

    // MARK: - Facebook Presets
    static let facebookFeed = SocialMediaPreset(
        platform: .facebook,
        name: "Facebook Feed",
        resolution: CGSize(width: 1280, height: 720),
        aspectRatio: .horizontal,
        frameRate: 30,
        maxDuration: nil,
        fileFormat: .mp4,
        exportQuality: .high,
        cropMode: .fit,
        shouldOptimize: true,
        suggestedHashtags: []
    )

    static let facebookStory = SocialMediaPreset(
        platform: .facebook,
        name: "Facebook Story",
        resolution: CGSize(width: 1080, height: 1920),
        aspectRatio: .vertical,
        frameRate: 30,
        maxDuration: CMTime(seconds: 60, preferredTimescale: 600),
        fileFormat: .mp4,
        exportQuality: .high,
        cropMode: .fill,
        shouldOptimize: true,
        suggestedHashtags: []
    )
}

enum ExportQuality {
    case low, medium, high, highest

    var avPreset: String {
        switch self {
        case .low:      return AVAssetExportPresetMediumQuality
        case .medium:   return AVAssetExportPresetHighQuality
        case .high:     return AVAssetExportPreset1920x1080
        case .highest:  return AVAssetExportPreset3840x2160
        }
    }
}

enum CropMode {
    case fill       // Scale to fill, crop edges
    case fit        // Scale to fit, letterbox
    case stretch    // Stretch to fill (distorts)
}

enum ExportError: LocalizedError {
    case alreadyExporting
    case cannotCreateExportSession
    case cancelled
    case photoLibraryAccessDenied
    case unknownError

    var errorDescription: String? {
        switch self {
        case .alreadyExporting:             return "Export already in progress"
        case .cannotCreateExportSession:    return "Cannot create export session"
        case .cancelled:                    return "Export cancelled"
        case .photoLibraryAccessDenied:     return "Photo library access denied"
        case .unknownError:                 return "Unknown export error"
        }
    }
}

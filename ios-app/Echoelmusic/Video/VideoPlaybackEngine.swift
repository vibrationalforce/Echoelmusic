import Foundation
import AVFoundation
import CoreImage
import Metal
import MetalKit
import SwiftUI

// MARK: - Video Playback Engine
/// Real-time video playback and compositing engine
/// Syncs with Timeline, renders video clips with effects
/// Phase 7.2: Complete video playback with composition
class VideoPlaybackEngine: ObservableObject {

    // MARK: - Published Properties
    @Published var currentFrame: CIImage?
    @Published var isPlaying: Bool = false
    @Published var currentTime: CMTime = .zero

    // MARK: - Properties
    private let timeline: Timeline
    private var videoTracks: [Track] = []

    // AVFoundation
    private var assetReaders: [UUID: AVAssetReader] = [:]
    private var assetReaderOutputs: [UUID: AVAssetReaderTrackOutput] = [:]

    // CoreImage Context
    private let ciContext: CIContext
    private let metalDevice: MTLDevice

    // Playback
    private var displayLink: CADisplayLink?
    private var startTime: Date?
    private var pausedTime: TimeInterval = 0

    // Frame cache for performance
    private var frameCache: [String: CIImage] = [:]
    private let maxCacheSize = 100

    // Composition
    private var composition: AVMutableComposition?
    private var videoComposition: AVMutableVideoComposition?

    // MARK: - Initialization
    init(timeline: Timeline) {
        self.timeline = timeline

        // Setup Metal device for hardware-accelerated rendering
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.metalDevice = device
        self.ciContext = CIContext(mtlDevice: device)

        // Filter video tracks
        updateVideoTracks()
    }

    // MARK: - Playback Control
    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        startTime = Date()

        // Start display link for frame updates
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        displayLink?.add(to: .main, forMode: .common)
    }

    func pause() {
        guard isPlaying else { return }
        isPlaying = false

        if let start = startTime {
            pausedTime += Date().timeIntervalSince(start)
        }

        displayLink?.invalidate()
        displayLink = nil
    }

    func stop() {
        isPlaying = false
        pausedTime = 0
        currentTime = .zero
        startTime = nil

        displayLink?.invalidate()
        displayLink = nil

        clearCache()
    }

    func seek(to time: CMTime) {
        currentTime = time
        pausedTime = time.seconds

        // Render frame at new position
        renderFrame(at: time)
    }

    // MARK: - Frame Rendering
    @objc private func updateFrame() {
        guard isPlaying, let start = startTime else { return }

        // Calculate current playback time
        let elapsed = Date().timeIntervalSince(start) + pausedTime
        let time = CMTime(seconds: elapsed, preferredTimescale: 600)

        currentTime = time
        renderFrame(at: time)
    }

    private func renderFrame(at time: CMTime) {
        // Get all active video clips at current time
        let activeClips = getActiveVideoClips(at: time)

        guard !activeClips.isEmpty else {
            // No video clips, clear frame
            DispatchQueue.main.async {
                self.currentFrame = nil
            }
            return
        }

        // Composite all video layers
        let composited = compositeClips(activeClips, at: time)

        // Update published frame
        DispatchQueue.main.async {
            self.currentFrame = composited
        }
    }

    /// Gets all video clips active at given time
    private func getActiveVideoClips(at time: CMTime) -> [Clip] {
        updateVideoTracks()

        var activeClips: [Clip] = []

        for track in videoTracks {
            for clip in track.clips {
                guard clip.type == .video else { continue }

                let clipStartTime = CMTime(value: clip.startPosition, timescale: CMTimeScale(timeline.sampleRate))
                let clipEndTime = CMTime(value: clip.endPosition, timescale: CMTimeScale(timeline.sampleRate))

                if time >= clipStartTime && time < clipEndTime {
                    activeClips.append(clip)
                }
            }
        }

        // Sort by track index (lower tracks render first, higher on top)
        activeClips.sort { clip1, clip2 in
            guard let track1 = clip1.track, let track2 = clip2.track else { return false }
            return (timeline.tracks.firstIndex(where: { $0.id == track1.id }) ?? 0) <
                   (timeline.tracks.firstIndex(where: { $0.id == track2.id }) ?? 0)
        }

        return activeClips
    }

    /// Composites multiple video clips into single frame
    private func compositeClips(_ clips: [Clip], at time: CMTime) -> CIImage? {
        var compositedImage: CIImage?

        for clip in clips {
            guard let frameImage = renderClipFrame(clip, at: time) else { continue }

            if compositedImage == nil {
                compositedImage = frameImage
            } else {
                compositedImage = compositeFrame(background: compositedImage!, foreground: frameImage, settings: clip.videoSettings)
            }
        }

        return compositedImage
    }

    /// Renders single clip frame with all effects applied
    private func renderClipFrame(_ clip: Clip, at time: CMTime) -> CIImage? {
        guard let sourceURL = clip.sourceURL else { return nil }

        // Calculate clip-relative time
        let clipStartTime = CMTime(value: clip.startPosition, timescale: CMTimeScale(timeline.sampleRate))
        let relativeTime = time - clipStartTime

        // Apply time stretch
        let stretchedTime = CMTimeMultiplyByFloat64(relativeTime, multiplier: Float64(1.0 / clip.timeStretchRatio))

        // Add source offset
        let sourceTime = stretchedTime + CMTime(value: clip.sourceOffset, timescale: CMTimeScale(timeline.sampleRate))

        // Check cache
        let cacheKey = "\(clip.id.uuidString)_\(sourceTime.seconds)"
        if let cachedFrame = frameCache[cacheKey] {
            return applyClipEffects(cachedFrame, clip: clip, time: relativeTime)
        }

        // Load frame from source
        guard let sourceFrame = loadFrame(from: sourceURL, at: sourceTime) else { return nil }

        // Cache frame
        cacheFrame(sourceFrame, key: cacheKey)

        // Apply effects
        return applyClipEffects(sourceFrame, clip: clip, time: relativeTime)
    }

    /// Loads single frame from video file
    private func loadFrame(from url: URL, at time: CMTime) -> CIImage? {
        let asset = AVURLAsset(url: url)

        guard let videoTrack = asset.tracks(withMediaType: .video).first else { return nil }

        // Create asset reader if needed
        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }

        do {
            try compositionTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: asset.duration),
                of: videoTrack,
                at: .zero
            )
        } catch {
            print("Error inserting video track: \(error)")
            return nil
        }

        // Create image generator
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return CIImage(cgImage: cgImage)
        } catch {
            print("Error generating frame: \(error)")
            return nil
        }
    }

    /// Applies all effects to clip frame
    private func applyClipEffects(_ frame: CIImage, clip: Clip, time: CMTime) -> CIImage {
        var processed = frame

        guard let settings = clip.videoSettings else { return processed }

        // Apply transform (scale, rotate, position)
        processed = applyTransform(processed, transform: settings.transform)

        // Apply color correction
        if let colorCorrection = settings.colorCorrection {
            processed = applyColorCorrection(processed, correction: colorCorrection)
        }

        // Apply chroma key
        if let chromaKey = settings.chromaKey, chromaKey.enabled {
            processed = applyChromaKey(processed, settings: chromaKey)
        }

        // Apply fade in/out
        let fadeMultiplier = calculateFade(clip: clip, time: time)
        let opacity = settings.opacity * fadeMultiplier

        if opacity < 1.0 {
            processed = processed.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity))
            ])
        }

        return processed
    }

    /// Applies geometric transform to frame
    private func applyTransform(_ image: CIImage, transform: VideoTransform) -> CIImage {
        var transformed = image

        // Scale
        if transform.scale != 1.0 {
            let scaleTransform = CGAffineTransform(scaleX: transform.scale, y: transform.scale)
            transformed = transformed.transformed(by: scaleTransform)
        }

        // Rotate
        if transform.rotation != 0 {
            let radians = transform.rotation * .pi / 180.0
            let rotateTransform = CGAffineTransform(rotationAngle: radians)
            transformed = transformed.transformed(by: rotateTransform)
        }

        // Translate
        if transform.position != .zero {
            let translateTransform = CGAffineTransform(translationX: transform.position.x, y: transform.position.y)
            transformed = transformed.transformed(by: translateTransform)
        }

        return transformed
    }

    /// Applies color correction
    private func applyColorCorrection(_ image: CIImage, correction: ColorCorrection) -> CIImage {
        var processed = image

        // Brightness & Contrast
        processed = processed.applyingFilter("CIColorControls", parameters: [
            "inputBrightness": correction.brightness,
            "inputContrast": correction.contrast,
            "inputSaturation": correction.saturation
        ])

        // Hue Adjust
        if correction.hue != 0 {
            let hueRadians = CGFloat(correction.hue) * .pi / 180.0
            processed = processed.applyingFilter("CIHueAdjust", parameters: [
                "inputAngle": hueRadians
            ])
        }

        return processed
    }

    /// Applies chroma key (green screen) effect
    private func applyChromaKey(_ image: CIImage, settings: ChromaKeySettings) -> CIImage {
        // CIChromaKeyBlend filter
        // Create mask based on key color
        let keyColor = CIColor(
            red: settings.keyColor.red,
            green: settings.keyColor.green,
            blue: settings.keyColor.blue
        )

        var processed = image

        // Custom chroma key implementation using color cube
        // (CoreImage doesn't have built-in chroma key, so we build one)
        let cubeData = createChromaKeyCube(
            keyColor: keyColor,
            threshold: CGFloat(settings.threshold),
            smoothness: CGFloat(settings.smoothness)
        )

        processed = processed.applyingFilter("CIColorCube", parameters: [
            "inputCubeDimension": 64,
            "inputCubeData": cubeData
        ])

        return processed
    }

    /// Creates color cube data for chroma key
    private func createChromaKeyCube(keyColor: CIColor, threshold: CGFloat, smoothness: CGFloat) -> Data {
        let size = 64
        var cubeData = [Float](repeating: 0, count: size * size * size * 4)

        var index = 0
        for blue in 0..<size {
            for green in 0..<size {
                for red in 0..<size {
                    let r = CGFloat(red) / CGFloat(size - 1)
                    let g = CGFloat(green) / CGFloat(size - 1)
                    let b = CGFloat(blue) / CGFloat(size - 1)

                    // Calculate distance from key color
                    let dr = r - keyColor.red
                    let dg = g - keyColor.green
                    let db = b - keyColor.blue
                    let distance = sqrt(dr*dr + dg*dg + db*db)

                    // Calculate alpha based on distance
                    var alpha: CGFloat = 1.0
                    if distance < threshold {
                        alpha = 0.0
                    } else if distance < threshold + smoothness {
                        // Smooth falloff
                        alpha = (distance - threshold) / smoothness
                    }

                    cubeData[index + 0] = Float(r)
                    cubeData[index + 1] = Float(g)
                    cubeData[index + 2] = Float(b)
                    cubeData[index + 3] = Float(alpha)

                    index += 4
                }
            }
        }

        return Data(bytes: &cubeData, count: cubeData.count * MemoryLayout<Float>.size)
    }

    /// Composites foreground over background with blend mode
    private func compositeFrame(background: CIImage, foreground: CIImage, settings: VideoClipSettings?) -> CIImage {
        let blendMode: String

        switch settings?.blendMode ?? .normal {
        case .normal:       blendMode = "CISourceOverCompositing"
        case .add:          blendMode = "CIAdditionCompositing"
        case .multiply:     blendMode = "CIMultiplyBlendMode"
        case .screen:       blendMode = "CIScreenBlendMode"
        case .overlay:      blendMode = "CIOverlayBlendMode"
        case .difference:   blendMode = "CIDifferenceBlendMode"
        }

        return foreground.applyingFilter(blendMode, parameters: [
            "inputBackgroundImage": background
        ])
    }

    /// Calculates fade multiplier for clip at given time
    private func calculateFade(clip: Clip, time: CMTime) -> Float {
        let timeSamples = time.convertScale(CMTimeScale(timeline.sampleRate), method: .default).value

        // Fade in
        if timeSamples < clip.fadeInDuration {
            return Float(timeSamples) / Float(clip.fadeInDuration)
        }

        // Fade out
        let clipDuration = clip.duration
        let fadeOutStart = clipDuration - clip.fadeOutDuration

        if timeSamples > fadeOutStart {
            let fadeOutProgress = timeSamples - fadeOutStart
            return 1.0 - (Float(fadeOutProgress) / Float(clip.fadeOutDuration))
        }

        return 1.0
    }

    // MARK: - Cache Management
    private func cacheFrame(_ frame: CIImage, key: String) {
        // Limit cache size
        if frameCache.count >= maxCacheSize {
            // Remove oldest (first) entry
            if let firstKey = frameCache.keys.first {
                frameCache.removeValue(forKey: firstKey)
            }
        }

        frameCache[key] = frame
    }

    private func clearCache() {
        frameCache.removeAll()
    }

    // MARK: - Track Management
    private func updateVideoTracks() {
        videoTracks = timeline.tracks.filter { track in
            track.type == .video || track.clips.contains(where: { $0.type == .video })
        }
    }

    // MARK: - Export
    /// Exports video timeline to file
    func exportVideo(to url: URL, resolution: VideoResolution, frameRate: Int, completion: @escaping (Bool, Error?) -> Void) {
        // Create export composition
        guard let composition = createComposition() else {
            completion(false, NSError(domain: "VideoPlaybackEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create composition"]))
            return
        }

        // Create export session
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(false, NSError(domain: "VideoPlaybackEngine", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"]))
            return
        }

        exportSession.outputURL = url
        exportSession.outputFileType = .mp4

        // Set video composition if we have effects
        if let videoComposition = createVideoComposition(for: composition, resolution: resolution, frameRate: frameRate) {
            exportSession.videoComposition = videoComposition
        }

        // Export
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    completion(true, nil)
                case .failed:
                    completion(false, exportSession.error)
                case .cancelled:
                    completion(false, NSError(domain: "VideoPlaybackEngine", code: -3, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]))
                default:
                    completion(false, NSError(domain: "VideoPlaybackEngine", code: -4, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
                }
            }
        }
    }

    /// Creates AVComposition from timeline
    private func createComposition() -> AVMutableComposition? {
        let composition = AVMutableComposition()

        // Add video tracks
        for (index, track) in videoTracks.enumerated() {
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { continue }

            // Add clips to track
            for clip in track.clips {
                guard clip.type == .video, let sourceURL = clip.sourceURL else { continue }

                let asset = AVURLAsset(url: sourceURL)
                guard let videoTrack = asset.tracks(withMediaType: .video).first else { continue }

                let startTime = CMTime(value: clip.startPosition, timescale: CMTimeScale(timeline.sampleRate))
                let duration = CMTime(value: clip.duration, timescale: CMTimeScale(timeline.sampleRate))
                let sourceStart = CMTime(value: clip.sourceOffset, timescale: CMTimeScale(timeline.sampleRate))

                do {
                    try compositionTrack.insertTimeRange(
                        CMTimeRange(start: sourceStart, duration: duration),
                        of: videoTrack,
                        at: startTime
                    )
                } catch {
                    print("Error inserting clip \(clip.name): \(error)")
                }
            }
        }

        return composition
    }

    /// Creates video composition with effects
    private func createVideoComposition(for composition: AVComposition, resolution: VideoResolution, frameRate: Int) -> AVMutableVideoComposition? {
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = resolution.size
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))

        // TODO: Add layer instructions for effects
        // This would apply all our clip effects during export

        return videoComposition
    }
}

// MARK: - Supporting Types

enum VideoResolution {
    case hd720, hd1080, uhd4K, uhd8K, custom(width: Int, height: Int)

    var size: CGSize {
        switch self {
        case .hd720:    return CGSize(width: 1280, height: 720)
        case .hd1080:   return CGSize(width: 1920, height: 1080)
        case .uhd4K:    return CGSize(width: 3840, height: 2160)
        case .uhd8K:    return CGSize(width: 7680, height: 4320)
        case .custom(let width, let height):
            return CGSize(width: width, height: height)
        }
    }

    var name: String {
        switch self {
        case .hd720:    return "720p"
        case .hd1080:   return "1080p"
        case .uhd4K:    return "4K"
        case .uhd8K:    return "8K"
        case .custom(let w, let h): return "\(w)x\(h)"
        }
    }
}

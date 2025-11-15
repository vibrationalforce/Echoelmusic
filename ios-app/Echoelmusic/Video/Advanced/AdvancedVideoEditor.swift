import Foundation
import AVFoundation
import CoreImage
import Metal
import MetalKit
import Combine

// MARK: - Advanced Multi-Track Video Editor
// Professional video editing with keyframe animation, color grading, and advanced effects

/// Advanced Video Editor - Multi-track timeline with professional features
@MainActor
class AdvancedVideoEditor: ObservableObject {

    // MARK: - Published Properties
    @Published var videoTracks: [VideoTrack] = []
    @Published var currentTime: CMTime = .zero
    @Published var duration: CMTime = .zero
    @Published var selectedClips: Set<UUID> = []
    @Published var isPlaying = false
    @Published var playbackRate: Float = 1.0
    @Published var resolution: CGSize = CGSize(width: 1920, height: 1080)
    @Published var frameRate: Double = 30.0

    // MARK: - Composition
    private var composition: AVMutableComposition?
    private var videoComposition: AVMutableVideoComposition?
    private var audioMix: AVMutableAudioMix?
    private var playerItem: AVPlayerItem?
    private var player: AVPlayer?

    // MARK: - Rendering
    private var metalDevice: MTLDevice?
    private var ciContext: CIContext?
    private var commandQueue: MTLCommandQueue?

    // MARK: - Init
    init() {
        setupMetal()
    }

    private func setupMetal() {
        metalDevice = MTLCreateSystemDefaultDevice()
        if let device = metalDevice {
            ciContext = CIContext(mtlDevice: device)
            commandQueue = device.makeCommandQueue()
        }
    }

    // MARK: - Track Management
    func addVideoTrack(name: String = "Video Track") -> VideoTrack {
        let track = VideoTrack(
            id: UUID(),
            name: name,
            index: videoTracks.count,
            clips: [],
            compositeMode: .normal,
            opacity: 1.0,
            transform: .identity,
            isVisible: true,
            isLocked: false
        )
        videoTracks.append(track)
        return track
    }

    func removeTrack(_ trackID: UUID) {
        videoTracks.removeAll { $0.id == trackID }
        rebuildComposition()
    }

    func moveTrack(from: Int, to: Int) {
        guard from >= 0 && from < videoTracks.count &&
              to >= 0 && to < videoTracks.count else { return }

        let track = videoTracks.remove(at: from)
        videoTracks.insert(track, at: to)

        // Update indices
        for i in 0..<videoTracks.count {
            videoTracks[i].index = i
        }

        rebuildComposition()
    }

    // MARK: - Clip Management
    func addClip(_ clip: VideoClip, to trackID: UUID) {
        guard let trackIndex = videoTracks.firstIndex(where: { $0.id == trackID }) else { return }

        videoTracks[trackIndex].clips.append(clip)
        videoTracks[trackIndex].clips.sort { $0.startTime < $1.startTime }

        updateDuration()
        rebuildComposition()
    }

    func removeClip(_ clipID: UUID) {
        for i in 0..<videoTracks.count {
            videoTracks[i].clips.removeAll { $0.id == clipID }
        }

        updateDuration()
        rebuildComposition()
    }

    func moveClip(_ clipID: UUID, toTime time: CMTime) {
        for i in 0..<videoTracks.count {
            if let clipIndex = videoTracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                videoTracks[i].clips[clipIndex].startTime = time
                videoTracks[i].clips.sort { $0.startTime < $1.startTime }
                rebuildComposition()
                return
            }
        }
    }

    func trimClip(_ clipID: UUID, start: CMTime, duration: CMTime) {
        for i in 0..<videoTracks.count {
            if let clipIndex = videoTracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                videoTracks[i].clips[clipIndex].sourceStart = start
                videoTracks[i].clips[clipIndex].duration = duration
                rebuildComposition()
                return
            }
        }
    }

    func splitClip(_ clipID: UUID, at time: CMTime) {
        for i in 0..<videoTracks.count {
            if let clipIndex = videoTracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                let clip = videoTracks[i].clips[clipIndex]

                // Calculate split position
                let relativeTime = CMTimeSubtract(time, clip.startTime)
                guard relativeTime > .zero && relativeTime < clip.duration else { return }

                // Create two new clips
                let clip1Duration = relativeTime
                let clip2Start = CMTimeAdd(clip.startTime, relativeTime)
                let clip2Duration = CMTimeSubtract(clip.duration, relativeTime)
                let clip2SourceStart = CMTimeAdd(clip.sourceStart, relativeTime)

                var clip1 = clip
                clip1.id = UUID()
                clip1.duration = clip1Duration

                var clip2 = clip
                clip2.id = UUID()
                clip2.startTime = clip2Start
                clip2.duration = clip2Duration
                clip2.sourceStart = clip2SourceStart

                // Replace original with split clips
                videoTracks[i].clips[clipIndex] = clip1
                videoTracks[i].clips.insert(clip2, at: clipIndex + 1)

                rebuildComposition()
                return
            }
        }
    }

    // MARK: - Keyframe Animation
    func addKeyframe(_ keyframe: Keyframe, to clipID: UUID, for property: AnimatableProperty) {
        for i in 0..<videoTracks.count {
            if let clipIndex = videoTracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                videoTracks[i].clips[clipIndex].keyframes[property, default: []].append(keyframe)
                videoTracks[i].clips[clipIndex].keyframes[property]?.sort { $0.time < $1.time }
                rebuildComposition()
                return
            }
        }
    }

    func removeKeyframe(_ keyframeID: UUID, from clipID: UUID, for property: AnimatableProperty) {
        for i in 0..<videoTracks.count {
            if let clipIndex = videoTracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                videoTracks[i].clips[clipIndex].keyframes[property]?.removeAll { $0.id == keyframeID }
                rebuildComposition()
                return
            }
        }
    }

    func interpolateValue(for property: AnimatableProperty, in clip: VideoClip, at time: CMTime) -> Any? {
        guard let keyframes = clip.keyframes[property], !keyframes.isEmpty else {
            return nil
        }

        // Find surrounding keyframes
        let relativeTime = CMTimeSubtract(time, clip.startTime)
        let seconds = CMTimeGetSeconds(relativeTime)

        var before: Keyframe?
        var after: Keyframe?

        for keyframe in keyframes {
            if keyframe.time <= seconds {
                before = keyframe
            } else if keyframe.time > seconds && after == nil {
                after = keyframe
                break
            }
        }

        // Interpolate
        if let b = before, let a = after {
            let t = (seconds - b.time) / (a.time - b.time)
            return interpolate(from: b.value, to: a.value, progress: Float(t), curve: b.interpolation)
        } else if let b = before {
            return b.value
        } else if let a = after {
            return a.value
        }

        return nil
    }

    private func interpolate(from: KeyframeValue, to: KeyframeValue, progress: Float, curve: InterpolationCurve) -> Any? {
        let p = applyCurve(progress, curve: curve)

        switch (from, to) {
        case (.float(let a), .float(let b)):
            return a + (b - a) * p

        case (.point(let a), .point(let b)):
            return CGPoint(
                x: a.x + (b.x - a.x) * CGFloat(p),
                y: a.y + (b.y - a.y) * CGFloat(p)
            )

        case (.size(let a), .size(let b)):
            return CGSize(
                width: a.width + (b.width - a.width) * CGFloat(p),
                height: a.height + (b.height - a.height) * CGFloat(p)
            )

        case (.color(let a), .color(let b)):
            return CIColor(
                red: a.red + (b.red - a.red) * CGFloat(p),
                green: a.green + (b.green - a.green) * CGFloat(p),
                blue: a.blue + (b.blue - a.blue) * CGFloat(p),
                alpha: a.alpha + (b.alpha - a.alpha) * CGFloat(p)
            )

        case (.transform(let a), .transform(let b)):
            // Decompose and interpolate
            return interpolateTransform(from: a, to: b, progress: CGFloat(p))

        default:
            return from
        }
    }

    private func applyCurve(_ t: Float, curve: InterpolationCurve) -> Float {
        switch curve {
        case .linear:
            return t

        case .easeIn:
            return t * t

        case .easeOut:
            return t * (2.0 - t)

        case .easeInOut:
            return t < 0.5 ? 2.0 * t * t : -1.0 + (4.0 - 2.0 * t) * t

        case .bezier(let cp1, let cp2):
            // Cubic Bezier interpolation
            let t2 = t * t
            let t3 = t2 * t
            let mt = 1.0 - t
            let mt2 = mt * mt
            let mt3 = mt2 * mt

            return mt3 * 0.0 + 3.0 * mt2 * t * cp1 + 3.0 * mt * t2 * cp2 + t3 * 1.0
        }
    }

    private func interpolateTransform(from: CGAffineTransform, to: CGAffineTransform, progress: CGFloat) -> CGAffineTransform {
        // Decompose transforms
        let fromDecomp = decomposeTransform(from)
        let toDecomp = decomposeTransform(to)

        // Interpolate components
        let scale = CGPoint(
            x: fromDecomp.scale.x + (toDecomp.scale.x - fromDecomp.scale.x) * progress,
            y: fromDecomp.scale.y + (toDecomp.scale.y - fromDecomp.scale.y) * progress
        )

        let rotation = fromDecomp.rotation + (toDecomp.rotation - fromDecomp.rotation) * progress

        let translation = CGPoint(
            x: fromDecomp.translation.x + (toDecomp.translation.x - fromDecomp.translation.x) * progress,
            y: fromDecomp.translation.y + (toDecomp.translation.y - fromDecomp.translation.y) * progress
        )

        // Recompose
        return CGAffineTransform.identity
            .scaledBy(x: scale.x, y: scale.y)
            .rotated(by: rotation)
            .translatedBy(x: translation.x, y: translation.y)
    }

    private func decomposeTransform(_ transform: CGAffineTransform) -> (scale: CGPoint, rotation: CGFloat, translation: CGPoint) {
        let translation = CGPoint(x: transform.tx, y: transform.ty)
        let scale = CGPoint(
            x: sqrt(transform.a * transform.a + transform.c * transform.c),
            y: sqrt(transform.b * transform.b + transform.d * transform.d)
        )
        let rotation = atan2(transform.b, transform.a)

        return (scale, rotation, translation)
    }

    // MARK: - Effects & Color Grading
    func applyColorGrading(_ grading: ColorGrading, to clipID: UUID) {
        for i in 0..<videoTracks.count {
            if let clipIndex = videoTracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                videoTracks[i].clips[clipIndex].colorGrading = grading
                rebuildComposition()
                return
            }
        }
    }

    func applyEffect(_ effect: VideoEffect, to clipID: UUID) {
        for i in 0..<videoTracks.count {
            if let clipIndex = videoTracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                videoTracks[i].clips[clipIndex].effects.append(effect)
                rebuildComposition()
                return
            }
        }
    }

    func removeEffect(_ effectID: UUID, from clipID: UUID) {
        for i in 0..<videoTracks.count {
            if let clipIndex = videoTracks[i].clips.firstIndex(where: { $0.id == clipID }) {
                videoTracks[i].clips[clipIndex].effects.removeAll { $0.id == effectID }
                rebuildComposition()
                return
            }
        }
    }

    // MARK: - Composition Building
    private func rebuildComposition() {
        composition = AVMutableComposition()
        videoComposition = AVMutableVideoComposition()

        guard let composition = composition,
              let videoComposition = videoComposition else { return }

        // Set composition properties
        videoComposition.renderSize = resolution
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))

        // Add video tracks
        for (index, track) in videoTracks.enumerated() where track.isVisible {
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { continue }

            for clip in track.clips {
                addClipToComposition(clip, compositionTrack: compositionTrack, trackIndex: index)
            }
        }

        // Create video composition with instructions
        createVideoCompositionInstructions()

        // Update player
        if let player = player {
            let newPlayerItem = AVPlayerItem(asset: composition)
            newPlayerItem.videoComposition = videoComposition
            player.replaceCurrentItem(with: newPlayerItem)
        }
    }

    private func addClipToComposition(_ clip: VideoClip, compositionTrack: AVMutableCompositionTrack, trackIndex: Int) {
        guard let asset = clip.asset else { return }

        let timeRange = CMTimeRange(start: clip.sourceStart, duration: clip.duration)

        do {
            try compositionTrack.insertTimeRange(
                timeRange,
                of: asset.tracks(withMediaType: .video)[0],
                at: clip.startTime
            )
        } catch {
            print("Failed to insert clip: \(error)")
        }
    }

    private func createVideoCompositionInstructions() {
        guard let videoComposition = videoComposition,
              let composition = composition else { return }

        var instructions: [AVMutableVideoCompositionInstruction] = []

        // Create instructions for each time range
        var currentTime = CMTime.zero

        while currentTime < duration {
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: currentTime, duration: CMTime(value: 1, timescale: CMTimeScale(frameRate)))

            // Create layer instructions for each visible track
            var layerInstructions: [AVMutableVideoCompositionLayerInstruction] = []

            for (index, track) in videoTracks.enumerated() where track.isVisible {
                if let compositionTrack = composition.tracks(withMediaType: .video).first(where: { $0.trackID == Int32(index + 1) }) {
                    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)

                    // Apply transform
                    layerInstruction.setTransform(track.transform, at: currentTime)

                    // Apply opacity
                    layerInstruction.setOpacity(track.opacity, at: currentTime)

                    layerInstructions.append(layerInstruction)
                }
            }

            instruction.layerInstructions = layerInstructions
            instructions.append(instruction)

            currentTime = CMTimeAdd(currentTime, CMTime(value: 1, timescale: CMTimeScale(frameRate)))
        }

        videoComposition.instructions = instructions
    }

    // MARK: - Playback
    func play() {
        if player == nil {
            setupPlayer()
        }

        player?.play()
        player?.rate = playbackRate
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        currentTime = .zero
        isPlaying = false
    }

    func seek(to time: CMTime) {
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    private func setupPlayer() {
        guard let composition = composition,
              let videoComposition = videoComposition else { return }

        playerItem = AVPlayerItem(asset: composition)
        playerItem?.videoComposition = videoComposition

        player = AVPlayer(playerItem: playerItem)
    }

    // MARK: - Export
    func export(to url: URL, preset: ExportPreset) async throws {
        guard let composition = composition,
              let videoComposition = videoComposition else {
            throw VideoEditorError.compositionNotReady
        }

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: preset.avPresetName
        ) else {
            throw VideoEditorError.exportFailed
        }

        exportSession.outputURL = url
        exportSession.outputFileType = preset.fileType
        exportSession.videoComposition = videoComposition

        await exportSession.export()

        if let error = exportSession.error {
            throw error
        }
    }

    // MARK: - Utility
    private func updateDuration() {
        var maxTime = CMTime.zero

        for track in videoTracks {
            for clip in track.clips {
                let endTime = CMTimeAdd(clip.startTime, clip.duration)
                if CMTimeCompare(endTime, maxTime) > 0 {
                    maxTime = endTime
                }
            }
        }

        duration = maxTime
    }
}

// MARK: - Video Track
struct VideoTrack: Identifiable {
    var id: UUID
    var name: String
    var index: Int
    var clips: [VideoClip]
    var compositeMode: CompositeMode
    var opacity: Float
    var transform: CGAffineTransform
    var isVisible: Bool
    var isLocked: Bool

    enum CompositeMode {
        case normal, multiply, screen, overlay, add
    }
}

// MARK: - Video Clip
struct VideoClip: Identifiable {
    var id: UUID
    var name: String
    var asset: AVAsset?
    var startTime: CMTime
    var duration: CMTime
    var sourceStart: CMTime
    var transform: CGAffineTransform
    var opacity: Float
    var colorGrading: ColorGrading?
    var effects: [VideoEffect]
    var keyframes: [AnimatableProperty: [Keyframe]]
    var transition: ClipTransition?
}

// MARK: - Color Grading
struct ColorGrading: Codable {
    var temperature: Float  // -1 to 1
    var tint: Float         // -1 to 1
    var exposure: Float     // -2 to 2
    var contrast: Float     // 0 to 2
    var highlights: Float   // -1 to 1
    var shadows: Float      // -1 to 1
    var whites: Float       // -1 to 1
    var blacks: Float       // -1 to 1
    var saturation: Float   // 0 to 2
    var vibrance: Float     // -1 to 1
    var lut: String?        // LUT file name
}

// MARK: - Video Effect
struct VideoEffect: Identifiable {
    var id: UUID
    var type: EffectType
    var parameters: [String: Float]
    var enabled: Bool

    enum EffectType: String {
        case blur, sharpen, glow, bloom
        case vignette, grain, chromatic
        case pixelate, mosaic, distortion
        case colorCorrection, hueShift
        case edgeDetect, emboss, oil
    }
}

// MARK: - Keyframe Animation
struct Keyframe: Identifiable {
    var id: UUID
    var time: Double  // seconds relative to clip start
    var value: KeyframeValue
    var interpolation: InterpolationCurve
}

enum KeyframeValue: Codable {
    case float(Float)
    case point(CGPoint)
    case size(CGSize)
    case color(CIColor)
    case transform(CGAffineTransform)
}

enum InterpolationCurve {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case bezier(cp1: Float, cp2: Float)
}

enum AnimatableProperty: String, Hashable {
    case position, scale, rotation, opacity
    case brightness, contrast, saturation
    case cropRect, blur, glow
}

// MARK: - Transitions
struct ClipTransition {
    var type: TransitionType
    var duration: CMTime

    enum TransitionType {
        case dissolve, wipe(direction: WipeDirection), push(direction: PushDirection)
        case fade, zoom, spin
    }

    enum WipeDirection {
        case left, right, up, down
    }

    enum PushDirection {
        case left, right, up, down
    }
}

// MARK: - Export Presets
struct ExportPreset {
    var name: String
    var resolution: CGSize
    var frameRate: Double
    var videoBitrate: Int  // kbps
    var audioBitrate: Int  // kbps
    var codec: VideoCodec
    var fileType: AVFileType

    enum VideoCodec: String {
        case h264, h265, prores, prores422, prores4444
    }

    var avPresetName: String {
        switch codec {
        case .h264:
            return AVAssetExportPresetHEVCHighestQuality
        case .h265:
            return AVAssetExportPresetHEVC3840x2160
        default:
            return AVAssetExportPresetHighestQuality
        }
    }

    // Common presets
    static let youtube4K = ExportPreset(
        name: "YouTube 4K",
        resolution: CGSize(width: 3840, height: 2160),
        frameRate: 60,
        videoBitrate: 50000,
        audioBitrate: 320,
        codec: .h264,
        fileType: .mp4
    )

    static let youtube1080p = ExportPreset(
        name: "YouTube 1080p",
        resolution: CGSize(width: 1920, height: 1080),
        frameRate: 60,
        videoBitrate: 12000,
        audioBitrate: 192,
        codec: .h264,
        fileType: .mp4
    )

    static let instagram = ExportPreset(
        name: "Instagram",
        resolution: CGSize(width: 1080, height: 1920),
        frameRate: 30,
        videoBitrate: 8000,
        audioBitrate: 192,
        codec: .h264,
        fileType: .mp4
    )

    static let proresProxy = ExportPreset(
        name: "ProRes Proxy",
        resolution: CGSize(width: 1920, height: 1080),
        frameRate: 30,
        videoBitrate: 45000,
        audioBitrate: 256,
        codec: .prores,
        fileType: .mov
    )
}

// MARK: - Errors
enum VideoEditorError: Error {
    case compositionNotReady
    case exportFailed
    case invalidClip
    case trackNotFound
}

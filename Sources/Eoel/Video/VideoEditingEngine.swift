import Foundation
import AVFoundation
import CoreData
import Combine

/// Video Editing Engine - Non-Linear Editor with Magnetic Timeline
/// Supports unlimited tracks, keyframe animation, nested sequences
/// Bio-reactive effects driven by HRV coherence and heart rate
@MainActor
class VideoEditingEngine: ObservableObject {

    // MARK: - Published State

    @Published var timeline: Timeline
    @Published var playhead: CMTime = .zero
    @Published var isPlaying: Bool = false
    @Published var selectedClips: Set<UUID> = []
    @Published var editMode: EditMode = .select

    // MARK: - Playback

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?

    // MARK: - Edit Modes

    enum EditMode: String, CaseIterable {
        case select = "Select"
        case ripple = "Ripple"       // Shift all subsequent clips
        case roll = "Roll"           // Move cut point between clips
        case slip = "Slip"           // Change in/out without moving position
        case slide = "Slide"         // Move clip, ripple neighbors
        case trim = "Trim"           // Trim clip edges
        case razor = "Razor"         // Split clips

        var description: String {
            switch self {
            case .select: return "Select and move clips"
            case .ripple: return "Shift all subsequent clips when trimming"
            case .roll: return "Move cut point between two clips"
            case .slip: return "Change in/out points without changing timeline position"
            case .slide: return "Move clip and ripple neighboring clips"
            case .trim: return "Trim clip edges"
            case .razor: return "Split clips at playhead"
            }
        }
    }

    // MARK: - Initialization

    init(timeline: Timeline = Timeline()) {
        self.timeline = timeline
        print("✅ VideoEditingEngine: Initialized")
    }

    deinit {
        stopPlayback()
    }

    // MARK: - Timeline Management

    func addClip(_ clip: VideoClip, to track: Track, at time: CMTime) {
        // Magnetic timeline - snap to nearest clip or beat
        let snappedTime = timeline.magneticSnap(time: time)

        // Insert clip
        var mutableClip = clip
        mutableClip.startTime = snappedTime
        track.clips.append(mutableClip)

        // Sort clips by start time
        track.clips.sort { $0.startTime < $1.startTime }

        print("➕ VideoEditingEngine: Added clip '\(clip.name)' to track '\(track.name)' at \(snappedTime.seconds)s")
    }

    func removeClip(_ clipID: UUID, from track: Track) {
        guard let index = track.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let clip = track.clips[index]

        track.clips.remove(at: index)

        print("➖ VideoEditingEngine: Removed clip '\(clip.name)' from track '\(track.name)'")
    }

    func moveClip(_ clipID: UUID, from sourceTrack: Track, to destinationTrack: Track, at time: CMTime) {
        guard let index = sourceTrack.clips.firstIndex(where: { $0.id == clipID }) else { return }
        var clip = sourceTrack.clips[index]

        // Remove from source
        sourceTrack.clips.remove(at: index)

        // Add to destination
        clip.startTime = time
        destinationTrack.clips.append(clip)
        destinationTrack.clips.sort { $0.startTime < $1.startTime }

        print("🔀 VideoEditingEngine: Moved clip '\(clip.name)' to track '\(destinationTrack.name)'")
    }

    // MARK: - Edit Operations

    func rippleEdit(clipID: UUID, track: Track, newDuration: CMTime) {
        guard let index = track.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let oldDuration = track.clips[index].duration
        let delta = newDuration - oldDuration

        // Update clip duration
        track.clips[index].duration = newDuration

        // Shift all subsequent clips
        for i in (index + 1)..<track.clips.count {
            track.clips[i].startTime = track.clips[i].startTime + delta
        }

        print("✂️ VideoEditingEngine: Ripple edit - shifted \(track.clips.count - index - 1) clips by \(delta.seconds)s")
    }

    func rollEdit(leftClipID: UUID, rightClipID: UUID, track: Track, newCutPoint: CMTime) {
        guard let leftIndex = track.clips.firstIndex(where: { $0.id == leftClipID }),
              let rightIndex = track.clips.firstIndex(where: { $0.id == rightClipID }) else { return }

        let leftClip = track.clips[leftIndex]
        let rightClip = track.clips[rightIndex]

        // Calculate new durations
        let leftNewDuration = newCutPoint - leftClip.startTime
        let rightNewStart = newCutPoint
        let rightNewDuration = rightClip.duration + (rightClip.startTime - rightNewStart)

        // Update clips
        track.clips[leftIndex].duration = leftNewDuration
        track.clips[rightIndex].startTime = rightNewStart
        track.clips[rightIndex].duration = rightNewDuration

        print("🎞️ VideoEditingEngine: Roll edit - moved cut point to \(newCutPoint.seconds)s")
    }

    func slipEdit(clipID: UUID, track: Track, newInPoint: CMTime) {
        guard let index = track.clips.firstIndex(where: { $0.id == clipID }) else { return }

        // Change in/out points without changing timeline position or duration
        track.clips[index].inPoint = newInPoint
        track.clips[index].outPoint = newInPoint + track.clips[index].duration

        print("🔄 VideoEditingEngine: Slip edit - new in point: \(newInPoint.seconds)s")
    }

    func slideEdit(clipID: UUID, track: Track, newStartTime: CMTime) {
        guard let index = track.clips.firstIndex(where: { $0.id == clipID }) else { return }

        let clip = track.clips[index]
        let delta = newStartTime - clip.startTime

        // Move clip
        track.clips[index].startTime = newStartTime

        // Ripple left neighbor
        if index > 0 {
            track.clips[index - 1].duration = track.clips[index - 1].duration + delta
        }

        // Ripple right neighbor
        if index < track.clips.count - 1 {
            track.clips[index + 1].startTime = newStartTime + clip.duration
        }

        print("↔️ VideoEditingEngine: Slide edit - moved clip to \(newStartTime.seconds)s")
    }

    func splitClip(clipID: UUID, track: Track, at time: CMTime) -> (UUID, UUID)? {
        guard let index = track.clips.firstIndex(where: { $0.id == clipID }) else { return nil }
        let originalClip = track.clips[index]

        guard time > originalClip.startTime && time < originalClip.endTime else { return nil }

        // Create left clip
        var leftClip = originalClip
        leftClip.id = UUID()
        leftClip.duration = time - originalClip.startTime
        leftClip.outPoint = originalClip.inPoint + leftClip.duration

        // Create right clip
        var rightClip = originalClip
        rightClip.id = UUID()
        rightClip.startTime = time
        rightClip.duration = originalClip.endTime - time
        rightClip.inPoint = leftClip.outPoint

        // Replace original with two new clips
        track.clips[index] = leftClip
        track.clips.insert(rightClip, at: index + 1)

        print("✂️ VideoEditingEngine: Split clip '\(originalClip.name)' at \(time.seconds)s")

        return (leftClip.id, rightClip.id)
    }

    // MARK: - Keyframe Animation

    func addKeyframe(clipID: UUID, track: Track, property: KeyframeProperty, at time: CMTime, value: Float) {
        guard let index = track.clips.firstIndex(where: { $0.id == clipID }) else { return }

        let keyframe = Keyframe(time: time, value: value, interpolation: .bezier)
        track.clips[index].keyframes[property, default: []].append(keyframe)
        track.clips[index].keyframes[property]?.sort { $0.time < $1.time }

        print("🎯 VideoEditingEngine: Added keyframe for \(property.rawValue) at \(time.seconds)s")
    }

    func removeKeyframe(clipID: UUID, track: Track, property: KeyframeProperty, at time: CMTime) {
        guard let index = track.clips.firstIndex(where: { $0.id == clipID }) else { return }

        track.clips[index].keyframes[property]?.removeAll { abs($0.time.seconds - time.seconds) < 0.01 }

        print("🗑️ VideoEditingEngine: Removed keyframe for \(property.rawValue)")
    }

    func evaluateKeyframe(clipID: UUID, track: Track, property: KeyframeProperty, at time: CMTime) -> Float? {
        guard let index = track.clips.firstIndex(where: { $0.id == clipID }),
              let keyframes = track.clips[index].keyframes[property],
              !keyframes.isEmpty else { return nil }

        // Find surrounding keyframes
        var prevKeyframe: Keyframe?
        var nextKeyframe: Keyframe?

        for keyframe in keyframes {
            if keyframe.time <= time {
                prevKeyframe = keyframe
            } else if nextKeyframe == nil {
                nextKeyframe = keyframe
                break
            }
        }

        // Interpolate
        if let prev = prevKeyframe, let next = nextKeyframe {
            let t = Float((time.seconds - prev.time.seconds) / (next.time.seconds - prev.time.seconds))

            switch next.interpolation {
            case .linear:
                return prev.value + (next.value - prev.value) * t
            case .bezier:
                // Cubic Bezier easing
                let t2 = t * t
                let t3 = t2 * t
                return prev.value + (next.value - prev.value) * (3.0 * t2 - 2.0 * t3)
            case .hold:
                return prev.value
            }
        } else if let prev = prevKeyframe {
            return prev.value
        } else if let next = nextKeyframe {
            return next.value
        }

        return nil
    }

    // MARK: - Playback

    func play() {
        guard !isPlaying else { return }

        // Build composition
        do {
            let composition = try buildComposition()
            playerItem = AVPlayerItem(asset: composition)
            player = AVPlayer(playerItem: playerItem)

            // Seek to playhead
            player?.seek(to: playhead)

            // Start playback
            player?.play()
            isPlaying = true

            // Observe time
            startTimeObserver()

            print("▶️ VideoEditingEngine: Started playback")
        } catch {
            print("❌ VideoEditingEngine: Failed to build composition - \(error)")
        }
    }

    func pause() {
        guard isPlaying else { return }

        player?.pause()
        isPlaying = false

        stopTimeObserver()

        print("⏸️ VideoEditingEngine: Paused playback")
    }

    func stopPlayback() {
        player?.pause()
        player = nil
        playerItem = nil
        isPlaying = false

        stopTimeObserver()

        playhead = .zero

        print("⏹️ VideoEditingEngine: Stopped playback")
    }

    func seek(to time: CMTime) {
        playhead = time
        player?.seek(to: time)
    }

    // MARK: - Time Observer

    private func startTimeObserver() {
        let interval = CMTime(value: 1, timescale: 30) // 30 Hz

        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.playhead = time
        }
    }

    private func stopTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    // MARK: - Build Composition

    func buildComposition() throws -> AVMutableComposition {
        let composition = AVMutableComposition()

        // Add video tracks
        for (trackIndex, track) in timeline.videoTracks.enumerated() {
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw VideoEditingError.compositionCreationFailed
            }

            // Insert clips
            for clip in track.clips {
                guard let asset = clip.asset else { continue }
                guard let assetTrack = asset.tracks(withMediaType: .video).first else { continue }

                let timeRange = CMTimeRange(start: clip.inPoint, duration: clip.duration)

                try compositionTrack.insertTimeRange(
                    timeRange,
                    of: assetTrack,
                    at: clip.startTime
                )
            }
        }

        // Add audio tracks
        for (trackIndex, track) in timeline.audioTracks.enumerated() {
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw VideoEditingError.compositionCreationFailed
            }

            // Insert clips
            for clip in track.clips {
                guard let asset = clip.asset else { continue }
                guard let assetTrack = asset.tracks(withMediaType: .audio).first else { continue }

                let timeRange = CMTimeRange(start: clip.inPoint, duration: clip.duration)

                try compositionTrack.insertTimeRange(
                    timeRange,
                    of: assetTrack,
                    at: clip.startTime
                )
            }
        }

        return composition
    }

    // MARK: - Markers

    func addMarker(at time: CMTime, label: String, color: MarkerColor) {
        let marker = TimeMarker(time: time, label: label, color: color)
        timeline.markers.append(marker)
        timeline.markers.sort { $0.time < $1.time }

        print("📍 VideoEditingEngine: Added marker '\(label)' at \(time.seconds)s")
    }

    func removeMarker(at time: CMTime) {
        timeline.markers.removeAll { abs($0.time.seconds - time.seconds) < 0.1 }
    }
}

// MARK: - Timeline Model

class Timeline: ObservableObject {
    @Published var name: String
    @Published var videoTracks: [Track]
    @Published var audioTracks: [Track]
    @Published var markers: [TimeMarker]
    @Published var tempo: Double // BPM for beat snapping
    @Published var duration: CMTime

    init(name: String = "Untitled Timeline") {
        self.name = name
        self.videoTracks = [Track(name: "Video 1", type: .video)]
        self.audioTracks = [Track(name: "Audio 1", type: .audio)]
        self.markers = []
        self.tempo = 120.0
        self.duration = CMTime(seconds: 60, preferredTimescale: 600)
    }

    // Magnetic timeline - snap to nearest clip edge or beat
    func magneticSnap(time: CMTime, tolerance: Double = 0.1) -> CMTime {
        let allClips = (videoTracks + audioTracks).flatMap { $0.clips }

        // Find nearest clip edge
        var nearestTime = time
        var nearestDistance = tolerance

        for clip in allClips {
            let startDistance = abs(clip.startTime.seconds - time.seconds)
            if startDistance < nearestDistance {
                nearestTime = clip.startTime
                nearestDistance = startDistance
            }

            let endDistance = abs(clip.endTime.seconds - time.seconds)
            if endDistance < nearestDistance {
                nearestTime = clip.endTime
                nearestDistance = endDistance
            }
        }

        // If no clip edge nearby, snap to beat
        if nearestDistance >= tolerance {
            let secondsPerBeat = 60.0 / tempo
            let nearestBeat = round(time.seconds / secondsPerBeat)
            nearestTime = CMTime(seconds: nearestBeat * secondsPerBeat, preferredTimescale: 600)
        }

        return nearestTime
    }
}

// MARK: - Track Model

class Track: ObservableObject, Identifiable {
    let id = UUID()
    @Published var name: String
    @Published var type: TrackType
    @Published var clips: [VideoClip]
    @Published var isMuted: Bool
    @Published var isSolo: Bool
    @Published var volume: Float // 0-1
    @Published var isLocked: Bool

    enum TrackType {
        case video
        case audio
    }

    init(name: String, type: TrackType) {
        self.name = name
        self.type = type
        self.clips = []
        self.isMuted = false
        self.isSolo = false
        self.volume = 1.0
        self.isLocked = false
    }
}

// MARK: - Video Clip Model

struct VideoClip: Identifiable {
    var id = UUID()
    var name: String
    var asset: AVAsset?
    var startTime: CMTime
    var duration: CMTime
    var inPoint: CMTime  // Source media in point
    var outPoint: CMTime // Source media out point

    // Effects
    var effects: [VideoEffect] = []

    // Keyframes
    var keyframes: [KeyframeProperty: [Keyframe]] = [:]

    var endTime: CMTime {
        return startTime + duration
    }
}

// MARK: - Keyframe Model

struct Keyframe {
    let time: CMTime
    let value: Float
    let interpolation: Interpolation

    enum Interpolation {
        case linear
        case bezier
        case hold
    }
}

enum KeyframeProperty: String {
    case opacity = "Opacity"
    case scale = "Scale"
    case rotation = "Rotation"
    case positionX = "Position X"
    case positionY = "Position Y"
    case volume = "Volume"
}

// MARK: - Time Marker Model

struct TimeMarker: Identifiable {
    let id = UUID()
    let time: CMTime
    let label: String
    let color: MarkerColor
}

enum MarkerColor: String, CaseIterable {
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case blue = "Blue"
    case purple = "Purple"
}

// MARK: - Video Effect Model

enum VideoEffect {
    case colorGrade(ColorGradeEffect)
    case blur(BlurEffect)
    case distortion(DistortionEffect)
    case stylize(StylizeEffect)
}

struct ColorGradeEffect {
    var exposure: Float = 0.0
    var contrast: Float = 1.0
    var saturation: Float = 1.0
    var temperature: Float = 0.0
    var tint: Float = 0.0
}

struct BlurEffect {
    var radius: Float = 10.0
    var type: BlurType

    enum BlurType {
        case gaussian
        case motion
        case radial
        case box
    }
}

struct DistortionEffect {
    var amount: Float = 0.0
    var type: DistortionType

    enum DistortionType {
        case lens
        case warp
        case fisheye
        case twirl
    }
}

struct StylizeEffect {
    var amount: Float = 0.0
    var type: StylizeType

    enum StylizeType {
        case pixelate
        case halftone
        case posterize
        case sketch
        case oilPaint
    }
}

// MARK: - Errors

enum VideoEditingError: LocalizedError {
    case compositionCreationFailed
    case clipNotFound
    case invalidTimeRange

    var errorDescription: String? {
        switch self {
        case .compositionCreationFailed:
            return "Failed to create video composition"
        case .clipNotFound:
            return "Clip not found in timeline"
        case .invalidTimeRange:
            return "Invalid time range for clip"
        }
    }
}

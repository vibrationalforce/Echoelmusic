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

    // MARK: - Undo/Redo Integration
    private let undoManager = UndoRedoManager.shared

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
        log.video("✅ VideoEditingEngine: Initialized with Undo/Redo support")
    }

    // MARK: - Undo/Redo Convenience Methods

    /// Undo last action (Cmd+Z)
    func undo() {
        undoManager.undo()
    }

    /// Redo last undone action (Cmd+Shift+Z)
    func redo() {
        undoManager.redo()
    }

    /// Whether undo is available
    var canUndo: Bool {
        undoManager.canUndo
    }

    /// Whether redo is available
    var canRedo: Bool {
        undoManager.canRedo
    }

    /// Name of action that will be undone
    var undoActionName: String {
        undoManager.undoActionName
    }

    /// Name of action that will be redone
    var redoActionName: String {
        undoManager.redoActionName
    }

    // MARK: - Computed Properties for Views

    /// Video clips from all video tracks (as EditorVideoClip for timeline display)
    var videoClips: [EditorVideoClip] {
        timeline.videoTracks.flatMap { track in
            track.clips.map { clip in
                EditorVideoClip(
                    name: clip.name,
                    startTime: clip.startTime.seconds,
                    duration: clip.duration.seconds
                )
            }
        }
    }

    /// Audio clips from all audio tracks (as EditorVideoClip for timeline display)
    var audioClips: [EditorVideoClip] {
        timeline.audioTracks.flatMap { track in
            track.clips.map { clip in
                EditorVideoClip(
                    name: clip.name,
                    startTime: clip.startTime.seconds,
                    duration: clip.duration.seconds
                )
            }
        }
    }

    /// Total timeline duration in seconds
    var duration: TimeInterval {
        timeline.duration.seconds
    }

    /// Current project name (nil if no clips loaded)
    var currentProject: String? {
        let hasClips = timeline.videoTracks.contains(where: { !$0.clips.isEmpty }) ||
                       timeline.audioTracks.contains(where: { !$0.clips.isEmpty })
        return hasClips ? timeline.name : nil
    }

    deinit {
        player?.pause()
        player = nil
        playerItem = nil
    }

    // MARK: - Timeline Management

    func addClip(_ clip: VideoClip, to track: VideoTrack, at time: CMTime) {
        // Magnetic timeline - snap to nearest clip or beat
        let snappedTime = timeline.magneticSnap(time: time)

        // Create undoable command
        let command = VideoClipCommand(
            operation: .add,
            clipData: (clip: clip, trackID: track.id, time: snappedTime),
            execute_: { [weak self, weak track] in
                guard let track = track else { return }
                var mutableClip = clip
                mutableClip.startTime = snappedTime
                track.clips.append(mutableClip)
                track.clips.sort { $0.startTime < $1.startTime }
            },
            undo_: { [weak track] in
                guard let track = track else { return }
                track.clips.removeAll { $0.id == clip.id }
            }
        )

        undoManager.execute(command)
        log.video("➕ VideoEditingEngine: Added clip '\(clip.name)' to track '\(track.name)' at \(snappedTime.seconds)s")
    }

    func removeClip(_ clipID: UUID, from track: VideoTrack) {
        guard let index = track.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let clip = track.clips[index]
        let clipIndex = index

        // Create undoable command
        let command = VideoClipCommand(
            operation: .delete,
            clipData: (clip: clip, trackID: track.id, index: clipIndex),
            execute_: { [weak track] in
                guard let track = track else { return }
                track.clips.removeAll { $0.id == clipID }
            },
            undo_: { [weak track] in
                guard let track = track else { return }
                track.clips.insert(clip, at: min(clipIndex, track.clips.count))
                track.clips.sort { $0.startTime < $1.startTime }
            }
        )

        undoManager.execute(command)
        log.video("➖ VideoEditingEngine: Removed clip '\(clip.name)' from track '\(track.name)'")
    }

    func moveClip(_ clipID: UUID, from sourceTrack: VideoTrack, to destinationTrack: VideoTrack, at time: CMTime) {
        guard let index = sourceTrack.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let clip = sourceTrack.clips[index]
        let originalTime = clip.startTime
        let originalIndex = index

        // Create undoable command
        let command = VideoClipCommand(
            operation: .move,
            clipData: (clip: clip, sourceTrackID: sourceTrack.id, destTrackID: destinationTrack.id, time: time),
            execute_: { [weak sourceTrack, weak destinationTrack] in
                guard let sourceTrack = sourceTrack, let destinationTrack = destinationTrack else { return }
                sourceTrack.clips.removeAll { $0.id == clipID }
                var movedClip = clip
                movedClip.startTime = time
                destinationTrack.clips.append(movedClip)
                destinationTrack.clips.sort { $0.startTime < $1.startTime }
            },
            undo_: { [weak sourceTrack, weak destinationTrack] in
                guard let sourceTrack = sourceTrack, let destinationTrack = destinationTrack else { return }
                destinationTrack.clips.removeAll { $0.id == clipID }
                var restoredClip = clip
                restoredClip.startTime = originalTime
                sourceTrack.clips.insert(restoredClip, at: min(originalIndex, sourceTrack.clips.count))
                sourceTrack.clips.sort { $0.startTime < $1.startTime }
            }
        )

        undoManager.execute(command)
        log.video("🔀 VideoEditingEngine: Moved clip '\(clip.name)' to track '\(destinationTrack.name)'")
    }

    // MARK: - Edit Operations

    func rippleEdit(clipID: UUID, track: VideoTrack, newDuration: CMTime) {
        guard let index = track.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let oldDuration = track.clips[index].duration
        let delta = newDuration - oldDuration

        // Update clip duration
        track.clips[index].duration = newDuration

        // Shift all subsequent clips
        for i in (index + 1)..<track.clips.count {
            track.clips[i].startTime = track.clips[i].startTime + delta
        }

        log.video("✂️ VideoEditingEngine: Ripple edit - shifted \(track.clips.count - index - 1) clips by \(delta.seconds)s")
    }

    func rollEdit(leftClipID: UUID, rightClipID: UUID, track: VideoTrack, newCutPoint: CMTime) {
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

        log.video("🎞️ VideoEditingEngine: Roll edit - moved cut point to \(newCutPoint.seconds)s")
    }

    func slipEdit(clipID: UUID, track: VideoTrack, newInPoint: CMTime) {
        guard let index = track.clips.firstIndex(where: { $0.id == clipID }) else { return }

        // Change in/out points without changing timeline position or duration
        track.clips[index].inPoint = newInPoint
        track.clips[index].outPoint = newInPoint + track.clips[index].duration

        log.video("🔄 VideoEditingEngine: Slip edit - new in point: \(newInPoint.seconds)s")
    }

    func slideEdit(clipID: UUID, track: VideoTrack, newStartTime: CMTime) {
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

        log.video("↔️ VideoEditingEngine: Slide edit - moved clip to \(newStartTime.seconds)s")
    }

    func splitClip(clipID: UUID, track: VideoTrack, at time: CMTime) -> (UUID, UUID)? {
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

        let leftID = leftClip.id
        let rightID = rightClip.id
        let originalIndex = index

        // Create undoable command
        let command = VideoClipCommand(
            operation: .split,
            clipData: (original: originalClip, left: leftClip, right: rightClip, trackID: track.id),
            execute_: { [weak track] in
                guard let track = track else { return }
                guard let idx = track.clips.firstIndex(where: { $0.id == originalClip.id }) else {
                    // Already split - use stored clips
                    return
                }
                track.clips[idx] = leftClip
                track.clips.insert(rightClip, at: idx + 1)
            },
            undo_: { [weak track] in
                guard let track = track else { return }
                track.clips.removeAll { $0.id == leftID || $0.id == rightID }
                track.clips.insert(originalClip, at: min(originalIndex, track.clips.count))
                track.clips.sort { $0.startTime < $1.startTime }
            }
        )

        undoManager.execute(command)
        log.video("✂️ VideoEditingEngine: Split clip '\(originalClip.name)' at \(time.seconds)s")

        return (leftID, rightID)
    }

    // MARK: - Keyframe Animation

    func addKeyframe(clipID: UUID, track: VideoTrack, property: KeyframeProperty, at time: CMTime, value: Float) {
        guard let index = track.clips.firstIndex(where: { $0.id == clipID }) else { return }

        let keyframe = Keyframe(time: time, value: value, interpolation: .bezier)
        track.clips[index].keyframes[property, default: []].append(keyframe)
        track.clips[index].keyframes[property]?.sort { $0.time < $1.time }

        log.video("🎯 VideoEditingEngine: Added keyframe for \(property.rawValue) at \(time.seconds)s")
    }

    func removeKeyframe(clipID: UUID, track: VideoTrack, property: KeyframeProperty, at time: CMTime) {
        guard let index = track.clips.firstIndex(where: { $0.id == clipID }) else { return }

        track.clips[index].keyframes[property]?.removeAll { abs($0.time.seconds - time.seconds) < 0.01 }

        log.video("🗑️ VideoEditingEngine: Removed keyframe for \(property.rawValue)")
    }

    func evaluateKeyframe(clipID: UUID, track: VideoTrack, property: KeyframeProperty, at time: CMTime) -> Float? {
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

    // MARK: - Live Color Grading

    /// Applies a live color grade from ProColorGrading to selected video clips.
    /// Called by the workspace bridge when the grading wheels change.
    func applyLiveGrade(_ grade: ColorGradeEffect) {
        let gradeEffect = VideoEffect.colorGrade(grade)

        for (trackIdx, track) in timeline.videoTracks.enumerated() {
            for (clipIdx, clip) in track.clips.enumerated() {
                guard selectedClips.contains(clip.id) else { continue }
                // Replace existing color grade or append
                var updatedEffects = clip.effects.filter {
                    if case .colorGrade = $0 { return false }
                    return true
                }
                updatedEffects.append(gradeEffect)
                timeline.videoTracks[trackIdx].clips[clipIdx].effects = updatedEffects
            }
        }
    }

    // MARK: - Playback

    func play() async {
        guard !isPlaying else { return }

        // Build composition
        do {
            let composition = try await buildComposition()
            playerItem = AVPlayerItem(asset: composition)
            player = AVPlayer(playerItem: playerItem)

            // Seek to playhead
            await player?.seek(to: playhead)

            // Start playback
            player?.play()
            isPlaying = true

            // Observe time
            startTimeObserver()

            log.video("▶️ VideoEditingEngine: Started playback")
        } catch {
            log.video("❌ VideoEditingEngine: Failed to build composition - \(error)", level: .error)
        }
    }

    func pause() {
        guard isPlaying else { return }

        player?.pause()
        isPlaying = false

        stopTimeObserver()

        log.video("⏸️ VideoEditingEngine: Paused playback")
    }

    func stopPlayback() {
        player?.pause()
        player = nil
        playerItem = nil
        isPlaying = false

        stopTimeObserver()

        playhead = .zero

        log.video("⏹️ VideoEditingEngine: Stopped playback")
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

    private func loadFirstTrack(from asset: AVAsset, mediaType: AVMediaType) async throws -> AVAssetTrack? {
        return try await asset.loadTracks(withMediaType: mediaType).first
    }

    func buildComposition() async throws -> AVMutableComposition {
        let composition = AVMutableComposition()

        // Add video tracks
        for (_, track) in timeline.videoTracks.enumerated() {
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw VideoEditingError.compositionCreationFailed
            }

            // Insert clips
            for clip in track.clips {
                guard let asset = clip.asset else { continue }
                guard let assetTrack = try? await loadFirstTrack(from: asset, mediaType: .video) else { continue }

                let timeRange = CMTimeRange(start: clip.inPoint, duration: clip.duration)

                try compositionTrack.insertTimeRange(
                    timeRange,
                    of: assetTrack,
                    at: clip.startTime
                )
            }
        }

        // Add audio tracks
        for (_, track) in timeline.audioTracks.enumerated() {
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw VideoEditingError.compositionCreationFailed
            }

            // Insert clips
            for clip in track.clips {
                guard let asset = clip.asset else { continue }
                guard let assetTrack = try? await loadFirstTrack(from: asset, mediaType: .audio) else { continue }

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

        log.video("📍 VideoEditingEngine: Added marker '\(label)' at \(time.seconds)s")
    }

    func removeMarker(at time: CMTime) {
        timeline.markers.removeAll { abs($0.time.seconds - time.seconds) < 0.1 }
    }
}

// MARK: - Timeline Model

class Timeline: ObservableObject {
    @Published var name: String
    @Published var videoTracks: [VideoTrack]
    @Published var audioTracks: [VideoTrack]
    @Published var markers: [TimeMarker]
    @Published var tempo: Double // BPM for beat snapping
    @Published var duration: CMTime
    @Published var textOverlays: [TextOverlay] = []

    init(name: String = "Untitled Timeline") {
        self.name = name
        self.videoTracks = [VideoTrack(name: "Video 1", type: .video)]
        self.audioTracks = [VideoTrack(name: "Audio 1", type: .audio)]
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

// MARK: - Video Track Model (renamed to avoid conflict with Recording/Track)

class VideoTrack: ObservableObject, Identifiable {
    let id = UUID()
    @Published var name: String
    @Published var type: VideoTrackType
    @Published var clips: [VideoClip]
    @Published var isMuted: Bool
    @Published var isSolo: Bool
    @Published var volume: Float // 0-1
    @Published var isLocked: Bool

    enum VideoTrackType {
        case video
        case audio
    }

    init(name: String, type: VideoTrackType) {
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

// MARK: - Text Overlay System (Titles, Captions, Lower Thirds)

/// Text overlay for video titles, captions, and lower thirds
struct TextOverlay: Identifiable {
    var id = UUID()
    var text: String
    var font: TextFont
    var color: CGColor
    var backgroundColor: CGColor?
    var position: CGPoint // Normalized 0-1
    var alignment: TextAlignment
    var startTime: CMTime
    var duration: CMTime
    var animation: TextAnimation?
    var style: TextStyle

    enum TextFont {
        case system(size: CGFloat, weight: FontWeight)
        case custom(name: String, size: CGFloat)

        enum FontWeight {
            case regular, medium, semibold, bold, heavy
        }
    }

    enum TextAlignment {
        case left, center, right
    }

    enum TextAnimation {
        case fadeIn(duration: Double)
        case fadeOut(duration: Double)
        case slideIn(from: Direction, duration: Double)
        case slideOut(to: Direction, duration: Double)
        case typewriter(charDelay: Double)
        case scale(from: CGFloat, to: CGFloat, duration: Double)
        case bounce

        enum Direction {
            case left, right, top, bottom
        }
    }

    struct TextStyle {
        var shadow: Shadow?
        var outline: Outline?
        var letterSpacing: CGFloat = 0
        var lineHeight: CGFloat = 1.2

        struct Shadow {
            var color: CGColor
            var offset: CGSize
            var blur: CGFloat
        }

        struct Outline {
            var color: CGColor
            var width: CGFloat
        }
    }
}

/// Text layer preset types
enum TextPreset: String, CaseIterable {
    case title = "Title"
    case subtitle = "Subtitle"
    case lowerThird = "Lower Third"
    case caption = "Caption"
    case endCredits = "End Credits"
    case callout = "Callout"
    case watermark = "Watermark"

    func createOverlay(text: String, at time: CMTime, duration: CMTime) -> TextOverlay {
        switch self {
        case .title:
            return TextOverlay(
                text: text,
                font: .system(size: 72, weight: .bold),
                color: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                backgroundColor: nil,
                position: CGPoint(x: 0.5, y: 0.5),
                alignment: .center,
                startTime: time,
                duration: duration,
                animation: .fadeIn(duration: 0.5),
                style: TextOverlay.TextStyle(
                    shadow: TextOverlay.TextStyle.Shadow(
                        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.5),
                        offset: CGSize(width: 2, height: 2),
                        blur: 4
                    ),
                    outline: nil
                )
            )
        case .subtitle:
            return TextOverlay(
                text: text,
                font: .system(size: 36, weight: .medium),
                color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.9),
                backgroundColor: nil,
                position: CGPoint(x: 0.5, y: 0.65),
                alignment: .center,
                startTime: time,
                duration: duration,
                animation: .fadeIn(duration: 0.3),
                style: TextOverlay.TextStyle()
            )
        case .lowerThird:
            return TextOverlay(
                text: text,
                font: .system(size: 28, weight: .semibold),
                color: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                backgroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 0.7),
                position: CGPoint(x: 0.05, y: 0.85),
                alignment: .left,
                startTime: time,
                duration: duration,
                animation: .slideIn(from: .left, duration: 0.4),
                style: TextOverlay.TextStyle()
            )
        case .caption:
            return TextOverlay(
                text: text,
                font: .system(size: 24, weight: .regular),
                color: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                backgroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 0.6),
                position: CGPoint(x: 0.5, y: 0.9),
                alignment: .center,
                startTime: time,
                duration: duration,
                animation: nil,
                style: TextOverlay.TextStyle()
            )
        case .endCredits:
            return TextOverlay(
                text: text,
                font: .system(size: 32, weight: .regular),
                color: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                backgroundColor: nil,
                position: CGPoint(x: 0.5, y: 1.2),
                alignment: .center,
                startTime: time,
                duration: duration,
                animation: .slideIn(from: .bottom, duration: duration.seconds),
                style: TextOverlay.TextStyle(lineHeight: 2.0)
            )
        case .callout:
            return TextOverlay(
                text: text,
                font: .system(size: 20, weight: .medium),
                color: CGColor(red: 0, green: 0, blue: 0, alpha: 1),
                backgroundColor: CGColor(red: 1, green: 0.8, blue: 0, alpha: 1),
                position: CGPoint(x: 0.5, y: 0.3),
                alignment: .center,
                startTime: time,
                duration: duration,
                animation: .scale(from: 0.8, to: 1.0, duration: 0.3),
                style: TextOverlay.TextStyle()
            )
        case .watermark:
            return TextOverlay(
                text: text,
                font: .system(size: 16, weight: .regular),
                color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.5),
                backgroundColor: nil,
                position: CGPoint(x: 0.95, y: 0.95),
                alignment: .right,
                startTime: .zero,
                duration: CMTime(seconds: 86400, preferredTimescale: 1), // All day
                animation: nil,
                style: TextOverlay.TextStyle()
            )
        }
    }
}

// MARK: - Text Overlay Extension for VideoEditingEngine

extension VideoEditingEngine {

    /// Add text overlay to timeline
    func addTextOverlay(_ overlay: TextOverlay) {
        timeline.textOverlays.append(overlay)
        log.video("📝 VideoEditingEngine: Added text overlay '\(overlay.text)' at \(overlay.startTime.seconds)s")
    }

    /// Add text overlay from preset
    func addTextFromPreset(_ preset: TextPreset, text: String, at time: CMTime, duration: CMTime) {
        let overlay = preset.createOverlay(text: text, at: time, duration: duration)
        addTextOverlay(overlay)
    }

    /// Remove text overlay
    func removeTextOverlay(id: UUID) {
        timeline.textOverlays.removeAll { $0.id == id }
    }

    /// Update text overlay
    func updateTextOverlay(id: UUID, newText: String) {
        if let index = timeline.textOverlays.firstIndex(where: { $0.id == id }) {
            timeline.textOverlays[index].text = newText
        }
    }
}

// Note: textOverlays property moved to main Timeline class definition

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

// VideoTimelineView.swift
// Echoelmusic - Professional Non-Linear Video Editor Timeline
// Rivals: DaVinci Resolve, Adobe Premiere Pro, Final Cut Pro

import SwiftUI
import AVFoundation
import Combine
import CoreImage
import Metal

// MARK: - Video Timeline Data Models

/// Represents a video clip on the timeline
struct VideoClip: Identifiable, Codable {
    let id: UUID
    var name: String
    var sourceURL: URL?
    var trackId: UUID
    var startTime: Double // seconds on timeline
    var inPoint: Double // source in point
    var outPoint: Double // source out point
    var duration: Double { outPoint - inPoint }
    var speed: Double = 1.0
    var isReversed: Bool = false
    var opacity: Float = 1.0
    var blendMode: BlendMode = .normal
    var transform: ClipTransform = ClipTransform()
    var effects: [VideoEffect] = []
    var audioEnabled: Bool = true
    var audioVolume: Float = 1.0
    var transitions: ClipTransitions = ClipTransitions()
    var color: Color = .blue

    enum BlendMode: String, Codable, CaseIterable {
        case normal = "Normal"
        case add = "Add"
        case multiply = "Multiply"
        case screen = "Screen"
        case overlay = "Overlay"
        case softLight = "Soft Light"
        case hardLight = "Hard Light"
        case difference = "Difference"
        case exclusion = "Exclusion"
        case colorDodge = "Color Dodge"
        case colorBurn = "Color Burn"
        case darken = "Darken"
        case lighten = "Lighten"
        case hue = "Hue"
        case saturation = "Saturation"
        case color = "Color"
        case luminosity = "Luminosity"
    }

    struct ClipTransform: Codable {
        var positionX: Double = 0
        var positionY: Double = 0
        var scaleX: Double = 1.0
        var scaleY: Double = 1.0
        var rotation: Double = 0 // degrees
        var anchorX: Double = 0.5
        var anchorY: Double = 0.5
    }

    struct ClipTransitions: Codable {
        var inTransition: Transition?
        var outTransition: Transition?

        struct Transition: Codable {
            var type: TransitionType
            var duration: Double
            var easing: EasingType

            enum TransitionType: String, Codable, CaseIterable {
                case cut = "Cut"
                case crossDissolve = "Cross Dissolve"
                case fade = "Fade"
                case wipe = "Wipe"
                case slide = "Slide"
                case push = "Push"
                case zoom = "Zoom"
                case iris = "Iris"
                case pageFlip = "Page Flip"
                case doorway = "Doorway"
                case cube = "Cube"
                case ripple = "Ripple"
                case swirl = "Swirl"
            }

            enum EasingType: String, Codable, CaseIterable {
                case linear = "Linear"
                case easeIn = "Ease In"
                case easeOut = "Ease Out"
                case easeInOut = "Ease In Out"
                case bounce = "Bounce"
                case elastic = "Elastic"
            }
        }
    }
}

/// Video effect applied to a clip
struct VideoEffect: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: EffectType
    var isEnabled: Bool = true
    var parameters: [String: Double]
    var keyframes: [Keyframe] = []

    enum EffectType: String, Codable, CaseIterable {
        // Color Correction
        case colorCorrection = "Color Correction"
        case curves = "Curves"
        case levels = "Levels"
        case hslSecondary = "HSL Secondary"
        case colorWheels = "Color Wheels"
        case lut = "LUT"

        // Blur & Sharpen
        case gaussianBlur = "Gaussian Blur"
        case motionBlur = "Motion Blur"
        case radialBlur = "Radial Blur"
        case zoomBlur = "Zoom Blur"
        case sharpen = "Sharpen"
        case unsharpMask = "Unsharp Mask"

        // Distortion
        case transform = "Transform"
        case warp = "Warp"
        case spherize = "Spherize"
        case twirl = "Twirl"
        case ripple = "Ripple"
        case wave = "Wave"
        case fishEye = "Fish Eye"
        case perspective = "Perspective"

        // Stylize
        case glow = "Glow"
        case vignette = "Vignette"
        case filmGrain = "Film Grain"
        case chromaticAberration = "Chromatic Aberration"
        case pixelate = "Pixelate"
        case posterize = "Posterize"
        case oilPaint = "Oil Paint"
        case sketch = "Sketch"
        case halftone = "Halftone"

        // Keying
        case chromaKey = "Chroma Key"
        case lumaKey = "Luma Key"
        case differenceKey = "Difference Key"

        // Generate
        case solidColor = "Solid Color"
        case gradient = "Gradient"
        case noise = "Noise"
        case fractalNoise = "Fractal Noise"

        // Time
        case echo = "Echo"
        case trails = "Trails"
        case timeRemap = "Time Remap"
    }

    struct Keyframe: Codable, Identifiable {
        let id: UUID
        var time: Double
        var value: Double
        var interpolation: InterpolationType

        enum InterpolationType: String, Codable {
            case linear
            case bezier
            case hold
        }
    }
}

/// Video track in the timeline
struct VideoTrack: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: TrackType
    var clips: [VideoClip]
    var isVisible: Bool = true
    var isLocked: Bool = false
    var isMuted: Bool = false
    var height: CGFloat = 60
    var opacity: Float = 1.0
    var blendMode: VideoClip.BlendMode = .normal

    enum TrackType: String, Codable {
        case video
        case audio
        case title
        case adjustment
        case composite
    }
}

/// Audio clip for audio tracks
struct AudioClip: Identifiable, Codable {
    let id: UUID
    var name: String
    var sourceURL: URL?
    var trackId: UUID
    var startTime: Double
    var inPoint: Double
    var outPoint: Double
    var duration: Double { outPoint - inPoint }
    var volume: Float = 1.0
    var pan: Float = 0
    var fadeIn: Double = 0
    var fadeOut: Double = 0
    var effects: [AudioEffectReference] = []
    var waveformData: [Float]?

    struct AudioEffectReference: Codable, Identifiable {
        let id: UUID
        var effectName: String
        var parameters: [String: Double]
    }
}

/// Title/Text overlay
struct TitleClip: Identifiable, Codable {
    let id: UUID
    var text: String
    var trackId: UUID
    var startTime: Double
    var duration: Double
    var font: String = "Helvetica Neue"
    var fontSize: CGFloat = 72
    var fontWeight: FontWeight = .bold
    var textColor: CodableColor = CodableColor(color: .white)
    var backgroundColor: CodableColor?
    var strokeColor: CodableColor?
    var strokeWidth: CGFloat = 0
    var shadowEnabled: Bool = false
    var shadowColor: CodableColor = CodableColor(color: .black)
    var shadowOffset: CGSize = CGSize(width: 2, height: 2)
    var shadowBlur: CGFloat = 4
    var alignment: TextAlignment = .center
    var position: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var animation: TitleAnimation?

    enum FontWeight: String, Codable, CaseIterable {
        case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
    }

    enum TextAlignment: String, Codable {
        case left, center, right
    }

    struct TitleAnimation: Codable {
        var inAnimation: AnimationType
        var outAnimation: AnimationType
        var inDuration: Double
        var outDuration: Double

        enum AnimationType: String, Codable, CaseIterable {
            case none = "None"
            case fade = "Fade"
            case slideLeft = "Slide Left"
            case slideRight = "Slide Right"
            case slideUp = "Slide Up"
            case slideDown = "Slide Down"
            case scale = "Scale"
            case typewriter = "Typewriter"
            case blur = "Blur"
            case bounce = "Bounce"
        }
    }
}

/// Codable color wrapper
struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(color: Color) {
        // Default white
        self.red = 1
        self.green = 1
        self.blue = 1
        self.alpha = 1
    }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

/// Timeline marker
struct TimelineMarker: Identifiable, Codable {
    let id: UUID
    var name: String
    var time: Double
    var color: CodableColor
    var type: MarkerType

    enum MarkerType: String, Codable {
        case standard
        case chapter
        case todo
        case note
    }
}

// MARK: - Video Timeline Engine

@MainActor
class VideoTimelineEngine: ObservableObject {
    // Timeline Data
    @Published var videoTracks: [VideoTrack] = []
    @Published var audioTracks: [VideoTrack] = []
    @Published var markers: [TimelineMarker] = []

    // Playback
    @Published var currentTime: Double = 0
    @Published var isPlaying: Bool = false
    @Published var playbackRate: Double = 1.0
    @Published var duration: Double = 60 // Total timeline duration

    // Selection
    @Published var selectedClipIds: Set<UUID> = []
    @Published var selectedTrackId: UUID?

    // View State
    @Published var horizontalZoom: Double = 100 // pixels per second
    @Published var verticalZoom: Double = 1.0
    @Published var scrollPosition: CGPoint = .zero
    @Published var isSnappingEnabled: Bool = true
    @Published var snapTolerance: Double = 0.1 // seconds

    // Edit Mode
    @Published var editMode: EditMode = .select
    @Published var rippleMode: Bool = false

    // Scopes
    @Published var showScopes: Bool = false
    @Published var scopeType: ScopeType = .waveform

    // Preview
    @Published var previewResolution: PreviewResolution = .full
    @Published var isProxyMode: Bool = false

    // Undo/Redo
    private var undoStack: [TimelineState] = []
    private var redoStack: [TimelineState] = []

    // Playback Timer
    private var displayLink: CADisplayLink?
    private var player: AVPlayer?

    enum EditMode: String, CaseIterable {
        case select = "Select"
        case blade = "Blade"
        case trim = "Trim"
        case slip = "Slip"
        case slide = "Slide"
        case roll = "Roll"
        case ripple = "Ripple"
        case timeStretch = "Time Stretch"
    }

    enum ScopeType: String, CaseIterable {
        case waveform = "Waveform"
        case vectorscope = "Vectorscope"
        case histogram = "Histogram"
        case parade = "RGB Parade"
    }

    enum PreviewResolution: String, CaseIterable {
        case full = "Full"
        case half = "1/2"
        case quarter = "1/4"
        case eighth = "1/8"
    }

    struct TimelineState: Codable {
        var videoTracks: [VideoTrack]
        var audioTracks: [VideoTrack]
        var markers: [TimelineMarker]
    }

    init() {
        setupDefaultTimeline()
    }

    private func setupDefaultTimeline() {
        // Create default video tracks
        videoTracks = [
            VideoTrack(id: UUID(), name: "V3 - Titles", type: .title, clips: []),
            VideoTrack(id: UUID(), name: "V2 - Overlay", type: .video, clips: []),
            VideoTrack(id: UUID(), name: "V1 - Main", type: .video, clips: createDemoClips()),
        ]

        // Create default audio tracks
        audioTracks = [
            VideoTrack(id: UUID(), name: "A1 - Dialogue", type: .audio, clips: []),
            VideoTrack(id: UUID(), name: "A2 - Music", type: .audio, clips: []),
            VideoTrack(id: UUID(), name: "A3 - SFX", type: .audio, clips: []),
        ]

        // Add some markers
        markers = [
            TimelineMarker(id: UUID(), name: "Intro", time: 0, color: CodableColor(red: 0, green: 1, blue: 0, alpha: 1), type: .chapter),
            TimelineMarker(id: UUID(), name: "Main Content", time: 15, color: CodableColor(red: 1, green: 1, blue: 0, alpha: 1), type: .chapter),
            TimelineMarker(id: UUID(), name: "Outro", time: 50, color: CodableColor(red: 1, green: 0, blue: 0, alpha: 1), type: .chapter),
        ]
    }

    private func createDemoClips() -> [VideoClip] {
        [
            VideoClip(id: UUID(), name: "Intro_v2.mov", sourceURL: nil, trackId: UUID(),
                     startTime: 0, inPoint: 0, outPoint: 10, color: .blue),
            VideoClip(id: UUID(), name: "Interview_A.mp4", sourceURL: nil, trackId: UUID(),
                     startTime: 10, inPoint: 5, outPoint: 35, color: .green),
            VideoClip(id: UUID(), name: "B-Roll_City.mp4", sourceURL: nil, trackId: UUID(),
                     startTime: 40, inPoint: 0, outPoint: 15, color: .orange),
        ]
    }

    // MARK: - Transport Controls

    func play() {
        isPlaying = true
        startPlaybackTimer()
    }

    func pause() {
        isPlaying = false
        stopPlaybackTimer()
    }

    func stop() {
        isPlaying = false
        currentTime = 0
        stopPlaybackTimer()
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seekTo(time: Double) {
        currentTime = max(0, min(duration, time))
    }

    func seekToStart() {
        currentTime = 0
    }

    func seekToEnd() {
        currentTime = duration
    }

    func seekForward(seconds: Double) {
        seekTo(time: currentTime + seconds)
    }

    func seekBackward(seconds: Double) {
        seekTo(time: currentTime - seconds)
    }

    func goToNextMarker() {
        let nextMarker = markers.first { $0.time > currentTime + 0.01 }
        if let marker = nextMarker {
            seekTo(time: marker.time)
        }
    }

    func goToPreviousMarker() {
        let previousMarker = markers.last { $0.time < currentTime - 0.01 }
        if let marker = previousMarker {
            seekTo(time: marker.time)
        }
    }

    func goToNextClip() {
        var nextClipStart: Double = duration
        for track in videoTracks {
            for clip in track.clips {
                if clip.startTime > currentTime + 0.01 {
                    nextClipStart = min(nextClipStart, clip.startTime)
                }
            }
        }
        if nextClipStart < duration {
            seekTo(time: nextClipStart)
        }
    }

    func goToPreviousClip() {
        var previousClipStart: Double = 0
        for track in videoTracks {
            for clip in track.clips {
                if clip.startTime < currentTime - 0.01 {
                    previousClipStart = max(previousClipStart, clip.startTime)
                }
            }
        }
        seekTo(time: previousClipStart)
    }

    private func startPlaybackTimer() {
        displayLink = CADisplayLink(target: self, selector: #selector(updatePlayhead))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopPlaybackTimer() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updatePlayhead() {
        guard isPlaying else { return }

        let deltaTime = (1.0 / 60.0) * playbackRate
        currentTime += deltaTime

        if currentTime >= duration {
            currentTime = duration
            pause()
        }
    }

    // MARK: - Track Management

    func addVideoTrack(name: String? = nil) {
        saveUndoState()
        let trackName = name ?? "V\(videoTracks.count + 1)"
        let newTrack = VideoTrack(id: UUID(), name: trackName, type: .video, clips: [])
        videoTracks.insert(newTrack, at: 0) // Insert at top
    }

    func addAudioTrack(name: String? = nil) {
        saveUndoState()
        let trackName = name ?? "A\(audioTracks.count + 1)"
        let newTrack = VideoTrack(id: UUID(), name: trackName, type: .audio, clips: [])
        audioTracks.append(newTrack)
    }

    func deleteTrack(_ trackId: UUID) {
        saveUndoState()
        videoTracks.removeAll { $0.id == trackId }
        audioTracks.removeAll { $0.id == trackId }
    }

    func toggleTrackVisibility(_ trackId: UUID) {
        if let index = videoTracks.firstIndex(where: { $0.id == trackId }) {
            videoTracks[index].isVisible.toggle()
        }
    }

    func toggleTrackLock(_ trackId: UUID) {
        if let index = videoTracks.firstIndex(where: { $0.id == trackId }) {
            videoTracks[index].isLocked.toggle()
        }
    }

    func toggleTrackMute(_ trackId: UUID) {
        if let index = videoTracks.firstIndex(where: { $0.id == trackId }) {
            videoTracks[index].isMuted.toggle()
        } else if let index = audioTracks.firstIndex(where: { $0.id == trackId }) {
            audioTracks[index].isMuted.toggle()
        }
    }

    // MARK: - Clip Management

    func addClip(to trackId: UUID, clip: VideoClip, at time: Double) {
        saveUndoState()

        var newClip = clip
        newClip.trackId = trackId
        newClip.startTime = snapToClip(time)

        if let index = videoTracks.firstIndex(where: { $0.id == trackId }) {
            videoTracks[index].clips.append(newClip)
            videoTracks[index].clips.sort { $0.startTime < $1.startTime }
        }
    }

    func moveClip(_ clipId: UUID, toTime: Double, toTrackId: UUID? = nil) {
        saveUndoState()

        // Find and remove clip
        var movedClip: VideoClip?
        for trackIndex in videoTracks.indices {
            if let clipIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                movedClip = videoTracks[trackIndex].clips.remove(at: clipIndex)
                break
            }
        }

        guard var clip = movedClip else { return }

        clip.startTime = snapToClip(toTime)
        let targetTrackId = toTrackId ?? clip.trackId
        clip.trackId = targetTrackId

        if let trackIndex = videoTracks.firstIndex(where: { $0.id == targetTrackId }) {
            videoTracks[trackIndex].clips.append(clip)
            videoTracks[trackIndex].clips.sort { $0.startTime < $1.startTime }
        }
    }

    func trimClip(_ clipId: UUID, newInPoint: Double? = nil, newOutPoint: Double? = nil) {
        saveUndoState()

        for trackIndex in videoTracks.indices {
            if let clipIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                if let inPoint = newInPoint {
                    let trimDelta = inPoint - videoTracks[trackIndex].clips[clipIndex].inPoint
                    videoTracks[trackIndex].clips[clipIndex].inPoint = inPoint
                    videoTracks[trackIndex].clips[clipIndex].startTime += trimDelta
                }
                if let outPoint = newOutPoint {
                    videoTracks[trackIndex].clips[clipIndex].outPoint = outPoint
                }
                break
            }
        }
    }

    func splitClip(_ clipId: UUID, at time: Double) {
        saveUndoState()

        for trackIndex in videoTracks.indices {
            if let clipIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                let originalClip = videoTracks[trackIndex].clips[clipIndex]
                let clipEndTime = originalClip.startTime + originalClip.duration

                guard time > originalClip.startTime && time < clipEndTime else { return }

                // Calculate split point in source
                let splitPointInSource = originalClip.inPoint + (time - originalClip.startTime)

                // Modify original clip (first half)
                videoTracks[trackIndex].clips[clipIndex].outPoint = splitPointInSource

                // Create second half
                var secondClip = originalClip
                secondClip.id = UUID()
                secondClip.inPoint = splitPointInSource
                secondClip.startTime = time
                secondClip.name += " (2)"

                videoTracks[trackIndex].clips.append(secondClip)
                videoTracks[trackIndex].clips.sort { $0.startTime < $1.startTime }
                break
            }
        }
    }

    func deleteClip(_ clipId: UUID) {
        saveUndoState()
        for trackIndex in videoTracks.indices {
            videoTracks[trackIndex].clips.removeAll { $0.id == clipId }
        }
        selectedClipIds.remove(clipId)
    }

    func deleteSelectedClips() {
        saveUndoState()
        for clipId in selectedClipIds {
            for trackIndex in videoTracks.indices {
                videoTracks[trackIndex].clips.removeAll { $0.id == clipId }
            }
        }
        selectedClipIds.removeAll()
    }

    func duplicateClip(_ clipId: UUID) {
        saveUndoState()

        for trackIndex in videoTracks.indices {
            if let clipIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                var newClip = videoTracks[trackIndex].clips[clipIndex]
                newClip.id = UUID()
                newClip.startTime = newClip.startTime + newClip.duration
                newClip.name += " (Copy)"
                videoTracks[trackIndex].clips.append(newClip)
                videoTracks[trackIndex].clips.sort { $0.startTime < $1.startTime }
                break
            }
        }
    }

    // MARK: - Speed/Time Operations

    func setClipSpeed(_ clipId: UUID, speed: Double) {
        saveUndoState()
        for trackIndex in videoTracks.indices {
            if let clipIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                videoTracks[trackIndex].clips[clipIndex].speed = speed
                break
            }
        }
    }

    func reverseClip(_ clipId: UUID) {
        saveUndoState()
        for trackIndex in videoTracks.indices {
            if let clipIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                videoTracks[trackIndex].clips[clipIndex].isReversed.toggle()
                break
            }
        }
    }

    func freezeFrame(at time: Double, duration: Double) {
        // Create a freeze frame clip at the specified time
        saveUndoState()
        // Implementation would create a still image from the frame
    }

    // MARK: - Effects

    func addEffect(to clipId: UUID, effect: VideoEffect) {
        saveUndoState()
        for trackIndex in videoTracks.indices {
            if let clipIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                videoTracks[trackIndex].clips[clipIndex].effects.append(effect)
                break
            }
        }
    }

    func removeEffect(from clipId: UUID, effectId: UUID) {
        saveUndoState()
        for trackIndex in videoTracks.indices {
            if let clipIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                videoTracks[trackIndex].clips[clipIndex].effects.removeAll { $0.id == effectId }
                break
            }
        }
    }

    func reorderEffects(for clipId: UUID, from: Int, to: Int) {
        saveUndoState()
        for trackIndex in videoTracks.indices {
            if let clipIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                let effect = videoTracks[trackIndex].clips[clipIndex].effects.remove(at: from)
                videoTracks[trackIndex].clips[clipIndex].effects.insert(effect, at: to)
                break
            }
        }
    }

    // MARK: - Transitions

    func addTransition(between clipAId: UUID, and clipBId: UUID, transition: VideoClip.ClipTransitions.Transition) {
        saveUndoState()

        for trackIndex in videoTracks.indices {
            if let clipAIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipAId }) {
                videoTracks[trackIndex].clips[clipAIndex].transitions.outTransition = transition
            }
            if let clipBIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipBId }) {
                videoTracks[trackIndex].clips[clipBIndex].transitions.inTransition = transition
            }
        }
    }

    // MARK: - Markers

    func addMarker(at time: Double, name: String, type: TimelineMarker.MarkerType = .standard) {
        saveUndoState()
        let marker = TimelineMarker(
            id: UUID(),
            name: name,
            time: snapToClip(time),
            color: CodableColor(red: 1, green: 1, blue: 0, alpha: 1),
            type: type
        )
        markers.append(marker)
        markers.sort { $0.time < $1.time }
    }

    func deleteMarker(_ markerId: UUID) {
        saveUndoState()
        markers.removeAll { $0.id == markerId }
    }

    // MARK: - Snapping

    func snapToClip(_ time: Double) -> Double {
        guard isSnappingEnabled else { return time }

        var nearestSnapPoint = time
        var minDistance = snapTolerance

        // Snap to playhead
        if abs(time - currentTime) < minDistance {
            nearestSnapPoint = currentTime
            minDistance = abs(time - currentTime)
        }

        // Snap to markers
        for marker in markers {
            if abs(time - marker.time) < minDistance {
                nearestSnapPoint = marker.time
                minDistance = abs(time - marker.time)
            }
        }

        // Snap to clip edges
        for track in videoTracks {
            for clip in track.clips {
                // Snap to start
                if abs(time - clip.startTime) < minDistance {
                    nearestSnapPoint = clip.startTime
                    minDistance = abs(time - clip.startTime)
                }
                // Snap to end
                let clipEnd = clip.startTime + clip.duration
                if abs(time - clipEnd) < minDistance {
                    nearestSnapPoint = clipEnd
                    minDistance = abs(time - clipEnd)
                }
            }
        }

        return nearestSnapPoint
    }

    // MARK: - Undo/Redo

    private func saveUndoState() {
        let state = TimelineState(
            videoTracks: videoTracks,
            audioTracks: audioTracks,
            markers: markers
        )
        undoStack.append(state)
        if undoStack.count > 100 {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    func undo() {
        guard let previousState = undoStack.popLast() else { return }
        let currentState = TimelineState(
            videoTracks: videoTracks,
            audioTracks: audioTracks,
            markers: markers
        )
        redoStack.append(currentState)

        videoTracks = previousState.videoTracks
        audioTracks = previousState.audioTracks
        markers = previousState.markers
    }

    func redo() {
        guard let nextState = redoStack.popLast() else { return }
        let currentState = TimelineState(
            videoTracks: videoTracks,
            audioTracks: audioTracks,
            markers: markers
        )
        undoStack.append(currentState)

        videoTracks = nextState.videoTracks
        audioTracks = nextState.audioTracks
        markers = nextState.markers
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Utilities

    func formatTimecode(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let frames = Int((seconds.truncatingRemainder(dividingBy: 1)) * 30) // Assuming 30fps
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, secs, frames)
    }

    func secondsToX(_ seconds: Double) -> CGFloat {
        CGFloat(seconds * horizontalZoom)
    }

    func xToSeconds(_ x: CGFloat) -> Double {
        Double(x) / horizontalZoom
    }

    func calculateDuration() {
        var maxEnd: Double = 0
        for track in videoTracks {
            for clip in track.clips {
                let clipEnd = clip.startTime + clip.duration
                maxEnd = max(maxEnd, clipEnd)
            }
        }
        duration = max(maxEnd, 60)
    }
}

// MARK: - Video Timeline View

struct VideoTimelineView: View {
    @StateObject private var engine = VideoTimelineEngine()
    @State private var showingEffectPicker = false
    @State private var selectedClipForEffects: UUID?

    private let trackHeaderWidth: CGFloat = 150
    private let rulerHeight: CGFloat = 40
    private let minimumTrackHeight: CGFloat = 50

    var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar
            videoToolbar

            // Preview + Timeline
            HSplitView {
                // Left: Preview & Inspector
                VStack(spacing: 0) {
                    previewPanel
                    inspectorPanel
                }
                .frame(minWidth: 400)

                // Right: Timeline
                VStack(spacing: 0) {
                    // Timeline Content
                    HStack(spacing: 0) {
                        // Track Headers
                        trackHeaders

                        // Timeline Grid
                        timelineGrid
                    }

                    // Audio Waveform / Scopes
                    if engine.showScopes {
                        scopesPanel
                    }
                }
            }
        }
        .background(Color(white: 0.1))
    }

    // MARK: - Toolbar

    private var videoToolbar: some View {
        HStack(spacing: 12) {
            // Edit Mode
            Picker("Mode", selection: $engine.editMode) {
                ForEach(VideoTimelineEngine.EditMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 400)

            Divider().frame(height: 30)

            // Snapping
            Toggle(isOn: $engine.isSnappingEnabled) {
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
            }
            .toggleStyle(.button)
            .help("Snapping")

            // Ripple Mode
            Toggle(isOn: $engine.rippleMode) {
                Image(systemName: "arrow.left.arrow.right")
            }
            .toggleStyle(.button)
            .help("Ripple Edit")

            Divider().frame(height: 30)

            // Transport
            transportControls

            Spacer()

            // Undo/Redo
            Button(action: engine.undo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!engine.canUndo)

            Button(action: engine.redo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!engine.canRedo)

            Divider().frame(height: 30)

            // Zoom
            HStack(spacing: 4) {
                Button(action: { engine.horizontalZoom = max(10, engine.horizontalZoom * 0.8) }) {
                    Image(systemName: "minus.magnifyingglass")
                }

                Slider(value: $engine.horizontalZoom, in: 10...500)
                    .frame(width: 100)

                Button(action: { engine.horizontalZoom = min(500, engine.horizontalZoom * 1.25) }) {
                    Image(systemName: "plus.magnifyingglass")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.15))
    }

    private var transportControls: some View {
        HStack(spacing: 8) {
            Button(action: engine.seekToStart) {
                Image(systemName: "backward.end.fill")
            }

            Button(action: engine.goToPreviousClip) {
                Image(systemName: "backward.frame.fill")
            }

            Button(action: engine.togglePlayback) {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
            }
            .frame(width: 40)

            Button(action: engine.goToNextClip) {
                Image(systemName: "forward.frame.fill")
            }

            Button(action: engine.seekToEnd) {
                Image(systemName: "forward.end.fill")
            }

            // Timecode Display
            Text(engine.formatTimecode(engine.currentTime))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 100)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black)
                .cornerRadius(4)
        }
        .foregroundColor(.white)
    }

    // MARK: - Preview Panel

    private var previewPanel: some View {
        VStack(spacing: 0) {
            // Preview Header
            HStack {
                Text("PREVIEW")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)

                Spacer()

                // Resolution Picker
                Picker("", selection: $engine.previewResolution) {
                    ForEach(VideoTimelineEngine.PreviewResolution.allCases, id: \.self) { res in
                        Text(res.rawValue).tag(res)
                    }
                }
                .frame(width: 60)

                // Toggle Proxy
                Toggle(isOn: $engine.isProxyMode) {
                    Text("Proxy")
                        .font(.system(size: 10))
                }
                .toggleStyle(.button)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(white: 0.12))

            // Preview Area
            ZStack {
                Color.black

                // Video preview would go here
                Text("Preview")
                    .foregroundColor(.gray)

                // Safe Areas Overlay
                Rectangle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    .padding(20)
            }
            .aspectRatio(16/9, contentMode: .fit)
        }
    }

    // MARK: - Inspector Panel

    private var inspectorPanel: some View {
        VStack(spacing: 0) {
            // Inspector Header
            HStack {
                Text("INSPECTOR")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(white: 0.12))

            // Inspector Content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if engine.selectedClipIds.count == 1,
                       let clipId = engine.selectedClipIds.first {
                        clipInspector(clipId: clipId)
                    } else if engine.selectedClipIds.isEmpty {
                        Text("No selection")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        Text("\(engine.selectedClipIds.count) clips selected")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                .padding()
            }
        }
        .frame(maxHeight: 300)
    }

    @ViewBuilder
    private func clipInspector(clipId: UUID) -> some View {
        // Find the clip
        var foundClip: VideoClip?
        for track in engine.videoTracks {
            if let clip = track.clips.first(where: { $0.id == clipId }) {
                foundClip = clip
                break
            }
        }

        if let clip = foundClip {
            VStack(alignment: .leading, spacing: 16) {
                // Clip Info
                Group {
                    Text("CLIP INFO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)

                    TextField("Name", text: .constant(clip.name))
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Text("Duration:")
                        Spacer()
                        Text(engine.formatTimecode(clip.duration))
                            .foregroundColor(.white)
                    }
                    .font(.system(size: 12))
                }

                Divider()

                // Transform
                Group {
                    Text("TRANSFORM")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)

                    HStack {
                        Text("Position")
                        Spacer()
                        Text("X: \(Int(clip.transform.positionX)) Y: \(Int(clip.transform.positionY))")
                    }

                    HStack {
                        Text("Scale")
                        Spacer()
                        Text("\(Int(clip.transform.scaleX * 100))%")
                    }

                    HStack {
                        Text("Rotation")
                        Spacer()
                        Text("\(Int(clip.transform.rotation))°")
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(.gray)

                Divider()

                // Speed
                Group {
                    Text("SPEED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)

                    HStack {
                        Text("Speed")
                        Spacer()
                        Text("\(Int(clip.speed * 100))%")
                    }

                    Toggle("Reverse", isOn: .constant(clip.isReversed))
                }
                .font(.system(size: 12))

                Divider()

                // Effects
                Group {
                    HStack {
                        Text("EFFECTS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)

                        Spacer()

                        Button(action: {
                            selectedClipForEffects = clipId
                            showingEffectPicker = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }

                    ForEach(clip.effects) { effect in
                        HStack {
                            Toggle(isOn: .constant(effect.isEnabled)) {
                                Text(effect.name)
                            }
                            Spacer()
                            Button(action: {
                                engine.removeEffect(from: clipId, effectId: effect.id)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        .font(.system(size: 12))
                    }
                }
            }
        }
    }

    // MARK: - Track Headers

    private var trackHeaders: some View {
        VStack(spacing: 0) {
            // Ruler spacer
            Rectangle()
                .fill(Color(white: 0.12))
                .frame(height: rulerHeight)

            // Video Track Headers
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 1) {
                    ForEach(engine.videoTracks) { track in
                        VideoTrackHeader(track: track, engine: engine)
                            .frame(height: track.height * engine.verticalZoom)
                    }

                    // Separator
                    Rectangle()
                        .fill(Color.orange)
                        .frame(height: 2)

                    // Audio Track Headers
                    ForEach(engine.audioTracks) { track in
                        VideoTrackHeader(track: track, engine: engine)
                            .frame(height: track.height * engine.verticalZoom)
                    }
                }
            }

            // Add Track Buttons
            HStack {
                Button(action: { engine.addVideoTrack() }) {
                    Label("+ Video", systemImage: "film")
                        .font(.system(size: 10))
                }

                Button(action: { engine.addAudioTrack() }) {
                    Label("+ Audio", systemImage: "waveform")
                        .font(.system(size: 10))
                }
            }
            .padding(.vertical, 8)
            .foregroundColor(.gray)
        }
        .frame(width: trackHeaderWidth)
        .background(Color(white: 0.12))
    }

    // MARK: - Timeline Grid

    private var timelineGrid: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    // Grid Background
                    timelineBackground(width: max(geometry.size.width, engine.duration * engine.horizontalZoom))

                    // Clips
                    clipsLayer

                    // Markers
                    markersLayer

                    // Playhead
                    playheadView
                }
                .frame(
                    width: max(geometry.size.width, engine.duration * engine.horizontalZoom + 200),
                    height: totalTracksHeight + rulerHeight
                )
            }

            // Ruler overlay
            VStack {
                timelineRuler(width: geometry.size.width)
                Spacer()
            }
        }
    }

    private var totalTracksHeight: CGFloat {
        let videoHeight = engine.videoTracks.reduce(0) { $0 + $1.height * engine.verticalZoom }
        let audioHeight = engine.audioTracks.reduce(0) { $0 + $1.height * engine.verticalZoom }
        return videoHeight + audioHeight + 2 // +2 for separator
    }

    private func timelineBackground(width: CGFloat) -> some View {
        Canvas { context, size in
            // Draw time grid
            let secondWidth = engine.horizontalZoom
            let totalSeconds = Int(width / secondWidth) + 1

            for second in 0...totalSeconds {
                let x = CGFloat(second) * secondWidth
                let isMajor = second % 10 == 0
                let isMinor = second % 5 == 0

                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: rulerHeight))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(isMajor ? Color(white: 0.35) : isMinor ? Color(white: 0.25) : Color(white: 0.15)),
                    lineWidth: isMajor ? 1 : 0.5
                )
            }

            // Draw track separators
            var yOffset = rulerHeight
            for track in engine.videoTracks {
                yOffset += track.height * engine.verticalZoom
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: yOffset))
                        path.addLine(to: CGPoint(x: size.width, y: yOffset))
                    },
                    with: .color(Color(white: 0.2)),
                    lineWidth: 1
                )
            }

            // Video/Audio separator
            context.fill(
                Path(CGRect(x: 0, y: yOffset, width: size.width, height: 2)),
                with: .color(Color.orange.opacity(0.5))
            )
            yOffset += 2

            for track in engine.audioTracks {
                yOffset += track.height * engine.verticalZoom
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: yOffset))
                        path.addLine(to: CGPoint(x: size.width, y: yOffset))
                    },
                    with: .color(Color(white: 0.2)),
                    lineWidth: 1
                )
            }
        }
        .background(Color(white: 0.08))
    }

    private var clipsLayer: some View {
        VStack(spacing: 1) {
            Rectangle().fill(Color.clear).frame(height: rulerHeight)

            ForEach(engine.videoTracks) { track in
                ZStack(alignment: .leading) {
                    ForEach(track.clips) { clip in
                        VideoClipView(
                            clip: clip,
                            engine: engine,
                            trackHeight: track.height * engine.verticalZoom
                        )
                        .offset(x: engine.secondsToX(clip.startTime))
                    }
                }
                .frame(height: track.height * engine.verticalZoom)
                .opacity(track.isVisible ? 1 : 0.3)
            }

            Rectangle().fill(Color.orange.opacity(0.5)).frame(height: 2)

            ForEach(engine.audioTracks) { track in
                ZStack(alignment: .leading) {
                    // Audio clips would go here
                }
                .frame(height: track.height * engine.verticalZoom)
            }
        }
    }

    private var markersLayer: some View {
        ForEach(engine.markers) { marker in
            VStack(spacing: 0) {
                // Marker flag
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: marker.color.red, green: marker.color.green, blue: marker.color.blue))

                // Marker line
                Rectangle()
                    .fill(Color(red: marker.color.red, green: marker.color.green, blue: marker.color.blue).opacity(0.5))
                    .frame(width: 1, height: totalTracksHeight)
            }
            .offset(x: engine.secondsToX(marker.time) - 5, y: 5)
        }
    }

    private var playheadView: some View {
        VStack(spacing: 0) {
            // Playhead top indicator
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 12))
                .foregroundColor(.red)
                .offset(y: rulerHeight - 15)

            // Playhead line
            Rectangle()
                .fill(Color.red)
                .frame(width: 2, height: totalTracksHeight)
                .offset(y: rulerHeight)
        }
        .offset(x: engine.secondsToX(engine.currentTime) - 1)
    }

    private func timelineRuler(width: CGFloat) -> some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(white: 0.15))
            )

            let secondWidth = engine.horizontalZoom
            let totalSeconds = Int(width / secondWidth) + 1

            for second in 0...totalSeconds {
                let x = CGFloat(second) * secondWidth
                let isMajor = second % 10 == 0
                let isMinor = second % 5 == 0

                // Time label
                if isMajor {
                    context.draw(
                        Text(engine.formatTimecode(Double(second)))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white),
                        at: CGPoint(x: x + 2, y: size.height / 2),
                        anchor: .leading
                    )
                }

                // Tick mark
                context.stroke(
                    Path { path in
                        let tickHeight: CGFloat = isMajor ? size.height * 0.5 : isMinor ? size.height * 0.3 : size.height * 0.2
                        path.move(to: CGPoint(x: x, y: size.height - tickHeight))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(isMajor ? .white : Color(white: 0.5)),
                    lineWidth: 1
                )
            }
        }
        .frame(height: rulerHeight)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let time = engine.xToSeconds(value.location.x)
                    engine.seekTo(time: time)
                }
        )
    }

    // MARK: - Scopes Panel

    private var scopesPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SCOPES")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)

                Spacer()

                Picker("", selection: $engine.scopeType) {
                    ForEach(VideoTimelineEngine.ScopeType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .frame(width: 120)

                Button(action: { engine.showScopes = false }) {
                    Image(systemName: "xmark")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(white: 0.12))

            // Scope visualization
            Rectangle()
                .fill(Color.black)
                .frame(height: 150)
                .overlay(
                    Text(engine.scopeType.rawValue)
                        .foregroundColor(.green.opacity(0.5))
                )
        }
    }
}

// MARK: - Supporting Views

struct VideoTrackHeader: View {
    let track: VideoTrack
    @ObservedObject var engine: VideoTimelineEngine

    var body: some View {
        HStack(spacing: 4) {
            // Track Color
            Rectangle()
                .fill(track.type == .audio ? Color.green : Color.blue)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                // Track Name
                Text(track.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Track Type
                Text(track.type.rawValue.uppercased())
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }

            Spacer()

            // Track Controls
            HStack(spacing: 2) {
                // Visibility (Video only)
                if track.type != .audio {
                    Button(action: { engine.toggleTrackVisibility(track.id) }) {
                        Image(systemName: track.isVisible ? "eye" : "eye.slash")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(track.isVisible ? .white : .gray)
                }

                // Mute
                Button(action: { engine.toggleTrackMute(track.id) }) {
                    Text("M")
                        .font(.system(size: 9, weight: .bold))
                }
                .frame(width: 18, height: 18)
                .background(track.isMuted ? Color.orange.opacity(0.5) : Color(white: 0.2))
                .foregroundColor(track.isMuted ? .orange : .gray)
                .cornerRadius(3)

                // Lock
                Button(action: { engine.toggleTrackLock(track.id) }) {
                    Image(systemName: track.isLocked ? "lock.fill" : "lock.open")
                        .font(.system(size: 9))
                }
                .foregroundColor(track.isLocked ? .yellow : .gray)
            }
        }
        .padding(.horizontal, 4)
        .background(
            engine.selectedTrackId == track.id
                ? Color.white.opacity(0.1)
                : Color.clear
        )
        .onTapGesture {
            engine.selectedTrackId = track.id
        }
    }
}

struct VideoClipView: View {
    let clip: VideoClip
    @ObservedObject var engine: VideoTimelineEngine
    let trackHeight: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            // Clip Background
            RoundedRectangle(cornerRadius: 4)
                .fill(clip.color.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            engine.selectedClipIds.contains(clip.id) ? Color.white : clip.color,
                            lineWidth: engine.selectedClipIds.contains(clip.id) ? 2 : 1
                        )
                )

            // Clip Content
            VStack(alignment: .leading, spacing: 2) {
                // Clip Name
                Text(clip.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)

                // Thumbnail strip would go here
                HStack(spacing: 1) {
                    ForEach(0..<Int(clip.duration / 5), id: \.self) { _ in
                        Rectangle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 40, height: trackHeight - 25)
                    }
                }
                .padding(.horizontal, 2)

                Spacer()
            }

            // Effects indicator
            if !clip.effects.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                        Spacer()
                    }
                    .padding(4)
                }
            }

            // Resize handles
            HStack {
                // Left handle (trim in)
                Rectangle()
                    .fill(Color.white.opacity(0.01))
                    .frame(width: 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let deltaSeconds = Double(value.translation.width) / engine.horizontalZoom
                                let newInPoint = clip.inPoint + deltaSeconds
                                engine.trimClip(clip.id, newInPoint: newInPoint)
                            }
                    )

                Spacer()

                // Right handle (trim out)
                Rectangle()
                    .fill(Color.white.opacity(0.01))
                    .frame(width: 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let deltaSeconds = Double(value.translation.width) / engine.horizontalZoom
                                let newOutPoint = clip.outPoint + deltaSeconds
                                engine.trimClip(clip.id, newOutPoint: newOutPoint)
                            }
                    )
            }
        }
        .frame(
            width: max(20, engine.secondsToX(clip.duration)),
            height: trackHeight - 2
        )
        .opacity(clip.audioEnabled ? 1.0 : 0.7)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newTime = engine.xToSeconds(engine.secondsToX(clip.startTime) + value.translation.width)
                    engine.moveClip(clip.id, toTime: newTime)
                }
        )
        .onTapGesture {
            if engine.selectedClipIds.contains(clip.id) {
                engine.selectedClipIds.remove(clip.id)
            } else {
                engine.selectedClipIds.insert(clip.id)
            }
        }
        .contextMenu {
            Button("Split at Playhead") {
                engine.splitClip(clip.id, at: engine.currentTime)
            }
            Button("Duplicate") {
                engine.duplicateClip(clip.id)
            }
            Divider()
            Button("Reverse") {
                engine.reverseClip(clip.id)
            }
            Menu("Speed") {
                Button("50%") { engine.setClipSpeed(clip.id, speed: 0.5) }
                Button("100%") { engine.setClipSpeed(clip.id, speed: 1.0) }
                Button("200%") { engine.setClipSpeed(clip.id, speed: 2.0) }
                Button("400%") { engine.setClipSpeed(clip.id, speed: 4.0) }
            }
            Divider()
            Button("Delete", role: .destructive) {
                engine.deleteClip(clip.id)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VideoTimelineView()
        .preferredColorScheme(.dark)
        .frame(width: 1400, height: 900)
}

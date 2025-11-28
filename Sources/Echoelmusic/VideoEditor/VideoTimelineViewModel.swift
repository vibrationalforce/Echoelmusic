//
//  VideoTimelineViewModel.swift
//  Echoelmusic
//
//  Created: 2025-11-28
//  Professional Video Timeline ViewModel (MVVM Architecture)
//
//  Clean separation of concerns from View
//  Handles all business logic, state management, and undo/redo
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Video Timeline ViewModel

@MainActor
public final class VideoTimelineViewModel: ObservableObject {
    // MARK: - Timeline Data

    @Published public var videoTracks: [VideoTrackModel] = []
    @Published public var audioTracks: [VideoTrackModel] = []
    @Published public var markers: [TimelineMarkerModel] = []
    @Published public var projectSettings: ProjectSettings = ProjectSettings()

    // MARK: - Playback State

    @Published public var currentTime: Double = 0
    @Published public var isPlaying: Bool = false
    @Published public var playbackRate: Double = 1.0
    @Published public private(set) var duration: Double = 60

    // MARK: - Selection State

    @Published public var selectedClipIds: Set<UUID> = []
    @Published public var selectedTrackId: UUID?
    @Published public var hoveredClipId: UUID?

    // MARK: - View State

    @Published public var horizontalZoom: Double = 100 // pixels per second
    @Published public var verticalZoom: Double = 1.0
    @Published public var scrollOffset: CGPoint = .zero
    @Published public var isSnappingEnabled: Bool = true
    @Published public var snapTolerance: Double = 0.1 // seconds

    // MARK: - Edit Mode State

    @Published public var editMode: TimelineEditMode = .select
    @Published public var rippleMode: Bool = false

    // MARK: - Scopes

    @Published public var showScopes: Bool = false
    @Published public var scopeType: TimelineScopeType = .waveform

    // MARK: - Preview

    @Published public var previewResolution: PreviewResolution = .full
    @Published public var isProxyMode: Bool = false

    // MARK: - Undo/Redo

    private var undoStack: [TimelineStateSnapshot] = []
    private var redoStack: [TimelineStateSnapshot] = []
    private let maxUndoLevels = 100

    @Published public private(set) var canUndo: Bool = false
    @Published public private(set) var canRedo: Bool = false

    // MARK: - Playback

    private var displayLink: CADisplayLink?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        setupDefaultTimeline()
        setupBindings()
    }

    deinit {
        displayLink?.invalidate()
    }

    private func setupDefaultTimeline() {
        let mainTrackId = UUID()
        videoTracks = [
            VideoTrackModel(id: UUID(), name: "V3 - Titles", type: .title, clips: []),
            VideoTrackModel(id: UUID(), name: "V2 - Overlay", type: .video, clips: []),
            VideoTrackModel(id: mainTrackId, name: "V1 - Main", type: .video, clips: createDemoClips(trackId: mainTrackId)),
        ]

        audioTracks = [
            VideoTrackModel(id: UUID(), name: "A1 - Dialogue", type: .audio, clips: []),
            VideoTrackModel(id: UUID(), name: "A2 - Music", type: .audio, clips: []),
            VideoTrackModel(id: UUID(), name: "A3 - SFX", type: .audio, clips: []),
        ]

        markers = [
            TimelineMarkerModel(name: "Intro", time: 0, color: .green, type: .chapter),
            TimelineMarkerModel(name: "Main Content", time: 15, color: .yellow, type: .chapter),
            TimelineMarkerModel(name: "Outro", time: 50, color: .red, type: .chapter),
        ]

        recalculateDuration()
    }

    private func createDemoClips(trackId: UUID) -> [VideoClipModel] {
        [
            VideoClipModel(
                name: "Intro_v2.mov",
                trackId: trackId,
                startTime: 0,
                inPoint: 0,
                outPoint: 10,
                color: CodableColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
            ),
            VideoClipModel(
                name: "Interview_A.mp4",
                trackId: trackId,
                startTime: 10,
                inPoint: 5,
                outPoint: 35,
                color: CodableColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
            ),
            VideoClipModel(
                name: "B-Roll_City.mp4",
                trackId: trackId,
                startTime: 40,
                inPoint: 0,
                outPoint: 15,
                color: CodableColor(red: 1.0, green: 0.5, blue: 0.2, alpha: 1.0)
            ),
        ]
    }

    private func setupBindings() {
        // Auto-recalculate duration when tracks change
        $videoTracks
            .sink { [weak self] _ in
                self?.recalculateDuration()
            }
            .store(in: &cancellables)
    }

    // MARK: - Transport Controls

    public func play() {
        isPlaying = true
        startPlaybackTimer()
    }

    public func pause() {
        isPlaying = false
        stopPlaybackTimer()
    }

    public func stop() {
        isPlaying = false
        currentTime = 0
        stopPlaybackTimer()
    }

    public func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func seekTo(time: Double) {
        currentTime = max(0, min(duration, time))
    }

    public func seekToStart() {
        currentTime = 0
    }

    public func seekToEnd() {
        currentTime = duration
    }

    public func seekForward(seconds: Double = 1.0) {
        seekTo(time: currentTime + seconds)
    }

    public func seekBackward(seconds: Double = 1.0) {
        seekTo(time: currentTime - seconds)
    }

    public func goToNextMarker() {
        if let nextMarker = markers.sorted(by: { $0.time < $1.time }).first(where: { $0.time > currentTime + 0.01 }) {
            seekTo(time: nextMarker.time)
        }
    }

    public func goToPreviousMarker() {
        if let previousMarker = markers.sorted(by: { $0.time > $1.time }).first(where: { $0.time < currentTime - 0.01 }) {
            seekTo(time: previousMarker.time)
        }
    }

    public func goToNextClip() {
        var nextClipStart: Double = duration
        for track in videoTracks {
            for clip in track.clips where clip.startTime > currentTime + 0.01 {
                nextClipStart = min(nextClipStart, clip.startTime)
            }
        }
        if nextClipStart < duration {
            seekTo(time: nextClipStart)
        }
    }

    public func goToPreviousClip() {
        var previousClipStart: Double = 0
        for track in videoTracks {
            for clip in track.clips where clip.startTime < currentTime - 0.01 {
                previousClipStart = max(previousClipStart, clip.startTime)
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

    public func addVideoTrack(name: String? = nil) {
        saveUndoState()
        let trackName = name ?? "V\(videoTracks.count + 1)"
        let newTrack = VideoTrackModel(id: UUID(), name: trackName, type: .video, clips: [])
        videoTracks.insert(newTrack, at: 0)
    }

    public func addAudioTrack(name: String? = nil) {
        saveUndoState()
        let trackName = name ?? "A\(audioTracks.count + 1)"
        let newTrack = VideoTrackModel(id: UUID(), name: trackName, type: .audio, clips: [])
        audioTracks.append(newTrack)
    }

    public func deleteTrack(_ trackId: UUID) {
        saveUndoState()
        videoTracks.removeAll { $0.id == trackId }
        audioTracks.removeAll { $0.id == trackId }
        if selectedTrackId == trackId {
            selectedTrackId = nil
        }
    }

    public func toggleTrackVisibility(_ trackId: UUID) {
        if let index = videoTracks.firstIndex(where: { $0.id == trackId }) {
            videoTracks[index].isVisible.toggle()
        }
    }

    public func toggleTrackLock(_ trackId: UUID) {
        if let index = videoTracks.firstIndex(where: { $0.id == trackId }) {
            videoTracks[index].isLocked.toggle()
        }
    }

    public func toggleTrackMute(_ trackId: UUID) {
        if let index = videoTracks.firstIndex(where: { $0.id == trackId }) {
            videoTracks[index].isMuted.toggle()
        } else if let index = audioTracks.firstIndex(where: { $0.id == trackId }) {
            audioTracks[index].isMuted.toggle()
        }
    }

    // MARK: - Clip Management

    public func addClip(to trackId: UUID, clip: VideoClipModel, at time: Double) {
        saveUndoState()

        var newClip = clip
        newClip.trackId = trackId
        newClip.startTime = snapTime(time)

        if let index = videoTracks.firstIndex(where: { $0.id == trackId }) {
            videoTracks[index].clips.append(newClip)
            sortClipsInTrack(at: index)
        }

        recalculateDuration()
    }

    public func moveClip(_ clipId: UUID, toTime: Double, toTrackId: UUID? = nil) {
        saveUndoState()

        var movedClip: VideoClipModel?
        var sourceTrackIndex: Int?

        for (trackIndex, track) in videoTracks.enumerated() {
            if let clipIndex = track.clips.firstIndex(where: { $0.id == clipId }) {
                movedClip = videoTracks[trackIndex].clips.remove(at: clipIndex)
                sourceTrackIndex = trackIndex
                break
            }
        }

        guard var clip = movedClip else { return }

        clip.startTime = snapTime(max(0, toTime))
        let targetTrackId = toTrackId ?? clip.trackId
        clip.trackId = targetTrackId

        if let trackIndex = videoTracks.firstIndex(where: { $0.id == targetTrackId }) {
            videoTracks[trackIndex].clips.append(clip)
            sortClipsInTrack(at: trackIndex)
        }

        recalculateDuration()
    }

    public func trimClip(_ clipId: UUID, newInPoint: Double? = nil, newOutPoint: Double? = nil) {
        saveUndoState()

        for trackIndex in videoTracks.indices {
            if let clipIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                if let inPoint = newInPoint {
                    let trimDelta = inPoint - videoTracks[trackIndex].clips[clipIndex].inPoint
                    videoTracks[trackIndex].clips[clipIndex].inPoint = max(0, inPoint)
                    videoTracks[trackIndex].clips[clipIndex].startTime += trimDelta
                }
                if let outPoint = newOutPoint {
                    videoTracks[trackIndex].clips[clipIndex].outPoint = outPoint
                }
                break
            }
        }

        recalculateDuration()
    }

    public func splitClip(_ clipId: UUID, at time: Double) {
        saveUndoState()

        for trackIndex in videoTracks.indices {
            if let clipIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                let originalClip = videoTracks[trackIndex].clips[clipIndex]
                let clipEndTime = originalClip.startTime + originalClip.duration

                guard time > originalClip.startTime && time < clipEndTime else { return }

                let splitPointInSource = originalClip.inPoint + (time - originalClip.startTime)

                videoTracks[trackIndex].clips[clipIndex].outPoint = splitPointInSource

                var secondClip = originalClip
                secondClip.id = UUID()
                secondClip.inPoint = splitPointInSource
                secondClip.startTime = time
                secondClip.name += " (2)"

                videoTracks[trackIndex].clips.append(secondClip)
                sortClipsInTrack(at: trackIndex)
                break
            }
        }
    }

    public func deleteClip(_ clipId: UUID) {
        saveUndoState()
        for trackIndex in videoTracks.indices {
            videoTracks[trackIndex].clips.removeAll { $0.id == clipId }
        }
        selectedClipIds.remove(clipId)
        recalculateDuration()
    }

    public func deleteSelectedClips() {
        saveUndoState()
        for clipId in selectedClipIds {
            for trackIndex in videoTracks.indices {
                videoTracks[trackIndex].clips.removeAll { $0.id == clipId }
            }
        }
        selectedClipIds.removeAll()
        recalculateDuration()
    }

    public func duplicateClip(_ clipId: UUID) {
        saveUndoState()

        for trackIndex in videoTracks.indices {
            if let clipIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                var newClip = videoTracks[trackIndex].clips[clipIndex]
                newClip.id = UUID()
                newClip.startTime = newClip.startTime + newClip.duration
                newClip.name += " (Copy)"
                videoTracks[trackIndex].clips.append(newClip)
                sortClipsInTrack(at: trackIndex)
                break
            }
        }

        recalculateDuration()
    }

    // MARK: - Speed/Time Operations

    public func setClipSpeed(_ clipId: UUID, speed: Double) {
        saveUndoState()
        for trackIndex in videoTracks.indices {
            if let clipIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                videoTracks[trackIndex].clips[clipIndex].speed = speed
                break
            }
        }
    }

    public func reverseClip(_ clipId: UUID) {
        saveUndoState()
        for trackIndex in videoTracks.indices {
            if let clipIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                videoTracks[trackIndex].clips[clipIndex].isReversed.toggle()
                break
            }
        }
    }

    // MARK: - Effects

    public func addEffect(to clipId: UUID, effect: VideoEffectModel) {
        saveUndoState()
        for trackIndex in videoTracks.indices {
            if let clipIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                videoTracks[trackIndex].clips[clipIndex].effects.append(effect)
                break
            }
        }
    }

    public func removeEffect(from clipId: UUID, effectId: UUID) {
        saveUndoState()
        for trackIndex in videoTracks.indices {
            if let clipIndex = videoTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                videoTracks[trackIndex].clips[clipIndex].effects.removeAll { $0.id == effectId }
                break
            }
        }
    }

    public func reorderEffects(for clipId: UUID, from: Int, to: Int) {
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

    public func addTransition(between clipAId: UUID, and clipBId: UUID, transition: ClipTransitions.Transition) {
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

    public func addMarker(at time: Double, name: String, type: TimelineMarkerModel.MarkerType = .standard) {
        saveUndoState()
        let marker = TimelineMarkerModel(
            name: name,
            time: snapTime(time),
            color: .yellow,
            type: type
        )
        markers.append(marker)
        markers.sort { $0.time < $1.time }
    }

    public func deleteMarker(_ markerId: UUID) {
        saveUndoState()
        markers.removeAll { $0.id == markerId }
    }

    // MARK: - Selection

    public func selectClip(_ clipId: UUID, additive: Bool = false) {
        if additive {
            if selectedClipIds.contains(clipId) {
                selectedClipIds.remove(clipId)
            } else {
                selectedClipIds.insert(clipId)
            }
        } else {
            selectedClipIds = [clipId]
        }
    }

    public func deselectAllClips() {
        selectedClipIds.removeAll()
    }

    public func selectAllClipsInTrack(_ trackId: UUID) {
        if let track = videoTracks.first(where: { $0.id == trackId }) {
            selectedClipIds = Set(track.clips.map { $0.id })
        }
    }

    // MARK: - Snapping

    public func snapTime(_ time: Double) -> Double {
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
                if abs(time - clip.startTime) < minDistance {
                    nearestSnapPoint = clip.startTime
                    minDistance = abs(time - clip.startTime)
                }
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
        let state = TimelineStateSnapshot(
            videoTracks: videoTracks,
            audioTracks: audioTracks,
            markers: markers
        )
        undoStack.append(state)

        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst()
        }

        redoStack.removeAll()
        updateUndoRedoState()
    }

    public func undo() {
        guard let previousState = undoStack.popLast() else { return }

        let currentState = TimelineStateSnapshot(
            videoTracks: videoTracks,
            audioTracks: audioTracks,
            markers: markers
        )
        redoStack.append(currentState)

        videoTracks = previousState.videoTracks
        audioTracks = previousState.audioTracks
        markers = previousState.markers

        updateUndoRedoState()
        recalculateDuration()
    }

    public func redo() {
        guard let nextState = redoStack.popLast() else { return }

        let currentState = TimelineStateSnapshot(
            videoTracks: videoTracks,
            audioTracks: audioTracks,
            markers: markers
        )
        undoStack.append(currentState)

        videoTracks = nextState.videoTracks
        audioTracks = nextState.audioTracks
        markers = nextState.markers

        updateUndoRedoState()
        recalculateDuration()
    }

    private func updateUndoRedoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    // MARK: - Helpers

    private func sortClipsInTrack(at index: Int) {
        videoTracks[index].clips.sort { $0.startTime < $1.startTime }
    }

    private func recalculateDuration() {
        var maxEnd: Double = 0
        for track in videoTracks {
            for clip in track.clips {
                let clipEnd = clip.startTime + clip.duration
                maxEnd = max(maxEnd, clipEnd)
            }
        }
        duration = max(maxEnd + 10, 60) // Always at least 60 seconds, plus 10s buffer
    }

    public func findClip(by id: UUID) -> VideoClipModel? {
        for track in videoTracks {
            if let clip = track.clips.first(where: { $0.id == id }) {
                return clip
            }
        }
        return nil
    }

    // MARK: - Coordinate Conversion

    public func secondsToX(_ seconds: Double) -> CGFloat {
        CGFloat(seconds * horizontalZoom)
    }

    public func xToSeconds(_ x: CGFloat) -> Double {
        Double(x) / horizontalZoom
    }

    public func formatTimecode(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let frames = Int((seconds.truncatingRemainder(dividingBy: 1)) * projectSettings.frameRate.value)
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, secs, frames)
    }

    // MARK: - Total Track Heights

    public var totalVideoTrackHeight: CGFloat {
        videoTracks.reduce(0) { $0 + $1.height * verticalZoom }
    }

    public var totalAudioTrackHeight: CGFloat {
        audioTracks.reduce(0) { $0 + $1.height * verticalZoom }
    }

    public var totalTracksHeight: CGFloat {
        totalVideoTrackHeight + totalAudioTrackHeight + 2 // +2 for separator
    }
}

// MARK: - Keyboard Handling

extension VideoTimelineViewModel {
    public func handleKeyPress(key: String, modifiers: Set<String>) {
        switch key {
        case " ":
            togglePlayback()
        case "j":
            playbackRate = max(-4, playbackRate - 1)
        case "k":
            pause()
        case "l":
            playbackRate = min(4, playbackRate + 1)
            if !isPlaying { play() }
        case "z":
            if modifiers.contains("command") {
                if modifiers.contains("shift") {
                    redo()
                } else {
                    undo()
                }
            }
        case "delete", "backspace":
            deleteSelectedClips()
        case "d":
            if modifiers.contains("command"), let clipId = selectedClipIds.first {
                duplicateClip(clipId)
            }
        case "b":
            if let clipId = selectedClipIds.first {
                splitClip(clipId, at: currentTime)
            }
        case "s":
            editMode = .select
        case "c":
            editMode = .blade
        case "t":
            editMode = .trim
        case "m":
            addMarker(at: currentTime, name: "Marker \(markers.count + 1)")
        case "home":
            seekToStart()
        case "end":
            seekToEnd()
        case "leftArrow":
            if modifiers.contains("shift") {
                goToPreviousClip()
            } else {
                seekBackward(seconds: modifiers.contains("option") ? 10 : 1)
            }
        case "rightArrow":
            if modifiers.contains("shift") {
                goToNextClip()
            } else {
                seekForward(seconds: modifiers.contains("option") ? 10 : 1)
            }
        case "upArrow":
            goToPreviousMarker()
        case "downArrow":
            goToNextMarker()
        default:
            break
        }
    }
}

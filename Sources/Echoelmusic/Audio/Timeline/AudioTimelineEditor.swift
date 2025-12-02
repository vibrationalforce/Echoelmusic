import SwiftUI
import AVFoundation
import Combine

// MARK: - Audio Clip Model
/// Represents an audio clip on the timeline
struct AudioClip: Identifiable, Equatable {
    let id: UUID
    var trackID: UUID
    var url: URL?
    var name: String

    // Timeline position
    var startTime: TimeInterval = 0.0
    var duration: TimeInterval = 0.0

    // In/Out points (for trimming)
    var inPoint: TimeInterval = 0.0
    var outPoint: TimeInterval = 0.0

    // Audio properties
    var volume: Float = 1.0
    var pan: Float = 0.0
    var isMuted: Bool = false

    // Fade in/out
    var fadeInDuration: TimeInterval = 0.0
    var fadeOutDuration: TimeInterval = 0.0

    // Waveform for display
    var waveform: [Float] = []

    // Computed
    var endTime: TimeInterval {
        startTime + duration
    }

    var trimmedDuration: TimeInterval {
        outPoint - inPoint
    }
}

// MARK: - Timeline Track
/// Represents a track in the audio timeline
struct TimelineTrack: Identifiable {
    let id: UUID
    var name: String
    var clips: [AudioClip] = []
    var color: Color = .blue
    var height: CGFloat = 80
    var isMuted: Bool = false
    var isSoloed: Bool = false
    var volume: Float = 1.0
    var pan: Float = 0.0
}

// MARK: - Audio Timeline Editor
/// Full-featured audio timeline editor with clip management
@MainActor
class AudioTimelineEditor: ObservableObject {

    // MARK: - Published State

    @Published var tracks: [TimelineTrack] = []
    @Published var playheadPosition: TimeInterval = 0.0
    @Published var isPlaying: Bool = false
    @Published var zoom: CGFloat = 1.0  // Pixels per second
    @Published var scrollOffset: CGFloat = 0.0

    // Selection
    @Published var selectedClipIDs: Set<UUID> = []
    @Published var selectedTrackID: UUID?

    // Snapping
    @Published var snapEnabled: Bool = true
    @Published var snapToGrid: Bool = true
    @Published var snapToClips: Bool = true
    @Published var gridSize: TimeInterval = 0.25  // Quarter notes at 120 BPM

    // Edit mode
    @Published var editMode: EditMode = .select

    enum EditMode: String, CaseIterable {
        case select = "Select"
        case trim = "Trim"
        case slip = "Slip"
        case razor = "Razor"
        case draw = "Draw"
    }

    // Timeline settings
    @Published var tempo: Double = 120.0  // BPM
    @Published var timeSignature: (beats: Int, noteValue: Int) = (4, 4)
    @Published var totalDuration: TimeInterval = 300.0  // 5 minutes default

    // MARK: - Private

    private let undoManager = UndoRedoManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var playbackTimer: Timer?

    // MARK: - Initialization

    init() {
        // Create default tracks
        tracks = [
            TimelineTrack(id: UUID(), name: "Audio 1", color: .blue),
            TimelineTrack(id: UUID(), name: "Audio 2", color: .green),
            TimelineTrack(id: UUID(), name: "Audio 3", color: .orange),
            TimelineTrack(id: UUID(), name: "Audio 4", color: .purple)
        ]
    }

    // MARK: - Track Management

    func addTrack(name: String = "New Track") -> UUID {
        let track = TimelineTrack(
            id: UUID(),
            name: name,
            color: Color(hue: Double.random(in: 0...1), saturation: 0.6, brightness: 0.8)
        )
        tracks.append(track)
        return track.id
    }

    func deleteTrack(id: UUID) {
        tracks.removeAll { $0.id == id }
    }

    func moveTrack(from: Int, to: Int) {
        guard from != to else { return }
        let track = tracks.remove(at: from)
        tracks.insert(track, at: to)
    }

    // MARK: - Clip Management

    /// Add a clip to a track
    func addClip(to trackID: UUID, url: URL, at position: TimeInterval) async throws -> UUID {
        guard let trackIndex = tracks.firstIndex(where: { $0.id == trackID }) else {
            throw TimelineError.trackNotFound
        }

        // Load audio file to get duration
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds

        // Generate waveform
        let waveform = try await generateWaveform(from: url, samples: 200)

        let clip = AudioClip(
            id: UUID(),
            trackID: trackID,
            url: url,
            name: url.lastPathComponent,
            startTime: snapEnabled ? snapTime(position) : position,
            duration: duration,
            inPoint: 0,
            outPoint: duration,
            waveform: waveform
        )

        // Add with undo support
        let command = AddClipCommand(
            clip: clip,
            trackIndex: trackIndex,
            addClip: { [weak self] clip, index in
                self?.tracks[index].clips.append(clip)
                self?.sortClips(in: index)
            },
            removeClip: { [weak self] clipID, index in
                self?.tracks[index].clips.removeAll { $0.id == clipID }
            }
        )

        undoManager.execute(command)
        return clip.id
    }

    /// Delete selected clips
    func deleteSelectedClips() {
        guard !selectedClipIDs.isEmpty else { return }

        let batch = undoManager.beginBatch(name: "Delete Clips")

        for clipID in selectedClipIDs {
            if let (trackIndex, clipIndex) = findClip(id: clipID) {
                let clip = tracks[trackIndex].clips[clipIndex]

                let command = DeleteClipCommand(
                    clip: clip,
                    trackIndex: trackIndex,
                    addClip: { [weak self] clip, index in
                        self?.tracks[index].clips.append(clip)
                        self?.sortClips(in: index)
                    },
                    removeClip: { [weak self] clipID, index in
                        self?.tracks[index].clips.removeAll { $0.id == clipID }
                    }
                )

                batch.add(command)
            }
        }

        batch.commit()
        selectedClipIDs.removeAll()
    }

    /// Move a clip to a new position
    func moveClip(id: UUID, to newPosition: TimeInterval, toTrack newTrackID: UUID? = nil) {
        guard let (trackIndex, clipIndex) = findClip(id: id) else { return }

        let clip = tracks[trackIndex].clips[clipIndex]
        let oldPosition = clip.startTime
        let snappedPosition = snapEnabled ? snapTime(newPosition) : newPosition

        let command = MoveClipCommand(
            clipID: id,
            oldPosition: oldPosition,
            newPosition: snappedPosition,
            applyChange: { [weak self] clipID, position in
                if let (ti, ci) = self?.findClip(id: clipID) {
                    self?.tracks[ti].clips[ci].startTime = position
                    self?.sortClips(in: ti)
                }
            }
        )

        undoManager.execute(command)
    }

    /// Trim a clip
    func trimClip(id: UUID, edge: TrimEdge, to time: TimeInterval) {
        guard let (trackIndex, clipIndex) = findClip(id: id) else { return }

        var clip = tracks[trackIndex].clips[clipIndex]
        let snappedTime = snapEnabled ? snapTime(time) : time

        let oldStart = clip.startTime
        let oldEnd = clip.endTime

        switch edge {
        case .left:
            let newStart = max(0, min(snappedTime, oldEnd - 0.1))
            let delta = newStart - oldStart
            clip.startTime = newStart
            clip.inPoint += delta
            clip.duration -= delta

        case .right:
            let newEnd = max(oldStart + 0.1, snappedTime)
            clip.duration = newEnd - oldStart
            clip.outPoint = clip.inPoint + clip.duration
        }

        let command = TrimClipCommand(
            clipID: id,
            oldStart: oldStart,
            oldEnd: oldEnd,
            newStart: clip.startTime,
            newEnd: clip.endTime,
            applyChange: { [weak self] clipID, start, end in
                if let (ti, ci) = self?.findClip(id: clipID) {
                    self?.tracks[ti].clips[ci].startTime = start
                    self?.tracks[ti].clips[ci].duration = end - start
                }
            }
        )

        undoManager.execute(command)
    }

    enum TrimEdge {
        case left, right
    }

    /// Split a clip at the playhead
    func splitClipAtPlayhead(id: UUID) {
        guard let (trackIndex, clipIndex) = findClip(id: id) else { return }

        let clip = tracks[trackIndex].clips[clipIndex]

        // Check if playhead is within clip
        guard playheadPosition > clip.startTime && playheadPosition < clip.endTime else {
            return
        }

        let splitTime = playheadPosition - clip.startTime

        // Create two new clips
        var leftClip = clip
        leftClip.duration = splitTime
        leftClip.outPoint = clip.inPoint + splitTime

        var rightClip = clip
        rightClip.id = UUID()
        rightClip.startTime = playheadPosition
        rightClip.duration = clip.duration - splitTime
        rightClip.inPoint = clip.inPoint + splitTime

        // Apply with undo
        tracks[trackIndex].clips[clipIndex] = leftClip
        tracks[trackIndex].clips.append(rightClip)
        sortClips(in: trackIndex)
    }

    // MARK: - Playback

    func play() {
        guard !isPlaying else { return }
        isPlaying = true

        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePlayhead()
            }
        }
    }

    func pause() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    func stop() {
        pause()
        playheadPosition = 0
    }

    func seek(to time: TimeInterval) {
        playheadPosition = max(0, min(time, totalDuration))
    }

    private func updatePlayhead() {
        playheadPosition += 1.0/60.0

        if playheadPosition >= totalDuration {
            stop()
        }
    }

    // MARK: - Snapping

    func snapTime(_ time: TimeInterval) -> TimeInterval {
        var snappedTime = time

        // Snap to grid
        if snapToGrid {
            let gridSnap = round(time / gridSize) * gridSize
            if abs(time - gridSnap) < 0.05 {
                snappedTime = gridSnap
            }
        }

        // Snap to clip edges
        if snapToClips {
            for track in tracks {
                for clip in track.clips {
                    if abs(time - clip.startTime) < 0.05 {
                        snappedTime = clip.startTime
                    }
                    if abs(time - clip.endTime) < 0.05 {
                        snappedTime = clip.endTime
                    }
                }
            }
        }

        // Snap to playhead
        if abs(time - playheadPosition) < 0.05 {
            snappedTime = playheadPosition
        }

        return snappedTime
    }

    // MARK: - Selection

    func selectClip(id: UUID, addToSelection: Bool = false) {
        if addToSelection {
            selectedClipIDs.insert(id)
        } else {
            selectedClipIDs = [id]
        }
    }

    func deselectAll() {
        selectedClipIDs.removeAll()
        selectedTrackID = nil
    }

    func selectClipsInRange(start: TimeInterval, end: TimeInterval) {
        selectedClipIDs.removeAll()

        for track in tracks {
            for clip in track.clips {
                if clip.startTime < end && clip.endTime > start {
                    selectedClipIDs.insert(clip.id)
                }
            }
        }
    }

    // MARK: - Helpers

    private func findClip(id: UUID) -> (trackIndex: Int, clipIndex: Int)? {
        for (ti, track) in tracks.enumerated() {
            if let ci = track.clips.firstIndex(where: { $0.id == id }) {
                return (ti, ci)
            }
        }
        return nil
    }

    private func sortClips(in trackIndex: Int) {
        tracks[trackIndex].clips.sort { $0.startTime < $1.startTime }
    }

    private func generateWaveform(from url: URL, samples: Int) async throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = UInt32(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return []
        }

        try file.read(into: buffer)

        guard let channelData = buffer.floatChannelData?[0] else {
            return []
        }

        // Downsample to target number of samples
        let framesPerSample = Int(frameCount) / samples
        var waveform = [Float](repeating: 0, count: samples)

        for i in 0..<samples {
            let start = i * framesPerSample
            let end = min(start + framesPerSample, Int(frameCount))

            var maxVal: Float = 0
            for j in start..<end {
                maxVal = max(maxVal, abs(channelData[j]))
            }
            waveform[i] = maxVal
        }

        return waveform
    }

    // MARK: - Time Conversion

    func timeToPixels(_ time: TimeInterval) -> CGFloat {
        CGFloat(time) * zoom * 50  // 50 pixels per second at zoom 1.0
    }

    func pixelsToTime(_ pixels: CGFloat) -> TimeInterval {
        TimeInterval(pixels / (zoom * 50))
    }

    func beatsToTime(_ beats: Double) -> TimeInterval {
        (beats / tempo) * 60.0
    }

    func timeToBeats(_ time: TimeInterval) -> Double {
        (time / 60.0) * tempo
    }
}

// MARK: - Commands

struct AddClipCommand: UndoableCommand {
    let clip: AudioClip
    let trackIndex: Int
    let addClip: (AudioClip, Int) -> Void
    let removeClip: (UUID, Int) -> Void

    var actionName: String { "Add Clip" }

    func execute() {
        addClip(clip, trackIndex)
    }

    func undo() {
        removeClip(clip.id, trackIndex)
    }
}

struct DeleteClipCommand: UndoableCommand {
    let clip: AudioClip
    let trackIndex: Int
    let addClip: (AudioClip, Int) -> Void
    let removeClip: (UUID, Int) -> Void

    var actionName: String { "Delete Clip" }

    func execute() {
        removeClip(clip.id, trackIndex)
    }

    func undo() {
        addClip(clip, trackIndex)
    }
}

// MARK: - Errors

enum TimelineError: Error, LocalizedError {
    case trackNotFound
    case clipNotFound
    case invalidPosition
    case audioLoadFailed

    var errorDescription: String? {
        switch self {
        case .trackNotFound: return "Track not found"
        case .clipNotFound: return "Clip not found"
        case .invalidPosition: return "Invalid position"
        case .audioLoadFailed: return "Failed to load audio"
        }
    }
}

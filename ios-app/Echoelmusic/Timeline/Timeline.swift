// Timeline.swift
// Core Timeline Model - Foundation für DAW + Video + Visual
//
// Vereint Audio Timeline (Ableton/Reaper) + Video Timeline (DaVinci)
// auf einer einzigen Timeline mit Sample-Accurate Sync

import Foundation
import AVFoundation

/// Timeline ist die zentrale Zeitachse für Audio, Video, MIDI, Automation
/// Alle Tracks (Audio, Video, MIDI, Automation) teilen sich dieselbe Timeline
class Timeline: ObservableObject, Codable {

    // MARK: - Properties

    /// Unique identifier
    let id: UUID

    /// Timeline name
    var name: String

    /// Sample rate (44100, 48000, 96000, etc.)
    var sampleRate: Double

    /// Tempo in BPM
    @Published var tempo: Double

    /// Time signature
    @Published var timeSignature: TimeSignature

    /// All tracks (Audio, MIDI, Video, Automation)
    @Published var tracks: [Track]

    /// Current playhead position (in samples)
    @Published var playheadPosition: Int64

    /// Is timeline playing
    @Published var isPlaying: Bool

    /// Is timeline recording
    @Published var isRecording: Bool

    /// Loop enabled
    @Published var isLooping: Bool

    /// Loop range (start/end in samples)
    @Published var loopRange: ClosedRange<Int64>?

    /// Timeline length (in samples)
    var length: Int64

    /// Markers for navigation
    @Published var markers: [Marker]

    /// Automation lanes
    @Published var automationLanes: [AutomationLane]

    /// Metronome enabled
    @Published var metronomeEnabled: Bool

    /// Count-in bars before recording
    var countInBars: Int

    /// Created date
    let createdAt: Date

    /// Last modified
    var modifiedAt: Date


    // MARK: - Computed Properties

    /// Timeline duration in seconds
    var durationSeconds: TimeInterval {
        Double(length) / sampleRate
    }

    /// Timeline duration as CMTime (for video sync)
    var durationCMTime: CMTime {
        CMTime(seconds: durationSeconds, preferredTimescale: CMTimeScale(sampleRate))
    }

    /// Current playhead position in seconds
    var playheadSeconds: TimeInterval {
        Double(playheadPosition) / sampleRate
    }

    /// Current playhead as CMTime
    var playheadCMTime: CMTime {
        CMTime(seconds: playheadSeconds, preferredTimescale: CMTimeScale(sampleRate))
    }

    /// Current bar/beat position
    var currentBarBeat: BarBeat {
        samplesToBarBeat(playheadPosition)
    }


    // MARK: - Initialization

    init(
        name: String = "New Timeline",
        sampleRate: Double = 48000,
        tempo: Double = 120.0,
        timeSignature: TimeSignature = TimeSignature(beats: 4, noteValue: 4)
    ) {
        self.id = UUID()
        self.name = name
        self.sampleRate = sampleRate
        self.tempo = tempo
        self.timeSignature = timeSignature
        self.tracks = []
        self.playheadPosition = 0
        self.isPlaying = false
        self.isRecording = false
        self.isLooping = false
        self.loopRange = nil
        self.length = Int64(sampleRate * 60 * 5) // Default 5 minutes
        self.markers = []
        self.automationLanes = []
        self.metronomeEnabled = true
        self.countInBars = 1
        self.createdAt = Date()
        self.modifiedAt = Date()
    }


    // MARK: - Track Management

    /// Add track to timeline
    func addTrack(_ track: Track) {
        tracks.append(track)
        track.timeline = self
        modifiedAt = Date()
    }

    /// Remove track
    func removeTrack(_ track: Track) {
        tracks.removeAll { $0.id == track.id }
        modifiedAt = Date()
    }

    /// Reorder tracks
    func moveTrack(from source: IndexSet, to destination: Int) {
        tracks.move(fromOffsets: source, toOffset: destination)
        modifiedAt = Date()
    }

    /// Get track by ID
    func track(withID id: UUID) -> Track? {
        tracks.first { $0.id == id }
    }

    /// Get all tracks of specific type
    func tracks(ofType type: TrackType) -> [Track] {
        tracks.filter { $0.type == type }
    }


    // MARK: - Playback Control

    /// Start playback
    func play() {
        isPlaying = true
        print("▶️ Timeline playing from \(currentBarBeat)")
    }

    /// Stop playback
    func stop() {
        isPlaying = false
        playheadPosition = 0
        print("⏹️ Timeline stopped")
    }

    /// Pause playback
    func pause() {
        isPlaying = false
        print("⏸️ Timeline paused at \(currentBarBeat)")
    }

    /// Start recording
    func startRecording() {
        isRecording = true
        isPlaying = true
        print("🔴 Recording started")
    }

    /// Stop recording
    func stopRecording() {
        isRecording = false
        print("⏺️ Recording stopped")
    }

    /// Seek to position (in samples)
    func seek(to position: Int64) {
        playheadPosition = max(0, min(position, length))
        print("⏩ Seeked to \(samplesToBarBeat(playheadPosition))")
    }

    /// Seek to seconds
    func seekToSeconds(_ seconds: TimeInterval) {
        let samples = Int64(seconds * sampleRate)
        seek(to: samples)
    }

    /// Seek to bar/beat
    func seekToBarBeat(_ barBeat: BarBeat) {
        let samples = barBeatToSamples(barBeat)
        seek(to: samples)
    }


    // MARK: - Loop Control

    /// Set loop range (in samples)
    func setLoopRange(start: Int64, end: Int64) {
        guard start < end else { return }
        loopRange = start...end
        isLooping = true
        print("🔁 Loop set: \(samplesToBarBeat(start)) - \(samplesToBarBeat(end))")
    }

    /// Set loop range (in bars)
    func setLoopRangeBars(start: Int, end: Int) {
        let startSamples = barBeatToSamples(BarBeat(bar: start, beat: 1))
        let endSamples = barBeatToSamples(BarBeat(bar: end, beat: 1))
        setLoopRange(start: startSamples, end: endSamples)
    }

    /// Clear loop
    func clearLoop() {
        loopRange = nil
        isLooping = false
        print("🔁 Loop cleared")
    }


    // MARK: - Time Conversion

    /// Convert samples to bar/beat position
    func samplesToBarBeat(_ samples: Int64) -> BarBeat {
        let seconds = Double(samples) / sampleRate
        let beats = seconds * (tempo / 60.0)

        let bar = Int(beats / Double(timeSignature.beats)) + 1
        let beat = Int(beats.truncatingRemainder(dividingBy: Double(timeSignature.beats))) + 1
        let subdivision = Int((beats * 960).truncatingRemainder(dividingBy: 960)) // MIDI PPQ = 960

        return BarBeat(bar: bar, beat: beat, subdivision: subdivision)
    }

    /// Convert bar/beat to samples
    func barBeatToSamples(_ barBeat: BarBeat) -> Int64 {
        let totalBeats = Double(barBeat.bar - 1) * Double(timeSignature.beats) + Double(barBeat.beat - 1)
        let seconds = totalBeats / (tempo / 60.0)
        return Int64(seconds * sampleRate)
    }

    /// Convert seconds to samples
    func secondsToSamples(_ seconds: TimeInterval) -> Int64 {
        Int64(seconds * sampleRate)
    }

    /// Convert samples to seconds
    func samplesToSeconds(_ samples: Int64) -> TimeInterval {
        Double(samples) / sampleRate
    }


    // MARK: - Markers

    /// Add marker at current position
    func addMarker(name: String) {
        let marker = Marker(
            name: name,
            position: playheadPosition,
            color: .blue
        )
        markers.append(marker)
        markers.sort { $0.position < $1.position }
        modifiedAt = Date()
    }

    /// Remove marker
    func removeMarker(_ marker: Marker) {
        markers.removeAll { $0.id == marker.id }
        modifiedAt = Date()
    }

    /// Navigate to next marker
    func goToNextMarker() {
        guard let nextMarker = markers.first(where: { $0.position > playheadPosition }) else { return }
        seek(to: nextMarker.position)
    }

    /// Navigate to previous marker
    func goToPreviousMarker() {
        guard let prevMarker = markers.last(where: { $0.position < playheadPosition }) else { return }
        seek(to: prevMarker.position)
    }


    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, sampleRate, tempo, timeSignature, tracks
        case playheadPosition, length, markers, automationLanes
        case metronomeEnabled, countInBars, createdAt, modifiedAt
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        sampleRate = try container.decode(Double.self, forKey: .sampleRate)
        tempo = try container.decode(Double.self, forKey: .tempo)
        timeSignature = try container.decode(TimeSignature.self, forKey: .timeSignature)
        tracks = try container.decode([Track].self, forKey: .tracks)
        playheadPosition = try container.decode(Int64.self, forKey: .playheadPosition)
        length = try container.decode(Int64.self, forKey: .length)
        markers = try container.decode([Marker].self, forKey: .markers)
        automationLanes = try container.decode([AutomationLane].self, forKey: .automationLanes)
        metronomeEnabled = try container.decode(Bool.self, forKey: .metronomeEnabled)
        countInBars = try container.decode(Int.self, forKey: .countInBars)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)

        // Published properties
        isPlaying = false
        isRecording = false
        isLooping = false
        loopRange = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(sampleRate, forKey: .sampleRate)
        try container.encode(tempo, forKey: .tempo)
        try container.encode(timeSignature, forKey: .timeSignature)
        try container.encode(tracks, forKey: .tracks)
        try container.encode(playheadPosition, forKey: .playheadPosition)
        try container.encode(length, forKey: .length)
        try container.encode(markers, forKey: .markers)
        try container.encode(automationLanes, forKey: .automationLanes)
        try container.encode(metronomeEnabled, forKey: .metronomeEnabled)
        try container.encode(countInBars, forKey: .countInBars)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
    }
}


// MARK: - Supporting Types

/// Time signature
struct TimeSignature: Codable, Equatable {
    var beats: Int          // Numerator (4 in 4/4)
    var noteValue: Int      // Denominator (4 in 4/4)

    var description: String {
        "\(beats)/\(noteValue)"
    }
}

/// Bar/Beat position
struct BarBeat: Equatable, CustomStringConvertible {
    var bar: Int            // Bar number (1-based)
    var beat: Int           // Beat within bar (1-based)
    var subdivision: Int    // Subdivision (960 PPQ)

    init(bar: Int, beat: Int, subdivision: Int = 0) {
        self.bar = bar
        self.beat = beat
        self.subdivision = subdivision
    }

    var description: String {
        "\(bar).\(beat).\(subdivision)"
    }
}

/// Timeline marker
struct Marker: Identifiable, Codable {
    let id: UUID
    var name: String
    var position: Int64     // Position in samples
    var color: MarkerColor

    init(id: UUID = UUID(), name: String, position: Int64, color: MarkerColor) {
        self.id = id
        self.name = name
        self.position = position
        self.color = color
    }
}

/// Marker colors
enum MarkerColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, pink, gray
}

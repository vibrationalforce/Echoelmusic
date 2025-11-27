//
//  DAWTimelineEngine.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  PROFESSIONAL DAW TIMELINE ENGINE
//  Multiple time signatures, tempo changes, beat grid, quantization
//
//  **Features:**
//  - Multiple time signatures in one session (4/4, 3/4, 5/4, 7/8, etc.)
//  - Sample-accurate timing
//  - Beat grid generation
//  - Quantization engine
//  - SMPTE timecode support
//  - Musical time (bars/beats) ↔ Sample time conversion
//

import Foundation
import AVFoundation

// MARK: - Timeline Engine

/// Professional DAW timeline engine with time signature support
@MainActor
class DAWTimelineEngine: ObservableObject {
    static let shared = DAWTimelineEngine()

    // MARK: - Published Properties

    @Published var currentPosition: TimelinePosition = .zero
    @Published var isPlaying: Bool = false
    @Published var isRecording: Bool = false
    @Published var loopEnabled: Bool = false
    @Published var loopRange: ClosedRange<TimelinePosition>?

    // Project settings
    @Published var sampleRate: Double = 48000.0
    @Published var projectLength: TimeInterval = 300.0  // 5 minutes default

    // Transport
    private var audioEngine = AVAudioEngine()
    private var lastUpdateTime: Date?

    // Timeline data
    private(set) var timeSignatures: [TimeSignatureMarker] = []
    private(set) var markers: [TimelineMarker] = []
    private(set) var regions: [TimelineRegion] = []

    // MARK: - Time Signature

    /// Time signature (e.g., 4/4, 3/4, 7/8)
    struct TimeSignature: Codable, Equatable {
        let numerator: Int      // Beats per bar (top number)
        let denominator: Int    // Note value (bottom number: 4=quarter, 8=eighth)

        // Common time signatures
        static let fourFour = TimeSignature(numerator: 4, denominator: 4)
        static let threeFour = TimeSignature(numerator: 3, denominator: 4)
        static let sixEight = TimeSignature(numerator: 6, denominator: 8)
        static let fiveFour = TimeSignature(numerator: 5, denominator: 4)
        static let sevenEight = TimeSignature(numerator: 7, denominator: 8)
        static let fiveEight = TimeSignature(numerator: 5, denominator: 8)
        static let nineEight = TimeSignature(numerator: 9, denominator: 8)
        static let twelveEight = TimeSignature(numerator: 12, denominator: 8)
        static let sevenFour = TimeSignature(numerator: 7, denominator: 4)
        static let elevenEight = TimeSignature(numerator: 11, denominator: 8)

        var description: String {
            "\(numerator)/\(denominator)"
        }

        /// Beats per bar
        var beatsPerBar: Int { numerator }

        /// Note value for one beat (in quarter notes)
        var beatValue: Double { 4.0 / Double(denominator) }
    }

    /// Time signature marker at a specific position
    struct TimeSignatureMarker: Identifiable, Codable {
        let id: UUID
        let position: TimelinePosition  // When this time signature starts
        let timeSignature: TimeSignature

        init(position: TimelinePosition, timeSignature: TimeSignature) {
            self.id = UUID()
            self.position = position
            self.timeSignature = timeSignature
        }
    }

    // MARK: - Timeline Position

    /// Position in the timeline (can be represented in multiple formats)
    struct TimelinePosition: Codable, Equatable, Comparable {
        let samples: Int64  // Master reference (sample-accurate)

        static let zero = TimelinePosition(samples: 0)

        // MARK: - Initializers

        init(samples: Int64) {
            self.samples = samples
        }

        init(seconds: TimeInterval, sampleRate: Double) {
            self.samples = Int64(seconds * sampleRate)
        }

        init(bars: Int, beats: Int, ticks: Int, timeSignature: TimeSignature, tempo: Double, sampleRate: Double) {
            // Convert musical time to samples
            // 1 bar = timeSignature.beatsPerBar beats
            // 1 beat = (60.0 / tempo) seconds at quarter note
            // Adjust for time signature's beat value

            let totalBeats = Double(bars) * Double(timeSignature.beatsPerBar) + Double(beats)
            let beatDuration = (60.0 / tempo) * timeSignature.beatValue
            let tickDuration = beatDuration / 960.0  // 960 ticks per beat (MIDI standard)

            let seconds = totalBeats * beatDuration + Double(ticks) * tickDuration
            self.samples = Int64(seconds * sampleRate)
        }

        init(smpte: SMPTETimecode, sampleRate: Double) {
            let seconds = smpte.totalSeconds
            self.samples = Int64(seconds * sampleRate)
        }

        // MARK: - Conversions

        func toSeconds(sampleRate: Double) -> TimeInterval {
            Double(samples) / sampleRate
        }

        func toMusicalTime(timeSignature: TimeSignature, tempo: Double, sampleRate: Double) -> MusicalTime {
            let seconds = toSeconds(sampleRate: sampleRate)
            let beatDuration = (60.0 / tempo) * timeSignature.beatValue
            let totalBeats = seconds / beatDuration

            let bars = Int(totalBeats) / timeSignature.beatsPerBar
            let beats = Int(totalBeats) % timeSignature.beatsPerBar
            let fractionalBeat = totalBeats - floor(totalBeats)
            let ticks = Int(fractionalBeat * 960.0)

            return MusicalTime(bars: bars, beats: beats, ticks: ticks)
        }

        func toSMPTE(frameRate: SMPTEFrameRate = .fps30, sampleRate: Double) -> SMPTETimecode {
            let seconds = toSeconds(sampleRate: sampleRate)
            return SMPTETimecode(seconds: seconds, frameRate: frameRate)
        }

        // MARK: - Comparable

        static func < (lhs: TimelinePosition, rhs: TimelinePosition) -> Bool {
            lhs.samples < rhs.samples
        }

        // MARK: - Arithmetic

        static func + (lhs: TimelinePosition, rhs: TimelinePosition) -> TimelinePosition {
            TimelinePosition(samples: lhs.samples + rhs.samples)
        }

        static func - (lhs: TimelinePosition, rhs: TimelinePosition) -> TimelinePosition {
            TimelinePosition(samples: lhs.samples - rhs.samples)
        }
    }

    /// Musical time (bars, beats, ticks)
    struct MusicalTime: Codable, Equatable {
        let bars: Int       // Bar number (0-based)
        let beats: Int      // Beat within bar (0-based)
        let ticks: Int      // Tick within beat (0-959, 960 ticks per beat)

        static let zero = MusicalTime(bars: 0, beats: 0, ticks: 0)

        var description: String {
            "\(bars + 1).\(beats + 1).\(String(format: "%03d", ticks))"
        }
    }

    /// SMPTE timecode
    struct SMPTETimecode: Codable, Equatable {
        let hours: Int
        let minutes: Int
        let seconds: Int
        let frames: Int
        let frameRate: SMPTEFrameRate

        init(seconds totalSeconds: TimeInterval, frameRate: SMPTEFrameRate) {
            self.frameRate = frameRate

            let hours = Int(totalSeconds / 3600)
            let minutes = Int((totalSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
            let seconds = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
            let frames = Int((totalSeconds - floor(totalSeconds)) * frameRate.fps)

            self.hours = hours
            self.minutes = minutes
            self.seconds = seconds
            self.frames = frames
        }

        var totalSeconds: TimeInterval {
            Double(hours) * 3600.0 +
            Double(minutes) * 60.0 +
            Double(seconds) +
            Double(frames) / frameRate.fps
        }

        var description: String {
            String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
        }
    }

    enum SMPTEFrameRate: String, Codable, CaseIterable {
        case fps24 = "24 fps"
        case fps25 = "25 fps"
        case fps30 = "30 fps"
        case fps30Drop = "29.97 fps (Drop)"
        case fps60 = "60 fps"

        var fps: Double {
            switch self {
            case .fps24: return 24.0
            case .fps25: return 25.0
            case .fps30: return 30.0
            case .fps30Drop: return 29.97
            case .fps60: return 60.0
            }
        }
    }

    // MARK: - Timeline Markers

    /// Timeline marker (for navigation)
    struct TimelineMarker: Identifiable, Codable {
        let id: UUID
        let position: TimelinePosition
        let name: String
        let color: String  // Color name or hex

        init(position: TimelinePosition, name: String, color: String = "cyan") {
            self.id = UUID()
            self.position = position
            self.name = name
            self.color = color
        }
    }

    /// Timeline region (for loops, selections, etc.)
    struct TimelineRegion: Identifiable, Codable {
        let id: UUID
        let startPosition: TimelinePosition
        let endPosition: TimelinePosition
        let name: String
        let color: String

        init(start: TimelinePosition, end: TimelinePosition, name: String, color: String = "blue") {
            self.id = UUID()
            self.startPosition = start
            self.endPosition = end
            self.name = name
            self.color = color
        }

        var length: TimelinePosition {
            endPosition - startPosition
        }
    }

    // MARK: - Time Signature Management

    /// Add a time signature change at a position
    func addTimeSignature(_ timeSignature: TimeSignature, at position: TimelinePosition) {
        let marker = TimeSignatureMarker(position: position, timeSignature: timeSignature)
        timeSignatures.append(marker)
        timeSignatures.sort { $0.position < $1.position }
        print("➕ Added time signature \(timeSignature.description) at \(position.samples) samples")
    }

    /// Remove time signature at position
    func removeTimeSignature(at position: TimelinePosition) {
        timeSignatures.removeAll { $0.position == position }
        print("➖ Removed time signature at \(position.samples) samples")
    }

    /// Get active time signature at a given position
    func timeSignature(at position: TimelinePosition) -> TimeSignature {
        // Find the most recent time signature before or at this position
        let activeMarker = timeSignatures
            .filter { $0.position <= position }
            .sorted { $0.position > $1.position }
            .first

        return activeMarker?.timeSignature ?? .fourFour  // Default to 4/4
    }

    /// Get all time signature changes in a range
    func timeSignatureChanges(in range: ClosedRange<TimelinePosition>) -> [TimeSignatureMarker] {
        timeSignatures.filter { range.contains($0.position) }
    }

    // MARK: - Beat Grid Generation

    /// Generate beat grid for the entire timeline
    func generateBeatGrid(tempo: Double) -> [BeatGridPoint] {
        var grid: [BeatGridPoint] = []
        var currentPosition: TimelinePosition = .zero
        var currentBar = 0
        var currentBeat = 0

        let projectSamples = Int64(projectLength * sampleRate)

        while currentPosition.samples < projectSamples {
            let timeSignature = self.timeSignature(at: currentPosition)

            // Add grid point
            grid.append(BeatGridPoint(
                position: currentPosition,
                bar: currentBar,
                beat: currentBeat,
                timeSignature: timeSignature,
                isDownbeat: currentBeat == 0
            ))

            // Calculate next beat position
            let beatDuration = (60.0 / tempo) * timeSignature.beatValue
            let beatSamples = Int64(beatDuration * sampleRate)
            currentPosition = TimelinePosition(samples: currentPosition.samples + beatSamples)

            // Update bar/beat counters
            currentBeat += 1
            if currentBeat >= timeSignature.beatsPerBar {
                currentBeat = 0
                currentBar += 1
            }
        }

        return grid
    }

    struct BeatGridPoint: Identifiable {
        let id = UUID()
        let position: TimelinePosition
        let bar: Int
        let beat: Int
        let timeSignature: TimeSignature
        let isDownbeat: Bool  // First beat of the bar
    }

    // MARK: - Quantization

    /// Quantize a position to the nearest beat grid point
    func quantize(
        position: TimelinePosition,
        to division: QuantizeDivision,
        tempo: Double,
        strength: Double = 1.0  // 0-1, 0 = no quantization, 1 = full snap
    ) -> TimelinePosition {
        let grid = generateBeatGrid(tempo: tempo)

        // Find nearest grid point with the specified division
        let filteredGrid = grid.filter { point in
            switch division {
            case .bar:
                return point.isDownbeat
            case .beat:
                return true
            case .half:
                return point.beat % 2 == 0
            case .quarter:
                return true  // All beats
            case .eighth:
                return true  // Would need sub-beat grid
            case .sixteenth:
                return true  // Would need sub-beat grid
            case .triplet:
                return true  // Would need triplet grid
            }
        }

        guard let nearest = filteredGrid.min(by: { abs($0.position.samples - position.samples) < abs($1.position.samples - position.samples) }) else {
            return position
        }

        // Apply quantization strength
        let delta = nearest.position.samples - position.samples
        let quantizedSamples = position.samples + Int64(Double(delta) * strength)

        return TimelinePosition(samples: quantizedSamples)
    }

    enum QuantizeDivision: String, CaseIterable {
        case bar = "Bar"
        case beat = "Beat"
        case half = "1/2"
        case quarter = "1/4"
        case eighth = "1/8"
        case sixteenth = "1/16"
        case triplet = "Triplet"
    }

    // MARK: - Markers & Regions

    func addMarker(at position: TimelinePosition, name: String, color: String = "cyan") {
        let marker = TimelineMarker(position: position, name: name, color: color)
        markers.append(marker)
        markers.sort { $0.position < $1.position }
        print("📍 Added marker '\(name)' at \(position.samples) samples")
    }

    func removeMarker(id: UUID) {
        markers.removeAll { $0.id == id }
    }

    func addRegion(start: TimelinePosition, end: TimelinePosition, name: String, color: String = "blue") {
        let region = TimelineRegion(start: start, end: end, name: name, color: color)
        regions.append(region)
        print("📏 Added region '\(name)' from \(start.samples) to \(end.samples) samples")
    }

    func removeRegion(id: UUID) {
        regions.removeAll { $0.id == id }
    }

    // MARK: - Transport Control

    func play() {
        isPlaying = true
        lastUpdateTime = Date()
        print("▶️ Timeline playing from \(currentPosition.samples) samples")
    }

    func pause() {
        isPlaying = false
        print("⏸️ Timeline paused at \(currentPosition.samples) samples")
    }

    func stop() {
        isPlaying = false
        currentPosition = .zero
        print("⏹️ Timeline stopped")
    }

    func seek(to position: TimelinePosition) {
        currentPosition = position
        print("⏩ Seeked to \(position.samples) samples")
    }

    func setLoop(start: TimelinePosition, end: TimelinePosition) {
        loopRange = start...end
        loopEnabled = true
        print("🔁 Loop set: \(start.samples) - \(end.samples) samples")
    }

    func disableLoop() {
        loopEnabled = false
        loopRange = nil
        print("🔁 Loop disabled")
    }

    // MARK: - Update

    func update() {
        guard isPlaying, let lastTime = lastUpdateTime else { return }

        let now = Date()
        let deltaTime = now.timeIntervalSince(lastTime)
        let deltaSamples = Int64(deltaTime * sampleRate)

        currentPosition = TimelinePosition(samples: currentPosition.samples + deltaSamples)

        // Handle looping
        if loopEnabled, let loop = loopRange {
            if currentPosition > loop.upperBound {
                currentPosition = loop.lowerBound
            }
        }

        lastUpdateTime = now
    }

    // MARK: - Initialization

    private init() {
        // Add default time signature at start
        addTimeSignature(.fourFour, at: .zero)
    }
}

// MARK: - Debug

#if DEBUG
extension DAWTimelineEngine {
    func testTimelineEngine() {
        print("🧪 Testing Timeline Engine...")

        // Test time signature changes
        addTimeSignature(.fourFour, at: .zero)
        addTimeSignature(.threeFour, at: TimelinePosition(seconds: 10.0, sampleRate: sampleRate))
        addTimeSignature(.sevenEight, at: TimelinePosition(seconds: 20.0, sampleRate: sampleRate))

        // Test beat grid
        let grid = generateBeatGrid(tempo: 120.0)
        print("  Generated \(grid.count) beat grid points")

        // Test quantization
        let testPosition = TimelinePosition(seconds: 5.5, sampleRate: sampleRate)
        let quantized = quantize(position: testPosition, to: .beat, tempo: 120.0)
        print("  Quantized \(testPosition.samples) → \(quantized.samples) samples")

        // Test musical time conversion
        let musicalPos = TimelinePosition(bars: 4, beats: 2, ticks: 480, timeSignature: .fourFour, tempo: 120.0, sampleRate: sampleRate)
        let musicalTime = musicalPos.toMusicalTime(timeSignature: .fourFour, tempo: 120.0, sampleRate: sampleRate)
        print("  Musical time: \(musicalTime.description)")

        // Test SMPTE
        let smpte = testPosition.toSMPTE(sampleRate: sampleRate)
        print("  SMPTE: \(smpte.description)")

        print("✅ Timeline Engine test complete")
    }
}
#endif

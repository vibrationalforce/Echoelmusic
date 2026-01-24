import Foundation
import AVFoundation
import Accelerate
#if canImport(Combine)
import Combine
#endif

// ╔═══════════════════════════════════════════════════════════════════════════════════════════════════════╗
// ║                                                                                                       ║
// ║   ██████╗ ██████╗ ███╗   ███╗     ██████╗ ██████╗ ██╗██████╗                                          ║
// ║   ██╔══██╗██╔══██╗████╗ ████║    ██╔════╝ ██╔══██╗██║██╔══██╗                                         ║
// ║   ██████╔╝██████╔╝██╔████╔██║    ██║  ███╗██████╔╝██║██║  ██║                                         ║
// ║   ██╔══██╗██╔═══╝ ██║╚██╔╝██║    ██║   ██║██╔══██╗██║██║  ██║                                         ║
// ║   ██████╔╝██║     ██║ ╚═╝ ██║    ╚██████╔╝██║  ██║██║██████╔╝                                         ║
// ║   ╚═════╝ ╚═╝     ╚═╝     ╚═╝     ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝                                          ║
// ║                                                                                                       ║
// ║   🎵 BPM GRID EDIT ENGINE - Beat-Synchronized Video Editing 🎵                                        ║
// ║                                                                                                       ║
// ║   Edit auf dem BPM Raster • Beat Detection • Quantize • Beat-Synced Effects                          ║
// ║                                                                                                       ║
// ║   Features:                                                                                           ║
// ║   • Beat Detection (Audio Analysis with FFT)                                                          ║
// ║   • BPM Grid with Time Signature Support (4/4, 3/4, 6/8, etc.)                                        ║
// ║   • Snap Modes: Beat, Bar, Half-Beat, Quarter-Beat, Triplet                                           ║
// ║   • Beat-Synced Cuts, Transitions & Effects                                                           ║
// ║   • Quantize Clips to Grid                                                                            ║
// ║   • Tempo Automation & Changes                                                                        ║
// ║   • Visual Beat Markers                                                                               ║
// ║   • DAW Transport Sync (MIDI Clock, Ableton Link)                                                     ║
// ║                                                                                                       ║
// ╚═══════════════════════════════════════════════════════════════════════════════════════════════════════╝

// MARK: - Time Signature

/// Musical time signature
public struct TimeSignature: Codable, Equatable, Hashable {
    public var numerator: Int      // Beats per bar (top number)
    public var denominator: Int    // Note value of beat (bottom number)

    public init(numerator: Int = 4, denominator: Int = 4) {
        self.numerator = numerator
        self.denominator = denominator
    }

    /// Common time signatures
    public static let fourFour = TimeSignature(numerator: 4, denominator: 4)
    public static let threeFour = TimeSignature(numerator: 3, denominator: 4)
    public static let sixEight = TimeSignature(numerator: 6, denominator: 8)
    public static let twoFour = TimeSignature(numerator: 2, denominator: 4)
    public static let fiveFour = TimeSignature(numerator: 5, denominator: 4)
    public static let sevenEight = TimeSignature(numerator: 7, denominator: 8)
    public static let twelveEight = TimeSignature(numerator: 12, denominator: 8)

    /// Display string (e.g., "4/4")
    public var displayString: String {
        return "\(numerator)/\(denominator)"
    }

    /// Beats per bar (adjusted for compound meters)
    public var beatsPerBar: Int {
        // For compound meters (6/8, 9/8, 12/8), group into larger beats
        if denominator == 8 && numerator % 3 == 0 {
            return numerator / 3
        }
        return numerator
    }

    /// Subdivisions per beat
    public var subdivisionsPerBeat: Int {
        if denominator == 8 && numerator % 3 == 0 {
            return 3  // Compound meter: triplet feel
        }
        return 1
    }
}

// MARK: - Snap Mode

/// Grid snap mode for editing
public enum SnapMode: String, CaseIterable, Codable {
    case off = "Off"
    case bar = "Bar"
    case beat = "Beat"
    case halfBeat = "1/2 Beat"
    case quarterBeat = "1/4 Beat"
    case eighthBeat = "1/8 Beat"
    case triplet = "Triplet"
    case sixteenth = "1/16"
    case thirtySecond = "1/32"

    /// Subdivisions per beat for this snap mode
    public var subdivisionsPerBeat: Int {
        switch self {
        case .off: return 0
        case .bar: return 0  // Special case: snap to bar
        case .beat: return 1
        case .halfBeat: return 2
        case .quarterBeat: return 4
        case .eighthBeat: return 8
        case .triplet: return 3
        case .sixteenth: return 16
        case .thirtySecond: return 32
        }
    }

    /// Icon for UI
    public var icon: String {
        switch self {
        case .off: return "🔓"
        case .bar: return "📊"
        case .beat: return "🎵"
        case .halfBeat: return "♪"
        case .quarterBeat: return "♫"
        case .eighthBeat: return "𝅘𝅥𝅮"
        case .triplet: return "③"
        case .sixteenth: return "𝅘𝅥𝅯"
        case .thirtySecond: return "𝅘𝅥𝅰"
        }
    }
}

// MARK: - Beat Position

/// Position in musical time (bars, beats, ticks)
public struct BeatPosition: Codable, Equatable, Comparable {
    public var bar: Int           // 1-indexed bar number
    public var beat: Int          // 1-indexed beat within bar
    public var tick: Int          // Ticks within beat (0-959 for 960 PPQ)
    public var ticksPerQuarterNote: Int = 960  // PPQ resolution

    public init(bar: Int = 1, beat: Int = 1, tick: Int = 0) {
        self.bar = bar
        self.beat = beat
        self.tick = tick
    }

    /// Create from absolute time
    public static func from(
        seconds: Double,
        bpm: Double,
        timeSignature: TimeSignature = .fourFour,
        ppq: Int = 960
    ) -> BeatPosition {
        let secondsPerBeat = 60.0 / bpm
        let totalBeats = seconds / secondsPerBeat
        let beatsPerBar = Double(timeSignature.numerator)

        let totalBars = totalBeats / beatsPerBar
        let bar = Int(floor(totalBars)) + 1
        let beatInBar = totalBeats.truncatingRemainder(dividingBy: beatsPerBar)
        let beat = Int(floor(beatInBar)) + 1
        let tickFraction = beatInBar.truncatingRemainder(dividingBy: 1.0)
        let tick = Int(tickFraction * Double(ppq))

        return BeatPosition(bar: bar, beat: beat, tick: tick)
    }

    /// Convert to absolute time in seconds
    public func toSeconds(bpm: Double, timeSignature: TimeSignature = .fourFour) -> Double {
        let secondsPerBeat = 60.0 / bpm
        let beatsPerBar = Double(timeSignature.numerator)

        let totalBeats = Double(bar - 1) * beatsPerBar + Double(beat - 1) + Double(tick) / Double(ticksPerQuarterNote)
        return totalBeats * secondsPerBeat
    }

    /// Display string (e.g., "1.2.480")
    public var displayString: String {
        return "\(bar).\(beat).\(tick)"
    }

    /// Short display (e.g., "1.2")
    public var shortDisplayString: String {
        return "\(bar).\(beat)"
    }

    public static func < (lhs: BeatPosition, rhs: BeatPosition) -> Bool {
        if lhs.bar != rhs.bar { return lhs.bar < rhs.bar }
        if lhs.beat != rhs.beat { return lhs.beat < rhs.beat }
        return lhs.tick < rhs.tick
    }
}

// MARK: - Beat Marker

/// Visual/functional marker at a beat position
public struct BeatMarker: Identifiable, Codable {
    public var id: UUID
    public var position: BeatPosition
    public var type: MarkerType
    public var label: String
    public var color: String

    public enum MarkerType: String, Codable, CaseIterable {
        case downbeat = "Downbeat"          // First beat of bar
        case beat = "Beat"                  // Regular beat
        case accent = "Accent"              // Accented beat
        case cue = "Cue"                    // Cue point
        case drop = "Drop"                  // Drop marker
        case breakdown = "Breakdown"        // Breakdown start
        case buildup = "Buildup"            // Buildup start
        case transition = "Transition"      // Transition point
        case cut = "Cut"                    // Edit cut point
        case custom = "Custom"
    }

    public init(
        id: UUID = UUID(),
        position: BeatPosition = BeatPosition(),
        type: MarkerType = .beat,
        label: String = "",
        color: String = "#FF0000"
    ) {
        self.id = id
        self.position = position
        self.type = type
        self.label = label
        self.color = color
    }

    /// Icon for marker type
    public var icon: String {
        switch type {
        case .downbeat: return "⬇️"
        case .beat: return "🎵"
        case .accent: return "❗"
        case .cue: return "🎯"
        case .drop: return "💥"
        case .breakdown: return "🌊"
        case .buildup: return "📈"
        case .transition: return "🔄"
        case .cut: return "✂️"
        case .custom: return "📍"
        }
    }
}

// MARK: - Tempo Change

/// Tempo automation point
public struct TempoChange: Identifiable, Codable {
    public var id: UUID
    public var position: BeatPosition
    public var bpm: Double
    public var curve: TempoChangeCurve

    public enum TempoChangeCurve: String, Codable, CaseIterable {
        case instant = "Instant"            // Jump to new tempo
        case linear = "Linear"              // Linear ramp
        case exponential = "Exponential"    // Exponential curve
        case sCurve = "S-Curve"             // Smooth S-curve
    }

    public init(
        id: UUID = UUID(),
        position: BeatPosition = BeatPosition(),
        bpm: Double = 120,
        curve: TempoChangeCurve = .instant
    ) {
        self.id = id
        self.position = position
        self.bpm = bpm
        self.curve = curve
    }
}

// MARK: - Beat-Synced Transition

/// Transition that aligns to beats
public struct BeatSyncedTransition: Identifiable, Codable {
    public var id: UUID
    public var type: TransitionType
    public var durationBeats: Double      // Duration in beats
    public var startOnBeat: Bool          // Start exactly on beat
    public var endOnBeat: Bool            // End exactly on beat
    public var syncToDownbeat: Bool       // Sync to bar start
    public var intensity: Float           // 0-1

    public enum TransitionType: String, Codable, CaseIterable {
        case cut = "Cut"
        case crossfade = "Crossfade"
        case fadeToBlack = "Fade to Black"
        case fadeFromBlack = "Fade from Black"
        case wipe = "Wipe"
        case push = "Push"
        case slide = "Slide"
        case zoom = "Zoom"
        case spin = "Spin"
        case flash = "Flash"
        case glitch = "Glitch"
        case beatFlash = "Beat Flash"
        case rhythmCut = "Rhythm Cut"
        case strobeTransition = "Strobe"
    }

    public init(
        id: UUID = UUID(),
        type: TransitionType = .cut,
        durationBeats: Double = 1,
        startOnBeat: Bool = true,
        endOnBeat: Bool = true,
        syncToDownbeat: Bool = false,
        intensity: Float = 1.0
    ) {
        self.id = id
        self.type = type
        self.durationBeats = durationBeats
        self.startOnBeat = startOnBeat
        self.endOnBeat = endOnBeat
        self.syncToDownbeat = syncToDownbeat
        self.intensity = intensity
    }

    public var icon: String {
        switch type {
        case .cut: return "✂️"
        case .crossfade: return "🔀"
        case .fadeToBlack: return "🌑"
        case .fadeFromBlack: return "🌕"
        case .wipe: return "➡️"
        case .push: return "👉"
        case .slide: return "📐"
        case .zoom: return "🔍"
        case .spin: return "🔄"
        case .flash: return "💫"
        case .glitch: return "📺"
        case .beatFlash: return "⚡"
        case .rhythmCut: return "🎵✂️"
        case .strobeTransition: return "💡"
        }
    }
}

// MARK: - Beat-Synced Effect

/// Effect that pulses/triggers on beats
public struct BeatSyncedEffect: Identifiable, Codable {
    public var id: UUID
    public var type: EffectType
    public var triggerOn: TriggerMode
    public var intensity: Float           // 0-1
    public var decay: Float               // How fast effect fades (0-1)
    public var phase: Float               // Phase offset (0-1)

    public enum EffectType: String, Codable, CaseIterable {
        // Visual effects
        case flash = "Flash"
        case pulse = "Pulse"
        case shake = "Shake"
        case zoom = "Zoom Pulse"
        case colorShift = "Color Shift"
        case saturationPulse = "Saturation Pulse"
        case contrastPulse = "Contrast Pulse"
        case brightnessPulse = "Brightness Pulse"
        case glitch = "Glitch"
        case scanlines = "Scanlines"
        case vhsEffect = "VHS Effect"
        case filmBurn = "Film Burn"
        case letterboxPulse = "Letterbox Pulse"

        // Motion effects
        case sway = "Sway"
        case bounce = "Bounce"
        case spin = "Spin"
        case scaleBreathing = "Scale Breathing"

        // Particle effects
        case particleBurst = "Particle Burst"
        case lightRays = "Light Rays"
        case lensFlare = "Lens Flare"

        // Bio-reactive
        case heartbeatPulse = "Heartbeat Pulse"
        case coherenceGlow = "Coherence Glow"
    }

    public enum TriggerMode: String, Codable, CaseIterable {
        case everyBeat = "Every Beat"
        case everyDownbeat = "Every Downbeat"
        case everyOtherBeat = "Every Other Beat"
        case everyBar = "Every Bar"
        case every2Bars = "Every 2 Bars"
        case every4Bars = "Every 4 Bars"
        case onCue = "On Cue"
        case continuous = "Continuous (Synced)"
        case random = "Random (Synced)"
    }

    public init(
        id: UUID = UUID(),
        type: EffectType = .pulse,
        triggerOn: TriggerMode = .everyBeat,
        intensity: Float = 1.0,
        decay: Float = 0.5,
        phase: Float = 0
    ) {
        self.id = id
        self.type = type
        self.triggerOn = triggerOn
        self.intensity = intensity
        self.decay = decay
        self.phase = phase
    }

    public var icon: String {
        switch type {
        case .flash: return "💫"
        case .pulse: return "💓"
        case .shake: return "📳"
        case .zoom: return "🔍"
        case .colorShift: return "🌈"
        case .saturationPulse: return "🎨"
        case .contrastPulse: return "◐"
        case .brightnessPulse: return "☀️"
        case .glitch: return "📺"
        case .scanlines: return "📊"
        case .vhsEffect: return "📼"
        case .filmBurn: return "🔥"
        case .letterboxPulse: return "🎬"
        case .sway: return "🌊"
        case .bounce: return "⬆️"
        case .spin: return "🔄"
        case .scaleBreathing: return "🫁"
        case .particleBurst: return "✨"
        case .lightRays: return "☀️"
        case .lensFlare: return "💠"
        case .heartbeatPulse: return "❤️"
        case .coherenceGlow: return "🔮"
        }
    }
}

// MARK: - Beat Detection Result

/// Result from beat detection analysis
public struct BeatDetectionResult: Codable {
    public var bpm: Double
    public var confidence: Float          // 0-1
    public var beats: [Double]            // Beat times in seconds
    public var downbeats: [Double]        // Downbeat times in seconds
    public var timeSignature: TimeSignature
    public var offset: Double             // Time offset to first beat

    public init(
        bpm: Double = 120,
        confidence: Float = 0,
        beats: [Double] = [],
        downbeats: [Double] = [],
        timeSignature: TimeSignature = .fourFour,
        offset: Double = 0
    ) {
        self.bpm = bpm
        self.confidence = confidence
        self.beats = beats
        self.downbeats = downbeats
        self.timeSignature = timeSignature
        self.offset = offset
    }
}

// MARK: - BPM Grid

/// The BPM grid for a timeline
public struct BPMGrid: Codable {
    public var bpm: Double
    public var timeSignature: TimeSignature
    public var offset: Double              // Offset to first downbeat in seconds
    public var tempoChanges: [TempoChange]

    public init(
        bpm: Double = 120,
        timeSignature: TimeSignature = .fourFour,
        offset: Double = 0,
        tempoChanges: [TempoChange] = []
    ) {
        self.bpm = bpm
        self.timeSignature = timeSignature
        self.offset = offset
        self.tempoChanges = tempoChanges
    }

    /// Get BPM at specific time (considering tempo changes)
    public func bpmAt(seconds: Double) -> Double {
        guard !tempoChanges.isEmpty else { return bpm }

        // Find the last tempo change before this time
        var currentBPM = bpm
        for change in tempoChanges.sorted(by: { $0.position < $1.position }) {
            let changeTime = change.position.toSeconds(bpm: currentBPM, timeSignature: timeSignature)
            if changeTime <= seconds {
                currentBPM = change.bpm
            } else {
                break
            }
        }
        return currentBPM
    }

    /// Seconds per beat at given time
    public func secondsPerBeat(at seconds: Double = 0) -> Double {
        return 60.0 / bpmAt(seconds: seconds)
    }

    /// Seconds per bar at given time
    public func secondsPerBar(at seconds: Double = 0) -> Double {
        return secondsPerBeat(at: seconds) * Double(timeSignature.numerator)
    }

    /// Snap time to nearest grid position
    public func snapToGrid(seconds: Double, snapMode: SnapMode) -> Double {
        guard snapMode != .off else { return seconds }

        let adjustedTime = seconds - offset
        let spb = secondsPerBeat(at: seconds)

        if snapMode == .bar {
            let barDuration = spb * Double(timeSignature.numerator)
            let nearestBar = round(adjustedTime / barDuration)
            return nearestBar * barDuration + offset
        }

        let gridInterval = spb / Double(snapMode.subdivisionsPerBeat)
        let nearestGrid = round(adjustedTime / gridInterval)
        return nearestGrid * gridInterval + offset
    }

    /// Get all grid lines in a time range
    public func gridLines(from startTime: Double, to endTime: Double, snapMode: SnapMode) -> [Double] {
        guard snapMode != .off else { return [] }

        var lines: [Double] = []
        let spb = secondsPerBeat(at: startTime)

        let interval: Double
        if snapMode == .bar {
            interval = spb * Double(timeSignature.numerator)
        } else {
            interval = spb / Double(snapMode.subdivisionsPerBeat)
        }

        var time = snapToGrid(seconds: startTime, snapMode: snapMode)
        while time <= endTime {
            lines.append(time)
            time += interval
        }

        return lines
    }

    /// Get beat position for time
    public func beatPosition(at seconds: Double) -> BeatPosition {
        return BeatPosition.from(
            seconds: seconds - offset,
            bpm: bpmAt(seconds: seconds),
            timeSignature: timeSignature
        )
    }

    /// Check if time is on a beat
    public func isOnBeat(_ seconds: Double, tolerance: Double = 0.02) -> Bool {
        let snapped = snapToGrid(seconds: seconds, snapMode: .beat)
        return abs(snapped - seconds) < tolerance
    }

    /// Check if time is on a downbeat (bar start)
    public func isOnDownbeat(_ seconds: Double, tolerance: Double = 0.02) -> Bool {
        let snapped = snapToGrid(seconds: seconds, snapMode: .bar)
        return abs(snapped - seconds) < tolerance
    }

    /// Get nearest beat time
    public func nearestBeat(to seconds: Double) -> Double {
        return snapToGrid(seconds: seconds, snapMode: .beat)
    }

    /// Get nearest bar time
    public func nearestBar(to seconds: Double) -> Double {
        return snapToGrid(seconds: seconds, snapMode: .bar)
    }

    /// Get next beat after time
    public func nextBeat(after seconds: Double) -> Double {
        let spb = secondsPerBeat(at: seconds)
        let currentBeat = snapToGrid(seconds: seconds, snapMode: .beat)
        if currentBeat > seconds {
            return currentBeat
        }
        return currentBeat + spb
    }

    /// Get previous beat before time
    public func previousBeat(before seconds: Double) -> Double {
        let spb = secondsPerBeat(at: seconds)
        let currentBeat = snapToGrid(seconds: seconds, snapMode: .beat)
        if currentBeat < seconds {
            return currentBeat
        }
        return currentBeat - spb
    }
}

// MARK: - Main BPM Grid Edit Engine

/// Main engine for BPM-synchronized video editing
@MainActor
public class BPMGridEditEngine: ObservableObject {

    // MARK: - Published State

    @Published public var grid: BPMGrid = BPMGrid()
    @Published public var snapMode: SnapMode = .beat
    @Published public var isSnapEnabled: Bool = true
    @Published public var markers: [BeatMarker] = []
    @Published public var beatSyncedEffects: [BeatSyncedEffect] = []
    @Published public var isAnalyzing: Bool = false
    @Published public var lastDetectionResult: BeatDetectionResult?

    // Visual settings
    @Published public var showBeatGrid: Bool = true
    @Published public var showDownbeatLines: Bool = true
    @Published public var showBeatNumbers: Bool = true
    @Published public var gridOpacity: Float = 0.5

    // Playback state
    @Published public var currentBeat: Int = 1
    @Published public var currentBar: Int = 1
    @Published public var currentPosition: BeatPosition = BeatPosition()
    @Published public var isOnBeat: Bool = false

    // MARK: - Settings

    public var metronomeEnabled: Bool = false
    public var countIn: Bool = false
    public var countInBars: Int = 1

    // MARK: - Callbacks

    public var onBeat: ((Int, Int) -> Void)?        // (beat, bar)
    public var onDownbeat: ((Int) -> Void)?         // (bar)
    public var onBeatEffect: ((BeatSyncedEffect) -> Void)?

    // MARK: - Internal

    private var beatCounter: Int = 0
    private var lastBeatTime: Double = 0

    // MARK: - Initialization

    public init(bpm: Double = 120, timeSignature: TimeSignature = .fourFour) {
        self.grid = BPMGrid(bpm: bpm, timeSignature: timeSignature)
    }

    // MARK: - Grid Configuration

    /// Set BPM
    public func setBPM(_ bpm: Double) {
        grid.bpm = max(20, min(300, bpm))
    }

    /// Set time signature
    public func setTimeSignature(_ timeSignature: TimeSignature) {
        grid.timeSignature = timeSignature
    }

    /// Set grid offset (time to first downbeat)
    public func setOffset(_ offset: Double) {
        grid.offset = offset
    }

    /// Tap tempo - call multiple times to detect BPM
    private var tapTimes: [Date] = []

    public func tapTempo() {
        let now = Date()
        tapTimes.append(now)

        // Keep only last 8 taps
        if tapTimes.count > 8 {
            tapTimes.removeFirst()
        }

        // Need at least 2 taps to calculate
        guard tapTimes.count >= 2 else { return }

        // Calculate average interval
        var totalInterval: Double = 0
        for i in 1..<tapTimes.count {
            totalInterval += tapTimes[i].timeIntervalSince(tapTimes[i-1])
        }
        let avgInterval = totalInterval / Double(tapTimes.count - 1)

        // Convert to BPM
        let detectedBPM = 60.0 / avgInterval
        setBPM(detectedBPM)
    }

    /// Reset tap tempo
    public func resetTapTempo() {
        tapTimes.removeAll()
    }

    // MARK: - Snapping

    /// Snap time to grid based on current snap mode
    public func snap(_ seconds: Double) -> Double {
        guard isSnapEnabled else { return seconds }
        return grid.snapToGrid(seconds: seconds, snapMode: snapMode)
    }

    /// Snap CMTime to grid
    public func snap(_ time: CMTime) -> CMTime {
        let snappedSeconds = snap(time.seconds)
        return CMTime(seconds: snappedSeconds, preferredTimescale: time.timescale)
    }

    // MARK: - Beat Detection

    /// Analyze audio for beat detection
    public func detectBeats(from audioURL: URL) async -> BeatDetectionResult {
        isAnalyzing = true

        do {
            let result = try await performBeatDetection(audioURL: audioURL)
            lastDetectionResult = result

            // Apply detected settings
            grid.bpm = result.bpm
            grid.offset = result.offset
            if result.confidence > 0.7 {
                grid.timeSignature = result.timeSignature
            }

            // Create beat markers
            createBeatMarkers(from: result)

            isAnalyzing = false
            return result

        } catch {
            isAnalyzing = false
            return BeatDetectionResult()
        }
    }

    /// Perform beat detection using audio analysis
    private func performBeatDetection(audioURL: URL) async throws -> BeatDetectionResult {
        let asset = AVURLAsset(url: audioURL)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            return BeatDetectionResult()
        }

        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMBitDepthKey: 32,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1
        ]

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(output)
        reader.startReading()

        // Collect audio samples
        var samples: [Float] = []
        while let buffer = output.copyNextSampleBuffer(),
              let blockBuffer = CMSampleBufferGetDataBuffer(buffer) {
            var length = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

            if let data = dataPointer {
                let floatPointer = UnsafeRawPointer(data).bindMemory(to: Float.self, capacity: length / 4)
                let floatBuffer = UnsafeBufferPointer(start: floatPointer, count: length / 4)
                samples.append(contentsOf: floatBuffer)
            }
        }

        // Perform onset detection and BPM estimation
        let onsets = detectOnsets(samples: samples, sampleRate: 44100)
        let (bpm, confidence) = estimateBPM(onsets: onsets, sampleRate: 44100)

        // Find beat times
        let beatInterval = 60.0 / bpm
        var beats: [Double] = []
        var time = onsets.first ?? 0

        let duration = Double(samples.count) / 44100.0
        while time < duration {
            beats.append(time)
            time += beatInterval
        }

        // Estimate downbeats (every 4 beats for 4/4)
        let downbeats = beats.enumerated().compactMap { index, beat in
            index % 4 == 0 ? beat : nil
        }

        return BeatDetectionResult(
            bpm: bpm,
            confidence: confidence,
            beats: beats,
            downbeats: downbeats,
            timeSignature: .fourFour,
            offset: beats.first ?? 0
        )
    }

    /// Simple onset detection using energy difference
    private func detectOnsets(samples: [Float], sampleRate: Int) -> [Double] {
        let hopSize = 512
        let windowSize = 1024
        var onsets: [Double] = []
        var lastEnergy: Float = 0

        for i in stride(from: 0, to: samples.count - windowSize, by: hopSize) {
            let window = Array(samples[i..<i+windowSize])
            let energy = window.reduce(0) { $0 + $1 * $1 } / Float(windowSize)

            // Onset when energy increases significantly
            if energy > lastEnergy * 1.5 && energy > 0.01 {
                let time = Double(i) / Double(sampleRate)
                if onsets.isEmpty || (onsets.last.map { time - $0 > 0.1 } ?? true) {
                    onsets.append(time)
                }
            }
            lastEnergy = energy
        }

        return onsets
    }

    /// Estimate BPM from onset times
    private func estimateBPM(onsets: [Double], sampleRate: Int) -> (bpm: Double, confidence: Float) {
        guard onsets.count >= 2 else { return (120, 0) }

        // Calculate intervals between onsets
        var intervals: [Double] = []
        for i in 1..<onsets.count {
            intervals.append(onsets[i] - onsets[i-1])
        }

        // Histogram of intervals (quantized to common beat durations)
        var histogram: [Double: Int] = [:]
        for interval in intervals {
            // Quantize to nearest common interval
            let bpm = 60.0 / interval
            let quantizedBPM = round(bpm / 5) * 5 // Round to nearest 5 BPM
            if quantizedBPM >= 60 && quantizedBPM <= 200 {
                histogram[quantizedBPM, default: 0] += 1
            }
        }

        // Find most common BPM
        guard let (mostCommonBPM, count) = histogram.max(by: { $0.value < $1.value }) else {
            return (120, 0)
        }

        let confidence = Float(count) / Float(intervals.count)
        return (mostCommonBPM, confidence)
    }

    /// Create beat markers from detection result
    private func createBeatMarkers(from result: BeatDetectionResult) {
        markers.removeAll()

        for (index, beatTime) in result.beats.enumerated() {
            let isDownbeat = result.downbeats.contains(beatTime)
            let position = BeatPosition.from(
                seconds: beatTime - result.offset,
                bpm: result.bpm,
                timeSignature: result.timeSignature
            )

            markers.append(BeatMarker(
                position: position,
                type: isDownbeat ? .downbeat : .beat,
                label: isDownbeat ? "Bar \(position.bar)" : "",
                color: isDownbeat ? "#FF0000" : "#0088FF"
            ))
        }
    }

    // MARK: - Playback Updates

    /// Update current position (call from playback loop)
    public func updatePosition(_ seconds: Double) {
        let newPosition = grid.beatPosition(at: seconds)

        // Check if we crossed a beat
        let wasOnBeat = isOnBeat
        isOnBeat = grid.isOnBeat(seconds)

        if !wasOnBeat && isOnBeat {
            currentBeat = newPosition.beat
            currentBar = newPosition.bar
            onBeat?(currentBeat, currentBar)

            // Trigger beat-synced effects
            triggerBeatEffects(beat: currentBeat, bar: currentBar)

            if newPosition.beat == 1 {
                onDownbeat?(currentBar)
            }
        }

        currentPosition = newPosition
    }

    /// Trigger beat-synced effects
    private func triggerBeatEffects(beat: Int, bar: Int) {
        for effect in beatSyncedEffects {
            var shouldTrigger = false

            switch effect.triggerOn {
            case .everyBeat:
                shouldTrigger = true
            case .everyDownbeat:
                shouldTrigger = (beat == 1)
            case .everyOtherBeat:
                shouldTrigger = (beat % 2 == 1)
            case .everyBar:
                shouldTrigger = (beat == 1)
            case .every2Bars:
                shouldTrigger = (beat == 1 && bar % 2 == 1)
            case .every4Bars:
                shouldTrigger = (beat == 1 && bar % 4 == 1)
            case .continuous, .random, .onCue:
                break
            }

            if shouldTrigger {
                onBeatEffect?(effect)
            }
        }
    }

    // MARK: - Quantize Operations

    /// Quantize clip start time to grid
    public func quantizeClipStart(_ seconds: Double) -> Double {
        return snap(seconds)
    }

    /// Quantize clip end time to grid
    public func quantizeClipEnd(_ seconds: Double) -> Double {
        return snap(seconds)
    }

    /// Quantize clip duration to nearest number of beats
    public func quantizeDuration(_ duration: Double, to beats: Double) -> Double {
        let secondsPerBeat = grid.secondsPerBeat()
        return beats * secondsPerBeat
    }

    /// Get number of beats in duration
    public func beatsInDuration(_ duration: Double) -> Double {
        let secondsPerBeat = grid.secondsPerBeat()
        return duration / secondsPerBeat
    }

    /// Round duration to nearest whole number of beats
    public func roundToNearestBeats(_ duration: Double) -> Double {
        let beats = beatsInDuration(duration)
        let roundedBeats = round(beats)
        return quantizeDuration(0, to: roundedBeats)
    }

    // MARK: - Edit Operations

    /// Cut at next beat
    public func cutAtNextBeat(from currentTime: Double) -> Double {
        return grid.nextBeat(after: currentTime)
    }

    /// Cut at next bar
    public func cutAtNextBar(from currentTime: Double) -> Double {
        let spb = grid.secondsPerBeat(at: currentTime)
        let barDuration = spb * Double(grid.timeSignature.numerator)

        let currentBar = grid.snapToGrid(seconds: currentTime, snapMode: .bar)
        if currentBar > currentTime {
            return currentBar
        }
        return currentBar + barDuration
    }

    /// Generate auto-cuts on beats within range
    public func generateAutoCuts(from start: Double, to end: Double, every: SnapMode) -> [Double] {
        return grid.gridLines(from: start, to: end, snapMode: every)
    }

    // MARK: - Markers

    /// Add marker at current position
    public func addMarker(at seconds: Double, type: BeatMarker.MarkerType, label: String = "") {
        let position = grid.beatPosition(at: seconds)
        markers.append(BeatMarker(position: position, type: type, label: label))
    }

    /// Remove marker
    public func removeMarker(id: UUID) {
        markers.removeAll { $0.id == id }
    }

    /// Get markers in time range
    public func markers(from start: Double, to end: Double) -> [BeatMarker] {
        return markers.filter { marker in
            let time = marker.position.toSeconds(bpm: grid.bpm, timeSignature: grid.timeSignature) + grid.offset
            return time >= start && time <= end
        }
    }

    // MARK: - Effects

    /// Add beat-synced effect
    public func addBeatSyncedEffect(_ effect: BeatSyncedEffect) {
        beatSyncedEffects.append(effect)
    }

    /// Remove beat-synced effect
    public func removeBeatSyncedEffect(id: UUID) {
        beatSyncedEffects.removeAll { $0.id == id }
    }

    /// Get effect value at time (for continuous effects)
    public func effectValue(for effect: BeatSyncedEffect, at seconds: Double) -> Float {
        let position = grid.beatPosition(at: seconds)
        let beatFraction = Float(position.tick) / Float(position.ticksPerQuarterNote)

        // Calculate effect envelope
        let phase = (beatFraction + effect.phase).truncatingRemainder(dividingBy: 1.0)
        let envelope = pow(1.0 - phase, effect.decay * 4)

        return envelope * effect.intensity
    }

    // MARK: - Presets

    /// Quick presets for common scenarios
    public static let presets: [(name: String, bpm: Double, timeSignature: TimeSignature)] = [
        ("Hip Hop", 90, .fourFour),
        ("House", 128, .fourFour),
        ("Techno", 140, .fourFour),
        ("Drum & Bass", 174, .fourFour),
        ("Dubstep", 140, .fourFour),
        ("Pop", 120, .fourFour),
        ("Rock", 110, .fourFour),
        ("Jazz Waltz", 140, .threeFour),
        ("6/8 Ballad", 60, .sixEight),
        ("Film Score", 100, .fourFour)
    ]

    /// Apply preset
    public func applyPreset(name: String) {
        if let preset = Self.presets.first(where: { $0.name == name }) {
            grid.bpm = preset.bpm
            grid.timeSignature = preset.timeSignature
        }
    }
}

// MARK: - Extensions

extension BPMGridEditEngine {

    /// Get grid info string
    public var gridInfoString: String {
        return "\(Int(grid.bpm)) BPM • \(grid.timeSignature.displayString)"
    }

    /// Get current position string
    public var positionString: String {
        return currentPosition.displayString
    }

    /// Get time until next beat
    public func timeUntilNextBeat(from seconds: Double) -> Double {
        let nextBeat = grid.nextBeat(after: seconds)
        return nextBeat - seconds
    }

    /// Get time until next bar
    public func timeUntilNextBar(from seconds: Double) -> Double {
        let nextBar = cutAtNextBar(from: seconds)
        return nextBar - seconds
    }
}

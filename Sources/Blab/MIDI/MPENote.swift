import Foundation
import UIKit

/// MPE (MIDI Polyphonic Expression) Note
/// Represents a single touch/finger with full polyphonic expression
/// Each note can have independent pitch bend, pressure, and timbre modulation
///
/// MPE Standard: MIDI Manufacturers Association (MMA) specification
/// - Each note gets its own MIDI channel (up to 15 channels)
/// - Dimension 1 (X-axis): Pitch bend (CC74)
/// - Dimension 2 (Y-axis): Timbre/brightness (CC74)
/// - Dimension 3 (Pressure/Z): Aftertouch/loudness (Channel Pressure)
///
/// References:
/// - MMA MIDI Polyphonic Expression (MPE) Specification v1.0 (2017)
/// - MIDI 2.0 specification
struct MPENote: Identifiable, Equatable {

    /// Unique identifier (matches UITouch)
    let id: UUID

    /// MIDI note number (0-127)
    /// This is the BASE note before pitch bend is applied
    let midiNote: Int

    /// MPE channel (1-15, channel 0 is reserved for global messages in MPE)
    /// In MPE, each note gets its own channel for independent control
    let mpeChannel: Int

    /// Current position on touchpad
    var position: CGPoint

    /// Initial touch position (for relative gestures)
    let initialPosition: CGPoint

    /// Velocity (0.0-1.0) - determined at note-on from initial touch force
    let velocity: Float

    /// Current pressure/force (0.0-1.0) - Dimension 3 (Z-axis)
    /// Maps to MIDI Channel Pressure (Aftertouch)
    var pressure: Float

    /// Pitch bend amount in semitones (-2.0 to +2.0 typical range)
    /// Dimension 1 (X-axis horizontal slide)
    /// Maps to MIDI Pitch Bend
    var pitchBend: Float

    /// Timbre/brightness (0.0-1.0) - Dimension 2 (Y-axis vertical slide)
    /// Maps to MIDI CC74 (Brightness/Timbre)
    var timbre: Float

    /// Timestamp when note started
    let startTime: TimeInterval

    /// Current state
    var state: NoteState

    enum NoteState {
        case active    // Note is playing
        case releasing // Note-off sent, in release phase
        case ended     // Note completely finished
    }


    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        midiNote: Int,
        mpeChannel: Int,
        position: CGPoint,
        velocity: Float,
        pressure: Float = 0.5,
        startTime: TimeInterval = Date().timeIntervalSinceReferenceDate
    ) {
        self.id = id
        self.midiNote = midiNote
        self.mpeChannel = mpeChannel
        self.position = position
        self.initialPosition = position
        self.velocity = velocity
        self.pressure = pressure
        self.pitchBend = 0.0  // No bend initially
        self.timbre = 0.5     // Neutral timbre initially
        self.startTime = startTime
        self.state = .active
    }


    // MARK: - Computed Properties

    /// Actual frequency in Hz (base note + pitch bend)
    func frequency(using tuning: TuningSystem, pitchBendRange: Float = 2.0) -> Double {
        let baseFreq = tuning.frequency(forMIDINote: midiNote)
        let bendFactor = pow(2.0, Double(pitchBend * pitchBendRange) / 12.0)
        return baseFreq * bendFactor
    }

    /// Actual frequency using microtonal scale
    func frequency(using scale: MicrotonalScale, pitchBendRange: Float = 2.0) -> Double {
        let baseFreq = scale.frequency(forMIDINote: midiNote)
        let bendFactor = pow(2.0, Double(pitchBend * pitchBendRange) / 12.0)
        return baseFreq * bendFactor
    }

    /// MIDI pitch bend value (0-16383, center = 8192)
    var midiPitchBendValue: Int {
        // Pitch bend range is typically ±2 semitones
        // MIDI pitch bend: 0-16383, center at 8192
        // pitchBend is in semitones: -2.0 to +2.0
        let normalizedBend = (pitchBend + 2.0) / 4.0  // Map -2...+2 to 0...1
        let bendValue = Int(normalizedBend * 16383.0)
        return max(0, min(16383, bendValue))
    }

    /// MIDI timbre CC74 value (0-127)
    var midiTimbreValue: Int {
        return Int(timbre * 127.0)
    }

    /// MIDI pressure value (0-127)
    var midiPressureValue: Int {
        return Int(pressure * 127.0)
    }

    /// MIDI velocity value (0-127)
    var midiVelocityValue: Int {
        return Int(velocity * 127.0)
    }

    /// How long this note has been playing (seconds)
    var duration: TimeInterval {
        return Date().timeIntervalSinceReferenceDate - startTime
    }


    // MARK: - Equatable

    static func == (lhs: MPENote, rhs: MPENote) -> Bool {
        return lhs.id == rhs.id
    }
}


// MARK: - MPE Touch Gesture

/// Represents a continuous touch gesture for MPE control
/// Tracks touch movement over time for smooth parameter interpolation
struct MPETouchGesture {
    let touchID: UUID
    var positions: [TimestampedPosition]
    var note: MPENote?

    struct TimestampedPosition {
        let position: CGPoint
        let timestamp: TimeInterval
        let force: CGFloat
    }

    init(touchID: UUID) {
        self.touchID = touchID
        self.positions = []
    }

    mutating func addPosition(_ position: CGPoint, force: CGFloat) {
        let timestamped = TimestampedPosition(
            position: position,
            timestamp: Date().timeIntervalSinceReferenceDate,
            force: force
        )
        positions.append(timestamped)

        // Keep only last 100 positions (prevent memory growth)
        if positions.count > 100 {
            positions.removeFirst()
        }
    }

    /// Get velocity vector (speed and direction of touch movement)
    var velocity: CGVector {
        guard positions.count >= 2 else { return .zero }

        let recent = positions.suffix(5)  // Last 5 positions
        guard let first = recent.first, let last = recent.last else { return .zero }

        let deltaTime = last.timestamp - first.timestamp
        guard deltaTime > 0 else { return .zero }

        let deltaX = last.position.x - first.position.x
        let deltaY = last.position.y - first.position.y

        return CGVector(dx: deltaX / deltaTime, dy: deltaY / deltaTime)
    }

    /// Average force over recent positions
    var averageForce: CGFloat {
        guard !positions.isEmpty else { return 0.5 }

        let recent = positions.suffix(10)
        let sum = recent.reduce(0.0) { $0 + $1.force }
        return sum / CGFloat(recent.count)
    }
}


// MARK: - MPE Configuration

/// Configuration for MPE touchpad behavior
struct MPEConfiguration {

    /// Pitch bend range in semitones (typical: 2, 12, or 24)
    var pitchBendRange: Float = 2.0

    /// Sensitivity for horizontal pitch bend (0.0-1.0)
    /// Higher = more bend for less movement
    var pitchBendSensitivity: Float = 0.5

    /// Sensitivity for vertical timbre control (0.0-1.0)
    var timbreSensitivity: Float = 0.5

    /// Sensitivity for pressure/force (0.0-1.0)
    var pressureSensitivity: Float = 0.8

    /// Snap to scale notes (true = discrete notes, false = continuous pitch)
    var snapToScale: Bool = true

    /// Glide/portamento time when switching notes (seconds)
    var glideTime: Float = 0.1

    /// Number of available MPE channels (1-15)
    var maxPolyphony: Int = 15

    /// MIDI output enabled
    var midiOutputEnabled: Bool = true

    /// Audio output enabled
    var audioOutputEnabled: Bool = true

    /// Visual feedback enabled
    var visualFeedbackEnabled: Bool = true

    /// Haptic feedback enabled
    var hapticFeedbackEnabled: Bool = true
}


// MARK: - Helper Extensions

extension CGPoint {
    /// Distance to another point
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx*dx + dy*dy)
    }

    /// Angle to another point (radians)
    func angle(to other: CGPoint) -> CGFloat {
        return atan2(other.y - y, other.x - x)
    }
}

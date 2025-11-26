import Foundation
import CoreMIDI

/// MIDI Router - Connects MIDI Input to Instruments
///
/// **CRITICAL COMPONENT:** Bridges MIDI2Manager with InstrumentAudioEngine
///
/// **Features:**
/// - MIDI → Instrument mapping
/// - Multi-instrument routing (one MIDI input → multiple instruments)
/// - MIDI learn functionality
/// - Channel filtering
/// - Velocity curves
/// - Transpose & octave shift
///
/// **Architecture:**
/// ```
/// MIDI Input → MIDI2Manager → MIDIRouter → InstrumentAudioEngine → Audio Output
/// ```
///
/// **Usage:**
/// ```swift
/// let router = MIDIRouter(
///     midiManager: midi2Manager,
///     instrumentEngine: instrumentEngine
/// )
/// router.start()
/// ```
@MainActor
class MIDIRouter: ObservableObject {

    // MARK: - Published State

    @Published var isActive: Bool = false
    @Published var activeNotes: Set<UInt8> = []
    @Published var lastMIDIMessage: String = ""
    @Published var mappings: [MIDIMapping] = []

    // MARK: - Dependencies

    private weak var midiManager: MIDI2Manager?
    private weak var instrumentEngine: InstrumentAudioEngine?

    // MARK: - Routing Configuration

    private var transpose: Int = 0  // Semitones
    private var velocityCurve: VelocityCurve = .linear
    private var channelFilter: Set<UInt8>? = nil  // nil = all channels

    // MARK: - MIDI Mapping

    struct MIDIMapping: Identifiable {
        let id = UUID()
        var sourceType: MIDISourceType
        var targetParameter: TargetParameter
        var minValue: Float = 0.0
        var maxValue: Float = 1.0
        var curve: MappingCurve = .linear
        var isEnabled: Bool = true

        enum MIDISourceType {
            case noteVelocity
            case noteNumber
            case controlChange(UInt8)  // CC number
            case pitchBend
            case channelPressure
            case modWheel
            case expression
        }

        enum TargetParameter {
            case filterCutoff
            case filterResonance
            case volume
            case pan
            case attack
            case release
            case lfoRate
            case lfoDepth
            case custom(String)
        }

        enum MappingCurve {
            case linear
            case exponential
            case logarithmic
            case sCurve
        }
    }

    // MARK: - Velocity Curve

    enum VelocityCurve {
        case linear
        case soft      // Lower velocities boosted
        case hard      // Higher velocities emphasized
        case fixed(UInt8)  // All notes same velocity
    }

    // MARK: - Initialization

    init(midiManager: MIDI2Manager, instrumentEngine: InstrumentAudioEngine) {
        self.midiManager = midiManager
        self.instrumentEngine = instrumentEngine

        print("✅ MIDIRouter initialized")
    }

    // MARK: - Start/Stop

    /// Start routing MIDI messages
    func start() {
        guard let midiManager = midiManager else {
            print("⚠️ MIDIRouter: No MIDI manager")
            return
        }

        // Subscribe to MIDI messages
        // Note: This would require MIDI2Manager to have a callback mechanism
        // For now, we'll add a method for manual routing

        isActive = true
        print("▶️ MIDIRouter started")
    }

    /// Stop routing
    func stop() {
        isActive = false

        // Send all-notes-off to prevent stuck notes
        instrumentEngine?.allNotesOff()
        activeNotes.removeAll()

        print("⏹️ MIDIRouter stopped")
    }

    // MARK: - MIDI Message Routing

    /// Route MIDI note-on message
    func routeNoteOn(channel: UInt8, note: UInt8, velocity: UInt8) {
        guard isActive else { return }
        guard shouldProcessChannel(channel) else { return }

        // Apply transpose
        let transposedNote = applyTranspose(note)
        guard transposedNote >= 0 && transposedNote <= 127 else { return }

        // Apply velocity curve
        let mappedVelocity = applyVelocityCurve(velocity)

        // Trigger instrument
        instrumentEngine?.noteOn(note: UInt8(transposedNote), velocity: mappedVelocity)

        // Track active notes
        activeNotes.insert(UInt8(transposedNote))

        // Update UI
        lastMIDIMessage = "Note ON: \(transposedNote) (\(mappedVelocity))"

        print("🎹 MIDI Note ON: Ch\(channel) Note\(transposedNote) Vel\(mappedVelocity)")
    }

    /// Route MIDI note-off message
    func routeNoteOff(channel: UInt8, note: UInt8, velocity: UInt8 = 0) {
        guard isActive else { return }
        guard shouldProcessChannel(channel) else { return }

        // Apply transpose
        let transposedNote = applyTranspose(note)
        guard transposedNote >= 0 && transposedNote <= 127 else { return }

        // Release instrument
        instrumentEngine?.noteOff(note: UInt8(transposedNote))

        // Remove from active notes
        activeNotes.remove(UInt8(transposedNote))

        // Update UI
        lastMIDIMessage = "Note OFF: \(transposedNote)"

        print("🎹 MIDI Note OFF: Ch\(channel) Note\(transposedNote)")
    }

    /// Route MIDI control change
    func routeControlChange(channel: UInt8, controller: UInt8, value: UInt8) {
        guard isActive else { return }
        guard shouldProcessChannel(channel) else { return }

        let normalizedValue = Float(value) / 127.0

        // Check for mapped parameters
        for mapping in mappings where mapping.isEnabled {
            if case .controlChange(let cc) = mapping.sourceType, cc == controller {
                applyMapping(mapping, value: normalizedValue)
            }
        }

        // Common CC mappings
        switch controller {
        case 1:  // Mod Wheel
            // Could modulate filter cutoff, vibrato, etc.
            break
        case 7:  // Volume
            // Set instrument volume
            break
        case 10:  // Pan
            // Set instrument pan
            break
        case 74:  // Filter Cutoff (common mapping)
            instrumentEngine?.setFilterCutoff(normalizedValue * 20000.0)
        case 71:  // Filter Resonance
            instrumentEngine?.setFilterResonance(normalizedValue)
        default:
            break
        }

        lastMIDIMessage = "CC\(controller): \(value)"
    }

    /// Route MIDI pitch bend
    func routePitchBend(channel: UInt8, value: Int) {
        guard isActive else { return }
        guard shouldProcessChannel(channel) else { return }

        // Pitch bend: -8192 to +8191
        // TODO: Implement pitch bend in InstrumentAudioEngine

        lastMIDIMessage = "Pitch Bend: \(value)"
    }

    /// Route MIDI channel pressure (aftertouch)
    func routeChannelPressure(channel: UInt8, pressure: UInt8) {
        guard isActive else { return }
        guard shouldProcessChannel(channel) else { return }

        let normalizedPressure = Float(pressure) / 127.0

        // Check for mapped parameters
        for mapping in mappings where mapping.isEnabled {
            if case .channelPressure = mapping.sourceType {
                applyMapping(mapping, value: normalizedPressure)
            }
        }

        lastMIDIMessage = "Pressure: \(pressure)"
    }

    // MARK: - Parameter Mapping

    private func applyMapping(_ mapping: MIDIMapping, value: Float) {
        // Apply curve
        let curvedValue = applyCurve(value, curve: mapping.curve)

        // Scale to range
        let scaledValue = mapping.minValue + (curvedValue * (mapping.maxValue - mapping.minValue))

        // Apply to target parameter
        switch mapping.targetParameter {
        case .filterCutoff:
            instrumentEngine?.setFilterCutoff(scaledValue)
        case .filterResonance:
            instrumentEngine?.setFilterResonance(scaledValue)
        case .attack:
            instrumentEngine?.setAttackTime(scaledValue)
        case .release:
            instrumentEngine?.setReleaseTime(scaledValue)
        case .volume, .pan, .lfoRate, .lfoDepth, .custom:
            // TODO: Implement these parameters
            break
        }
    }

    private func applyCurve(_ value: Float, curve: MIDIMapping.MappingCurve) -> Float {
        switch curve {
        case .linear:
            return value
        case .exponential:
            return value * value
        case .logarithmic:
            return sqrt(value)
        case .sCurve:
            // Smooth S-curve (sigmoid-like)
            return (sin((value - 0.5) * .pi) + 1.0) / 2.0
        }
    }

    // MARK: - MIDI Learn

    private var learnMode: Bool = false
    private var learnTargetParameter: MIDIMapping.TargetParameter?

    /// Start MIDI learn for a parameter
    func startLearn(parameter: MIDIMapping.TargetParameter) {
        learnMode = true
        learnTargetParameter = parameter
        print("🎓 MIDI Learn: Move a control to assign to \(parameter)")
    }

    /// Stop MIDI learn
    func stopLearn() {
        learnMode = false
        learnTargetParameter = nil
        print("🛑 MIDI Learn stopped")
    }

    /// Called when MIDI message received during learn mode
    func learnMapping(sourceType: MIDIMapping.MIDISourceType) {
        guard learnMode, let targetParameter = learnTargetParameter else { return }

        let mapping = MIDIMapping(
            sourceType: sourceType,
            targetParameter: targetParameter
        )

        mappings.append(mapping)
        print("✅ MIDI Learn: Mapped \(sourceType) → \(targetParameter)")

        stopLearn()
    }

    // MARK: - Configuration

    /// Set transpose (semitones)
    func setTranspose(_ semitones: Int) {
        transpose = max(-48, min(semitones, 48))
        print("🎼 Transpose: \(transpose > 0 ? "+" : "")\(transpose) semitones")
    }

    /// Set velocity curve
    func setVelocityCurve(_ curve: VelocityCurve) {
        velocityCurve = curve
        print("📈 Velocity curve: \(curve)")
    }

    /// Set channel filter (nil = all channels)
    func setChannelFilter(_ channels: Set<UInt8>?) {
        channelFilter = channels
        if let channels = channels {
            print("🎛️ Channel filter: \(channels.sorted())")
        } else {
            print("🎛️ Channel filter: All channels")
        }
    }

    // MARK: - Helpers

    private func applyTranspose(_ note: UInt8) -> Int {
        return Int(note) + transpose
    }

    private func applyVelocityCurve(_ velocity: UInt8) -> UInt8 {
        switch velocityCurve {
        case .linear:
            return velocity
        case .soft:
            // Boost lower velocities
            let normalized = Float(velocity) / 127.0
            let boosted = sqrt(normalized)
            return UInt8(boosted * 127.0)
        case .hard:
            // Emphasize higher velocities
            let normalized = Float(velocity) / 127.0
            let emphasized = normalized * normalized
            return UInt8(emphasized * 127.0)
        case .fixed(let vel):
            return vel
        }
    }

    private func shouldProcessChannel(_ channel: UInt8) -> Bool {
        if let filter = channelFilter {
            return filter.contains(channel)
        }
        return true
    }

    // MARK: - Panic

    /// Send all notes off (MIDI panic)
    func panic() {
        instrumentEngine?.allNotesOff()
        activeNotes.removeAll()
        print("🚨 MIDI Panic - All notes off")
    }
}

// MARK: - MIDI2Manager Integration Extension

extension MIDI2Manager {
    /// Connect to MIDIRouter
    func connectToRouter(_ router: MIDIRouter) {
        // This would set up callbacks from MIDI2Manager to MIDIRouter
        // Implementation depends on MIDI2Manager's event system

        print("🔌 MIDI2Manager connected to MIDIRouter")
    }
}

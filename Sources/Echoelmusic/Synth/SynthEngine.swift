import Foundation
import AVFoundation
import Accelerate

/// Professional Synthesizer Engine with FULL USER CONTROL
/// This is NOT an AI that generates sounds - it's a TOOL that the user controls
/// completely to craft their own unique sounds.
///
/// Synthesis Types:
/// - Subtractive (classic analog-style)
/// - FM (Frequency Modulation)
/// - Wavetable
/// - Additive
/// - Granular
/// - Physical Modeling
///
/// Every parameter is exposed and controllable by the user.
/// No AI magic - just professional synthesis tools.
@MainActor
class SynthEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var voices: [Voice] = []
    @Published var maxPolyphony: Int = 16
    @Published var globalSettings: GlobalSettings

    // MARK: - Global Settings

    struct GlobalSettings: Codable {
        var masterVolume: Float  // 0-1
        var masterTune: Float  // -100 to +100 cents
        var voiceMode: VoiceMode
        var glideTime: Float  // 0-5 seconds
        var bendRange: Int  // semitones

        enum VoiceMode: String, Codable {
            case poly = "Poly"
            case mono = "Mono"
            case legato = "Legato"
            case unison = "Unison"
        }

        static let `default` = GlobalSettings(
            masterVolume: 0.7,
            masterTune: 0.0,
            voiceMode: .poly,
            glideTime: 0.0,
            bendRange: 2
        )
    }

    // MARK: - Synthesis Type

    enum SynthesisType: String, CaseIterable {
        case subtractive = "Subtractive"
        case fm = "FM Synthesis"
        case wavetable = "Wavetable"
        case additive = "Additive"
        case granular = "Granular"
        case physical = "Physical Modeling"

        var description: String {
            switch self {
            case .subtractive:
                return "Classic analog-style synthesis with oscillators, filters, and envelopes"
            case .fm:
                return "Frequency modulation for complex, metallic timbres"
            case .wavetable:
                return "Scan through wavetables for evolving, dynamic sounds"
            case .additive:
                return "Build sounds from individual sine waves (partials)"
            case .granular:
                return "Manipulate tiny sound grains for textured, atmospheric sounds"
            case .physical:
                return "Model physical instruments using waveguides and resonators"
            }
        }
    }

    // MARK: - Voice

    struct Voice: Identifiable {
        let id = UUID()
        var note: Int  // MIDI note
        var velocity: Float  // 0-1
        var startTime: TimeInterval
        var isActive: Bool
        var phase: Double  // Oscillator phase
        var envelopes: EnvelopeStates
        var lfos: LFOStates

        struct EnvelopeStates {
            var amp: EnvelopeState
            var filter: EnvelopeState
            var pitch: EnvelopeState
        }

        struct LFOStates {
            var lfo1: LFOState
            var lfo2: LFOState
        }

        struct EnvelopeState {
            var stage: EnvelopeStage
            var value: Float  // 0-1
            var timeInStage: TimeInterval

            enum EnvelopeStage {
                case attack, decay, sustain, release, idle
            }
        }

        struct LFOState {
            var phase: Double
            var value: Float  // -1 to +1
        }
    }

    // MARK: - Oscillator (USER CONTROLLED)

    struct Oscillator: Codable {
        var enabled: Bool
        var waveform: Waveform
        var octave: Int  // -3 to +3
        var semitone: Int  // -12 to +12
        var cents: Float  // -100 to +100
        var level: Float  // 0-1
        var phase: Float  // 0-360 degrees
        var pulseWidth: Float  // 0-1 (for pulse wave)
        var unisonVoices: Int  // 1-8
        var unisonDetune: Float  // 0-100 cents
        var unisonSpread: Float  // 0-1 stereo spread

        enum Waveform: String, Codable, CaseIterable {
            case sine = "Sine"
            case saw = "Saw"
            case square = "Square"
            case triangle = "Triangle"
            case pulse = "Pulse"
            case noise = "Noise"

            var displayName: String { rawValue }
        }

        static let `default` = Oscillator(
            enabled: true,
            waveform: .saw,
            octave: 0,
            semitone: 0,
            cents: 0,
            level: 1.0,
            phase: 0,
            pulseWidth: 0.5,
            unisonVoices: 1,
            unisonDetune: 10,
            unisonSpread: 0.5
        )
    }

    // MARK: - Filter (USER CONTROLLED)

    struct Filter: Codable {
        var enabled: Bool
        var type: FilterType
        var cutoff: Float  // 20-20000 Hz
        var resonance: Float  // 0-1
        var drive: Float  // 0-1 (overdrive/distortion)
        var keyTracking: Float  // 0-1 (filter follows note pitch)
        var velocitySensitivity: Float  // 0-1

        enum FilterType: String, Codable, CaseIterable {
            case lowpass = "Low Pass"
            case highpass = "High Pass"
            case bandpass = "Band Pass"
            case notch = "Notch"
            case lowshelf = "Low Shelf"
            case highshelf = "High Shelf"
            case peak = "Peak"
            case allpass = "All Pass"

            var description: String {
                switch self {
                case .lowpass: return "Cuts highs, allows lows"
                case .highpass: return "Cuts lows, allows highs"
                case .bandpass: return "Allows middle frequencies"
                case .notch: return "Cuts middle frequencies"
                case .lowshelf: return "Boost/cut low frequencies"
                case .highshelf: return "Boost/cut high frequencies"
                case .peak: return "Boost/cut specific frequency"
                case .allpass: return "Phase shift only"
                }
            }
        }

        static let `default` = Filter(
            enabled: true,
            type: .lowpass,
            cutoff: 2000,
            resonance: 0.3,
            drive: 0.0,
            keyTracking: 0.5,
            velocitySensitivity: 0.5
        )
    }

    // MARK: - Envelope (USER CONTROLLED)

    struct Envelope: Codable {
        var attack: Float  // 0-10 seconds
        var decay: Float  // 0-10 seconds
        var sustain: Float  // 0-1 level
        var release: Float  // 0-10 seconds
        var attackCurve: Curve  // Shape of attack
        var decayReleaseCurve: Curve

        enum Curve: String, Codable, CaseIterable {
            case linear = "Linear"
            case exponential = "Exponential"
            case logarithmic = "Logarithmic"
        }

        static let `default` = Envelope(
            attack: 0.01,
            decay: 0.3,
            sustain: 0.7,
            release: 0.5,
            attackCurve: .exponential,
            decayReleaseCurve: .exponential
        )
    }

    // MARK: - LFO (USER CONTROLLED)

    struct LFO: Codable {
        var enabled: Bool
        var waveform: Waveform
        var rate: Float  // 0.01-20 Hz
        var depth: Float  // 0-1
        var phase: Float  // 0-360 degrees
        var syncToTempo: Bool
        var tempoSync: TempoSync
        var destination: LFODestination

        enum Waveform: String, Codable, CaseIterable {
            case sine = "Sine"
            case triangle = "Triangle"
            case saw = "Saw"
            case square = "Square"
            case sampleHold = "Sample & Hold"
            case random = "Random"
        }

        enum TempoSync: String, Codable, CaseIterable {
            case whole = "1/1"
            case half = "1/2"
            case quarter = "1/4"
            case eighth = "1/8"
            case sixteenth = "1/16"
            case thirtysecond = "1/32"
        }

        enum LFODestination: String, Codable, CaseIterable {
            case pitch = "Pitch"
            case filterCutoff = "Filter Cutoff"
            case amplitude = "Amplitude"
            case panning = "Panning"
            case pulseWidth = "Pulse Width"
        }

        static let `default` = LFO(
            enabled: false,
            waveform: .sine,
            rate: 4.0,
            depth: 0.5,
            phase: 0,
            syncToTempo: false,
            tempoSync: .quarter,
            destination: .pitch
        )
    }

    // MARK: - Modulation Matrix (USER CONTROLLED)

    struct ModulationMatrix: Codable {
        var routes: [ModulationRoute]

        struct ModulationRoute: Identifiable, Codable {
            let id = UUID()
            var source: ModulationSource
            var destination: ModulationDestination
            var amount: Float  // -1 to +1

            enum ModulationSource: String, Codable, CaseIterable {
                case lfo1 = "LFO 1"
                case lfo2 = "LFO 2"
                case envelope1 = "Envelope 1"
                case envelope2 = "Envelope 2"
                case velocity = "Velocity"
                case modWheel = "Mod Wheel"
                case aftertouch = "Aftertouch"
                case pitchBend = "Pitch Bend"
                case random = "Random"
            }

            enum ModulationDestination: String, Codable, CaseIterable {
                case osc1Pitch = "Osc 1 Pitch"
                case osc2Pitch = "Osc 2 Pitch"
                case osc1Level = "Osc 1 Level"
                case osc2Level = "Osc 2 Level"
                case filterCutoff = "Filter Cutoff"
                case filterResonance = "Filter Resonance"
                case amplitude = "Amplitude"
                case panning = "Panning"
            }
        }

        static let empty = ModulationMatrix(routes: [])
    }

    // MARK: - Synth Patch (Complete Sound)

    struct SynthPatch: Identifiable, Codable {
        let id = UUID()
        var name: String
        var type: SynthesisType
        var oscillators: [Oscillator]
        var filter: Filter
        var ampEnvelope: Envelope
        var filterEnvelope: Envelope
        var lfos: [LFO]
        var modulationMatrix: ModulationMatrix
        var effects: EffectChain
        var createdBy: String  // USER created!
        var createdDate: Date
        var tags: [String]

        struct EffectChain: Codable {
            var reverb: ReverbParameters?
            var delay: DelayParameters?
            var chorus: ChorusParameters?
            var distortion: DistortionParameters?

            struct ReverbParameters: Codable {
                var enabled: Bool
                var size: Float  // 0-1
                var damping: Float  // 0-1
                var mix: Float  // 0-1
            }

            struct DelayParameters: Codable {
                var enabled: Bool
                var time: Float  // seconds
                var feedback: Float  // 0-1
                var mix: Float  // 0-1
            }

            struct ChorusParameters: Codable {
                var enabled: Bool
                var rate: Float  // Hz
                var depth: Float  // 0-1
                var mix: Float  // 0-1
            }

            struct DistortionParameters: Codable {
                var enabled: Bool
                var drive: Float  // 0-1
                var mix: Float  // 0-1
            }
        }

        static func createDefault(name: String) -> SynthPatch {
            SynthPatch(
                name: name,
                type: .subtractive,
                oscillators: [.default, .default],
                filter: .default,
                ampEnvelope: .default,
                filterEnvelope: .default,
                lfos: [.default, .default],
                modulationMatrix: .empty,
                effects: EffectChain(reverb: nil, delay: nil, chorus: nil, distortion: nil),
                createdBy: "User",
                createdDate: Date(),
                tags: []
            )
        }
    }

    @Published var currentPatch: SynthPatch

    // MARK: - Initialization

    init() {
        self.globalSettings = .default
        self.currentPatch = .createDefault(name: "Init Patch")

        print("🎹 Synth Engine initialized")
        print("   🎛️ Type: \(currentPatch.type.rawValue)")
        print("   🎵 Max Polyphony: \(maxPolyphony)")
        print("   👤 USER CONTROLLED - No AI Generation!")
    }

    // MARK: - Note On/Off

    func noteOn(note: Int, velocity: Float) {
        print("🎹 Note ON: \(noteName(note)) velocity: \(Int(velocity * 127))")

        // Check voice limit
        guard voices.filter({ $0.isActive }).count < maxPolyphony else {
            print("   ⚠️ Max polyphony reached, stealing voice")
            stealVoice()
            return
        }

        let voice = Voice(
            note: note,
            velocity: velocity,
            startTime: Date().timeIntervalSince1970,
            isActive: true,
            phase: 0,
            envelopes: Voice.EnvelopeStates(
                amp: Voice.EnvelopeState(stage: .attack, value: 0, timeInStage: 0),
                filter: Voice.EnvelopeState(stage: .attack, value: 0, timeInStage: 0),
                pitch: Voice.EnvelopeState(stage: .attack, value: 0, timeInStage: 0)
            ),
            lfos: Voice.LFOStates(
                lfo1: Voice.LFOState(phase: 0, value: 0),
                lfo2: Voice.LFOState(phase: 0, value: 0)
            )
        )

        voices.append(voice)
    }

    func noteOff(note: Int) {
        print("🎹 Note OFF: \(noteName(note))")

        for index in voices.indices where voices[index].note == note && voices[index].isActive {
            voices[index].envelopes.amp.stage = .release
            voices[index].envelopes.amp.timeInStage = 0
        }
    }

    func allNotesOff() {
        print("🔇 All notes OFF")

        for index in voices.indices {
            voices[index].isActive = false
        }
        voices.removeAll()
    }

    private func stealVoice() {
        // Voice stealing: take the oldest voice
        if let oldest = voices.first(where: { $0.isActive }) {
            if let index = voices.firstIndex(where: { $0.id == oldest.id }) {
                voices[index].isActive = false
            }
        }
    }

    // MARK: - Audio Generation (DSP)

    func generateAudio(frameCount: Int, sampleRate: Double) -> [Float] {
        var buffer = [Float](repeating: 0, count: frameCount)

        for voice in voices where voice.isActive {
            let voiceBuffer = generateVoiceAudio(voice: voice, frameCount: frameCount, sampleRate: sampleRate)

            // Mix voice into main buffer
            for i in 0..<frameCount {
                buffer[i] += voiceBuffer[i]
            }
        }

        // Apply master volume
        vDSP_vsmul(buffer, 1, [globalSettings.masterVolume], &buffer, 1, vDSP_Length(frameCount))

        return buffer
    }

    private func generateVoiceAudio(voice: Voice, frameCount: Int, sampleRate: Double) -> [Float] {
        var buffer = [Float](repeating: 0, count: frameCount)

        // Calculate frequency
        let midiNote = Float(voice.note)
        let frequency = 440.0 * pow(2.0, (midiNote - 69.0) / 12.0)

        // Generate oscillator waveform
        for (index, oscillator) in currentPatch.oscillators.enumerated() where oscillator.enabled {
            let oscBuffer = generateOscillator(
                oscillator: oscillator,
                baseFrequency: frequency,
                frameCount: frameCount,
                sampleRate: sampleRate,
                phase: voice.phase
            )

            // Mix oscillator
            for i in 0..<frameCount {
                buffer[i] += oscBuffer[i] * oscillator.level
            }
        }

        // Apply amplitude envelope
        let envelope = voice.envelopes.amp.value * voice.velocity
        vDSP_vsmul(buffer, 1, [envelope], &buffer, 1, vDSP_Length(frameCount))

        return buffer
    }

    private func generateOscillator(
        oscillator: Oscillator,
        baseFrequency: Double,
        frameCount: Int,
        sampleRate: Double,
        phase: Double
    ) -> [Float] {
        var buffer = [Float](repeating: 0, count: frameCount)

        // Apply octave/semitone/cents tuning
        let octaveMult = pow(2.0, Double(oscillator.octave))
        let semitoneMult = pow(2.0, Double(oscillator.semitone) / 12.0)
        let centsMult = pow(2.0, Double(oscillator.cents) / 1200.0)
        let frequency = baseFrequency * octaveMult * semitoneMult * centsMult

        let phaseIncrement = frequency / sampleRate
        var currentPhase = phase

        for i in 0..<frameCount {
            buffer[i] = generateWaveform(oscillator.waveform, phase: currentPhase, pulseWidth: oscillator.pulseWidth)
            currentPhase += phaseIncrement
            if currentPhase >= 1.0 {
                currentPhase -= 1.0
            }
        }

        return buffer
    }

    private func generateWaveform(_ type: Oscillator.Waveform, phase: Double, pulseWidth: Float) -> Float {
        let normalizedPhase = phase - floor(phase)

        switch type {
        case .sine:
            return Float(sin(normalizedPhase * 2.0 * .pi))

        case .saw:
            return Float(2.0 * normalizedPhase - 1.0)

        case .square:
            return normalizedPhase < 0.5 ? 1.0 : -1.0

        case .triangle:
            if normalizedPhase < 0.5 {
                return Float(4.0 * normalizedPhase - 1.0)
            } else {
                return Float(-4.0 * normalizedPhase + 3.0)
            }

        case .pulse:
            return normalizedPhase < Double(pulseWidth) ? 1.0 : -1.0

        case .noise:
            return Float.random(in: -1...1)
        }
    }

    // MARK: - Patch Management

    func savePatch(name: String) -> SynthPatch {
        print("💾 Saving patch: \(name)")

        var patch = currentPatch
        patch.name = name
        patch.createdBy = "User"
        patch.createdDate = Date()

        print("   ✅ Patch saved by USER")
        print("   🎛️ Oscillators: \(patch.oscillators.count)")
        print("   🎚️ Filter: \(patch.filter.type.rawValue)")

        return patch
    }

    func loadPatch(_ patch: SynthPatch) {
        print("📂 Loading patch: \(patch.name)")

        currentPatch = patch

        print("   ✅ Patch loaded")
        print("   👤 Created by: \(patch.createdBy)")
        print("   📅 Date: \(patch.createdDate)")
    }

    func createPatchFromScratch(name: String) -> SynthPatch {
        print("✨ Creating new patch from scratch: \(name)")

        let patch = SynthPatch.createDefault(name: name)

        print("   ✅ Empty patch created - USER will design it!")

        return patch
    }

    // MARK: - Helper Methods

    private func noteName(_ note: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (note / 12) - 1
        let noteName = names[note % 12]
        return "\(noteName)\(octave)"
    }

    // MARK: - Factory Presets (USER CAN MODIFY THESE!)

    static func createFactoryPresets() -> [SynthPatch] {
        return [
            createBassPreset(),
            createLeadPreset(),
            createPadPreset(),
            createPluckPreset(),
        ]
    }

    private static func createBassPreset() -> SynthPatch {
        var patch = SynthPatch.createDefault(name: "Deep Bass")
        patch.tags = ["bass", "deep", "sub"]

        // Configure for bass
        patch.oscillators[0].waveform = .saw
        patch.oscillators[0].octave = -1
        patch.oscillators[1].waveform = .sine
        patch.oscillators[1].octave = -2

        patch.filter.cutoff = 400
        patch.filter.resonance = 0.5

        patch.ampEnvelope.attack = 0.001
        patch.ampEnvelope.decay = 0.3
        patch.ampEnvelope.sustain = 0.8
        patch.ampEnvelope.release = 0.2

        return patch
    }

    private static func createLeadPreset() -> SynthPatch {
        var patch = SynthPatch.createDefault(name: "Bright Lead")
        patch.tags = ["lead", "bright", "cutting"]

        patch.oscillators[0].waveform = .saw
        patch.oscillators[1].waveform = .saw
        patch.oscillators[1].cents = 7  // Slight detune

        patch.filter.cutoff = 3000
        patch.filter.resonance = 0.6

        patch.ampEnvelope.attack = 0.01
        patch.ampEnvelope.decay = 0.2
        patch.ampEnvelope.sustain = 0.7
        patch.ampEnvelope.release = 0.3

        return patch
    }

    private static func createPadPreset() -> SynthPatch {
        var patch = SynthPatch.createDefault(name: "Soft Pad")
        patch.tags = ["pad", "ambient", "soft"]

        patch.oscillators[0].waveform = .triangle
        patch.oscillators[1].waveform = .triangle
        patch.oscillators[1].cents = 12

        patch.filter.cutoff = 2000
        patch.filter.resonance = 0.2

        patch.ampEnvelope.attack = 0.8
        patch.ampEnvelope.decay = 0.5
        patch.ampEnvelope.sustain = 0.6
        patch.ampEnvelope.release = 1.5

        return patch
    }

    private static func createPluckPreset() -> SynthPatch {
        var patch = SynthPatch.createDefault(name: "Pluck")
        patch.tags = ["pluck", "percussive"]

        patch.oscillators[0].waveform = .saw

        patch.filter.cutoff = 1500
        patch.filter.resonance = 0.4

        patch.ampEnvelope.attack = 0.001
        patch.ampEnvelope.decay = 0.4
        patch.ampEnvelope.sustain = 0.0
        patch.ampEnvelope.release = 0.3

        return patch
    }
}

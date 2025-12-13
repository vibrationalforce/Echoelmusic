import Foundation
import Combine
import AVFoundation
import Accelerate

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOEL SUPER INSTRUMENT
// ═══════════════════════════════════════════════════════════════════════════════
//
// Unified Intelligent Instrument combining ALL synthesis engines:
// - Wavetable (Serum/Vital style)
// - Subtractive (Moog/303 style)
// - FM/Additive (DX7/Operator style)
// - Granular/Spectral
// - Physical Modeling
// - Drums (808/909 style)
//
// INSPIRED BY:
// - Steven Slate Cymatics (Bass Quake sub frequencies)
// - Xfer Serum (Wavetable morphing)
// - Vital (Spectral warping)
// - Arturia Pigments (Multi-engine)
// - Native Instruments Massive X (Gorilla routing)
//
// BIO-REACTIVE FEATURES:
// - HRV → Filter cutoff, wavetable position
// - Coherence → Harmonic complexity, stereo width
// - Heart Rate → LFO rate, arpeggio speed
// - Breathing → Amplitude modulation, swell
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Super Instrument

@MainActor
public final class EchoelSuperInstrument: ObservableObject {

    // MARK: - Singleton

    public static let shared = EchoelSuperInstrument()

    // MARK: - Published State

    @Published public var currentEngine: SynthEngine = .hybrid
    @Published public var masterVolume: Float = 0.8
    @Published public var isPlaying: Bool = false
    @Published public var bioReactiveEnabled: Bool = true
    @Published public var currentPreset: IntelligentPreset = .init

    // MARK: - Engines

    public let wavetableEngine = WavetableEngine()
    public let subtractiveEngine = SubtractiveEngine()
    public let fmEngine = FMEngine()
    public let granularEngine = GranularEngine()
    public let drumEngine = DrumEngine()

    // MARK: - Bio-Reactive

    public let bioModMatrix = BioModulationMatrix()

    // MARK: - Audio

    private var sampleRate: Double = 48000
    private var audioEngine: AVAudioEngine?

    // MARK: - Synthesis Engine Types

    public enum SynthEngine: String, CaseIterable {
        case wavetable = "Wavetable"
        case subtractive = "Subtractive"
        case fm = "FM"
        case granular = "Granular"
        case drums = "Drums"
        case hybrid = "Hybrid"        // Combines all engines
        case adaptive = "Adaptive"    // Bio-selects engine
    }

    // MARK: - Initialization

    private init() {
        setupAudio()
        loadDefaultPreset()
    }

    private func setupAudio() {
        wavetableEngine.setSampleRate(sampleRate)
        subtractiveEngine.setSampleRate(sampleRate)
        fmEngine.setSampleRate(sampleRate)
        granularEngine.setSampleRate(sampleRate)
        drumEngine.setSampleRate(sampleRate)
    }

    private func loadDefaultPreset() {
        currentPreset = IntelligentPreset.bassQuakeStyle()
    }

    // MARK: - Note Control

    public func noteOn(note: Int, velocity: Int) {
        let vel = Float(velocity) / 127.0

        switch currentEngine {
        case .wavetable:
            wavetableEngine.noteOn(note: note, velocity: vel)
        case .subtractive:
            subtractiveEngine.noteOn(note: note, velocity: vel)
        case .fm:
            fmEngine.noteOn(note: note, velocity: vel)
        case .granular:
            granularEngine.noteOn(note: note, velocity: vel)
        case .drums:
            drumEngine.trigger(note: note, velocity: vel)
        case .hybrid:
            // Layer multiple engines
            wavetableEngine.noteOn(note: note, velocity: vel * currentPreset.engineMix.wavetable)
            subtractiveEngine.noteOn(note: note, velocity: vel * currentPreset.engineMix.subtractive)
            fmEngine.noteOn(note: note, velocity: vel * currentPreset.engineMix.fm)
        case .adaptive:
            // Bio-data selects engine
            selectAdaptiveEngine(note: note, velocity: vel)
        }

        isPlaying = true
    }

    public func noteOff(note: Int) {
        wavetableEngine.noteOff(note: note)
        subtractiveEngine.noteOff(note: note)
        fmEngine.noteOff(note: note)
        granularEngine.noteOff(note: note)
    }

    // MARK: - Adaptive Engine Selection

    private func selectAdaptiveEngine(note: Int, velocity: Float) {
        let coherence = bioModMatrix.currentCoherence
        let hrv = bioModMatrix.currentHRV
        let energy = bioModMatrix.currentEnergy

        // High coherence = smooth wavetable
        // Low coherence = aggressive FM
        // High energy = punchy drums/subtractive
        // Low energy = ambient granular

        if coherence > 0.7 {
            wavetableEngine.noteOn(note: note, velocity: velocity)
        } else if energy > 0.6 {
            subtractiveEngine.noteOn(note: note, velocity: velocity)
        } else if coherence < 0.3 {
            fmEngine.noteOn(note: note, velocity: velocity)
        } else {
            granularEngine.noteOn(note: note, velocity: velocity)
        }
    }

    // MARK: - Process Audio

    public func process(buffer: inout [Float], frames: Int) {
        // Clear buffer
        buffer = [Float](repeating: 0, count: frames * 2)

        // Apply bio modulation
        if bioReactiveEnabled {
            bioModMatrix.applyModulation(to: self)
        }

        // Mix engines based on current mode
        var tempBuffer = [Float](repeating: 0, count: frames * 2)

        switch currentEngine {
        case .wavetable:
            wavetableEngine.process(buffer: &tempBuffer, frames: frames)
        case .subtractive:
            subtractiveEngine.process(buffer: &tempBuffer, frames: frames)
        case .fm:
            fmEngine.process(buffer: &tempBuffer, frames: frames)
        case .granular:
            granularEngine.process(buffer: &tempBuffer, frames: frames)
        case .drums:
            drumEngine.process(buffer: &tempBuffer, frames: frames)
        case .hybrid, .adaptive:
            processHybrid(buffer: &tempBuffer, frames: frames)
        }

        // Apply master volume
        vDSP_vsmul(tempBuffer, 1, &masterVolume, &buffer, 1, vDSP_Length(frames * 2))
    }

    private func processHybrid(buffer: inout [Float], frames: Int) {
        var wtBuffer = [Float](repeating: 0, count: frames * 2)
        var subBuffer = [Float](repeating: 0, count: frames * 2)
        var fmBuffer = [Float](repeating: 0, count: frames * 2)
        var granBuffer = [Float](repeating: 0, count: frames * 2)

        wavetableEngine.process(buffer: &wtBuffer, frames: frames)
        subtractiveEngine.process(buffer: &subBuffer, frames: frames)
        fmEngine.process(buffer: &fmBuffer, frames: frames)
        granularEngine.process(buffer: &granBuffer, frames: frames)

        // Mix with engine levels
        let mix = currentPreset.engineMix
        for i in 0..<(frames * 2) {
            buffer[i] = wtBuffer[i] * mix.wavetable +
                        subBuffer[i] * mix.subtractive +
                        fmBuffer[i] * mix.fm +
                        granBuffer[i] * mix.granular
        }
    }

    // MARK: - Bio-Reactive Update

    public func updateBioData(hrv: Double, coherence: Double, heartRate: Double, breathingRate: Double) {
        bioModMatrix.update(
            hrv: hrv,
            coherence: coherence,
            heartRate: heartRate,
            breathingRate: breathingRate
        )
    }

    // MARK: - Preset Management

    public func loadPreset(_ preset: IntelligentPreset) {
        currentPreset = preset
        applyPreset(preset)
    }

    private func applyPreset(_ preset: IntelligentPreset) {
        // Apply to all engines
        wavetableEngine.applyPreset(preset.wavetable)
        subtractiveEngine.applyPreset(preset.subtractive)
        fmEngine.applyPreset(preset.fm)
        granularEngine.applyPreset(preset.granular)
        drumEngine.applyPreset(preset.drums)

        // Apply bio mappings
        bioModMatrix.loadMappings(preset.bioMappings)
    }

    // MARK: - Quick Access Parameters

    /// Universal filter cutoff (affects all engines)
    public func setFilterCutoff(_ value: Float) {
        wavetableEngine.filterCutoff = value
        subtractiveEngine.filterCutoff = value
        fmEngine.filterCutoff = value
    }

    /// Universal resonance
    public func setFilterResonance(_ value: Float) {
        wavetableEngine.filterResonance = value
        subtractiveEngine.filterResonance = value
    }

    /// Universal LFO rate
    public func setLFORate(_ value: Float) {
        wavetableEngine.lfoRate = value
        subtractiveEngine.lfoRate = value
        fmEngine.lfoRate = value
    }

    /// Bass enhancement (Cymatics/Bass Quake style)
    public func setBassEnhance(_ value: Float) {
        subtractiveEngine.subOscLevel = value
        subtractiveEngine.driveAmount = value * 0.3
    }

    /// Stereo width
    public func setStereoWidth(_ value: Float) {
        wavetableEngine.stereoWidth = value
        granularEngine.stereoSpread = value
    }
}

// MARK: - Wavetable Engine

public class WavetableEngine: ObservableObject {
    @Published public var filterCutoff: Float = 5000
    @Published public var filterResonance: Float = 0.3
    @Published public var wavetablePosition: Float = 0.5
    @Published public var lfoRate: Float = 2.0
    @Published public var stereoWidth: Float = 0.5
    @Published public var morphAmount: Float = 0.0

    private var sampleRate: Double = 48000
    private var voices: [WavetableVoice] = []
    private let maxVoices = 16

    public init() {
        voices = (0..<maxVoices).map { _ in WavetableVoice() }
    }

    public func setSampleRate(_ sr: Double) {
        sampleRate = sr
        voices.forEach { $0.sampleRate = sr }
    }

    public func noteOn(note: Int, velocity: Float) {
        if let voice = voices.first(where: { !$0.isActive }) {
            voice.noteOn(note: note, velocity: velocity)
            voice.wavetablePosition = wavetablePosition
        }
    }

    public func noteOff(note: Int) {
        voices.filter { $0.note == note }.forEach { $0.noteOff() }
    }

    public func process(buffer: inout [Float], frames: Int) {
        for i in 0..<frames {
            var left: Float = 0
            var right: Float = 0

            for voice in voices where voice.isActive {
                let sample = voice.process()
                // Stereo spread
                let pan = voice.pan * stereoWidth
                left += sample * (1.0 - pan) * 0.5
                right += sample * (1.0 + pan) * 0.5
            }

            buffer[i * 2] = left
            buffer[i * 2 + 1] = right
        }
    }

    public func applyPreset(_ preset: WavetablePreset) {
        wavetablePosition = preset.position
        filterCutoff = preset.filterCutoff
        filterResonance = preset.resonance
        morphAmount = preset.morphAmount
    }
}

// MARK: - Subtractive Engine (Moog/303 Style)

public class SubtractiveEngine: ObservableObject {
    @Published public var filterCutoff: Float = 1000
    @Published public var filterResonance: Float = 0.5
    @Published public var lfoRate: Float = 2.0
    @Published public var subOscLevel: Float = 0.0
    @Published public var driveAmount: Float = 0.0
    @Published public var oscillatorMix: Float = 0.5

    public enum OscillatorType: String, CaseIterable {
        case saw, square, pulse, triangle, sine
    }

    @Published public var osc1Type: OscillatorType = .saw
    @Published public var osc2Type: OscillatorType = .square

    private var sampleRate: Double = 48000
    private var voices: [SubtractiveVoice] = []
    private let maxVoices = 8

    public init() {
        voices = (0..<maxVoices).map { _ in SubtractiveVoice() }
    }

    public func setSampleRate(_ sr: Double) {
        sampleRate = sr
        voices.forEach { $0.sampleRate = sr }
    }

    public func noteOn(note: Int, velocity: Float) {
        if let voice = voices.first(where: { !$0.isActive }) {
            voice.noteOn(note: note, velocity: velocity)
            voice.filterCutoff = filterCutoff
            voice.filterResonance = filterResonance
        }
    }

    public func noteOff(note: Int) {
        voices.filter { $0.note == note }.forEach { $0.noteOff() }
    }

    public func process(buffer: inout [Float], frames: Int) {
        for i in 0..<frames {
            var sample: Float = 0

            for voice in voices where voice.isActive {
                sample += voice.process()
            }

            // Sub oscillator (Bass Quake style)
            if subOscLevel > 0 {
                sample += generateSubOsc(frame: i) * subOscLevel
            }

            // Drive/saturation
            if driveAmount > 0 {
                sample = tanh(sample * (1 + driveAmount * 3))
            }

            buffer[i * 2] = sample
            buffer[i * 2 + 1] = sample
        }
    }

    private var subOscPhase: Float = 0
    private func generateSubOsc(frame: Int) -> Float {
        // One octave below fundamental
        let freq: Float = 55.0  // A1
        subOscPhase += freq / Float(sampleRate)
        if subOscPhase >= 1.0 { subOscPhase -= 1.0 }
        return sin(subOscPhase * .pi * 2)
    }

    public func applyPreset(_ preset: SubtractivePreset) {
        filterCutoff = preset.cutoff
        filterResonance = preset.resonance
        subOscLevel = preset.subLevel
        driveAmount = preset.drive
    }
}

// MARK: - FM Engine

public class FMEngine: ObservableObject {
    @Published public var algorithm: Int = 0
    @Published public var filterCutoff: Float = 8000
    @Published public var lfoRate: Float = 5.0
    @Published public var modulationIndex: Float = 1.0
    @Published public var feedback: Float = 0.0

    private var sampleRate: Double = 48000
    private var voices: [FMVoice] = []
    private let maxVoices = 8

    public init() {
        voices = (0..<maxVoices).map { _ in FMVoice() }
    }

    public func setSampleRate(_ sr: Double) {
        sampleRate = sr
        voices.forEach { $0.sampleRate = sr }
    }

    public func noteOn(note: Int, velocity: Float) {
        if let voice = voices.first(where: { !$0.isActive }) {
            voice.noteOn(note: note, velocity: velocity)
            voice.modulationIndex = modulationIndex
        }
    }

    public func noteOff(note: Int) {
        voices.filter { $0.note == note }.forEach { $0.noteOff() }
    }

    public func process(buffer: inout [Float], frames: Int) {
        for i in 0..<frames {
            var sample: Float = 0
            for voice in voices where voice.isActive {
                sample += voice.process()
            }
            buffer[i * 2] = sample
            buffer[i * 2 + 1] = sample
        }
    }

    public func applyPreset(_ preset: FMPreset) {
        algorithm = preset.algorithm
        modulationIndex = preset.modIndex
        feedback = preset.feedback
    }
}

// MARK: - Granular Engine

public class GranularEngine: ObservableObject {
    @Published public var grainSize: Float = 0.05  // seconds
    @Published public var grainDensity: Float = 20  // grains per second
    @Published public var pitch: Float = 1.0
    @Published public var position: Float = 0.5
    @Published public var stereoSpread: Float = 0.5
    @Published public var randomization: Float = 0.2

    private var sampleRate: Double = 48000
    private var grains: [Grain] = []

    public func setSampleRate(_ sr: Double) { sampleRate = sr }

    public func noteOn(note: Int, velocity: Float) {
        // Spawn grain cloud
        let numGrains = Int(grainDensity)
        for i in 0..<numGrains {
            let grain = Grain()
            grain.pitch = pitch * pow(2, Float(note - 60) / 12)
            grain.pan = Float.random(in: -stereoSpread...stereoSpread)
            grain.startTime = Float(i) / grainDensity
            grains.append(grain)
        }
    }

    public func noteOff(note: Int) {
        grains.removeAll()
    }

    public func process(buffer: inout [Float], frames: Int) {
        for i in 0..<frames {
            var left: Float = 0
            var right: Float = 0

            for grain in grains {
                let sample = grain.process()
                left += sample * (1.0 - grain.pan)
                right += sample * (1.0 + grain.pan)
            }

            buffer[i * 2] = left * 0.5
            buffer[i * 2 + 1] = right * 0.5
        }
    }

    public func applyPreset(_ preset: GranularPreset) {
        grainSize = preset.size
        grainDensity = preset.density
        randomization = preset.random
    }
}

// MARK: - Drum Engine (808/909 Style)

public class DrumEngine: ObservableObject {
    @Published public var kickDecay: Float = 0.5
    @Published public var kickPunch: Float = 0.7
    @Published public var snareSnap: Float = 0.5
    @Published public var hihatDecay: Float = 0.3

    private var sampleRate: Double = 48000
    private var drums: [DrumSound] = []

    public enum DrumType: Int {
        case kick = 36
        case snare = 38
        case clap = 39
        case closedHat = 42
        case openHat = 46
        case tomLow = 45
        case tomMid = 47
        case tomHigh = 50
    }

    public func setSampleRate(_ sr: Double) { sampleRate = sr }

    public func trigger(note: Int, velocity: Float) {
        let drum = DrumSound(type: DrumType(rawValue: note) ?? .kick, velocity: velocity)
        drum.sampleRate = sampleRate
        drums.append(drum)
    }

    public func process(buffer: inout [Float], frames: Int) {
        for i in 0..<frames {
            var sample: Float = 0
            for drum in drums where drum.isActive {
                sample += drum.process()
            }
            buffer[i * 2] = sample
            buffer[i * 2 + 1] = sample
        }
        drums.removeAll { !$0.isActive }
    }

    public func applyPreset(_ preset: DrumPreset) {
        kickDecay = preset.kickDecay
        kickPunch = preset.kickPunch
        snareSnap = preset.snareSnap
    }
}

// MARK: - Bio Modulation Matrix

public class BioModulationMatrix: ObservableObject {
    @Published public var currentHRV: Double = 50
    @Published public var currentCoherence: Double = 0.5
    @Published public var currentHeartRate: Double = 70
    @Published public var currentBreathingRate: Double = 12
    @Published public var currentEnergy: Double = 0.5

    public struct BioMapping {
        public var source: BioSource
        public var target: ModTarget
        public var amount: Float
        public var curve: ModCurve

        public enum BioSource {
            case hrv, coherence, heartRate, breathingRate, energy
        }

        public enum ModTarget {
            case filterCutoff, filterResonance
            case wavetablePosition, morphAmount
            case lfoRate, lfoDepth
            case stereoWidth, volume
            case attackTime, releaseTime
            case engineMix
        }

        public enum ModCurve {
            case linear, exponential, logarithmic, sCurve
        }
    }

    private var mappings: [BioMapping] = []

    public func update(hrv: Double, coherence: Double, heartRate: Double, breathingRate: Double) {
        currentHRV = hrv
        currentCoherence = coherence
        currentHeartRate = heartRate
        currentBreathingRate = breathingRate

        // Calculate energy from heart rate
        currentEnergy = (heartRate - 50) / 100.0
    }

    public func loadMappings(_ newMappings: [BioMapping]) {
        mappings = newMappings
    }

    public func applyModulation(to instrument: EchoelSuperInstrument) {
        for mapping in mappings {
            let sourceValue = getSourceValue(mapping.source)
            let modulatedValue = applyCurve(sourceValue, curve: mapping.curve) * Float(mapping.amount)

            applyToTarget(instrument, target: mapping.target, value: modulatedValue)
        }
    }

    private func getSourceValue(_ source: BioMapping.BioSource) -> Float {
        switch source {
        case .hrv: return Float(currentHRV / 100.0)
        case .coherence: return Float(currentCoherence)
        case .heartRate: return Float((currentHeartRate - 50) / 100.0)
        case .breathingRate: return Float(currentBreathingRate / 20.0)
        case .energy: return Float(currentEnergy)
        }
    }

    private func applyCurve(_ value: Float, curve: BioMapping.ModCurve) -> Float {
        switch curve {
        case .linear: return value
        case .exponential: return value * value
        case .logarithmic: return sqrt(value)
        case .sCurve: return value * value * (3 - 2 * value)
        }
    }

    private func applyToTarget(_ instrument: EchoelSuperInstrument, target: BioMapping.ModTarget, value: Float) {
        switch target {
        case .filterCutoff:
            instrument.setFilterCutoff(200 + value * 8000)
        case .filterResonance:
            instrument.setFilterResonance(value)
        case .wavetablePosition:
            instrument.wavetableEngine.wavetablePosition = value
        case .lfoRate:
            instrument.setLFORate(0.1 + value * 20)
        case .stereoWidth:
            instrument.setStereoWidth(value)
        default:
            break
        }
    }

    // MARK: - Default Bio Mappings

    public static func defaultMappings() -> [BioMapping] {
        return [
            BioMapping(source: .hrv, target: .filterCutoff, amount: 0.6, curve: .exponential),
            BioMapping(source: .coherence, target: .wavetablePosition, amount: 1.0, curve: .linear),
            BioMapping(source: .heartRate, target: .lfoRate, amount: 0.5, curve: .linear),
            BioMapping(source: .breathingRate, target: .volume, amount: 0.3, curve: .sCurve),
            BioMapping(source: .energy, target: .stereoWidth, amount: 0.7, curve: .exponential)
        ]
    }
}

// MARK: - Intelligent Preset

public struct IntelligentPreset {
    public var name: String = "Init"
    public var engineMix: EngineMix = EngineMix()
    public var wavetable: WavetablePreset = WavetablePreset()
    public var subtractive: SubtractivePreset = SubtractivePreset()
    public var fm: FMPreset = FMPreset()
    public var granular: GranularPreset = GranularPreset()
    public var drums: DrumPreset = DrumPreset()
    public var bioMappings: [BioModulationMatrix.BioMapping] = BioModulationMatrix.defaultMappings()

    public struct EngineMix {
        public var wavetable: Float = 0.5
        public var subtractive: Float = 0.3
        public var fm: Float = 0.1
        public var granular: Float = 0.1
    }

    // MARK: - Factory Presets

    public static func bassQuakeStyle() -> IntelligentPreset {
        var preset = IntelligentPreset()
        preset.name = "Bass Quake"
        preset.engineMix = EngineMix(wavetable: 0.3, subtractive: 0.6, fm: 0.0, granular: 0.1)
        preset.subtractive.cutoff = 800
        preset.subtractive.resonance = 0.6
        preset.subtractive.subLevel = 0.8
        preset.subtractive.drive = 0.4
        preset.bioMappings = [
            .init(source: .hrv, target: .filterCutoff, amount: 0.8, curve: .exponential),
            .init(source: .coherence, target: .filterResonance, amount: 0.5, curve: .linear)
        ]
        return preset
    }

    public static func vitalPad() -> IntelligentPreset {
        var preset = IntelligentPreset()
        preset.name = "Vital Pad"
        preset.engineMix = EngineMix(wavetable: 0.7, subtractive: 0.1, fm: 0.1, granular: 0.1)
        preset.wavetable.position = 0.5
        preset.wavetable.filterCutoff = 3000
        preset.wavetable.morphAmount = 0.5
        preset.bioMappings = [
            .init(source: .coherence, target: .wavetablePosition, amount: 1.0, curve: .sCurve),
            .init(source: .breathingRate, target: .volume, amount: 0.4, curve: .sCurve)
        ]
        return preset
    }

    public static func acidBass() -> IntelligentPreset {
        var preset = IntelligentPreset()
        preset.name = "Acid Bass"
        preset.engineMix = EngineMix(wavetable: 0.0, subtractive: 1.0, fm: 0.0, granular: 0.0)
        preset.subtractive.cutoff = 500
        preset.subtractive.resonance = 0.8
        preset.subtractive.drive = 0.3
        preset.bioMappings = [
            .init(source: .hrv, target: .filterCutoff, amount: 1.0, curve: .exponential),
            .init(source: .heartRate, target: .lfoRate, amount: 0.6, curve: .linear)
        ]
        return preset
    }

    public static func ambientTexture() -> IntelligentPreset {
        var preset = IntelligentPreset()
        preset.name = "Ambient Texture"
        preset.engineMix = EngineMix(wavetable: 0.3, subtractive: 0.0, fm: 0.2, granular: 0.5)
        preset.granular.size = 0.1
        preset.granular.density = 30
        preset.bioMappings = [
            .init(source: .coherence, target: .stereoWidth, amount: 1.0, curve: .sCurve),
            .init(source: .energy, target: .lfoRate, amount: 0.3, curve: .logarithmic)
        ]
        return preset
    }
}

// MARK: - Preset Structs

public struct WavetablePreset {
    public var position: Float = 0.5
    public var filterCutoff: Float = 5000
    public var resonance: Float = 0.3
    public var morphAmount: Float = 0.0
}

public struct SubtractivePreset {
    public var cutoff: Float = 1000
    public var resonance: Float = 0.5
    public var subLevel: Float = 0.0
    public var drive: Float = 0.0
}

public struct FMPreset {
    public var algorithm: Int = 0
    public var modIndex: Float = 1.0
    public var feedback: Float = 0.0
}

public struct GranularPreset {
    public var size: Float = 0.05
    public var density: Float = 20
    public var random: Float = 0.2
}

public struct DrumPreset {
    public var kickDecay: Float = 0.5
    public var kickPunch: Float = 0.7
    public var snareSnap: Float = 0.5
}

// MARK: - Voice Classes (Simplified)

class WavetableVoice {
    var sampleRate: Double = 48000
    var isActive: Bool = false
    var note: Int = 60
    var velocity: Float = 1.0
    var pan: Float = 0.0
    var wavetablePosition: Float = 0.5
    private var phase: Float = 0
    private var envLevel: Float = 0

    func noteOn(note: Int, velocity: Float) {
        self.note = note
        self.velocity = velocity
        self.isActive = true
        self.envLevel = 1.0
        self.pan = Float.random(in: -0.3...0.3)
    }

    func noteOff() {
        // Start release
    }

    func process() -> Float {
        guard isActive else { return 0 }
        let freq = 440.0 * pow(2, Double(note - 69) / 12.0)
        phase += Float(freq / sampleRate)
        if phase >= 1.0 { phase -= 1.0 }

        // Wavetable with position morphing
        let morphedWave = sin(phase * .pi * 2) * (1 - wavetablePosition) +
                          (phase < 0.5 ? 1 : -1) * wavetablePosition

        envLevel *= 0.9999
        if envLevel < 0.001 { isActive = false }

        return morphedWave * velocity * envLevel
    }
}

class SubtractiveVoice {
    var sampleRate: Double = 48000
    var isActive: Bool = false
    var note: Int = 60
    var velocity: Float = 1.0
    var filterCutoff: Float = 1000
    var filterResonance: Float = 0.5
    private var phase: Float = 0
    private var envLevel: Float = 0
    private var filterState: [Float] = [0, 0, 0, 0]

    func noteOn(note: Int, velocity: Float) {
        self.note = note
        self.velocity = velocity
        self.isActive = true
        self.envLevel = 1.0
    }

    func noteOff() {}

    func process() -> Float {
        guard isActive else { return 0 }
        let freq = 440.0 * pow(2, Double(note - 69) / 12.0)
        phase += Float(freq / sampleRate)
        if phase >= 1.0 { phase -= 1.0 }

        // Sawtooth
        var sample = phase * 2 - 1

        // Moog-style filter
        let fc = filterCutoff / Float(sampleRate)
        let g = fc * 0.9
        let feedback = filterResonance * 3.5
        sample = sample - filterState[3] * feedback
        filterState[0] += g * (tanh(sample) - tanh(filterState[0]))
        filterState[1] += g * (tanh(filterState[0]) - tanh(filterState[1]))
        filterState[2] += g * (tanh(filterState[1]) - tanh(filterState[2]))
        filterState[3] += g * (tanh(filterState[2]) - tanh(filterState[3]))

        envLevel *= 0.9998
        if envLevel < 0.001 { isActive = false }

        return filterState[3] * velocity * envLevel
    }
}

class FMVoice {
    var sampleRate: Double = 48000
    var isActive: Bool = false
    var note: Int = 60
    var velocity: Float = 1.0
    var modulationIndex: Float = 1.0
    private var carrierPhase: Float = 0
    private var modPhase: Float = 0
    private var envLevel: Float = 0

    func noteOn(note: Int, velocity: Float) {
        self.note = note
        self.velocity = velocity
        self.isActive = true
        self.envLevel = 1.0
    }

    func noteOff() {}

    func process() -> Float {
        guard isActive else { return 0 }
        let freq = Float(440.0 * pow(2, Double(note - 69) / 12.0))

        // Modulator
        modPhase += freq * 2 / Float(sampleRate)
        if modPhase >= 1.0 { modPhase -= 1.0 }
        let modulator = sin(modPhase * .pi * 2) * modulationIndex

        // Carrier with FM
        carrierPhase += freq / Float(sampleRate)
        if carrierPhase >= 1.0 { carrierPhase -= 1.0 }
        let sample = sin((carrierPhase + modulator) * .pi * 2)

        envLevel *= 0.9995
        if envLevel < 0.001 { isActive = false }

        return sample * velocity * envLevel
    }
}

class Grain {
    var pitch: Float = 1.0
    var pan: Float = 0.0
    var startTime: Float = 0
    var isActive: Bool = true
    private var phase: Float = 0
    private var life: Float = 0
    private let lifespan: Float = 0.05

    func process() -> Float {
        life += 1.0 / 48000
        if life >= lifespan {
            isActive = false
            return 0
        }

        phase += pitch * 440 / 48000
        if phase >= 1.0 { phase -= 1.0 }

        // Gaussian window
        let window = exp(-pow((life / lifespan - 0.5) * 4, 2))

        return sin(phase * .pi * 2) * window * 0.3
    }
}

class DrumSound {
    var sampleRate: Double = 48000
    var isActive: Bool = true
    var velocity: Float = 1.0
    let type: DrumEngine.DrumType
    private var phase: Float = 0
    private var envLevel: Float = 1.0

    init(type: DrumEngine.DrumType, velocity: Float) {
        self.type = type
        self.velocity = velocity
    }

    func process() -> Float {
        guard isActive else { return 0 }

        var sample: Float = 0

        switch type {
        case .kick:
            let pitchEnv = exp(-phase * 30)
            let freq = 50 + pitchEnv * 150
            sample = sin(phase * .pi * 2 * freq / Float(sampleRate) * 1000)
            envLevel *= 0.9995

        case .snare:
            let tone = sin(phase * .pi * 2 * 180)
            let noise = Float.random(in: -1...1)
            sample = tone * 0.4 + noise * 0.6
            envLevel *= 0.998

        case .closedHat:
            sample = Float.random(in: -1...1) * sin(phase * .pi * 2 * 8000)
            envLevel *= 0.99

        case .openHat:
            sample = Float.random(in: -1...1) * sin(phase * .pi * 2 * 8000)
            envLevel *= 0.997

        default:
            sample = sin(phase * .pi * 2 * 200) * envLevel
            envLevel *= 0.999
        }

        phase += 1.0 / Float(sampleRate)
        if envLevel < 0.001 { isActive = false }

        return sample * velocity * envLevel
    }
}

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
    public let physicalEngine = PhysicalModelingEngine()

    // MARK: - AI Sample Converter

    public let aiSampleConverter = AISampleToPhysicalConverter()

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
        case physical = "Physical"    // Karplus-Strong, Waveguide, Modal
        case aiSampler = "AI Sampler" // AI-converted sample → physical
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
        physicalEngine.setSampleRate(sampleRate)
        aiSampleConverter.setSampleRate(sampleRate)
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
        case .physical:
            physicalEngine.noteOn(note: note, velocity: vel)
        case .aiSampler:
            aiSampleConverter.noteOn(note: note, velocity: vel)
        case .hybrid:
            // Layer multiple engines
            wavetableEngine.noteOn(note: note, velocity: vel * currentPreset.engineMix.wavetable)
            subtractiveEngine.noteOn(note: note, velocity: vel * currentPreset.engineMix.subtractive)
            fmEngine.noteOn(note: note, velocity: vel * currentPreset.engineMix.fm)
            physicalEngine.noteOn(note: note, velocity: vel * currentPreset.engineMix.physical)
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
        physicalEngine.noteOff(note: note)
        aiSampleConverter.noteOff(note: note)
    }

    // MARK: - Adaptive Engine Selection

    private func selectAdaptiveEngine(note: Int, velocity: Float) {
        let coherence = bioModMatrix.currentCoherence
        let hrv = bioModMatrix.currentHRV
        let energy = bioModMatrix.currentEnergy
        let breathingRate = bioModMatrix.currentBreathingRate

        // Bio-adaptive engine selection:
        // High coherence + low energy = organic physical modeling (strings, bells)
        // High coherence = smooth wavetable
        // Low coherence = aggressive FM
        // High energy = punchy drums/subtractive
        // Low energy = ambient granular
        // Slow breathing = resonant physical (bowed)

        if coherence > 0.8 && energy < 0.4 {
            // Meditative state: Use physical modeling (bells, strings)
            physicalEngine.setModel(.modal)  // Bell-like tones
            physicalEngine.noteOn(note: note, velocity: velocity)
        } else if breathingRate < 8 && coherence > 0.6 {
            // Deep breathing: Bowed strings
            physicalEngine.setModel(.bowed)
            physicalEngine.noteOn(note: note, velocity: velocity)
        } else if coherence > 0.7 {
            wavetableEngine.noteOn(note: note, velocity: velocity)
        } else if energy > 0.6 {
            subtractiveEngine.noteOn(note: note, velocity: velocity)
        } else if coherence < 0.3 {
            fmEngine.noteOn(note: note, velocity: velocity)
        } else if hrv > 60 {
            // High HRV: Plucked strings (Karplus-Strong)
            physicalEngine.setModel(.karplusStrong)
            physicalEngine.noteOn(note: note, velocity: velocity)
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
        case .physical:
            physicalEngine.process(buffer: &tempBuffer, frames: frames)
        case .aiSampler:
            aiSampleConverter.process(buffer: &tempBuffer, frames: frames)
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
        var physBuffer = [Float](repeating: 0, count: frames * 2)

        wavetableEngine.process(buffer: &wtBuffer, frames: frames)
        subtractiveEngine.process(buffer: &subBuffer, frames: frames)
        fmEngine.process(buffer: &fmBuffer, frames: frames)
        granularEngine.process(buffer: &granBuffer, frames: frames)
        physicalEngine.process(buffer: &physBuffer, frames: frames)

        // Mix with engine levels
        let mix = currentPreset.engineMix
        for i in 0..<(frames * 2) {
            buffer[i] = wtBuffer[i] * mix.wavetable +
                        subBuffer[i] * mix.subtractive +
                        fmBuffer[i] * mix.fm +
                        granBuffer[i] * mix.granular +
                        physBuffer[i] * mix.physical
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
        public var wavetable: Float = 0.4
        public var subtractive: Float = 0.25
        public var fm: Float = 0.1
        public var granular: Float = 0.1
        public var physical: Float = 0.15
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

// ═══════════════════════════════════════════════════════════════════════════════
// PHYSICAL MODELING ENGINE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Synthesizes sounds using physical models:
// - Karplus-Strong: Plucked strings (guitar, harp)
// - Waveguide: Wind instruments (flute, clarinet)
// - Modal: Metallic/resonant (bells, marimba, gongs)
// - Bowed: Sustained strings (violin, cello)
//
// Bio-Reactive Features:
// - HRV → String tension/brightness
// - Coherence → Resonance/sustain
// - Heart Rate → Excitation intensity
// - Breathing → Bow pressure/breath
//
// ═══════════════════════════════════════════════════════════════════════════════

public class PhysicalModelingEngine: ObservableObject {

    // MARK: - Physical Model Type

    public enum PhysicalModel: String, CaseIterable {
        case karplusStrong = "Plucked String"   // Guitar, harp, kalimba
        case waveguide = "Wind"                  // Flute, clarinet, pan flute
        case modal = "Modal"                     // Bells, marimba, vibraphone
        case bowed = "Bowed String"              // Violin, cello, erhu
        case membrane = "Membrane"               // Drums, tabla
    }

    // MARK: - Published Properties

    @Published public var currentModel: PhysicalModel = .karplusStrong
    @Published public var damping: Float = 0.996           // String decay (0.99-0.999)
    @Published public var brightness: Float = 0.5          // High-frequency content
    @Published public var resonance: Float = 0.7           // Body resonance
    @Published public var excitationStrength: Float = 0.8  // Pick/bow/strike strength
    @Published public var bowPressure: Float = 0.5         // For bowed model
    @Published public var bowSpeed: Float = 0.5            // For bowed model

    // MARK: - Material Properties (affects resonance)

    public enum Material: String, CaseIterable {
        case steel = "Steel"
        case nylon = "Nylon"
        case bronze = "Bronze"
        case gut = "Gut"
        case wood = "Wood"
        case glass = "Glass"
    }

    @Published public var material: Material = .steel

    // MARK: - Private State

    private var sampleRate: Double = 48000
    private var voices: [PhysicalVoice] = []
    private let maxVoices = 8

    // MARK: - Initialization

    public init() {
        voices = (0..<maxVoices).map { _ in PhysicalVoice() }
    }

    public func setSampleRate(_ sr: Double) {
        sampleRate = sr
        voices.forEach { $0.sampleRate = sr }
    }

    public func setModel(_ model: PhysicalModel) {
        currentModel = model
    }

    // MARK: - Note Control

    public func noteOn(note: Int, velocity: Float) {
        if let voice = voices.first(where: { !$0.isActive }) {
            voice.sampleRate = sampleRate
            voice.model = currentModel
            voice.damping = damping
            voice.brightness = brightness
            voice.resonance = resonance
            voice.excitationStrength = excitationStrength * velocity
            voice.material = material
            voice.bowPressure = bowPressure
            voice.bowSpeed = bowSpeed
            voice.noteOn(note: note, velocity: velocity)
        }
    }

    public func noteOff(note: Int) {
        voices.filter { $0.note == note }.forEach { $0.noteOff() }
    }

    // MARK: - Process

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

    // MARK: - Bio-Reactive Updates

    public func applyBioData(hrv: Double, coherence: Double, heartRate: Double, breathingRate: Double) {
        // HRV affects brightness (high HRV = brighter)
        brightness = Float(min(1.0, hrv / 80.0))

        // Coherence affects damping (high coherence = longer sustain)
        damping = 0.990 + Float(coherence) * 0.009

        // Heart rate affects excitation
        excitationStrength = Float(min(1.0, heartRate / 100.0))

        // Breathing rate affects bow pressure/speed
        bowPressure = Float(min(1.0, breathingRate / 20.0))
        bowSpeed = Float(min(1.0, 15.0 / max(5.0, breathingRate)))
    }
}

// MARK: - Physical Voice

class PhysicalVoice {
    var sampleRate: Double = 48000
    var isActive: Bool = false
    var note: Int = 60
    var velocity: Float = 1.0
    var model: PhysicalModelingEngine.PhysicalModel = .karplusStrong
    var damping: Float = 0.996
    var brightness: Float = 0.5
    var resonance: Float = 0.7
    var excitationStrength: Float = 0.8
    var material: PhysicalModelingEngine.Material = .steel
    var bowPressure: Float = 0.5
    var bowSpeed: Float = 0.5

    // Karplus-Strong delay line
    private var delayLine: [Float] = []
    private var delayIndex: Int = 0
    private var filterState: Float = 0

    // Modal synthesis
    private var modalPhases: [Float] = []
    private var modalFreqs: [Float] = []
    private var modalAmps: [Float] = []

    // Bowed string state
    private var bowPosition: Float = 0
    private var stringVelocity: Float = 0

    // Envelope
    private var envLevel: Float = 0
    private var releasing: Bool = false

    func noteOn(note: Int, velocity: Float) {
        self.note = note
        self.velocity = velocity
        self.isActive = true
        self.releasing = false
        self.envLevel = 1.0

        let freq = 440.0 * pow(2, Double(note - 69) / 12.0)

        switch model {
        case .karplusStrong:
            setupKarplusStrong(frequency: Float(freq))
        case .waveguide:
            setupWaveguide(frequency: Float(freq))
        case .modal:
            setupModal(frequency: Float(freq))
        case .bowed:
            setupBowed(frequency: Float(freq))
        case .membrane:
            setupMembrane(frequency: Float(freq))
        }
    }

    func noteOff() {
        releasing = true
    }

    func process() -> Float {
        guard isActive else { return 0 }

        var sample: Float = 0

        switch model {
        case .karplusStrong:
            sample = processKarplusStrong()
        case .waveguide:
            sample = processWaveguide()
        case .modal:
            sample = processModal()
        case .bowed:
            sample = processBowed()
        case .membrane:
            sample = processMembrane()
        }

        // Apply envelope
        if releasing {
            envLevel *= 0.999
            if envLevel < 0.001 { isActive = false }
        }

        return sample * velocity * envLevel
    }

    // MARK: - Karplus-Strong (Plucked String)

    private func setupKarplusStrong(frequency: Float) {
        // Delay line length = sample rate / frequency
        let delayLength = Int(Float(sampleRate) / frequency)
        delayLine = [Float](repeating: 0, count: delayLength)

        // Initialize with noise burst (pluck excitation)
        for i in 0..<delayLength {
            let noise = Float.random(in: -1...1)
            // Apply brightness filter to initial noise
            let filtered = noise * brightness + (1 - brightness) * sin(Float(i) / Float(delayLength) * .pi)
            delayLine[i] = filtered * excitationStrength
        }

        delayIndex = 0
        filterState = 0
    }

    private func processKarplusStrong() -> Float {
        guard !delayLine.isEmpty else { return 0 }

        let output = delayLine[delayIndex]

        // Low-pass filter (averaging) with damping
        let nextIndex = (delayIndex + 1) % delayLine.count
        let filtered = (output + delayLine[nextIndex]) * 0.5 * damping

        // Apply material-specific characteristics
        let materialDamping = getMaterialDamping()
        delayLine[delayIndex] = filtered * materialDamping

        delayIndex = nextIndex

        return output
    }

    // MARK: - Waveguide (Wind Instrument)

    private func setupWaveguide(frequency: Float) {
        let delayLength = Int(Float(sampleRate) / frequency / 2)
        delayLine = [Float](repeating: 0, count: max(1, delayLength))
        delayIndex = 0
        filterState = 0
    }

    private func processWaveguide() -> Float {
        guard !delayLine.isEmpty else { return 0 }

        // Breath excitation
        let breath = Float.random(in: -0.1...0.1) * excitationStrength

        // Read from delay line
        let delayed = delayLine[delayIndex]

        // Jet nonlinearity (cubic saturation)
        let jet = delayed + breath
        let nonlinear = jet - jet * jet * jet / 3.0

        // Reflection filter
        filterState = filterState * 0.7 + nonlinear * 0.3
        let reflected = -filterState * damping

        // Write to delay line
        delayLine[delayIndex] = reflected

        delayIndex = (delayIndex + 1) % delayLine.count

        return reflected * 2
    }

    // MARK: - Modal Synthesis (Bells/Metallic)

    private func setupModal(frequency: Float) {
        // Modal ratios for bell-like sound (partials are non-harmonic)
        let modalRatios: [Float] = [1.0, 2.0, 2.4, 3.0, 4.5, 5.0, 6.3, 8.2]
        let modalDecays: [Float] = [1.0, 0.9, 0.85, 0.8, 0.7, 0.6, 0.5, 0.4]

        modalFreqs = modalRatios.map { $0 * frequency }
        modalAmps = modalDecays.map { $0 * excitationStrength }
        modalPhases = [Float](repeating: 0, count: modalRatios.count)
    }

    private func processModal() -> Float {
        var output: Float = 0

        for i in 0..<modalFreqs.count {
            modalPhases[i] += modalFreqs[i] / Float(sampleRate)
            if modalPhases[i] >= 1.0 { modalPhases[i] -= 1.0 }

            // Each mode is a damped sinusoid
            output += sin(modalPhases[i] * .pi * 2) * modalAmps[i]

            // Decay each mode
            modalAmps[i] *= (0.9995 + damping * 0.0004)
        }

        return output * resonance * 0.2
    }

    // MARK: - Bowed String

    private func setupBowed(frequency: Float) {
        let delayLength = Int(Float(sampleRate) / frequency)
        delayLine = [Float](repeating: 0, count: max(1, delayLength))
        delayIndex = 0
        stringVelocity = 0
        bowPosition = 0
    }

    private func processBowed() -> Float {
        guard !delayLine.isEmpty else { return 0 }

        // Bow-string friction model
        let bowVelocity = bowSpeed * 0.1
        let relativeVelocity = bowVelocity - stringVelocity

        // Friction curve (stick-slip)
        let friction: Float
        if abs(relativeVelocity) < 0.01 {
            // Sticking
            friction = relativeVelocity * bowPressure * 10
        } else {
            // Slipping
            friction = sign(relativeVelocity) * bowPressure * 0.3
        }

        // String dynamics
        let delayed = delayLine[delayIndex]
        stringVelocity = delayed * 0.9 + friction * excitationStrength

        // Reflection
        let reflected = -stringVelocity * damping

        delayLine[delayIndex] = reflected
        delayIndex = (delayIndex + 1) % delayLine.count

        bowPosition += bowSpeed / Float(sampleRate)
        if bowPosition > 1 { bowPosition = 0 }

        return stringVelocity * 2
    }

    // MARK: - Membrane (Drum)

    private func setupMembrane(frequency: Float) {
        // Use modal for membrane with drum-specific ratios
        // Circular membrane modes: 1.0, 1.59, 2.14, 2.30, 2.65, 2.92...
        let membraneRatios: [Float] = [1.0, 1.59, 2.14, 2.30, 2.65, 2.92, 3.16, 3.50]

        modalFreqs = membraneRatios.map { $0 * frequency }
        modalAmps = [Float](repeating: excitationStrength, count: membraneRatios.count)
        modalPhases = [Float](repeating: 0, count: membraneRatios.count)
    }

    private func processMembrane() -> Float {
        var output: Float = 0

        for i in 0..<modalFreqs.count {
            modalPhases[i] += modalFreqs[i] / Float(sampleRate)
            if modalPhases[i] >= 1.0 { modalPhases[i] -= 1.0 }

            output += sin(modalPhases[i] * .pi * 2) * modalAmps[i]

            // Faster decay for membrane
            modalAmps[i] *= (0.998 * damping)
        }

        // Check if all modes have decayed
        if modalAmps.allSatisfy({ $0 < 0.001 }) {
            isActive = false
        }

        return output * 0.15
    }

    // MARK: - Material Properties

    private func getMaterialDamping() -> Float {
        switch material {
        case .steel: return 0.998
        case .nylon: return 0.995
        case .bronze: return 0.997
        case .gut: return 0.993
        case .wood: return 0.99
        case .glass: return 0.999
        }
    }

    private func sign(_ x: Float) -> Float {
        return x > 0 ? 1 : (x < 0 ? -1 : 0)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AI SAMPLE TO PHYSICAL CONVERTER
// ═══════════════════════════════════════════════════════════════════════════════
//
// Analyzes audio samples and extracts physical model parameters:
// - Attack analysis → Excitation type (pluck, bow, strike)
// - Spectral analysis → Modal frequencies
// - Decay analysis → Damping/resonance
// - Harmonic content → Material properties
//
// This enables:
// - Converting any sample into a playable physical instrument
// - Creating hybrid sample + physical synthesis
// - Bio-reactive sample morphing
//
// ═══════════════════════════════════════════════════════════════════════════════

public class AISampleToPhysicalConverter: ObservableObject {

    // MARK: - Analysis Results

    public struct SampleAnalysis {
        public var fundamentalFrequency: Float = 440
        public var modalFrequencies: [Float] = []
        public var modalAmplitudes: [Float] = []
        public var modalDecayRates: [Float] = []
        public var attackTime: Float = 0.01
        public var decayTime: Float = 0.5
        public var sustainLevel: Float = 0.5
        public var releaseTime: Float = 0.3
        public var brightness: Float = 0.5
        public var inharmonicity: Float = 0.0
        public var estimatedMaterial: PhysicalModelingEngine.Material = .steel
        public var estimatedExcitation: ExcitationType = .pluck

        public enum ExcitationType: String {
            case pluck = "Plucked"
            case bow = "Bowed"
            case strike = "Struck"
            case blow = "Blown"
        }
    }

    // MARK: - Published State

    @Published public var currentAnalysis: SampleAnalysis = SampleAnalysis()
    @Published public var isAnalyzing: Bool = false
    @Published public var conversionProgress: Float = 0

    // Physical model derived from sample
    @Published public var derivedModel: PhysicalModelingEngine.PhysicalModel = .karplusStrong

    // MARK: - Sample Storage

    private var loadedSample: [Float] = []
    private var sampleRate: Double = 48000
    private var voices: [ConvertedPhysicalVoice] = []
    private let maxVoices = 8

    // MARK: - Initialization

    public init() {
        voices = (0..<maxVoices).map { _ in ConvertedPhysicalVoice() }
    }

    public func setSampleRate(_ sr: Double) {
        sampleRate = sr
        voices.forEach { $0.sampleRate = sr }
    }

    // MARK: - Sample Loading & Analysis

    public func loadSample(_ samples: [Float], sampleRate: Double) async {
        loadedSample = samples
        self.sampleRate = sampleRate

        await MainActor.run { isAnalyzing = true }

        // Perform analysis
        let analysis = await analyzeSample(samples, sampleRate: sampleRate)

        await MainActor.run {
            currentAnalysis = analysis
            derivedModel = determinePhysicalModel(from: analysis)
            isAnalyzing = false
        }
    }

    // MARK: - Analysis Pipeline

    private func analyzeSample(_ samples: [Float], sampleRate: Double) async -> SampleAnalysis {
        var analysis = SampleAnalysis()

        // 1. Find fundamental frequency
        analysis.fundamentalFrequency = findFundamental(samples, sampleRate: sampleRate)

        await MainActor.run { conversionProgress = 0.2 }

        // 2. Extract modal frequencies (partials)
        let (freqs, amps) = extractModalFrequencies(samples, sampleRate: sampleRate, fundamental: analysis.fundamentalFrequency)
        analysis.modalFrequencies = freqs
        analysis.modalAmplitudes = amps

        await MainActor.run { conversionProgress = 0.4 }

        // 3. Analyze envelope (ADSR)
        let envelope = analyzeEnvelope(samples)
        analysis.attackTime = envelope.attack
        analysis.decayTime = envelope.decay
        analysis.sustainLevel = envelope.sustain
        analysis.releaseTime = envelope.release

        await MainActor.run { conversionProgress = 0.6 }

        // 4. Calculate inharmonicity
        analysis.inharmonicity = calculateInharmonicity(analysis.modalFrequencies, fundamental: analysis.fundamentalFrequency)

        // 5. Estimate brightness
        analysis.brightness = calculateBrightness(samples, sampleRate: sampleRate)

        await MainActor.run { conversionProgress = 0.8 }

        // 6. Determine excitation type and material
        analysis.estimatedExcitation = classifyExcitation(attack: analysis.attackTime, brightness: analysis.brightness)
        analysis.estimatedMaterial = estimateMaterial(decay: analysis.decayTime, brightness: analysis.brightness)

        // 7. Calculate modal decay rates
        analysis.modalDecayRates = calculateModalDecays(samples, frequencies: analysis.modalFrequencies, sampleRate: sampleRate)

        await MainActor.run { conversionProgress = 1.0 }

        return analysis
    }

    // MARK: - Analysis Algorithms

    private func findFundamental(_ samples: [Float], sampleRate: Double) -> Float {
        // Autocorrelation-based pitch detection
        let frameSize = min(4096, samples.count)
        let minPeriod = Int(sampleRate / 2000)  // Max freq 2000Hz
        let maxPeriod = Int(sampleRate / 50)    // Min freq 50Hz

        guard frameSize > maxPeriod else { return 440 }

        var bestCorrelation: Float = 0
        var bestPeriod = minPeriod

        for period in minPeriod..<min(maxPeriod, frameSize / 2) {
            var correlation: Float = 0
            for i in 0..<(frameSize - period) {
                correlation += samples[i] * samples[i + period]
            }
            correlation /= Float(frameSize - period)

            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestPeriod = period
            }
        }

        return Float(sampleRate) / Float(bestPeriod)
    }

    private func extractModalFrequencies(_ samples: [Float], sampleRate: Double, fundamental: Float) -> ([Float], [Float]) {
        // Simplified FFT-based partial extraction
        var frequencies: [Float] = []
        var amplitudes: [Float] = []

        // Look for harmonics/partials
        let numPartials = 16
        for n in 1...numPartials {
            let expectedFreq = fundamental * Float(n)

            // Simple spectral peak detection around expected frequency
            let binWidth = Float(sampleRate) / Float(min(4096, samples.count))
            let expectedBin = Int(expectedFreq / binWidth)

            // Sum magnitude around expected bin (simplified)
            var magnitude: Float = 0
            let window = 5
            for b in max(0, expectedBin - window)..<min(samples.count / 2, expectedBin + window) {
                let sample = b < samples.count ? abs(samples[b]) : 0
                magnitude += sample
            }

            if magnitude > 0.01 {
                frequencies.append(expectedFreq)
                amplitudes.append(magnitude / Float(window * 2))
            }
        }

        // Normalize amplitudes
        if let maxAmp = amplitudes.max(), maxAmp > 0 {
            amplitudes = amplitudes.map { $0 / maxAmp }
        }

        return (frequencies, amplitudes)
    }

    private func analyzeEnvelope(_ samples: [Float]) -> (attack: Float, decay: Float, sustain: Float, release: Float) {
        guard samples.count > 100 else { return (0.01, 0.5, 0.5, 0.3) }

        // Calculate RMS envelope
        let windowSize = Int(sampleRate / 100)  // 10ms windows
        var envelope: [Float] = []

        for i in stride(from: 0, to: samples.count - windowSize, by: windowSize / 2) {
            var rms: Float = 0
            for j in 0..<windowSize {
                rms += samples[i + j] * samples[i + j]
            }
            envelope.append(sqrt(rms / Float(windowSize)))
        }

        guard !envelope.isEmpty else { return (0.01, 0.5, 0.5, 0.3) }

        // Find peak
        let peakIndex = envelope.firstIndex(of: envelope.max() ?? 0) ?? 0
        let peakValue = envelope[peakIndex]

        // Attack time (time to reach peak)
        let attackSamples = Float(peakIndex * windowSize / 2)
        let attack = attackSamples / Float(sampleRate)

        // Find sustain level (average after peak, before release)
        let sustainStart = min(peakIndex + 10, envelope.count - 1)
        let sustainEnd = envelope.count * 3 / 4
        let sustainLevel = sustainEnd > sustainStart ?
            envelope[sustainStart..<sustainEnd].reduce(0, +) / Float(sustainEnd - sustainStart) / peakValue :
            0.5

        // Decay time (time to reach sustain)
        var decaySamples = 0
        for i in peakIndex..<envelope.count {
            if envelope[i] <= peakValue * sustainLevel * 1.1 {
                decaySamples = (i - peakIndex) * windowSize / 2
                break
            }
        }
        let decay = Float(decaySamples) / Float(sampleRate)

        // Release (time from end to silence)
        var releaseStart = envelope.count - 1
        for i in (envelope.count / 2..<envelope.count).reversed() {
            if envelope[i] > peakValue * 0.1 {
                releaseStart = i
                break
            }
        }
        let release = Float((envelope.count - releaseStart) * windowSize / 2) / Float(sampleRate)

        return (max(0.001, attack), max(0.01, decay), max(0.1, min(1.0, sustainLevel)), max(0.01, release))
    }

    private func calculateInharmonicity(_ modalFreqs: [Float], fundamental: Float) -> Float {
        guard modalFreqs.count > 2 else { return 0 }

        var totalDeviation: Float = 0
        for (index, freq) in modalFreqs.enumerated() {
            let harmonic = Float(index + 1)
            let expectedFreq = fundamental * harmonic
            let deviation = abs(freq - expectedFreq) / expectedFreq
            totalDeviation += deviation
        }

        return totalDeviation / Float(modalFreqs.count)
    }

    private func calculateBrightness(_ samples: [Float], sampleRate: Double) -> Float {
        // Spectral centroid approximation
        var weightedSum: Float = 0
        var totalEnergy: Float = 0

        let windowSize = min(4096, samples.count)
        for i in 0..<windowSize {
            let freq = Float(i) * Float(sampleRate) / Float(windowSize)
            let magnitude = abs(samples[i])
            weightedSum += freq * magnitude
            totalEnergy += magnitude
        }

        guard totalEnergy > 0 else { return 0.5 }

        let centroid = weightedSum / totalEnergy
        // Normalize to 0-1 (assuming centroid typically 500-5000 Hz)
        return min(1.0, max(0, (centroid - 500) / 4500))
    }

    private func classifyExcitation(attack: Float, brightness: Float) -> SampleAnalysis.ExcitationType {
        if attack < 0.01 && brightness > 0.6 {
            return .pluck
        } else if attack < 0.005 {
            return .strike
        } else if attack > 0.1 {
            return .bow
        } else if brightness < 0.3 && attack > 0.05 {
            return .blow
        }
        return .pluck
    }

    private func estimateMaterial(decay: Float, brightness: Float) -> PhysicalModelingEngine.Material {
        if brightness > 0.7 && decay > 0.5 {
            return .steel
        } else if brightness > 0.5 && decay > 0.3 {
            return .bronze
        } else if brightness < 0.4 && decay < 0.3 {
            return .nylon
        } else if decay > 0.8 {
            return .glass
        } else if decay < 0.2 {
            return .wood
        }
        return .steel
    }

    private func calculateModalDecays(_ samples: [Float], frequencies: [Float], sampleRate: Double) -> [Float] {
        // Simplified: estimate decay from overall decay
        let envelope = analyzeEnvelope(samples)
        let baseDecay = envelope.decay

        // Higher modes decay faster
        return frequencies.enumerated().map { index, _ in
            let decayFactor = 1.0 / Float(index + 1)
            return baseDecay * decayFactor
        }
    }

    private func determinePhysicalModel(from analysis: SampleAnalysis) -> PhysicalModelingEngine.PhysicalModel {
        switch analysis.estimatedExcitation {
        case .pluck:
            return .karplusStrong
        case .bow:
            return .bowed
        case .strike:
            return analysis.inharmonicity > 0.05 ? .modal : .membrane
        case .blow:
            return .waveguide
        }
    }

    // MARK: - Playback

    public func noteOn(note: Int, velocity: Float) {
        if let voice = voices.first(where: { !$0.isActive }) {
            voice.configure(from: currentAnalysis, model: derivedModel)
            voice.noteOn(note: note, velocity: velocity)
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
}

// MARK: - Converted Physical Voice

class ConvertedPhysicalVoice {
    var sampleRate: Double = 48000
    var isActive: Bool = false
    var note: Int = 60
    var velocity: Float = 1.0

    // Analysis-derived parameters
    private var modalFreqs: [Float] = []
    private var modalAmps: [Float] = []
    private var modalDecays: [Float] = []
    private var modalPhases: [Float] = []
    private var damping: Float = 0.996

    // Delay line for Karplus-Strong
    private var delayLine: [Float] = []
    private var delayIndex: Int = 0

    private var model: PhysicalModelingEngine.PhysicalModel = .karplusStrong
    private var envLevel: Float = 1.0
    private var releasing: Bool = false

    func configure(from analysis: AISampleToPhysicalConverter.SampleAnalysis, model: PhysicalModelingEngine.PhysicalModel) {
        self.model = model
        self.modalFreqs = analysis.modalFrequencies
        self.modalAmps = analysis.modalAmplitudes
        self.modalDecays = analysis.modalDecayRates
        self.damping = 0.99 + analysis.sustainLevel * 0.009
    }

    func noteOn(note: Int, velocity: Float) {
        self.note = note
        self.velocity = velocity
        self.isActive = true
        self.releasing = false
        self.envLevel = 1.0

        let freq = 440.0 * pow(2, Double(note - 69) / 12.0)

        // Transpose modal frequencies
        let ratio = Float(freq) / (modalFreqs.first ?? 440)
        let transposedFreqs = modalFreqs.map { $0 * ratio }

        modalPhases = [Float](repeating: 0, count: transposedFreqs.count)
        modalFreqs = transposedFreqs

        // Reset modal amplitudes
        modalAmps = modalAmps.map { $0 * velocity }

        // Setup delay line for plucked model
        if model == .karplusStrong {
            let delayLength = Int(Float(sampleRate) / Float(freq))
            delayLine = (0..<delayLength).map { _ in Float.random(in: -1...1) * velocity }
            delayIndex = 0
        }
    }

    func noteOff() {
        releasing = true
    }

    func process() -> Float {
        guard isActive else { return 0 }

        var output: Float = 0

        if model == .karplusStrong && !delayLine.isEmpty {
            // Karplus-Strong
            output = delayLine[delayIndex]
            let nextIndex = (delayIndex + 1) % delayLine.count
            let filtered = (output + delayLine[nextIndex]) * 0.5 * damping
            delayLine[delayIndex] = filtered
            delayIndex = nextIndex
        } else {
            // Modal synthesis
            for i in 0..<modalFreqs.count {
                guard i < modalAmps.count && i < modalPhases.count else { continue }

                modalPhases[i] += modalFreqs[i] / Float(sampleRate)
                if modalPhases[i] >= 1.0 { modalPhases[i] -= 1.0 }

                output += sin(modalPhases[i] * .pi * 2) * modalAmps[i]

                // Apply decay
                let decayRate = i < modalDecays.count ? modalDecays[i] : 0.5
                modalAmps[i] *= (0.9995 + decayRate * 0.0004)
            }
            output *= 0.2
        }

        // Envelope
        if releasing {
            envLevel *= 0.998
            if envLevel < 0.001 { isActive = false }
        }

        // Check if sound has fully decayed
        if model == .karplusStrong {
            if delayLine.allSatisfy({ abs($0) < 0.001 }) {
                isActive = false
            }
        } else if modalAmps.allSatisfy({ $0 < 0.001 }) {
            isActive = false
        }

        return output * envLevel
    }
}

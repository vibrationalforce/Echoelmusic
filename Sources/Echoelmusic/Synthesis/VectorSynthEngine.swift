import Foundation
import Accelerate
import simd

// MARK: - Vector Synthesis Engine
// Based on Sequential Prophet VS and Korg Wavestation architecture
// Cross-platform: iOS, macOS, Windows, Linux, Android

/// VectorSynthEngine: Professional vector synthesis with joystick morphing
/// Combines 4 oscillator sources with 2D vector mixing (X/Y joystick control)
///
/// Architecture:
/// - 4 independent wave sources (A, B, C, D)
/// - 2D vector mixer (joystick position controls blend)
/// - Vector envelope for automated movement
/// - Wave sequencing capability (Wavestation-style)
///
/// Reference: Sequential Circuits Prophet VS (1986), Korg Wavestation (1990)
@MainActor
public final class VectorSynthEngine: ObservableObject {

    // MARK: - Constants

    /// Maximum polyphony
    public static let maxVoices: Int = 16

    /// Sample rate
    private var sampleRate: Double = 48000

    /// Oversampling factor for alias reduction
    private let oversamplingFactor: Int = 2

    // MARK: - Published State

    @Published public private(set) var isPlaying: Bool = false
    @Published public var vectorPosition: SIMD2<Float> = .zero  // -1 to +1 for X and Y
    @Published public var masterVolume: Float = 0.8

    // MARK: - Oscillator Sources

    /// Four vector sources (corners of the vector space)
    public var sourceA: VectorSource  // Top-Left
    public var sourceB: VectorSource  // Top-Right
    public var sourceC: VectorSource  // Bottom-Left
    public var sourceD: VectorSource  // Bottom-Right

    // MARK: - Vector Envelope

    /// Automated vector movement envelope
    public var vectorEnvelope: VectorEnvelope

    /// Wave sequence for Wavestation-style morphing
    public var waveSequence: WaveSequence?

    // MARK: - Voice Management

    private var voices: [VectorVoice] = []
    private var activeVoices: Set<Int> = []

    // MARK: - Modulation

    /// LFO for vector modulation
    public var vectorLFO: LFOGenerator

    /// Modulation matrix
    public var modMatrix: ModulationMatrix

    // MARK: - Effects

    /// Built-in chorus for classic vector sound
    private var chorus: ChorusEffect

    /// Reverb for spatial depth
    private var reverb: ReverbEffect

    // MARK: - Initialization

    public init(sampleRate: Double = 48000) {
        self.sampleRate = sampleRate

        // Initialize four vector sources with classic waveforms
        sourceA = VectorSource(waveform: .saw, detune: 0, sampleRate: sampleRate)
        sourceB = VectorSource(waveform: .pulse, detune: 0.02, sampleRate: sampleRate)
        sourceC = VectorSource(waveform: .triangle, detune: -0.02, sampleRate: sampleRate)
        sourceD = VectorSource(waveform: .wavetable, detune: 0, sampleRate: sampleRate)

        // Vector envelope (automated joystick movement)
        vectorEnvelope = VectorEnvelope()

        // LFO for vector modulation
        vectorLFO = LFOGenerator(sampleRate: sampleRate)

        // Modulation matrix
        modMatrix = ModulationMatrix()

        // Effects
        chorus = ChorusEffect(sampleRate: sampleRate)
        reverb = ReverbEffect(sampleRate: sampleRate)

        // Pre-allocate voices
        for i in 0..<Self.maxVoices {
            voices.append(VectorVoice(id: i, sampleRate: sampleRate))
        }

        setupDefaultPatch()
    }

    private func setupDefaultPatch() {
        // Classic vector pad sound
        sourceA.waveform = .saw
        sourceA.amplitude = 1.0

        sourceB.waveform = .pulse
        sourceB.pulseWidth = 0.3
        sourceB.amplitude = 1.0

        sourceC.waveform = .triangle
        sourceC.amplitude = 1.0

        sourceD.waveform = .sine
        sourceD.amplitude = 1.0

        // Subtle chorus
        chorus.rate = 0.5
        chorus.depth = 0.3
        chorus.mix = 0.3

        // Ambient reverb
        reverb.roomSize = 0.6
        reverb.damping = 0.4
        reverb.mix = 0.25
    }

    // MARK: - Voice Control

    /// Start a new note
    public func noteOn(note: Int, velocity: Float) {
        guard let voiceIndex = findFreeVoice() else {
            // Voice stealing: find oldest voice
            guard let oldest = findOldestVoice() else { return }
            voices[oldest].noteOff()
            startVoice(oldest, note: note, velocity: velocity)
            return
        }

        startVoice(voiceIndex, note: note, velocity: velocity)
    }

    /// Stop a note
    public func noteOff(note: Int) {
        for (index, voice) in voices.enumerated() where voice.currentNote == note && voice.isActive {
            voices[index].noteOff()
            activeVoices.remove(index)
        }
    }

    private func startVoice(_ index: Int, note: Int, velocity: Float) {
        voices[index].noteOn(note: note, velocity: velocity)
        activeVoices.insert(index)
        isPlaying = true
    }

    private func findFreeVoice() -> Int? {
        return voices.firstIndex { !$0.isActive }
    }

    private func findOldestVoice() -> Int? {
        return voices.enumerated()
            .filter { $0.element.isActive }
            .min { $0.element.startTime < $1.element.startTime }?
            .offset
    }

    // MARK: - Audio Processing

    /// Process audio buffer
    public func process(
        buffer: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        // Clear buffer
        vDSP_vclr(buffer, 1, vDSP_Length(frameCount))

        // Check if any voices are active
        guard !activeVoices.isEmpty else {
            isPlaying = false
            return
        }

        // Process each active voice
        for voiceIndex in activeVoices {
            processVoice(voiceIndex, buffer: buffer, frameCount: frameCount)
        }

        // Remove finished voices
        activeVoices = activeVoices.filter { voices[$0].isActive }

        // Apply master volume
        var volume = masterVolume
        vDSP_vsmul(buffer, 1, &volume, buffer, 1, vDSP_Length(frameCount))

        // Apply effects
        chorus.process(buffer: buffer, frameCount: frameCount)
        reverb.process(buffer: buffer, frameCount: frameCount)
    }

    private func processVoice(_ voiceIndex: Int, buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        let voice = voices[voiceIndex]

        // Temp buffer for voice output
        var voiceBuffer = [Float](repeating: 0, count: frameCount)

        for i in 0..<frameCount {
            // Update vector position from envelope + LFO
            let envPosition = vectorEnvelope.process()
            let lfoMod = vectorLFO.process()

            var currentVector = vectorPosition
            currentVector.x += envPosition.x * 0.5 + lfoMod * modMatrix.lfoToVectorX
            currentVector.y += envPosition.y * 0.5 + lfoMod * modMatrix.lfoToVectorY

            // Clamp to valid range
            currentVector.x = max(-1, min(1, currentVector.x))
            currentVector.y = max(-1, min(1, currentVector.y))

            // Calculate vector mix weights (bilinear interpolation)
            let weights = calculateVectorWeights(position: currentVector)

            // Get frequency for this voice
            let frequency = voice.currentFrequency

            // Generate samples from each source
            let sampleA = sourceA.generateSample(frequency: frequency, phase: voice.phaseA)
            let sampleB = sourceB.generateSample(frequency: frequency, phase: voice.phaseB)
            let sampleC = sourceC.generateSample(frequency: frequency, phase: voice.phaseC)
            let sampleD = sourceD.generateSample(frequency: frequency, phase: voice.phaseD)

            // Vector mix
            let mixed = sampleA * weights.a +
                       sampleB * weights.b +
                       sampleC * weights.c +
                       sampleD * weights.d

            // Apply voice envelope
            let envelope = voice.processEnvelope()

            // Apply velocity
            let output = mixed * envelope * voice.velocity

            voiceBuffer[i] = output

            // Update voice phases
            voices[voiceIndex].updatePhases(sampleRate: sampleRate)
        }

        // Add to main buffer
        vDSP_vadd(buffer, 1, voiceBuffer, 1, buffer, 1, vDSP_Length(frameCount))
    }

    /// Calculate bilinear interpolation weights for vector position
    private func calculateVectorWeights(position: SIMD2<Float>) -> (a: Float, b: Float, c: Float, d: Float) {
        // Convert -1...+1 to 0...1
        let x = (position.x + 1) * 0.5
        let y = (position.y + 1) * 0.5

        // Bilinear interpolation
        // A (top-left), B (top-right), C (bottom-left), D (bottom-right)
        let a = (1 - x) * y        // Top-Left
        let b = x * y              // Top-Right
        let c = (1 - x) * (1 - y)  // Bottom-Left
        let d = x * (1 - y)        // Bottom-Right

        return (a, b, c, d)
    }

    // MARK: - Preset Management

    /// Load a preset
    public func loadPreset(_ preset: VectorPreset) {
        sourceA = preset.sourceA
        sourceB = preset.sourceB
        sourceC = preset.sourceC
        sourceD = preset.sourceD
        vectorEnvelope = preset.vectorEnvelope
        vectorLFO.rate = preset.lfoRate
        vectorLFO.waveform = preset.lfoWaveform
        chorus.mix = preset.chorusMix
        reverb.mix = preset.reverbMix
    }

    /// Get current settings as preset
    public func currentPreset() -> VectorPreset {
        return VectorPreset(
            name: "Current",
            sourceA: sourceA,
            sourceB: sourceB,
            sourceC: sourceC,
            sourceD: sourceD,
            vectorEnvelope: vectorEnvelope,
            lfoRate: vectorLFO.rate,
            lfoWaveform: vectorLFO.waveform,
            chorusMix: chorus.mix,
            reverbMix: reverb.mix
        )
    }
}


// MARK: - Vector Source

/// Individual oscillator source for vector synthesis
public class VectorSource {

    public enum Waveform: String, CaseIterable, Codable {
        case sine = "Sine"
        case saw = "Sawtooth"
        case pulse = "Pulse"
        case triangle = "Triangle"
        case noise = "Noise"
        case wavetable = "Wavetable"

        // Advanced waveforms
        case superSaw = "Super Saw"
        case pwm = "PWM"
        case sync = "Sync"
        case formant = "Formant"
    }

    public var waveform: Waveform = .saw
    public var amplitude: Float = 1.0
    public var detune: Float = 0.0  // Cents
    public var pulseWidth: Float = 0.5
    public var wavetablePosition: Float = 0.0

    // Super Saw parameters
    public var superSawVoices: Int = 7
    public var superSawDetune: Float = 0.3

    // Formant parameters
    public var formantVowel: Int = 0  // 0-4: A, E, I, O, U

    private var sampleRate: Double
    private var wavetable: [Float] = []
    private var noiseState: UInt32 = 1

    public init(waveform: Waveform, detune: Float, sampleRate: Double) {
        self.waveform = waveform
        self.detune = detune
        self.sampleRate = sampleRate
        initializeWavetable()
    }

    private func initializeWavetable() {
        // Generate a basic wavetable with multiple waveforms morphable
        let tableSize = 2048
        wavetable = [Float](repeating: 0, count: tableSize * 4)  // 4 waves

        for i in 0..<tableSize {
            let phase = Float(i) / Float(tableSize) * 2 * .pi

            // Wave 0: Sine
            wavetable[i] = sin(phase)

            // Wave 1: Soft saw
            wavetable[tableSize + i] = 2 * (Float(i) / Float(tableSize)) - 1

            // Wave 2: Triangle
            let t = Float(i) / Float(tableSize)
            wavetable[tableSize * 2 + i] = t < 0.5 ? 4 * t - 1 : 3 - 4 * t

            // Wave 3: Pulse
            wavetable[tableSize * 3 + i] = Float(i) / Float(tableSize) < 0.5 ? 1 : -1
        }
    }

    /// Generate a sample at given frequency and phase
    public func generateSample(frequency: Float, phase: Double) -> Float {
        // Apply detune
        let detuneRatio = pow(2.0, Double(detune) / 1200.0)
        let detunedFreq = frequency * Float(detuneRatio)

        switch waveform {
        case .sine:
            return sin(Float(phase) * 2 * .pi) * amplitude

        case .saw:
            return generatePolyBLEPSaw(phase: phase, frequency: detunedFreq) * amplitude

        case .pulse:
            return generatePolyBLEPPulse(phase: phase, frequency: detunedFreq, width: pulseWidth) * amplitude

        case .triangle:
            return generateTriangle(phase: phase) * amplitude

        case .noise:
            return generateWhiteNoise() * amplitude

        case .wavetable:
            return generateWavetable(phase: phase) * amplitude

        case .superSaw:
            return generateSuperSaw(phase: phase, frequency: detunedFreq) * amplitude

        case .pwm:
            let pwmWidth = 0.5 + 0.4 * sin(Float(phase) * 0.1)
            return generatePolyBLEPPulse(phase: phase, frequency: detunedFreq, width: pwmWidth) * amplitude

        case .sync:
            return generateHardSync(phase: phase, frequency: detunedFreq, ratio: 2.5) * amplitude

        case .formant:
            return generateFormant(phase: phase, frequency: detunedFreq) * amplitude
        }
    }

    // MARK: - PolyBLEP Anti-Aliasing

    private func polyBLEP(t: Float, dt: Float) -> Float {
        if t < dt {
            let t_norm = t / dt
            return t_norm + t_norm - t_norm * t_norm - 1
        } else if t > 1 - dt {
            let t_norm = (t - 1) / dt
            return t_norm * t_norm + t_norm + t_norm + 1
        }
        return 0
    }

    private func generatePolyBLEPSaw(phase: Double, frequency: Float) -> Float {
        let t = Float(phase.truncatingRemainder(dividingBy: 1.0))
        let dt = frequency / Float(sampleRate)

        var saw = 2 * t - 1
        saw -= polyBLEP(t: t, dt: dt)

        return saw
    }

    private func generatePolyBLEPPulse(phase: Double, frequency: Float, width: Float) -> Float {
        let t = Float(phase.truncatingRemainder(dividingBy: 1.0))
        let dt = frequency / Float(sampleRate)

        var pulse: Float = t < width ? 1 : -1

        // Apply PolyBLEP at transitions
        pulse += polyBLEP(t: t, dt: dt)
        pulse -= polyBLEP(t: (t + 1 - width).truncatingRemainder(dividingBy: 1), dt: dt)

        return pulse
    }

    private func generateTriangle(phase: Double) -> Float {
        let t = Float(phase.truncatingRemainder(dividingBy: 1.0))
        if t < 0.25 {
            return 4 * t
        } else if t < 0.75 {
            return 2 - 4 * t
        } else {
            return 4 * t - 4
        }
    }

    private func generateWhiteNoise() -> Float {
        // Xorshift32
        noiseState ^= noiseState << 13
        noiseState ^= noiseState >> 17
        noiseState ^= noiseState << 5
        return Float(noiseState) / Float(UInt32.max) * 2 - 1
    }

    private func generateWavetable(phase: Double) -> Float {
        let tableSize = 2048
        let position = wavetablePosition * 3  // 0-3 for 4 waves

        let wave1 = Int(position)
        let wave2 = min(wave1 + 1, 3)
        let morphAmount = position - Float(wave1)

        let index = Int(phase * Double(tableSize)) % tableSize

        let sample1 = wavetable[wave1 * tableSize + index]
        let sample2 = wavetable[wave2 * tableSize + index]

        return sample1 * (1 - morphAmount) + sample2 * morphAmount
    }

    private func generateSuperSaw(phase: Double, frequency: Float) -> Float {
        var output: Float = 0
        let detuneRange = superSawDetune * 50  // cents

        for i in 0..<superSawVoices {
            let voiceDetune = -detuneRange + 2 * detuneRange * Float(i) / Float(superSawVoices - 1)
            let voiceRatio = pow(2.0, Double(voiceDetune) / 1200.0)
            let voicePhase = phase * voiceRatio

            output += generatePolyBLEPSaw(phase: voicePhase, frequency: frequency * Float(voiceRatio))
        }

        return output / Float(superSawVoices)
    }

    private func generateHardSync(phase: Double, frequency: Float, ratio: Float) -> Float {
        let masterPhase = phase.truncatingRemainder(dividingBy: 1.0)
        let slavePhase = (phase * Double(ratio)).truncatingRemainder(dividingBy: 1.0)

        return generatePolyBLEPSaw(phase: slavePhase, frequency: frequency * ratio)
    }

    private func generateFormant(phase: Double, frequency: Float) -> Float {
        // Formant frequencies for vowels (Hz)
        let formants: [[Float]] = [
            [800, 1150, 2900, 3900, 4950],   // A
            [350, 2000, 2800, 3600, 4950],   // E
            [270, 2140, 2950, 3900, 4950],   // I
            [450, 800, 2830, 3800, 4950],    // O
            [325, 700, 2700, 3800, 4950]     // U
        ]

        let vowel = min(max(formantVowel, 0), 4)
        let f = formants[vowel]

        var output: Float = 0
        let t = Float(phase)

        for i in 0..<5 {
            let formantPhase = t * f[i] / frequency
            let bandwidth: Float = 100 + Float(i) * 50
            let q = f[i] / bandwidth
            let amplitude = 1.0 / Float(i + 1)

            output += sin(formantPhase * 2 * .pi) * amplitude * exp(-Float(i) * 0.3)
        }

        return output / 3
    }
}


// MARK: - Vector Voice

/// Individual voice for polyphonic vector synthesis
public class VectorVoice {

    public let id: Int
    public private(set) var isActive: Bool = false
    public private(set) var currentNote: Int = 0
    public private(set) var currentFrequency: Float = 440
    public private(set) var velocity: Float = 1.0
    public private(set) var startTime: Double = 0

    // Phases for each oscillator
    public var phaseA: Double = 0
    public var phaseB: Double = 0
    public var phaseC: Double = 0
    public var phaseD: Double = 0

    // ADSR Envelope
    private var envelope: ADSREnvelope
    private var sampleRate: Double

    public init(id: Int, sampleRate: Double) {
        self.id = id
        self.sampleRate = sampleRate
        self.envelope = ADSREnvelope(sampleRate: sampleRate)

        // Default envelope
        envelope.attack = 0.01
        envelope.decay = 0.3
        envelope.sustain = 0.7
        envelope.release = 0.5
    }

    public func noteOn(note: Int, velocity: Float) {
        currentNote = note
        currentFrequency = midiToFrequency(note)
        self.velocity = velocity
        isActive = true
        startTime = Date().timeIntervalSince1970

        // Reset phases with slight randomization for analog feel
        phaseA = Double.random(in: 0..<0.1)
        phaseB = Double.random(in: 0..<0.1)
        phaseC = Double.random(in: 0..<0.1)
        phaseD = Double.random(in: 0..<0.1)

        envelope.gate(on: true)
    }

    public func noteOff() {
        envelope.gate(on: false)
    }

    public func processEnvelope() -> Float {
        let env = envelope.process()
        if envelope.stage == .idle {
            isActive = false
        }
        return env
    }

    public func updatePhases(sampleRate: Double) {
        let phaseIncrement = Double(currentFrequency) / sampleRate
        phaseA += phaseIncrement
        phaseB += phaseIncrement
        phaseC += phaseIncrement
        phaseD += phaseIncrement

        // Wrap phases
        if phaseA >= 1.0 { phaseA -= 1.0 }
        if phaseB >= 1.0 { phaseB -= 1.0 }
        if phaseC >= 1.0 { phaseC -= 1.0 }
        if phaseD >= 1.0 { phaseD -= 1.0 }
    }

    private func midiToFrequency(_ note: Int) -> Float {
        return 440.0 * pow(2.0, Float(note - 69) / 12.0)
    }
}


// MARK: - Vector Envelope

/// 2D envelope for automated vector movement
public class VectorEnvelope {

    public struct Point: Codable {
        public var position: SIMD2<Float>
        public var time: Float  // seconds

        public init(position: SIMD2<Float>, time: Float) {
            self.position = position
            self.time = time
        }
    }

    public var points: [Point] = []
    public var loop: Bool = true
    public var loopStart: Int = 0
    public var loopEnd: Int = 0

    private var currentTime: Float = 0
    private var currentSegment: Int = 0

    public init() {
        // Default: simple circular movement
        points = [
            Point(position: SIMD2(-0.5, 0.5), time: 0),
            Point(position: SIMD2(0.5, 0.5), time: 1),
            Point(position: SIMD2(0.5, -0.5), time: 2),
            Point(position: SIMD2(-0.5, -0.5), time: 3),
            Point(position: SIMD2(-0.5, 0.5), time: 4)
        ]
        loopEnd = points.count - 1
    }

    public func process() -> SIMD2<Float> {
        guard points.count >= 2 else { return .zero }

        // Find current segment
        var startPoint = points[0]
        var endPoint = points[1]

        for i in 0..<(points.count - 1) {
            if currentTime >= points[i].time && currentTime < points[i + 1].time {
                startPoint = points[i]
                endPoint = points[i + 1]
                break
            }
        }

        // Interpolate position
        let segmentDuration = endPoint.time - startPoint.time
        let segmentProgress = segmentDuration > 0 ?
            (currentTime - startPoint.time) / segmentDuration : 0

        let position = simd_mix(startPoint.position, endPoint.position, SIMD2(repeating: segmentProgress))

        // Advance time
        currentTime += 1.0 / 48000.0  // Assuming 48kHz

        // Handle looping
        if currentTime >= points[loopEnd].time {
            if loop {
                currentTime = points[loopStart].time
            } else {
                currentTime = points[loopEnd].time
            }
        }

        return position
    }

    public func reset() {
        currentTime = 0
        currentSegment = 0
    }
}


// MARK: - Wave Sequence (Wavestation-style)

/// Wave sequencing for complex timbral evolution
public class WaveSequence {

    public struct Step: Codable {
        public var waveformA: VectorSource.Waveform
        public var waveformB: VectorSource.Waveform
        public var waveformC: VectorSource.Waveform
        public var waveformD: VectorSource.Waveform
        public var duration: Float  // beats
        public var crossfade: Float  // 0-1

        public init(waveformA: VectorSource.Waveform = .saw,
                   waveformB: VectorSource.Waveform = .pulse,
                   waveformC: VectorSource.Waveform = .triangle,
                   waveformD: VectorSource.Waveform = .sine,
                   duration: Float = 1.0,
                   crossfade: Float = 0.5) {
            self.waveformA = waveformA
            self.waveformB = waveformB
            self.waveformC = waveformC
            self.waveformD = waveformD
            self.duration = duration
            self.crossfade = crossfade
        }
    }

    public var steps: [Step] = []
    public var tempo: Float = 120  // BPM
    public var loop: Bool = true

    private var currentStep: Int = 0
    private var stepTime: Float = 0

    public init() {
        // Default sequence
        steps = [
            Step(waveformA: .saw, duration: 2),
            Step(waveformA: .pulse, duration: 2),
            Step(waveformA: .superSaw, duration: 4),
            Step(waveformA: .wavetable, duration: 2)
        ]
    }

    public func process() -> (current: Step, next: Step, crossfade: Float)? {
        guard !steps.isEmpty else { return nil }

        let current = steps[currentStep]
        let next = steps[(currentStep + 1) % steps.count]

        let beatDuration = 60.0 / tempo
        let stepDuration = current.duration * Float(beatDuration)

        let crossfadeAmount = min(stepTime / stepDuration, 1.0)

        // Advance time
        stepTime += 1.0 / 48000.0

        if stepTime >= stepDuration {
            stepTime = 0
            currentStep = (currentStep + 1) % steps.count
        }

        return (current, next, crossfadeAmount * current.crossfade)
    }
}


// MARK: - Supporting Components

public class LFOGenerator {
    public enum Waveform: String, CaseIterable, Codable {
        case sine, triangle, saw, square, random
    }

    public var rate: Float = 1.0
    public var waveform: Waveform = .sine
    private var phase: Float = 0
    private var sampleRate: Double
    private var randomValue: Float = 0
    private var lastRandomUpdate: Float = 0

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    public func process() -> Float {
        let phaseIncrement = rate / Float(sampleRate)
        phase += phaseIncrement
        if phase >= 1 { phase -= 1 }

        switch waveform {
        case .sine:
            return sin(phase * 2 * .pi)
        case .triangle:
            return phase < 0.5 ? 4 * phase - 1 : 3 - 4 * phase
        case .saw:
            return 2 * phase - 1
        case .square:
            return phase < 0.5 ? 1 : -1
        case .random:
            if phase < lastRandomUpdate {
                randomValue = Float.random(in: -1...1)
            }
            lastRandomUpdate = phase
            return randomValue
        }
    }
}

public struct ModulationMatrix {
    public var lfoToVectorX: Float = 0
    public var lfoToVectorY: Float = 0
    public var velocityToFilter: Float = 0.5
    public var keyTrackToFilter: Float = 0.3
    public var envToVector: Float = 0.5
}

public class ADSREnvelope {
    public enum Stage { case idle, attack, decay, sustain, release }

    public var attack: Float = 0.01
    public var decay: Float = 0.1
    public var sustain: Float = 0.7
    public var release: Float = 0.3

    public private(set) var stage: Stage = .idle
    private var level: Float = 0
    private var sampleRate: Double

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    public func gate(on: Bool) {
        if on {
            stage = .attack
        } else if stage != .idle {
            stage = .release
        }
    }

    public func process() -> Float {
        switch stage {
        case .idle:
            return 0

        case .attack:
            level += 1.0 / (attack * Float(sampleRate))
            if level >= 1 {
                level = 1
                stage = .decay
            }

        case .decay:
            level -= (1 - sustain) / (decay * Float(sampleRate))
            if level <= sustain {
                level = sustain
                stage = .sustain
            }

        case .sustain:
            level = sustain

        case .release:
            level -= sustain / (release * Float(sampleRate))
            if level <= 0 {
                level = 0
                stage = .idle
            }
        }

        return level
    }
}

public class ChorusEffect {
    public var rate: Float = 0.5
    public var depth: Float = 0.3
    public var mix: Float = 0.3

    private var delayBuffer: [Float]
    private var writeIndex: Int = 0
    private var lfoPhase: Float = 0
    private var sampleRate: Double

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
        let bufferSize = Int(sampleRate * 0.05)  // 50ms max delay
        delayBuffer = [Float](repeating: 0, count: bufferSize)
    }

    public func process(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        for i in 0..<frameCount {
            let input = buffer[i]

            // LFO modulates delay time
            lfoPhase += rate / Float(sampleRate)
            if lfoPhase >= 1 { lfoPhase -= 1 }
            let lfo = sin(lfoPhase * 2 * .pi)

            // Calculate delay in samples (5-25ms)
            let delayMs = 15 + lfo * 10 * depth
            let delaySamples = Int(delayMs * Float(sampleRate) / 1000)

            // Read from delay buffer
            var readIndex = writeIndex - delaySamples
            if readIndex < 0 { readIndex += delayBuffer.count }
            let delayed = delayBuffer[readIndex % delayBuffer.count]

            // Write to delay buffer
            delayBuffer[writeIndex] = input
            writeIndex = (writeIndex + 1) % delayBuffer.count

            // Mix
            buffer[i] = input * (1 - mix) + delayed * mix
        }
    }
}

public class ReverbEffect {
    public var roomSize: Float = 0.5
    public var damping: Float = 0.5
    public var mix: Float = 0.3

    private var combFilters: [CombFilter]
    private var allPassFilters: [AllPassFilter]

    public init(sampleRate: Double) {
        // Freeverb-style configuration
        let combDelays = [1557, 1617, 1491, 1422, 1277, 1356, 1188, 1116]
        let allPassDelays = [225, 556, 441, 341]

        combFilters = combDelays.map { CombFilter(delayLength: $0) }
        allPassFilters = allPassDelays.map { AllPassFilter(delayLength: $0) }
    }

    public func process(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        for i in 0..<frameCount {
            let input = buffer[i]

            // Parallel comb filters
            var combSum: Float = 0
            for j in 0..<combFilters.count {
                combSum += combFilters[j].process(input: input, feedback: roomSize, damping: damping)
            }
            combSum /= Float(combFilters.count)

            // Series all-pass filters
            var output = combSum
            for j in 0..<allPassFilters.count {
                output = allPassFilters[j].process(input: output)
            }

            // Mix
            buffer[i] = input * (1 - mix) + output * mix
        }
    }

    private class CombFilter {
        private var buffer: [Float]
        private var index: Int = 0
        private var filterStore: Float = 0

        init(delayLength: Int) {
            buffer = [Float](repeating: 0, count: delayLength)
        }

        func process(input: Float, feedback: Float, damping: Float) -> Float {
            let output = buffer[index]
            filterStore = output * (1 - damping) + filterStore * damping
            buffer[index] = input + filterStore * feedback
            index = (index + 1) % buffer.count
            return output
        }
    }

    private class AllPassFilter {
        private var buffer: [Float]
        private var index: Int = 0

        init(delayLength: Int) {
            buffer = [Float](repeating: 0, count: delayLength)
        }

        func process(input: Float) -> Float {
            let buffered = buffer[index]
            let output = -input + buffered
            buffer[index] = input + buffered * 0.5
            index = (index + 1) % buffer.count
            return output
        }
    }
}


// MARK: - Preset

public struct VectorPreset: Codable {
    public var name: String
    public var sourceA: VectorSource
    public var sourceB: VectorSource
    public var sourceC: VectorSource
    public var sourceD: VectorSource
    public var vectorEnvelope: VectorEnvelope
    public var lfoRate: Float
    public var lfoWaveform: LFOGenerator.Waveform
    public var chorusMix: Float
    public var reverbMix: Float
}

// Codable conformance for VectorSource
extension VectorSource: Codable {
    enum CodingKeys: String, CodingKey {
        case waveform, amplitude, detune, pulseWidth, wavetablePosition
        case superSawVoices, superSawDetune, formantVowel
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(waveform, forKey: .waveform)
        try container.encode(amplitude, forKey: .amplitude)
        try container.encode(detune, forKey: .detune)
        try container.encode(pulseWidth, forKey: .pulseWidth)
        try container.encode(wavetablePosition, forKey: .wavetablePosition)
        try container.encode(superSawVoices, forKey: .superSawVoices)
        try container.encode(superSawDetune, forKey: .superSawDetune)
        try container.encode(formantVowel, forKey: .formantVowel)
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let waveform = try container.decode(Waveform.self, forKey: .waveform)
        let detune = try container.decode(Float.self, forKey: .detune)

        self.init(waveform: waveform, detune: detune, sampleRate: 48000)

        self.amplitude = try container.decode(Float.self, forKey: .amplitude)
        self.pulseWidth = try container.decode(Float.self, forKey: .pulseWidth)
        self.wavetablePosition = try container.decode(Float.self, forKey: .wavetablePosition)
        self.superSawVoices = try container.decode(Int.self, forKey: .superSawVoices)
        self.superSawDetune = try container.decode(Float.self, forKey: .superSawDetune)
        self.formantVowel = try container.decode(Int.self, forKey: .formantVowel)
    }
}

extension VectorEnvelope: Codable {}

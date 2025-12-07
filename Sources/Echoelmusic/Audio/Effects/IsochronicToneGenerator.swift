import Foundation
import AVFoundation
import Combine

// MARK: - Isochronic Tone Generator
/// Generiert isochrone Töne als Alternative zu Binaural Beats
///
/// **Unterschied zu Binaural Beats:**
/// - Binaural: Zwei leicht unterschiedliche Frequenzen in jedem Ohr → Gehirn erzeugt Beat
/// - Isochron: Ein Ton der rhythmisch an/aus pulsiert → direktere Entrainment-Wirkung
///
/// **Vorteile isochroner Töne:**
/// - ✅ Funktionieren auch ohne Kopfhörer (Lautsprecher möglich)
/// - ✅ Stärkere kortikale Reaktion (Studien: Chatrian 1959, Frederick 2012)
/// - ✅ Einfacher zu produzieren
/// - ✅ Weniger Schwebungsartefakte
///
/// **Wissenschaftliche Basis:**
/// - ✅ Auditory Driving Response (Chatrian et al. 1959)
/// - ✅ Photic/Auditory Entrainment (Siever 2007)
/// - ⚠️ Therapeutische Anwendung (emerging research)

@MainActor
public class IsochronicToneGenerator: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isPlaying: Bool = false

    @Published public private(set) var currentFrequency: Double = 10.0  // Hz (Pulsrate)

    @Published public private(set) var carrierFrequency: Double = 200.0  // Hz (Trägerfrequenz)

    @Published public private(set) var amplitude: Float = 0.5

    @Published public private(set) var waveformType: IsochronicWaveform = .sine

    @Published public private(set) var pulseShape: PulseShape = .smooth

    // MARK: - Audio Engine

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var mixerNode: AVAudioMixerNode?

    // MARK: - Generation State

    private var phase: Double = 0.0
    private var pulsePhase: Double = 0.0
    private let sampleRate: Double = 48000.0

    // MARK: - EFx Modeling

    private var efxChain: [EntrainmentEffect] = []

    // MARK: - ULTRA OPTIMIZATION: Inline Effect Chain (no protocol overhead)
    private var inlineEffectsEnabled: Bool = false
    private var compressorEnvelope: Float = 0
    private var compressorThreshold: Float = 0.7
    private var compressorRatio: Float = 3.0
    private var harmonizerAmount: Float = 0.2
    private var widenerBuffer: [Float] = [Float](repeating: 0, count: 100)
    private var widenerIndex: Int = 0
    private var widenerWidth: Float = 0.3

    // MARK: - ULTRA OPTIMIZATION: Pre-computed lookup tables
    private static let sineLUT: [Float] = {
        var table = [Float](repeating: 0, count: 4096)
        for i in 0..<4096 {
            table[i] = sin(Float(i) / 4096.0 * 2.0 * .pi)
        }
        return table
    }()

    private static let gaussianLUT: [Float] = {
        var table = [Float](repeating: 0, count: 1024)
        let center: Float = 0.25
        let sigma: Float = 0.15
        for i in 0..<1024 {
            let phase = Float(i) / 1024.0
            let x = phase - center
            table[i] = exp(-x * x / (2.0 * sigma * sigma))
        }
        return table
    }()

    // MARK: - Presets

    public static let presets: [IsochronicPreset] = [
        // Delta (0.5-4 Hz) - Tiefschlaf
        IsochronicPreset(name: "Deep Sleep", pulseFrequency: 2.0, carrier: 100.0, waveform: .sine, evidence: .peerReviewed),
        IsochronicPreset(name: "Healing Delta", pulseFrequency: 3.5, carrier: 150.0, waveform: .sine, evidence: .preliminary),

        // Theta (4-8 Hz) - Meditation, Kreativität
        IsochronicPreset(name: "Deep Meditation", pulseFrequency: 6.0, carrier: 200.0, waveform: .sine, evidence: .peerReviewed),
        IsochronicPreset(name: "Creative Flow", pulseFrequency: 7.0, carrier: 250.0, waveform: .triangle, evidence: .preliminary),

        // Alpha (8-13 Hz) - Entspannung, leichte Meditation
        IsochronicPreset(name: "Relaxed Focus", pulseFrequency: 10.0, carrier: 300.0, waveform: .sine, evidence: .peerReviewed),
        IsochronicPreset(name: "Calm Alert", pulseFrequency: 11.0, carrier: 350.0, waveform: .sine, evidence: .peerReviewed),

        // Beta (13-30 Hz) - Konzentration, Wachheit
        IsochronicPreset(name: "Focused Work", pulseFrequency: 15.0, carrier: 400.0, waveform: .sine, evidence: .peerReviewed),
        IsochronicPreset(name: "Peak Performance", pulseFrequency: 18.0, carrier: 440.0, waveform: .sine, evidence: .preliminary),
        IsochronicPreset(name: "High Energy", pulseFrequency: 25.0, carrier: 500.0, waveform: .square, evidence: .preliminary),

        // Gamma (30-100 Hz) - Kognition, Lernen
        IsochronicPreset(name: "Enhanced Learning", pulseFrequency: 40.0, carrier: 528.0, waveform: .sine, evidence: .preliminary),
    ]

    // MARK: - Initialization

    public init() {
        setupAudioEngine()
    }

    deinit {
        stop()
    }

    // MARK: - Audio Setup

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        mixerNode = AVAudioMixerNode()

        guard let engine = audioEngine, let mixer = mixerNode else { return }

        engine.attach(mixer)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        // Source Node für Echtzeit-Generierung
        sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                let sample = self.generateSample()

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = sample
                }
            }

            return noErr
        }

        if let source = sourceNode {
            engine.attach(source)
            engine.connect(source, to: mixer, format: format)
            engine.connect(mixer, to: engine.mainMixerNode, format: format)
        }
    }

    // MARK: - Sample Generation (ULTRA OPTIMIZED)

    @inline(__always)
    private func generateSample() -> Float {
        // 1. Carrier-Waveform generieren (LUT-optimiert)
        let carrierSample = generateCarrierWaveformOptimized()

        // 2. Puls-Envelope generieren (LUT-optimiert)
        let pulseEnvelope = generatePulseEnvelopeOptimized()

        // 3. Modulieren
        var sample = carrierSample * pulseEnvelope * amplitude

        // 4. EFx Chain anwenden - ULTRA OPTIMIZED: Inline statt Protocol
        if inlineEffectsEnabled {
            sample = processInlineEffects(sample)
        } else if !efxChain.isEmpty {
            for effect in efxChain {
                sample = effect.process(sample)
            }
        }

        // 5. Phasen aktualisieren
        let carrierIncrement = carrierFrequency / sampleRate
        phase += carrierIncrement
        if phase >= 1.0 { phase -= 1.0 }

        let pulseIncrement = currentFrequency / sampleRate
        pulsePhase += pulseIncrement
        if pulsePhase >= 1.0 { pulsePhase -= 1.0 }

        return sample
    }

    /// ULTRA OPTIMIZED: Inline effect processing (no protocol dispatch)
    @inline(__always)
    private func processInlineEffects(_ input: Float) -> Float {
        var sample = input

        // 1. Soft Compressor (inline)
        let abs = Swift.abs(sample)
        let coeff: Float = abs > compressorEnvelope ? 0.01 : 0.1
        compressorEnvelope += coeff * (abs - compressorEnvelope)

        if compressorEnvelope > compressorThreshold {
            let over = compressorEnvelope - compressorThreshold
            let gain = compressorThreshold + over / compressorRatio
            sample *= gain / max(compressorEnvelope, 0.0001)
        }

        // 2. Harmonic Enhancer (inline tanh approximation)
        let x = sample * 1.5
        let x2 = x * x
        let saturated = x * (27.0 + x2) / (27.0 + 9.0 * x2)  // Fast tanh
        sample = sample * (1.0 - harmonizerAmount) + saturated * 0.8 * harmonizerAmount

        // 3. Spatial Widener (inline)
        let delayed = widenerBuffer[widenerIndex]
        widenerBuffer[widenerIndex] = sample
        widenerIndex = (widenerIndex + 1) % 100
        sample = sample * (1.0 - widenerWidth * 0.5) + delayed * widenerWidth * 0.3

        return sample
    }

    /// ULTRA OPTIMIZED: LUT-based carrier waveform
    @inline(__always)
    private func generateCarrierWaveformOptimized() -> Float {
        switch waveformType {
        case .sine:
            // LUT lookup instead of sin()
            let index = Int(phase * 4096.0) & 4095
            return Self.sineLUT[index]

        case .triangle:
            let t = Float(phase)
            if t < 0.25 {
                return t * 4.0
            } else if t < 0.75 {
                return 2.0 - t * 4.0
            } else {
                return t * 4.0 - 4.0
            }

        case .square:
            return phase < 0.5 ? 1.0 : -1.0

        case .sawtooth:
            return Float(2.0 * phase - 1.0)

        case .harmonic:
            // Optimized: nur 3 Harmonische statt 5
            let p = Float(phase)
            let idx1 = Int(phase * 4096.0) & 4095
            let idx2 = Int(phase * 2.0 * 4096.0) & 4095
            let idx3 = Int(phase * 3.0 * 4096.0) & 4095
            return (Self.sineLUT[idx1] + Self.sineLUT[idx2] * 0.5 + Self.sineLUT[idx3] * 0.333) * 0.545
        }
    }

    /// ULTRA OPTIMIZED: LUT-based pulse envelope
    @inline(__always)
    private func generatePulseEnvelopeOptimized() -> Float {
        switch pulseShape {
        case .sharp:
            return pulsePhase < 0.5 ? 1.0 : 0.0

        case .smooth:
            let index = Int(pulsePhase * 4096.0) & 4095
            return (Self.sineLUT[index] + 1.0) * 0.5

        case .exponential:
            if pulsePhase < 0.1 {
                return Float(pulsePhase / 0.1)
            } else {
                return Float(exp(-5.0 * (pulsePhase - 0.1)))
            }

        case .gaussian:
            let index = Int(pulsePhase * 1024.0) & 1023
            return Self.gaussianLUT[index]

        case .ramp:
            return Float(1.0 - pulsePhase)
        }
    }

    private func generateCarrierWaveform() -> Float {
        switch waveformType {
        case .sine:
            return Float(sin(phase * 2.0 * .pi))

        case .triangle:
            let t = phase
            if t < 0.25 {
                return Float(t * 4.0)
            } else if t < 0.75 {
                return Float(2.0 - t * 4.0)
            } else {
                return Float(t * 4.0 - 4.0)
            }

        case .square:
            return phase < 0.5 ? 1.0 : -1.0

        case .sawtooth:
            return Float(2.0 * phase - 1.0)

        case .harmonic:
            // Grundton + Obertöne für reicheren Klang
            var sum: Float = 0
            for harmonic in 1...5 {
                let harmonicPhase = phase * Double(harmonic)
                let harmonicAmplitude = 1.0 / Float(harmonic)
                sum += Float(sin(harmonicPhase * 2.0 * .pi)) * harmonicAmplitude
            }
            return sum / 2.28  // Normalisierung
        }
    }

    private func generatePulseEnvelope() -> Float {
        switch pulseShape {
        case .sharp:
            // Harter An/Aus-Übergang
            return pulsePhase < 0.5 ? 1.0 : 0.0

        case .smooth:
            // Sinusförmige Modulation (sanfter)
            return Float((sin(pulsePhase * 2.0 * .pi) + 1.0) / 2.0)

        case .exponential:
            // Schneller Attack, langsamer Decay
            if pulsePhase < 0.1 {
                return Float(pulsePhase / 0.1)
            } else {
                return Float(exp(-5.0 * (pulsePhase - 0.1)))
            }

        case .gaussian:
            // Glockenförmig
            let center = 0.25
            let sigma = 0.15
            let x = pulsePhase - center
            return Float(exp(-x * x / (2.0 * sigma * sigma)))

        case .ramp:
            // Linearer Anstieg, sofortiger Abfall
            return Float(1.0 - pulsePhase)
        }
    }

    // MARK: - Control

    /// Starte Isochronic Tone
    public func start() {
        guard !isPlaying else { return }

        do {
            try audioEngine?.start()
            isPlaying = true
            print("[Isochronic] ▶️ Started: \(currentFrequency) Hz pulse, \(carrierFrequency) Hz carrier")
        } catch {
            print("[Isochronic] ❌ Failed to start: \(error)")
        }
    }

    /// Stoppe Isochronic Tone
    public func stop() {
        guard isPlaying else { return }

        audioEngine?.stop()
        isPlaying = false
        print("[Isochronic] ⏹ Stopped")
    }

    /// Setze Pulsfrequenz (Entrainment-Frequenz)
    public func setPulseFrequency(_ frequency: Double) {
        // Sicherheitsgrenzen
        currentFrequency = max(0.5, min(100.0, frequency))
    }

    /// Setze Trägerfrequenz
    public func setCarrierFrequency(_ frequency: Double) {
        // Hörbereich
        carrierFrequency = max(20.0, min(2000.0, frequency))
    }

    /// Setze Amplitude
    public func setAmplitude(_ amp: Float) {
        amplitude = max(0.0, min(1.0, amp))
        mixerNode?.outputVolume = amplitude
    }

    /// Setze Waveform
    public func setWaveform(_ waveform: IsochronicWaveform) {
        self.waveformType = waveform
    }

    /// Setze Puls-Shape
    public func setPulseShape(_ shape: PulseShape) {
        self.pulseShape = shape
    }

    /// Lade Preset
    public func loadPreset(_ preset: IsochronicPreset) {
        currentFrequency = preset.pulseFrequency
        carrierFrequency = preset.carrierFrequency
        waveformType = preset.waveform

        print("[Isochronic] Loaded preset: \(preset.name)")
    }

    // MARK: - EFx Chain

    /// Füge Entrainment-Effekt hinzu
    public func addEffect(_ effect: EntrainmentEffect) {
        efxChain.append(effect)
    }

    /// Entferne alle Effekte
    public func clearEffects() {
        efxChain.removeAll()
    }

    /// Konfiguriere Standard-EFx-Chain für Entrainment
    /// ULTRA OPTIMIZED: Uses inline processing by default
    public func setupEntrainmentEFxChain() {
        // ULTRA OPTIMIZATION: Use inline effects (no protocol overhead)
        inlineEffectsEnabled = true
        compressorThreshold = 0.7
        compressorRatio = 3.0
        harmonizerAmount = 0.2
        widenerWidth = 0.3

        // Clear protocol-based chain (not used when inline enabled)
        clearEffects()

        print("[Isochronic] ⚡ ULTRA EFx chain configured (inline mode)")
    }

    /// Configure effects with custom parameters
    public func configureInlineEffects(
        compressorThreshold: Float = 0.7,
        compressorRatio: Float = 3.0,
        harmonizerAmount: Float = 0.2,
        widenerWidth: Float = 0.3
    ) {
        inlineEffectsEnabled = true
        self.compressorThreshold = compressorThreshold
        self.compressorRatio = compressorRatio
        self.harmonizerAmount = harmonizerAmount
        self.widenerWidth = widenerWidth
    }

    /// Disable inline effects (use protocol-based chain)
    public func disableInlineEffects() {
        inlineEffectsEnabled = false
    }
}

// MARK: - Types

public enum IsochronicWaveform: String, CaseIterable, Codable {
    case sine       // Reinster Ton
    case triangle   // Weicher, aber mit Obertönen
    case square     // Scharf, viele Obertöne
    case sawtooth   // Alle Obertöne
    case harmonic   // Grundton + natürliche Obertöne

    public var displayName: String {
        switch self {
        case .sine: return "Sinus (Rein)"
        case .triangle: return "Dreieck (Weich)"
        case .square: return "Rechteck (Scharf)"
        case .sawtooth: return "Sägezahn (Reich)"
        case .harmonic: return "Harmonisch (Natürlich)"
        }
    }
}

public enum PulseShape: String, CaseIterable, Codable {
    case sharp       // Hartes An/Aus
    case smooth      // Sinusförmig
    case exponential // Schneller Attack, Decay
    case gaussian    // Glockenförmig
    case ramp        // Rampe

    public var displayName: String {
        switch self {
        case .sharp: return "Scharf (Stark)"
        case .smooth: return "Weich (Sanft)"
        case .exponential: return "Exponentiell"
        case .gaussian: return "Glocke"
        case .ramp: return "Rampe"
        }
    }
}

public struct IsochronicPreset: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let pulseFrequency: Double
    public let carrierFrequency: Double
    public let waveform: IsochronicWaveform
    public let evidence: EvidenceLevel

    public init(
        name: String,
        pulseFrequency: Double,
        carrier: Double,
        waveform: IsochronicWaveform,
        evidence: EvidenceLevel
    ) {
        self.id = UUID()
        self.name = name
        self.pulseFrequency = pulseFrequency
        self.carrierFrequency = carrier
        self.waveform = waveform
        self.evidence = evidence
    }

    public var brainwaveBand: String {
        switch pulseFrequency {
        case 0.5..<4: return "Delta (Schlaf)"
        case 4..<8: return "Theta (Meditation)"
        case 8..<13: return "Alpha (Entspannung)"
        case 13..<30: return "Beta (Fokus)"
        case 30..<100: return "Gamma (Kognition)"
        default: return "Unbekannt"
        }
    }
}

// MARK: - Entrainment Effects (EFx Modeling)

public protocol EntrainmentEffect {
    var name: String { get }
    func process(_ sample: Float) -> Float
}

/// Sanfter Kompressor für konsistenten Pegel
public class SoftCompressorEffect: EntrainmentEffect {
    public let name = "Soft Compressor"
    private let threshold: Float
    private let ratio: Float
    private var envelope: Float = 0

    public init(threshold: Float, ratio: Float) {
        self.threshold = threshold
        self.ratio = ratio
    }

    public func process(_ sample: Float) -> Float {
        let abs = Swift.abs(sample)

        // Envelope folgen
        let attackTime: Float = 0.01
        let releaseTime: Float = 0.1
        let coeff = abs > envelope ? attackTime : releaseTime
        envelope += coeff * (abs - envelope)

        if envelope > threshold {
            let overThreshold = envelope - threshold
            let gain = threshold + overThreshold / ratio
            return sample * (gain / envelope)
        }

        return sample
    }
}

/// Fügt sanfte Obertöne hinzu
public class HarmonicEnhancerEffect: EntrainmentEffect {
    public let name = "Harmonic Enhancer"
    private let amount: Float

    public init(amount: Float) {
        self.amount = amount
    }

    public func process(_ sample: Float) -> Float {
        // Sanfte Sättigung für Obertöne
        let saturated = tanh(sample * 1.5) * 0.8
        return sample * (1.0 - amount) + saturated * amount
    }
}

/// Stereo-Weitung für Immersion
public class SpatialWidenerEffect: EntrainmentEffect {
    public let name = "Spatial Widener"
    private let width: Float
    private var delayBuffer: [Float] = Array(repeating: 0, count: 100)
    private var writeIndex: Int = 0

    public init(width: Float) {
        self.width = width
    }

    public func process(_ sample: Float) -> Float {
        // Haas-Effekt Simulation
        let delayed = delayBuffer[writeIndex]
        delayBuffer[writeIndex] = sample
        writeIndex = (writeIndex + 1) % delayBuffer.count

        return sample * (1.0 - width * 0.5) + delayed * width * 0.3
    }
}

/// Resonanz-Filter für bestimmte Frequenzen
public class ResonanceFilterEffect: EntrainmentEffect {
    public let name = "Resonance Filter"
    private let frequency: Float
    private let q: Float
    private var z1: Float = 0
    private var z2: Float = 0

    public init(frequency: Float, q: Float = 5.0) {
        self.frequency = frequency
        self.q = q
    }

    public func process(_ sample: Float) -> Float {
        // Biquad Bandpass
        let omega = 2.0 * Float.pi * frequency / 48000.0
        let alpha = sin(omega) / (2.0 * q)

        let b0 = alpha
        let b1: Float = 0
        let b2 = -alpha
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cos(omega)
        let a2 = 1.0 - alpha

        let output = (b0/a0) * sample + (b1/a0) * z1 + (b2/a0) * z2
            - (a1/a0) * z1 - (a2/a0) * z2

        z2 = z1
        z1 = sample

        // Mix mit Original
        return sample * 0.7 + output * 0.3
    }
}

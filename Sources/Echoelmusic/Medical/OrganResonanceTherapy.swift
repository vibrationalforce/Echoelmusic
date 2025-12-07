// OrganResonanceTherapy.swift
// Echoelmusic - Frequency-Based Wellness Exploration
//
// CRITICAL SCIENTIFIC DISCLAIMER:
// ════════════════════════════════════════════════════════════════════════════
// This module explores frequency-based approaches to wellness.
// The evidence base varies significantly:
//
// ✅ VALIDATED SCIENCE:
//    - Photobiomodulation (red/NIR light therapy) - FDA-cleared for some uses
//    - Binaural beats affecting brainwave states - peer-reviewed evidence
//    - Music therapy for mood/anxiety - Cochrane review supported
//
// ⚠️ PRELIMINARY/MIXED EVIDENCE:
//    - Specific frequency effects on physiology - limited studies
//    - Heart coherence training - proprietary (HeartMath), not universally accepted
//
// ❌ UNVALIDATED/TRADITIONAL:
//    - Solfeggio frequencies (528Hz "DNA repair", etc.) - NO scientific evidence
//    - Organ-specific healing frequencies - NOT supported by peer-reviewed research
//    - "Chakra" frequencies - spiritual tradition, not science
//
// This is NOT a medical device. Does NOT diagnose, treat, or cure any condition.
// Always consult qualified healthcare professionals.
// ════════════════════════════════════════════════════════════════════════════
//
// PEER-REVIEWED References (validated research only):
// - Hamblin, M.R. (2016): Photobiomodulation - mechanisms and applications
// - Chaieb, L. et al. (2015): Auditory beat stimulation - neural entrainment
// - Thaut, M.H. (2015): Rhythm, Music, and the Brain - Scientific Foundations
// - Goldberger, A.L. (2002): Fractal dynamics in physiology - variability as health
// - Malik, M. (1996): Heart rate variability - Standards of measurement
//
// NOTE: Earlier versions cited Rife (1934) - this has been REMOVED as his
// "frequency therapy" claims were never scientifically validated and his
// devices were ruled fraudulent by the FDA.

import Foundation
import simd
import Combine

// MARK: - Organ System Definition

/// Human organ systems with their resonant properties
public enum OrganSystem: String, CaseIterable, Codable {
    case cardiovascular = "Cardiovascular"
    case respiratory = "Respiratory"
    case digestive = "Digestive"
    case nervous = "Nervous"
    case endocrine = "Endocrine"
    case lymphatic = "Lymphatic"
    case urinary = "Urinary"
    case reproductive = "Reproductive"
    case musculoskeletal = "Musculoskeletal"
    case integumentary = "Integumentary"  // Skin

    public var primaryOrgans: [Organ] {
        switch self {
        case .cardiovascular:
            return [.heart, .bloodVessels]
        case .respiratory:
            return [.lungs, .bronchi, .diaphragm]
        case .digestive:
            return [.stomach, .liver, .gallbladder, .pancreas, .smallIntestine, .largeIntestine]
        case .nervous:
            return [.brain, .spinalCord, .nerves]
        case .endocrine:
            return [.thyroid, .adrenals, .pituitary, .pineal]
        case .lymphatic:
            return [.spleen, .thymus, .lymphNodes]
        case .urinary:
            return [.kidneys, .bladder]
        case .reproductive:
            return [.gonads]
        case .musculoskeletal:
            return [.bones, .muscles, .joints]
        case .integumentary:
            return [.skin]
        }
    }
}

public enum Organ: String, CaseIterable, Codable {
    // Cardiovascular
    case heart = "Heart"
    case bloodVessels = "Blood Vessels"

    // Respiratory
    case lungs = "Lungs"
    case bronchi = "Bronchi"
    case diaphragm = "Diaphragm"

    // Digestive
    case stomach = "Stomach"
    case liver = "Liver"
    case gallbladder = "Gallbladder"
    case pancreas = "Pancreas"
    case smallIntestine = "Small Intestine"
    case largeIntestine = "Large Intestine"

    // Nervous
    case brain = "Brain"
    case spinalCord = "Spinal Cord"
    case nerves = "Peripheral Nerves"

    // Endocrine
    case thyroid = "Thyroid"
    case adrenals = "Adrenal Glands"
    case pituitary = "Pituitary Gland"
    case pineal = "Pineal Gland"

    // Lymphatic
    case spleen = "Spleen"
    case thymus = "Thymus"
    case lymphNodes = "Lymph Nodes"

    // Urinary
    case kidneys = "Kidneys"
    case bladder = "Bladder"

    // Other
    case gonads = "Gonads"
    case bones = "Bones"
    case muscles = "Muscles"
    case joints = "Joints"
    case skin = "Skin"

    /// Physiological rhythm ranges - these are MEASURED biological rhythms,
    /// NOT therapeutic frequencies. Used for synchronization/biofeedback only.
    ///
    /// Evidence levels:
    /// ✅ = Peer-reviewed, measured physiological rhythm
    /// ⚠️ = Estimated/derived, needs individual calibration
    /// ❌ = Traditional/unvalidated - included for exploration only
    public var physiologicalRhythmRange: ClosedRange<Float> {
        switch self {
        // ✅ VALIDATED - Measurable physiological rhythms
        case .heart: return 0.8...2.0           // ✅ Heart rate 48-120 BPM
        case .lungs: return 0.15...0.4          // ✅ Respiration 9-24 breaths/min
        case .brain: return 0.5...100.0         // ✅ EEG: delta(0.5-4) to gamma(30-100)
        case .diaphragm: return 0.15...0.4      // ✅ Matches respiration

        // ⚠️ ESTIMATED - Based on physiology but individual variation high
        case .stomach: return 0.03...0.1        // ⚠️ Gastric slow waves ~3 cycles/min
        case .smallIntestine: return 0.15...0.2 // ⚠️ ~9-12 cycles/min
        case .largeIntestine: return 0.05...0.1 // ⚠️ ~3-6 cycles/min
        case .bloodVessels: return 0.01...0.1   // ⚠️ Vasomotion waves
        case .muscles: return 8.0...30.0        // ⚠️ EMG tremor frequencies

        // ❌ UNVALIDATED - Traditional/alternative sources, no peer-reviewed evidence
        // Included for experimental exploration only - NOT therapeutic claims
        case .bronchi: return 10.0...20.0       // ❌ Unvalidated
        case .liver: return 5.0...8.0           // ❌ Unvalidated
        case .gallbladder: return 6.0...10.0    // ❌ Unvalidated
        case .pancreas: return 5.0...7.0        // ❌ Unvalidated
        case .spinalCord: return 7.0...14.0     // ❌ Unvalidated
        case .nerves: return 20.0...1000.0      // ⚠️ Action potential range
        case .thyroid: return 60.0...70.0       // ❌ Unvalidated
        case .adrenals: return 50.0...55.0      // ❌ Unvalidated
        case .pituitary: return 600.0...650.0   // ❌ Unvalidated
        case .pineal: return 900.0...1000.0     // ❌ Unvalidated
        case .spleen: return 45.0...50.0        // ❌ Unvalidated
        case .thymus: return 55.0...60.0        // ❌ Unvalidated
        case .lymphNodes: return 15.0...25.0    // ❌ Unvalidated
        case .kidneys: return 300.0...350.0     // ❌ Unvalidated
        case .bladder: return 350.0...400.0     // ❌ Unvalidated
        case .gonads: return 280.0...300.0      // ❌ Unvalidated
        case .bones: return 20.0...50.0         // ⚠️ LIPUS uses 20-100Hz (some evidence)
        case .joints: return 8.0...15.0         // ❌ Unvalidated
        case .skin: return 250.0...300.0        // ❌ Unvalidated
        }
    }

    /// Solfeggio frequencies - TRADITIONAL/SPIRITUAL, NOT SCIENTIFICALLY VALIDATED
    ///
    /// ⚠️ WARNING: These frequencies have NO peer-reviewed evidence for health effects.
    /// Claims like "DNA repair" or "healing" are NOT supported by science.
    /// Included for historical/cultural interest and sonic exploration only.
    /// DO NOT use as medical treatment.
    public var solfeggioFrequency: Float? {
        switch self {
        case .heart: return 639.0      // Traditional: "Connection" - NO EVIDENCE
        case .liver: return 528.0      // Traditional: "Transformation" - NO EVIDENCE for "DNA repair"
        case .stomach: return 417.0    // Traditional - NO EVIDENCE
        case .thyroid: return 741.0    // Traditional - NO EVIDENCE
        case .pineal: return 963.0     // Traditional - NO EVIDENCE
        case .kidneys: return 396.0    // Traditional - NO EVIDENCE
        case .lungs: return 852.0      // Traditional - NO EVIDENCE
        default: return nil
        }
    }

    /// Light color wavelength in nanometers for photobiomodulation
    public var therapeuticWavelength: ClosedRange<Int> {
        switch self {
        case .heart: return 620...650      // Red - circulation
        case .bloodVessels: return 635...680  // Deep red
        case .lungs: return 520...560      // Green - respiratory
        case .liver: return 550...570      // Yellow-green - detox
        case .gallbladder: return 570...590 // Yellow
        case .stomach: return 590...610    // Orange - digestion
        case .kidneys: return 400...420    // Violet - purification
        case .brain: return 810...850      // Near-infrared - neural
        case .skin: return 630...670       // Red - healing
        case .muscles: return 800...850    // Near-infrared - recovery
        case .bones: return 630...670      // Red - osteogenesis
        case .joints: return 800...850     // Near-infrared
        default: return 630...700          // General red therapy
        }
    }
}

// MARK: - Organ Health Assessment

/// Non-diagnostic wellness assessment based on biomarkers
public struct OrganWellnessState: Codable {
    public var organ: Organ
    public var energyLevel: Float        // 0-1 subjective energy
    public var coherenceScore: Float     // Heart rate variability derived
    public var stressIndicator: Float    // 0-1 stress level
    public var inflammationRisk: Float   // Based on lifestyle factors
    public var lastAssessment: Date

    public var overallWellness: Float {
        let weights: [Float] = [0.3, 0.25, 0.25, 0.2]
        return weights[0] * energyLevel +
               weights[1] * coherenceScore +
               weights[2] * (1.0 - stressIndicator) +
               weights[3] * (1.0 - inflammationRisk)
    }

    public var needsAttention: Bool {
        return overallWellness < 0.5
    }
}

// MARK: - Frequency Protocol

/// A therapeutic frequency combination
public struct FrequencyProtocol: Identifiable, Codable {
    public var id: UUID
    public var name: String
    public var description: String
    public var targetOrgan: Organ?
    public var targetSystem: OrganSystem?

    // Audio frequencies
    public var baseFrequency: Float           // Primary frequency in Hz
    public var harmonics: [Float]             // Additional harmonic frequencies
    public var binauralBeatFrequency: Float?  // For brainwave entrainment
    public var isochronicPulse: Float?        // Rhythmic pulsing

    // Light parameters
    public var lightWavelength: Int           // Nanometers
    public var lightPulseFrequency: Float?    // Hz (pulsed light therapy)
    public var lightIntensity: Float          // 0-1 relative intensity

    // Timing
    public var sessionDuration: TimeInterval  // Recommended duration
    public var rampUpTime: TimeInterval       // Gradual onset
    public var rampDownTime: TimeInterval     // Gradual offset

    // Safety
    public var maxSessionsPerDay: Int
    public var contraindicatedConditions: [String]

    public init(name: String, targetOrgan: Organ, baseFrequency: Float) {
        self.id = UUID()
        self.name = name
        self.description = ""
        self.targetOrgan = targetOrgan
        self.targetSystem = nil
        self.baseFrequency = baseFrequency
        self.harmonics = []
        self.binauralBeatFrequency = nil
        self.isochronicPulse = nil
        self.lightWavelength = targetOrgan.therapeuticWavelength.lowerBound
        self.lightPulseFrequency = nil
        self.lightIntensity = 0.5
        self.sessionDuration = 600  // 10 minutes default
        self.rampUpTime = 30
        self.rampDownTime = 30
        self.maxSessionsPerDay = 2
        self.contraindicatedConditions = []
    }
}

// MARK: - Pre-defined Protocols

public struct TherapeuticProtocols {

    // MARK: - Cardiovascular

    public static let heartCoherence = FrequencyProtocol(
        name: "Heart Coherence",
        targetOrgan: .heart,
        baseFrequency: 1.0  // ~60 BPM rhythm
    ).with {
        $0.description = "Promotes heart rate variability and cardiac coherence"
        $0.harmonics = [2.0, 4.0, 8.0]  // Harmonic series
        $0.binauralBeatFrequency = 10.0  // Alpha for relaxation
        $0.lightWavelength = 635  // Red for circulation
        $0.lightPulseFrequency = 1.0  // Synced with heart
    }

    public static let circulationSupport = FrequencyProtocol(
        name: "Circulation Support",
        targetOrgan: .bloodVessels,
        baseFrequency: 7.83  // Schumann resonance
    ).with {
        $0.description = "Supports healthy blood flow"
        $0.harmonics = [14.1, 20.8, 27.3]  // Schumann harmonics
        $0.lightWavelength = 660  // Deep red
        $0.lightIntensity = 0.7
    }

    // MARK: - Digestive

    public static let liverDetox = FrequencyProtocol(
        name: "Liver Harmony",
        targetOrgan: .liver,
        baseFrequency: 528.0  // "Miracle tone" / DNA repair
    ).with {
        $0.description = "Supports liver function and detoxification processes"
        $0.harmonics = [264.0, 1056.0]  // Octaves
        $0.lightWavelength = 560  // Yellow-green
        $0.sessionDuration = 900  // 15 minutes
        $0.contraindicatedConditions = ["pregnancy", "liver disease under treatment"]
    }

    public static let digestiveBalance = FrequencyProtocol(
        name: "Digestive Balance",
        targetOrgan: .stomach,
        baseFrequency: 417.0  // Solfeggio RE
    ).with {
        $0.description = "Promotes healthy digestion and gut motility"
        $0.isochronicPulse = 0.1  // Slow pulsing
        $0.lightWavelength = 590  // Orange
        $0.sessionDuration = 1200  // 20 minutes
    }

    // MARK: - Respiratory

    public static let lungVitality = FrequencyProtocol(
        name: "Lung Vitality",
        targetOrgan: .lungs,
        baseFrequency: 0.25  // 4-second breath cycle
    ).with {
        $0.description = "Encourages deep, rhythmic breathing"
        $0.harmonics = [0.5, 1.0, 2.0]
        $0.binauralBeatFrequency = 4.0  // Theta for deep relaxation
        $0.lightWavelength = 540  // Green
        $0.sessionDuration = 600
    }

    // MARK: - Nervous System

    public static let brainwaveBalance = FrequencyProtocol(
        name: "Brainwave Balance",
        targetOrgan: .brain,
        baseFrequency: 40.0  // Gamma for cognitive function
    ).with {
        $0.description = "Supports healthy brain function and mental clarity"
        $0.harmonics = [10.0, 20.0, 80.0]  // Alpha, Beta, High Gamma
        $0.binauralBeatFrequency = 40.0  // Gamma entrainment
        $0.lightWavelength = 810  // Near-infrared
        $0.sessionDuration = 1200
    }

    public static let nerveCalmness = FrequencyProtocol(
        name: "Nerve Calmness",
        targetOrgan: .nerves,
        baseFrequency: 7.83  // Schumann resonance
    ).with {
        $0.description = "Calms nervous system and reduces stress response"
        $0.binauralBeatFrequency = 6.0  // Theta border
        $0.lightWavelength = 810
        $0.lightPulseFrequency = 7.83
    }

    // MARK: - Endocrine

    public static let thyroidBalance = FrequencyProtocol(
        name: "Thyroid Balance",
        targetOrgan: .thyroid,
        baseFrequency: 741.0  // Solfeggio SOL
    ).with {
        $0.description = "Supports healthy thyroid function"
        $0.lightWavelength = 640
        $0.sessionDuration = 600
        $0.contraindicatedConditions = ["hyperthyroidism", "thyroid medication"]
    }

    public static let pinealActivation = FrequencyProtocol(
        name: "Pineal Activation",
        targetOrgan: .pineal,
        baseFrequency: 963.0  // Solfeggio TI
    ).with {
        $0.description = "Supports circadian rhythm and melatonin production"
        $0.binauralBeatFrequency = 3.5  // Deep delta for sleep
        $0.lightWavelength = 480  // Blue (evening mode: dim)
        $0.lightIntensity = 0.2  // Low for evening use
        $0.sessionDuration = 1800  // 30 minutes
    }

    // MARK: - Lymphatic/Immune

    public static let immuneSupport = FrequencyProtocol(
        name: "Immune Support",
        targetOrgan: .thymus,
        baseFrequency: 528.0
    ).with {
        $0.description = "Supports healthy immune function"
        $0.harmonics = [264.0, 396.0, 639.0]  // Supporting Solfeggio
        $0.lightWavelength = 660  // Red
        $0.sessionDuration = 900
    }

    // MARK: - Musculoskeletal

    public static let boneHealing = FrequencyProtocol(
        name: "Bone Support",
        targetOrgan: .bones,
        baseFrequency: 40.0  // Known bone healing frequency
    ).with {
        $0.description = "Supports bone density and healing processes"
        $0.harmonics = [25.0, 50.0]
        $0.lightWavelength = 650  // Red
        $0.lightPulseFrequency = 40.0
        $0.sessionDuration = 1200
    }

    public static let muscleRecovery = FrequencyProtocol(
        name: "Muscle Recovery",
        targetOrgan: .muscles,
        baseFrequency = 10.0  // Alpha for relaxation
    ).with {
        $0.description = "Promotes muscle relaxation and recovery"
        $0.isochronicPulse = 8.0
        $0.lightWavelength = 830  // Near-infrared
        $0.lightIntensity = 0.8
        $0.sessionDuration = 900
    }

    public static let jointMobility = FrequencyProtocol(
        name: "Joint Mobility",
        targetOrgan: .joints,
        baseFrequency: 12.0
    ).with {
        $0.description = "Supports joint health and flexibility"
        $0.lightWavelength = 850  // Deep near-infrared
        $0.sessionDuration = 900
    }

    // MARK: - Urinary

    public static let kidneyFlow = FrequencyProtocol(
        name: "Kidney Flow",
        targetOrgan: .kidneys,
        baseFrequency: 319.88  // Traditional kidney frequency
    ).with {
        $0.description = "Supports healthy kidney function"
        $0.harmonics = [396.0]  // Solfeggio UT
        $0.lightWavelength = 410  // Violet
        $0.sessionDuration = 600
        $0.contraindicatedConditions = ["kidney disease", "dialysis"]
    }

    // MARK: - All Protocols Collection

    public static let allProtocols: [FrequencyProtocol] = [
        heartCoherence, circulationSupport,
        liverDetox, digestiveBalance,
        lungVitality,
        brainwaveBalance, nerveCalmness,
        thyroidBalance, pinealActivation,
        immuneSupport,
        boneHealing, muscleRecovery, jointMobility,
        kidneyFlow
    ]
}

// MARK: - Protocol Builder Extension

extension FrequencyProtocol {
    public func with(_ configure: (inout FrequencyProtocol) -> Void) -> FrequencyProtocol {
        var copy = self
        configure(&copy)
        return copy
    }
}

// MARK: - Organ Resonance Therapy Engine

@MainActor
public class OrganResonanceEngine: ObservableObject {

    @Published public var currentProtocol: FrequencyProtocol?
    @Published public var sessionProgress: Float = 0  // 0-1
    @Published public var isSessionActive: Bool = false
    @Published public var currentPhase: SessionPhase = .idle

    // Audio output
    @Published public var audioFrequencies: [Float] = []
    @Published public var audioAmplitude: Float = 0

    // Light output
    @Published public var lightColor: SIMD3<Float> = .zero  // RGB
    @Published public var lightIntensity: Float = 0

    private var sessionTimer: Timer?
    private var sessionStartTime: Date?

    public enum SessionPhase: String {
        case idle = "Idle"
        case rampUp = "Ramping Up"
        case active = "Active"
        case rampDown = "Ramping Down"
        case complete = "Complete"
    }

    public init() {}

    // MARK: - Session Control

    /// Start a therapy session with the given protocol
    public func startSession(protocol: FrequencyProtocol) {
        guard !isSessionActive else { return }

        currentProtocol = `protocol`
        sessionStartTime = Date()
        isSessionActive = true
        currentPhase = .rampUp

        // Set initial frequencies
        updateAudioOutput(progress: 0)
        updateLightOutput(progress: 0)

        // Start session timer
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSession()
            }
        }
    }

    /// Stop the current session
    public func stopSession() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        isSessionActive = false
        currentPhase = .idle
        sessionProgress = 0

        // Fade out
        audioAmplitude = 0
        lightIntensity = 0
        currentProtocol = nil
    }

    private func updateSession() {
        guard let proto = currentProtocol,
              let startTime = sessionStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let totalDuration = proto.sessionDuration

        // Calculate progress
        sessionProgress = Float(min(1.0, elapsed / totalDuration))

        // Determine phase
        if elapsed < proto.rampUpTime {
            currentPhase = .rampUp
            let rampProgress = Float(elapsed / proto.rampUpTime)
            audioAmplitude = rampProgress * 0.5
            lightIntensity = rampProgress * proto.lightIntensity
        } else if elapsed < (totalDuration - proto.rampDownTime) {
            currentPhase = .active
            audioAmplitude = 0.5
            lightIntensity = proto.lightIntensity
        } else if elapsed < totalDuration {
            currentPhase = .rampDown
            let rampProgress = Float((totalDuration - elapsed) / proto.rampDownTime)
            audioAmplitude = rampProgress * 0.5
            lightIntensity = rampProgress * proto.lightIntensity
        } else {
            currentPhase = .complete
            stopSession()
            return
        }

        updateAudioOutput(progress: sessionProgress)
        updateLightOutput(progress: sessionProgress)
    }

    private func updateAudioOutput(progress: Float) {
        guard let proto = currentProtocol else { return }

        var frequencies: [Float] = [proto.baseFrequency]
        frequencies.append(contentsOf: proto.harmonics)

        // Add binaural beat if specified
        if let binaural = proto.binauralBeatFrequency {
            frequencies.append(proto.baseFrequency + binaural)  // Right ear offset
        }

        audioFrequencies = frequencies
    }

    private func updateLightOutput(progress: Float) {
        guard let proto = currentProtocol else { return }

        // Convert wavelength to RGB (simplified)
        lightColor = wavelengthToRGB(proto.lightWavelength)

        // Apply pulsing if specified
        if let pulseFreq = proto.lightPulseFrequency {
            let time = Float(Date().timeIntervalSince1970)
            let pulse = (sin(time * pulseFreq * 2 * .pi) + 1) / 2
            lightIntensity = proto.lightIntensity * (0.5 + 0.5 * pulse)
        }
    }

    /// Convert wavelength (nm) to RGB color
    private func wavelengthToRGB(_ wavelength: Int) -> SIMD3<Float> {
        let w = Float(wavelength)

        var r: Float = 0
        var g: Float = 0
        var b: Float = 0

        if w >= 380 && w < 440 {
            r = -(w - 440) / (440 - 380)
            b = 1.0
        } else if w >= 440 && w < 490 {
            g = (w - 440) / (490 - 440)
            b = 1.0
        } else if w >= 490 && w < 510 {
            g = 1.0
            b = -(w - 510) / (510 - 490)
        } else if w >= 510 && w < 580 {
            r = (w - 510) / (580 - 510)
            g = 1.0
        } else if w >= 580 && w < 645 {
            r = 1.0
            g = -(w - 645) / (645 - 580)
        } else if w >= 645 && w <= 780 {
            r = 1.0
        } else if w >= 780 && w <= 900 {
            // Near-infrared (invisible, show as dark red indicator)
            r = 0.3
        }

        return SIMD3<Float>(r, g, b)
    }

    // MARK: - Protocol Selection

    /// Get recommended protocol for an organ
    public func recommendProtocol(for organ: Organ) -> FrequencyProtocol? {
        return TherapeuticProtocols.allProtocols.first { $0.targetOrgan == organ }
    }

    /// Get protocols for a body system
    public func protocols(for system: OrganSystem) -> [FrequencyProtocol] {
        return TherapeuticProtocols.allProtocols.filter {
            $0.targetSystem == system ||
            (system.primaryOrgans.contains($0.targetOrgan ?? .heart))
        }
    }

    /// Create custom protocol based on wellness assessment
    public func createCustomProtocol(for assessment: OrganWellnessState) -> FrequencyProtocol {
        let organ = assessment.organ
        let baseFreq = (organ.resonantFrequencyRange.lowerBound +
                       organ.resonantFrequencyRange.upperBound) / 2

        var protocol = FrequencyProtocol(name: "Custom \(organ.rawValue)", targetOrgan: organ, baseFrequency: baseFreq)

        // Adjust based on wellness state
        if assessment.stressIndicator > 0.6 {
            // High stress: add calming frequencies
            `protocol`.binauralBeatFrequency = 6.0  // Theta
        }

        if assessment.inflammationRisk > 0.5 {
            // Inflammation: use red/infrared light
            `protocol`.lightWavelength = 830
        }

        if assessment.energyLevel < 0.4 {
            // Low energy: longer session
            `protocol`.sessionDuration = 1200
        }

        return `protocol`
    }
}

// MARK: - Medical Imaging Integration

/// Integration point for medical imaging systems
public struct MedicalImagingIntegration {

    public enum ImagingModality: String, CaseIterable {
        case ultrasound = "Ultrasound"
        case mri = "MRI"
        case ct = "CT Scan"
        case petScan = "PET Scan"
        case xRay = "X-Ray"
        case thermography = "Thermography"
        case bioelectrical = "Bioelectrical Impedance"
    }

    /// Frequency parameters that could complement imaging
    public struct ImagingProtocolParameters {
        public var modality: ImagingModality
        public var prepFrequency: Float?      // Pre-imaging relaxation
        public var breathHoldCue: Bool        // Audio cue for breath hold
        public var anxietyReduction: Bool     // Calming protocol during scan
        public var postImagingSupport: Float? // Post-scan frequency

        public static let mriSupport = ImagingProtocolParameters(
            modality: .mri,
            prepFrequency: 7.83,  // Schumann for grounding
            breathHoldCue: true,
            anxietyReduction: true,
            postImagingSupport: 10.0  // Alpha for recovery
        )

        public static let ultrasoundSupport = ImagingProtocolParameters(
            modality: .ultrasound,
            prepFrequency: 528.0,  // Relaxation
            breathHoldCue: false,
            anxietyReduction: false,
            postImagingSupport: nil
        )
    }

    /// Audio feedback based on imaging data (research concept)
    public struct SonificationMapping {
        public var dataRange: ClosedRange<Float>
        public var frequencyRange: ClosedRange<Float>
        public var volumeMapping: Bool

        /// Convert imaging data value to audio frequency
        public func sonify(_ value: Float) -> Float {
            let normalized = (value - dataRange.lowerBound) /
                           (dataRange.upperBound - dataRange.lowerBound)
            let clamped = max(0, min(1, normalized))
            return frequencyRange.lowerBound +
                   clamped * (frequencyRange.upperBound - frequencyRange.lowerBound)
        }
    }
}

// MARK: - Surgical/Nanorobotics Integration

/// Integration concepts for surgical and nanorobotics applications
public struct SurgicalIntegration {

    /// Frequency support during surgical procedures
    public struct SurgicalProtocol {
        public var procedureType: ProcedureType
        public var patientFrequencies: [Float]       // Calming for patient
        public var surgeonFrequencies: [Float]?      // Focus for surgeon
        public var ambientLightWavelength: Int?

        public enum ProcedureType: String {
            case laparoscopic = "Laparoscopic"
            case roboticAssisted = "Robotic-Assisted"
            case microsurgery = "Microsurgery"
            case laserProcedure = "Laser Procedure"
            case nanorobotic = "Nanorobotic"
        }
    }

    /// Nanorobotics control frequency interface
    /// (Theoretical - for future medical nanorobot coordination)
    public struct NanorobotFrequencyInterface {
        public var controlFrequency: Float           // Command frequency
        public var feedbackFrequency: Float          // Status feedback
        public var safetyStopFrequency: Float        // Emergency halt
        public var coordinationProtocol: String      // Swarm coordination

        /// Default interface for medical nanorobots
        public static let medicalDefault = NanorobotFrequencyInterface(
            controlFrequency: 1000000,     // 1 MHz ultrasonic
            feedbackFrequency: 1100000,    // 1.1 MHz return
            safetyStopFrequency: 500000,   // 500 kHz emergency
            coordinationProtocol: "SwarmMed-1.0"
        )
    }

    /// Laser surgery frequency synchronization
    public struct LaserSurgerySync {
        public var laserWavelength: Int              // nm
        public var pulseFrequency: Float             // Hz
        public var tissueType: TissueType
        public var audioFeedback: Bool               // Sonify laser activity

        public enum TissueType: String {
            case soft = "Soft Tissue"
            case hard = "Hard Tissue"
            case vascular = "Vascular"
            case neural = "Neural"
            case ophthalmic = "Ophthalmic"
        }
    }
}

// MARK: - Safety and Compliance

public struct TherapySafetySystem {

    public static let medicalDisclaimer = """
    IMPORTANT MEDICAL DISCLAIMER

    This frequency therapy system is designed for RESEARCH, EDUCATION,
    and general WELLNESS purposes only.

    This system:
    • Is NOT a medical device
    • Does NOT diagnose, treat, cure, or prevent any disease
    • Should NOT replace professional medical care
    • Should NOT be used during pregnancy without medical advice
    • May have contraindications with certain medical conditions

    ALWAYS consult a qualified healthcare professional before use,
    especially if you have:
    • Epilepsy or seizure disorders
    • Heart conditions or pacemakers
    • Photosensitivity conditions
    • Mental health conditions
    • Any chronic illness

    If you experience any adverse effects, stop immediately and
    consult a healthcare provider.

    By using this system, you acknowledge that you have read,
    understood, and agree to this disclaimer.
    """

    public struct ContraindicationCheck {
        public var condition: String
        public var severity: Severity
        public var blockedProtocols: [String]

        public enum Severity: String {
            case warning = "Warning"
            case caution = "Caution"
            case blocked = "Blocked"
        }
    }

    public static let commonContraindications: [ContraindicationCheck] = [
        ContraindicationCheck(
            condition: "Epilepsy",
            severity: .blocked,
            blockedProtocols: ["*"]  // All protocols blocked
        ),
        ContraindicationCheck(
            condition: "Pacemaker",
            severity: .blocked,
            blockedProtocols: ["Heart Coherence", "Circulation Support"]
        ),
        ContraindicationCheck(
            condition: "Pregnancy",
            severity: .caution,
            blockedProtocols: ["Liver Harmony", "Kidney Flow"]
        ),
        ContraindicationCheck(
            condition: "Photosensitivity",
            severity: .warning,
            blockedProtocols: []  // Light intensity should be reduced
        )
    ]

    /// Check if a protocol is safe for given conditions
    public static func checkSafety(protocol: FrequencyProtocol,
                                   userConditions: [String]) -> (safe: Bool, warnings: [String]) {
        var warnings: [String] = []

        for condition in userConditions {
            for check in commonContraindications {
                if condition.lowercased().contains(check.condition.lowercased()) {
                    if check.severity == .blocked {
                        if check.blockedProtocols.contains("*") ||
                           check.blockedProtocols.contains(`protocol`.name) {
                            return (false, ["Protocol blocked due to: \(check.condition)"])
                        }
                    } else {
                        warnings.append("\(check.severity.rawValue): \(check.condition)")
                    }
                }
            }
        }

        return (true, warnings)
    }
}

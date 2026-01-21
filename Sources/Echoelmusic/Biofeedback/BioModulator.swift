// BioModulator.swift
// Echoelmusic - Biofeedback to BPM, EFX, Instruments Modulation
//
// ⚠️ DEPRECATED - This class is superseded by UnifiedControlHub
// UnifiedControlHub provides:
// - 60Hz control loop for real-time bio-reactive modulation
// - Octave-based color mapping (HR → Audio → Light → CIE 1931 RGB)
// - Unified audio, visual, and lighting control
// - Integration with MIDIToLightMapper, ILDALaserController, LambdaModeEngine
//
// Removal scheduled: Phase 12000
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import Combine

// MARK: - Biometric Input Types

/// Raw biometric data from HealthKit or external sensors
public struct BiometricData: Equatable, Sendable {
    public var heartRate: Double          // BPM (40-200)
    public var hrvMs: Double              // Heart Rate Variability in ms (10-150)
    public var coherence: Double          // HRV coherence score (0.0-1.0)
    public var breathingRate: Double      // Breaths per minute (4-30)
    public var breathPhase: Double        // Inhale/exhale phase (0.0-1.0)
    public var skinConductance: Double    // GSR/EDA (0.0-1.0 normalized)
    public var bodyTemperature: Double    // Celsius (35-40)
    public var oxygenSaturation: Double   // SpO2 percentage (90-100)

    public init(
        heartRate: Double = 70,
        hrvMs: Double = 50,
        coherence: Double = 0.5,
        breathingRate: Double = 12,
        breathPhase: Double = 0.5,
        skinConductance: Double = 0.5,
        bodyTemperature: Double = 37,
        oxygenSaturation: Double = 98
    ) {
        self.heartRate = heartRate
        self.hrvMs = hrvMs
        self.coherence = coherence
        self.breathingRate = breathingRate
        self.breathPhase = breathPhase
        self.skinConductance = skinConductance
        self.bodyTemperature = bodyTemperature
        self.oxygenSaturation = oxygenSaturation
    }
}

// MARK: - Modulation Target Types

/// BPM/Tempo modulation targets
public enum BPMModulationTarget: String, CaseIterable, Sendable {
    case globalTempo           // Master tempo
    case sequencerTempo        // Sequencer/arpeggiator
    case delaySync             // Delay time sync
    case lfoRate               // LFO speed
    case filterEnvelope        // Filter envelope speed
    case grainDensity          // Granular synthesis density
}

/// Effect modulation targets
public enum EFXModulationTarget: String, CaseIterable, Sendable {
    // Dynamics
    case compressorThreshold
    case compressorRatio
    case limiterCeiling
    case gateThreshold

    // EQ/Filter
    case filterCutoff
    case filterResonance
    case filterEnvelopeAmount
    case eqBandGain
    case dynamicEQThreshold

    // Time-Based
    case reverbSize
    case reverbDecay
    case reverbMix
    case delayTime
    case delayFeedback
    case delayMix

    // Modulation
    case chorusDepth
    case chorusRate
    case flangerDepth
    case flangerFeedback
    case phaserDepth
    case phaserRate

    // Distortion
    case driveAmount
    case bitDepth
    case sampleRate

    // Spatial
    case stereoWidth
    case panPosition
    case spatialDistance
    case spatialAzimuth

    // Special
    case spectralMorph
    case granularPosition
    case vocoderMix
    case shimmerAmount
}

/// Instrument modulation targets
public enum InstrumentModulationTarget: String, CaseIterable, Sendable {
    // Oscillator
    case oscPitch
    case oscDetune
    case oscPulseWidth
    case oscWavetablePosition
    case oscFMAmount

    // Filter
    case synthFilterCutoff
    case synthFilterResonance
    case synthFilterEnvAmount
    case synthFilterKeyTrack

    // Amplitude
    case ampAttack
    case ampDecay
    case ampSustain
    case ampRelease
    case ampVelocitySens

    // Modulation
    case lfoAmount
    case lfoDestination
    case envModAmount
    case modulationMatrix

    // Effects (per voice)
    case voiceDistortion
    case voiceChorus
    case voiceReverb

    // Sampler
    case sampleStart
    case sampleEnd
    case sampleLoop
    case samplePitch
    case sampleStretch

    // Expression
    case expression
    case aftertouch
    case modWheel
    case breathController
}

// MARK: - Modulation Mapping

/// Defines how biometric input maps to modulation target
public struct ModulationMapping: Identifiable, Codable, Sendable {
    public let id: UUID
    public var sourceBio: BiometricSource
    public var targetType: ModulationTargetType
    public var targetName: String
    public var amount: Double           // Modulation depth (-1.0 to 1.0)
    public var curve: BioMappingCurve      // Response curve
    public var smoothing: Double        // Smoothing time in ms (0-1000)
    public var minInput: Double         // Input range min
    public var maxInput: Double         // Input range max
    public var minOutput: Double        // Output range min
    public var maxOutput: Double        // Output range max
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        sourceBio: BiometricSource,
        targetType: ModulationTargetType,
        targetName: String,
        amount: Double = 1.0,
        curve: BioMappingCurve = .linear,
        smoothing: Double = 50,
        minInput: Double = 0,
        maxInput: Double = 1,
        minOutput: Double = 0,
        maxOutput: Double = 1,
        enabled: Bool = true
    ) {
        self.id = id
        self.sourceBio = sourceBio
        self.targetType = targetType
        self.targetName = targetName
        self.amount = amount
        self.curve = curve
        self.smoothing = smoothing
        self.minInput = minInput
        self.maxInput = maxInput
        self.minOutput = minOutput
        self.maxOutput = maxOutput
        self.enabled = enabled
    }
}

/// Biometric data sources
public enum BiometricSource: String, CaseIterable, Codable, Sendable {
    case heartRate
    case hrvMs
    case coherence
    case breathingRate
    case breathPhase
    case skinConductance
    case bodyTemperature
    case oxygenSaturation

    /// Get typical range for this source
    public var typicalRange: ClosedRange<Double> {
        switch self {
        case .heartRate: return 40...200
        case .hrvMs: return 10...150
        case .coherence: return 0...1
        case .breathingRate: return 4...30
        case .breathPhase: return 0...1
        case .skinConductance: return 0...1
        case .bodyTemperature: return 35...40
        case .oxygenSaturation: return 90...100
        }
    }
}

/// Modulation target categories
public enum ModulationTargetType: String, CaseIterable, Codable, Sendable {
    case bpm
    case efx
    case instrument
}

/// Mapping curve types
public enum BioMappingCurve: String, CaseIterable, Codable, Sendable {
    case linear
    case exponential
    case logarithmic
    case sCurve
    case inverted
    case random
    case stepped
    case sine

    /// Apply curve transformation
    public func apply(_ input: Double) -> Double {
        let clamped = max(0, min(1, input))

        switch self {
        case .linear:
            return clamped
        case .exponential:
            return clamped * clamped
        case .logarithmic:
            return sqrt(clamped)
        case .sCurve:
            return clamped * clamped * (3 - 2 * clamped)
        case .inverted:
            return 1 - clamped
        case .random:
            return clamped * Double.random(in: 0.8...1.2)
        case .stepped:
            return floor(clamped * 8) / 8
        case .sine:
            return (sin((clamped - 0.5) * .pi) + 1) / 2
        }
    }
}

// MARK: - BioModulator Engine

/// Main biofeedback modulation engine
///
/// - Important: **DEPRECATED** - Use `UnifiedControlHub` instead.
///   UnifiedControlHub now handles all bio-reactive audio/visual/lighting modulation
///   in a unified 60Hz control loop with octave-based color mapping.
///
/// Migration Guide:
/// ```swift
/// // Old (BioModulator)
/// let modulator = BioModulator()
/// modulator.addMapping(source: .heartRate, target: .filterCutoff, ...)
///
/// // New (UnifiedControlHub)
/// let hub = UnifiedControlHub()
/// hub.start()  // Bio data automatically flows to audio, visuals, and lights
/// ```
///
/// This class remains for backward compatibility but will be removed in a future version.
@available(*, deprecated, message: "Use UnifiedControlHub instead. It provides unified bio-reactive control for audio, visuals, and lighting.")
@MainActor
public final class BioModulator: ObservableObject {

    // MARK: - Published Properties

    @Published public var isActive: Bool = false
    @Published public var currentBioData: BiometricData = BiometricData()
    @Published public private(set) var mappings: [ModulationMapping] = []
    @Published public private(set) var modulationOutputs: [String: Double] = [:]

    // BPM outputs
    @Published public var modulatedBPM: Double = 120
    @Published public var bpmModulationAmount: Double = 0

    // EFX outputs
    @Published public var efxModulations: [EFXModulationTarget: Double] = [:]

    // Instrument outputs
    @Published public var instrumentModulations: [InstrumentModulationTarget: Double] = [:]

    // MARK: - Configuration

    public var baseBPM: Double = 120
    public var bpmRange: ClosedRange<Double> = 60...180
    public var globalSmoothingMs: Double = 50
    public var bioReactivityLevel: Double = 1.0  // 0 = no reaction, 1 = full

    // MARK: - Internal State

    private var smoothedValues: [String: Double] = [:]
    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 1.0 / 60.0  // 60 Hz

    // MARK: - Singleton

    public static let shared = BioModulator()

    private init() {
        setupDefaultMappings()
    }

    // MARK: - Lifecycle

    public func start() {
        isActive = true
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processModulations()
            }
        }
    }

    public func stop() {
        isActive = false
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - Biometric Input

    /// Update biometric data from HealthKit or external source
    public func updateBioData(_ data: BiometricData) {
        currentBioData = data
    }

    /// Update individual biometric value
    public func updateBioValue(_ source: BiometricSource, value: Double) {
        switch source {
        case .heartRate:
            currentBioData.heartRate = value
        case .hrvMs:
            currentBioData.hrvMs = value
        case .coherence:
            currentBioData.coherence = value
        case .breathingRate:
            currentBioData.breathingRate = value
        case .breathPhase:
            currentBioData.breathPhase = value
        case .skinConductance:
            currentBioData.skinConductance = value
        case .bodyTemperature:
            currentBioData.bodyTemperature = value
        case .oxygenSaturation:
            currentBioData.oxygenSaturation = value
        }
    }

    // MARK: - Mapping Management

    public func addMapping(_ mapping: ModulationMapping) {
        mappings.append(mapping)
    }

    public func removeMapping(id: UUID) {
        mappings.removeAll { $0.id == id }
    }

    public func updateMapping(_ mapping: ModulationMapping) {
        if let index = mappings.firstIndex(where: { $0.id == mapping.id }) {
            mappings[index] = mapping
        }
    }

    public func clearMappings() {
        mappings.removeAll()
    }

    // MARK: - Default Mappings

    private func setupDefaultMappings() {
        // BPM Mappings
        addMapping(ModulationMapping(
            sourceBio: .heartRate,
            targetType: .bpm,
            targetName: BPMModulationTarget.globalTempo.rawValue,
            amount: 0.5,
            curve: .linear,
            smoothing: 200,
            minInput: 60,
            maxInput: 120,
            minOutput: 80,
            maxOutput: 140
        ))

        addMapping(ModulationMapping(
            sourceBio: .coherence,
            targetType: .bpm,
            targetName: BPMModulationTarget.lfoRate.rawValue,
            amount: 0.7,
            curve: .sCurve,
            smoothing: 100
        ))

        // EFX Mappings
        addMapping(ModulationMapping(
            sourceBio: .breathPhase,
            targetType: .efx,
            targetName: EFXModulationTarget.filterCutoff.rawValue,
            amount: 0.8,
            curve: .sine,
            smoothing: 30
        ))

        addMapping(ModulationMapping(
            sourceBio: .coherence,
            targetType: .efx,
            targetName: EFXModulationTarget.reverbSize.rawValue,
            amount: 0.6,
            curve: .exponential,
            smoothing: 500
        ))

        addMapping(ModulationMapping(
            sourceBio: .hrvMs,
            targetType: .efx,
            targetName: EFXModulationTarget.delayFeedback.rawValue,
            amount: 0.4,
            curve: .logarithmic,
            smoothing: 150,
            minInput: 20,
            maxInput: 100,
            minOutput: 0.1,
            maxOutput: 0.7
        ))

        addMapping(ModulationMapping(
            sourceBio: .skinConductance,
            targetType: .efx,
            targetName: EFXModulationTarget.driveAmount.rawValue,
            amount: 0.5,
            curve: .exponential,
            smoothing: 80
        ))

        // Instrument Mappings
        addMapping(ModulationMapping(
            sourceBio: .breathPhase,
            targetType: .instrument,
            targetName: InstrumentModulationTarget.synthFilterCutoff.rawValue,
            amount: 1.0,
            curve: .sine,
            smoothing: 20
        ))

        addMapping(ModulationMapping(
            sourceBio: .coherence,
            targetType: .instrument,
            targetName: InstrumentModulationTarget.oscWavetablePosition.rawValue,
            amount: 0.8,
            curve: .linear,
            smoothing: 300
        ))

        addMapping(ModulationMapping(
            sourceBio: .heartRate,
            targetType: .instrument,
            targetName: InstrumentModulationTarget.lfoAmount.rawValue,
            amount: 0.5,
            curve: .sCurve,
            smoothing: 100,
            minInput: 60,
            maxInput: 100,
            minOutput: 0.2,
            maxOutput: 0.8
        ))

        addMapping(ModulationMapping(
            sourceBio: .hrvMs,
            targetType: .instrument,
            targetName: InstrumentModulationTarget.ampRelease.rawValue,
            amount: 0.6,
            curve: .logarithmic,
            smoothing: 200,
            minInput: 20,
            maxInput: 100,
            minOutput: 0.1,
            maxOutput: 2.0
        ))
    }

    // MARK: - Processing

    private func processModulations() {
        guard isActive else { return }

        modulationOutputs.removeAll()

        for mapping in mappings where mapping.enabled {
            let inputValue = getBioValue(for: mapping.sourceBio)
            let outputValue = calculateModulation(mapping: mapping, inputValue: inputValue)

            let key = "\(mapping.targetType.rawValue).\(mapping.targetName)"
            modulationOutputs[key] = outputValue

            // Route to specific outputs
            routeModulation(mapping: mapping, value: outputValue)
        }

        // Calculate final BPM
        calculateModulatedBPM()
    }

    private func getBioValue(for source: BiometricSource) -> Double {
        switch source {
        case .heartRate: return currentBioData.heartRate
        case .hrvMs: return currentBioData.hrvMs
        case .coherence: return currentBioData.coherence
        case .breathingRate: return currentBioData.breathingRate
        case .breathPhase: return currentBioData.breathPhase
        case .skinConductance: return currentBioData.skinConductance
        case .bodyTemperature: return currentBioData.bodyTemperature
        case .oxygenSaturation: return currentBioData.oxygenSaturation
        }
    }

    private func calculateModulation(mapping: ModulationMapping, inputValue: Double) -> Double {
        // Normalize input to 0-1
        let normalizedInput = (inputValue - mapping.minInput) / (mapping.maxInput - mapping.minInput)
        let clampedInput = max(0, min(1, normalizedInput))

        // Apply curve
        let curvedValue = mapping.curve.apply(clampedInput)

        // Apply amount and reactivity
        let modulated = curvedValue * mapping.amount * bioReactivityLevel

        // Map to output range
        let outputValue = mapping.minOutput + modulated * (mapping.maxOutput - mapping.minOutput)

        // Apply smoothing
        let key = "\(mapping.targetType.rawValue).\(mapping.targetName)"
        let smoothed = applySmoothing(
            current: outputValue,
            previous: smoothedValues[key] ?? outputValue,
            smoothingMs: mapping.smoothing
        )
        smoothedValues[key] = smoothed

        return smoothed
    }

    private func applySmoothing(current: Double, previous: Double, smoothingMs: Double) -> Double {
        let smoothingFactor = 1.0 - exp(-updateInterval * 1000 / max(1, smoothingMs))
        return previous + (current - previous) * smoothingFactor
    }

    private func routeModulation(mapping: ModulationMapping, value: Double) {
        switch mapping.targetType {
        case .bpm:
            // BPM routing handled separately
            break

        case .efx:
            if let target = EFXModulationTarget(rawValue: mapping.targetName) {
                efxModulations[target] = value
            }

        case .instrument:
            if let target = InstrumentModulationTarget(rawValue: mapping.targetName) {
                instrumentModulations[target] = value
            }
        }
    }

    private func calculateModulatedBPM() {
        var totalModulation: Double = 0
        var modulationCount = 0

        for mapping in mappings where mapping.enabled && mapping.targetType == .bpm {
            if let value = modulationOutputs["\(mapping.targetType.rawValue).\(mapping.targetName)"] {
                totalModulation += value
                modulationCount += 1
            }
        }

        if modulationCount > 0 {
            bpmModulationAmount = totalModulation / Double(modulationCount)
            modulatedBPM = max(bpmRange.lowerBound, min(bpmRange.upperBound, bpmModulationAmount))
        } else {
            bpmModulationAmount = 0
            modulatedBPM = baseBPM
        }
    }

    // MARK: - Presets

    public func loadPreset(_ preset: BioModulatorPreset) {
        clearMappings()
        mappings = preset.mappings
        baseBPM = preset.baseBPM
        bpmRange = preset.bpmRange
        bioReactivityLevel = preset.reactivityLevel
    }

    public func saveCurrentAsPreset(name: String) -> BioModulatorPreset {
        BioModulatorPreset(
            name: name,
            mappings: mappings,
            baseBPM: baseBPM,
            bpmRange: bpmRange,
            reactivityLevel: bioReactivityLevel
        )
    }
}

// MARK: - Presets

public struct BioModulatorPreset: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var mappings: [ModulationMapping]
    public var baseBPM: Double
    public var bpmRange: ClosedRange<Double>
    public var reactivityLevel: Double

    public init(
        id: UUID = UUID(),
        name: String,
        mappings: [ModulationMapping],
        baseBPM: Double = 120,
        bpmRange: ClosedRange<Double> = 60...180,
        reactivityLevel: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.mappings = mappings
        self.baseBPM = baseBPM
        self.bpmRange = bpmRange
        self.reactivityLevel = reactivityLevel
    }

    // Built-in presets
    public static let meditation = BioModulatorPreset(
        name: "Meditation",
        mappings: [
            ModulationMapping(
                sourceBio: .breathPhase,
                targetType: .efx,
                targetName: EFXModulationTarget.filterCutoff.rawValue,
                amount: 0.8,
                curve: .sine,
                smoothing: 50
            ),
            ModulationMapping(
                sourceBio: .coherence,
                targetType: .efx,
                targetName: EFXModulationTarget.reverbSize.rawValue,
                amount: 0.9,
                curve: .exponential,
                smoothing: 1000
            ),
            ModulationMapping(
                sourceBio: .hrvMs,
                targetType: .bpm,
                targetName: BPMModulationTarget.globalTempo.rawValue,
                amount: 0.3,
                curve: .logarithmic,
                smoothing: 500,
                minInput: 30,
                maxInput: 100,
                minOutput: 50,
                maxOutput: 80
            )
        ],
        baseBPM: 60,
        bpmRange: 40...80,
        reactivityLevel: 0.7
    )

    public static let energetic = BioModulatorPreset(
        name: "Energetic",
        mappings: [
            ModulationMapping(
                sourceBio: .heartRate,
                targetType: .bpm,
                targetName: BPMModulationTarget.globalTempo.rawValue,
                amount: 1.0,
                curve: .linear,
                smoothing: 100,
                minInput: 80,
                maxInput: 150,
                minOutput: 110,
                maxOutput: 160
            ),
            ModulationMapping(
                sourceBio: .skinConductance,
                targetType: .efx,
                targetName: EFXModulationTarget.driveAmount.rawValue,
                amount: 0.8,
                curve: .exponential,
                smoothing: 50
            ),
            ModulationMapping(
                sourceBio: .breathPhase,
                targetType: .instrument,
                targetName: InstrumentModulationTarget.synthFilterCutoff.rawValue,
                amount: 1.0,
                curve: .sine,
                smoothing: 10
            )
        ],
        baseBPM: 128,
        bpmRange: 100...160,
        reactivityLevel: 1.0
    )

    public static let ambient = BioModulatorPreset(
        name: "Ambient",
        mappings: [
            ModulationMapping(
                sourceBio: .breathPhase,
                targetType: .efx,
                targetName: EFXModulationTarget.shimmerAmount.rawValue,
                amount: 0.9,
                curve: .sCurve,
                smoothing: 200
            ),
            ModulationMapping(
                sourceBio: .coherence,
                targetType: .efx,
                targetName: EFXModulationTarget.spectralMorph.rawValue,
                amount: 0.7,
                curve: .linear,
                smoothing: 500
            ),
            ModulationMapping(
                sourceBio: .hrvMs,
                targetType: .instrument,
                targetName: InstrumentModulationTarget.oscWavetablePosition.rawValue,
                amount: 0.6,
                curve: .sine,
                smoothing: 1000
            ),
            ModulationMapping(
                sourceBio: .coherence,
                targetType: .instrument,
                targetName: InstrumentModulationTarget.ampRelease.rawValue,
                amount: 0.8,
                curve: .exponential,
                smoothing: 500,
                minOutput: 0.5,
                maxOutput: 5.0
            )
        ],
        baseBPM: 70,
        bpmRange: 50...90,
        reactivityLevel: 0.5
    )

    public static let all: [BioModulatorPreset] = [
        .meditation,
        .energetic,
        .ambient
    ]
}

// MARK: - MIDI Output

extension BioModulator {

    /// Get modulation as MIDI CC value (0-127)
    public func getMidiCC(for target: EFXModulationTarget) -> UInt8 {
        let value = efxModulations[target] ?? 0.5
        return UInt8(max(0, min(127, value * 127)))
    }

    /// Get modulation as MIDI pitch bend (-8192 to 8191)
    public func getMidiPitchBend(for target: InstrumentModulationTarget) -> Int16 {
        let value = instrumentModulations[target] ?? 0.5
        let normalized = (value - 0.5) * 2  // -1 to 1
        return Int16(normalized * 8191)
    }

    /// Get all modulations as MIDI CC messages
    public func getAllMidiCCs() -> [(cc: UInt8, value: UInt8)] {
        var messages: [(UInt8, UInt8)] = []

        // Map common targets to MIDI CCs
        let ccMappings: [EFXModulationTarget: UInt8] = [
            .filterCutoff: 74,       // Cutoff
            .filterResonance: 71,    // Resonance
            .reverbMix: 91,          // Reverb
            .chorusDepth: 93,        // Chorus
            .delayMix: 94,           // Delay
            .stereoWidth: 10,        // Pan
            .driveAmount: 92         // Tremolo (repurposed)
        ]

        for (target, cc) in ccMappings {
            if let value = efxModulations[target] {
                messages.append((cc, UInt8(max(0, min(127, value * 127)))))
            }
        }

        return messages
    }
}

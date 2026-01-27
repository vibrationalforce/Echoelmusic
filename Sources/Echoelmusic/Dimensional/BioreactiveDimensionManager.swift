// BioreactiveDimensionManager.swift
// Echoelmusic
//
// Core manager for N-dimensional bioreactive mapping system.
// Handles dynamic dimension management, normalization, interference,
// and mapping to synthesis parameters.
//
// Mathematical Basis:
// - Vector space model for biometric state representation
// - PCA for dimensionality reduction to latent space
// - Dimension interference via tensor multiplication
// - Tesseract rotation for spatial modulation
// - Zernike polynomials for light array control
//
// References:
// - Russell (1980): Circumplex Model of Affect
// - McCraty et al. (2009): HeartMath Coherence
// - Mandelbrot (1982): Fractal Geometry
//
// Created 2026-01-25

import Foundation
import Accelerate
import Combine

// MARK: - Dimension Types

/// Category of biometric dimension
public enum DimensionCategory: String, Codable, Sendable, CaseIterable {
    case biometric      // Internal physiological signals
    case external       // External environmental data
    case derived        // Computed from other dimensions
    case custom         // User-defined dimensions
}

/// Specific biometric dimension types
public enum BiometricDimensionType: String, Codable, Sendable, CaseIterable {
    // Cardiac
    case heartRate
    case hrvRMSSD
    case hrvCoherence
    case hrvLFHFRatio

    // Respiratory
    case breathingRate
    case breathingPhase
    case breathingDepth

    // Electrodermal
    case gsrLevel
    case gsrResponse

    // Thermal
    case skinTemperature

    // Blood Oxygen
    case spO2

    // EEG Bands
    case eegDelta
    case eegTheta
    case eegAlpha
    case eegBeta
    case eegGamma

    // Eye Tracking
    case gazeX
    case gazeY
    case pupilDilation
    case blinkRate

    // Facial EMG
    case emgZygomatic  // Smile muscle
    case emgCorrugator // Frown muscle

    // Motion
    case accelerometerX
    case accelerometerY
    case accelerometerZ
    case gyroscopeX
    case gyroscopeY
    case gyroscopeZ
}

/// External dimension types
public enum ExternalDimensionType: String, Codable, Sendable, CaseIterable {
    case weatherTemperature
    case weatherHumidity
    case weatherPressure
    case weatherWindSpeed
    case moonPhase
    case solarActivity
    case circadianPhase
    case ambientLight
    case ambientSoundLevel
    case groupCoherence
    case latitude
    case longitude
    case altitude
}

/// Unified dimension identifier
public enum DimensionIdentifier: Hashable, Codable, Sendable {
    case biometric(BiometricDimensionType)
    case external(ExternalDimensionType)
    case derived(String)
    case custom(String)

    public var category: DimensionCategory {
        switch self {
        case .biometric: return .biometric
        case .external: return .external
        case .derived: return .derived
        case .custom: return .custom
        }
    }

    public var name: String {
        switch self {
        case .biometric(let type): return type.rawValue
        case .external(let type): return type.rawValue
        case .derived(let name): return name
        case .custom(let name): return name
        }
    }
}

// MARK: - Dimension Configuration

/// Configuration for a single dimension
public struct DimensionConfig: Codable, Sendable {
    public let identifier: DimensionIdentifier
    public let minValue: Float
    public let maxValue: Float
    public let defaultValue: Float
    public let smoothingFactor: Float  // 0 = no smoothing, 1 = max smoothing
    public let updateRate: Float       // Hz
    public let weight: Float           // Importance weight for PCA

    public static func biometric(
        _ type: BiometricDimensionType,
        min: Float,
        max: Float,
        default defaultVal: Float? = nil,
        smoothing: Float = 0.1,
        rate: Float = 60,
        weight: Float = 1.0
    ) -> DimensionConfig {
        DimensionConfig(
            identifier: .biometric(type),
            minValue: min,
            maxValue: max,
            defaultValue: defaultVal ?? (min + max) / 2,
            smoothingFactor: smoothing,
            updateRate: rate,
            weight: weight
        )
    }

    public static func external(
        _ type: ExternalDimensionType,
        min: Float,
        max: Float,
        default defaultVal: Float? = nil,
        smoothing: Float = 0.5,
        rate: Float = 1,
        weight: Float = 0.5
    ) -> DimensionConfig {
        DimensionConfig(
            identifier: .external(type),
            minValue: min,
            maxValue: max,
            defaultValue: defaultVal ?? (min + max) / 2,
            smoothingFactor: smoothing,
            updateRate: rate,
            weight: weight
        )
    }
}

// MARK: - Dimension State

/// Current state of a dimension
public struct DimensionState: Sendable {
    public let identifier: DimensionIdentifier
    public var rawValue: Float
    public var normalizedValue: Float  // 0-1 range
    public var smoothedValue: Float
    public var velocity: Float         // Rate of change
    public var lastUpdateTime: Date

    public static func initial(for config: DimensionConfig) -> DimensionState {
        let normalized = (config.defaultValue - config.minValue) / (config.maxValue - config.minValue)
        return DimensionState(
            identifier: config.identifier,
            rawValue: config.defaultValue,
            normalizedValue: normalized,
            smoothedValue: normalized,
            velocity: 0,
            lastUpdateTime: Date()
        )
    }
}

// MARK: - Interference Rule

/// Rule defining how one dimension affects another
public struct InterferenceRule: Codable, Sendable {
    public let sourceDimension: DimensionIdentifier
    public let targetDimension: DimensionIdentifier
    public let strength: Float           // -1 to 1
    public let mode: InterferenceMode
    public let threshold: Float?         // Optional activation threshold

    public enum InterferenceMode: String, Codable, Sendable {
        case multiplicative   // target *= source * strength
        case additive         // target += source * strength
        case gating           // target *= (source > threshold ? 1 : 0)
        case modulation       // target *= 1 + sin(source * 2π) * strength
        case inverse          // target *= 1 - source * strength
    }

    public init(
        from source: DimensionIdentifier,
        to target: DimensionIdentifier,
        strength: Float,
        mode: InterferenceMode = .multiplicative,
        threshold: Float? = nil
    ) {
        self.sourceDimension = source
        self.targetDimension = target
        self.strength = max(-1, min(1, strength))
        self.mode = mode
        self.threshold = threshold
    }
}

// MARK: - Latent Space

/// Reduced dimensional representation
public struct LatentState: Sendable {
    public let dimensions: [Float]
    public let timestamp: Date
    public let varianceExplained: Float

    public var arousal: Float { dimensions.count > 0 ? dimensions[0] : 0 }
    public var valence: Float { dimensions.count > 1 ? dimensions[1] : 0 }
    public var coherence: Float { dimensions.count > 2 ? dimensions[2] : 0 }
    public var attention: Float { dimensions.count > 3 ? dimensions[3] : 0 }

    public subscript(index: Int) -> Float {
        guard index >= 0 && index < dimensions.count else { return 0 }
        return dimensions[index]
    }

    public static let empty = LatentState(dimensions: [], timestamp: Date(), varianceExplained: 0)
}

// MARK: - Synthesis Parameters

/// Parameters for audio/visual synthesis
public struct SynthesisParameters: Sendable {
    // Granular Synthesis
    public var grainDensity: Float = 0.5
    public var grainSize: Float = 0.5
    public var grainPitch: Float = 0.5
    public var grainPosition: Float = 0.5
    public var grainSpread: Float = 0.5
    public var grainRandomness: Float = 0.5

    // Wavetable Synthesis
    public var wavetablePosition: Float = 0.5
    public var warpAmount: Float = 0.0
    public var filterCutoff: Float = 0.7
    public var filterResonance: Float = 0.3
    public var filterEnvelope: Float = 0.5

    // Spatial Audio
    public var spatialAzimuth: Float = 0.5
    public var spatialElevation: Float = 0.5
    public var spatialDistance: Float = 0.5
    public var spatialSpread: Float = 0.5
    public var reverbSend: Float = 0.3

    // Visual
    public var visualIntensity: Float = 0.5
    public var visualComplexity: Float = 0.5
    public var visualHue: Float = 0.5
    public var visualSaturation: Float = 0.7
    public var particleCount: Float = 0.5

    // Lighting (Zernike coefficients)
    public var lightPiston: Float = 0.5     // Z(0,0) - overall brightness
    public var lightTiltX: Float = 0.0      // Z(1,1)
    public var lightTiltY: Float = 0.0      // Z(1,-1)
    public var lightDefocus: Float = 0.0    // Z(2,0)
    public var lightAstigmatism: Float = 0.0 // Z(2,2)

    public static let `default` = SynthesisParameters()
}

// MARK: - Bioreactive Dimension Manager

/// Central manager for N-dimensional bioreactive mapping
///
/// This class handles:
/// - Dynamic dimension registration and removal
/// - Real-time normalization of heterogeneous data
/// - Dimension interference (cross-modulation)
/// - PCA-based dimensionality reduction
/// - Mapping to synthesis parameters
///
/// Usage:
/// ```swift
/// let manager = BioreactiveDimensionManager()
///
/// // Add dimensions
/// manager.addDimension(.biometric(.hrvCoherence, min: 0, max: 1))
/// manager.addDimension(.external(.weatherTemperature, min: -20, max: 45))
///
/// // Configure interference
/// manager.addInterference(from: .biometric(.hrvCoherence),
///                         to: .biometric(.heartRate),
///                         strength: -0.3)
///
/// // Process incoming data
/// manager.update(.biometric(.hrvCoherence), value: 0.75)
///
/// // Get synthesis parameters
/// let params = manager.currentSynthesisParameters
/// ```
@MainActor
public final class BioreactiveDimensionManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var dimensionCount: Int = 0
    @Published public private(set) var latentDimensions: Int = 4
    @Published public private(set) var currentLatentState: LatentState = .empty
    @Published public private(set) var currentSynthesisParameters: SynthesisParameters = .default
    @Published public private(set) var isProcessing: Bool = false

    // MARK: - Configuration

    public var targetVarianceExplained: Float = 0.95
    public var maxLatentDimensions: Int = 8
    public var pcaUpdateInterval: Int = 100  // samples between PCA updates

    // MARK: - Private State

    private var dimensions: [DimensionIdentifier: DimensionConfig] = [:]
    private var states: [DimensionIdentifier: DimensionState] = [:]
    private var interferenceRules: [InterferenceRule] = []
    private var mappingMatrix: [[Float]] = []

    // PCA State
    private var pcaMean: [Float] = []
    private var pcaComponents: [[Float]] = []
    private var pcaEigenvalues: [Float] = []
    private var sampleBuffer: [[Float]] = []
    private var sampleCount: Int = 0

    // Processing
    private var processingTimer: Timer?
    private var updateCallbacks: [(LatentState) -> Void] = []

    // MARK: - Initialization

    public init() {
        setupDefaultDimensions()
        setupDefaultMapping()
    }

    private func setupDefaultDimensions() {
        // Core biometric dimensions
        addDimension(.biometric(.heartRate, min: 40, max: 200, smoothing: 0.3))
        addDimension(.biometric(.hrvCoherence, min: 0, max: 1, smoothing: 0.2))
        addDimension(.biometric(.breathingRate, min: 4, max: 30, smoothing: 0.4))
        addDimension(.biometric(.breathingPhase, min: 0, max: 1, smoothing: 0.05))

        // EEG bands
        addDimension(.biometric(.eegAlpha, min: 0, max: 1, smoothing: 0.2, weight: 0.8))
        addDimension(.biometric(.eegTheta, min: 0, max: 1, smoothing: 0.2, weight: 0.6))

        // Default interference rules
        addInterference(
            from: .biometric(.hrvCoherence),
            to: .biometric(.heartRate),
            strength: -0.2,  // High coherence tends to lower HR
            mode: .multiplicative
        )
    }

    private func setupDefaultMapping() {
        // Initialize mapping matrix (latent dims -> synthesis params)
        // 4 latent dimensions -> ~25 synthesis parameters
        let synthParamCount = 25
        mappingMatrix = [[Float]](
            repeating: [Float](repeating: 0, count: synthParamCount),
            count: maxLatentDimensions
        )

        // Arousal (PC1) mappings
        mappingMatrix[0][0] = 0.8   // grainDensity
        mappingMatrix[0][2] = 0.3   // grainPitch
        mappingMatrix[0][7] = 0.5   // wavetablePosition
        mappingMatrix[0][10] = 0.6  // filterCutoff
        mappingMatrix[0][15] = 0.7  // visualIntensity

        // Valence (PC2) mappings
        mappingMatrix[1][4] = 0.5   // grainSpread
        mappingMatrix[1][9] = 0.4   // filterResonance
        mappingMatrix[1][17] = 0.8  // visualHue
        mappingMatrix[1][20] = 0.3  // lightTiltX

        // Coherence (PC3) mappings
        mappingMatrix[2][14] = 0.7  // reverbSend
        mappingMatrix[2][16] = 0.5  // visualComplexity
        mappingMatrix[2][19] = 0.6  // lightPiston
        mappingMatrix[2][22] = 0.4  // lightDefocus

        // Attention (PC4) mappings
        mappingMatrix[3][1] = 0.4   // grainSize
        mappingMatrix[3][5] = -0.3  // grainRandomness (inverse)
        mappingMatrix[3][13] = 0.5  // spatialSpread
    }

    // MARK: - Dimension Management

    /// Add a new dimension to the system
    public func addDimension(_ config: DimensionConfig) {
        dimensions[config.identifier] = config
        states[config.identifier] = .initial(for: config)
        dimensionCount = dimensions.count
        resetPCA()
    }

    /// Remove a dimension from the system
    public func removeDimension(_ identifier: DimensionIdentifier) {
        dimensions.removeValue(forKey: identifier)
        states.removeValue(forKey: identifier)
        interferenceRules.removeAll { $0.sourceDimension == identifier || $0.targetDimension == identifier }
        dimensionCount = dimensions.count
        resetPCA()
    }

    /// Check if dimension exists
    public func hasDimension(_ identifier: DimensionIdentifier) -> Bool {
        return dimensions[identifier] != nil
    }

    /// Get all registered dimensions
    public var registeredDimensions: [DimensionIdentifier] {
        Array(dimensions.keys)
    }

    // MARK: - Interference Management

    /// Add an interference rule
    public func addInterference(_ rule: InterferenceRule) {
        // Remove existing rule for same source-target pair
        interferenceRules.removeAll {
            $0.sourceDimension == rule.sourceDimension &&
            $0.targetDimension == rule.targetDimension
        }
        interferenceRules.append(rule)
    }

    /// Convenience method to add interference
    public func addInterference(
        from source: DimensionIdentifier,
        to target: DimensionIdentifier,
        strength: Float,
        mode: InterferenceRule.InterferenceMode = .multiplicative,
        threshold: Float? = nil
    ) {
        addInterference(InterferenceRule(
            from: source,
            to: target,
            strength: strength,
            mode: mode,
            threshold: threshold
        ))
    }

    /// Remove interference rule
    public func removeInterference(from source: DimensionIdentifier, to target: DimensionIdentifier) {
        interferenceRules.removeAll {
            $0.sourceDimension == source && $0.targetDimension == target
        }
    }

    // MARK: - Data Input

    /// Update a dimension with a new raw value
    public func update(_ identifier: DimensionIdentifier, value: Float) {
        guard let config = dimensions[identifier],
              var state = states[identifier] else { return }

        let now = Date()
        let dt = Float(now.timeIntervalSince(state.lastUpdateTime))

        // Normalize to 0-1 range
        let range = config.maxValue - config.minValue
        let normalized = range > 0 ? (value - config.minValue) / range : 0.5
        let clampedNormalized = max(0, min(1, normalized))

        // Calculate velocity
        let velocity = dt > 0 ? (clampedNormalized - state.normalizedValue) / dt : 0

        // Apply smoothing (exponential moving average)
        let alpha = 1.0 - config.smoothingFactor
        let smoothed = alpha * clampedNormalized + config.smoothingFactor * state.smoothedValue

        // Update state
        state.rawValue = value
        state.normalizedValue = clampedNormalized
        state.smoothedValue = smoothed
        state.velocity = velocity
        state.lastUpdateTime = now

        states[identifier] = state
    }

    /// Batch update multiple dimensions
    public func update(_ values: [DimensionIdentifier: Float]) {
        for (identifier, value) in values {
            update(identifier, value: value)
        }
        processUpdate()
    }

    // MARK: - Processing

    /// Start continuous processing at specified rate
    public func startProcessing(rate: Float = 60, callback: @escaping (LatentState) -> Void) {
        updateCallbacks.append(callback)

        if processingTimer == nil {
            let interval = 1.0 / Double(rate)
            processingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.processUpdate()
                }
            }
        }
        isProcessing = true
    }

    /// Stop processing
    public func stopProcessing() {
        processingTimer?.invalidate()
        processingTimer = nil
        updateCallbacks.removeAll()
        isProcessing = false
    }

    /// Process a single update cycle
    public func processUpdate() {
        // 1. Apply interference rules
        applyInterference()

        // 2. Build feature vector
        let featureVector = buildFeatureVector()

        // 3. Update PCA if needed
        updatePCA(with: featureVector)

        // 4. Transform to latent space
        let latent = transformToLatent(featureVector)
        currentLatentState = latent

        // 5. Map to synthesis parameters
        currentSynthesisParameters = mapToSynthesis(latent)

        // 6. Notify callbacks
        for callback in updateCallbacks {
            callback(latent)
        }
    }

    // MARK: - Interference Application

    private func applyInterference() {
        for rule in interferenceRules {
            guard let sourceState = states[rule.sourceDimension],
                  var targetState = states[rule.targetDimension] else { continue }

            let sourceValue = sourceState.smoothedValue

            // Check threshold if specified
            if let threshold = rule.threshold, sourceValue < threshold {
                continue
            }

            var targetValue = targetState.smoothedValue

            switch rule.mode {
            case .multiplicative:
                targetValue *= (1.0 + sourceValue * rule.strength)

            case .additive:
                targetValue += sourceValue * rule.strength

            case .gating:
                if sourceValue < (rule.threshold ?? 0.5) {
                    targetValue *= 0
                }

            case .modulation:
                targetValue *= 1.0 + sin(sourceValue * .pi * 2) * rule.strength

            case .inverse:
                targetValue *= 1.0 - sourceValue * rule.strength
            }

            targetState.smoothedValue = max(0, min(1, targetValue))
            states[rule.targetDimension] = targetState
        }
    }

    // MARK: - Feature Vector

    private func buildFeatureVector() -> [Float] {
        // Sort dimensions for consistent ordering
        let sortedIdentifiers = dimensions.keys.sorted { $0.name < $1.name }

        return sortedIdentifiers.compactMap { identifier -> Float? in
            guard let state = states[identifier],
                  let config = dimensions[identifier] else { return nil }
            return state.smoothedValue * config.weight
        }
    }

    // MARK: - PCA

    private func resetPCA() {
        pcaMean = []
        pcaComponents = []
        pcaEigenvalues = []
        sampleBuffer = []
        sampleCount = 0
    }

    private func updatePCA(with sample: [Float]) {
        guard sample.count > 0 else { return }

        // Add to buffer
        sampleBuffer.append(sample)
        sampleCount += 1

        // Update PCA periodically
        if sampleCount % pcaUpdateInterval == 0 && sampleBuffer.count >= maxLatentDimensions * 2 {
            computePCA()
        }
    }

    private func computePCA() {
        let n = sampleBuffer.count
        let d = sampleBuffer[0].count
        guard n > 0 && d > 0 else { return }

        // Compute mean
        pcaMean = [Float](repeating: 0, count: d)
        for sample in sampleBuffer {
            for i in 0..<d {
                pcaMean[i] += sample[i]
            }
        }
        for i in 0..<d {
            pcaMean[i] /= Float(n)
        }

        // Center data
        var centered = sampleBuffer.map { sample in
            zip(sample, pcaMean).map { $0 - $1 }
        }

        // Compute covariance matrix (simplified for real-time)
        var covariance = [[Float]](repeating: [Float](repeating: 0, count: d), count: d)
        for sample in centered {
            for i in 0..<d {
                for j in 0..<d {
                    covariance[i][j] += sample[i] * sample[j]
                }
            }
        }
        for i in 0..<d {
            for j in 0..<d {
                covariance[i][j] /= Float(n - 1)
            }
        }

        // Power iteration for top k eigenvectors (simplified)
        let k = min(maxLatentDimensions, d)
        pcaComponents = []
        pcaEigenvalues = []

        var residualCov = covariance

        for _ in 0..<k {
            // Random initial vector
            var v = (0..<d).map { _ in Float.random(in: -1...1) }
            var eigenvalue: Float = 0

            // Power iteration (20 iterations)
            for _ in 0..<20 {
                // v = Av
                var newV = [Float](repeating: 0, count: d)
                for i in 0..<d {
                    for j in 0..<d {
                        newV[i] += residualCov[i][j] * v[j]
                    }
                }

                // Normalize
                var norm: Float = 0
                vDSP_svesq(newV, 1, &norm, vDSP_Length(d))
                norm = sqrt(norm)

                if norm > 1e-10 {
                    eigenvalue = norm
                    var scale = 1.0 / norm
                    vDSP_vsmul(newV, 1, &scale, &v, 1, vDSP_Length(d))
                }
            }

            pcaComponents.append(v)
            pcaEigenvalues.append(eigenvalue)

            // Deflate covariance matrix
            for i in 0..<d {
                for j in 0..<d {
                    residualCov[i][j] -= eigenvalue * v[i] * v[j]
                }
            }
        }

        // Determine number of components for target variance
        let totalVariance = pcaEigenvalues.reduce(0, +)
        var cumVariance: Float = 0
        latentDimensions = 1

        for (i, eigenvalue) in pcaEigenvalues.enumerated() {
            cumVariance += eigenvalue
            if cumVariance / totalVariance >= targetVarianceExplained {
                latentDimensions = i + 1
                break
            }
        }

        latentDimensions = min(latentDimensions, maxLatentDimensions)

        // Trim old samples
        if sampleBuffer.count > pcaUpdateInterval * 10 {
            sampleBuffer = Array(sampleBuffer.suffix(pcaUpdateInterval * 5))
        }
    }

    private func transformToLatent(_ featureVector: [Float]) -> LatentState {
        guard pcaComponents.count >= latentDimensions,
              pcaMean.count == featureVector.count else {
            // Fallback: use first dimensions directly
            let dims = Array(featureVector.prefix(maxLatentDimensions))
            return LatentState(
                dimensions: dims,
                timestamp: Date(),
                varianceExplained: 0
            )
        }

        // Center
        let centered = zip(featureVector, pcaMean).map { $0 - $1 }

        // Project
        var latent = [Float](repeating: 0, count: latentDimensions)
        for i in 0..<latentDimensions {
            var dot: Float = 0
            vDSP_dotpr(centered, 1, pcaComponents[i], 1, &dot, vDSP_Length(centered.count))
            latent[i] = dot
        }

        // Normalize to 0-1 range (sigmoid)
        latent = latent.map { 1.0 / (1.0 + exp(-$0)) }

        let totalVariance = pcaEigenvalues.reduce(0, +)
        let explainedVariance = pcaEigenvalues.prefix(latentDimensions).reduce(0, +)
        let varianceRatio = totalVariance > 0 ? explainedVariance / totalVariance : 0

        return LatentState(
            dimensions: latent,
            timestamp: Date(),
            varianceExplained: varianceRatio
        )
    }

    // MARK: - Synthesis Mapping

    private func mapToSynthesis(_ latent: LatentState) -> SynthesisParameters {
        var params = SynthesisParameters.default

        guard latent.dimensions.count > 0 else { return params }

        // Apply mapping matrix
        var synthVector = [Float](repeating: 0.5, count: 25)

        for i in 0..<min(latent.dimensions.count, mappingMatrix.count) {
            for j in 0..<synthVector.count {
                synthVector[j] += (latent.dimensions[i] - 0.5) * mappingMatrix[i][j]
            }
        }

        // Clamp to 0-1
        synthVector = synthVector.map { max(0, min(1, $0)) }

        // Map to struct
        params.grainDensity = synthVector[0]
        params.grainSize = synthVector[1]
        params.grainPitch = synthVector[2]
        params.grainPosition = synthVector[3]
        params.grainSpread = synthVector[4]
        params.grainRandomness = synthVector[5]

        params.wavetablePosition = synthVector[7]
        params.warpAmount = synthVector[8]
        params.filterCutoff = synthVector[10]
        params.filterResonance = synthVector[9]
        params.filterEnvelope = synthVector[11]

        params.spatialAzimuth = synthVector[12]
        params.spatialElevation = synthVector[13]
        params.spatialDistance = synthVector[14]
        params.spatialSpread = synthVector[15]
        params.reverbSend = synthVector[14]

        params.visualIntensity = synthVector[15]
        params.visualComplexity = synthVector[16]
        params.visualHue = synthVector[17]
        params.visualSaturation = synthVector[18]
        params.particleCount = synthVector[19]

        params.lightPiston = synthVector[19]
        params.lightTiltX = synthVector[20]
        params.lightTiltY = synthVector[21]
        params.lightDefocus = synthVector[22]
        params.lightAstigmatism = synthVector[23]

        return params
    }

    // MARK: - Mapping Configuration

    /// Set custom mapping coefficient
    public func setMapping(
        latentDimension: Int,
        synthesisParameter: Int,
        coefficient: Float
    ) {
        guard latentDimension < mappingMatrix.count,
              synthesisParameter < mappingMatrix[latentDimension].count else { return }
        mappingMatrix[latentDimension][synthesisParameter] = coefficient
    }

    /// Get current dimension state
    public func getState(_ identifier: DimensionIdentifier) -> DimensionState? {
        return states[identifier]
    }

    /// Get all states as dictionary
    public var allStates: [DimensionIdentifier: DimensionState] {
        return states
    }
}

// MARK: - Presets

extension BioreactiveDimensionManager {

    /// Preset configurations for common use cases
    public enum Preset: String, CaseIterable {
        case meditation
        case energetic
        case ambient
        case research
        case performance
    }

    /// Apply a preset configuration
    public func applyPreset(_ preset: Preset) {
        // Clear existing
        dimensions.removeAll()
        states.removeAll()
        interferenceRules.removeAll()

        switch preset {
        case .meditation:
            addDimension(.biometric(.hrvCoherence, min: 0, max: 1, smoothing: 0.3, weight: 1.5))
            addDimension(.biometric(.breathingRate, min: 4, max: 12, smoothing: 0.5))
            addDimension(.biometric(.breathingPhase, min: 0, max: 1, smoothing: 0.05))
            addDimension(.biometric(.eegAlpha, min: 0, max: 1, smoothing: 0.3, weight: 1.2))
            addDimension(.biometric(.eegTheta, min: 0, max: 1, smoothing: 0.3, weight: 1.0))

            addInterference(from: .biometric(.hrvCoherence), to: .biometric(.eegAlpha), strength: 0.3)

        case .energetic:
            addDimension(.biometric(.heartRate, min: 60, max: 180, smoothing: 0.2, weight: 1.2))
            addDimension(.biometric(.hrvCoherence, min: 0, max: 1, smoothing: 0.15))
            addDimension(.biometric(.gsrLevel, min: 0, max: 1, smoothing: 0.3))
            addDimension(.biometric(.eegBeta, min: 0, max: 1, smoothing: 0.2, weight: 1.0))
            addDimension(.biometric(.accelerometerX, min: -1, max: 1, smoothing: 0.1))

            addInterference(from: .biometric(.heartRate), to: .biometric(.gsrLevel), strength: 0.4)

        case .ambient:
            addDimension(.biometric(.hrvCoherence, min: 0, max: 1, smoothing: 0.5))
            addDimension(.biometric(.breathingPhase, min: 0, max: 1, smoothing: 0.1))
            addDimension(.external(.weatherTemperature, min: -10, max: 40, smoothing: 0.9))
            addDimension(.external(.ambientLight, min: 0, max: 1000, smoothing: 0.7))
            addDimension(.external(.circadianPhase, min: 0, max: 1, smoothing: 0.95))

        case .research:
            // Full biometric suite for research
            for type in BiometricDimensionType.allCases {
                let config: DimensionConfig
                switch type {
                case .heartRate:
                    config = .biometric(type, min: 40, max: 200, smoothing: 0.1)
                case .hrvRMSSD:
                    config = .biometric(type, min: 0, max: 300, smoothing: 0.2)
                case .hrvCoherence, .gsrLevel, .gsrResponse:
                    config = .biometric(type, min: 0, max: 1, smoothing: 0.2)
                case .breathingRate:
                    config = .biometric(type, min: 4, max: 30, smoothing: 0.3)
                case .breathingPhase, .breathingDepth:
                    config = .biometric(type, min: 0, max: 1, smoothing: 0.05)
                case .skinTemperature:
                    config = .biometric(type, min: 25, max: 40, smoothing: 0.5)
                case .spO2:
                    config = .biometric(type, min: 85, max: 100, smoothing: 0.3)
                default:
                    config = .biometric(type, min: 0, max: 1, smoothing: 0.2)
                }
                addDimension(config)
            }

        case .performance:
            addDimension(.biometric(.heartRate, min: 60, max: 180, smoothing: 0.1, weight: 1.0))
            addDimension(.biometric(.hrvCoherence, min: 0, max: 1, smoothing: 0.1, weight: 1.2))
            addDimension(.biometric(.breathingPhase, min: 0, max: 1, smoothing: 0.02))
            addDimension(.biometric(.gsrResponse, min: 0, max: 1, smoothing: 0.1))
            addDimension(.biometric(.emgZygomatic, min: 0, max: 1, smoothing: 0.1))

            addInterference(from: .biometric(.hrvCoherence), to: .biometric(.gsrResponse), strength: -0.3)
            addInterference(from: .biometric(.emgZygomatic), to: .biometric(.hrvCoherence), strength: 0.2)
        }

        dimensionCount = dimensions.count
        resetPCA()
    }
}

// MARK: - OSC/WebSocket Integration

extension BioreactiveDimensionManager {

    /// Parse OSC message and update dimension
    public func handleOSCMessage(address: String, arguments: [Any]) {
        // Expected format: /echoelmusic/bio/<dimension> [float]
        let components = address.split(separator: "/")
        guard components.count >= 3,
              components[0] == "echoelmusic",
              let value = arguments.first as? Float else { return }

        let category = String(components[1])
        let dimensionName = String(components[2])

        let identifier: DimensionIdentifier?

        if category == "bio" {
            if let bioType = BiometricDimensionType(rawValue: dimensionName) {
                identifier = .biometric(bioType)
            } else {
                identifier = nil
            }
        } else if category == "external" {
            if let extType = ExternalDimensionType(rawValue: dimensionName) {
                identifier = .external(extType)
            } else {
                identifier = nil
            }
        } else {
            identifier = nil
        }

        if let id = identifier {
            update(id, value: value)
        }
    }

    /// Parse WebSocket JSON and update dimensions
    public func handleWebSocketMessage(_ json: [String: Any]) {
        if let biometrics = json["biometrics"] as? [String: Any] {
            if let hrv = biometrics["hrv"] as? [String: Any] {
                if let coherence = hrv["coherence"] as? Float {
                    update(.biometric(.hrvCoherence), value: coherence)
                }
                if let rmssd = hrv["rmssd"] as? Float {
                    update(.biometric(.hrvRMSSD), value: rmssd)
                }
            }

            if let breathing = biometrics["breathing"] as? [String: Any] {
                if let rate = breathing["rate"] as? Float {
                    update(.biometric(.breathingRate), value: rate)
                }
                if let phase = breathing["phase"] as? Float {
                    update(.biometric(.breathingPhase), value: phase)
                }
            }

            if let eeg = biometrics["eeg"] as? [String: Any] {
                if let alpha = eeg["alpha"] as? Float {
                    update(.biometric(.eegAlpha), value: alpha)
                }
                if let theta = eeg["theta"] as? Float {
                    update(.biometric(.eegTheta), value: theta)
                }
                if let beta = eeg["beta"] as? Float {
                    update(.biometric(.eegBeta), value: beta)
                }
            }
        }

        if let external = json["external"] as? [String: Any] {
            if let temp = external["temperature"] as? Float {
                update(.external(.weatherTemperature), value: temp)
            }
            if let light = external["ambient_light"] as? Float {
                update(.external(.ambientLight), value: light)
            }
        }

        processUpdate()
    }
}

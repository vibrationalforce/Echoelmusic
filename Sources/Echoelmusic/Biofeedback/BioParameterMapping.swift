import Foundation
import Combine

/// Advanced bio-parameter mapping engine with Kalman filtering
/// Applies preset configurations to transform biometric data into audio parameters
@MainActor
class BioParameterMapping: ObservableObject {

    // MARK: - Published Output Parameters

    /// Reverb wet/dry mix (0.0 - 1.0)
    @Published private(set) var reverbWet: Float = 0.3

    /// Filter cutoff frequency (Hz)
    @Published private(set) var filterCutoff: Float = 1000.0

    /// Amplitude/volume (0.0 - 1.0)
    @Published private(set) var amplitude: Float = 0.5

    /// Base note frequency (Hz)
    @Published private(set) var baseFrequency: Float = 432.0

    /// Tempo (breaths/beats per minute)
    @Published private(set) var tempo: Float = 6.0

    /// Spatial position (X/Y/Z coordinates)
    @Published private(set) var spatialPosition: SIMD3<Float> = SIMD3(0, 0, 1)

    /// Harmonic richness (number of harmonics)
    @Published private(set) var harmonicCount: Int = 5


    // MARK: - Kalman Filters

    private var hrvKalman: KalmanFilter
    private var hrKalman: KalmanFilter
    private var coherenceKalman: KalmanFilter


    // MARK: - Configuration

    private var configuration: BioMappingConfiguration
    private let presetManager: BioPresetManager


    // MARK: - Smoothing State

    private var previousReverbWet: Float = 0.3
    private var previousFilterCutoff: Float = 1000.0
    private var previousAmplitude: Float = 0.5
    private var previousTempo: Float = 6.0


    // MARK: - Initialization

    init(presetManager: BioPresetManager) {
        self.presetManager = presetManager
        self.configuration = presetManager.activeConfiguration

        // Initialize Kalman filters with default configuration
        self.hrvKalman = KalmanFilter(
            processNoise: configuration.kalmanProcessNoise,
            measurementNoise: configuration.kalmanMeasurementNoise
        )

        self.hrKalman = KalmanFilter(
            processNoise: configuration.kalmanProcessNoise,
            measurementNoise: configuration.kalmanMeasurementNoise
        )

        self.coherenceKalman = KalmanFilter(
            processNoise: configuration.kalmanProcessNoise,
            measurementNoise: configuration.kalmanMeasurementNoise
        )

        self.baseFrequency = configuration.baseFrequency

        // Listen for preset changes
        presetManager.onPresetChanged = { [weak self] newPreset in
            self?.updateConfiguration(newPreset.mapping)
        }
    }


    // MARK: - Configuration Update

    /// Update the mapping configuration (e.g., when preset changes)
    func updateConfiguration(_ newConfig: BioMappingConfiguration) {
        configuration = newConfig

        // Update Kalman filters with new noise parameters
        hrvKalman.updateNoiseParameters(
            processNoise: newConfig.kalmanProcessNoise,
            measurementNoise: newConfig.kalmanMeasurementNoise
        )

        hrKalman.updateNoiseParameters(
            processNoise: newConfig.kalmanProcessNoise,
            measurementNoise: newConfig.kalmanMeasurementNoise
        )

        coherenceKalman.updateNoiseParameters(
            processNoise: newConfig.kalmanProcessNoise,
            measurementNoise: newConfig.kalmanMeasurementNoise
        )

        // Update base frequency immediately
        baseFrequency = newConfig.baseFrequency

        print("🎛️ Bio-mapping configuration updated for preset: \(presetManager.currentPreset.rawValue)")
    }


    // MARK: - Main Update Method

    /// Apply bio-data through the mapping configuration
    /// - Parameters:
    ///   - bioData: Current biometric readings
    func apply(bioData: BioData) {
        // Step 1: Apply Kalman filtering to smooth input signals
        let filteredHRV = hrvKalman.update(measurement: bioData.hrvCoherence)
        let filteredHR = hrKalman.update(measurement: bioData.heartRate)
        let filteredCoherence = coherenceKalman.update(measurement: bioData.hrvCoherence)

        // Step 2: Map filtered values to audio parameters
        let targetReverb = mapHRVToReverb(hrv: filteredHRV)
        let targetFilter = mapHRToFilter(hr: filteredHR)
        let targetAmplitude = mapCoherenceToAmplitude(coherence: filteredCoherence)
        let targetTempo = mapHRToTempo(hr: filteredHR)

        // Step 3: Apply exponential smoothing for natural parameter transitions
        let smoothing = configuration.parameterSmoothingFactor

        reverbWet = smooth(
            current: previousReverbWet,
            target: targetReverb,
            factor: smoothing
        )
        previousReverbWet = reverbWet

        filterCutoff = smooth(
            current: previousFilterCutoff,
            target: targetFilter,
            factor: smoothing
        )
        previousFilterCutoff = filterCutoff

        amplitude = smooth(
            current: previousAmplitude,
            target: targetAmplitude,
            factor: smoothing
        )
        previousAmplitude = amplitude

        tempo = smooth(
            current: previousTempo,
            target: targetTempo,
            factor: smoothing
        )
        previousTempo = tempo

        // Step 4: Update spatial position based on coherence
        spatialPosition = calculateSpatialPosition(coherence: filteredCoherence)

        // Step 5: Calculate harmonic count
        harmonicCount = calculateHarmonicCount(
            coherence: filteredCoherence,
            audioLevel: bioData.audioLevel
        )

        #if DEBUG
        logDebugInfo(bioData: bioData, filteredHRV: filteredHRV, filteredHR: filteredHR)
        #endif
    }


    // MARK: - Mapping Functions

    /// Map HRV to reverb wet amount
    private func mapHRVToReverb(hrv: Double) -> Float {
        let normalized = normalize(
            value: hrv,
            from: 0.0,
            to: 100.0
        )

        let curved = configuration.hrvToReverbCurve.apply(normalized)

        return lerp(
            from: configuration.hrvToReverbRange.min,
            to: configuration.hrvToReverbRange.max,
            t: Float(curved)
        )
    }

    /// Map heart rate to filter cutoff
    private func mapHRToFilter(hr: Double) -> Float {
        let normalized = normalize(
            value: hr,
            from: 40.0,  // min HR
            to: 140.0    // max HR
        )

        let curved = configuration.hrToFilterCurve.apply(normalized)

        return lerp(
            from: configuration.hrToFilterRange.min,
            to: configuration.hrToFilterRange.max,
            t: Float(curved)
        )
    }

    /// Map coherence to amplitude
    private func mapCoherenceToAmplitude(coherence: Double) -> Float {
        let normalized = normalize(
            value: coherence,
            from: 0.0,
            to: 100.0
        )

        let curved = configuration.coherenceToAmplitudeCurve.apply(normalized)

        return lerp(
            from: configuration.coherenceToAmplitudeRange.min,
            to: configuration.coherenceToAmplitudeRange.max,
            t: Float(curved)
        )
    }

    /// Map heart rate to tempo
    private func mapHRToTempo(hr: Double) -> Float {
        let rawTempo = Float(hr) * configuration.hrToTempoMultiplier

        return max(
            configuration.tempoRange.min,
            min(configuration.tempoRange.max, rawTempo)
        )
    }

    /// Calculate spatial position based on coherence
    private func calculateSpatialPosition(coherence: Double) -> SIMD3<Float> {
        let stability = configuration.coherenceToSpatialStability
        let movementIntensity = configuration.spatialMovementIntensity

        // High stability = centered, low stability = moving
        let coherenceNorm = Float(normalize(value: coherence, from: 0.0, to: 100.0))
        let effectiveStability = stability * coherenceNorm + (1.0 - movementIntensity) * (1.0 - coherenceNorm)

        // Create subtle circular motion for low coherence states
        if effectiveStability < 0.9 {
            let time = Float(Date().timeIntervalSinceReferenceDate)
            let angle = time.truncatingRemainder(dividingBy: Float.pi * 2.0)
            let deviation = (1.0 - effectiveStability) * movementIntensity

            return SIMD3(
                cos(angle) * deviation * 0.5,
                sin(angle) * deviation * 0.5,
                1.0
            )
        }

        // Centered position for high coherence
        return SIMD3(0, 0, 1)
    }

    /// Calculate harmonic count based on coherence and audio level
    private func calculateHarmonicCount(coherence: Double, audioLevel: Float) -> Int {
        let baseHarmonics = 3
        let maxAdditionalHarmonics = 6

        let coherenceNorm = Float(normalize(value: coherence, from: 0.0, to: 100.0))
        let levelContribution = audioLevel * 0.3
        let coherenceContribution = coherenceNorm * 0.7

        let enrichment = (levelContribution + coherenceContribution) * configuration.harmonicEnrichmentFactor
        let additionalHarmonics = Int(enrichment * Float(maxAdditionalHarmonics))

        return min(baseHarmonics + additionalHarmonics, 12)
    }


    // MARK: - Utility Functions

    /// Normalize a value to 0-1 range
    private func normalize(value: Double, from min: Double, to max: Double) -> Double {
        let clamped = Swift.max(min, Swift.min(max, value))
        return (clamped - min) / (max - min)
    }

    /// Linear interpolation
    private func lerp(from: Float, to: Float, t: Float) -> Float {
        return from + (to - from) * t
    }

    /// Exponential smoothing
    private func smooth(current: Float, target: Float, factor: Float) -> Float {
        return current * factor + target * (1.0 - factor)
    }

    /// Log debug information periodically
    private func logDebugInfo(bioData: BioData, filteredHRV: Double, filteredHR: Double) {
        let timestamp = Int(Date().timeIntervalSince1970)
        if timestamp % 3 == 0 {
            print("""
            🎛️ BioMapping [\(presetManager.currentPreset.rawValue)]
               In:  HRV=\(String(format: "%.1f", bioData.hrvCoherence)) HR=\(String(format: "%.0f", bioData.heartRate))
               Flt: HRV=\(String(format: "%.1f", filteredHRV)) HR=\(String(format: "%.0f", filteredHR))
               Out: Rev=\(Int(reverbWet * 100))% Filt=\(Int(filterCutoff))Hz Amp=\(Int(amplitude * 100))% Tempo=\(String(format: "%.1f", tempo))
            """)
        }
    }


    // MARK: - State Summary

    /// Get a summary of current parameters
    var parameterSummary: String {
        """
        Bio-Parameter Mapping [\(presetManager.currentPreset.rawValue)]:
        - Reverb: \(Int(reverbWet * 100))%
        - Filter: \(Int(filterCutoff)) Hz
        - Amplitude: \(Int(amplitude * 100))%
        - Base Frequency: \(Int(baseFrequency)) Hz
        - Tempo: \(String(format: "%.1f", tempo)) bpm
        - Spatial: (\(String(format: "%.2f", spatialPosition.x)), \(String(format: "%.2f", spatialPosition.y)), \(String(format: "%.2f", spatialPosition.z)))
        - Harmonics: \(harmonicCount)
        """
    }
}


// MARK: - BioData Input Structure

/// Input structure for biometric data
struct BioData {
    let hrvCoherence: Double     // HeartMath coherence 0-100
    let heartRate: Double        // BPM
    let hrvRMSSD: Double         // HRV RMSSD in ms
    let breathingRate: Double    // breaths per minute
    let audioLevel: Float        // detected audio level 0-1
    let voicePitch: Float        // detected voice pitch in Hz

    /// Create BioData from HealthKitManager
    init(healthKit: HealthKitManager, audioLevel: Float = 0.5, voicePitch: Float = 0.0) {
        self.hrvCoherence = healthKit.hrvCoherence
        self.heartRate = healthKit.heartRate
        self.hrvRMSSD = healthKit.hrvRMSSD
        self.breathingRate = healthKit.heartRate / 4.0 // estimated
        self.audioLevel = audioLevel
        self.voicePitch = voicePitch
    }

    /// Create BioData with explicit values (for testing)
    init(hrvCoherence: Double, heartRate: Double, hrvRMSSD: Double = 50.0,
         breathingRate: Double = 6.0, audioLevel: Float = 0.5, voicePitch: Float = 0.0) {
        self.hrvCoherence = hrvCoherence
        self.heartRate = heartRate
        self.hrvRMSSD = hrvRMSSD
        self.breathingRate = breathingRate
        self.audioLevel = audioLevel
        self.voicePitch = voicePitch
    }

    /// Default relaxed state
    static var relaxed: BioData {
        BioData(hrvCoherence: 70, heartRate: 65, hrvRMSSD: 60, breathingRate: 5)
    }

    /// Stressed state
    static var stressed: BioData {
        BioData(hrvCoherence: 25, heartRate: 90, hrvRMSSD: 30, breathingRate: 12)
    }

    /// High coherence (flow state)
    static var flow: BioData {
        BioData(hrvCoherence: 85, heartRate: 72, hrvRMSSD: 70, breathingRate: 6)
    }
}


// MARK: - Kalman Filter

/// 1D Kalman Filter for signal smoothing
/// Provides optimal estimation of noisy biometric signals
class KalmanFilter {

    // State estimate
    private var x: Double = 0.0

    // Error covariance
    private var p: Double = 1.0

    // Process noise covariance (Q)
    private var q: Double

    // Measurement noise covariance (R)
    private var r: Double

    // Kalman gain
    private var k: Double = 0.0

    /// Initialize the Kalman filter
    /// - Parameters:
    ///   - processNoise: Q - how much the true state changes between measurements
    ///   - measurementNoise: R - how noisy the measurements are
    init(processNoise: Double, measurementNoise: Double) {
        self.q = processNoise
        self.r = measurementNoise
    }

    /// Update noise parameters (e.g., when preset changes)
    func updateNoiseParameters(processNoise: Double, measurementNoise: Double) {
        self.q = processNoise
        self.r = measurementNoise
    }

    /// Update the filter with a new measurement
    /// - Parameter measurement: The new noisy measurement
    /// - Returns: The filtered estimate
    func update(measurement: Double) -> Double {
        // Prediction step
        // x_pred = x (no control input)
        // p_pred = p + q
        let pPred = p + q

        // Update step
        // K = p_pred / (p_pred + r)
        k = pPred / (pPred + r)

        // x = x_pred + K * (measurement - x_pred)
        x = x + k * (measurement - x)

        // p = (1 - K) * p_pred
        p = (1.0 - k) * pPred

        return x
    }

    /// Reset the filter state
    func reset(initialValue: Double = 0.0) {
        x = initialValue
        p = 1.0
        k = 0.0
    }

    /// Get current estimate without updating
    var estimate: Double {
        return x
    }

    /// Get current Kalman gain (useful for diagnostics)
    var kalmanGain: Double {
        return k
    }
}


// MARK: - Extended Kalman Filter for Multi-dimensional State

/// Extended Kalman filter for tracking multiple correlated bio-signals
class ExtendedBioKalmanFilter {

    // State vector: [HRV, HR, Coherence, Breathing]
    private var state: [Double]

    // Error covariance matrix (4x4)
    private var covariance: [[Double]]

    // Process noise covariance
    private var processNoise: [[Double]]

    // Measurement noise covariance
    private var measurementNoise: [[Double]]

    init() {
        // Initialize state
        state = [50.0, 70.0, 50.0, 6.0]

        // Initialize covariance (identity)
        covariance = [
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        ]

        // Process noise (small diagonal)
        processNoise = [
            [0.01, 0, 0, 0],
            [0, 0.02, 0, 0],
            [0, 0, 0.01, 0],
            [0, 0, 0, 0.005]
        ]

        // Measurement noise
        measurementNoise = [
            [0.1, 0, 0, 0],
            [0, 0.05, 0, 0],
            [0, 0, 0.1, 0],
            [0, 0, 0, 0.1]
        ]
    }

    /// Update with new measurements
    func update(hrvRMSSD: Double, heartRate: Double, coherence: Double, breathingRate: Double) -> (hrvRMSSD: Double, heartRate: Double, coherence: Double, breathingRate: Double) {

        // Simplified update (full matrix operations would be more complex)
        // Using scalar Kalman gains for each channel

        let measurements = [hrvRMSSD, heartRate, coherence, breathingRate]

        for i in 0..<4 {
            let pPred = covariance[i][i] + processNoise[i][i]
            let k = pPred / (pPred + measurementNoise[i][i])
            state[i] = state[i] + k * (measurements[i] - state[i])
            covariance[i][i] = (1.0 - k) * pPred
        }

        return (state[0], state[1], state[2], state[3])
    }

    /// Reset to initial state
    func reset() {
        state = [50.0, 70.0, 50.0, 6.0]
        covariance = [
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        ]
    }
}

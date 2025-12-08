import Foundation
import Accelerate
import Combine

/// Breathing Rate Analyzer
/// Calculates respiratory rate from HRV data using RSA (Respiratory Sinus Arrhythmia)
/// Also supports direct respiration sensor input and camera-based breathing detection
@MainActor
public final class BreathingRateAnalyzer: ObservableObject {

    // MARK: - Published State

    /// Current breathing rate in breaths per minute (BPM)
    @Published public private(set) var breathingRate: Float = 6.0

    /// Breathing depth estimate (0-1)
    @Published public private(set) var breathingDepth: Float = 0.5

    /// Current phase of breathing cycle
    @Published public private(set) var breathingPhase: BreathingPhase = .neutral

    /// Phase progress (0-1) within current breath
    @Published public private(set) var phaseProgress: Float = 0.0

    /// Breathing regularity (0-1, higher = more regular)
    @Published public private(set) var breathingRegularity: Float = 0.8

    /// Confidence in breathing rate estimate (0-1)
    @Published public private(set) var confidence: Float = 0.0

    /// Coherence between heart rate and breathing (RSA)
    @Published public private(set) var hrvBreathingCoherence: Float = 0.5

    // MARK: - Breathing Phase

    public enum BreathingPhase: String, CaseIterable {
        case inhale = "Inhale"
        case holdInhale = "Hold (In)"
        case exhale = "Exhale"
        case holdExhale = "Hold (Out)"
        case neutral = "Neutral"

        public var suggestedDuration: Float {
            switch self {
            case .inhale: return 4.0
            case .holdInhale: return 2.0
            case .exhale: return 6.0
            case .holdExhale: return 2.0
            case .neutral: return 0.0
            }
        }
    }

    // MARK: - Analysis Mode

    public enum AnalysisMode {
        case hrvBased        // Calculate from HRV data
        case sensorBased     // Direct respiration sensor input
        case cameraBased     // Camera-based chest movement detection
        case hybrid          // Combine multiple sources
    }

    // MARK: - Private State

    private var rrIntervals: [Float] = []
    private let maxRRIntervals = 300 // ~5 minutes at 60 BPM

    private var breathingHistory: [Float] = []
    private let maxBreathingHistory = 60 // 1 minute of breathing rate samples

    private var phaseStartTime: Date = Date()
    private var currentPhaseIndex: Int = 0
    private let phaseSequence: [BreathingPhase] = [.inhale, .holdInhale, .exhale, .holdExhale]

    private var analysisMode: AnalysisMode = .hrvBased

    // FFT components
    private var fftSetup: vDSP_DFT_Setup?
    private let fftLength = 256

    // MARK: - Initialization

    public init() {
        setupFFT()
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    private func setupFFT() {
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftLength),
            .FORWARD
        )
    }

    // MARK: - Update from HRV Data

    /// Update breathing analysis from R-R intervals (HRV)
    /// - Parameter rrInterval: Time between heartbeats in milliseconds
    public func updateWithRRInterval(_ rrInterval: Float) {
        rrIntervals.append(rrInterval)
        if rrIntervals.count > maxRRIntervals {
            rrIntervals.removeFirst()
        }

        // Need at least 30 seconds of data
        guard rrIntervals.count >= 30 else {
            confidence = Float(rrIntervals.count) / 30.0
            return
        }

        // Calculate breathing rate from RSA
        analyzeRSA()
    }

    /// Update breathing analysis from heart rate series
    /// - Parameter heartRates: Array of heart rate values
    public func updateWithHeartRateSeries(_ heartRates: [Float]) {
        // Convert heart rates to R-R intervals
        let rrFromHR = heartRates.map { 60000.0 / $0 } // ms
        rrIntervals = Array(rrFromHR.suffix(maxRRIntervals))

        if rrIntervals.count >= 30 {
            analyzeRSA()
        }
    }

    // MARK: - RSA Analysis (Respiratory Sinus Arrhythmia)

    private func analyzeRSA() {
        guard rrIntervals.count >= fftLength / 2 else { return }

        // Prepare data for FFT
        var signal = Array(rrIntervals.suffix(fftLength))

        // Pad to FFT length if needed
        while signal.count < fftLength {
            signal.insert(signal.first ?? 0, at: 0)
        }

        // Remove DC component (mean)
        let mean = signal.reduce(0, +) / Float(signal.count)
        signal = signal.map { $0 - mean }

        // Apply Hanning window
        var window = [Float](repeating: 0, count: fftLength)
        vDSP_hann_window(&window, vDSP_Length(fftLength), Int32(vDSP_HANN_NORM))

        var windowedSignal = [Float](repeating: 0, count: fftLength)
        vDSP_vmul(signal, 1, window, 1, &windowedSignal, 1, vDSP_Length(fftLength))

        // Perform FFT
        var realPart = [Float](repeating: 0, count: fftLength)
        var imagPart = [Float](repeating: 0, count: fftLength)

        guard let setup = fftSetup else { return }

        windowedSignal.withUnsafeBufferPointer { inputBuffer in
            var zeroBuffer = [Float](repeating: 0, count: fftLength)
            zeroBuffer.withUnsafeMutableBufferPointer { zeroPtr in
                realPart.withUnsafeMutableBufferPointer { realPtr in
                    imagPart.withUnsafeMutableBufferPointer { imagPtr in
                        vDSP_DFT_Execute(
                            setup,
                            inputBuffer.baseAddress!,
                            zeroPtr.baseAddress!,
                            realPtr.baseAddress!,
                            imagPtr.baseAddress!
                        )
                    }
                }
            }
        }

        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: fftLength / 2)
        realPart.withUnsafeBufferPointer { realPtr in
            imagPart.withUnsafeBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(
                    realp: UnsafeMutablePointer(mutating: realPtr.baseAddress!),
                    imagp: UnsafeMutablePointer(mutating: imagPtr.baseAddress!)
                )
                magnitudes.withUnsafeMutableBufferPointer { magPtr in
                    vDSP_zvabs(&splitComplex, 1, magPtr.baseAddress!, 1, vDSP_Length(fftLength / 2))
                }
            }
        }

        // Calculate sample rate (average RR interval)
        let avgRR = rrIntervals.reduce(0, +) / Float(rrIntervals.count)
        let sampleRate = 1000.0 / avgRR // Hz

        // Find peak in respiratory frequency band (0.1-0.4 Hz = 6-24 breaths/min)
        let freqResolution = sampleRate / Float(fftLength)
        let lowBin = Int(0.1 / freqResolution)
        let highBin = min(Int(0.4 / freqResolution), fftLength / 2 - 1)

        guard highBin > lowBin else { return }

        // Find peak frequency
        var peakMagnitude: Float = 0
        var peakIndex: vDSP_Length = 0

        let respiratoryBand = Array(magnitudes[lowBin...highBin])
        vDSP_maxvi(respiratoryBand, 1, &peakMagnitude, &peakIndex, vDSP_Length(respiratoryBand.count))

        let peakFreq = Float(lowBin + Int(peakIndex)) * freqResolution
        let newBreathingRate = peakFreq * 60.0 // Convert Hz to breaths per minute

        // Validate and update
        if newBreathingRate >= 4.0 && newBreathingRate <= 30.0 {
            // Smooth the breathing rate
            let smoothedRate = breathingRate * 0.8 + newBreathingRate * 0.2
            breathingRate = smoothedRate

            // Calculate confidence based on peak prominence
            let avgMagnitude = respiratoryBand.reduce(0, +) / Float(respiratoryBand.count)
            confidence = min(1.0, peakMagnitude / (avgMagnitude * 5.0))

            // Calculate depth from peak magnitude
            breathingDepth = min(1.0, peakMagnitude / 100.0)

            // Calculate coherence (how much HRV follows breathing)
            hrvBreathingCoherence = confidence * 0.8 + 0.2

            // Update breathing history for regularity calculation
            breathingHistory.append(breathingRate)
            if breathingHistory.count > maxBreathingHistory {
                breathingHistory.removeFirst()
            }

            calculateRegularity()
            updateBreathingPhase()
        }
    }

    // MARK: - Breathing Regularity

    private func calculateRegularity() {
        guard breathingHistory.count >= 10 else {
            breathingRegularity = 0.5
            return
        }

        // Calculate coefficient of variation
        let mean = breathingHistory.reduce(0, +) / Float(breathingHistory.count)
        let variance = breathingHistory.map { pow($0 - mean, 2) }.reduce(0, +) / Float(breathingHistory.count)
        let stdDev = sqrt(variance)
        let cv = stdDev / mean

        // Lower CV = more regular breathing
        breathingRegularity = max(0, min(1, 1.0 - cv * 5.0))
    }

    // MARK: - Breathing Phase Tracking

    private func updateBreathingPhase() {
        // Calculate phase based on breathing rate
        let cycleLength = 60.0 / Double(breathingRate) // seconds per breath

        let timeSincePhaseStart = Date().timeIntervalSince(phaseStartTime)

        // Standard 4-7-8 pattern ratios: inhale 4, hold 7, exhale 8 (simplified to 4-2-6-2)
        let inhaleRatio: Double = 4.0 / 14.0
        let holdInRatio: Double = 2.0 / 14.0
        let exhaleRatio: Double = 6.0 / 14.0
        let holdOutRatio: Double = 2.0 / 14.0

        let phaseDurations = [
            inhaleRatio * cycleLength,
            holdInRatio * cycleLength,
            exhaleRatio * cycleLength,
            holdOutRatio * cycleLength
        ]

        let currentPhaseDuration = phaseDurations[currentPhaseIndex]

        if timeSincePhaseStart >= currentPhaseDuration {
            // Move to next phase
            currentPhaseIndex = (currentPhaseIndex + 1) % phaseSequence.count
            phaseStartTime = Date()
            breathingPhase = phaseSequence[currentPhaseIndex]
            phaseProgress = 0.0
        } else {
            phaseProgress = Float(timeSincePhaseStart / currentPhaseDuration)
        }
    }

    // MARK: - Direct Sensor Input

    /// Update from direct respiration sensor value
    /// - Parameter value: Respiration amplitude (0-1)
    public func updateWithRespirationSensor(_ value: Float) {
        analysisMode = .sensorBased

        // Detect breath cycle from amplitude changes
        // Rising = inhale, falling = exhale
        // Peak detection for breath rate calculation

        // Simple state machine for breath detection
        if value > 0.7 && breathingPhase != .inhale {
            breathingPhase = .holdInhale
        } else if value < 0.3 && breathingPhase != .exhale {
            breathingPhase = .holdExhale
        }

        breathingDepth = value
        confidence = 0.9 // Direct sensor = high confidence
    }

    // MARK: - Guided Breathing Support

    /// Get suggested breathing parameters for coherence training
    /// - Returns: Optimal breathing rate and phase durations
    public func getGuidedBreathingParameters() -> GuidedBreathingParameters {
        // Optimal coherence breathing rate is typically 4-7 breaths/min
        // Personalized based on current rate and regularity
        let targetRate: Float

        if breathingRegularity > 0.7 {
            // User has regular breathing - guide toward coherence
            targetRate = 6.0
        } else {
            // User has irregular breathing - guide more gradually
            targetRate = max(6.0, min(breathingRate, 10.0))
        }

        let cycleLength = 60.0 / targetRate

        return GuidedBreathingParameters(
            targetRate: targetRate,
            inhaleDuration: Float(cycleLength * 0.4),
            holdInDuration: Float(cycleLength * 0.1),
            exhaleDuration: Float(cycleLength * 0.4),
            holdOutDuration: Float(cycleLength * 0.1),
            currentPhase: breathingPhase,
            phaseProgress: phaseProgress
        )
    }

    public struct GuidedBreathingParameters {
        public let targetRate: Float
        public let inhaleDuration: Float
        public let holdInDuration: Float
        public let exhaleDuration: Float
        public let holdOutDuration: Float
        public let currentPhase: BreathingPhase
        public let phaseProgress: Float

        /// Total cycle duration in seconds
        public var cycleDuration: Float {
            inhaleDuration + holdInDuration + exhaleDuration + holdOutDuration
        }
    }

    // MARK: - Audio/Visual Parameter Mapping

    /// Map breathing to audio parameters
    public func mapToAudioParameters() -> BreathingAudioParameters {
        return BreathingAudioParameters(
            filterModulation: sin(phaseProgress * .pi) * breathingDepth,
            amplitudeEnvelope: phaseBasedAmplitude(),
            tempoModulation: breathingRate / 12.0, // Normalize to 0.5-2.0 range
            reverbMix: 1.0 - breathingRegularity // Irregular = more reverb (calming)
        )
    }

    private func phaseBasedAmplitude() -> Float {
        switch breathingPhase {
        case .inhale: return 0.3 + phaseProgress * 0.7
        case .holdInhale: return 1.0
        case .exhale: return 1.0 - phaseProgress * 0.7
        case .holdExhale: return 0.3
        case .neutral: return 0.5
        }
    }

    public struct BreathingAudioParameters {
        /// Filter cutoff modulation (oscillates with breath)
        public let filterModulation: Float

        /// Amplitude envelope following breath
        public let amplitudeEnvelope: Float

        /// Tempo modulation based on breathing rate
        public let tempoModulation: Float

        /// Reverb mix (higher for calming effect)
        public let reverbMix: Float
    }

    /// Map breathing to visual parameters
    public func mapToVisualParameters() -> BreathingVisualParameters {
        return BreathingVisualParameters(
            expansionFactor: breathingDepth * (breathingPhase == .inhale || breathingPhase == .holdInhale ? 1.0 : 0.8),
            brightness: phaseBasedAmplitude(),
            hueShift: phaseProgress * 0.1, // Subtle color shift through breath
            pulseIntensity: breathingRegularity
        )
    }

    public struct BreathingVisualParameters {
        /// Visual expansion factor (grows with inhale)
        public let expansionFactor: Float

        /// Overall brightness modulation
        public let brightness: Float

        /// Hue shift through breathing cycle
        public let hueShift: Float

        /// Pulse intensity (higher for regular breathing)
        public let pulseIntensity: Float
    }
}

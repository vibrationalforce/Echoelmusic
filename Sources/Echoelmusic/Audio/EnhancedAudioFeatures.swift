import Foundation
import AVFoundation
import Accelerate
import Combine

// MARK: - Adaptive Audio Engine

/// Dynamically adjusts audio quality and latency based on system resources
@MainActor
class AdaptiveAudioEngine: ObservableObject {

    // MARK: - Quality Presets

    enum QualityPreset: String, CaseIterable {
        case batterySaver = "Battery Saver"
        case balanced = "Balanced"
        case maximum = "Maximum Quality"
        case ultraLowLatency = "Ultra Low Latency"

        var bufferSize: Int {
            switch self {
            case .batterySaver: return 2048
            case .balanced: return 512
            case .maximum: return 1024
            case .ultraLowLatency: return 128
            }
        }

        var sampleRate: Double {
            switch self {
            case .batterySaver: return 44100
            case .balanced: return 48000
            case .maximum: return 96000
            case .ultraLowLatency: return 48000
            }
        }

        var channelCount: Int {
            switch self {
            case .batterySaver: return 2
            case .balanced: return 2
            case .maximum: return 8
            case .ultraLowLatency: return 2
            }
        }
    }

    // MARK: - Published Properties

    @Published var currentPreset: QualityPreset = .balanced
    @Published var cpuUsage: Float = 0.0
    @Published var currentLatency: TimeInterval = 0.0
    @Published var isAdaptiveMode: Bool = true
    @Published var bufferUnderrunCount: Int = 0

    // MARK: - Private Properties

    private var timer: Timer?
    private var performanceHistory: [Float] = []
    private let maxHistorySize = 30 // 30 seconds at 1Hz sampling

    // MARK: - Initialization

    init() {
        startMonitoring()
    }

    deinit {
        // Timer must be invalidated directly — stopMonitoring() is @MainActor-isolated
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Public Methods

    func setPreset(_ preset: QualityPreset) {
        currentPreset = preset
        applyAudioConfiguration()
        log.audio("Applied audio preset: \(preset.rawValue)")
    }

    func enableAdaptiveMode(_ enabled: Bool) {
        isAdaptiveMode = enabled
        if enabled {
            log.audio("Adaptive audio mode enabled")
        } else {
            log.audio("Adaptive audio mode disabled")
        }
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePerformanceMetrics()
            }
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updatePerformanceMetrics() {
        // Estimate CPU usage (simplified)
        let processorCount = ProcessInfo.processInfo.processorCount
        let activeProcessorCount = ProcessInfo.processInfo.activeProcessorCount
        let estimatedCPU = 1.0 - (Float(activeProcessorCount) / Float(processorCount))

        cpuUsage = estimatedCPU * 100.0
        performanceHistory.append(cpuUsage)

        if performanceHistory.count > maxHistorySize {
            performanceHistory.removeFirst()
        }

        // Adaptive quality adjustment
        if isAdaptiveMode {
            adaptQuality()
        }

        // Update latency estimate
        updateLatencyEstimate()
    }

    private func adaptQuality() {
        let avgCPU = performanceHistory.reduce(0, +) / Float(performanceHistory.count)

        if avgCPU > 80.0 && currentPreset != .batterySaver {
            // High CPU usage - downgrade quality
            switch currentPreset {
            case .maximum:
                setPreset(.balanced)
            case .balanced, .ultraLowLatency:
                setPreset(.batterySaver)
            default:
                break
            }
        } else if avgCPU < 40.0 && currentPreset == .batterySaver {
            // Low CPU usage - can upgrade quality
            setPreset(.balanced)
        }
    }

    private func updateLatencyEstimate() {
        let bufferDuration = Double(currentPreset.bufferSize) / currentPreset.sampleRate
        currentLatency = bufferDuration * 1000.0 // Convert to milliseconds
    }

    private func applyAudioConfiguration() {
        #if os(macOS)
        log.audio("Audio configured: \(currentPreset.sampleRate)Hz, \(currentPreset.bufferSize) samples (macOS — HAL managed)")
        #else
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setPreferredIOBufferDuration(
                Double(currentPreset.bufferSize) / currentPreset.sampleRate
            )
            try audioSession.setPreferredSampleRate(currentPreset.sampleRate)

            log.audio("Audio configured: \(currentPreset.sampleRate)Hz, \(currentPreset.bufferSize) samples")
        } catch {
            log.audio("Failed to apply audio configuration: \(error)", level: .error)
        }
        #endif
    }
}

// MARK: - Advanced Binaural Processor

/// Advanced binaural beat processor with gamma entrainment and Schumann resonance
class AdvancedBinauralProcessor {

    // MARK: - Frequency Presets

    enum FrequencyPreset: String, CaseIterable {
        case gammaEntrainment = "Gamma (40 Hz) - Focus"
        case schumannResonance = "Schumann (7.83 Hz) - Earth"
        case deltaDeep = "Delta (2 Hz) - Deep Sleep"
        case thetaMeditation = "Theta (6 Hz) - Meditation"
        case alphaRelaxation = "Alpha (10 Hz) - Relaxation"
        case betaConcentration = "Beta (20 Hz) - Concentration"
        case highGamma = "High Gamma (100 Hz) - Peak Performance"

        var beatFrequency: Float {
            switch self {
            case .gammaEntrainment: return 40.0
            case .schumannResonance: return 7.83
            case .deltaDeep: return 2.0
            case .thetaMeditation: return 6.0
            case .alphaRelaxation: return 10.0
            case .betaConcentration: return 20.0
            case .highGamma: return 100.0
            }
        }

        /// Carrier frequency — A4 = 440 Hz (ISO 16 standard)
        var carrierFrequency: Float {
            return 440.0 // A4 standard tuning (ISO 16)
        }
    }

    enum BeatType {
        case binaural      // Left/right frequency difference
        case isochronic    // Pulsing tone
        case monaural      // Same frequency both ears
    }

    // MARK: - Properties

    private var currentPreset: FrequencyPreset = .alphaRelaxation
    private var beatType: BeatType = .binaural
    private var amplitude: Float = 0.3
    private var phase: Float = 0.0
    private var sampleRate: Float = 48000.0
    private var hrtfEnabled: Bool = false

    // HRTF coefficients (simplified - production would use full HRTF database)
    private var hrtfLeftITD: Float = 0.0  // Interaural Time Difference
    private var hrtfRightITD: Float = 0.0

    // MARK: - Public Methods

    func configure(preset: FrequencyPreset, type: BeatType = .binaural, amplitude: Float = 0.3) {
        self.currentPreset = preset
        self.beatType = type
        self.amplitude = min(max(amplitude, 0.0), 1.0)
        log.audio("Binaural configured: \(preset.rawValue), type: \(type)")
    }

    func enableHRTF(_ enabled: Bool, azimuth: Float = 0.0) {
        hrtfEnabled = enabled
        if enabled {
            // Simplified HRTF: azimuth affects ITD
            // Full implementation would use CIPIC or MIT KEMAR database
            let maxITD: Float = 0.0007 // ~700 microseconds max
            hrtfLeftITD = -sin(azimuth * .pi / 180.0) * maxITD
            hrtfRightITD = sin(azimuth * .pi / 180.0) * maxITD
            log.audio("HRTF enabled with azimuth: \(azimuth)°")
        }
    }

    func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        guard channelCount >= 2 else {
            log.audio("Binaural requires stereo output", level: .warning)
            return
        }

        let leftChannel = channelData[0]
        let rightChannel = channelData[1]

        switch beatType {
        case .binaural:
            processBinaural(leftChannel: leftChannel, rightChannel: rightChannel, frameLength: frameLength)
        case .isochronic:
            processIsochronic(leftChannel: leftChannel, rightChannel: rightChannel, frameLength: frameLength)
        case .monaural:
            processMonaural(leftChannel: leftChannel, rightChannel: rightChannel, frameLength: frameLength)
        }
    }

    // MARK: - Private Methods

    private func processBinaural(leftChannel: UnsafeMutablePointer<Float>,
                                 rightChannel: UnsafeMutablePointer<Float>,
                                 frameLength: Int) {
        let carrier = currentPreset.carrierFrequency
        let beat = currentPreset.beatFrequency
        let leftFreq = carrier - beat / 2.0
        let rightFreq = carrier + beat / 2.0

        let phaseIncLeft = 2.0 * Float.pi * leftFreq / sampleRate
        let phaseIncRight = 2.0 * Float.pi * rightFreq / sampleRate

        var currentPhaseLeft = phase
        var currentPhaseRight = phase

        for i in 0..<frameLength {
            // Apply HRTF if enabled
            let hrtfLeft = hrtfEnabled ? sin(currentPhaseLeft - hrtfLeftITD * sampleRate) : sin(currentPhaseLeft)
            let hrtfRight = hrtfEnabled ? sin(currentPhaseRight - hrtfRightITD * sampleRate) : sin(currentPhaseRight)

            leftChannel[i] += amplitude * hrtfLeft
            rightChannel[i] += amplitude * hrtfRight

            currentPhaseLeft += phaseIncLeft
            currentPhaseRight += phaseIncRight

            // Wrap phase
            if currentPhaseLeft > 2.0 * Float.pi { currentPhaseLeft -= 2.0 * Float.pi }
            if currentPhaseRight > 2.0 * Float.pi { currentPhaseRight -= 2.0 * Float.pi }
        }

        phase = currentPhaseLeft
    }

    private func processIsochronic(leftChannel: UnsafeMutablePointer<Float>,
                                   rightChannel: UnsafeMutablePointer<Float>,
                                   frameLength: Int) {
        let carrier = currentPreset.carrierFrequency
        let pulseFreq = currentPreset.beatFrequency

        let carrierPhaseInc = 2.0 * Float.pi * carrier / sampleRate
        let pulsePhaseInc = 2.0 * Float.pi * pulseFreq / sampleRate

        var carrierPhase = phase
        var pulsePhase: Float = 0.0

        for i in 0..<frameLength {
            let carrierSample = sin(carrierPhase)
            let pulseSample = (sin(pulsePhase) + 1.0) / 2.0 // 0 to 1
            let outputSample = amplitude * carrierSample * pulseSample

            leftChannel[i] += outputSample
            rightChannel[i] += outputSample

            carrierPhase += carrierPhaseInc
            pulsePhase += pulsePhaseInc

            if carrierPhase > 2.0 * Float.pi { carrierPhase -= 2.0 * Float.pi }
            if pulsePhase > 2.0 * Float.pi { pulsePhase -= 2.0 * Float.pi }
        }

        phase = carrierPhase
    }

    private func processMonaural(leftChannel: UnsafeMutablePointer<Float>,
                                 rightChannel: UnsafeMutablePointer<Float>,
                                 frameLength: Int) {
        let carrier = currentPreset.carrierFrequency
        let beat = currentPreset.beatFrequency

        let freq1PhaseInc = 2.0 * Float.pi * carrier / sampleRate
        let freq2PhaseInc = 2.0 * Float.pi * (carrier + beat) / sampleRate

        var phase1 = phase
        var phase2: Float = 0.0

        for i in 0..<frameLength {
            let sample1 = sin(phase1)
            let sample2 = sin(phase2)
            let outputSample = amplitude * (sample1 + sample2) / 2.0

            leftChannel[i] += outputSample
            rightChannel[i] += outputSample

            phase1 += freq1PhaseInc
            phase2 += freq2PhaseInc

            if phase1 > 2.0 * Float.pi { phase1 -= 2.0 * Float.pi }
            if phase2 > 2.0 * Float.pi { phase2 -= 2.0 * Float.pi }
        }

        phase = phase1
    }
}

// MARK: - Spectral Analyzer

/// Real-time FFT spectral analyzer with peak detection and band analysis
class SpectralAnalyzer {

    // MARK: - Analysis Results

    struct SpectralData {
        var spectrum: [Float]           // Magnitude spectrum
        var frequencies: [Float]        // Frequency bins
        var peaks: [Peak]              // Detected peaks
        var spectralCentroid: Float    // Brightness measure
        var spectralFlux: Float        // Onset detection
        var melBands: [Float]          // Mel-frequency bands
        var dominantFrequency: Float   // Strongest frequency
        var spectralRolloff: Float     // 85% energy point
    }

    struct Peak {
        var frequency: Float
        var magnitude: Float
        var binIndex: Int
    }

    // MARK: - Properties

    private let fftSize: Int = 8192
    private let hopSize: Int = 2048
    private var fftSetup: vDSP_DFT_Setup?

    private var window: [Float]
    private var magnitudes: [Float]
    private var previousMagnitudes: [Float]

    private let sampleRate: Float
    private let nyquistFrequency: Float

    // Mel filterbank
    private let melBandCount = 40
    private var melFilterbank: [[Float]] = []

    // MARK: - Initialization

    init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        self.nyquistFrequency = sampleRate / 2.0

        // Create Hann window
        self.window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        self.magnitudes = [Float](repeating: 0, count: fftSize / 2)
        self.previousMagnitudes = [Float](repeating: 0, count: fftSize / 2)

        // Create FFT setup
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        )

        // Create mel filterbank
        createMelFilterbank()

        log.audio("Spectral analyzer initialized: \(fftSize)-point FFT")
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // MARK: - Public Methods

    func analyze(buffer: AVAudioPCMBuffer) -> SpectralData {
        guard let channelData = buffer.floatChannelData else {
            return emptySpectralData()
        }

        let samples = channelData[0]
        let frameLength = Int(buffer.frameLength)

        // Perform FFT
        let spectrum = performFFT(samples: samples, length: frameLength)

        // Calculate frequencies for each bin
        let frequencies = calculateFrequencies()

        // Detect peaks
        let peaks = detectPeaks(spectrum: spectrum, frequencies: frequencies)

        // Calculate spectral centroid
        let centroid = calculateSpectralCentroid(spectrum: spectrum, frequencies: frequencies)

        // Calculate spectral flux
        let flux = calculateSpectralFlux(spectrum: spectrum)

        // Calculate mel bands
        let melBands = calculateMelBands(spectrum: spectrum)

        // Find dominant frequency
        let dominantFreq = findDominantFrequency(spectrum: spectrum, frequencies: frequencies)

        // Calculate spectral rolloff
        let rolloff = calculateSpectralRolloff(spectrum: spectrum, frequencies: frequencies)

        // Store current magnitudes for next flux calculation
        previousMagnitudes = spectrum

        return SpectralData(
            spectrum: spectrum,
            frequencies: frequencies,
            peaks: peaks,
            spectralCentroid: centroid,
            spectralFlux: flux,
            melBands: melBands,
            dominantFrequency: dominantFreq,
            spectralRolloff: rolloff
        )
    }

    func isolateBand(buffer: AVAudioPCMBuffer, lowFreq: Float, highFreq: Float) {
        guard let channelData = buffer.floatChannelData else { return }
        guard let setup = fftSetup else { return }

        let samples = channelData[0]
        let frameLength = Int(buffer.frameLength)

        // Prepare buffers
        var real = [Float](repeating: 0, count: fftSize)
        var imaginary = [Float](repeating: 0, count: fftSize)

        // Copy and window samples
        let copyLength = min(frameLength, fftSize)
        for i in 0..<copyLength {
            real[i] = samples[i] * window[i]
        }

        // Forward FFT — copy inputs to avoid overlapping access with outputs
        var realIn = [Float](real)
        var imagIn = [Float](imaginary)
        vDSP_DFT_Execute(setup, &realIn, &imagIn, &real, &imaginary)

        // Zero out bins outside desired frequency range
        let lowBin = Int((lowFreq / nyquistFrequency) * Float(fftSize / 2))
        let highBin = Int((highFreq / nyquistFrequency) * Float(fftSize / 2))

        for i in 0..<fftSize {
            if i < lowBin || i > highBin {
                real[i] = 0
                imaginary[i] = 0
            }
        }

        // Inverse FFT
        var inverseSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.INVERSE
        )

        if let invSetup = inverseSetup {
            // Copy inputs to avoid overlapping access with outputs
            var invRealIn = [Float](real)
            var invImagIn = [Float](imaginary)
            vDSP_DFT_Execute(invSetup, &invRealIn, &invImagIn, &real, &imaginary)
            vDSP_DFT_DestroySetup(invSetup)
        }

        // Normalize and copy back
        var scale = 1.0 / Float(fftSize)
        var scaledReal = real
        vDSP_vsmul(scaledReal, 1, &scale, &real, 1, vDSP_Length(copyLength))

        for i in 0..<copyLength {
            samples[i] = real[i]
        }
    }

    // MARK: - Private Methods

    private func performFFT(samples: UnsafeMutablePointer<Float>, length: Int) -> [Float] {
        guard let setup = fftSetup else { return [] }

        var real = [Float](repeating: 0, count: fftSize)
        var imaginary = [Float](repeating: 0, count: fftSize)

        // Copy and window samples
        let copyLength = min(length, fftSize)
        for i in 0..<copyLength {
            real[i] = samples[i] * window[i]
        }

        // Perform FFT
        var fftRealIn = real
        var fftImagIn = imaginary
        vDSP_DFT_Execute(setup, &fftRealIn, &fftImagIn, &real, &imaginary)

        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        for i in 0..<fftSize / 2 {
            magnitudes[i] = sqrt(real[i] * real[i] + imaginary[i] * imaginary[i])
        }

        return magnitudes
    }

    private func calculateFrequencies() -> [Float] {
        var frequencies = [Float](repeating: 0, count: fftSize / 2)
        for i in 0..<fftSize / 2 {
            frequencies[i] = Float(i) * sampleRate / Float(fftSize)
        }
        return frequencies
    }

    private func detectPeaks(spectrum: [Float], frequencies: [Float], threshold: Float = 0.1) -> [Peak] {
        var peaks: [Peak] = []

        // Find local maxima
        for i in 1..<spectrum.count - 1 {
            if spectrum[i] > spectrum[i - 1] && spectrum[i] > spectrum[i + 1] && spectrum[i] > threshold {
                peaks.append(Peak(
                    frequency: frequencies[i],
                    magnitude: spectrum[i],
                    binIndex: i
                ))
            }
        }

        // Sort by magnitude
        peaks.sort { $0.magnitude > $1.magnitude }

        // Return top 10 peaks
        return Array(peaks.prefix(10))
    }

    private func calculateSpectralCentroid(spectrum: [Float], frequencies: [Float]) -> Float {
        var weightedSum: Float = 0.0
        var totalMagnitude: Float = 0.0

        for i in 0..<spectrum.count {
            weightedSum += frequencies[i] * spectrum[i]
            totalMagnitude += spectrum[i]
        }

        return totalMagnitude > 0 ? weightedSum / totalMagnitude : 0
    }

    private func calculateSpectralFlux(spectrum: [Float]) -> Float {
        var flux: Float = 0.0

        for i in 0..<min(spectrum.count, previousMagnitudes.count) {
            let diff = spectrum[i] - previousMagnitudes[i]
            flux += max(diff, 0) // Half-wave rectification
        }

        return flux / Float(spectrum.count)
    }

    private func calculateMelBands(spectrum: [Float]) -> [Float] {
        var melBands = [Float](repeating: 0, count: melBandCount)

        for (bandIdx, filter) in melFilterbank.enumerated() {
            var bandEnergy: Float = 0.0
            for (binIdx, weight) in filter.enumerated() {
                if binIdx < spectrum.count {
                    bandEnergy += spectrum[binIdx] * weight
                }
            }
            melBands[bandIdx] = bandEnergy
        }

        return melBands
    }

    private func findDominantFrequency(spectrum: [Float], frequencies: [Float]) -> Float {
        guard let maxIndex = spectrum.enumerated().max(by: { $0.element < $1.element })?.offset else {
            return 0
        }
        return frequencies[maxIndex]
    }

    private func calculateSpectralRolloff(spectrum: [Float], frequencies: [Float], threshold: Float = 0.85) -> Float {
        let totalEnergy = spectrum.reduce(0, +)
        var cumulativeEnergy: Float = 0.0
        let targetEnergy = totalEnergy * threshold

        for i in 0..<spectrum.count {
            cumulativeEnergy += spectrum[i]
            if cumulativeEnergy >= targetEnergy {
                return frequencies[i]
            }
        }

        return nyquistFrequency
    }

    private func createMelFilterbank() {
        // Mel scale conversion functions
        func hzToMel(_ hz: Float) -> Float {
            return 2595.0 * log10(1.0 + hz / 700.0)
        }

        func melToHz(_ mel: Float) -> Float {
            return 700.0 * (pow(10.0, mel / 2595.0) - 1.0)
        }

        let minMel = hzToMel(0)
        let maxMel = hzToMel(nyquistFrequency)
        let melStep = (maxMel - minMel) / Float(melBandCount + 1)

        // Create triangular filters
        for i in 0..<melBandCount {
            let leftMel = minMel + Float(i) * melStep
            let centerMel = minMel + Float(i + 1) * melStep
            let rightMel = minMel + Float(i + 2) * melStep

            let leftHz = melToHz(leftMel)
            let centerHz = melToHz(centerMel)
            let rightHz = melToHz(rightMel)

            var filter = [Float](repeating: 0, count: fftSize / 2)

            for binIdx in 0..<fftSize / 2 {
                let freq = Float(binIdx) * sampleRate / Float(fftSize)

                if freq >= leftHz && freq <= centerHz {
                    filter[binIdx] = (freq - leftHz) / (centerHz - leftHz)
                } else if freq > centerHz && freq <= rightHz {
                    filter[binIdx] = (rightHz - freq) / (rightHz - centerHz)
                }
            }

            melFilterbank.append(filter)
        }
    }

    private func emptySpectralData() -> SpectralData {
        return SpectralData(
            spectrum: [],
            frequencies: [],
            peaks: [],
            spectralCentroid: 0,
            spectralFlux: 0,
            melBands: [],
            dominantFrequency: 0,
            spectralRolloff: 0
        )
    }
}

// MARK: - Bio-Adaptive Mixer

/// Mixes audio based on biometric data (coherence, HRV, heart rate, breathing)
@MainActor
class BioAdaptiveMixer: ObservableObject {

    // MARK: - Biometric State

    struct BiometricState {
        var coherence: Float          // 0.0 - 1.0
        var heartRate: Float          // BPM
        var hrv: Float                // RMSSD in ms
        var breathingRate: Float      // Breaths per minute
        var breathPhase: Float        // 0.0 - 1.0 (inhale to exhale)
        var arousal: Float            // 0.0 - 1.0 (calculated from HR/HRV)
    }

    // MARK: - Published Properties

    @Published var currentState = BiometricState(
        coherence: 0.5,
        heartRate: 70,
        hrv: 50,
        breathingRate: 15,
        breathPhase: 0,
        arousal: 0.5
    )

    @Published var volumeAutomation: Float = 1.0
    @Published var filterCutoff: Float = 8000.0
    @Published var reverbAmount: Float = 0.3
    @Published var effectsDepth: Float = 0.5

    // MARK: - Private Properties

    private var tempo: Float = 120.0
    private var targetTempo: Float = 120.0
    private let tempoSmoothingFactor: Float = 0.95

    // Filter parameters
    private var filterResonance: Float = 0.7
    private var currentFilterCutoff: Float = 8000.0

    // MARK: - Public Methods

    func updateBiometrics(_ state: BiometricState) {
        self.currentState = state

        // Update audio parameters based on biometrics
        updateVolumeAutomation()
        updateTempoMatching()
        updateFilterSweep()
        updateEffectsDepth()
    }

    func applyToBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // Apply volume automation
        for ch in 0..<channelCount {
            let channel = channelData[ch]
            var volume = volumeAutomation
            vDSP_vsmul(channel, 1, &volume, channel, 1, vDSP_Length(frameLength))
        }

        // Apply breath-synced filter (simplified - production would use proper filter)
        applyBreathFilter(buffer: buffer)
    }

    func getCurrentTempo() -> Float {
        return tempo
    }

    // MARK: - Private Methods

    private func updateVolumeAutomation() {
        // Coherence affects overall volume
        // High coherence = fuller volume, low coherence = reduced volume
        volumeAutomation = 0.5 + (currentState.coherence * 0.5)
    }

    private func updateTempoMatching() {
        // Heart rate drives target tempo
        // Map 40-200 BPM heart rate to 60-180 BPM tempo
        let minHR: Float = 40
        let maxHR: Float = 200
        let minTempo: Float = 60
        let maxTempo: Float = 180

        let normalizedHR = (currentState.heartRate - minHR) / (maxHR - minHR)
        targetTempo = minTempo + normalizedHR * (maxTempo - minTempo)

        // Smooth tempo changes
        tempo = tempoSmoothingFactor * tempo + (1.0 - tempoSmoothingFactor) * targetTempo
    }

    private func updateFilterSweep() {
        // Breathing phase modulates filter cutoff
        // Inhale (0.0) = open filter, Exhale (1.0) = closed filter
        let minCutoff: Float = 200.0
        let maxCutoff: Float = 12000.0

        let breathModulation = 1.0 - currentState.breathPhase // Invert so inhale opens filter
        filterCutoff = minCutoff + breathModulation * (maxCutoff - minCutoff)

        // Smooth filter changes
        currentFilterCutoff = 0.9 * currentFilterCutoff + 0.1 * filterCutoff
    }

    private func updateEffectsDepth() {
        // HRV modulates effects depth
        // Higher HRV = more effects, lower HRV = dryer signal
        let normalizedHRV = min(currentState.hrv / 100.0, 1.0) // Normalize to 0-1
        effectsDepth = normalizedHRV

        // Map to reverb amount
        reverbAmount = 0.1 + effectsDepth * 0.6 // Range 0.1 to 0.7
    }

    private func applyBreathFilter(buffer: AVAudioPCMBuffer) {
        // Simplified one-pole lowpass filter
        // Production would use proper biquad filter
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        let sampleRate = Float(buffer.format.sampleRate)
        let cutoffNormalized = currentFilterCutoff / (sampleRate / 2.0)
        let alpha = min(cutoffNormalized, 0.99)

        for ch in 0..<channelCount {
            let channel = channelData[ch]
            var previousSample: Float = 0.0

            for i in 0..<frameLength {
                let filtered = alpha * channel[i] + (1.0 - alpha) * previousSample
                previousSample = filtered
                channel[i] = filtered
            }
        }
    }
}

// MARK: - Spatial Enhancements

/// Advanced spatial audio processing (Ambisonics, Dolby Atmos, HRTF)
class SpatialEnhancements {

    // MARK: - Spatial Modes

    enum SpatialMode {
        case stereo           // Standard stereo
        case binaural         // HRTF-based 3D
        case ambisonics1st    // First-order ambisonics (4 channels)
        case ambisonics3rd    // Third-order ambisonics (16 channels)
        case dolbyAtmos       // Object-based spatial audio
    }

    // MARK: - Audio Source

    struct AudioSource {
        var position: SIMD3<Float>    // X, Y, Z in meters
        var velocity: SIMD3<Float>    // For Doppler
        var directivity: Float        // 0 = omnidirectional, 1 = highly directional
        var width: Float              // Apparent source width
    }

    // MARK: - Room Characteristics

    struct RoomCharacteristics {
        var dimensions: SIMD3<Float>  // Width, height, depth in meters
        var absorption: Float         // 0 = reflective, 1 = anechoic
        var reverbTime: Float         // RT60 in seconds
    }

    // MARK: - Properties

    private var mode: SpatialMode = .binaural
    private var listenerPosition: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    private var listenerOrientation: SIMD3<Float> = SIMD3<Float>(0, 0, -1) // Looking forward
    private var sources: [AudioSource] = []
    private var room: RoomCharacteristics?

    // HRTF database (simplified - production would use full SOFA format)
    private var hrtfAzimuths: [Float] = []
    private var hrtfElevations: [Float] = []

    // Ambisonics encoding matrices
    private var ambisonicsEncoder: [[Float]] = []

    // MARK: - Initialization

    init() {
        setupHRTF()
        setupAmbisonics()
        log.audio("Spatial enhancements initialized")
    }

    // MARK: - Public Methods

    func setSpatialMode(_ mode: SpatialMode) {
        self.mode = mode
        log.audio("Spatial mode: \(mode)")
    }

    func setListenerPosition(_ position: SIMD3<Float>) {
        self.listenerPosition = position
    }

    func setListenerOrientation(_ forward: SIMD3<Float>) {
        self.listenerOrientation = normalize(forward)
    }

    func addSource(_ source: AudioSource) {
        sources.append(source)
    }

    func setRoom(_ room: RoomCharacteristics) {
        self.room = room
    }

    func spatializeBuffer(_ buffer: AVAudioPCMBuffer, sourceIndex: Int) {
        guard sourceIndex < sources.count else { return }
        let source = sources[sourceIndex]

        switch mode {
        case .stereo:
            applyStereoPositioning(buffer: buffer, source: source)
        case .binaural:
            applyBinauralProcessing(buffer: buffer, source: source)
        case .ambisonics1st, .ambisonics3rd:
            applyAmbisonicsEncoding(buffer: buffer, source: source)
        case .dolbyAtmos:
            applyObjectBasedAudio(buffer: buffer, source: source)
        }

        // Apply distance-based filtering
        applyDistanceFiltering(buffer: buffer, source: source)
    }

    // MARK: - Private Methods

    private func setupHRTF() {
        // Simplified HRTF setup
        // Production would load full CIPIC or MIT KEMAR database
        for azimuth in stride(from: Float(-180), to: Float(180), by: 5.0) {
            hrtfAzimuths.append(azimuth)
        }
        for elevation in stride(from: Float(-90), to: Float(90), by: 5.0) {
            hrtfElevations.append(elevation)
        }
    }

    private func setupAmbisonics() {
        // First-order ambisonics encoding (W, X, Y, Z)
        ambisonicsEncoder = [
            [1.0, 0.0, 0.0, 0.0],  // W (omnidirectional)
            [0.0, 1.0, 0.0, 0.0],  // X (front-back)
            [0.0, 0.0, 1.0, 0.0],  // Y (left-right)
            [0.0, 0.0, 0.0, 1.0]   // Z (up-down)
        ]
    }

    private func applyStereoPositioning(buffer: AVAudioPCMBuffer, source: AudioSource) {
        guard let channelData = buffer.floatChannelData else { return }
        guard buffer.format.channelCount >= 2 else { return }

        let frameLength = Int(buffer.frameLength)
        let leftChannel = channelData[0]
        let rightChannel = channelData[1]

        // Calculate pan based on X position
        let relativePos = source.position - listenerPosition
        let angle = atan2(relativePos.x, -relativePos.z) // Angle from forward

        // Constant power panning
        let pan = (angle / .pi + 1.0) / 2.0 // Normalize to 0-1
        let leftGain = cos(pan * .pi / 2.0)
        let rightGain = sin(pan * .pi / 2.0)

        var leftGainFloat = Float(leftGain)
        var rightGainFloat = Float(rightGain)

        vDSP_vsmul(leftChannel, 1, &leftGainFloat, leftChannel, 1, vDSP_Length(frameLength))
        vDSP_vsmul(rightChannel, 1, &rightGainFloat, rightChannel, 1, vDSP_Length(frameLength))
    }

    private func applyBinauralProcessing(buffer: AVAudioPCMBuffer, source: AudioSource) {
        // Simplified binaural processing
        // Production would convolve with full HRTF impulse responses

        let relativePos = source.position - listenerPosition
        let distance = length(relativePos)

        if distance > 0 {
            let direction = normalize(relativePos)

            // Calculate azimuth and elevation
            let azimuth = atan2(direction.x, -direction.z) * 180.0 / .pi
            let elevation = asin(direction.y) * 180.0 / .pi

            // Apply simplified ITD and ILD
            let maxITD: Float = 0.0007 // seconds
            let itd = sin(azimuth * .pi / 180.0) * maxITD

            // Interaural Level Difference
            let ild = abs(sin(azimuth * .pi / 180.0)) * 6.0 // dB

            // Apply to buffer (simplified - would need delay line for ITD)
            applyStereoPositioning(buffer: buffer, source: source)
        }
    }

    private func applyAmbisonicsEncoding(buffer: AVAudioPCMBuffer, source: AudioSource) {
        // Encode mono source to ambisonics
        let relativePos = source.position - listenerPosition
        let direction = normalize(relativePos)

        // First-order ambisonics coefficients
        let w: Float = 1.0 / sqrt(2.0)  // Omnidirectional
        let x = direction.z             // Front-back (reversed Z)
        let y = direction.x             // Left-right
        let z = direction.y             // Up-down

        // These would be applied to create 4-channel ambisonics output
        // For now, we'll just apply stereo positioning
        applyStereoPositioning(buffer: buffer, source: source)

        log.audio("Ambisonics encoding: W=\(w), X=\(x), Y=\(y), Z=\(z)")
    }

    private func applyObjectBasedAudio(buffer: AVAudioPCMBuffer, source: AudioSource) {
        // Object-based audio (Dolby Atmos style)
        // Each source has metadata about position, width, directivity
        // Renderer decides how to map to speaker layout

        // For now, use binaural rendering
        applyBinauralProcessing(buffer: buffer, source: source)
    }

    private func applyDistanceFiltering(buffer: AVAudioPCMBuffer, source: AudioSource) {
        // Apply distance-based attenuation and filtering
        let distance = length(source.position - listenerPosition)

        // Inverse square law attenuation
        let referenceDistance: Float = 1.0
        let attenuation = referenceDistance / max(distance, 0.1)

        // Air absorption (high frequencies attenuate more with distance)
        // Simplified: just apply lowpass filter for distant sources
        if distance > 10.0 {
            // Would apply actual lowpass filter here
            // For now just attenuate
            guard let channelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)

            var gain = attenuation
            for ch in 0..<channelCount {
                vDSP_vsmul(channelData[ch], 1, &gain, channelData[ch], 1, vDSP_Length(frameLength))
            }
        }
    }
}

// MARK: - Audio Analysis Engine

/// Comprehensive audio analysis (BPM, key, chord detection)
class AudioAnalysisEngine {

    // MARK: - Analysis Results

    struct AnalysisResult {
        var bpm: Float?
        var key: String?
        var chords: [Chord]
        var beatGrid: [TimeInterval]
        var transients: [TimeInterval]
        var energy: Float
    }

    struct Chord {
        var timestamp: TimeInterval
        var root: String        // C, C#, D, etc.
        var quality: String     // major, minor, dim, aug, etc.
        var confidence: Float
    }

    // MARK: - Properties

    private let spectralAnalyzer: SpectralAnalyzer
    private var sampleRate: Float

    // BPM detection
    private var onsetTimes: [TimeInterval] = []
    private var beatHistory: [TimeInterval] = []

    // Key detection
    private let chromaNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private var chromaProfile = [Float](repeating: 0, count: 12)

    // Chord templates (simplified)
    private let majorTemplate: [Float] = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0]
    private let minorTemplate: [Float] = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0]

    // MARK: - Initialization

    init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        self.spectralAnalyzer = SpectralAnalyzer(sampleRate: sampleRate)
        log.audio("Audio analysis engine initialized")
    }

    // MARK: - Public Methods

    func analyze(buffer: AVAudioPCMBuffer, timestamp: TimeInterval) -> AnalysisResult {
        // Spectral analysis
        let spectralData = spectralAnalyzer.analyze(buffer: buffer)

        // Detect transients/onsets
        if spectralData.spectralFlux > 0.1 { // Threshold for onset
            onsetTimes.append(timestamp)
        }

        // BPM detection
        let bpm = detectBPM()

        // Key detection
        let key = detectKey(spectralData: spectralData)

        // Chord detection
        let chord = detectChord(spectralData: spectralData, timestamp: timestamp)

        // Energy calculation
        let energy = spectralData.spectrum.reduce(0, +) / Float(spectralData.spectrum.count)

        return AnalysisResult(
            bpm: bpm,
            key: key,
            chords: chord.map { [$0] } ?? [],
            beatGrid: beatHistory,
            transients: onsetTimes,
            energy: energy
        )
    }

    // MARK: - Private Methods

    private func detectBPM() -> Float? {
        guard onsetTimes.count > 4 else { return nil }

        // Calculate inter-onset intervals
        var intervals: [TimeInterval] = []
        for i in 1..<onsetTimes.count {
            let interval = onsetTimes[i] - onsetTimes[i - 1]
            if interval > 0.2 && interval < 2.0 { // Filter unreasonable intervals
                intervals.append(interval)
            }
        }

        guard !intervals.isEmpty else { return nil }

        // Find most common interval (simplified - would use autocorrelation in production)
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let bpm = Float(60.0 / avgInterval)

        // BPM should be in reasonable range
        if bpm >= 60 && bpm <= 200 {
            return bpm
        }

        return nil
    }

    private func detectKey(spectralData: SpectralAnalyzer.SpectralData) -> String? {
        // Update chroma profile from spectrum
        updateChromaProfile(spectralData: spectralData)

        // Compare with major/minor key profiles
        var bestKey: String?
        var bestScore: Float = 0

        for root in 0..<12 {
            // Major key
            let majorScore = correlateWithKeyProfile(root: root, isMajor: true)
            if majorScore > bestScore {
                bestScore = majorScore
                bestKey = "\(chromaNames[root]) Major"
            }

            // Minor key
            let minorScore = correlateWithKeyProfile(root: root, isMajor: false)
            if minorScore > bestScore {
                bestScore = minorScore
                bestKey = "\(chromaNames[root]) Minor"
            }
        }

        return bestKey
    }

    private func detectChord(spectralData: SpectralAnalyzer.SpectralData, timestamp: TimeInterval) -> Chord? {
        // Update chroma from spectrum
        updateChromaProfile(spectralData: spectralData)

        var bestChord: Chord?
        var bestScore: Float = 0

        // Try each root note
        for root in 0..<12 {
            // Major chord
            let majorScore = correlateWithChordTemplate(root: root, template: majorTemplate)
            if majorScore > bestScore {
                bestScore = majorScore
                bestChord = Chord(
                    timestamp: timestamp,
                    root: chromaNames[root],
                    quality: "major",
                    confidence: majorScore
                )
            }

            // Minor chord
            let minorScore = correlateWithChordTemplate(root: root, template: minorTemplate)
            if minorScore > bestScore {
                bestScore = minorScore
                bestChord = Chord(
                    timestamp: timestamp,
                    root: chromaNames[root],
                    quality: "minor",
                    confidence: minorScore
                )
            }
        }

        return bestChord
    }

    private func updateChromaProfile(spectralData: SpectralAnalyzer.SpectralData) {
        // Reset chroma
        chromaProfile = [Float](repeating: 0, count: 12)

        // Map frequencies to chroma bins
        for (idx, freq) in spectralData.frequencies.enumerated() {
            guard freq > 0 && idx < spectralData.spectrum.count else { continue }

            // Convert frequency to MIDI note
            let midiNote = 12.0 * log2(freq / 440.0) + 69.0
            let chromaBin = Int(midiNote) % 12

            if chromaBin >= 0 && chromaBin < 12 {
                chromaProfile[chromaBin] += spectralData.spectrum[idx]
            }
        }

        // Normalize
        let sum = chromaProfile.reduce(0, +)
        if sum > 0 {
            chromaProfile = chromaProfile.map { $0 / sum }
        }
    }

    private func correlateWithKeyProfile(root: Int, isMajor: Bool) -> Float {
        // Simplified key profiles (Krumhansl-Schmuckler)
        let majorProfile: [Float] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
        let minorProfile: [Float] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

        let profile = isMajor ? majorProfile : minorProfile
        var correlation: Float = 0

        for i in 0..<12 {
            let chromaIdx = (i + root) % 12
            correlation += chromaProfile[chromaIdx] * profile[i]
        }

        return correlation
    }

    private func correlateWithChordTemplate(root: Int, template: [Float]) -> Float {
        var correlation: Float = 0

        for i in 0..<12 {
            let chromaIdx = (i + root) % 12
            correlation += chromaProfile[chromaIdx] * template[i]
        }

        return correlation
    }
}

// MARK: - Voice Processor

/// Advanced voice processing (pitch correction, formant preservation, breath removal)
class VoiceProcessor {

    // MARK: - Processing Parameters

    struct ProcessingParams {
        var pitchCorrectionAmount: Float = 0.5  // 0 = none, 1 = full
        var pitchCorrectionSpeed: Float = 0.1   // 0 = slow, 1 = instant
        var formantPreservation: Bool = true
        var breathReduction: Float = 0.5        // 0 = none, 1 = full
        var deEsserAmount: Float = 0.3          // 0 = none, 1 = aggressive
        var enhancement: Float = 0.2            // Overall clarity boost
    }

    // MARK: - Properties

    private var params = ProcessingParams()
    private let spectralAnalyzer: SpectralAnalyzer

    // Pitch correction
    private var targetPitch: Float = 0.0
    private var currentPitch: Float = 0.0

    // De-esser
    private let sibilanceFreqMin: Float = 4000.0
    private let sibilanceFreqMax: Float = 10000.0

    // MARK: - Initialization

    init(sampleRate: Float = 48000.0) {
        self.spectralAnalyzer = SpectralAnalyzer(sampleRate: sampleRate)
        log.audio("Voice processor initialized")
    }

    // MARK: - Public Methods

    func setParameters(_ params: ProcessingParams) {
        self.params = params
    }

    func process(buffer: AVAudioPCMBuffer) {
        // Apply voice processing chain
        if params.breathReduction > 0 {
            reduceBreath(buffer: buffer)
        }

        if params.pitchCorrectionAmount > 0 {
            applyPitchCorrection(buffer: buffer)
        }

        if params.deEsserAmount > 0 {
            applyDeEsser(buffer: buffer)
        }

        if params.enhancement > 0 {
            enhanceVoice(buffer: buffer)
        }
    }

    // MARK: - Private Methods

    private func reduceBreath(buffer: AVAudioPCMBuffer) {
        // Breath sounds are typically low-frequency, broadband noise
        // Detect and attenuate

        let spectralData = spectralAnalyzer.analyze(buffer: buffer)

        // Calculate spectral flatness (noise-like content)
        let flatness = calculateSpectralFlatness(spectrum: spectralData.spectrum)

        // If signal is noise-like (breath), attenuate
        if flatness > 0.5 { // Threshold for breath detection
            guard let channelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)

            var attenuation = 1.0 - params.breathReduction
            for ch in 0..<channelCount {
                vDSP_vsmul(channelData[ch], 1, &attenuation, channelData[ch], 1, vDSP_Length(frameLength))
            }
        }
    }

    private func applyPitchCorrection(buffer: AVAudioPCMBuffer) {
        // Simplified pitch correction
        // Production would use phase vocoder or granular synthesis

        let spectralData = spectralAnalyzer.analyze(buffer: buffer)
        currentPitch = spectralData.dominantFrequency

        // Snap to nearest musical note if correction amount is high
        if params.pitchCorrectionAmount > 0.5 {
            targetPitch = snapToNearestNote(currentPitch)
        } else {
            targetPitch = currentPitch
        }

        // Would apply pitch shift here
        // Requires phase vocoder implementation
        log.audio("Pitch: \(currentPitch)Hz → \(targetPitch)Hz")
    }

    private func applyDeEsser(buffer: AVAudioPCMBuffer) {
        // Detect and reduce sibilance (harsh "s" sounds)

        let spectralData = spectralAnalyzer.analyze(buffer: buffer)

        // Calculate energy in sibilance frequency range
        var sibilanceEnergy: Float = 0
        var totalEnergy: Float = 0

        for (idx, freq) in spectralData.frequencies.enumerated() {
            if idx < spectralData.spectrum.count {
                totalEnergy += spectralData.spectrum[idx]
                if freq >= sibilanceFreqMin && freq <= sibilanceFreqMax {
                    sibilanceEnergy += spectralData.spectrum[idx]
                }
            }
        }

        // If high sibilance, apply reduction
        if totalEnergy > 0 && (sibilanceEnergy / totalEnergy) > 0.3 {
            // Attenuate sibilance band
            spectralAnalyzer.isolateBand(
                buffer: buffer,
                lowFreq: sibilanceFreqMin,
                highFreq: sibilanceFreqMax
            )

            // Apply attenuation
            guard let channelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)

            var attenuation = 1.0 - params.deEsserAmount * 0.5
            for ch in 0..<channelCount {
                vDSP_vsmul(channelData[ch], 1, &attenuation, channelData[ch], 1, vDSP_Length(frameLength))
            }
        }
    }

    private func enhanceVoice(buffer: AVAudioPCMBuffer) {
        // Enhance clarity by boosting formant regions (2-4 kHz)
        // Simplified - would use proper EQ in production

        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        var boost = 1.0 + params.enhancement * 0.3
        for ch in 0..<channelCount {
            vDSP_vsmul(channelData[ch], 1, &boost, channelData[ch], 1, vDSP_Length(frameLength))
        }
    }

    private func calculateSpectralFlatness(spectrum: [Float]) -> Float {
        // Spectral flatness = geometric mean / arithmetic mean
        // High flatness = noise-like, low flatness = tonal

        guard !spectrum.isEmpty else { return 0 }

        // Geometric mean (using log)
        var logSum: Float = 0
        var count = 0
        for mag in spectrum where mag > 0 {
            logSum += Darwin.log(mag)
            count += 1
        }
        let geometricMean = exp(logSum / Float(count))

        // Arithmetic mean
        let arithmeticMean = spectrum.reduce(0, +) / Float(spectrum.count)

        return arithmeticMean > 0 ? geometricMean / arithmeticMean : 0
    }

    private func snapToNearestNote(_ frequency: Float) -> Float {
        // Convert to MIDI note number
        let midiNote = 12.0 * log2(frequency / 440.0) + 69.0

        // Round to nearest semitone
        let roundedNote = round(midiNote)

        // Convert back to frequency
        return 440.0 * pow(2.0, (roundedNote - 69.0) / 12.0)
    }
}

// MARK: - Utility Extensions

extension SIMD3 where Scalar == Float {
    var length: Float {
        return sqrt(x * x + y * y + z * z)
    }
}

func length(_ vector: SIMD3<Float>) -> Float {
    return vector.length
}

func normalize(_ vector: SIMD3<Float>) -> SIMD3<Float> {
    let len = vector.length
    return len > 0 ? SIMD3<Float>(vector.x / len, vector.y / len, vector.z / len) : vector
}

import Foundation
import Accelerate

// MARK: - Spectral Synthesizer
// FFT-based spectral processing and resynthesis
// Based on: Phase Vocoder techniques (Dolson, 1986)

/// SpectralSynthesizer: FFT-based spectral manipulation and resynthesis
/// Implements phase vocoder analysis/synthesis with spectral processing
///
/// Features:
/// - Real-time FFT analysis and resynthesis
/// - Time stretching without pitch change
/// - Pitch shifting without time change
/// - Spectral freeze and morphing
/// - Spectral filtering and effects
/// - Cross-synthesis between sources
/// - Robotization and whisperization
public final class SpectralSynthesizer {

    // MARK: - Types

    /// FFT sizes supported
    public enum FFTSize: Int, CaseIterable {
        case fft256 = 256
        case fft512 = 512
        case fft1024 = 1024
        case fft2048 = 2048
        case fft4096 = 4096
        case fft8192 = 8192

        var log2n: vDSP_Length {
            vDSP_Length(log2(Double(rawValue)))
        }
    }

    /// Spectral processing modes
    public enum SpectralMode: Int, CaseIterable {
        case passthrough       // No processing
        case timeStretch       // Time stretch
        case pitchShift        // Pitch shift
        case robotize          // Zero phases (robotic)
        case whisperize        // Random phases (breathy)
        case freeze            // Spectral freeze
        case spectralGate      // Spectral noise gate
        case spectralFilter    // Parametric spectral EQ
        case crossSynthesis    // Cross-synthesis
        case spectralDelay     // Frequency-dependent delay
        case formantShift      // Shift formants
        case harmonizer        // Add harmonies

        var displayName: String {
            switch self {
            case .passthrough: return "Passthrough"
            case .timeStretch: return "Time Stretch"
            case .pitchShift: return "Pitch Shift"
            case .robotize: return "Robotize"
            case .whisperize: return "Whisperize"
            case .freeze: return "Spectral Freeze"
            case .spectralGate: return "Spectral Gate"
            case .spectralFilter: return "Spectral Filter"
            case .crossSynthesis: return "Cross Synthesis"
            case .spectralDelay: return "Spectral Delay"
            case .formantShift: return "Formant Shift"
            case .harmonizer: return "Harmonizer"
            }
        }
    }

    /// Window types for FFT
    public enum WindowType: Int, CaseIterable {
        case hanning
        case hamming
        case blackman
        case blackmanHarris
        case kaiser
        case rectangular

        func generate(size: Int) -> [Float] {
            var window = [Float](repeating: 0, count: size)
            let n = Float(size)

            switch self {
            case .hanning:
                vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM))

            case .hamming:
                vDSP_hamm_window(&window, vDSP_Length(size), 0)

            case .blackman:
                vDSP_blkman_window(&window, vDSP_Length(size), 0)

            case .blackmanHarris:
                for i in 0..<size {
                    let x = Float(i) / n
                    window[i] = 0.35875 - 0.48829 * cos(2 * .pi * x)
                                + 0.14128 * cos(4 * .pi * x)
                                - 0.01168 * cos(6 * .pi * x)
                }

            case .kaiser:
                // Kaiser window with beta = 9
                let beta: Float = 9
                let halfN = n / 2
                for i in 0..<size {
                    let x = (Float(i) - halfN) / halfN
                    let arg = beta * sqrt(1 - x * x)
                    window[i] = besselI0(arg) / besselI0(beta)
                }

            case .rectangular:
                for i in 0..<size { window[i] = 1 }
            }

            return window
        }

        /// Bessel function I0 approximation for Kaiser window
        private func besselI0(_ x: Float) -> Float {
            var sum: Float = 1
            var term: Float = 1
            let halfX = x / 2

            for k in 1...20 {
                term *= (halfX / Float(k)) * (halfX / Float(k))
                sum += term
                if term < 1e-10 { break }
            }

            return sum
        }
    }

    /// Spectral frame for processing
    public struct SpectralFrame {
        var magnitudes: [Float]
        var phases: [Float]
        var frequencies: [Float]  // Instantaneous frequencies

        init(size: Int) {
            magnitudes = [Float](repeating: 0, count: size / 2 + 1)
            phases = [Float](repeating: 0, count: size / 2 + 1)
            frequencies = [Float](repeating: 0, count: size / 2 + 1)
        }
    }

    // MARK: - Properties

    /// Sample rate
    private var sampleRate: Float = 44100

    /// FFT size
    public var fftSize: FFTSize = .fft2048 {
        didSet { setupFFT() }
    }

    /// Overlap factor (1 = no overlap, 4 = 75% overlap typical)
    public var overlapFactor: Int = 4

    /// Window type
    public var windowType: WindowType = .hanning {
        didSet { window = windowType.generate(size: fftSize.rawValue) }
    }

    /// Current processing mode
    public var mode: SpectralMode = .passthrough

    /// Time stretch factor (1.0 = normal, 2.0 = double length)
    public var timeStretch: Float = 1.0

    /// Pitch shift in semitones
    public var pitchShift: Float = 0

    /// Spectral freeze enabled
    public var freezeEnabled: Bool = false

    /// Spectral gate threshold (0-1)
    public var gateThreshold: Float = 0.1

    /// Cross-synthesis mix (0 = source A, 1 = source B magnitudes with A phases)
    public var crossSynthesisMix: Float = 0.5

    /// Formant shift in semitones
    public var formantShift: Float = 0

    /// Harmonizer intervals (semitones)
    public var harmonizerIntervals: [Float] = [0, 7, 12]

    /// Global volume
    public var volume: Float = 0.8

    // FFT setup
    private var fftSetup: vDSP_DFT_Setup?
    private var fftSetupInverse: vDSP_DFT_Setup?

    // Processing buffers
    private var window: [Float] = []
    private var inputBuffer: [Float] = []
    private var outputBuffer: [Float] = []
    private var overlapAddBuffer: [Float] = []

    // Analysis/synthesis
    private var analysisFrame = SpectralFrame(size: 2048)
    private var synthesisFrame = SpectralFrame(size: 2048)
    private var previousPhases: [Float] = []
    private var phaseCumulative: [Float] = []

    // Freeze buffer
    private var frozenFrame = SpectralFrame(size: 2048)

    // Cross-synthesis source
    private var crossSynthesisFrame = SpectralFrame(size: 2048)

    // Read/write positions
    private var inputWritePos: Int = 0
    private var outputReadPos: Int = 0
    private var hopCounter: Int = 0

    // FFT real/imaginary buffers
    private var realBuffer: [Float] = []
    private var imagBuffer: [Float] = []

    // MARK: - Initialization

    public init(sampleRate: Float = 44100, fftSize: FFTSize = .fft2048) {
        self.sampleRate = sampleRate
        self.fftSize = fftSize
        setupFFT()
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_Destroy(setup)
        }
        if let setup = fftSetupInverse {
            vDSP_DFT_Destroy(setup)
        }
    }

    /// Setup FFT structures
    private func setupFFT() {
        let size = fftSize.rawValue

        // Destroy old setups
        if let setup = fftSetup {
            vDSP_DFT_Destroy(setup)
        }
        if let setup = fftSetupInverse {
            vDSP_DFT_Destroy(setup)
        }

        // Create new FFT setups
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(size),
            .FORWARD
        )

        fftSetupInverse = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(size),
            .INVERSE
        )

        // Initialize buffers
        window = windowType.generate(size: size)
        inputBuffer = [Float](repeating: 0, count: size * 2)
        outputBuffer = [Float](repeating: 0, count: size * 2)
        overlapAddBuffer = [Float](repeating: 0, count: size * 2)

        analysisFrame = SpectralFrame(size: size)
        synthesisFrame = SpectralFrame(size: size)
        frozenFrame = SpectralFrame(size: size)
        crossSynthesisFrame = SpectralFrame(size: size)

        previousPhases = [Float](repeating: 0, count: size / 2 + 1)
        phaseCumulative = [Float](repeating: 0, count: size / 2 + 1)

        realBuffer = [Float](repeating: 0, count: size)
        imagBuffer = [Float](repeating: 0, count: size)

        inputWritePos = 0
        outputReadPos = 0
        hopCounter = 0
    }

    // MARK: - Audio Processing

    /// Process audio buffer
    public func process(
        input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        let size = fftSize.rawValue
        let hopSize = size / overlapFactor

        for i in 0..<frameCount {
            // Write input to circular buffer
            inputBuffer[inputWritePos] = input[i]
            inputWritePos = (inputWritePos + 1) % inputBuffer.count

            // Check if we have enough samples for FFT
            hopCounter += 1
            if hopCounter >= hopSize {
                hopCounter = 0

                // Perform analysis
                performAnalysis()

                // Process spectrum
                processSpectrum()

                // Perform synthesis
                performSynthesis()

                // Overlap-add to output
                overlapAdd()
            }

            // Read from overlap-add buffer
            output[i] = overlapAddBuffer[outputReadPos] * volume
            overlapAddBuffer[outputReadPos] = 0  // Clear for next overlap
            outputReadPos = (outputReadPos + 1) % overlapAddBuffer.count
        }
    }

    /// Perform FFT analysis
    private func performAnalysis() {
        let size = fftSize.rawValue

        // Extract windowed frame from input buffer
        var frame = [Float](repeating: 0, count: size)
        for i in 0..<size {
            let bufferIndex = (inputWritePos - size + i + inputBuffer.count) % inputBuffer.count
            frame[i] = inputBuffer[bufferIndex] * window[i]
        }

        // Perform FFT
        guard let setup = fftSetup else { return }

        var realIn = frame
        var imagIn = [Float](repeating: 0, count: size)

        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realBuffer, &imagBuffer)

        // Convert to magnitude/phase
        let binCount = size / 2 + 1
        for bin in 0..<binCount {
            let real = realBuffer[bin]
            let imag = imagBuffer[bin]

            analysisFrame.magnitudes[bin] = sqrt(real * real + imag * imag)
            analysisFrame.phases[bin] = atan2(imag, real)

            // Calculate instantaneous frequency (phase vocoder)
            let phaseDiff = analysisFrame.phases[bin] - previousPhases[bin]
            previousPhases[bin] = analysisFrame.phases[bin]

            // Unwrap phase difference
            var unwrappedDiff = phaseDiff
            while unwrappedDiff > .pi { unwrappedDiff -= 2 * .pi }
            while unwrappedDiff < -.pi { unwrappedDiff += 2 * .pi }

            // Expected phase increment for this bin
            let expectedPhaseInc = 2 * .pi * Float(bin) / Float(overlapFactor)
            let deviation = unwrappedDiff - expectedPhaseInc

            // Instantaneous frequency
            let binFreq = Float(bin) * sampleRate / Float(size)
            let freqDeviation = deviation * sampleRate / (2 * .pi * Float(size / overlapFactor))
            analysisFrame.frequencies[bin] = binFreq + freqDeviation
        }
    }

    /// Process spectrum based on current mode
    private func processSpectrum() {
        switch mode {
        case .passthrough:
            synthesisFrame = analysisFrame

        case .timeStretch:
            processTimeStretch()

        case .pitchShift:
            processPitchShift()

        case .robotize:
            processRobotize()

        case .whisperize:
            processWhisperize()

        case .freeze:
            processFreeze()

        case .spectralGate:
            processSpectralGate()

        case .spectralFilter:
            processSpectralFilter()

        case .crossSynthesis:
            processCrossSynthesis()

        case .spectralDelay:
            processSpectralDelay()

        case .formantShift:
            processFormantShift()

        case .harmonizer:
            processHarmonizer()
        }
    }

    /// Time stretch processing
    private func processTimeStretch() {
        let binCount = analysisFrame.magnitudes.count

        synthesisFrame.magnitudes = analysisFrame.magnitudes

        // Scale phase increments for time stretch
        for bin in 0..<binCount {
            let phaseInc = (analysisFrame.frequencies[bin] / sampleRate) * 2 * .pi * Float(fftSize.rawValue / overlapFactor)
            phaseCumulative[bin] += phaseInc / timeStretch
            synthesisFrame.phases[bin] = phaseCumulative[bin]
            synthesisFrame.frequencies[bin] = analysisFrame.frequencies[bin]
        }
    }

    /// Pitch shift processing
    private func processPitchShift() {
        let binCount = analysisFrame.magnitudes.count
        let shiftRatio = pow(2.0, pitchShift / 12.0)

        // Clear synthesis frame
        synthesisFrame.magnitudes = [Float](repeating: 0, count: binCount)
        synthesisFrame.phases = [Float](repeating: 0, count: binCount)
        synthesisFrame.frequencies = [Float](repeating: 0, count: binCount)

        // Shift bins
        for bin in 0..<binCount {
            let newBin = Int(Float(bin) * shiftRatio)
            guard newBin >= 0 && newBin < binCount else { continue }

            synthesisFrame.magnitudes[newBin] += analysisFrame.magnitudes[bin]
            synthesisFrame.frequencies[newBin] = analysisFrame.frequencies[bin] * shiftRatio

            // Accumulate phase
            let phaseInc = (synthesisFrame.frequencies[newBin] / sampleRate) * 2 * .pi * Float(fftSize.rawValue / overlapFactor)
            phaseCumulative[newBin] += phaseInc
            synthesisFrame.phases[newBin] = phaseCumulative[newBin]
        }
    }

    /// Robotize (zero all phases)
    private func processRobotize() {
        synthesisFrame.magnitudes = analysisFrame.magnitudes
        synthesisFrame.phases = [Float](repeating: 0, count: analysisFrame.phases.count)
        synthesisFrame.frequencies = analysisFrame.frequencies
    }

    /// Whisperize (random phases)
    private func processWhisperize() {
        synthesisFrame.magnitudes = analysisFrame.magnitudes
        synthesisFrame.phases = analysisFrame.phases.map { _ in Float.random(in: 0...(2 * .pi)) }
        synthesisFrame.frequencies = analysisFrame.frequencies
    }

    /// Spectral freeze
    private func processFreeze() {
        if freezeEnabled {
            synthesisFrame = frozenFrame
        } else {
            frozenFrame = analysisFrame
            synthesisFrame = analysisFrame
        }
    }

    /// Spectral gate
    private func processSpectralGate() {
        let binCount = analysisFrame.magnitudes.count
        let maxMag = analysisFrame.magnitudes.max() ?? 1

        synthesisFrame.phases = analysisFrame.phases
        synthesisFrame.frequencies = analysisFrame.frequencies

        for bin in 0..<binCount {
            let normalizedMag = analysisFrame.magnitudes[bin] / maxMag
            synthesisFrame.magnitudes[bin] = normalizedMag > gateThreshold ? analysisFrame.magnitudes[bin] : 0
        }
    }

    /// Spectral filtering (simple parametric EQ)
    private func processSpectralFilter() {
        let binCount = analysisFrame.magnitudes.count

        synthesisFrame.phases = analysisFrame.phases
        synthesisFrame.frequencies = analysisFrame.frequencies

        for bin in 0..<binCount {
            let freq = Float(bin) * sampleRate / Float(fftSize.rawValue)

            // Apply spectral tilt (simple high/low shelf)
            var gain: Float = 1.0

            // Low shelf at 200 Hz
            if freq < 200 {
                gain *= 1.0 + 0.3  // Boost lows
            }

            // High shelf at 5000 Hz
            if freq > 5000 {
                gain *= 1.0 - 0.2  // Cut highs
            }

            synthesisFrame.magnitudes[bin] = analysisFrame.magnitudes[bin] * gain
        }
    }

    /// Cross-synthesis
    private func processCrossSynthesis() {
        let binCount = analysisFrame.magnitudes.count

        // Mix magnitudes, keep analysis phases
        for bin in 0..<binCount {
            let magA = analysisFrame.magnitudes[bin]
            let magB = crossSynthesisFrame.magnitudes[bin]

            synthesisFrame.magnitudes[bin] = magA * (1 - crossSynthesisMix) + magB * crossSynthesisMix
            synthesisFrame.phases[bin] = analysisFrame.phases[bin]
            synthesisFrame.frequencies[bin] = analysisFrame.frequencies[bin]
        }
    }

    /// Spectral delay (frequency-dependent delay)
    private func processSpectralDelay() {
        // This is a simplified version - full implementation would need
        // multiple previous frames
        synthesisFrame = analysisFrame

        // Apply phase rotation based on frequency (simulates delay)
        let binCount = analysisFrame.magnitudes.count
        for bin in 0..<binCount {
            let freq = Float(bin) * sampleRate / Float(fftSize.rawValue)
            let delayTime = 0.001 * (freq / 1000)  // More delay for higher frequencies
            let phaseShift = 2 * .pi * freq * delayTime
            synthesisFrame.phases[bin] = analysisFrame.phases[bin] - phaseShift
        }
    }

    /// Formant shift
    private func processFormantShift() {
        let binCount = analysisFrame.magnitudes.count
        let shiftRatio = pow(2.0, formantShift / 12.0)

        // Clear synthesis frame
        synthesisFrame.magnitudes = [Float](repeating: 0, count: binCount)

        // Shift spectral envelope
        for bin in 0..<binCount {
            let newBin = Int(Float(bin) * shiftRatio)
            guard newBin >= 0 && newBin < binCount else { continue }
            synthesisFrame.magnitudes[newBin] += analysisFrame.magnitudes[bin]
        }

        synthesisFrame.phases = analysisFrame.phases
        synthesisFrame.frequencies = analysisFrame.frequencies
    }

    /// Harmonizer
    private func processHarmonizer() {
        let binCount = analysisFrame.magnitudes.count

        // Start with original
        synthesisFrame = analysisFrame

        // Add shifted versions
        for interval in harmonizerIntervals where interval != 0 {
            let shiftRatio = pow(2.0, interval / 12.0)

            for bin in 0..<binCount {
                let newBin = Int(Float(bin) * shiftRatio)
                guard newBin >= 0 && newBin < binCount else { continue }

                // Add to existing with reduced amplitude
                synthesisFrame.magnitudes[newBin] += analysisFrame.magnitudes[bin] * 0.5
            }
        }
    }

    /// Perform inverse FFT synthesis
    private func performSynthesis() {
        let size = fftSize.rawValue
        let binCount = size / 2 + 1

        // Convert magnitude/phase back to real/imaginary
        for bin in 0..<binCount {
            let mag = synthesisFrame.magnitudes[bin]
            let phase = synthesisFrame.phases[bin]

            realBuffer[bin] = mag * cos(phase)
            imagBuffer[bin] = mag * sin(phase)

            // Mirror for negative frequencies (conjugate symmetry)
            if bin > 0 && bin < binCount - 1 {
                realBuffer[size - bin] = realBuffer[bin]
                imagBuffer[size - bin] = -imagBuffer[bin]
            }
        }

        // Perform inverse FFT
        guard let setup = fftSetupInverse else { return }

        var realOut = [Float](repeating: 0, count: size)
        var imagOut = [Float](repeating: 0, count: size)

        vDSP_DFT_Execute(setup, &realBuffer, &imagBuffer, &realOut, &imagOut)

        // Scale and window
        var scale = 1.0 / Float(size)
        vDSP_vsmul(&realOut, 1, &scale, &realOut, 1, vDSP_Length(size))

        // Apply window
        vDSP_vmul(&realOut, 1, &window, 1, &realOut, 1, vDSP_Length(size))

        // Copy to output buffer
        for i in 0..<size {
            let outIndex = (outputReadPos + i) % outputBuffer.count
            outputBuffer[outIndex] = realOut[i]
        }
    }

    /// Overlap-add to output
    private func overlapAdd() {
        let size = fftSize.rawValue

        // Add to overlap buffer with proper normalization
        let normalization = 1.0 / Float(overlapFactor)

        for i in 0..<size {
            let outIndex = (outputReadPos + i) % overlapAddBuffer.count
            let bufIndex = (outputReadPos + i) % outputBuffer.count
            overlapAddBuffer[outIndex] += outputBuffer[bufIndex] * normalization
        }
    }

    // MARK: - Cross-Synthesis Source

    /// Set cross-synthesis source from buffer
    public func setCrossSynthesisSource(_ buffer: [Float]) {
        // Perform FFT on cross-synthesis source
        let size = min(buffer.count, fftSize.rawValue)
        var frame = [Float](repeating: 0, count: fftSize.rawValue)

        for i in 0..<size {
            frame[i] = buffer[i] * window[i % window.count]
        }

        guard let setup = fftSetup else { return }

        var realIn = frame
        var imagIn = [Float](repeating: 0, count: fftSize.rawValue)
        var realOut = [Float](repeating: 0, count: fftSize.rawValue)
        var imagOut = [Float](repeating: 0, count: fftSize.rawValue)

        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)

        let binCount = fftSize.rawValue / 2 + 1
        for bin in 0..<binCount {
            crossSynthesisFrame.magnitudes[bin] = sqrt(realOut[bin] * realOut[bin] + imagOut[bin] * imagOut[bin])
            crossSynthesisFrame.phases[bin] = atan2(imagOut[bin], realOut[bin])
        }
    }

    // MARK: - Spectral Analysis Output

    /// Get current spectrum for visualization
    public func getSpectrum() -> [Float] {
        return analysisFrame.magnitudes
    }

    /// Get instantaneous frequencies
    public func getFrequencies() -> [Float] {
        return analysisFrame.frequencies
    }

    /// Get frequency for bin index
    public func frequencyForBin(_ bin: Int) -> Float {
        return Float(bin) * sampleRate / Float(fftSize.rawValue)
    }

    // MARK: - Utility

    /// Set sample rate
    public func setSampleRate(_ rate: Float) {
        sampleRate = rate
        setupFFT()
    }

    /// Reset processing state
    public func reset() {
        inputBuffer = [Float](repeating: 0, count: inputBuffer.count)
        outputBuffer = [Float](repeating: 0, count: outputBuffer.count)
        overlapAddBuffer = [Float](repeating: 0, count: overlapAddBuffer.count)
        previousPhases = [Float](repeating: 0, count: previousPhases.count)
        phaseCumulative = [Float](repeating: 0, count: phaseCumulative.count)
        inputWritePos = 0
        outputReadPos = 0
        hopCounter = 0
    }

    /// Capture current frame for freeze
    public func captureFreeze() {
        frozenFrame = analysisFrame
    }
}

// MARK: - Spectral Effects

extension SpectralSynthesizer {

    /// Spectral blur (smear magnitudes across bins)
    public func applySpectralBlur(amount: Float) {
        let binCount = analysisFrame.magnitudes.count
        let blurWidth = Int(amount * 20) + 1

        var blurred = [Float](repeating: 0, count: binCount)

        for bin in 0..<binCount {
            var sum: Float = 0
            var count: Float = 0

            for offset in -blurWidth...blurWidth {
                let idx = bin + offset
                if idx >= 0 && idx < binCount {
                    let weight = 1.0 - Float(abs(offset)) / Float(blurWidth + 1)
                    sum += analysisFrame.magnitudes[idx] * weight
                    count += weight
                }
            }

            blurred[bin] = sum / count
        }

        synthesisFrame.magnitudes = blurred
    }

    /// Spectral contrast enhancement
    public func applyContrastEnhancement(amount: Float) {
        let binCount = analysisFrame.magnitudes.count
        let avgMag = analysisFrame.magnitudes.reduce(0, +) / Float(binCount)

        for bin in 0..<binCount {
            let deviation = analysisFrame.magnitudes[bin] - avgMag
            synthesisFrame.magnitudes[bin] = avgMag + deviation * (1 + amount)
        }
    }

    /// Spectral shift (move all bins up or down)
    public func applySpectralShift(bins: Int) {
        let binCount = analysisFrame.magnitudes.count
        var shifted = [Float](repeating: 0, count: binCount)

        for bin in 0..<binCount {
            let newBin = bin + bins
            if newBin >= 0 && newBin < binCount {
                shifted[newBin] = analysisFrame.magnitudes[bin]
            }
        }

        synthesisFrame.magnitudes = shifted
    }
}

// MARK: - Presets

extension SpectralSynthesizer {

    /// Spectral effect presets
    public enum SpectralPreset: String, CaseIterable {
        case clean = "Clean"
        case robot = "Robot Voice"
        case whisper = "Whisper"
        case frozen = "Frozen"
        case stretched = "Time Stretch 2x"
        case pitched = "Octave Up"
        case choirEffect = "Choir Effect"
        case metallic = "Metallic"
        case underwater = "Underwater"

        public func apply(to synth: SpectralSynthesizer) {
            switch self {
            case .clean:
                synth.mode = .passthrough
                synth.pitchShift = 0
                synth.timeStretch = 1

            case .robot:
                synth.mode = .robotize

            case .whisper:
                synth.mode = .whisperize

            case .frozen:
                synth.mode = .freeze
                synth.freezeEnabled = true

            case .stretched:
                synth.mode = .timeStretch
                synth.timeStretch = 2.0

            case .pitched:
                synth.mode = .pitchShift
                synth.pitchShift = 12

            case .choirEffect:
                synth.mode = .harmonizer
                synth.harmonizerIntervals = [-12, -7, 0, 4, 7, 12]

            case .metallic:
                synth.mode = .spectralFilter
                synth.fftSize = .fft512  // Smaller = more artifacts

            case .underwater:
                synth.mode = .spectralFilter
                synth.fftSize = .fft4096  // Larger = smoother
            }
        }
    }

    /// Apply preset
    public func applyPreset(_ preset: SpectralPreset) {
        preset.apply(to: self)
    }
}

// MARK: - Real-time Morph

extension SpectralSynthesizer {

    /// Morph between two spectral frames
    public struct SpectralMorph {
        public var frameA: SpectralFrame
        public var frameB: SpectralFrame
        public var position: Float = 0  // 0 = A, 1 = B

        public init(size: Int) {
            frameA = SpectralFrame(size: size)
            frameB = SpectralFrame(size: size)
        }

        /// Get interpolated frame
        public func interpolatedFrame() -> SpectralFrame {
            var result = SpectralFrame(size: frameA.magnitudes.count * 2 - 2)

            for i in 0..<frameA.magnitudes.count {
                result.magnitudes[i] = frameA.magnitudes[i] * (1 - position) + frameB.magnitudes[i] * position
                result.phases[i] = frameA.phases[i] * (1 - position) + frameB.phases[i] * position
                result.frequencies[i] = frameA.frequencies[i] * (1 - position) + frameB.frequencies[i] * position
            }

            return result
        }
    }

    /// Capture frame A for morphing
    public func captureFrameA() -> SpectralFrame {
        return analysisFrame
    }

    /// Capture frame B for morphing
    public func captureFrameB() -> SpectralFrame {
        return analysisFrame
    }
}

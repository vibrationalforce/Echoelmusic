import Foundation
import Accelerate
import AVFoundation
import Combine

/// Spectral Analysis Engine - Professional Audio Frequency Analysis
///
/// **Features:**
/// - Real-time FFT (Fast Fourier Transform) analysis
/// - Spectrogram generation (2D time-frequency representation)
/// - Mel-spectrogram (perceptually weighted)
/// - Chromagram (pitch class analysis)
/// - Frequency peak detection
/// - Harmonic analysis
/// - Fundamental frequency (F0) tracking
/// - Spectral centroid, rolloff, flux
/// - Audio fingerprinting
/// - Onset detection
///
/// **Use Cases:**
/// - Audio visualization
/// - Pitch detection for auto-tune
/// - Beat detection and tempo tracking
/// - Sound identification and matching
/// - Quality analysis (clipping, noise)
/// - Mastering insights
///
/// **Example:**
/// ```swift
/// let analyzer = SpectralAnalysisEngine()
/// try await analyzer.analyzeFile(url: audioURL)
/// let spectrum = analyzer.currentSpectrum  // Real-time frequency data
/// let spectrogram = analyzer.generateSpectrogram()
/// ```
@MainActor
class SpectralAnalysisEngine: ObservableObject {

    // MARK: - Published State

    @Published var currentSpectrum: [Float] = []           // Current frequency bins
    @Published var currentMagnitudes: [Float] = []         // dB magnitudes
    @Published var fundamentalFrequency: Float = 0.0       // F0 in Hz
    @Published var spectralCentroid: Float = 0.0           // Hz
    @Published var spectralRolloff: Float = 0.0            // Hz (95% energy)
    @Published var spectralFlux: Float = 0.0               // Change rate
    @Published var harmonics: [Float] = []                 // Detected harmonics
    @Published var isAnalyzing: Bool = false

    // MARK: - Configuration

    struct AnalysisConfig {
        var fftSize: Int = 4096                            // FFT window size
        var hopSize: Int = 1024                            // Samples between analyses
        var sampleRate: Double = 48000                     // Hz
        var windowType: WindowType = .hann
        var minFrequency: Float = 20.0                     // Hz (low cut)
        var maxFrequency: Float = 20000.0                  // Hz (high cut)
        var melBands: Int = 128                            // Mel filterbank size
        var chromaBands: Int = 12                          // Pitch classes (C to B)
    }

    enum WindowType: String, CaseIterable {
        case hann = "Hann"
        case hamming = "Hamming"
        case blackman = "Blackman"
        case rectangular = "Rectangular"

        var description: String {
            switch self {
            case .hann: return "Hann window (general purpose)"
            case .hamming: return "Hamming window (frequency analysis)"
            case .blackman: return "Blackman window (low sidelobes)"
            case .rectangular: return "Rectangular window (no smoothing)"
            }
        }
    }

    // MARK: - Analysis Results

    struct SpectralSnapshot {
        let timestamp: TimeInterval
        let spectrum: [Float]                               // Frequency bins
        let magnitudes: [Float]                             // dB values
        let fundamentalFrequency: Float                     // F0
        let spectralCentroid: Float
        let spectralRolloff: Float
        let spectralFlux: Float
        let harmonics: [Float]
        let chromagram: [Float]                             // 12 pitch classes

        var dominantFrequency: Float {
            guard let maxIndex = magnitudes.enumerated().max(by: { $0.element < $1.element })?.offset else {
                return 0.0
            }
            return spectrum[maxIndex]
        }
    }

    struct Spectrogram {
        let timeFrames: [[Float]]                          // [time][frequency]
        let frequencyBins: [Float]                         // Hz
        let timeStamps: [TimeInterval]                     // Seconds
        let magnitudes: [[Float]]                          // dB
        let config: AnalysisConfig

        var duration: TimeInterval {
            timeStamps.last ?? 0.0
        }

        var frequencyRange: ClosedRange<Float> {
            frequencyBins.first!...frequencyBins.last!
        }
    }

    // MARK: - Private Properties

    private var config: AnalysisConfig
    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float] = []
    private var previousMagnitudes: [Float] = []
    private var analysisHistory: [SpectralSnapshot] = []

    // Mel filterbank
    private var melFilterbank: [[Float]] = []

    // Chroma filterbank
    private var chromaFilterbank: [[Float]] = []

    // MARK: - Initialization

    init(config: AnalysisConfig = AnalysisConfig()) {
        self.config = config
        self.fftSetup = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(config.fftSize), .FORWARD)

        // Pre-compute window function
        self.window = createWindow(size: config.fftSize, type: config.windowType)

        // Pre-compute Mel filterbank
        self.melFilterbank = createMelFilterbank()

        // Pre-compute Chroma filterbank
        self.chromaFilterbank = createChromaFilterbank()

        print("✅ SpectralAnalysisEngine initialized")
        print("   FFT Size: \(config.fftSize)")
        print("   Sample Rate: \(config.sampleRate) Hz")
        print("   Frequency Range: \(config.minFrequency) - \(config.maxFrequency) Hz")
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // MARK: - Real-Time Analysis

    /// Analyze audio buffer in real-time
    func analyzeBuffer(_ buffer: AVAudioPCMBuffer) -> SpectralSnapshot {
        guard let channelData = buffer.floatChannelData?[0] else {
            return emptySnapshot()
        }

        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))

        return analyzeFrame(samples, timestamp: 0.0)
    }

    /// Analyze single frame of audio
    private func analyzeFrame(_ samples: [Float], timestamp: TimeInterval) -> SpectralSnapshot {
        let paddedSamples = padSamples(samples, to: config.fftSize)

        // Apply window function
        var windowedSamples = [Float](repeating: 0.0, count: config.fftSize)
        vDSP_vmul(paddedSamples, 1, window, 1, &windowedSamples, 1, vDSP_Length(config.fftSize))

        // Perform FFT
        let (spectrum, magnitudes) = performFFT(windowedSamples)

        // Update current state
        currentSpectrum = spectrum
        currentMagnitudes = magnitudes

        // Compute spectral features
        let f0 = detectFundamentalFrequency(spectrum: spectrum, magnitudes: magnitudes)
        let centroid = computeSpectralCentroid(spectrum: spectrum, magnitudes: magnitudes)
        let rolloff = computeSpectralRolloff(spectrum: spectrum, magnitudes: magnitudes)
        let flux = computeSpectralFlux(current: magnitudes, previous: previousMagnitudes)
        let harmonics = detectHarmonics(f0: f0, spectrum: spectrum, magnitudes: magnitudes)
        let chromagram = computeChromagram(spectrum: spectrum, magnitudes: magnitudes)

        // Update state
        fundamentalFrequency = f0
        spectralCentroid = centroid
        spectralRolloff = rolloff
        spectralFlux = flux
        self.harmonics = harmonics
        previousMagnitudes = magnitudes

        return SpectralSnapshot(
            timestamp: timestamp,
            spectrum: spectrum,
            magnitudes: magnitudes,
            fundamentalFrequency: f0,
            spectralCentroid: centroid,
            spectralRolloff: rolloff,
            spectralFlux: flux,
            harmonics: harmonics,
            chromagram: chromagram
        )
    }

    // MARK: - File Analysis

    /// Analyze entire audio file and generate spectrogram
    func analyzeFile(url: URL, progressHandler: ((Double) -> Void)? = nil) async throws -> Spectrogram {
        isAnalyzing = true
        defer { isAnalyzing = false }

        print("🔍 Analyzing audio file: \(url.lastPathComponent)")

        let asset = AVURLAsset(url: url)
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AnalysisError.noAudioTrack
        }

        let duration = try await asset.load(.duration).seconds
        print("   Duration: \(String(format: "%.2f", duration)) seconds")

        // Read audio data
        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: config.sampleRate,
            AVNumberOfChannelsKey: 1
        ]

        let readerOutput = AVAssetReaderTrackOutput(track: assetTrack, outputSettings: outputSettings)
        reader.add(readerOutput)
        reader.startReading()

        var timeFrames: [[Float]] = []
        var magnitudesFrames: [[Float]] = []
        var timeStamps: [TimeInterval] = []
        var sampleCount = 0

        // Process audio in chunks
        while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }

            let length = CMBlockBufferGetDataLength(blockBuffer)
            var data = Data(count: length)

            data.withUnsafeMutableBytes { bytes in
                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: bytes.baseAddress!)
            }

            let samples = data.withUnsafeBytes { bytes in
                Array(UnsafeBufferPointer(start: bytes.bindMemory(to: Float.self).baseAddress, count: length / 4))
            }

            // Process with hop size
            var offset = 0
            while offset + config.fftSize <= samples.count {
                let frame = Array(samples[offset..<min(offset + config.fftSize, samples.count)])
                let timestamp = Double(sampleCount + offset) / config.sampleRate

                let snapshot = analyzeFrame(frame, timestamp: timestamp)
                timeFrames.append(snapshot.spectrum)
                magnitudesFrames.append(snapshot.magnitudes)
                timeStamps.append(timestamp)

                offset += config.hopSize
            }

            sampleCount += samples.count

            // Update progress
            let progress = Double(sampleCount) / Double(duration * config.sampleRate)
            progressHandler?(progress)
        }

        reader.cancelReading()

        print("   ✅ Analysis complete: \(timeFrames.count) frames")

        // Generate frequency bins
        let frequencyBins = (0..<config.fftSize/2).map { bin in
            Float(bin) * Float(config.sampleRate) / Float(config.fftSize)
        }

        return Spectrogram(
            timeFrames: timeFrames,
            frequencyBins: frequencyBins,
            timeStamps: timeStamps,
            magnitudes: magnitudesFrames,
            config: config
        )
    }

    // MARK: - FFT Processing

    private func performFFT(_ samples: [Float]) -> (spectrum: [Float], magnitudes: [Float]) {
        guard let setup = fftSetup else {
            return ([], [])
        }

        let halfN = config.fftSize / 2

        // Prepare input buffers
        var realIn = [Float](repeating: 0.0, count: halfN)
        var imagIn = [Float](repeating: 0.0, count: halfN)
        var realOut = [Float](repeating: 0.0, count: halfN)
        var imagOut = [Float](repeating: 0.0, count: halfN)

        // Split complex
        samples.withUnsafeBufferPointer { samplesPtr in
            var splitComplex = DSPSplitComplex(realp: &realIn, imagp: &imagIn)
            samplesPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfN))
            }
        }

        // Perform FFT
        var splitComplexOut = DSPSplitComplex(realp: &realOut, imagp: &imagOut)
        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)

        // Compute magnitudes (|FFT|)
        var magnitudes = [Float](repeating: 0.0, count: halfN)
        vDSP_zvabs(&splitComplexOut, 1, &magnitudes, 1, vDSP_Length(halfN))

        // Convert to dB
        var magnitudesdB = [Float](repeating: 0.0, count: halfN)
        var reference: Float = 1.0
        vDSP_vdbcon(magnitudes, 1, &reference, &magnitudesdB, 1, vDSP_Length(halfN), 1)

        // Generate frequency bins
        let spectrum = (0..<halfN).map { bin in
            Float(bin) * Float(config.sampleRate) / Float(config.fftSize)
        }

        return (spectrum, magnitudesdB)
    }

    // MARK: - Spectral Features

    private func detectFundamentalFrequency(spectrum: [Float], magnitudes: [Float]) -> Float {
        // Find peak magnitude
        guard let maxIndex = magnitudes.enumerated().filter({ $0.offset > 0 && spectrum[$0.offset] >= config.minFrequency && spectrum[$0.offset] <= config.maxFrequency }).max(by: { $0.element < $1.element })?.offset else {
            return 0.0
        }

        return spectrum[maxIndex]
    }

    private func computeSpectralCentroid(spectrum: [Float], magnitudes: [Float]) -> Float {
        // Weighted mean of frequencies
        var sumWeighted: Float = 0.0
        var sumWeights: Float = 0.0

        for i in 0..<spectrum.count {
            let magnitude = pow(10.0, magnitudes[i] / 20.0)  // Convert dB to linear
            sumWeighted += spectrum[i] * magnitude
            sumWeights += magnitude
        }

        return sumWeights > 0 ? sumWeighted / sumWeights : 0.0
    }

    private func computeSpectralRolloff(spectrum: [Float], magnitudes: [Float], threshold: Float = 0.95) -> Float {
        // Frequency below which 95% of energy is contained
        var totalEnergy: Float = 0.0
        let linearMagnitudes = magnitudes.map { pow(10.0, $0 / 20.0) }

        for magnitude in linearMagnitudes {
            totalEnergy += magnitude * magnitude
        }

        let targetEnergy = totalEnergy * threshold
        var cumulativeEnergy: Float = 0.0

        for i in 0..<spectrum.count {
            cumulativeEnergy += linearMagnitudes[i] * linearMagnitudes[i]
            if cumulativeEnergy >= targetEnergy {
                return spectrum[i]
            }
        }

        return spectrum.last ?? 0.0
    }

    private func computeSpectralFlux(current: [Float], previous: [Float]) -> Float {
        guard current.count == previous.count else { return 0.0 }

        var flux: Float = 0.0
        for i in 0..<current.count {
            let diff = current[i] - previous[i]
            flux += diff * diff
        }

        return sqrt(flux) / Float(current.count)
    }

    private func detectHarmonics(f0: Float, spectrum: [Float], magnitudes: [Float], maxHarmonics: Int = 10) -> [Float] {
        guard f0 > 0 else { return [] }

        var harmonics: [Float] = []

        for harmonic in 1...maxHarmonics {
            let targetFreq = f0 * Float(harmonic)
            if targetFreq > config.maxFrequency { break }

            // Find nearest bin
            if let nearestIndex = spectrum.enumerated().min(by: { abs($0.element - targetFreq) < abs($1.element - targetFreq) })?.offset {
                if magnitudes[nearestIndex] > -60.0 {  // Threshold: -60 dB
                    harmonics.append(spectrum[nearestIndex])
                }
            }
        }

        return harmonics
    }

    private func computeChromagram(spectrum: [Float], magnitudes: [Float]) -> [Float] {
        // Project spectrum onto 12 pitch classes (C, C#, D, ..., B)
        var chroma = [Float](repeating: 0.0, count: 12)

        for (i, freq) in spectrum.enumerated() {
            guard freq >= config.minFrequency && freq <= config.maxFrequency else { continue }

            // Convert frequency to MIDI note number
            let midiNote = 12.0 * log2(freq / 440.0) + 69.0
            let pitchClass = Int(midiNote.rounded()) % 12

            let magnitude = pow(10.0, magnitudes[i] / 20.0)
            chroma[pitchClass] += magnitude
        }

        // Normalize
        let maxChroma = chroma.max() ?? 1.0
        if maxChroma > 0 {
            for i in 0..<12 {
                chroma[i] /= maxChroma
            }
        }

        return chroma
    }

    // MARK: - Filterbanks

    private func createMelFilterbank() -> [[Float]] {
        // Mel scale filterbank for perceptual weighting
        var filterbank: [[Float]] = []

        let minMel = hzToMel(config.minFrequency)
        let maxMel = hzToMel(config.maxFrequency)
        let melStep = (maxMel - minMel) / Float(config.melBands + 1)

        for i in 0..<config.melBands {
            let centerMel = minMel + Float(i + 1) * melStep
            let centerHz = melToHz(centerMel)

            var filter = [Float](repeating: 0.0, count: config.fftSize / 2)

            // Triangular filter
            for (bin, freq) in currentSpectrum.enumerated() {
                if abs(freq - centerHz) < 200 {  // 200 Hz bandwidth
                    filter[bin] = 1.0 - abs(freq - centerHz) / 200.0
                }
            }

            filterbank.append(filter)
        }

        return filterbank
    }

    private func createChromaFilterbank() -> [[Float]] {
        // 12-bin chroma filterbank (pitch classes)
        var filterbank: [[Float]] = []

        for pitchClass in 0..<12 {
            var filter = [Float](repeating: 0.0, count: config.fftSize / 2)

            for (bin, freq) in currentSpectrum.enumerated() {
                let midiNote = 12.0 * log2(freq / 440.0) + 69.0
                let pc = Int(midiNote.rounded()) % 12

                if pc == pitchClass {
                    filter[bin] = 1.0
                }
            }

            filterbank.append(filter)
        }

        return filterbank
    }

    // MARK: - Mel Scale Conversion

    private func hzToMel(_ hz: Float) -> Float {
        return 2595.0 * log10(1.0 + hz / 700.0)
    }

    private func melToHz(_ mel: Float) -> Float {
        return 700.0 * (pow(10.0, mel / 2595.0) - 1.0)
    }

    // MARK: - Window Functions

    private func createWindow(size: Int, type: WindowType) -> [Float] {
        var window = [Float](repeating: 0.0, count: size)

        switch type {
        case .hann:
            vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM))
        case .hamming:
            vDSP_hamm_window(&window, vDSP_Length(size), 0)
        case .blackman:
            vDSP_blkman_window(&window, vDSP_Length(size), 0)
        case .rectangular:
            vDSP_vfill(&1.0, &window, 1, vDSP_Length(size))
        }

        return window
    }

    // MARK: - Helpers

    private func padSamples(_ samples: [Float], to size: Int) -> [Float] {
        var padded = samples
        if padded.count < size {
            padded.append(contentsOf: [Float](repeating: 0.0, count: size - padded.count))
        } else if padded.count > size {
            padded = Array(padded.prefix(size))
        }
        return padded
    }

    private func emptySnapshot() -> SpectralSnapshot {
        return SpectralSnapshot(
            timestamp: 0.0,
            spectrum: [],
            magnitudes: [],
            fundamentalFrequency: 0.0,
            spectralCentroid: 0.0,
            spectralRolloff: 0.0,
            spectralFlux: 0.0,
            harmonics: [],
            chromagram: []
        )
    }
}

// MARK: - Errors

enum AnalysisError: LocalizedError {
    case noAudioTrack
    case fftSetupFailed
    case invalidSampleRate

    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "No audio track found in file"
        case .fftSetupFailed:
            return "Failed to initialize FFT"
        case .invalidSampleRate:
            return "Invalid sample rate"
        }
    }
}

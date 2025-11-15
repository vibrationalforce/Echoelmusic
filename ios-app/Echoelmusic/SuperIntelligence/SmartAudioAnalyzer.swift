import Foundation
import AVFoundation
import Accelerate
import CoreGraphics

// MARK: - Smart Audio Analyzer
/// Professional audio analysis suite
/// Phase 6.3+: Super Intelligence Tools
///
/// Analysis Tools:
/// 1. Spectrum Analyzer - Real-time FFT visualization
/// 2. Waveform Display - Time-domain visualization
/// 3. Phase Correlation Meter - Stereo compatibility
/// 4. Loudness Meter - LUFS, RMS, Peak
/// 5. Stereo Imaging - L/R balance, width
/// 6. Frequency Analyzer - Detailed frequency content
class SmartAudioAnalyzer: ObservableObject {

    // MARK: - Published State
    @Published var spectrumData: [Float] = []
    @Published var waveformData: [Float] = []
    @Published var phaseCorrelation: Float = 0.0
    @Published var lufs: Double = -100.0
    @Published var peak: Float = 0.0
    @Published var rms: Float = 0.0
    @Published var stereoWidth: Float = 0.0
    @Published var isAnalyzing: Bool = false

    // MARK: - Configuration
    var fftSize: Int = 2048
    var spectrumBands: Int = 64
    var waveformResolution: Int = 512
    var smoothingFactor: Float = 0.8

    // MARK: - Private State
    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float] = []
    private var previousSpectrum: [Float] = []
    private var previousWaveform: [Float] = []

    // MARK: - Initialization

    init() {
        setupFFT()
        generateWindow()
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    private func setupFFT() {
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        )
    }

    private func generateWindow() {
        // Hann window for smoother FFT
        window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    // MARK: - Spectrum Analyzer

    /// Analyze spectrum from audio buffer
    func analyzeSpectrum(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let floatData = buffer.floatChannelData?[0] else {
            return Array(repeating: 0, count: spectrumBands)
        }

        let frameCount = Int(buffer.frameLength)
        guard frameCount >= fftSize else {
            return Array(repeating: 0, count: spectrumBands)
        }

        // Apply window
        var windowedData = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(floatData, 1, window, 1, &windowedData, 1, vDSP_Length(fftSize))

        // Perform FFT
        var realPart = [Float](repeating: 0, count: fftSize)
        var imagPart = [Float](repeating: 0, count: fftSize)

        windowedData.withUnsafeBufferPointer { windowedPtr in
            realPart.withUnsafeMutableBufferPointer { realPtr in
                imagPart.withUnsafeMutableBufferPointer { imagPtr in
                    guard let setup = fftSetup else { return }

                    vDSP_DFT_Execute(
                        setup,
                        windowedPtr.baseAddress!,
                        nil,
                        realPtr.baseAddress!,
                        imagPtr.baseAddress!
                    )
                }
            }
        }

        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        realPart.withUnsafeBufferPointer { realPtr in
            imagPart.withUnsafeBufferPointer { imagPtr in
                magnitudes.withUnsafeMutableBufferPointer { magPtr in
                    var complex = DSPSplitComplex(
                        realp: UnsafeMutablePointer(mutating: realPtr.baseAddress!),
                        imagp: UnsafeMutablePointer(mutating: imagPtr.baseAddress!)
                    )
                    vDSP_zvabs(&complex, 1, magPtr.baseAddress!, 1, vDSP_Length(fftSize / 2))
                }
            }
        }

        // Convert to dB
        var dBMagnitudes = [Float](repeating: 0, count: fftSize / 2)
        var zeroReference: Float = 1.0
        vDSP_vdbcon(magnitudes, 1, &zeroReference, &dBMagnitudes, 1, vDSP_Length(fftSize / 2), 1)

        // Bin to spectrum bands (logarithmic spacing)
        let spectrum = binToSpectrumBands(dBMagnitudes)

        // Apply smoothing
        let smoothedSpectrum = applySmoothing(current: spectrum, previous: previousSpectrum)
        previousSpectrum = smoothedSpectrum

        DispatchQueue.main.async {
            self.spectrumData = smoothedSpectrum
        }

        return smoothedSpectrum
    }

    private func binToSpectrumBands(_ fftData: [Float]) -> [Float] {
        var bands = [Float](repeating: 0, count: spectrumBands)

        let nyquist = fftSize / 2
        let minFreq = 20.0
        let maxFreq = 20000.0

        for i in 0..<spectrumBands {
            // Logarithmic frequency spacing
            let freqRatio = Double(i) / Double(spectrumBands)
            let frequency = minFreq * pow(maxFreq / minFreq, freqRatio)

            // Map frequency to FFT bin
            let bin = Int((frequency / (Double(fftSize) / 2.0)) * Double(nyquist))
            let clampedBin = min(bin, nyquist - 1)

            bands[i] = fftData[clampedBin]
        }

        return bands
    }

    private func applySmoothing(current: [Float], previous: [Float]) -> [Float] {
        guard previous.count == current.count else { return current }

        var smoothed = [Float](repeating: 0, count: current.count)

        for i in 0..<current.count {
            smoothed[i] = current[i] * (1.0 - smoothingFactor) + previous[i] * smoothingFactor
        }

        return smoothed
    }

    // MARK: - Waveform Display

    /// Generate waveform visualization data
    func analyzeWaveform(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let floatData = buffer.floatChannelData?[0] else {
            return Array(repeating: 0, count: waveformResolution)
        }

        let frameCount = Int(buffer.frameLength)
        let samplesPerPoint = max(1, frameCount / waveformResolution)

        var waveform = [Float](repeating: 0, count: waveformResolution)

        for i in 0..<waveformResolution {
            let startIndex = i * samplesPerPoint
            let endIndex = min(startIndex + samplesPerPoint, frameCount)

            // Find peak in this segment
            var segmentPeak: Float = 0.0
            vDSP_maxmgv(
                floatData.advanced(by: startIndex),
                1,
                &segmentPeak,
                vDSP_Length(endIndex - startIndex)
            )

            waveform[i] = segmentPeak
        }

        // Apply smoothing
        let smoothedWaveform = applySmoothing(current: waveform, previous: previousWaveform)
        previousWaveform = smoothedWaveform

        DispatchQueue.main.async {
            self.waveformData = smoothedWaveform
        }

        return smoothedWaveform
    }

    // MARK: - Phase Correlation Meter

    /// Calculate phase correlation between L/R channels
    /// Returns: -1.0 (out of phase) to +1.0 (in phase)
    func analyzePhaseCorrelation(from buffer: AVAudioPCMBuffer) -> Float {
        guard buffer.format.channelCount >= 2,
              let leftData = buffer.floatChannelData?[0],
              let rightData = buffer.floatChannelData?[1] else {
            return 0.0
        }

        let frameCount = Int(buffer.frameLength)

        // Calculate correlation coefficient
        var leftArray = [Float](repeating: 0, count: frameCount)
        var rightArray = [Float](repeating: 0, count: frameCount)

        leftArray.withUnsafeMutableBufferPointer { leftPtr in
            vDSP_mmov(leftData, leftPtr.baseAddress!, vDSP_Length(frameCount), 1, vDSP_Length(frameCount), 1)
        }

        rightArray.withUnsafeMutableBufferPointer { rightPtr in
            vDSP_mmov(rightData, rightPtr.baseAddress!, vDSP_Length(frameCount), 1, vDSP_Length(frameCount), 1)
        }

        // Calculate means
        var leftMean: Float = 0.0
        var rightMean: Float = 0.0
        vDSP_meanv(leftArray, 1, &leftMean, vDSP_Length(frameCount))
        vDSP_meanv(rightArray, 1, &rightMean, vDSP_Length(frameCount))

        // Subtract means
        var negLeftMean = -leftMean
        var negRightMean = -rightMean
        vDSP_vsadd(leftArray, 1, &negLeftMean, &leftArray, 1, vDSP_Length(frameCount))
        vDSP_vsadd(rightArray, 1, &negRightMean, &rightArray, 1, vDSP_Length(frameCount))

        // Calculate correlation
        var correlation: Float = 0.0
        vDSP_dotpr(leftArray, 1, rightArray, 1, &correlation, vDSP_Length(frameCount))

        var leftPower: Float = 0.0
        var rightPower: Float = 0.0
        vDSP_dotpr(leftArray, 1, leftArray, 1, &leftPower, vDSP_Length(frameCount))
        vDSP_dotpr(rightArray, 1, rightArray, 1, &rightPower, vDSP_Length(frameCount))

        let denominator = sqrt(leftPower * rightPower)
        let phaseCorr = denominator > 0 ? correlation / denominator : 0.0

        DispatchQueue.main.async {
            self.phaseCorrelation = phaseCorr
        }

        return phaseCorr
    }

    // MARK: - Loudness Meter

    /// Analyze loudness (LUFS, RMS, Peak)
    func analyzeLoudness(from buffer: AVAudioPCMBuffer) -> LoudnessMetrics {
        guard let floatData = buffer.floatChannelData?[0] else {
            return LoudnessMetrics(lufs: -100.0, rms: 0.0, peak: 0.0)
        }

        let frameCount = Int(buffer.frameLength)

        // Calculate Peak
        var peakValue: Float = 0.0
        vDSP_maxmgv(floatData, 1, &peakValue, vDSP_Length(frameCount))

        // Calculate RMS
        var sumSquares: Float = 0.0
        vDSP_svesq(floatData, 1, &sumSquares, vDSP_Length(frameCount))
        let rmsValue = sqrt(sumSquares / Float(frameCount))

        // Calculate LUFS (simplified ITU-R BS.1770)
        let lufsValue = -0.691 + 10.0 * log10(Double(rmsValue * rmsValue))

        let metrics = LoudnessMetrics(
            lufs: lufsValue,
            rms: rmsValue,
            peak: peakValue
        )

        DispatchQueue.main.async {
            self.lufs = lufsValue
            self.rms = rmsValue
            self.peak = peakValue
        }

        return metrics
    }

    // MARK: - Stereo Imaging

    /// Analyze stereo width and balance
    func analyzeStereoImaging(from buffer: AVAudioPCMBuffer) -> StereoImagingMetrics {
        guard buffer.format.channelCount >= 2,
              let leftData = buffer.floatChannelData?[0],
              let rightData = buffer.floatChannelData?[1] else {
            return StereoImagingMetrics(width: 0.0, balance: 0.0, monoCompatibility: 1.0)
        }

        let frameCount = Int(buffer.frameLength)

        // Calculate left/right RMS
        var leftSumSquares: Float = 0.0
        var rightSumSquares: Float = 0.0
        vDSP_svesq(leftData, 1, &leftSumSquares, vDSP_Length(frameCount))
        vDSP_svesq(rightData, 1, &rightSumSquares, vDSP_Length(frameCount))

        let leftRMS = sqrt(leftSumSquares / Float(frameCount))
        let rightRMS = sqrt(rightSumSquares / Float(frameCount))

        // Calculate balance (-1.0 = left, 0.0 = center, +1.0 = right)
        let totalRMS = leftRMS + rightRMS
        let balance = totalRMS > 0 ? (rightRMS - leftRMS) / totalRMS : 0.0

        // Calculate stereo width using Mid/Side analysis
        var mid = [Float](repeating: 0, count: frameCount)
        var side = [Float](repeating: 0, count: frameCount)

        // Mid = (L + R) / 2
        vDSP_vadd(leftData, 1, rightData, 1, &mid, 1, vDSP_Length(frameCount))
        var halfScalar: Float = 0.5
        vDSP_vsmul(mid, 1, &halfScalar, &mid, 1, vDSP_Length(frameCount))

        // Side = (L - R) / 2
        vDSP_vsub(rightData, 1, leftData, 1, &side, 1, vDSP_Length(frameCount))
        vDSP_vsmul(side, 1, &halfScalar, &side, 1, vDSP_Length(frameCount))

        var midPower: Float = 0.0
        var sidePower: Float = 0.0
        vDSP_svesq(mid, 1, &midPower, vDSP_Length(frameCount))
        vDSP_svesq(side, 1, &sidePower, vDSP_Length(frameCount))

        // Width calculation
        let totalPower = midPower + sidePower
        let width = totalPower > 0 ? sidePower / totalPower : 0.0

        // Mono compatibility (phase correlation)
        let monoCompat = (1.0 + phaseCorrelation) / 2.0

        let metrics = StereoImagingMetrics(
            width: width,
            balance: balance,
            monoCompatibility: monoCompat
        )

        DispatchQueue.main.async {
            self.stereoWidth = width
        }

        return metrics
    }

    // MARK: - Frequency Analyzer

    /// Detailed frequency analysis with band energy
    func analyzeFrequencyContent(from buffer: AVAudioPCMBuffer) -> FrequencyAnalysis {
        let spectrum = analyzeSpectrum(from: buffer)

        // Divide into frequency bands
        let subBass = averageEnergy(spectrum: spectrum, startBand: 0, endBand: 8)      // 20-60 Hz
        let bass = averageEnergy(spectrum: spectrum, startBand: 8, endBand: 16)        // 60-250 Hz
        let lowMids = averageEnergy(spectrum: spectrum, startBand: 16, endBand: 24)    // 250-500 Hz
        let mids = averageEnergy(spectrum: spectrum, startBand: 24, endBand: 40)       // 500-2kHz
        let highMids = averageEnergy(spectrum: spectrum, startBand: 40, endBand: 52)   // 2k-6kHz
        let highs = averageEnergy(spectrum: spectrum, startBand: 52, endBand: 64)      // 6k-20kHz

        // Find dominant frequency
        let dominantBand = spectrum.enumerated().max { $0.element < $1.element }?.offset ?? 0
        let dominantFrequency = bandToFrequency(band: dominantBand)

        // Calculate spectral centroid (brightness)
        var weightedSum: Float = 0.0
        var totalEnergy: Float = 0.0

        for (i, energy) in spectrum.enumerated() {
            let freq = Float(bandToFrequency(band: i))
            weightedSum += freq * energy
            totalEnergy += energy
        }

        let spectralCentroid = totalEnergy > 0 ? weightedSum / totalEnergy : 0.0

        return FrequencyAnalysis(
            subBass: subBass,
            bass: bass,
            lowMids: lowMids,
            mids: mids,
            highMids: highMids,
            highs: highs,
            dominantFrequency: dominantFrequency,
            spectralCentroid: spectralCentroid
        )
    }

    private func averageEnergy(spectrum: [Float], startBand: Int, endBand: Int) -> Float {
        let clampedStart = max(0, startBand)
        let clampedEnd = min(spectrum.count, endBand)

        guard clampedEnd > clampedStart else { return 0.0 }

        let bandSlice = spectrum[clampedStart..<clampedEnd]
        let sum = bandSlice.reduce(0, +)
        return sum / Float(bandSlice.count)
    }

    private func bandToFrequency(band: Int) -> Double {
        let minFreq = 20.0
        let maxFreq = 20000.0
        let freqRatio = Double(band) / Double(spectrumBands)
        return minFreq * pow(maxFreq / minFreq, freqRatio)
    }

    // MARK: - Full Analysis

    /// Perform complete audio analysis
    func performFullAnalysis(from buffer: AVAudioPCMBuffer) -> FullAudioAnalysis {
        let spectrum = analyzeSpectrum(from: buffer)
        let waveform = analyzeWaveform(from: buffer)
        let phaseCorr = analyzePhaseCorrelation(from: buffer)
        let loudness = analyzeLoudness(from: buffer)
        let stereo = analyzeStereoImaging(from: buffer)
        let frequency = analyzeFrequencyContent(from: buffer)

        return FullAudioAnalysis(
            spectrum: spectrum,
            waveform: waveform,
            phaseCorrelation: phaseCorr,
            loudness: loudness,
            stereoImaging: stereo,
            frequencyAnalysis: frequency
        )
    }
}

// MARK: - Analysis Result Types

struct LoudnessMetrics {
    let lufs: Double
    let rms: Float
    let peak: Float

    var peakDB: Double {
        return 20.0 * log10(Double(peak))
    }

    var rmsDB: Double {
        return 20.0 * log10(Double(rms))
    }

    var dynamicRange: Double {
        return peakDB - rmsDB
    }
}

struct StereoImagingMetrics {
    let width: Float           // 0.0 (mono) to 1.0 (wide)
    let balance: Float         // -1.0 (left) to +1.0 (right)
    let monoCompatibility: Float  // 0.0 (poor) to 1.0 (good)

    var widthPercentage: Float {
        return width * 100.0
    }
}

struct FrequencyAnalysis {
    let subBass: Float         // 20-60 Hz
    let bass: Float            // 60-250 Hz
    let lowMids: Float         // 250-500 Hz
    let mids: Float            // 500-2kHz
    let highMids: Float        // 2k-6kHz
    let highs: Float           // 6k-20kHz
    let dominantFrequency: Double
    let spectralCentroid: Float  // Brightness

    var totalEnergy: Float {
        return subBass + bass + lowMids + mids + highMids + highs
    }

    func bandPercentage(_ band: FrequencyBand) -> Float {
        let total = totalEnergy
        guard total > 0 else { return 0 }

        let bandEnergy: Float
        switch band {
        case .subBass: bandEnergy = subBass
        case .bass: bandEnergy = bass
        case .lowMids: bandEnergy = lowMids
        case .mids: bandEnergy = mids
        case .highMids: bandEnergy = highMids
        case .highs: bandEnergy = highs
        }

        return (bandEnergy / total) * 100.0
    }

    enum FrequencyBand {
        case subBass, bass, lowMids, mids, highMids, highs
    }
}

struct FullAudioAnalysis {
    let spectrum: [Float]
    let waveform: [Float]
    let phaseCorrelation: Float
    let loudness: LoudnessMetrics
    let stereoImaging: StereoImagingMetrics
    let frequencyAnalysis: FrequencyAnalysis
}

// MARK: - Visualization Helpers

extension SmartAudioAnalyzer {

    /// Generate spectrum visualization path (for drawing)
    func generateSpectrumPath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()

        guard !spectrumData.isEmpty else { return path }

        let barWidth = width / CGFloat(spectrumData.count)

        for (i, magnitude) in spectrumData.enumerated() {
            let x = CGFloat(i) * barWidth
            // Normalize magnitude to 0-1 range (assuming -100dB to 0dB)
            let normalizedHeight = CGFloat(max(0, (magnitude + 100.0) / 100.0))
            let barHeight = normalizedHeight * height

            path.addRect(CGRect(x: x, y: height - barHeight, width: barWidth - 1, height: barHeight))
        }

        return path
    }

    /// Generate waveform visualization path
    func generateWaveformPath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()

        guard !waveformData.isEmpty else { return path }

        let pointSpacing = width / CGFloat(waveformData.count)
        let centerY = height / 2

        path.move(to: CGPoint(x: 0, y: centerY))

        for (i, amplitude) in waveformData.enumerated() {
            let x = CGFloat(i) * pointSpacing
            let y = centerY + CGFloat(amplitude) * centerY

            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

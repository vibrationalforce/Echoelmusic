import Foundation
import Accelerate

/// Smart Mixer AI
///
/// AI-powered mixing assistant that provides:
/// - Auto EQ suggestions based on spectral analysis
/// - Compression recommendations
/// - Mastering chain suggestions
/// - Level balancing
/// - Stereo image optimization
///
public final class SmartMixerAI {

    // MARK: - Types

    /// EQ suggestion
    public struct EQSuggestion {
        public let bands: [EQBand]
        public let confidence: Float
        public let description: String
    }

    public struct EQBand {
        public let frequency: Float
        public let gain: Float        // dB
        public let q: Float
        public let type: EQBandType
    }

    public enum EQBandType {
        case lowShelf, highShelf, bell, lowPass, highPass, notch
    }

    /// Compression suggestion
    public struct CompressionSuggestion {
        public let threshold: Float   // dB
        public let ratio: Float
        public let attack: Float      // ms
        public let release: Float     // ms
        public let makeupGain: Float  // dB
        public let knee: Float        // dB
        public let confidence: Float
    }

    /// Mastering chain suggestion
    public struct MasteringChainSuggestion {
        public let stages: [MasteringStage]
        public let targetLoudness: Float  // LUFS
        public let confidence: Float
    }

    public struct MasteringStage {
        public let type: MasteringStageType
        public let parameters: [String: Float]
        public let order: Int
    }

    public enum MasteringStageType: String {
        case eq = "EQ"
        case multibandCompression = "Multiband Compression"
        case stereoEnhancer = "Stereo Enhancer"
        case saturation = "Saturation"
        case limiter = "Limiter"
        case loudnessMaximizer = "Loudness Maximizer"
    }

    /// Level balance suggestion
    public struct LevelBalance {
        public let trackAdjustments: [String: Float]  // Track name -> dB adjustment
        public let panSuggestions: [String: Float]    // Track name -> pan position
        public let confidence: Float
    }

    // MARK: - Properties

    private let fftSize = 4096
    private var fftSetup: FFTSetup?
    private var log2n: vDSP_Length = 0

    // Reference spectral curves (for genre-specific EQ)
    private var referenceSpectrum: [String: [Float]] = [:]

    // MARK: - Initialization

    public init() {
        setupFFT()
        loadReferenceCurves()
    }

    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    private func setupFFT() {
        log2n = vDSP_Length(log2(Double(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
    }

    private func loadReferenceCurves() {
        // Reference spectral curves for different genres
        // These represent "ideal" spectral balance
        let numBins = fftSize / 2

        // Pop/Radio reference (bright, present)
        referenceSpectrum["pop"] = createReferenceCurve(
            lowEnd: 0.0,       // 20-100 Hz
            lowMids: -2.0,     // 100-500 Hz
            mids: 0.0,         // 500-2000 Hz
            upperMids: 2.0,    // 2000-6000 Hz
            highs: 1.0,        // 6000+ Hz
            numBins: numBins
        )

        // Hip-Hop reference (heavy low end)
        referenceSpectrum["hiphop"] = createReferenceCurve(
            lowEnd: 3.0,
            lowMids: 0.0,
            mids: -1.0,
            upperMids: 1.0,
            highs: 0.0,
            numBins: numBins
        )

        // Rock reference (midrange focused)
        referenceSpectrum["rock"] = createReferenceCurve(
            lowEnd: 1.0,
            lowMids: 0.0,
            mids: 2.0,
            upperMids: 1.0,
            highs: 0.0,
            numBins: numBins
        )

        // Classical reference (flat, natural)
        referenceSpectrum["classical"] = createReferenceCurve(
            lowEnd: 0.0,
            lowMids: 0.0,
            mids: 0.0,
            upperMids: 0.0,
            highs: 0.0,
            numBins: numBins
        )

        // Electronic reference (scooped mids, strong bass/highs)
        referenceSpectrum["electronic"] = createReferenceCurve(
            lowEnd: 2.0,
            lowMids: -1.0,
            mids: -2.0,
            upperMids: 1.0,
            highs: 2.0,
            numBins: numBins
        )
    }

    private func createReferenceCurve(
        lowEnd: Float,
        lowMids: Float,
        mids: Float,
        upperMids: Float,
        highs: Float,
        numBins: Int
    ) -> [Float] {
        var curve = [Float](repeating: 0, count: numBins)
        let binWidth: Float = 24000 / Float(numBins)

        for i in 0..<numBins {
            let freq = Float(i) * binWidth

            if freq < 100 {
                curve[i] = lowEnd
            } else if freq < 500 {
                curve[i] = lowMids
            } else if freq < 2000 {
                curve[i] = mids
            } else if freq < 6000 {
                curve[i] = upperMids
            } else {
                curve[i] = highs
            }
        }

        return curve
    }

    // MARK: - EQ Suggestions

    /// Suggest EQ adjustments for a track
    public func suggestEQ(for audio: [Float], sampleRate: Float, genre: String = "pop") async -> EQSuggestion {
        // Analyze spectral content
        let spectrum = analyzeSpectrum(audio: audio)

        // Get reference curve
        let reference = referenceSpectrum[genre] ?? referenceSpectrum["pop"]!

        // Compare and find differences
        let differences = compareToReference(spectrum: spectrum, reference: reference, sampleRate: sampleRate)

        // Generate EQ bands based on differences
        var bands: [EQBand] = []

        // Low end (60 Hz)
        if abs(differences.lowEnd) > 1.5 {
            bands.append(EQBand(
                frequency: 60,
                gain: -differences.lowEnd * 0.5,
                q: 1.0,
                type: .lowShelf
            ))
        }

        // Low-mids (250 Hz)
        if abs(differences.lowMids) > 1.5 {
            bands.append(EQBand(
                frequency: 250,
                gain: -differences.lowMids * 0.5,
                q: 1.5,
                type: .bell
            ))
        }

        // Mids (1000 Hz)
        if abs(differences.mids) > 1.5 {
            bands.append(EQBand(
                frequency: 1000,
                gain: -differences.mids * 0.5,
                q: 1.5,
                type: .bell
            ))
        }

        // Upper-mids (3000 Hz)
        if abs(differences.upperMids) > 1.5 {
            bands.append(EQBand(
                frequency: 3000,
                gain: -differences.upperMids * 0.5,
                q: 2.0,
                type: .bell
            ))
        }

        // Highs (10000 Hz)
        if abs(differences.highs) > 1.5 {
            bands.append(EQBand(
                frequency: 10000,
                gain: -differences.highs * 0.5,
                q: 1.0,
                type: .highShelf
            ))
        }

        let description = generateEQDescription(differences: differences)
        let confidence = calculateConfidence(bands: bands)

        return EQSuggestion(bands: bands, confidence: confidence, description: description)
    }

    private func analyzeSpectrum(audio: [Float]) -> [Float] {
        guard let setup = fftSetup, audio.count >= fftSize else {
            return [Float](repeating: 0, count: fftSize / 2)
        }

        let numFrames = (audio.count - fftSize) / (fftSize / 2) + 1
        var avgSpectrum = [Float](repeating: 0, count: fftSize / 2)

        for frameIndex in 0..<numFrames {
            let startSample = frameIndex * (fftSize / 2)
            var frame = Array(audio[startSample..<min(startSample + fftSize, audio.count)])

            if frame.count < fftSize {
                frame.append(contentsOf: [Float](repeating: 0, count: fftSize - frame.count))
            }

            // Window
            var window = [Float](repeating: 0, count: fftSize)
            vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
            vDSP_vmul(frame, 1, window, 1, &frame, 1, vDSP_Length(fftSize))

            // FFT
            var realBuffer = [Float](repeating: 0, count: fftSize / 2)
            var imagBuffer = [Float](repeating: 0, count: fftSize / 2)
            var splitComplex = DSPSplitComplex(realp: &realBuffer, imagp: &imagBuffer)

            frame.withUnsafeBufferPointer { ptr in
                ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                    vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                }
            }

            vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

            // Magnitude
            var magnitudes = [Float](repeating: 0, count: fftSize / 2)
            vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

            // Add to average
            vDSP_vadd(avgSpectrum, 1, magnitudes, 1, &avgSpectrum, 1, vDSP_Length(fftSize / 2))
        }

        // Average and convert to dB
        var scale = 1.0 / Float(numFrames)
        vDSP_vsmul(avgSpectrum, 1, &scale, &avgSpectrum, 1, vDSP_Length(fftSize / 2))

        // Convert to dB
        for i in 0..<avgSpectrum.count {
            avgSpectrum[i] = 20 * log10(max(avgSpectrum[i], 1e-10))
        }

        return avgSpectrum
    }

    private struct SpectralDifferences {
        var lowEnd: Float
        var lowMids: Float
        var mids: Float
        var upperMids: Float
        var highs: Float
    }

    private func compareToReference(spectrum: [Float], reference: [Float], sampleRate: Float) -> SpectralDifferences {
        let binWidth = sampleRate / Float(fftSize)

        var lowEndSum: Float = 0, lowEndCount: Float = 0
        var lowMidsSum: Float = 0, lowMidsCount: Float = 0
        var midsSum: Float = 0, midsCount: Float = 0
        var upperMidsSum: Float = 0, upperMidsCount: Float = 0
        var highsSum: Float = 0, highsCount: Float = 0

        for i in 0..<min(spectrum.count, reference.count) {
            let freq = Float(i) * binWidth
            let diff = spectrum[i] - reference[i]

            if freq < 100 {
                lowEndSum += diff
                lowEndCount += 1
            } else if freq < 500 {
                lowMidsSum += diff
                lowMidsCount += 1
            } else if freq < 2000 {
                midsSum += diff
                midsCount += 1
            } else if freq < 6000 {
                upperMidsSum += diff
                upperMidsCount += 1
            } else {
                highsSum += diff
                highsCount += 1
            }
        }

        return SpectralDifferences(
            lowEnd: lowEndCount > 0 ? lowEndSum / lowEndCount : 0,
            lowMids: lowMidsCount > 0 ? lowMidsSum / lowMidsCount : 0,
            mids: midsCount > 0 ? midsSum / midsCount : 0,
            upperMids: upperMidsCount > 0 ? upperMidsSum / upperMidsCount : 0,
            highs: highsCount > 0 ? highsSum / highsCount : 0
        )
    }

    private func generateEQDescription(differences: SpectralDifferences) -> String {
        var parts: [String] = []

        if differences.lowEnd > 2 {
            parts.append("excess low end")
        } else if differences.lowEnd < -2 {
            parts.append("thin low end")
        }

        if differences.lowMids > 2 {
            parts.append("muddy low-mids")
        }

        if differences.mids > 2 {
            parts.append("boxy midrange")
        } else if differences.mids < -2 {
            parts.append("hollow midrange")
        }

        if differences.upperMids > 2 {
            parts.append("harsh upper-mids")
        } else if differences.upperMids < -2 {
            parts.append("lacking presence")
        }

        if differences.highs < -2 {
            parts.append("dull high end")
        } else if differences.highs > 2 {
            parts.append("excessive brightness")
        }

        if parts.isEmpty {
            return "Spectrum is well balanced"
        }

        return "Detected: " + parts.joined(separator: ", ")
    }

    private func calculateConfidence(bands: [EQBand]) -> Float {
        // More bands = less confidence (more changes needed)
        let bandPenalty = Float(bands.count) * 0.1

        // Large gain changes = less confidence
        let maxGain = bands.map { abs($0.gain) }.max() ?? 0
        let gainPenalty = maxGain * 0.05

        return max(0.3, 1.0 - bandPenalty - gainPenalty)
    }

    // MARK: - Compression Suggestions

    /// Suggest compression settings for a track
    public func suggestCompression(for audio: [Float]) async -> CompressionSuggestion {
        let dynamics = analyzeDynamics(audio: audio)

        var threshold: Float
        var ratio: Float
        var attack: Float
        var release: Float

        // High dynamic range -> more compression
        if dynamics.peakToRMS > 15 {
            // Very dynamic - aggressive compression
            threshold = -18
            ratio = 4.0
            attack = 10
            release = 100
        } else if dynamics.peakToRMS > 10 {
            // Moderately dynamic
            threshold = -15
            ratio = 3.0
            attack = 15
            release = 150
        } else if dynamics.peakToRMS > 6 {
            // Light dynamics
            threshold = -12
            ratio = 2.0
            attack = 20
            release = 200
        } else {
            // Already compressed
            threshold = -10
            ratio = 1.5
            attack = 30
            release = 250
        }

        // Adjust attack based on transient content
        if dynamics.transientDensity > 0.7 {
            attack = max(1, attack - 5)  // Faster attack for transients
        }

        // Calculate makeup gain
        let gainReduction = (dynamics.averageLevel - threshold) * (1 - 1/ratio)
        let makeupGain = max(0, gainReduction * 0.5)

        return CompressionSuggestion(
            threshold: threshold,
            ratio: ratio,
            attack: attack,
            release: release,
            makeupGain: makeupGain,
            knee: 3.0,
            confidence: 0.75
        )
    }

    private struct DynamicsAnalysis {
        var peakLevel: Float
        var rmsLevel: Float
        var averageLevel: Float
        var peakToRMS: Float
        var transientDensity: Float
    }

    private func analyzeDynamics(audio: [Float]) -> DynamicsAnalysis {
        guard !audio.isEmpty else {
            return DynamicsAnalysis(peakLevel: 0, rmsLevel: 0, averageLevel: 0, peakToRMS: 0, transientDensity: 0)
        }

        // Peak level
        var peak: Float = 0
        vDSP_maxmgv(audio, 1, &peak, vDSP_Length(audio.count))
        let peakDB = 20 * log10(max(peak, 1e-10))

        // RMS level
        var sumSquares: Float = 0
        vDSP_svesq(audio, 1, &sumSquares, vDSP_Length(audio.count))
        let rms = sqrt(sumSquares / Float(audio.count))
        let rmsDB = 20 * log10(max(rms, 1e-10))

        // Average level (mean of absolute values)
        var sum: Float = 0
        for sample in audio {
            sum += abs(sample)
        }
        let avgDB = 20 * log10(max(sum / Float(audio.count), 1e-10))

        // Transient density (count of sudden level increases)
        var transients = 0
        let threshold: Float = 0.1
        for i in 1..<audio.count {
            if abs(audio[i]) - abs(audio[i-1]) > threshold {
                transients += 1
            }
        }
        let transientDensity = Float(transients) / Float(audio.count) * 1000

        return DynamicsAnalysis(
            peakLevel: peakDB,
            rmsLevel: rmsDB,
            averageLevel: avgDB,
            peakToRMS: peakDB - rmsDB,
            transientDensity: min(1, transientDensity)
        )
    }

    // MARK: - Mastering Chain Suggestions

    /// Suggest complete mastering chain
    public func suggestMasteringChain(for audio: [Float], sampleRate: Float, genre: String = "pop") async -> MasteringChainSuggestion {
        let spectrum = analyzeSpectrum(audio: audio)
        let dynamics = analyzeDynamics(audio: audio)

        var stages: [MasteringStage] = []
        var order = 0

        // 1. EQ (always)
        let eqSuggestion = await suggestEQ(for: audio, sampleRate: sampleRate, genre: genre)
        if !eqSuggestion.bands.isEmpty {
            var eqParams: [String: Float] = [:]
            for (i, band) in eqSuggestion.bands.prefix(4).enumerated() {
                eqParams["band\(i)_freq"] = band.frequency
                eqParams["band\(i)_gain"] = band.gain
                eqParams["band\(i)_q"] = band.q
            }
            stages.append(MasteringStage(type: .eq, parameters: eqParams, order: order))
            order += 1
        }

        // 2. Multiband compression (if dynamics vary across frequency)
        let compressionSuggestion = await suggestCompression(for: audio)
        if dynamics.peakToRMS > 8 {
            stages.append(MasteringStage(
                type: .multibandCompression,
                parameters: [
                    "lowThreshold": compressionSuggestion.threshold + 2,
                    "midThreshold": compressionSuggestion.threshold,
                    "highThreshold": compressionSuggestion.threshold + 4,
                    "ratio": compressionSuggestion.ratio
                ],
                order: order
            ))
            order += 1
        }

        // 3. Stereo enhancer (optional based on genre)
        if genre == "electronic" || genre == "pop" {
            stages.append(MasteringStage(
                type: .stereoEnhancer,
                parameters: ["width": 1.2, "bass_mono": 1],
                order: order
            ))
            order += 1
        }

        // 4. Saturation (optional for warmth)
        if genre == "rock" || genre == "hiphop" {
            stages.append(MasteringStage(
                type: .saturation,
                parameters: ["drive": 0.2, "mix": 0.3],
                order: order
            ))
            order += 1
        }

        // 5. Limiter (always last)
        stages.append(MasteringStage(
            type: .limiter,
            parameters: [
                "ceiling": -0.3,
                "release": 50,
                "lookAhead": 5
            ],
            order: order
        ))

        // Target loudness based on genre
        let targetLoudness: Float
        switch genre {
        case "electronic", "hiphop":
            targetLoudness = -9
        case "pop", "rock":
            targetLoudness = -11
        case "classical":
            targetLoudness = -18
        default:
            targetLoudness = -14
        }

        return MasteringChainSuggestion(
            stages: stages,
            targetLoudness: targetLoudness,
            confidence: 0.8
        )
    }

    // MARK: - Level Balance

    /// Suggest level balance for multiple tracks
    public func suggestLevelBalance(tracks: [(name: String, audio: [Float])]) async -> LevelBalance {
        var adjustments: [String: Float] = [:]
        var panSuggestions: [String: Float] = [:]

        // Analyze each track
        var trackAnalysis: [(name: String, rms: Float, spectralCentroid: Float)] = []

        for track in tracks {
            let dynamics = analyzeDynamics(audio: track.audio)
            let centroid = calculateSpectralCentroid(audio: track.audio)
            trackAnalysis.append((track.name, dynamics.rmsLevel, centroid))
        }

        // Target average RMS
        let avgRMS = trackAnalysis.map { $0.rms }.reduce(0, +) / Float(trackAnalysis.count)

        for analysis in trackAnalysis {
            // Level adjustment to balance RMS
            adjustments[analysis.name] = avgRMS - analysis.rms

            // Pan suggestion based on spectral content
            // Lower content more center, higher content can be wider
            if analysis.spectralCentroid < 0.3 {
                panSuggestions[analysis.name] = 0  // Center
            } else if analysis.spectralCentroid > 0.6 {
                // Alternate left/right for high content
                panSuggestions[analysis.name] = Float.random(in: -0.5...0.5)
            } else {
                panSuggestions[analysis.name] = Float.random(in: -0.3...0.3)
            }
        }

        return LevelBalance(
            trackAdjustments: adjustments,
            panSuggestions: panSuggestions,
            confidence: 0.7
        )
    }

    private func calculateSpectralCentroid(audio: [Float]) -> Float {
        let spectrum = analyzeSpectrum(audio: audio)
        guard !spectrum.isEmpty else { return 0.5 }

        var weightedSum: Float = 0
        var sum: Float = 0

        // Convert from dB back to linear for weighting
        for (i, db) in spectrum.enumerated() {
            let linear = pow(10, db / 20)
            weightedSum += Float(i) * linear
            sum += linear
        }

        return sum > 0 ? weightedSum / sum / Float(spectrum.count) : 0.5
    }
}

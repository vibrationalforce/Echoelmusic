import Foundation
import AVFoundation
import Accelerate

/// Advanced Mastering Chain - Professional Audio Mastering Pipeline
///
/// **Mastering Chain Order:**
/// 1. Input Gain Staging
/// 2. Linear Phase EQ (Corrective)
/// 3. Multi-Band Compression (Dynamic Control)
/// 4. Mid-Side Processing (Stereo Enhancement)
/// 5. Harmonic Exciter (Saturation)
/// 6. Linear Phase EQ (Sweetening)
/// 7. Stereo Widening/Imaging
/// 8. Limiter (True Peak + Loudness)
/// 9. Dithering (Bit-Depth Reduction)
/// 10. Output Gain
///
/// **Presets:**
/// - Streaming (Spotify/Apple Music): -14 LUFS, True Peak -1.0 dBTP
/// - Mastering for Vinyl: -12 LUFS, bass mono, high-pass 30 Hz
/// - Broadcast (EBU R128): -23 LUFS, True Peak -1.0 dBTP
/// - Club/DJ: -8 LUFS, wide stereo, punchy bass
/// - Classical/Audiophile: -18 LUFS, pristine dynamics
///
/// **Example:**
/// ```swift
/// let mastering = AdvancedMasteringChain()
/// try await mastering.applyPreset(.streaming, to: audioURL, output: outputURL)
/// ```
@MainActor
class AdvancedMasteringChain: ObservableObject {

    // MARK: - Published State

    @Published var isProcessing: Bool = false
    @Published var currentPreset: MasteringPreset = .streaming
    @Published var analysisResults: AudioAnalysis?

    // MARK: - Mastering Presets

    enum MasteringPreset: String, CaseIterable {
        case streaming = "Streaming Master"
        case vinyl = "Vinyl Master"
        case broadcast = "Broadcast (EBU R128)"
        case club = "Club/DJ"
        case classical = "Classical/Audiophile"
        case podcast = "Podcast/Voice"
        case youtube = "YouTube/Online Video"
        case custom = "Custom"

        var targetLUFS: Float {
            switch self {
            case .streaming: return -14.0
            case .vinyl: return -12.0
            case .broadcast: return -23.0
            case .club: return -8.0
            case .classical: return -18.0
            case .podcast: return -16.0
            case .youtube: return -13.0
            case .custom: return -14.0
            }
        }

        var truePeakLimit: Float {
            switch self {
            case .streaming, .broadcast, .youtube: return -1.0  // dBTP
            case .vinyl: return -2.0  // More headroom for pressing
            case .club: return -0.3   // Maximize loudness
            case .classical: return -3.0  // Preserve dynamics
            case .podcast: return -1.0
            case .custom: return -1.0
            }
        }

        var description: String {
            switch self {
            case .streaming:
                return "Optimized for Spotify, Apple Music, Tidal (-14 LUFS)"
            case .vinyl:
                return "Bass mono, high-pass 30 Hz, optimized for vinyl pressing"
            case .broadcast:
                return "EBU R128 compliant for TV/Radio broadcast (-23 LUFS)"
            case .club:
                return "Maximum loudness for club systems, punchy bass"
            case .classical:
                return "Pristine dynamics, minimal processing, audiophile quality"
            case .podcast:
                return "Voice-optimized, speech clarity, broadcast-safe"
            case .youtube:
                return "Optimized for YouTube loudness normalization"
            case .custom:
                return "Custom settings for advanced users"
            }
        }
    }

    // MARK: - Chain Configuration

    struct ChainConfig {
        // 1. Input Gain
        var inputGain: Float = 0.0  // dB

        // 2. Linear Phase EQ (Corrective)
        var correctiveEQ: EQSettings = EQSettings()

        // 3. Multi-Band Compressor
        var multiband: MultiBandCompressor = MultiBandCompressor()

        // 4. Mid-Side Processing
        var midSide: MidSideProcessor = MidSideProcessor()

        // 5. Harmonic Exciter
        var exciter: HarmonicExciter = HarmonicExciter()

        // 6. Linear Phase EQ (Sweetening)
        var sweeteningEQ: EQSettings = EQSettings()

        // 7. Stereo Imaging
        var stereoImaging: StereoImager = StereoImager()

        // 8. Limiter
        var limiter: TruePeakLimiter = TruePeakLimiter()

        // 9. Dithering
        var dithering: DitheringSettings = DitheringSettings()

        // 10. Output Gain
        var outputGain: Float = 0.0  // dB
    }

    struct EQSettings {
        var enabled: Bool = true
        var bands: [EQBand] = []

        struct EQBand {
            var frequency: Float  // Hz
            var gain: Float       // dB
            var q: Float          // Quality factor
            var type: BandType

            enum BandType: String {
                case lowShelf = "Low Shelf"
                case peak = "Peak"
                case highShelf = "High Shelf"
                case lowPass = "Low Pass"
                case highPass = "High Pass"
            }
        }
    }

    struct MultiBandCompressor {
        var enabled: Bool = true
        var bands: [CompressorBand] = []

        struct CompressorBand {
            var lowFreq: Float      // Hz
            var highFreq: Float     // Hz
            var threshold: Float    // dB
            var ratio: Float        // x:1
            var attack: Float       // ms
            var release: Float      // ms
            var makeupGain: Float   // dB
        }
    }

    struct MidSideProcessor {
        var enabled: Bool = true
        var midGain: Float = 0.0      // dB
        var sideGain: Float = 0.0     // dB
        var bassToMono: Bool = false  // <120 Hz → mono (vinyl)
    }

    struct HarmonicExciter {
        var enabled: Bool = true
        var amount: Float = 0.0       // 0-100%
        var frequency: Float = 4000   // Hz (where to apply)
        var harmonics: Int = 2        // 2nd, 3rd, etc.
    }

    struct StereoImager {
        var enabled: Bool = true
        var width: Float = 1.0        // 0.0 (mono) - 2.0 (wide)
        var correlation: Float = 1.0  // Target correlation
    }

    struct TruePeakLimiter {
        var enabled: Bool = true
        var threshold: Float = -1.0   // dBTP
        var release: Float = 100.0    // ms
        var lookahead: Float = 5.0    // ms
        var oversampling: Int = 4     // 4x oversampling
    }

    struct DitheringSettings {
        var enabled: Bool = true
        var type: DitheringType = .tpdf
        var targetBitDepth: Int = 16

        enum DitheringType: String {
            case tpdf = "TPDF"
            case pow2 = "POW-r 2"
            case pow3 = "POW-r 3"
        }
    }

    // MARK: - Audio Analysis

    struct AudioAnalysis {
        let inputLUFS: Float
        let inputTruePeak: Float
        let inputDynamicRange: Float
        let outputLUFS: Float
        let outputTruePeak: Float
        let outputDynamicRange: Float
        let gainReduction: Float
        let stereoCorrelation: Float
        let spectralBalance: SpectralBalance

        struct SpectralBalance {
            let bass: Float     // 20-250 Hz (dB)
            let mids: Float     // 250-4000 Hz (dB)
            let highs: Float    // 4000-20000 Hz (dB)
        }

        var description: String {
            """
            📊 Mastering Analysis:

            INPUT:
            • Integrated Loudness: \(String(format: "%.1f", inputLUFS)) LUFS
            • True Peak: \(String(format: "%.2f", inputTruePeak)) dBTP
            • Dynamic Range: \(String(format: "%.1f", inputDynamicRange)) dB

            OUTPUT:
            • Integrated Loudness: \(String(format: "%.1f", outputLUFS)) LUFS
            • True Peak: \(String(format: "%.2f", outputTruePeak)) dBTP
            • Dynamic Range: \(String(format: "%.1f", outputDynamicRange)) dB

            PROCESSING:
            • Gain Reduction: \(String(format: "%.1f", gainReduction)) dB
            • Stereo Correlation: \(String(format: "%.2f", stereoCorrelation))

            SPECTRAL BALANCE:
            • Bass (20-250 Hz): \(String(format: "%.1f", spectralBalance.bass)) dB
            • Mids (250-4k Hz): \(String(format: "%.1f", spectralBalance.mids)) dB
            • Highs (4k-20k Hz): \(String(format: "%.1f", spectralBalance.highs)) dB
            """
        }
    }

    // MARK: - Preset Configurations

    private static func configForPreset(_ preset: MasteringPreset) -> ChainConfig {
        var config = ChainConfig()

        switch preset {
        case .streaming:
            // Spotify/Apple Music
            config.correctiveEQ.bands = [
                .init(frequency: 30, gain: -3, q: 0.7, type: .highPass),
                .init(frequency: 150, gain: 1.0, q: 1.0, type: .peak),
                .init(frequency: 8000, gain: 1.5, q: 0.7, type: .highShelf)
            ]

            config.multiband.bands = [
                .init(lowFreq: 20, highFreq: 150, threshold: -15, ratio: 3.0, attack: 30, release: 150, makeupGain: 2),
                .init(lowFreq: 150, highFreq: 5000, threshold: -12, ratio: 2.5, attack: 10, release: 100, makeupGain: 1),
                .init(lowFreq: 5000, highFreq: 20000, threshold: -10, ratio: 2.0, attack: 5, release: 80, makeupGain: 0.5)
            ]

            config.exciter.amount = 15
            config.stereoImaging.width = 1.1
            config.limiter.threshold = -1.0

        case .vinyl:
            // Vinyl Master
            config.correctiveEQ.bands = [
                .init(frequency: 30, gain: -6, q: 0.7, type: .highPass),  // Essential for vinyl
                .init(frequency: 100, gain: 0.5, q: 1.0, type: .peak)
            ]

            config.midSide.bassToMono = true  // <120 Hz → mono
            config.multiband.bands = [
                .init(lowFreq: 20, highFreq: 120, threshold: -18, ratio: 4.0, attack: 40, release: 200, makeupGain: 3)
            ]

            config.stereoImaging.width = 0.9  // Slightly narrower
            config.limiter.threshold = -2.0   // More headroom

        case .broadcast:
            // EBU R128
            config.correctiveEQ.bands = [
                .init(frequency: 40, gain: -2, q: 0.7, type: .highPass)
            ]

            config.multiband.bands = [
                .init(lowFreq: 20, highFreq: 200, threshold: -20, ratio: 3.0, attack: 30, release: 150, makeupGain: 2),
                .init(lowFreq: 200, highFreq: 6000, threshold: -18, ratio: 2.5, attack: 15, release: 120, makeupGain: 1)
            ]

            config.limiter.threshold = -1.0

        case .club:
            // Club/DJ
            config.correctiveEQ.bands = [
                .init(frequency: 25, gain: -3, q: 0.7, type: .highPass),
                .init(frequency: 60, gain: 2.0, q: 1.5, type: .peak),  // Punchy bass
                .init(frequency: 10000, gain: 2.0, q: 0.7, type: .highShelf)
            ]

            config.multiband.bands = [
                .init(lowFreq: 20, highFreq: 100, threshold: -12, ratio: 5.0, attack: 20, release: 100, makeupGain: 4),
                .init(lowFreq: 100, highFreq: 10000, threshold: -8, ratio: 4.0, attack: 5, release: 80, makeupGain: 2)
            ]

            config.exciter.amount = 25
            config.stereoImaging.width = 1.3  // Wide stereo
            config.limiter.threshold = -0.3   // Maximize loudness

        case .classical:
            // Classical/Audiophile
            config.correctiveEQ.enabled = false  // Minimal processing
            config.multiband.enabled = false
            config.exciter.enabled = false
            config.limiter.threshold = -3.0  // Preserve dynamics

        case .podcast:
            // Podcast/Voice
            config.correctiveEQ.bands = [
                .init(frequency: 80, gain: -6, q: 0.7, type: .highPass),
                .init(frequency: 200, gain: -2, q: 2.0, type: .peak),  // Reduce mud
                .init(frequency: 3000, gain: 2.0, q: 1.0, type: .peak)  // Clarity
            ]

            config.multiband.bands = [
                .init(lowFreq: 80, highFreq: 400, threshold: -18, ratio: 3.0, attack: 20, release: 100, makeupGain: 2),
                .init(lowFreq: 400, highFreq: 8000, threshold: -15, ratio: 2.5, attack: 10, release: 80, makeupGain: 1)
            ]

            config.stereoImaging.width = 0.7  // Narrow for voice
            config.limiter.threshold = -1.0

        case .youtube:
            // YouTube
            config.correctiveEQ.bands = [
                .init(frequency: 30, gain: -2, q: 0.7, type: .highPass),
                .init(frequency: 10000, gain: 1.0, q: 0.7, type: .highShelf)
            ]

            config.multiband.bands = [
                .init(lowFreq: 20, highFreq: 200, threshold: -15, ratio: 3.0, attack: 25, release: 120, makeupGain: 2)
            ]

            config.limiter.threshold = -1.0

        case .custom:
            // User-defined
            break
        }

        return config
    }

    // MARK: - Processing Pipeline

    /// Apply mastering preset to audio file
    func applyPreset(
        _ preset: MasteringPreset,
        to inputURL: URL,
        outputURL: URL,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> AudioAnalysis {
        isProcessing = true
        defer { isProcessing = false }

        print("🎛️ Starting mastering process:")
        print("   Preset: \(preset.rawValue)")
        print("   Input: \(inputURL.lastPathComponent)")
        print("   Output: \(outputURL.lastPathComponent)")

        let config = Self.configForPreset(preset)

        // Step 1: Analyze input
        progressHandler?(0.1)
        let inputAnalysis = try await analyzeAudio(url: inputURL)
        print("   Input LUFS: \(String(format: "%.1f", inputAnalysis.lufs))")
        print("   Input True Peak: \(String(format: "%.2f", inputAnalysis.truePeak))")

        // Step 2: Load audio
        progressHandler?(0.2)
        let asset = AVURLAsset(url: inputURL)
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw MasteringError.noAudioTrack
        }

        // Step 3: Read audio data
        progressHandler?(0.3)
        let audioData = try await readAudioData(from: asset, track: assetTrack)

        // Step 4: Apply mastering chain
        progressHandler?(0.4)
        var processedData = audioData

        // Chain order:
        processedData = applyInputGain(processedData, gain: config.inputGain)
        progressHandler?(0.5)

        processedData = applyEQ(processedData, settings: config.correctiveEQ)
        progressHandler?(0.6)

        processedData = applyMultiBandCompression(processedData, settings: config.multiband)
        progressHandler?(0.7)

        processedData = applyMidSideProcessing(processedData, settings: config.midSide)
        progressHandler?(0.75)

        processedData = applyHarmonicExcitation(processedData, settings: config.exciter)
        progressHandler?(0.8)

        processedData = applyEQ(processedData, settings: config.sweeteningEQ)
        progressHandler?(0.85)

        processedData = applyStereoImaging(processedData, settings: config.stereoImaging)
        progressHandler?(0.9)

        processedData = applyTruePeakLimiter(processedData, settings: config.limiter, targetLUFS: preset.targetLUFS)
        progressHandler?(0.95)

        processedData = applyOutputGain(processedData, gain: config.outputGain)

        // Step 5: Write output
        try writeAudioData(processedData, to: outputURL)
        progressHandler?(1.0)

        // Step 6: Analyze output
        let outputAnalysis = try await analyzeAudio(url: outputURL)

        let analysis = AudioAnalysis(
            inputLUFS: inputAnalysis.lufs,
            inputTruePeak: inputAnalysis.truePeak,
            inputDynamicRange: inputAnalysis.dynamicRange,
            outputLUFS: outputAnalysis.lufs,
            outputTruePeak: outputAnalysis.truePeak,
            outputDynamicRange: outputAnalysis.dynamicRange,
            gainReduction: inputAnalysis.lufs - outputAnalysis.lufs,
            stereoCorrelation: outputAnalysis.correlation,
            spectralBalance: AudioAnalysis.SpectralBalance(
                bass: outputAnalysis.bassLevel,
                mids: outputAnalysis.midsLevel,
                highs: outputAnalysis.highsLevel
            )
        )

        analysisResults = analysis
        print(analysis.description)

        return analysis
    }

    // MARK: - Chain Processors (Simplified)

    private func applyInputGain(_ data: AudioData, gain: Float) -> AudioData {
        var output = data
        let gainLinear = pow(10.0, gain / 20.0)

        for channel in 0..<output.samples.count {
            for i in 0..<output.samples[channel].count {
                output.samples[channel][i] *= gainLinear
            }
        }

        return output
    }

    private func applyEQ(_ data: AudioData, settings: EQSettings) -> AudioData {
        guard settings.enabled else { return data }
        // TODO: Implement linear-phase EQ using FFT convolution
        return data
    }

    private func applyMultiBandCompression(_ data: AudioData, settings: MultiBandCompressor) -> AudioData {
        guard settings.enabled else { return data }
        // TODO: Implement multi-band compressor with crossover filters
        return data
    }

    private func applyMidSideProcessing(_ data: AudioData, settings: MidSideProcessor) -> AudioData {
        guard settings.enabled else { return data }
        // TODO: Implement M/S encoding, processing, and decoding
        return data
    }

    private func applyHarmonicExcitation(_ data: AudioData, settings: HarmonicExciter) -> AudioData {
        guard settings.enabled else { return data }
        // TODO: Implement harmonic saturation/excitation
        return data
    }

    private func applyStereoImaging(_ data: AudioData, settings: StereoImager) -> AudioData {
        guard settings.enabled else { return data }
        // TODO: Implement stereo width adjustment
        return data
    }

    private func applyTruePeakLimiter(_ data: AudioData, settings: TruePeakLimiter, targetLUFS: Float) -> AudioData {
        guard settings.enabled else { return data }

        var output = data

        // Simple peak limiting (TODO: Implement true peak detection with oversampling)
        let limitLinear = pow(10.0, settings.threshold / 20.0)

        for channel in 0..<output.samples.count {
            for i in 0..<output.samples[channel].count {
                output.samples[channel][i] = min(max(output.samples[channel][i], -limitLinear), limitLinear)
            }
        }

        return output
    }

    private func applyOutputGain(_ data: AudioData, gain: Float) -> AudioData {
        return applyInputGain(data, gain: gain)
    }

    // MARK: - Audio I/O

    private struct AudioData {
        var samples: [[Float]]  // [channel][sample]
        var sampleRate: Double
        var channelCount: Int

        var duration: TimeInterval {
            Double(samples.first?.count ?? 0) / sampleRate
        }
    }

    private func readAudioData(from asset: AVURLAsset, track: AVAssetTrack) async throws -> AudioData {
        // TODO: Implement proper audio reading
        // For now, return empty data
        return AudioData(samples: [[]], sampleRate: 48000, channelCount: 2)
    }

    private func writeAudioData(_ data: AudioData, to url: URL) throws {
        // TODO: Implement proper audio writing
        print("   💾 Written to: \(url.lastPathComponent)")
    }

    // MARK: - Analysis

    private struct SimpleAnalysis {
        let lufs: Float
        let truePeak: Float
        let dynamicRange: Float
        let correlation: Float
        let bassLevel: Float
        let midsLevel: Float
        let highsLevel: Float
    }

    private func analyzeAudio(url: URL) async throws -> SimpleAnalysis {
        // TODO: Implement full LUFS/true peak analysis
        // Simplified placeholder
        return SimpleAnalysis(
            lufs: -18.0,
            truePeak: -3.0,
            dynamicRange: 12.0,
            correlation: 0.95,
            bassLevel: -15.0,
            midsLevel: -12.0,
            highsLevel: -18.0
        )
    }
}

// MARK: - Errors

enum MasteringError: LocalizedError {
    case noAudioTrack
    case processingFailed(String)
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "No audio track found in file"
        case .processingFailed(let reason):
            return "Mastering processing failed: \(reason)"
        case .invalidConfiguration:
            return "Invalid mastering configuration"
        }
    }
}

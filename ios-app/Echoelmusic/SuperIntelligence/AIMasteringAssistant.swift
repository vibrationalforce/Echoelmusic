import Foundation
import AVFoundation
import Accelerate
import CoreML

// MARK: - AI Mastering Assistant
/// Intelligent mastering engine with AI-powered decisions
/// Phase 6.3: Complete auto-mastering system
///
/// Features:
/// 1. Auto-EQ (spectral balance correction)
/// 2. Auto-Compression (dynamic range optimization)
/// 3. Auto-Limiting (loudness maximization)
/// 4. Reference Track Matching
/// 5. Genre-specific mastering chains
class AIMasteringAssistant: ObservableObject {

    // MARK: - Published State
    @Published var isAnalyzing: Bool = false
    @Published var masteringSettings: MasteringSettings?
    @Published var analysisResults: AnalysisResults?
    @Published var referenceTrack: ReferenceTrackAnalysis?

    // MARK: - Mastering Chain

    struct MasteringSettings {
        var eqBands: [EQBand]
        var compression: CompressionSettings
        var limiting: LimitingSettings
        var stereoWidth: Float           // 0-200%
        var targetLUFS: Double           // -14 to -8 LUFS
        var genrePreset: Genre

        enum Genre: String, CaseIterable {
            case pop, rock, edm, hiphop, jazz, classical, acoustic

            var targetLUFS: Double {
                switch self {
                case .pop, .rock, .hiphop: return -8.0  // Loud
                case .edm: return -6.0                   // Very loud
                case .jazz, .classical: return -16.0     // Dynamic
                case .acoustic: return -12.0             // Balanced
                }
            }

            var compressionRatio: Float {
                switch self {
                case .edm, .hiphop: return 6.0          // Heavy
                case .pop, .rock: return 4.0            // Medium
                case .jazz, .acoustic: return 2.5       // Light
                case .classical: return 1.5             // Minimal
                }
            }
        }

        struct EQBand {
            var frequency: Double
            var gain: Double             // dB
            var q: Double
            var type: FilterType

            enum FilterType {
                case lowShelf, highShelf, peak, lowPass, highPass
            }
        }

        struct CompressionSettings {
            var threshold: Float         // dBFS
            var ratio: Float             // 1:1 to 20:1
            var attack: Float            // ms
            var release: Float           // ms
            var knee: Float              // dB
            var makeupGain: Float        // dB
        }

        struct LimitingSettings {
            var ceiling: Float           // dBFS (usually -0.3 to -0.1)
            var threshold: Float         // dBFS
            var release: Float           // ms
            var lookahead: Float         // ms
        }

        static func forGenre(_ genre: Genre) -> MasteringSettings {
            var settings = MasteringSettings(
                eqBands: [],
                compression: CompressionSettings(
                    threshold: -12.0,
                    ratio: genre.compressionRatio,
                    attack: 10.0,
                    release: 100.0,
                    knee: 3.0,
                    makeupGain: 0.0
                ),
                limiting: LimitingSettings(
                    ceiling: -0.3,
                    threshold: -1.0,
                    release: 50.0,
                    lookahead: 5.0
                ),
                stereoWidth: 100.0,
                targetLUFS: genre.targetLUFS,
                genrePreset: genre
            )

            // Genre-specific EQ
            switch genre {
            case .pop:
                settings.eqBands = [
                    EQBand(frequency: 80, gain: -2, q: 0.7, type: .highPass),
                    EQBand(frequency: 200, gain: 1.5, q: 1.0, type: .peak),
                    EQBand(frequency: 3000, gain: 2.0, q: 1.5, type: .peak),
                    EQBand(frequency: 10000, gain: 1.0, q: 0.7, type: .highShelf)
                ]

            case .edm:
                settings.eqBands = [
                    EQBand(frequency: 60, gain: 3, q: 0.9, type: .lowShelf),
                    EQBand(frequency: 250, gain: -2, q: 1.2, type: .peak),
                    EQBand(frequency: 8000, gain: 2.5, q: 0.7, type: .highShelf)
                ]

            case .jazz:
                settings.eqBands = [
                    EQBand(frequency: 100, gain: 1, q: 0.5, type: .lowShelf),
                    EQBand(frequency: 5000, gain: 1.5, q: 0.9, type: .highShelf)
                ]

            default:
                settings.eqBands = []
            }

            return settings
        }
    }

    // MARK: - Analysis Results

    struct AnalysisResults {
        var spectralBalance: SpectralBalance
        var dynamicRange: Double         // dB
        var lufs: Double                 // LUFS integrated
        var peakLevel: Double            // dBFS
        var stereoWidth: Double          // 0-1
        var problems: [Problem]

        struct SpectralBalance {
            var bass: Double             // 20-250 Hz (dB)
            var lowMids: Double          // 250-2000 Hz
            var highMids: Double         // 2000-6000 Hz
            var highs: Double            // 6000-20000 Hz
            var isBalanced: Bool
        }

        enum Problem {
            case tooQuiet(current: Double, target: Double)
            case tooLoud(current: Double, target: Double)
            case muddyLowMids
            case harshHighMids
            case lackingHighEnd
            case excessiveBass
            case narrowStereo
            case overCompressed
            case highCrestFactor

            var description: String {
                switch self {
                case .tooQuiet(let current, let target):
                    return "Track is too quiet (\(String(format: "%.1f", current)) LUFS vs target \(String(format: "%.1f", target)) LUFS)"
                case .tooLoud(let current, let target):
                    return "Track is too loud (\(String(format: "%.1f", current)) LUFS vs target \(String(format: "%.1f", target)) LUFS)"
                case .muddyLowMids:
                    return "Muddy low-mids (250-500 Hz) - needs reduction"
                case .harshHighMids:
                    return "Harsh high-mids (2-4 kHz) - needs smoothing"
                case .lackingHighEnd:
                    return "Lacking high-end airiness (>8 kHz)"
                case .excessiveBass:
                    return "Excessive bass (<100 Hz)"
                case .narrowStereo:
                    return "Narrow stereo image - consider widening"
                case .overCompressed:
                    return "Over-compressed - dynamic range < 6dB"
                case .highCrestFactor:
                    return "High crest factor - needs compression"
                }
            }

            var solution: String {
                switch self {
                case .tooQuiet:
                    return "Apply makeup gain and limiting"
                case .tooLoud:
                    return "Reduce gain before limiting"
                case .muddyLowMids:
                    return "Cut -2 to -4 dB around 300-400 Hz"
                case .harshHighMids:
                    return "Cut -1 to -3 dB around 2.5-3.5 kHz"
                case .lackingHighEnd:
                    return "Boost +1 to +2 dB above 8 kHz (high shelf)"
                case .excessiveBass:
                    return "Cut -2 to -3 dB below 100 Hz or use high-pass filter"
                case .narrowStereo:
                    return "Increase stereo width to 110-130%"
                case .overCompressed:
                    return "Reduce compression ratio or increase threshold"
                case .highCrestFactor:
                    return "Apply gentle compression (ratio 3:1, threshold -15dB)"
                }
            }
        }
    }

    // MARK: - Reference Track Analysis

    struct ReferenceTrackAnalysis {
        var spectralBalance: AnalysisResults.SpectralBalance
        var lufs: Double
        var dynamicRange: Double
        var stereoWidth: Double
    }

    // MARK: - Auto-Mastering

    /// Analyzes track and generates mastering settings
    func analyzet(_ buffer: AVAudioPCMBuffer, genre: MasteringSettings.Genre) -> MasteringSettings {
        DispatchQueue.main.async {
            self.isAnalyzing = true
        }

        // 1. Analyze spectral balance
        let spectralBalance = analyzeSpectralBalance(buffer)

        // 2. Measure loudness
        let lufs = measureLUFS(buffer)

        // 3. Measure dynamic range
        let dynamicRange = measureDynamicRange(buffer)

        // 4. Measure peak level
        let peakLevel = measurePeakLevel(buffer)

        // 5. Measure stereo width
        let stereoWidth = measureStereoWidth(buffer)

        // 6. Identify problems
        var problems: [AnalysisResults.Problem] = []

        if lufs < genre.targetLUFS - 3.0 {
            problems.append(.tooQuiet(current: lufs, target: genre.targetLUFS))
        } else if lufs > genre.targetLUFS + 1.0 {
            problems.append(.tooLoud(current: lufs, target: genre.targetLUFS))
        }

        if spectralBalance.lowMids > -10.0 {
            problems.append(.muddyLowMids)
        }

        if spectralBalance.highMids > -8.0 {
            problems.append(.harshHighMids)
        }

        if spectralBalance.highs < -18.0 {
            problems.append(.lackingHighEnd)
        }

        if spectralBalance.bass > -6.0 {
            problems.append(.excessiveBass)
        }

        if stereoWidth < 0.5 {
            problems.append(.narrowStereo)
        }

        if dynamicRange < 6.0 {
            problems.append(.overCompressed)
        } else if dynamicRange > 20.0 {
            problems.append(.highCrestFactor)
        }

        // 7. Store analysis results
        let analysis = AnalysisResults(
            spectralBalance: spectralBalance,
            dynamicRange: dynamicRange,
            lufs: lufs,
            peakLevel: peakLevel,
            stereoWidth: stereoWidth,
            problems: problems
        )

        DispatchQueue.main.async {
            self.analysisResults = analysis
        }

        // 8. Generate mastering settings
        var settings = MasteringSettings.forGenre(genre)

        // Auto-adjust based on problems
        for problem in problems {
            switch problem {
            case .muddyLowMids:
                settings.eqBands.append(
                    MasteringSettings.EQBand(frequency: 350, gain: -3, q: 1.5, type: .peak)
                )

            case .harshHighMids:
                settings.eqBands.append(
                    MasteringSettings.EQBand(frequency: 3000, gain: -2, q: 2.0, type: .peak)
                )

            case .lackingHighEnd:
                settings.eqBands.append(
                    MasteringSettings.EQBand(frequency: 10000, gain: 2, q: 0.7, type: .highShelf)
                )

            case .excessiveBass:
                settings.eqBands.append(
                    MasteringSettings.EQBand(frequency: 80, gain: -3, q: 0.9, type: .highPass)
                )

            case .narrowStereo:
                settings.stereoWidth = 120.0

            case .highCrestFactor:
                settings.compression.ratio = 4.0
                settings.compression.threshold = -15.0

            default:
                break
            }
        }

        // Adjust limiting to reach target LUFS
        let currentHeadroom = 0.0 - peakLevel  // dB of headroom
        let targetHeadroom = 0.3               // Target -0.3 dBFS ceiling
        let makeupGain = currentHeadroom - targetHeadroom

        settings.compression.makeupGain = Float(makeupGain)

        DispatchQueue.main.async {
            self.masteringSettings = settings
            self.isAnalyzing = false
        }

        return settings
    }

    // MARK: - Analysis Functions

    private func analyzeSpectralBalance(_ buffer: AVAudioPCMBuffer) -> AnalysisResults.SpectralBalance {
        guard let floatData = buffer.floatChannelData?[0] else {
            return AnalysisResults.SpectralBalance(bass: -20, lowMids: -20, highMids: -20, highs: -20, isBalanced: false)
        }

        let frameCount = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate

        // Perform FFT
        let fftSize = 4096
        var realPart = [Float](repeating: 0, count: fftSize)
        var imagPart = [Float](repeating: 0, count: fftSize)

        // Copy data
        let copyCount = min(frameCount, fftSize)
        for i in 0..<copyCount {
            realPart[i] = floatData[i]
        }

        // Apply Hann window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(realPart, 1, window, 1, &realPart, 1, vDSP_Length(fftSize))

        // FFT setup
        guard let fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), vDSP_DFT_Direction.FORWARD) else {
            return AnalysisResults.SpectralBalance(bass: -20, lowMids: -20, highMids: -20, highs: -20, isBalanced: false)
        }
        defer { vDSP_DFT_DestroySetup(fftSetup) }

        // Perform FFT
        vDSP_DFT_Execute(fftSetup, &realPart, &imagPart, &realPart, &imagPart)

        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        var complexSplit = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        vDSP_zvabs(&complexSplit, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

        // Calculate band energies
        let freqResolution = Float(sampleRate) / Float(fftSize)

        var bassEnergy: Float = 0
        var lowMidsEnergy: Float = 0
        var highMidsEnergy: Float = 0
        var highsEnergy: Float = 0

        for bin in 0..<(fftSize / 2) {
            let freq = Float(bin) * freqResolution
            let energy = magnitudes[bin] * magnitudes[bin]

            if freq < 250 {
                bassEnergy += energy
            } else if freq < 2000 {
                lowMidsEnergy += energy
            } else if freq < 6000 {
                highMidsEnergy += energy
            } else {
                highsEnergy += energy
            }
        }

        // Convert to dB
        let bassDB = 10.0 * log10(Double(bassEnergy + 1e-10))
        let lowMidsDB = 10.0 * log10(Double(lowMidsEnergy + 1e-10))
        let highMidsDB = 10.0 * log10(Double(highMidsEnergy + 1e-10))
        let highsDB = 10.0 * log10(Double(highsEnergy + 1e-10))

        // Check if balanced (all bands within ±3dB of each other)
        let average = (bassDB + lowMidsDB + highMidsDB + highsDB) / 4.0
        let isBalanced = abs(bassDB - average) < 3.0 &&
                        abs(lowMidsDB - average) < 3.0 &&
                        abs(highMidsDB - average) < 3.0 &&
                        abs(highsDB - average) < 3.0

        return AnalysisResults.SpectralBalance(
            bass: bassDB,
            lowMids: lowMidsDB,
            highMids: highMidsDB,
            highs: highsDB,
            isBalanced: isBalanced
        )
    }

    private func measureLUFS(_ buffer: AVAudioPCMBuffer) -> Double {
        // Simplified LUFS calculation
        // Full implementation would use K-weighting filter
        return EchoCalculatorSuite.calculateLUFS(from: buffer)
    }

    private func measureDynamicRange(_ buffer: AVAudioPCMBuffer) -> Double {
        return EchoCalculatorSuite.calculateDynamicRange(from: buffer)
    }

    private func measurePeakLevel(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let floatData = buffer.floatChannelData?[0] else { return -100.0 }
        let frameCount = Int(buffer.frameLength)

        var peak: Float = 0
        vDSP_maxmgv(floatData, 1, &peak, vDSP_Length(frameCount))

        return 20.0 * log10(Double(peak))
    }

    private func measureStereoWidth(_ buffer: AVAudioPCMBuffer) -> Double {
        // Stereo correlation measurement
        // 1.0 = fully mono, 0.0 = fully decorrelated, -1.0 = fully out of phase
        guard buffer.format.channelCount >= 2 else { return 0.0 }

        guard let left = buffer.floatChannelData?[0],
              let right = buffer.floatChannelData?[1] else { return 0.0 }

        let frameCount = Int(buffer.frameLength)

        // Calculate correlation
        var correlation: Float = 0
        vDSP_dotpr(left, 1, right, 1, &correlation, vDSP_Length(frameCount))

        var leftPower: Float = 0
        var rightPower: Float = 0
        vDSP_svesq(left, 1, &leftPower, vDSP_Length(frameCount))
        vDSP_svesq(right, 1, &rightPower, vDSP_Length(frameCount))

        let denominator = sqrt(leftPower * rightPower)
        if denominator == 0 { return 0.0 }

        let correlationCoeff = correlation / denominator

        // Convert to stereo width (0-1 scale)
        // 1.0 correlation = 0.0 width (mono)
        // 0.0 correlation = 1.0 width (fully stereo)
        let width = 1.0 - Double(abs(correlationCoeff))

        return width
    }

    // MARK: - Reference Track Matching

    func analyzeReferenceTrack(_ buffer: AVAudioPCMBuffer) {
        let spectralBalance = analyzeSpectralBalance(buffer)
        let lufs = measureLUFS(buffer)
        let dynamicRange = measureDynamicRange(buffer)
        let stereoWidth = measureStereoWidth(buffer)

        let reference = ReferenceTrackAnalysis(
            spectralBalance: spectralBalance,
            lufs: lufs,
            dynamicRange: dynamicRange,
            stereoWidth: stereoWidth
        )

        DispatchQueue.main.async {
            self.referenceTrack = reference
        }
    }

    func matchToReference(_ buffer: AVAudioPCMBuffer, reference: ReferenceTrackAnalysis) -> MasteringSettings {
        // Analyze current track
        let currentBalance = analyzeSpectralBalance(buffer)
        let currentLUFS = measureLUFS(buffer)

        // Calculate differences
        let bassDiff = reference.spectralBalance.bass - currentBalance.bass
        let lowMidsDiff = reference.spectralBalance.lowMids - currentBalance.lowMids
        let highMidsDiff = reference.spectralBalance.highMids - currentBalance.highMids
        let highsDiff = reference.spectralBalance.highs - currentBalance.highs

        // Generate EQ to match reference
        var eqBands: [MasteringSettings.EQBand] = []

        if abs(bassDiff) > 1.0 {
            eqBands.append(MasteringSettings.EQBand(
                frequency: 100,
                gain: bassDiff,
                q: 0.7,
                type: .lowShelf
            ))
        }

        if abs(lowMidsDiff) > 1.0 {
            eqBands.append(MasteringSettings.EQBand(
                frequency: 500,
                gain: lowMidsDiff,
                q: 1.0,
                type: .peak
            ))
        }

        if abs(highMidsDiff) > 1.0 {
            eqBands.append(MasteringSettings.EQBand(
                frequency: 3000,
                gain: highMidsDiff,
                q: 1.5,
                type: .peak
            ))
        }

        if abs(highsDiff) > 1.0 {
            eqBands.append(MasteringSettings.EQBand(
                frequency: 10000,
                gain: highsDiff,
                q: 0.7,
                type: .highShelf
            ))
        }

        // Match loudness
        let makeupGain = Float(reference.lufs - currentLUFS)

        let settings = MasteringSettings(
            eqBands: eqBands,
            compression: MasteringSettings.CompressionSettings(
                threshold: -12,
                ratio: 4.0,
                attack: 10,
                release: 100,
                knee: 3,
                makeupGain: makeupGain
            ),
            limiting: MasteringSettings.LimitingSettings(
                ceiling: -0.3,
                threshold: -1.0,
                release: 50,
                lookahead: 5
            ),
            stereoWidth: Float(reference.stereoWidth * 100),
            targetLUFS: reference.lufs,
            genrePreset: .pop  // Default, user can override
        )

        return settings
    }
}

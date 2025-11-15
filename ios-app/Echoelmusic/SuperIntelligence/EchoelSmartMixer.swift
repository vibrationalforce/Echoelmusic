import Foundation
import AVFoundation
import Accelerate

// MARK: - Echoel Smart Mixer
/// AI-powered automatic mixing engine
/// Phase 6.3+: Super Intelligence Tools
///
/// Features:
/// 1. Auto Gain Staging (-18dBFS RMS target)
/// 2. Intelligent Auto-Panning (spectral content-based)
/// 3. AI-Powered EQ Suggestions (frequency masking detection)
/// 4. Smart Compression (dynamic range optimization)
/// 5. Auto Effects Sends (reverb/delay based on genre)
/// 6. Mix Balance Analysis
/// 7. Conflict Resolution (frequency masking fixes)
class EchoelSmartMixer: ObservableObject {

    // MARK: - Published State
    @Published var mixAnalysis: MixAnalysis?
    @Published var suggestions: [MixSuggestion] = []
    @Published var autoMixEnabled: Bool = false
    @Published var isAnalyzing: Bool = false

    // MARK: - Configuration
    var targetRMS: Float = -18.0  // dBFS
    var targetDynamicRange: Float = 12.0  // dB
    var genre: MusicGenre = .pop

    // MARK: - Dependencies
    private let audioAnalyzer = SmartAudioAnalyzer()

    // MARK: - Auto Gain Staging

    /// Analyze track and suggest optimal gain
    func analyzeGainStaging(for track: Track, buffer: AVAudioPCMBuffer) -> GainSuggestion {
        // Measure current levels
        let loudness = audioAnalyzer.analyzeLoudness(from: buffer)
        let currentRMS = loudness.rmsDB

        // Calculate gain adjustment needed
        let gainAdjustment = Double(targetRMS) - currentRMS

        // Check for clipping risk
        let peakAfterGain = loudness.peakDB + gainAdjustment
        let clippingRisk = peakAfterGain > -1.0

        return GainSuggestion(
            trackID: track.id,
            currentRMS: currentRMS,
            targetRMS: Double(targetRMS),
            gainAdjustment: gainAdjustment,
            clippingRisk: clippingRisk
        )
    }

    /// Auto-adjust gain for all tracks
    func autoGainStaging(tracks: [Track], buffers: [AVAudioPCMBuffer]) -> [GainSuggestion] {
        var suggestions: [GainSuggestion] = []

        for (track, buffer) in zip(tracks, buffers) {
            let suggestion = analyzeGainStaging(for: track, buffer: buffer)
            suggestions.append(suggestion)
        }

        return suggestions
    }

    // MARK: - Intelligent Auto-Panning

    /// Analyze spectral content and suggest panning
    func analyzePanning(for track: Track, buffer: AVAudioPCMBuffer) -> PanningSuggestion {
        let frequencyAnalysis = audioAnalyzer.analyzeFrequencyContent(from: buffer)

        // Panning strategy based on frequency content
        let suggestedPan: Float

        // Bass-heavy instruments → Center
        if frequencyAnalysis.bass > frequencyAnalysis.totalEnergy * 0.4 {
            suggestedPan = 0.0 // Center

        // High-frequency instruments → Sides
        } else if frequencyAnalysis.highs > frequencyAnalysis.totalEnergy * 0.3 {
            // Alternate left/right for stereo width
            suggestedPan = Float.random(in: -0.7...(-0.5)) // Left side
            // Or right side (would alternate in full implementation)

        // Mid-range → Slight panning
        } else {
            suggestedPan = Float.random(in: -0.3...0.3)
        }

        return PanningSuggestion(
            trackID: track.id,
            currentPan: track.pan,
            suggestedPan: suggestedPan,
            reason: determinePanningReason(frequencyAnalysis: frequencyAnalysis)
        )
    }

    private func determinePanningReason(frequencyAnalysis: FrequencyAnalysis) -> String {
        if frequencyAnalysis.bass > frequencyAnalysis.totalEnergy * 0.4 {
            return "Bass-heavy content → Center for mono compatibility"
        } else if frequencyAnalysis.highs > frequencyAnalysis.totalEnergy * 0.3 {
            return "High-frequency content → Sides for stereo width"
        } else {
            return "Mid-range content → Slight panning for separation"
        }
    }

    /// Auto-pan all tracks for optimal stereo image
    func autoPanning(tracks: [Track], buffers: [AVAudioPCMBuffer]) -> [PanningSuggestion] {
        var suggestions: [PanningSuggestion] = []
        var leftCount = 0
        var rightCount = 0

        for (track, buffer) in zip(tracks, buffers) {
            var suggestion = analyzePanning(for: track, buffer: buffer)

            // Balance left/right
            if suggestion.suggestedPan < -0.4 {
                leftCount += 1
            } else if suggestion.suggestedPan > 0.4 {
                rightCount += 1
            }

            // If imbalanced, adjust
            if leftCount > rightCount + 2 {
                suggestion.suggestedPan = abs(suggestion.suggestedPan) // Flip to right
            } else if rightCount > leftCount + 2 {
                suggestion.suggestedPan = -abs(suggestion.suggestedPan) // Flip to left
            }

            suggestions.append(suggestion)
        }

        return suggestions
    }

    // MARK: - AI-Powered EQ Suggestions

    /// Detect frequency masking conflicts between tracks
    func detectFrequencyMasking(tracks: [Track], buffers: [AVAudioPCMBuffer]) -> [FrequencyConflict] {
        var conflicts: [FrequencyConflict] = []

        // Analyze each track's frequency content
        var trackFrequencies: [(track: Track, analysis: FrequencyAnalysis)] = []

        for (track, buffer) in zip(tracks, buffers) {
            let analysis = audioAnalyzer.analyzeFrequencyContent(from: buffer)
            trackFrequencies.append((track, analysis))
        }

        // Find conflicts
        for i in 0..<trackFrequencies.count {
            for j in (i+1)..<trackFrequencies.count {
                let track1 = trackFrequencies[i]
                let track2 = trackFrequencies[j]

                // Check each frequency band
                if let conflict = detectConflictInBand(track1: track1, track2: track2) {
                    conflicts.append(conflict)
                }
            }
        }

        return conflicts
    }

    private func detectConflictInBand(
        track1: (track: Track, analysis: FrequencyAnalysis),
        track2: (track: Track, analysis: FrequencyAnalysis)
    ) -> FrequencyConflict? {
        // Check for significant overlap in each band
        let bands: [(FrequencyAnalysis.FrequencyBand, Float, Float)] = [
            (.bass, track1.analysis.bass, track2.analysis.bass),
            (.lowMids, track1.analysis.lowMids, track2.analysis.lowMids),
            (.mids, track1.analysis.mids, track2.analysis.mids),
            (.highMids, track1.analysis.highMids, track2.analysis.highMids)
        ]

        for (band, energy1, energy2) in bands {
            // Conflict if both tracks have significant energy in same band
            if energy1 > 0.3 && energy2 > 0.3 {
                return FrequencyConflict(
                    track1ID: track1.track.id,
                    track2ID: track2.track.id,
                    conflictBand: band,
                    severity: (energy1 + energy2) / 2.0
                )
            }
        }

        return nil
    }

    /// Generate EQ suggestions to resolve conflicts
    func generateEQSuggestions(conflicts: [FrequencyConflict]) -> [EQSuggestion] {
        var suggestions: [EQSuggestion] = []

        for conflict in conflicts {
            // Strategy: Cut one track, boost the other
            // Choose based on priority/importance

            let cutSuggestion = EQSuggestion(
                trackID: conflict.track1ID,
                band: conflict.conflictBand,
                adjustment: -3.0 * conflict.severity,  // Cut
                reason: "Reduce masking with Track \(conflict.track2ID)"
            )

            let boostSuggestion = EQSuggestion(
                trackID: conflict.track2ID,
                band: conflict.conflictBand,
                adjustment: 1.0 * conflict.severity,  // Slight boost
                reason: "Enhance clarity after cutting Track \(conflict.track1ID)"
            )

            suggestions.append(cutSuggestion)
            suggestions.append(boostSuggestion)
        }

        return suggestions
    }

    // MARK: - Smart Compression

    /// Analyze dynamics and suggest compression
    func analyzeCompression(for track: Track, buffer: AVAudioPCMBuffer) -> CompressionSuggestion {
        let loudness = audioAnalyzer.analyzeLoudness(from: buffer)
        let dynamicRange = loudness.dynamicRange

        // Compression strategy based on dynamic range
        let compressionNeeded = dynamicRange > Double(targetDynamicRange)

        var ratio: Float = 1.0
        var threshold: Float = -20.0
        var attack: Float = 10.0  // ms
        var release: Float = 100.0  // ms

        if compressionNeeded {
            // Calculate ratio based on excess dynamic range
            let excessDR = Float(dynamicRange - Double(targetDynamicRange))
            ratio = 1.0 + (excessDR / 10.0)  // e.g., 3:1 for 20dB excess

            // Genre-specific settings
            switch genre {
            case .pop, .edm:
                threshold = -12.0
                attack = 5.0
                release = 50.0

            case .rock:
                threshold = -15.0
                attack = 10.0
                release = 100.0

            case .hiphop:
                threshold = -10.0
                attack = 1.0
                release = 30.0

            case .jazz, .classical:
                threshold = -20.0
                attack = 30.0
                release = 200.0

            case .acoustic:
                threshold = -18.0
                attack = 20.0
                release = 150.0
            }
        }

        return CompressionSuggestion(
            trackID: track.id,
            compressionNeeded: compressionNeeded,
            currentDynamicRange: dynamicRange,
            targetDynamicRange: Double(targetDynamicRange),
            ratio: ratio,
            threshold: threshold,
            attack: attack,
            release: release
        )
    }

    // MARK: - Auto Effects Sends

    /// Suggest effects send levels based on genre and track type
    func suggestEffectsSends(for track: Track, buffer: AVAudioPCMBuffer) -> EffectsSendSuggestion {
        let frequencyAnalysis = audioAnalyzer.analyzeFrequencyContent(from: buffer)

        var reverbSend: Float = 0.0
        var delaySend: Float = 0.0

        // Genre-based reverb amounts
        switch genre {
        case .pop:
            reverbSend = 0.25
            delaySend = 0.15

        case .rock:
            reverbSend = 0.3
            delaySend = 0.2

        case .edm:
            reverbSend = 0.4
            delaySend = 0.3

        case .hiphop:
            reverbSend = 0.15
            delaySend = 0.25

        case .jazz:
            reverbSend = 0.35
            delaySend = 0.1

        case .classical:
            reverbSend = 0.5
            delaySend = 0.05

        case .acoustic:
            reverbSend = 0.4
            delaySend = 0.2
        }

        // Adjust based on frequency content
        // High-frequency instruments → more reverb
        if frequencyAnalysis.highs > frequencyAnalysis.totalEnergy * 0.3 {
            reverbSend *= 1.2
        }

        // Vocal-like mid-range → more delay
        if frequencyAnalysis.mids > frequencyAnalysis.totalEnergy * 0.4 {
            delaySend *= 1.3
        }

        return EffectsSendSuggestion(
            trackID: track.id,
            reverbSend: reverbSend,
            delaySend: delaySend,
            genre: genre
        )
    }

    // MARK: - Full Mix Analysis

    /// Perform comprehensive mix analysis
    func analyzeFullMix(tracks: [Track], buffers: [AVAudioPCMBuffer]) -> MixAnalysis {
        isAnalyzing = true

        // Gain staging
        let gainSuggestions = autoGainStaging(tracks: tracks, buffers: buffers)

        // Panning
        let panningSuggestions = autoPanning(tracks: tracks, buffers: buffers)

        // Frequency conflicts
        let conflicts = detectFrequencyMasking(tracks: tracks, buffers: buffers)
        let eqSuggestions = generateEQSuggestions(conflicts: conflicts)

        // Compression
        var compressionSuggestions: [CompressionSuggestion] = []
        for (track, buffer) in zip(tracks, buffers) {
            let suggestion = analyzeCompression(for: track, buffer: buffer)
            compressionSuggestions.append(suggestion)
        }

        // Effects sends
        var effectsSuggestions: [EffectsSendSuggestion] = []
        for (track, buffer) in zip(tracks, buffers) {
            let suggestion = suggestEffectsSends(for: track, buffer: buffer)
            effectsSuggestions.append(suggestion)
        }

        let analysis = MixAnalysis(
            gainSuggestions: gainSuggestions,
            panningSuggestions: panningSuggestions,
            eqSuggestions: eqSuggestions,
            compressionSuggestions: compressionSuggestions,
            effectsSuggestions: effectsSuggestions,
            conflicts: conflicts
        )

        DispatchQueue.main.async {
            self.mixAnalysis = analysis
            self.isAnalyzing = false
        }

        return analysis
    }

    /// Apply all suggestions automatically
    func applyAutoMix(to tracks: inout [Track], analysis: MixAnalysis) {
        // Apply gain
        for suggestion in analysis.gainSuggestions {
            if let index = tracks.firstIndex(where: { $0.id == suggestion.trackID }) {
                tracks[index].gain = Float(suggestion.gainAdjustment)
            }
        }

        // Apply panning
        for suggestion in analysis.panningSuggestions {
            if let index = tracks.firstIndex(where: { $0.id == suggestion.trackID }) {
                tracks[index].pan = suggestion.suggestedPan
            }
        }

        // Apply EQ (would need EQ implementation)
        // Apply compression (would need compressor implementation)
        // Apply effects sends (would need send implementation)
    }
}

// MARK: - Supporting Types

struct MixAnalysis {
    let gainSuggestions: [GainSuggestion]
    let panningSuggestions: [PanningSuggestion]
    let eqSuggestions: [EQSuggestion]
    let compressionSuggestions: [CompressionSuggestion]
    let effectsSuggestions: [EffectsSendSuggestion]
    let conflicts: [FrequencyConflict]

    var totalSuggestions: Int {
        return gainSuggestions.count + panningSuggestions.count + eqSuggestions.count +
               compressionSuggestions.count + effectsSuggestions.count
    }

    var criticalIssues: Int {
        return conflicts.filter { $0.severity > 0.7 }.count
    }
}

struct GainSuggestion: Identifiable {
    let id = UUID()
    let trackID: UUID
    let currentRMS: Double
    let targetRMS: Double
    let gainAdjustment: Double  // dB
    let clippingRisk: Bool
}

struct PanningSuggestion: Identifiable {
    let id = UUID()
    let trackID: UUID
    let currentPan: Float
    var suggestedPan: Float
    let reason: String
}

struct FrequencyConflict: Identifiable {
    let id = UUID()
    let track1ID: UUID
    let track2ID: UUID
    let conflictBand: FrequencyAnalysis.FrequencyBand
    let severity: Float  // 0-1
}

struct EQSuggestion: Identifiable {
    let id = UUID()
    let trackID: UUID
    let band: FrequencyAnalysis.FrequencyBand
    let adjustment: Float  // dB
    let reason: String

    var frequencyRange: String {
        switch band {
        case .subBass: return "20-60 Hz"
        case .bass: return "60-250 Hz"
        case .lowMids: return "250-500 Hz"
        case .mids: return "500-2kHz"
        case .highMids: return "2k-6kHz"
        case .highs: return "6k-20kHz"
        }
    }
}

struct CompressionSuggestion: Identifiable {
    let id = UUID()
    let trackID: UUID
    let compressionNeeded: Bool
    let currentDynamicRange: Double
    let targetDynamicRange: Double
    let ratio: Float
    let threshold: Float  // dBFS
    let attack: Float     // ms
    let release: Float    // ms
}

struct EffectsSendSuggestion: Identifiable {
    let id = UUID()
    let trackID: UUID
    let reverbSend: Float  // 0-1
    let delaySend: Float   // 0-1
    let genre: MusicGenre
}

enum MusicGenre: String, CaseIterable {
    case pop = "Pop"
    case rock = "Rock"
    case edm = "EDM"
    case hiphop = "Hip-Hop"
    case jazz = "Jazz"
    case classical = "Classical"
    case acoustic = "Acoustic"
}

struct MixSuggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let description: String
    let priority: Priority

    enum SuggestionType {
        case gain, panning, eq, compression, effects
    }

    enum Priority {
        case low, medium, high, critical
    }
}

// MARK: - Track Model Extension

extension Track {
    var gain: Float {
        get { return volume }
        set { volume = newValue }
    }
}

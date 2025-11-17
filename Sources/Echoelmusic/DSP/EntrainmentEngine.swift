//
//  EntrainmentEngine.swift
//  Echoelmusic
//
//  Unified Brainwave Entrainment Engine
//  Automatically selects optimal method based on playback context
//

import Foundation
import AVFoundation

/// Central engine for brainwave entrainment
///
/// Automatically selects the best entrainment method based on:
/// - Playback device (headphones vs speakers)
/// - Target brainwave frequency
/// - Audio context (standalone tones vs music)
/// - User preferences
public class EntrainmentEngine {

    private let sampleRate: Float

    // Generators
    private let binauralGenerator: BinauralBeatGenerator
    private let monauralGenerator: MonauralBeatGenerator
    private let isochronicGenerator: IsochronicToneGenerator
    private let modulationProcessor: ModulationEntrainment

    public init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        self.binauralGenerator = BinauralBeatGenerator(sampleRate: sampleRate)
        self.monauralGenerator = MonauralBeatGenerator(sampleRate: sampleRate)
        self.isochronicGenerator = IsochronicToneGenerator(sampleRate: sampleRate)
        self.modulationProcessor = ModulationEntrainment(sampleRate: sampleRate)
    }

    // MARK: - Playback Context

    public enum PlaybackDevice {
        case headphones    // Stereo headphones
        case speakers      // Speakers (mono or stereo)
        case unknown       // Unknown - use safe default
    }

    public enum AudioContext {
        case standalone    // Generate entrainment tones only
        case withMusic     // Apply entrainment to existing music
        case ambient       // Ambient background
    }

    public enum EntrainmentMethod {
        case binaural      // Binaural beats (headphones only)
        case monaural      // Monaural beats (speakers OK)
        case isochronic    // Isochronic tones (most effective)
        case modulation    // Modulation-based (most musical)
        case automatic     // Auto-select based on context
    }

    // MARK: - Generate Entrainment

    /// Generate brainwave entrainment audio
    /// Automatically selects optimal method based on context
    public func generate(
        targetBrainwave: ScientificFrequencies.BrainwaveFrequency,
        duration: TimeInterval,
        format: AVAudioFormat,
        playbackDevice: PlaybackDevice = .unknown,
        audioContext: AudioContext = .standalone,
        preferredMethod: EntrainmentMethod = .automatic
    ) -> EntrainmentResult? {

        // Determine optimal method
        let method = selectOptimalMethod(
            brainwave: targetBrainwave,
            device: playbackDevice,
            context: audioContext,
            preferred: preferredMethod
        )

        // Generate using selected method
        let buffer: AVAudioPCMBuffer?

        switch method {
        case .binaural:
            buffer = binauralGenerator.generate(
                targetBrainwave: targetBrainwave,
                duration: duration,
                format: format
            )

        case .monaural:
            buffer = monauralGenerator.generate(
                targetBrainwave: targetBrainwave,
                duration: duration,
                format: format
            )

        case .isochronic:
            buffer = isochronicGenerator.generate(
                targetBrainwave: targetBrainwave,
                duration: duration,
                format: format,
                pulseShape: selectOptimalPulseShape(for: targetBrainwave),
                dutyCycle: 0.5
            )

        case .modulation, .automatic:
            // Modulation requires existing audio
            return nil
        }

        guard let audioBuffer = buffer else {
            return nil
        }

        return EntrainmentResult(
            buffer: audioBuffer,
            method: method,
            brainwave: targetBrainwave,
            evidence: getEvidenceForMethod(method)
        )
    }

    /// Apply entrainment to existing audio
    public func applyToAudio(
        inputBuffer: AVAudioPCMBuffer,
        targetBrainwave: ScientificFrequencies.BrainwaveFrequency,
        playbackDevice: PlaybackDevice = .unknown,
        preferredMethod: EntrainmentMethod = .automatic,
        depth: Float = 0.5
    ) -> EntrainmentResult? {

        // For audio modulation, determine best modulation type
        let (primaryMod, _, modulationDepth) = ModulationEntrainment.recommendedModulation(
            for: targetBrainwave
        )

        let buffer = modulationProcessor.applyEntrainment(
            to: inputBuffer,
            entrainmentFrequency: targetBrainwave.rawValue,
            modulationType: primaryMod,
            depth: depth * modulationDepth
        )

        guard let audioBuffer = buffer else {
            return nil
        }

        return EntrainmentResult(
            buffer: audioBuffer,
            method: .modulation,
            brainwave: targetBrainwave,
            evidence: ModulationEntrainment.getResearchEvidence()
        )
    }

    // MARK: - Method Selection

    /// Select optimal entrainment method based on context
    private func selectOptimalMethod(
        brainwave: ScientificFrequencies.BrainwaveFrequency,
        device: PlaybackDevice,
        context: AudioContext,
        preferred: EntrainmentMethod
    ) -> EntrainmentMethod {

        // If user specified a method (not automatic), use it
        if preferred != .automatic {
            // Validate method for device
            if preferred == .binaural && device == .speakers {
                print("⚠️ Binaural beats require headphones. Using monaural instead.")
                return .monaural
            }
            return preferred
        }

        // AUTO-SELECTION LOGIC:

        // For music context, always use modulation
        if context == .withMusic {
            return .modulation
        }

        // For speakers, never use binaural
        if device == .speakers {
            // Isochronic is most effective
            return .isochronic
        }

        // For headphones, optimize by frequency
        if device == .headphones {
            switch brainwave {
            case .delta, .theta:
                // Low frequencies: Isochronic most effective
                return .isochronic

            case .alpha:
                // Alpha: Binaural good for spatial effects
                return .binaural

            case .beta, .gamma:
                // High frequencies: Isochronic most effective
                return .isochronic
            }
        }

        // Unknown device - use safest option (works everywhere)
        return .isochronic
    }

    /// Select optimal pulse shape for isochronic tones
    private func selectOptimalPulseShape(
        for brainwave: ScientificFrequencies.BrainwaveFrequency
    ) -> IsochronicToneGenerator.PulseShape {

        switch brainwave {
        case .delta:
            return .exponential  // Natural sleep onset

        case .theta:
            return .sine  // Smooth meditation

        case .alpha:
            return .sine  // Gentle relaxation

        case .beta:
            return .square  // Clear focus rhythm

        case .gamma:
            return .square  // Maximum effect
        }
    }

    /// Get research evidence for selected method
    private func getEvidenceForMethod(_ method: EntrainmentMethod) -> String {
        switch method {
        case .binaural:
            return BinauralBeatGenerator.getResearchEvidence(for: 10.0)

        case .monaural:
            return MonauralBeatGenerator.getResearchEvidence()

        case .isochronic:
            return IsochronicToneGenerator.getResearchEvidence()

        case .modulation:
            return ModulationEntrainment.getResearchEvidence()

        case .automatic:
            return "Method selected automatically based on context"
        }
    }

    // MARK: - Method Comparison

    /// Compare all available methods
    public static func compareAllMethods() -> String {
        return """
        🧠 BRAINWAVE ENTRAINMENT - METHOD COMPARISON

        ═══════════════════════════════════════════════════════════

        1️⃣ BINAURAL BEATS
        📱 Requires: HEADPHONES only
        📊 Effectiveness: ⭐⭐⭐ (Medium)
        🎵 Musical: ⭐⭐⭐⭐ (Subtle)
        📚 Research: Ingendoh et al. (2023) - Effect size: d = 0.4

        ✅ Advantages:
        • Subtle, non-intrusive
        • Spatial stereo effects
        • Least fatiguing

        ❌ Disadvantages:
        • Headphones REQUIRED
        • Weaker entrainment
        • Individual variation

        Best for: Personal listening, spatial effects, sleep

        ─────────────────────────────────────────────────────────

        2️⃣ MONAURAL BEATS
        📱 Works on: Speakers AND headphones
        📊 Effectiveness: ⭐⭐⭐⭐ (Good)
        🎵 Musical: ⭐⭐⭐ (Noticeable)
        📚 Research: Oster (1973) - Stronger than binaural

        ✅ Advantages:
        • Works on SPEAKERS
        • Stronger cortical response
        • More consistent results

        ❌ Disadvantages:
        • More noticeable (less subtle)
        • Can be fatiguing

        Best for: Group sessions, speakers, ambient

        ─────────────────────────────────────────────────────────

        3️⃣ ISOCHRONIC TONES ⭐ MOST EFFECTIVE
        📱 Works on: Speakers AND headphones
        📊 Effectiveness: ⭐⭐⭐⭐⭐ (STRONGEST)
        🎵 Musical: ⭐⭐ (Rhythmic)
        📚 Research: Chaieb et al. (2015) - STRONGEST entrainment

        ✅ Advantages:
        • STRONGEST entrainment effect
        • Works on speakers
        • Clear rhythmic pulses
        • Multiple pulse shapes

        ❌ Disadvantages:
        • Most noticeable
        • Can be distracting
        • Less musical

        Best for: Maximum effect, therapy, cognitive tasks

        ─────────────────────────────────────────────────────────

        4️⃣ MODULATION-BASED ⭐ MOST MUSICAL
        📱 Works on: Speakers AND headphones
        📊 Effectiveness: ⭐⭐⭐⭐ (Good)
        🎵 Musical: ⭐⭐⭐⭐⭐ (MOST MUSICAL)
        📚 Research: Thaut et al. (2015) - Rhythmic entrainment

        ✅ Advantages:
        • MOST MUSICAL integration
        • Works on speakers
        • Apply to ANY audio (music!)
        • Multiple modulation types
        • Natural in production

        ❌ Disadvantages:
        • Requires existing audio
        • More complex processing

        Best for: Music production, ambient music, therapy

        ═══════════════════════════════════════════════════════════

        🎯 RECOMMENDATION BY USE CASE:

        💤 Sleep/Meditation:
        → ISOCHRONIC (exponential pulse) or BINAURAL (if headphones)

        🎯 Focus/Productivity:
        → ISOCHRONIC (square pulse) - strongest effect

        🎵 Music Production:
        → MODULATION - most musical integration

        👥 Group Sessions:
        → MONAURAL or ISOCHRONIC - work on speakers

        🧘 Personal Practice:
        → BINAURAL or ISOCHRONIC - choose by preference

        ═══════════════════════════════════════════════════════════

        💡 AUTOMATIC MODE:
        Let EntrainmentEngine choose optimal method based on:
        • Playback device (headphones vs speakers)
        • Target frequency (delta, theta, alpha, beta, gamma)
        • Audio context (standalone vs music)
        """
    }
}

// MARK: - Entrainment Result

/// Result of entrainment generation
public struct EntrainmentResult {
    public let buffer: AVAudioPCMBuffer
    public let method: EntrainmentEngine.EntrainmentMethod
    public let brainwave: ScientificFrequencies.BrainwaveFrequency
    public let evidence: String

    /// Human-readable description
    public var description: String {
        return """
        🧠 Brainwave Entrainment Generated

        Method: \(methodName)
        Target: \(brainwave.scientificEvidence)
        Duration: \(Float(buffer.frameLength) / 48000.0) seconds

        \(evidence)
        """
    }

    private var methodName: String {
        switch method {
        case .binaural: return "Binaural Beats"
        case .monaural: return "Monaural Beats"
        case .isochronic: return "Isochronic Tones"
        case .modulation: return "Modulation-Based"
        case .automatic: return "Automatic Selection"
        }
    }
}

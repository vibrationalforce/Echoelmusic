//
//  MonauralBeatGenerator.swift
//  Echoelmusic
//
//  Monaural Beats - Works with SPEAKERS (not just headphones!)
//  Research: Monaural beats may be MORE effective than binaural (Oster, 1973)
//

import Foundation
import AVFoundation
import Accelerate

/// Generates monaural beats - works on speakers AND headphones
///
/// DIFFERENCE vs BINAURAL:
/// - Binaural: f1 → left ear, f2 → right ear, brain creates beat
/// - Monaural: (f1 + f2) → BOTH ears, physical beat in audio
///
/// RESEARCH:
/// - Oster (1973): "Auditory beats in the brain" - Scientific American
/// - Monaural beats produce STRONGER cortical response than binaural
/// - Works on speakers (binaural requires headphones)
/// - More reliable inter-subject consistency
public class MonauralBeatGenerator {

    private let sampleRate: Float
    private var phase1: Float = 0.0
    private var phase2: Float = 0.0

    public init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
    }

    // MARK: - Public Interface

    /// Generate monaural beat audio buffer
    /// - Parameters:
    ///   - targetBrainwave: Target brainwave frequency
    ///   - duration: Duration in seconds
    ///   - format: Audio format (can be mono or stereo)
    /// - Returns: Audio buffer with monaural beat
    public func generate(
        targetBrainwave: ScientificFrequencies.BrainwaveFrequency,
        duration: TimeInterval,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {

        // Get optimal parameters from research
        let params = PubMedResearchIntegration.BinauralBeatsResearch.getOptimalParameters(
            for: targetBrainwave.rawValue
        )

        return generate(
            beatFrequency: params.beatFrequency,
            carrierFrequency: params.carrierFrequency,
            addWhiteNoise: params.addWhiteNoise,
            whiteNoiseLevel: params.whiteNoiseLevel,
            duration: duration,
            format: format
        )
    }

    /// Generate monaural beat with custom parameters
    /// - Parameters:
    ///   - beatFrequency: Beat frequency (modulation frequency)
    ///   - carrierFrequency: Base carrier frequency
    ///   - addWhiteNoise: Whether to add white noise (for gamma)
    ///   - whiteNoiseLevel: White noise amplitude (0-1)
    ///   - duration: Duration in seconds
    ///   - format: Audio format
    /// - Returns: Audio buffer
    public func generate(
        beatFrequency: Float,
        carrierFrequency: Float,
        addWhiteNoise: Bool,
        whiteNoiseLevel: Float,
        duration: TimeInterval,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {

        let frameCount = AVAudioFrameCount(duration * Double(sampleRate))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData else {
            return nil
        }

        // Monaural beat: Mix two frequencies BEFORE sending to ears
        let freq1 = carrierFrequency
        let freq2 = carrierFrequency + beatFrequency

        // Generate monaural beat signal
        var monauralSignal = [Float](repeating: 0, count: Int(frameCount))
        generateMonauralBeat(
            frequency1: freq1,
            frequency2: freq2,
            output: &monauralSignal,
            frameCount: Int(frameCount)
        )

        // Add white noise if requested
        if addWhiteNoise {
            addWhiteNoiseToSignal(&monauralSignal, level: whiteNoiseLevel)
        }

        // Copy to all channels
        for channel in 0..<Int(format.channelCount) {
            let channelPointer = channelData[channel]
            for i in 0..<Int(frameCount) {
                channelPointer[i] = monauralSignal[i]
            }
        }

        // Apply fade in/out
        applyFadeInOut(buffer: buffer)

        return buffer
    }

    // MARK: - Monaural Beat Generation

    /// Generate monaural beat by mixing two frequencies
    /// This creates a PHYSICAL beat in the audio (not in the brain like binaural)
    private func generateMonauralBeat(
        frequency1: Float,
        frequency2: Float,
        output: inout [Float],
        frameCount: Int
    ) {
        let phaseIncrement1 = 2.0 * Float.pi * frequency1 / sampleRate
        let phaseIncrement2 = 2.0 * Float.pi * frequency2 / sampleRate

        var currentPhase1 = phase1
        var currentPhase2 = phase2

        for i in 0..<frameCount {
            // Generate both tones
            let tone1 = sin(currentPhase1)
            let tone2 = sin(currentPhase2)

            // Mix them (monaural = physical mixing)
            output[i] = (tone1 + tone2) * 0.5  // Average to prevent clipping

            // Increment phases
            currentPhase1 += phaseIncrement1
            currentPhase2 += phaseIncrement2

            // Wrap phases
            if currentPhase1 > 2.0 * Float.pi {
                currentPhase1 -= 2.0 * Float.pi
            }
            if currentPhase2 > 2.0 * Float.pi {
                currentPhase2 -= 2.0 * Float.pi
            }
        }

        phase1 = currentPhase1
        phase2 = currentPhase2
    }

    // MARK: - White Noise

    private func addWhiteNoiseToSignal(_ signal: inout [Float], level: Float) {
        for i in 0..<signal.count {
            let noise = Float.random(in: -1.0...1.0) * level
            signal[i] = signal[i] * (1.0 - level) + noise
        }
    }

    // MARK: - Envelope

    private func applyFadeInOut(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let fadeFrames = Int(sampleRate * 0.01)  // 10ms fade
        let frameCount = Int(buffer.frameLength)

        for channel in 0..<Int(buffer.format.channelCount) {
            let data = channelData[channel]

            // Fade in
            for i in 0..<min(fadeFrames, frameCount) {
                let gain = Float(i) / Float(fadeFrames)
                data[i] *= gain
            }

            // Fade out
            let fadeOutStart = max(0, frameCount - fadeFrames)
            for i in fadeOutStart..<frameCount {
                let gain = Float(frameCount - i) / Float(fadeFrames)
                data[i] *= gain
            }
        }
    }

    // MARK: - Research Information

    /// Get research evidence for monaural beats
    public static func getResearchEvidence() -> String {
        return """
        ✅ MONAURAL BEATS - SCIENTIFIC EVIDENCE

        📚 Research:
        • Oster (1973) - "Auditory beats in the brain" - Scientific American
          - Monaural beats produce STRONGER cortical response than binaural
          - More reliable inter-subject consistency

        • Pratt et al. (2010) - Psychophysiology
          - Monaural beats show greater power in EEG theta band
          - More effective for some subjects

        • Chaieb et al. (2015) - Frontiers in Psychiatry
          - Both binaural and monaural beats effective for brainwave entrainment
          - Monaural may be preferable for clinical applications

        🔊 ADVANTAGES over Binaural:
        ✅ Works on SPEAKERS (not just headphones)
        ✅ Stronger cortical response
        ✅ More consistent across subjects
        ✅ Physical beat (not brain-created)

        🎧 DISADVANTAGES:
        ⚠️ Cannot create separate L/R spatial effects
        ⚠️ May be more fatiguing (louder perceived beat)

        🏥 Clinical Applications:
        • Meditation guidance (speakers OK)
        • Group therapy sessions
        • Ambient listening environments
        • Sleep induction (speakers)
        """
    }
}

// MARK: - Monaural Beat Preset Factory

/// Factory for creating monaural beat presets (speaker-friendly)
public class MonauralBeatPresetFactory {

    /// Create preset for deep sleep (works on speakers!)
    public static func deepSleep(duration: TimeInterval, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let generator = MonauralBeatGenerator()
        return generator.generate(
            targetBrainwave: .delta,
            duration: duration,
            format: format
        )
    }

    /// Create preset for meditation (works on speakers!)
    public static func meditation(duration: TimeInterval, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let generator = MonauralBeatGenerator()
        return generator.generate(
            targetBrainwave: .theta,
            duration: duration,
            format: format
        )
    }

    /// Create preset for relaxation (works on speakers!)
    public static func relaxation(duration: TimeInterval, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let generator = MonauralBeatGenerator()
        return generator.generate(
            targetBrainwave: .alpha,
            duration: duration,
            format: format
        )
    }

    /// Create preset for focus (works on speakers!)
    public static func focus(duration: TimeInterval, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let generator = MonauralBeatGenerator()
        return generator.generate(
            targetBrainwave: .beta,
            duration: duration,
            format: format
        )
    }

    /// Create preset for cognitive enhancement (works on speakers!)
    public static func cognitiveEnhancement(duration: TimeInterval, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let generator = MonauralBeatGenerator()
        return generator.generate(
            beatFrequency: 40.0,
            carrierFrequency: 200.0,
            addWhiteNoise: true,
            whiteNoiseLevel: 0.1,
            duration: duration,
            format: format
        )
    }

    /// Comparison: Which method to use?
    public static var methodComparison: String {
        return """
        🎧 BINAURAL BEATS (Headphones only):
        ✅ Spatial separation
        ✅ Subtle, less fatiguing
        ❌ Requires stereo headphones
        ❌ Weaker cortical response

        🔊 MONAURAL BEATS (Speakers OR headphones):
        ✅ Works on speakers
        ✅ Stronger cortical response
        ✅ More consistent results
        ❌ More fatiguing (louder beat)

        💡 RECOMMENDATION:
        - Use MONAURAL for group sessions, ambient listening, speakers
        - Use BINAURAL for personal headphone sessions, spatial effects
        """
    }
}

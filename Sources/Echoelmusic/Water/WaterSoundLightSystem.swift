import Foundation
import AVFoundation
import Accelerate
import Combine
import CoreMotion

/// Water Sound Light Swimming Pool System
/// Wasserklanglichtschwimmbad - Innovative vibration technology for aquatic experiences
/// Integration with syng.visibra vibration pontoons and underwater speakers
///
/// Features:
/// - Vibroacoustic swimming pool therapy
/// - Floating vibration pontoons
/// - Underwater speaker systems
/// - Infraschall & Körperschall (Infrasound & Body sound)
/// - Light synchronization with sound
/// - Bio-reactive water experiences
@MainActor
class WaterSoundLightSystem: ObservableObject {

    // MARK: - Vibration Technology

    /// Custom vibration technology for heavy loads (swimming pools)
    /// Designed for syng.visibra brand
    class VibrationPontoon {

        enum PontoonSize {
            case personal      // 1-2 persons
            case therapy       // Clinical therapy bed
            case group         // Small group (4-6)
            case pool          // Full pool vibration

            var loadCapacity: Float {
                switch self {
                case .personal: return 150.0  // kg
                case .therapy: return 300.0
                case .group: return 600.0
                case .pool: return 5000.0
                }
            }

            var transducerCount: Int {
                switch self {
                case .personal: return 4
                case .therapy: return 8
                case .group: return 16
                case .pool: return 32
                }
            }
        }

        struct VibrationCharacteristics {
            let frequencyRange: ClosedRange<Float> // Hz
            let amplitudeMax: Float // mm displacement
            let powerRating: Float // Watts
            let waterproof: Bool
            let mountingType: MountingType

            enum MountingType {
                case floating      // On water surface
                case submerged     // Underwater
                case poolWall      // Mounted to pool structure
                case floor         // Pool floor
            }
        }

        // Vibration frequency bands for different effects
        static let frequencyBands: [String: ClosedRange<Float>] = [
            "Infrasound": 1...20,           // Below hearing, felt in body
            "SubBass": 20...60,             // Deep bass, full body vibration
            "Bass": 60...250,               // Tactile bass
            "LowMid": 250...500,            // Body resonance
            "Mid": 500...2000,              // Muscle/tissue resonance
            "HighMid": 2000...8000,         // Surface vibration
            "High": 8000...20000            // Skin/nerve stimulation
        ]

        func synthesizeVibrationSignal(
            frequencyBand: String,
            therapy: TherapyType,
            duration: TimeInterval = 1800
        ) -> AVAudioPCMBuffer {

            guard let freqRange = Self.frequencyBands[frequencyBand] else {
                return AVAudioPCMBuffer()
            }

            let sampleRate: Double = 48000
            let frameCount = AVAudioFrameCount(duration * sampleRate)

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!,
                frameCapacity: frameCount
            ) else {
                return AVAudioPCMBuffer()
            }

            buffer.frameLength = frameCount

            guard let leftChannel = buffer.floatChannelData?[0],
                  let rightChannel = buffer.floatChannelData?[1] else {
                return buffer
            }

            // Select center frequency based on therapy type
            let centerFreq: Float
            let modulation: Float

            switch therapy {
            case .relaxation:
                centerFreq = freqRange.lowerBound + (freqRange.upperBound - freqRange.lowerBound) * 0.3
                modulation = 0.2 // Gentle

            case .pain:
                centerFreq = freqRange.lowerBound + (freqRange.upperBound - freqRange.lowerBound) * 0.5
                modulation = 0.4 // Medium intensity

            case .circulation:
                centerFreq = freqRange.lowerBound + (freqRange.upperBound - freqRange.lowerBound) * 0.7
                modulation = 0.6 // Pulsing

            case .meditation:
                centerFreq = freqRange.lowerBound + (freqRange.upperBound - freqRange.lowerBound) * 0.2
                modulation = 0.1 // Very gentle

            case .energizing:
                centerFreq = freqRange.lowerBound + (freqRange.upperBound - freqRange.lowerBound) * 0.8
                modulation = 0.7 // Strong

            case .healing:
                centerFreq = 528.0 // Love/DNA frequency if in range, otherwise center
                modulation = 0.3
            }

            for frame in 0..<Int(frameCount) {
                let t = Float(frame) / Float(sampleRate)

                // Base vibration frequency
                let vibration = sin(2.0 * .pi * centerFreq * t)

                // Slow modulation for pulsing effect
                let pulse = 1.0 - modulation + modulation * sin(2.0 * .pi * 0.2 * t)

                // Add subtle harmonics for richer vibration
                let harmonic2 = 0.3 * sin(2.0 * .pi * centerFreq * 2.0 * t)
                let harmonic3 = 0.15 * sin(2.0 * .pi * centerFreq * 3.0 * t)

                let combined = (vibration + harmonic2 + harmonic3) * pulse * 0.5

                leftChannel[frame] = combined
                rightChannel[frame] = combined
            }

            return buffer
        }

        enum TherapyType {
            case relaxation
            case pain
            case circulation
            case meditation
            case energizing
            case healing
        }
    }

    // MARK: - Underwater Speaker System

    class UnderwaterSpeakerSystem {

        struct SpeakerConfiguration {
            let speakerCount: Int
            let positioning: PoolPositioning
            let frequencyResponse: ClosedRange<Float>
            let maxSPL: Float // Sound Pressure Level in water
            let waterDepth: Float // meters

            enum PoolPositioning {
                case corners        // 4 corners
                case walls          // Distributed on walls
                case floor          // Floor mounted
                case floating       // Floating speakers
                case surround       // Full surround (8+)
            }
        }

        /// Generate special underwater audio
        /// Sound travels 4.3x faster in water than air
        /// Frequencies below 1kHz work best underwater
        func synthesizeUnderwaterAudio(
            program: UnderwaterProgram,
            duration: TimeInterval = 1800
        ) -> AVAudioPCMBuffer {

            let sampleRate: Double = 48000
            let frameCount = AVAudioFrameCount(duration * sampleRate)

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!,
                frameCapacity: frameCount
            ) else {
                return AVAudioPCMBuffer()
            }

            buffer.frameLength = frameCount

            guard let leftChannel = buffer.floatChannelData?[0],
                  let rightChannel = buffer.floatChannelData?[1] else {
                return buffer
            }

            switch program {
            case .dolphinSounds:
                generateDolphinCommunication(leftChannel: leftChannel, rightChannel: rightChannel, frameCount: Int(frameCount), sampleRate: sampleRate)

            case .whalesSongs:
                generateWhaleSongs(leftChannel: leftChannel, rightChannel: rightChannel, frameCount: Int(frameCount), sampleRate: sampleRate)

            case .oceanWaves:
                generateUnderwaterOceanAmbience(leftChannel: leftChannel, rightChannel: rightChannel, frameCount: Int(frameCount), sampleRate: sampleRate)

            case .healingFrequencies:
                generateUnderwaterHealingFrequencies(leftChannel: leftChannel, rightChannel: rightChannel, frameCount: Int(frameCount), sampleRate: sampleRate)

            case .rhythmicBeats:
                generateUnderwaterBeats(leftChannel: leftChannel, rightChannel: rightChannel, frameCount: Int(frameCount), sampleRate: sampleRate)

            case .meditation:
                generateUnderwaterMeditation(leftChannel: leftChannel, rightChannel: rightChannel, frameCount: Int(frameCount), sampleRate: sampleRate)
            }

            return buffer
        }

        enum UnderwaterProgram {
            case dolphinSounds
            case whalesSongs
            case oceanWaves
            case healingFrequencies
            case rhythmicBeats
            case meditation
        }

        // MARK: - Underwater Audio Generators

        private func generateDolphinCommunication(leftChannel: UnsafeMutablePointer<Float>, rightChannel: UnsafeMutablePointer<Float>, frameCount: Int, sampleRate: Double) {
            // Dolphins: whistles 2-20 kHz, clicks up to 150 kHz (we'll use lower range for underwater speakers)
            for frame in 0..<frameCount {
                let t = Float(frame) / Float(sampleRate)

                // Characteristic dolphin whistle (frequency modulated)
                let whistleFreq: Float = 2000.0 + 4000.0 * sin(2.0 * .pi * 2.0 * t)
                let whistle = 0.2 * sin(2.0 * .pi * whistleFreq * t)

                // Click trains (echolocation)
                let clickRate: Float = 600.0 // Hz
                let clickPhase = fmod(t * clickRate, 1.0)
                let click = clickPhase < 0.1 ? 0.3 * sin(2.0 * .pi * 8000.0 * clickPhase * 10.0) : 0

                let combined = (whistle + click) * 0.15

                leftChannel[frame] = combined
                rightChannel[frame] = combined
            }
        }

        private func generateWhaleSongs(leftChannel: UnsafeMutablePointer<Float>, rightChannel: UnsafeMutablePointer<Float>, frameCount: Int, sampleRate: Double) {
            // Whale songs: very low frequencies 20-4000 Hz, complex patterns
            for frame in 0..<frameCount {
                let t = Float(frame) / Float(sampleRate)

                // Deep rumbling bass
                let bass = 0.2 * sin(2.0 * .pi * 30.0 * t)

                // Melodic elements
                let melodyFreq: Float = 200.0 + 300.0 * sin(2.0 * .pi * 0.05 * t)
                let melody = 0.15 * sin(2.0 * .pi * melodyFreq * t)

                // Harmonic overtones
                let overtone = 0.08 * sin(2.0 * .pi * melodyFreq * 2.5 * t)

                // Slow amplitude modulation (song phrases)
                let phrase = 0.5 + 0.5 * sin(2.0 * .pi * 0.02 * t)

                let combined = (bass + (melody + overtone) * phrase) * 0.2

                leftChannel[frame] = combined
                rightChannel[frame] = combined
            }
        }

        private func generateUnderwaterOceanAmbience(leftChannel: UnsafeMutablePointer<Float>, rightChannel: UnsafeMutablePointer<Float>, frameCount: Int, sampleRate: Double) {
            // Ocean ambience felt underwater
            for frame in 0..<frameCount {
                let t = Float(frame) / Float(sampleRate)

                // Low frequency wave motion
                var ocean: Float = 0
                for harmonic in 1...5 {
                    ocean += (0.15 / Float(harmonic)) * sin(2.0 * .pi * Float(harmonic) * 0.1 * t)
                }

                // Gentle bubbles (higher frequency noise bursts)
                let bubbles = Float.random(in: -0.05...0.05) * abs(sin(2.0 * .pi * 10.0 * t))

                let combined = ocean + bubbles

                leftChannel[frame] = combined
                rightChannel[frame] = combined
            }
        }

        private func generateUnderwaterHealingFrequencies(leftChannel: UnsafeMutablePointer<Float>, rightChannel: UnsafeMutablePointer<Float>, frameCount: Int, sampleRate: Double) {
            // Solfeggio and healing frequencies optimized for water transmission
            let healingFreqs: [Float] = [
                174.0,  // Pain reduction
                285.0,  // Tissue healing
                396.0,  // Liberation
                528.0   // DNA repair (most effective underwater)
            ]

            for frame in 0..<frameCount {
                let t = Float(frame) / Float(sampleRate)

                var combined: Float = 0

                for (index, freq) in healingFreqs.enumerated() {
                    // Stagger frequencies for complex healing field
                    let phase = t + Float(index) * 0.25
                    combined += (1.0 / Float(healingFreqs.count)) * sin(2.0 * .pi * freq * phase)
                }

                combined *= 0.2

                leftChannel[frame] = combined
                rightChannel[frame] = combined
            }
        }

        private func generateUnderwaterBeats(leftChannel: UnsafeMutablePointer<Float>, rightChannel: UnsafeMutablePointer<Float>, frameCount: Int, sampleRate: Double) {
            // Rhythmic beats felt through water
            let bpm: Float = 90.0
            let beatsPerSecond = bpm / 60.0
            let samplesPerBeat = Int(Float(sampleRate) / beatsPerSecond)

            for frame in 0..<frameCount {
                let beatPhase = frame % samplesPerBeat
                let beatT = Float(beatPhase) / Float(samplesPerBeat)

                // Low frequency pulse (best transmission underwater)
                let pulseFreq: Float = 60.0 + 120.0 * exp(-beatT * 15)
                let pulseEnv = exp(-beatT * 8)
                let pulse = sin(2.0 * .pi * pulseFreq * beatT) * pulseEnv * 0.3

                leftChannel[frame] = pulse
                rightChannel[frame] = pulse
            }
        }

        private func generateUnderwaterMeditation(leftChannel: UnsafeMutablePointer<Float>, rightChannel: UnsafeMutablePointer<Float>, frameCount: Int, sampleRate: Double) {
            // Deep meditation frequencies for floating/suspension
            for frame in 0..<frameCount {
                let t = Float(frame) / Float(sampleRate)

                // OM frequency (very stable underwater)
                let om = 0.15 * sin(2.0 * .pi * 136.1 * t)

                // Schumann resonance harmonics
                let schumann = 0.1 * sin(2.0 * .pi * 7.83 * t)

                // Very slow breathing rhythm
                let breath = 0.05 * sin(2.0 * .pi * 0.2 * t) // ~12 breaths/min

                let combined = om + schumann + breath

                leftChannel[frame] = combined
                rightChannel[frame] = combined
            }
        }
    }

    // MARK: - Integrated Water Experience

    class IntegratedWaterExperience {

        struct WaterProgram {
            let name: String
            let duration: TimeInterval
            let vibrationBands: [String] // Frequency bands to activate
            let underwaterAudio: UnderwaterSpeakerSystem.UnderwaterProgram
            let lightPattern: LightPattern
            let temperature: Float // °C
            let therapyGoal: TherapyGoal

            enum LightPattern {
                case sunset
                case ocean
                case aurora
                case chakra
                case synchronized // Sync with audio
                case stars
                case rainbow
            }

            enum TherapyGoal {
                case relaxation
                case painRelief
                case meditation
                case energizing
                case healing
                case prenatal // For pregnant women
                case rehabilitation
                case sensoryIntegration
            }
        }

        static let programs: [WaterProgram] = [
            WaterProgram(
                name: "Deep Relaxation Float",
                duration: 3600,
                vibrationBands: ["Infrasound", "SubBass"],
                underwaterAudio: .oceanWaves,
                lightPattern: .sunset,
                temperature: 34.0, // Skin temperature for sensory isolation
                therapyGoal: .relaxation
            ),

            WaterProgram(
                name: "Dolphin Therapy",
                duration: 1800,
                vibrationBands: ["SubBass", "Bass", "LowMid"],
                underwaterAudio: .dolphinSounds,
                lightPattern: .ocean,
                temperature: 32.0,
                therapyGoal: .sensoryIntegration
            ),

            WaterProgram(
                name: "Chakra Healing Waters",
                duration: 2400,
                vibrationBands: ["SubBass", "Bass", "LowMid", "Mid"],
                underwaterAudio: .healingFrequencies,
                lightPattern: .chakra,
                temperature: 36.0,
                therapyGoal: .healing
            ),

            WaterProgram(
                name: "Rhythmic Dance Pool",
                duration: 1200,
                vibrationBands: ["Bass", "LowMid", "Mid"],
                underwaterAudio: .rhythmicBeats,
                lightPattern: .synchronized,
                temperature: 28.0,
                therapyGoal: .energizing
            ),

            WaterProgram(
                name: "Prenatal Floating Meditation",
                duration: 3600,
                vibrationBands: ["Infrasound", "SubBass"],
                underwaterAudio: .meditation,
                lightPattern: .aurora,
                temperature: 35.0, // Amniotic fluid temperature
                therapyGoal: .prenatal
            ),

            WaterProgram(
                name: "Pain Relief Hydrotherapy",
                duration: 2400,
                vibrationBands: ["Infrasound", "SubBass", "Bass"],
                underwaterAudio: .healingFrequencies,
                lightPattern: .sunset,
                temperature: 38.0, // Warm for muscle relaxation
                therapyGoal: .painRelief
            ),

            WaterProgram(
                name: "Whale Song Meditation",
                duration: 3600,
                vibrationBands: ["Infrasound", "SubBass"],
                underwaterAudio: .whalesSongs,
                lightPattern: .ocean,
                temperature: 33.0,
                therapyGoal: .meditation
            )
        ]

        /// Generate multi-channel output for complete water experience
        /// Returns separate buffers for different frequency bands (multi-channel output)
        func generateCompleteExperience(program: WaterProgram) -> [String: AVAudioPCMBuffer] {
            var outputs: [String: AVAudioPCMBuffer] = [:]

            let pontoon = VibrationPontoon()
            let speakers = UnderwaterSpeakerSystem()

            // Generate vibration signals for each frequency band
            for band in program.vibrationBands {
                let therapy: VibrationPontoon.TherapyType

                switch program.therapyGoal {
                case .relaxation, .prenatal: therapy = .relaxation
                case .painRelief, .rehabilitation: therapy = .pain
                case .meditation: therapy = .meditation
                case .energizing: therapy = .energizing
                case .healing, .sensoryIntegration: therapy = .healing
                }

                let vibrationBuffer = pontoon.synthesizeVibrationSignal(
                    frequencyBand: band,
                    therapy: therapy,
                    duration: program.duration
                )

                outputs["Vibration_\(band)"] = vibrationBuffer
            }

            // Generate underwater audio
            let underwaterBuffer = speakers.synthesizeUnderwaterAudio(
                program: program.underwaterAudio,
                duration: program.duration
            )

            outputs["Underwater_Audio"] = underwaterBuffer

            return outputs
        }
    }

    // MARK: - Bio-Reactive Water Experience

    class BioReactiveWater {

        /// Adjust water experience based on biometric data
        func adjustToHeartRate(
            currentHR: Float,
            targetHR: Float,
            currentProgram: IntegratedWaterExperience.WaterProgram
        ) -> IntegratedWaterExperience.WaterProgram {

            var adjusted = currentProgram

            if currentHR > targetHR + 10 {
                // Too activated - increase relaxation
                adjusted.vibrationBands = ["Infrasound", "SubBass"]
                adjusted.underwaterAudio = .meditation
                adjusted.temperature = min(36.0, currentProgram.temperature + 1.0)

            } else if currentHR < targetHR - 10 {
                // Too relaxed - increase stimulation
                adjusted.vibrationBands = ["Bass", "LowMid", "Mid"]
                adjusted.underwaterAudio = .rhythmicBeats
                adjusted.temperature = max(28.0, currentProgram.temperature - 1.0)
            }

            return adjusted
        }

        /// Adjust based on HRV coherence
        func adjustToHRVCoherence(
            coherence: Float, // 0.0 - 1.0
            currentProgram: IntegratedWaterExperience.WaterProgram
        ) -> IntegratedWaterExperience.WaterProgram {

            var adjusted = currentProgram

            if coherence > 0.7 {
                // High coherence - maintain healing state
                adjusted.underwaterAudio = .healingFrequencies
                adjusted.vibrationBands = ["SubBass", "Bass"]

            } else if coherence < 0.3 {
                // Low coherence - help regulate
                adjusted.underwaterAudio = .meditation
                adjusted.vibrationBands = ["Infrasound", "SubBass"]
            }

            return adjusted
        }
    }
}

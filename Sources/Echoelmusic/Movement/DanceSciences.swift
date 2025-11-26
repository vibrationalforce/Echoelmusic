import Foundation
import AVFoundation
import Accelerate
import Combine
import CoreMotion

/// Dance Sciences - Comprehensive dance tradition integration
/// Von Stammestänzen über Barock und Klassik zu Jazz, Rave, Krumping, Ecstatic Dance
@MainActor
class DanceSciences: ObservableObject {

    enum DanceTradition: String, CaseIterable {
        // Tribal & Indigenous
        case tribalAfrican = "Afrikanischer Stammestanz"
        case tribalNativeAmerican = "Nativ Amerikanisch"
        case tribalMaori = "Maori Haka"
        case tribalAboriginal = "Aboriginal"

        // Historical European
        case baroque = "Barock (Menuett, Gavotte)"
        case classical = "Klassischer Tanz (Walzer, Polka)"
        case renaissance = "Renaissance (Pavane, Galliard)"

        // Classical Ballet
        case ballet = "Klassisches Ballett"
        case contemporaryBallet = "Zeitgenössisches Ballett"
        case neoclassical = "Neoklassisch"

        // Jazz & Swing
        case jazzDance = "Jazz Dance"
        case swing = "Swing (Lindy Hop, Charleston)"
        case tap = "Stepptanz"

        // Latin & Ballroom
        case salsa = "Salsa"
        case tango = "Tango"
        case samba = "Samba"
        case waltz = "Walzer"

        // Street & Hip Hop
        case breakdance = "Breakdance"
        case hiphop = "Hip Hop"
        case krumping = "Krumping"
        case popping = "Popping"
        case locking = "Locking"
        case house = "House Dance"

        // Electronic & Rave
        case rave = "Rave Dance"
        case techno = "Techno Dancing"
        case trance = "Trance Dance"
        case shuffle = "Melbourne Shuffle"
        case gloving = "Gloving"

        // Contemporary & Modern
        case modern = "Modern Dance"
        case contemporary = "Contemporary"
        case contactImprovisation = "Kontaktimprovisation"

        // Ecstatic & Therapeutic
        case ecstaticDance = "Ecstatic Dance"
        case fiverhythms = "5Rhythms"
        case biodanza = "Biodanza"
        case tantricDance = "Tantrischer Tanz"
        case sufiWhirling = "Sufi Wirbeln"
        case shakti = "Shakti Dance"

        // Cultural
        case flamenco = "Flamenco"
        case belly = "Bauchtanz"
        case irish = "Irischer Tanz"
        case bollywood = "Bollywood"
        case hula = "Hula"
        case capoeira = "Capoeira"
    }

    // MARK: - Dance Characteristics

    struct DanceCharacteristics {
        let bpm: ClosedRange<Float>
        let timeSignature: String
        let intensity: Float // 0.0 - 1.0
        let rhythmComplexity: Float
        let movementStyle: MovementStyle
        let culturalOrigin: String
        let therapeuticBenefits: [String]

        enum MovementStyle {
            case flowing
            case sharp
            case bouncing
            case grounded
            case aerial
            case rhythmic
            case trance
            case explosive
        }
    }

    // MARK: - Dance Database

    static let danceCharacteristics: [DanceTradition: DanceCharacteristics] = [
        // Tribal
        .tribalAfrican: DanceCharacteristics(
            bpm: 100...140,
            timeSignature: "4/4, 6/8, 12/8",
            intensity: 0.7,
            rhythmComplexity: 0.9,
            movementStyle: .grounded,
            culturalOrigin: "Afrika",
            therapeuticBenefits: ["Erdung", "Gemeinschaft", "Rhythmusgefühl", "Vitalität"]
        ),

        // Baroque
        .baroque: DanceCharacteristics(
            bpm: 60...80,
            timeSignature: "3/4, 4/4",
            intensity: 0.3,
            rhythmComplexity: 0.5,
            movementStyle: .flowing,
            culturalOrigin: "Europa 1600-1750",
            therapeuticBenefits: ["Eleganz", "Haltung", "Koordination", "Achtsamkeit"]
        ),

        // Classical Ballet
        .ballet: DanceCharacteristics(
            bpm: 60...120,
            timeSignature: "3/4, 4/4",
            intensity: 0.8,
            rhythmComplexity: 0.7,
            movementStyle: .aerial,
            culturalOrigin: "Europa/Russland",
            therapeuticBenefits: ["Kraft", "Flexibilität", "Disziplin", "Ausdruck"]
        ),

        // Jazz Dance
        .jazzDance: DanceCharacteristics(
            bpm: 90...140,
            timeSignature: "4/4",
            intensity: 0.7,
            rhythmComplexity: 0.7,
            movementStyle: .sharp,
            culturalOrigin: "USA",
            therapeuticBenefits: ["Koordination", "Energie", "Ausdruck", "Freude"]
        ),

        // Krumping
        .krumping: DanceCharacteristics(
            bpm: 90...120,
            timeSignature: "4/4",
            intensity: 1.0,
            rhythmComplexity: 0.8,
            movementStyle: .explosive,
            culturalOrigin: "USA (Los Angeles)",
            therapeuticBenefits: ["Emotionsausdruck", "Aggression transformieren", "Empowerment", "Katharsis"]
        ),

        // Rave
        .rave: DanceCharacteristics(
            bpm: 130...150,
            timeSignature: "4/4",
            intensity: 0.9,
            rhythmComplexity: 0.6,
            movementStyle: .bouncing,
            culturalOrigin: "UK/Europa 1980er",
            therapeuticBenefits: ["Endorphine", "Gemeinschaft", "Trance", "Ekstase"]
        ),

        // Ecstatic Dance
        .ecstaticDance: DanceCharacteristics(
            bpm: 80...140,
            timeSignature: "Frei",
            intensity: 0.6,
            rhythmComplexity: 0.5,
            movementStyle: .trance,
            culturalOrigin: "Global/Modern",
            therapeuticBenefits: ["Selbstausdruck", "Meditation", "Heilung", "Transformation", "Integration"]
        ),

        // 5Rhythms
        .fiverhythms: DanceCharacteristics(
            bpm: 60...160,
            timeSignature: "Variabel",
            intensity: 0.7,
            rhythmComplexity: 0.6,
            movementStyle: .flowing,
            culturalOrigin: "USA (Gabrielle Roth)",
            therapeuticBenefits: ["Selbsterkenntnis", "Emotionsarbeit", "Kreativität", "Heilung"]
        ),

        // Salsa
        .salsa: DanceCharacteristics(
            bpm: 150...180,
            timeSignature: "4/4",
            intensity: 0.7,
            rhythmComplexity: 0.8,
            movementStyle: .rhythmic,
            culturalOrigin: "Kuba/Puerto Rico",
            therapeuticBenefits: ["Lebensfreude", "Partnerschaft", "Koordination", "Ausdauer"]
        ),

        // Flamenco
        .flamenco: DanceCharacteristics(
            bpm: 120...200,
            timeSignature: "3/4, 6/8, 12/8",
            intensity: 0.9,
            rhythmComplexity: 0.95,
            movementStyle: .sharp,
            culturalOrigin: "Spanien (Andalusien)",
            therapeuticBenefits: ["Leidenschaft", "Ausdruck", "Erdung", "Stolz"]
        ),

        // Sufi Whirling
        .sufiWhirling: DanceCharacteristics(
            bpm: 80...100,
            timeSignature: "4/4, 7/8",
            intensity: 0.6,
            rhythmComplexity: 0.7,
            movementStyle: .trance,
            culturalOrigin: "Türkei/Persien",
            therapeuticBenefits: ["Meditation", "Zentrierung", "Trance", "Spiritualität", "Hingabe"]
        )
    ]

    // MARK: - Music Generation for Dance

    class DanceMusicGenerator {

        func generateDanceMusic(tradition: DanceTradition, duration: TimeInterval = 300) -> AVAudioPCMBuffer {
            guard let characteristics = DanceSciences.danceCharacteristics[tradition] else {
                return AVAudioPCMBuffer()
            }

            let sampleRate: Double = 48000
            let frameCount = AVAudioFrameCount(duration * sampleRate)

            guard let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!, frameCapacity: frameCount) else {
                return AVAudioPCMBuffer()
            }

            buffer.frameLength = frameCount

            guard let leftChannel = buffer.floatChannelData?[0],
                  let rightChannel = buffer.floatChannelData?[1] else {
                return buffer
            }

            // Use middle of BPM range
            let bpm = (characteristics.bpm.lowerBound + characteristics.bpm.upperBound) / 2.0
            let beatsPerSecond = bpm / 60.0
            let samplesPerBeat = Int(Float(sampleRate) / beatsPerSecond)

            switch characteristics.movementStyle {
            case .grounded:
                generateGroundedRhythm(leftChannel: leftChannel, rightChannel: rightChannel, frameCount: Int(frameCount), samplesPerBeat: samplesPerBeat, sampleRate: sampleRate, intensity: characteristics.intensity)

            case .flowing:
                generateFlowingMelody(leftChannel: leftChannel, rightChannel: rightChannel, frameCount: Int(frameCount), bpm: bpm, sampleRate: sampleRate, intensity: characteristics.intensity)

            case .sharp:
                generateSharpRhythm(leftChannel: leftChannel, rightChannel: rightChannel, frameCount: Int(frameCount), samplesPerBeat: samplesPerBeat, sampleRate: sampleRate, intensity: characteristics.intensity)

            case .explosive:
                generateExplosiveBeats(leftChannel: leftChannel, rightChannel: rightChannel, frameCount: Int(frameCount), samplesPerBeat: samplesPerBeat, sampleRate: sampleRate, intensity: characteristics.intensity)

            case .trance:
                generateTranceMusic(leftChannel: leftChannel, rightChannel: rightChannel, frameCount: Int(frameCount), bpm: bpm, sampleRate: sampleRate, intensity: characteristics.intensity)

            case .rhythmic:
                generateComplexRhythm(leftChannel: leftChannel, rightChannel: rightChannel, frameCount: Int(frameCount), samplesPerBeat: samplesPerBeat, sampleRate: sampleRate, complexity: characteristics.rhythmComplexity, intensity: characteristics.intensity)

            case .bouncing:
                generateBouncingBeat(leftChannel: leftChannel, rightChannel: rightChannel, frameCount: Int(frameCount), samplesPerBeat: samplesPerBeat, sampleRate: sampleRate, intensity: characteristics.intensity)

            case .aerial:
                generateAerialMelody(leftChannel: leftChannel, rightChannel: rightChannel, frameCount: Int(frameCount), bpm: bpm, sampleRate: sampleRate, intensity: characteristics.intensity)
            }

            return buffer
        }

        // MARK: - Movement Style Generators

        private func generateGroundedRhythm(leftChannel: UnsafeMutablePointer<Float>, rightChannel: UnsafeMutablePointer<Float>, frameCount: Int, samplesPerBeat: Int, sampleRate: Double, intensity: Float) {
            // Deep, earthy drums
            for frame in 0..<frameCount {
                let beatPhase = frame % samplesPerBeat
                let beatT = Float(beatPhase) / Float(samplesPerBeat)

                // Deep bass drum
                let kickFreq: Float = 60.0 + 40.0 * exp(-beatT * 20)
                let kickEnv = exp(-beatT * 8)
                let kick = sin(2.0 * .pi * kickFreq * beatT) * kickEnv

                // Add polyrhythmic complexity (3 against 4)
                let poly = frame % (samplesPerBeat * 3 / 4)
                let polyT = Float(poly) / Float(samplesPerBeat * 3 / 4)
                let polyDrum = sin(2.0 * .pi * 120.0 * polyT) * exp(-polyT * 10) * 0.3

                let combined = (kick + polyDrum) * intensity * 0.3

                leftChannel[frame] = combined
                rightChannel[frame] = combined
            }
        }

        private func generateFlowingMelody(leftChannel: UnsafeMutablePointer<Float>, rightChannel: UnsafeMutablePointer<Float>, frameCount: Int, bpm: Float, sampleRate: Double, intensity: Float) {
            // Smooth, elegant melodies (baroque/waltz style)
            for frame in 0..<frameCount {
                let t = Float(frame) / Float(sampleRate)

                // Waltz bass (3/4 time feel)
                let bassFreq: Float = 220.0
                let bass = 0.2 * sin(2.0 * .pi * bassFreq * t) * (0.7 + 0.3 * sin(2.0 * .pi * (bpm/60.0/3.0) * t))

                // Flowing melody
                let melodyFreq: Float = 440.0 + 220.0 * sin(2.0 * .pi * 0.25 * t)
                let melody = 0.15 * sin(2.0 * .pi * melodyFreq * t)

                let combined = (bass + melody) * intensity

                leftChannel[frame] = combined
                rightChannel[frame] = combined
            }
        }

        private func generateSharpRhythm(leftChannel: UnsafeMutablePointer<Float>, rightChannel: UnsafeMutablePointer<Float>, frameCount: Int, samplesPerBeat: Int, sampleRate: Double, intensity: Float) {
            // Sharp, staccato beats (jazz/flamenco)
            for frame in 0..<frameCount {
                let beatPhase = frame % samplesPerBeat
                let beatT = Float(beatPhase) / Float(samplesPerBeat)

                // Sharp snare
                let snareEnv = exp(-beatT * 50) // Very fast decay
                let snareNoise = Float.random(in: -1...1) * snareEnv
                let snareTone = sin(2.0 * .pi * 200.0 * beatT) * snareEnv

                // Syncopated hi-hat
                let offbeat = (frame + samplesPerBeat/2) % samplesPerBeat
                let offbeatT = Float(offbeat) / Float(samplesPerBeat)
                let hihat = Float.random(in: -0.5...0.5) * exp(-offbeatT * 30) * 0.2

                let combined = (snareNoise * 0.1 + snareTone * 0.2 + hihat) * intensity

                leftChannel[frame] = combined
                rightChannel[frame] = combined
            }
        }

        private func generateExplosiveBeats(leftChannel: UnsafeMutablePointer<Float>, rightChannel: UnsafeMutablePointer<Float>, frameCount: Int, samplesPerBeat: Int, sampleRate: Double, intensity: Float) {
            // Explosive, powerful beats (krumping style)
            for frame in 0..<frameCount {
                let beatPhase = frame % samplesPerBeat
                let beatT = Float(beatPhase) / Float(samplesPerBeat)

                // Massive kick
                let kickFreq: Float = 50.0 + 100.0 * exp(-beatT * 30)
                let kickEnv = exp(-beatT * 6)
                let kick = sin(2.0 * .pi * kickFreq * beatT) * kickEnv

                // Explosive clap (every other beat)
                var clap: Float = 0
                if frame % (samplesPerBeat * 2) < samplesPerBeat / 10 {
                    clap = Float.random(in: -1...1) * 0.5
                }

                let combined = (kick * 0.4 + clap) * intensity

                leftChannel[frame] = combined
                rightChannel[frame] = combined
            }
        }

        private func generateTranceMusic(leftChannel: UnsafeMutablePointer<Float>, rightChannel: UnsafeMutablePointer<Float>, frameCount: Int, bpm: Float, sampleRate: Double, intensity: Float) {
            // Hypnotic, trance-inducing music (ecstatic dance, sufi)
            for frame in 0..<frameCount {
                let t = Float(frame) / Float(sampleRate)

                // Drone bass
                let droneFreq: Float = 136.1 // OM frequency
                let drone = 0.15 * sin(2.0 * .pi * droneFreq * t)

                // Slow pulsing rhythm
                let pulse = 0.5 + 0.5 * sin(2.0 * .pi * (bpm/60.0/4.0) * t)

                // Overtone melody
                let overtone = 0.1 * sin(2.0 * .pi * droneFreq * 3.0 * t + 0.5 * sin(2.0 * .pi * 0.1 * t))

                let combined = (drone + overtone) * pulse * intensity

                leftChannel[frame] = combined
                rightChannel[frame] = combined
            }
        }

        private func generateComplexRhythm(leftChannel: UnsafeMutablePointer<Float>, rightChannel: UnsafeMutablePointer<Float>, frameCount: Int, samplesPerBeat: Int, sampleRate: Double, complexity: Float, intensity: Float) {
            // Complex polyrhythms (salsa, african)
            let polyRhythms = Int(2 + complexity * 3) // 2-5 layers

            for frame in 0..<frameCount {
                var combined: Float = 0

                for layer in 1...polyRhythms {
                    let rhythmPeriod = samplesPerBeat * layer / 2
                    let phase = frame % rhythmPeriod
                    let t = Float(phase) / Float(rhythmPeriod)

                    let freq: Float = 80.0 * Float(layer)
                    let env = exp(-t * Float(10 + layer * 2))
                    let sound = sin(2.0 * .pi * freq * t) * env

                    combined += sound / Float(polyRhythms)
                }

                combined *= intensity * 0.3

                leftChannel[frame] = combined
                rightChannel[frame] = combined
            }
        }

        private func generateBouncingBeat(leftChannel: UnsafeMutablePointer<Float>, rightChannel: UnsafeMutablePointer<Float>, frameCount: Int, samplesPerBeat: Int, sampleRate: Double, intensity: Float) {
            // Bouncy, energetic beats (rave, techno)
            for frame in 0..<frameCount {
                let beatPhase = frame % samplesPerBeat
                let beatT = Float(beatPhase) / Float(samplesPerBeat)

                // 4-on-the-floor kick
                let kickFreq: Float = 60.0 + 60.0 * exp(-beatT * 25)
                let kickEnv = exp(-beatT * 10)
                let kick = sin(2.0 * .pi * kickFreq * beatT) * kickEnv

                // Bouncy bass line
                let bassPhase = (frame % (samplesPerBeat * 4)) / samplesPerBeat
                let bassFreq: Float = 80.0 + 40.0 * sin(2.0 * .pi * Float(bassPhase) / 4.0)
                let bass = 0.15 * sin(2.0 * .pi * bassFreq * beatT)

                let combined = (kick * 0.3 + bass) * intensity

                leftChannel[frame] = combined
                rightChannel[frame] = combined
            }
        }

        private func generateAerialMelody(leftChannel: UnsafeMutablePointer<Float>, rightChannel: UnsafeMutablePointer<Float>, frameCount: Int, bpm: Float, sampleRate: Double, intensity: Float) {
            // Light, floating melodies (ballet)
            for frame in 0..<frameCount {
                let t = Float(frame) / Float(sampleRate)

                // High, delicate melody
                let melodyFreq: Float = 880.0 + 440.0 * sin(2.0 * .pi * 0.2 * t)
                let melody = 0.12 * sin(2.0 * .pi * melodyFreq * t)

                // Gentle accompaniment
                let accompFreq: Float = 220.0
                let accomp = 0.08 * sin(2.0 * .pi * accompFreq * t)

                // Light rhythm
                let rhythm = 0.7 + 0.3 * sin(2.0 * .pi * (bpm/60.0) * t)

                let combined = (melody + accomp) * rhythm * intensity

                leftChannel[frame] = combined
                rightChannel[frame] = combined
            }
        }
    }

    // MARK: - 5Rhythms Implementation

    class FiveRhythms {

        enum Rhythm: String, CaseIterable {
            case flowing = "Flowing" // Fließend
            case staccato = "Staccato" // Abgehackt
            case chaos = "Chaos" // Chaos
            case lyrical = "Lyrical" // Lyrisch
            case stillness = "Stillness" // Stille

            var bpmRange: ClosedRange<Float> {
                switch self {
                case .flowing: return 60...80
                case .staccato: return 100...120
                case .chaos: return 140...160
                case .lyrical: return 90...110
                case .stillness: return 40...60
                }
            }

            var therapeuticQuality: String {
                switch self {
                case .flowing: return "Weibliche Energie, Akzeptanz, Loslassen"
                case .staccato: return "Männliche Energie, Grenzen, Klarheit"
                case .chaos: return "Transformation, Freiheit, Wildheit"
                case .lyrical: return "Leichtigkeit, Freude, Integration"
                case .stillness: return "Frieden, Vollendung, Heilung"
                }
            }
        }

        func generateFiveRhythmsJourney(durationPerRhythm: TimeInterval = 600) -> AVAudioPCMBuffer {
            let totalDuration = durationPerRhythm * Double(Rhythm.allCases.count)
            let sampleRate: Double = 48000
            let frameCount = AVAudioFrameCount(totalDuration * sampleRate)

            guard let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!, frameCapacity: frameCount) else {
                return AVAudioPCMBuffer()
            }

            buffer.frameLength = frameCount

            guard let leftChannel = buffer.floatChannelData?[0],
                  let rightChannel = buffer.floatChannelData?[1] else {
                return buffer
            }

            for (index, rhythm) in Rhythm.allCases.enumerated() {
                let startFrame = Int(Double(index) * durationPerRhythm * sampleRate)
                let rhythmFrames = Int(durationPerRhythm * sampleRate)

                let bpm = (rhythm.bpmRange.lowerBound + rhythm.bpmRange.upperBound) / 2.0
                let beatsPerSecond = bpm / 60.0
                let samplesPerBeat = Int(Float(sampleRate) / beatsPerSecond)

                for frame in 0..<rhythmFrames {
                    guard startFrame + frame < Int(frameCount) else { break }

                    let t = Float(frame) / Float(sampleRate)
                    let beatPhase = frame % samplesPerBeat
                    let beatT = Float(beatPhase) / Float(samplesPerBeat)

                    var signal: Float = 0

                    switch rhythm {
                    case .flowing:
                        // Smooth, wave-like
                        signal = 0.15 * sin(2.0 * .pi * 80.0 * t + 0.5 * sin(2.0 * .pi * 0.2 * t))

                    case .staccato:
                        // Sharp, defined beats
                        let env = exp(-beatT * 15)
                        signal = sin(2.0 * .pi * 120.0 * beatT) * env * 0.2

                    case .chaos:
                        // Wild, unpredictable
                        signal = 0.2 * (
                            sin(2.0 * .pi * 160.0 * t) +
                            0.5 * sin(2.0 * .pi * 240.0 * t * 1.618) +
                            0.3 * Float.random(in: -1...1)
                        )

                    case .lyrical:
                        // Light, joyful
                        signal = 0.15 * sin(2.0 * .pi * (440.0 + 220.0 * sin(2.0 * .pi * 0.5 * t)) * t)

                    case .stillness:
                        // Quiet, meditative
                        signal = 0.08 * sin(2.0 * .pi * 136.1 * t) // OM frequency
                    }

                    // Smooth transitions between rhythms
                    let fadeTime: Float = 30.0
                    var envelope: Float = 1.0

                    if t < fadeTime {
                        envelope = t / fadeTime
                    } else if t > Float(durationPerRhythm) - fadeTime {
                        envelope = (Float(durationPerRhythm) - t) / fadeTime
                    }

                    signal *= envelope

                    leftChannel[startFrame + frame] = signal
                    rightChannel[startFrame + frame] = signal
                }
            }

            return buffer
        }
    }
}

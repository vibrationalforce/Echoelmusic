import Foundation
import AVFoundation
import Accelerate
import Combine

/// Sound Therapy Instruments - Classical healing instruments from worldwide traditions
///
/// **Instruments Included:**
/// - Tibetan Singing Bowls (Klangschalen)
/// - Crystal Singing Bowls
/// - Somachord (Body Monochord)
/// - Therapeutic Gongs
/// - Tuning Forks (Stimmgabeln)
/// - Hang / Handpan
/// - Shruti Box
/// - Tanpura
/// - Monochord
/// - Sound Bed / Sound Table
@MainActor
class SoundTherapyInstruments: ObservableObject {

    // MARK: - Published State

    @Published var activeInstrument: TherapyInstrument?
    @Published var currentFrequency: Float = 432.0
    @Published var isPlaying: Bool = false
    @Published var overtoneIntensity: Float = 0.5

    // MARK: - Therapy Instruments

    enum TherapyInstrument: String, CaseIterable {
        case tibetanSingingBowl = "Tibetische Klangschale"
        case crystalSingingBowl = "Kristall-Klangschale"
        case somachord = "Somachord"
        case therapeuticGong = "Therapeutischer Gong"
        case tuningFork = "Stimmgabel"
        case hang = "Hang / Handpan"
        case shrutiBox = "Shruti Box"
        case tanpura = "Tanpura"
        case monochord = "Monochord"
        case soundBed = "Klangliege"
        case rainstick = "Regenstab"
        case oceanDrum = "Ocean Drum"
        case koshi = "Koshi Chimes"
        case zaphir = "Zaphir Chimes"
        case tingsha = "Tingsha"

        var description: String {
            switch self {
            case .tibetanSingingBowl:
                return "Traditionelle Metallschale aus Tibet/Nepal. Erzeugt lang anhaltende Obertöne durch Reiben oder Anschlagen."
            case .crystalSingingBowl:
                return "Aus reinem Quarz. Erzeugt sehr reine, durchdringende Töne. Oft auf Chakra-Frequenzen gestimmt."
            case .somachord:
                return "Körpermonochord. Therapeutisches Instrument mit 30+ Saiten, unter Liege für Körper-Resonanz."
            case .therapeuticGong:
                return "Großer Gong (80-150cm) für Sound Healing. Vollständiges Frequenzspektrum, tiefe körperliche Vibration."
            case .tuningFork:
                return "Präzise gestimmte Metallgabeln. Einzelne Frequenzen für spezifische therapeutische Anwendungen."
            case .hang:
                return "Handpan / Hang Drum. Moderne Entwicklung aus Stahl mit harmonisch abgestimmten Tonfeldern."
            case .shrutiBox:
                return "Indisches Harmonium-ähnliches Instrument. Kontinuierlicher Bordunton für Meditation."
            case .tanpura:
                return "Indisches Saiteninstrument. 4-6 Saiten für harmonischen Bordun, reich an Obertönen."
            case .monochord:
                return "Viele gleichgestimmte Saiten. Erzeugt kraftvolle Obertöne und körperliche Resonanz."
            case .soundBed:
                return "Klangliege mit integrierten Lautsprechern. Ganzkörper-Vibrationserfahrung."
            case .rainstick:
                return "Röhre mit Samen/Perlen. Imitiert Regengeräusche für Entspannung."
            case .oceanDrum:
                return "Rahmentrommel mit Metallkugeln. Erzeugt Meeresrauschen."
            case .koshi:
                return "Koshi Wind Chimes. 4 Elemente (Aqua, Aria, Terra, Ignis) mit spezifischen Stimmungen."
            case .zaphir:
                return "Zaphir Klangspiele. Ähnlich Koshi, 5 Stimmungen (Blue Moon, Sunray, Twilight, Crystalide, Sufi)."
            case .tingsha:
                return "Tibetische Zimbeln. Paar von kleinen Becken für Meditation und Raumreinigung."
            }
        }

        var traditionalUse: String {
            switch self {
            case .tibetanSingingBowl:
                return "Meditation, Chakra-Arbeit, Massage, Klangmassage"
            case .crystalSingingBowl:
                return "Chakra-Healing, Raumreinigung, Gruppen-Meditation"
            case .somachord:
                return "Körpertherapie, Tiefenentspannung, Schmerztherapie"
            case .therapeuticGong:
                return "Gong-Bad, Tiefenreinigung, emotionale Befreiung"
            case .tuningFork:
                return "Akupunktur-Punkte, Knochen-Resonanz, Chakren"
            case .hang:
                return "Meditation, intuitive Musik, Trance"
            case .shrutiBox:
                return "Gesangs-Begleitung, Mantra-Gesang, Meditation"
            case .tanpura:
                return "Raga-Begleitung, Meditation, Stimmtraining"
            case .monochord:
                return "Oberton-Gesang, Klangtherapie, Trance-Arbeit"
            case .soundBed:
                return "Ganzkörper-Klangmassage, Stress-Reduktion"
            case .rainstick:
                return "Entspannung, Visualisierung, Naturverbindung"
            case .oceanDrum:
                return "Meditation, Entspannung, Meeresverbindung"
            case .koshi:
                return "Wind-Element-Arbeit, Feng Shui, Raumklärung"
            case .zaphir:
                return "Meditation, Therapieraum, energetische Arbeit"
            case .tingsha:
                return "Meditation-Beginn/-Ende, Raumklärung"
            }
        }
    }

    // MARK: - Tibetan Singing Bowl

    class TibetanSingingBowl {

        enum BowlSize {
            case small      // 8-12 cm, 100-200g
            case medium     // 12-18 cm, 200-500g
            case large      // 18-25 cm, 500-1000g
            case extraLarge // 25-35 cm, 1000-2500g
            case therapeutic // 35+ cm, 2500g+

            var fundamentalFrequency: ClosedRange<Float> {
                switch self {
                case .small: return 600...1200
                case .medium: return 400...600
                case .large: return 250...400
                case .extraLarge: return 150...250
                case .therapeutic: return 80...150
                }
            }

            var weight: ClosedRange<Float> {  // grams
                switch self {
                case .small: return 100...200
                case .medium: return 200...500
                case .large: return 500...1000
                case .extraLarge: return 1000...2500
                case .therapeutic: return 2500...5000
                }
            }
        }

        enum PlayingTechnique {
            case striking  // Anschlagen mit Klöppel
            case rimming   // Reiben am Rand
            case pulsing   // Rhythmisches Anschlagen

            var envelopeProfile: ADSREnvelope {
                switch self {
                case .striking:
                    return ADSREnvelope(attack: 0.01, decay: 0.5, sustain: 0.6, release: 8.0)
                case .rimming:
                    return ADSREnvelope(attack: 0.5, decay: 0.0, sustain: 1.0, release: 2.0)
                case .pulsing:
                    return ADSREnvelope(attack: 0.01, decay: 0.3, sustain: 0.4, release: 1.5)
                }
            }
        }

        // Klassische 7-Metall-Legierung (tibetisch)
        struct MetalComposition {
            let gold: Float   // Sonne
            let silver: Float // Mond
            let mercury: Float // Merkur
            let copper: Float // Venus
            let iron: Float   // Mars
            let tin: Float    // Jupiter
            let lead: Float   // Saturn

            // Klassische tibetische Rezeptur
            static let traditional = MetalComposition(
                gold: 0.01,    // 1%
                silver: 0.05,  // 5%
                mercury: 0.02, // 2%
                copper: 0.70,  // 70% (Hauptbestandteil)
                iron: 0.05,    // 5%
                tin: 0.15,     // 15%
                lead: 0.02     // 2%
            )
        }

        func synthesize(size: BowlSize, technique: PlayingTechnique, duration: TimeInterval) -> AVAudioPCMBuffer {
            let sampleRate: Double = 48000
            let frameCount = AVAudioFrameCount(duration * sampleRate)

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: AVAudioFormat(
                    standardFormatWithSampleRate: sampleRate,
                    channels: 2
                )!,
                frameCapacity: frameCount
            ) else {
                fatalError("Failed to create buffer")
            }

            buffer.frameLength = frameCount

            // Fundamental frequency (random within range)
            let fundamental = Float.random(in: size.fundamentalFrequency)

            // Tibetan singing bowls have rich harmonic content
            // Overtone series: f, 2f, 3f, 5f, 7f, 11f (not perfect harmonics!)
            let overtones: [(frequency: Float, amplitude: Float)] = [
                (fundamental, 1.0),           // Fundamental
                (fundamental * 2.01, 0.6),    // Slight inharmonicity
                (fundamental * 3.02, 0.4),
                (fundamental * 5.04, 0.25),
                (fundamental * 7.03, 0.15),
                (fundamental * 11.08, 0.08),
                (fundamental * 13.05, 0.05)
            ]

            // Generate complex waveform
            if let leftChannel = buffer.floatChannelData?[0],
               let rightChannel = buffer.floatChannelData?[1] {

                let envelope = technique.envelopeProfile

                for frame in 0..<Int(frameCount) {
                    let time = Float(frame) / Float(sampleRate)
                    var sample: Float = 0.0

                    // Add all overtones
                    for (freq, amp) in overtones {
                        let phase = 2.0 * Float.pi * freq * time

                        // Slight amplitude modulation (warble/shimmer effect)
                        let warble = 1.0 + 0.02 * sin(2.0 * Float.pi * 1.5 * time)

                        sample += amp * warble * sin(phase)
                    }

                    // Apply ADSR envelope
                    let envValue = envelope.valueAt(time: time, duration: Float(duration))
                    sample *= envValue

                    // Add slight noise for realistic metal texture
                    let noise = Float.random(in: -0.01...0.01)
                    sample += noise * 0.1

                    // Normalize
                    sample *= 0.3

                    // Stereo spread (slight phase difference)
                    leftChannel[frame] = sample
                    rightChannel[frame] = sample * cos(Float.pi * 0.1 * time)
                }
            }

            return buffer
        }

        struct ADSREnvelope {
            let attack: Float   // seconds
            let decay: Float
            let sustain: Float  // level (0-1)
            let release: Float

            func valueAt(time: Float, duration: Float) -> Float {
                if time < attack {
                    // Attack phase
                    return time / attack
                } else if time < attack + decay {
                    // Decay phase
                    let decayProgress = (time - attack) / decay
                    return 1.0 - (1.0 - sustain) * decayProgress
                } else if time < duration - release {
                    // Sustain phase
                    return sustain
                } else {
                    // Release phase
                    let releaseProgress = (time - (duration - release)) / release
                    return sustain * (1.0 - releaseProgress)
                }
            }
        }
    }

    // MARK: - Crystal Singing Bowl

    class CrystalSingingBowl {

        enum CrystalType {
            case clearQuartz
            case frosted
            case alchemical  // With metals/minerals fused
            case gemstone    // Infused with gemstones

            var purity: Float {
                switch self {
                case .clearQuartz: return 0.995
                case .frosted: return 0.990
                case .alchemical: return 0.985
                case .gemstone: return 0.980
                }
            }
        }

        enum ChakraTuning: String, CaseIterable {
            case root = "C (Root Chakra) 256 Hz"
            case sacral = "D (Sacral) 288 Hz"
            case solarPlexus = "E (Solar Plexus) 320 Hz"
            case heart = "F (Heart) 341.3 Hz"
            case throat = "G (Throat) 384 Hz"
            case thirdEye = "A (Third Eye) 426.7 Hz"
            case crown = "B (Crown) 480 Hz"

            var frequency: Float {
                switch self {
                case .root: return 256.0
                case .sacral: return 288.0
                case .solarPlexus: return 320.0
                case .heart: return 341.3
                case .throat: return 384.0
                case .thirdEye: return 426.7
                case .crown: return 480.0
                }
            }

            var chakraName: String {
                return String(describing: self).capitalized
            }
        }

        func synthesize(chakra: ChakraTuning, type: CrystalType, duration: TimeInterval) -> AVAudioPCMBuffer {
            let sampleRate: Double = 48000
            let frameCount = AVAudioFrameCount(duration * sampleRate)

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: AVAudioFormat(
                    standardFormatWithSampleRate: sampleRate,
                    channels: 2
                )!,
                frameCapacity: frameCount
            ) else {
                fatalError("Failed to create buffer")
            }

            buffer.frameLength = frameCount

            let fundamental = chakra.frequency

            // Crystal bowls have VERY pure harmonics (almost perfect sine waves)
            // But with subtle beating and shimmer
            let overtones: [(frequency: Float, amplitude: Float)] = [
                (fundamental, 1.0),
                (fundamental * 2.0, 0.3),     // Perfect octave
                (fundamental * 3.0, 0.15),    // Perfect fifth
                (fundamental * 4.0, 0.08),    // Two octaves
                (fundamental * 5.0, 0.04),    // Major third
                (fundamental * 6.0, 0.02)     // Fifth + octave
            ]

            if let leftChannel = buffer.floatChannelData?[0],
               let rightChannel = buffer.floatChannelData?[1] {

                for frame in 0..<Int(frameCount) {
                    let time = Float(frame) / Float(sampleRate)
                    var sample: Float = 0.0

                    // Add all overtones with VERY slow beating
                    for (freq, amp) in overtones {
                        let phase = 2.0 * Float.pi * freq * time

                        // Subtle beating (< 1 Hz)
                        let beating = 1.0 + 0.005 * sin(2.0 * Float.pi * 0.5 * time)

                        sample += amp * type.purity * beating * sin(phase)
                    }

                    // Very slow, gentle ADSR
                    let attack: Float = 2.0
                    let release = Float(duration) - attack
                    let envValue = min(1.0, time / attack) * max(0.0, 1.0 - (time - attack) / release)

                    sample *= envValue * 0.5

                    // Wide stereo field
                    leftChannel[frame] = sample
                    rightChannel[frame] = sample * 0.95  // Slight phase
                }
            }

            return buffer
        }
    }

    // MARK: - Somachord (Body Monochord)

    class Somachord {

        // Somachord hat typischerweise 30-50 Saiten
        let stringCount: Int = 40

        struct SomachordPreset {
            let name: String
            let tuning: [Float]  // Frequencies for all strings
            let description: String
        }

        static let presets: [SomachordPreset] = [
            SomachordPreset(
                name: "Klassisch A 432 Hz",
                tuning: Array(repeating: 432.0, count: 40),
                description: "Alle Saiten auf 432 Hz (harmonische Grundstimmung)"
            ),
            SomachordPreset(
                name: "OM 136.1 Hz",
                tuning: Array(repeating: 136.1, count: 40),
                description: "OM-Frequenz, Jahr der Erde (Tiefe Resonanz)"
            ),
            SomachordPreset(
                name: "Schumann 7.83 Hz",
                tuning: Array(repeating: 7.83 * 64, count: 40),  // 501.12 Hz (7 Oktaven höher)
                description: "Schumann-Resonanz (Erdfrequenz, hochoktaviert)"
            ),
            SomachordPreset(
                name: "Chakra-Spektrum",
                tuning: [
                    194.18, 194.18, 194.18, 194.18, 194.18,  // Root
                    210.42, 210.42, 210.42, 210.42, 210.42,  // Sacral
                    126.22, 126.22, 126.22, 126.22, 126.22,  // Solar
                    136.10, 136.10, 136.10, 136.10, 136.10,  // Heart
                    141.27, 141.27, 141.27, 141.27, 141.27,  // Throat
                    221.23, 221.23, 221.23, 221.23, 221.23,  // Third Eye
                    172.06, 172.06, 172.06, 172.06, 172.06,  // Crown
                    172.06, 172.06, 172.06, 172.06, 172.06   // Crown (continued)
                ],
                description: "Alle 7 Chakren repräsentiert"
            )
        ]

        func synthesize(preset: SomachordPreset, duration: TimeInterval, playingIntensity: Float = 1.0) -> AVAudioPCMBuffer {
            let sampleRate: Double = 48000
            let frameCount = AVAudioFrameCount(duration * sampleRate)

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: AVAudioFormat(
                    standardFormatWithSampleRate: sampleRate,
                    channels: 2
                )!,
                frameCapacity: frameCount
            ) else {
                fatalError("Failed to create buffer")
            }

            buffer.frameLength = frameCount

            if let leftChannel = buffer.floatChannelData?[0],
               let rightChannel = buffer.floatChannelData?[1] {

                for frame in 0..<Int(frameCount) {
                    let time = Float(frame) / Float(sampleRate)
                    var sample: Float = 0.0

                    // Simulate all strings vibrating together
                    for (stringIndex, frequency) in preset.tuning.enumerated() {
                        // Each string has slightly different phase and amplitude
                        let phaseOffset = Float(stringIndex) * 0.1
                        let amplitude = playingIntensity / Float(preset.tuning.count)

                        // Fundamental + some harmonics
                        let fundamental = sin(2.0 * Float.pi * frequency * time + phaseOffset)
                        let harmonic2 = 0.3 * sin(2.0 * Float.pi * frequency * 2.0 * time + phaseOffset)
                        let harmonic3 = 0.15 * sin(2.0 * Float.pi * frequency * 3.0 * time + phaseOffset)

                        sample += amplitude * (fundamental + harmonic2 + harmonic3)

                        // Subtle amplitude modulation per string (natural string vibration)
                        let modulation = 1.0 + 0.01 * sin(2.0 * Float.pi * 3.0 * time + Float(stringIndex))
                        sample *= modulation
                    }

                    // Gentle ADSR for body resonance
                    let attack: Float = 3.0
                    let release = Float(duration) - attack
                    let envValue = min(1.0, time / attack) * max(0.0, 1.0 - (time - attack) / release)

                    sample *= envValue * 0.2  // Keep amplitude moderate

                    // Stereo field (wide, immersive)
                    leftChannel[frame] = sample
                    rightChannel[frame] = sample * 0.97
                }
            }

            return buffer
        }
    }

    // MARK: - Therapeutic Gong

    class TherapeuticGong {

        enum GongType {
            case tam_tam        // Flat, no central boss
            case chau          // Central boss, pitched
            case planetaryGong // Tuned to planetary frequencies
            case symphonic     // Western orchestral
            case feng          // Chinese traditional

            var sizeRange: ClosedRange<Int> {  // cm diameter
                switch self {
                case .tam_tam: return 80...200
                case .chau: return 60...150
                case .planetaryGong: return 70...100
                case .symphonic: return 70...150
                case .feng: return 30...80
                }
            }
        }

        enum PlanetaryFrequency: String, CaseIterable {
            case sun = "Sonne 126.22 Hz"
            case moon = "Mond 210.42 Hz"
            case earth = "Erde 136.10 Hz (OM)"
            case mercury = "Merkur 141.27 Hz"
            case venus = "Venus 221.23 Hz"
            case mars = "Mars 144.72 Hz"
            case jupiter = "Jupiter 183.58 Hz"
            case saturn = "Saturn 147.85 Hz"
            case uranus = "Uranus 207.36 Hz"
            case neptune = "Neptun 211.44 Hz"
            case pluto = "Pluto 140.25 Hz"

            var frequency: Float {
                switch self {
                case .sun: return 126.22
                case .moon: return 210.42
                case .earth: return 136.10
                case .mercury: return 141.27
                case .venus: return 221.23
                case .mars: return 144.72
                case .jupiter: return 183.58
                case .saturn: return 147.85
                case .uranus: return 207.36
                case .neptune: return 211.44
                case .pluto: return 140.25
                }
            }
        }

        func synthesize(type: GongType, planetary: PlanetaryFrequency?, duration: TimeInterval, strikeIntensity: Float = 1.0) -> AVAudioPCMBuffer {
            let sampleRate: Double = 48000
            let frameCount = AVAudioFrameCount(duration * sampleRate)

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: AVAudioFormat(
                    standardFormatWithSampleRate: sampleRate,
                    channels: 2
                )!,
                frameCapacity: frameCount
            ) else {
                fatalError("Failed to create buffer")
            }

            buffer.frameLength = frameCount

            // Gong has EXTREMELY complex harmonic content
            // Almost the entire frequency spectrum!
            var frequencies: [Float] = []

            if let planetary = planetary {
                // If planetary, use that as fundamental
                let fundamental = planetary.frequency
                frequencies = [fundamental]

                // Add many inharmonic overtones
                for i in 1...50 {
                    let ratio = Float(i) * (Float.random(in: 0.95...1.05))
                    frequencies.append(fundamental * ratio)
                }
            } else {
                // Non-planetary: wide spectrum of frequencies
                for _ in 0...100 {
                    frequencies.append(Float.random(in: 20...10000))
                }
            }

            if let leftChannel = buffer.floatChannelData?[0],
               let rightChannel = buffer.floatChannelData?[1] {

                for frame in 0..<Int(frameCount) {
                    let time = Float(frame) / Float(sampleRate)
                    var sample: Float = 0.0

                    // Add many frequencies with complex decay
                    for (index, freq) in frequencies.enumerated() {
                        let amplitude = strikeIntensity / Float(frequencies.count)

                        // Each frequency has different decay rate
                        let decayRate = Float.random(in: 0.5...3.0)
                        let decay = exp(-decayRate * time)

                        // Phase with slight randomization
                        let phase = 2.0 * Float.pi * freq * time + Float(index) * 0.01

                        sample += amplitude * decay * sin(phase)
                    }

                    // Add noise for metallic shimmer
                    let noise = Float.random(in: -0.05...0.05) * exp(-2.0 * time)
                    sample += noise * strikeIntensity

                    // Normalize
                    sample *= 0.1

                    // Wide stereo
                    leftChannel[frame] = sample
                    rightChannel[frame] = sample * 0.93
                }
            }

            return buffer
        }
    }

    // MARK: - Tuning Forks (Stimmgabeln)

    class TuningForks {

        enum TherapeuticFork: String, CaseIterable {
            case c128 = "C 128 Hz (Körperarbeit)"
            case om = "OM 136.1 Hz (Jahr der Erde)"
            case solfeggio174 = "Solfeggio 174 Hz"
            case solfeggio285 = "Solfeggio 285 Hz"
            case solfeggio396 = "Solfeggio 396 Hz"
            case solfeggio417 = "Solfeggio 417 Hz"
            case solfeggio528 = "Solfeggio 528 Hz (DNA)"
            case solfeggio639 = "Solfeggio 639 Hz"
            case solfeggio741 = "Solfeggio 741 Hz"
            case solfeggio852 = "Solfeggio 852 Hz"
            case solfeggio963 = "Solfeggio 963 Hz"
            case otto64 = "Otto 64 Hz (Knochenarbeit)"
            case otto128 = "Otto 128 Hz (Wirbelsäule)"
            case schumann = "Schumann 7.83 Hz (Erdresonanz)"

            var frequency: Float {
                switch self {
                case .c128: return 128.0
                case .om: return 136.1
                case .solfeggio174: return 174.0
                case .solfeggio285: return 285.0
                case .solfeggio396: return 396.0
                case .solfeggio417: return 417.0
                case .solfeggio528: return 528.0
                case .solfeggio639: return 639.0
                case .solfeggio741: return 741.0
                case .solfeggio852: return 852.0
                case .solfeggio963: return 963.0
                case .otto64: return 64.0
                case .otto128: return 128.0
                case .schumann: return 7.83
                }
            }

            var therapeuticUse: String {
                switch self {
                case .c128: return "Körperarbeit, Nervensystem, Muskelentspannung"
                case .om: return "Meditation, Erdung, spirituelle Verbindung"
                case .solfeggio174: return "Schmerz-Reduktion, Sicherheit, Fundament"
                case .solfeggio285: return "Gewebeheilung, Zellregeneration"
                case .solfeggio396: return "Angst lösen, Schuldgefühle befreien"
                case .solfeggio417: return "Veränderung, Trauma-Heilung"
                case .solfeggio528: return "DNA-Reparatur, Liebe, Heilung"
                case .solfeggio639: return "Beziehungen, Verbindung, Harmonie"
                case .solfeggio741: return "Intuition, Ausdruck, Detox"
                case .solfeggio852: return "Spirituelles Erwachen, Ordnung"
                case .solfeggio963: return "Einheitsbewusstsein, Göttliche Verbindung"
                case .otto64: return "Knochenarbeit, tiefe Vibration"
                case .otto128: return "Wirbelsäule, Nervensystem"
                case .schumann: return "Erdung, Erdresonanz, Balance"
                }
            }
        }

        func synthesize(fork: TherapeuticFork, duration: TimeInterval) -> AVAudioPCMBuffer {
            let sampleRate: Double = 48000
            let frameCount = AVAudioFrameCount(duration * sampleRate)

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: AVAudioFormat(
                    standardFormatWithSampleRate: sampleRate,
                    channels: 2
                )!,
                frameCapacity: frameCount
            ) else {
                fatalError("Failed to create buffer")
            }

            buffer.frameLength = frameCount

            let fundamental = fork.frequency

            // Tuning forks produce very pure tones
            // Almost perfect sine wave with minimal harmonics
            if let leftChannel = buffer.floatChannelData?[0],
               let rightChannel = buffer.floatChannelData?[1] {

                for frame in 0..<Int(frameCount) {
                    let time = Float(frame) / Float(sampleRate)

                    // Pure fundamental
                    let phase = 2.0 * Float.pi * fundamental * time
                    var sample = sin(phase)

                    // Minimal second harmonic (< 5%)
                    sample += 0.03 * sin(2.0 * phase)

                    // Very slow decay (tuning forks sustain long)
                    let decay = exp(-0.3 * time)
                    sample *= decay * 0.5

                    // Mono (tuning forks are point sources)
                    leftChannel[frame] = sample
                    rightChannel[frame] = sample
                }
            }

            return buffer
        }
    }

    // MARK: - Convenience Methods

    func play(instrument: TherapyInstrument, duration: TimeInterval, intensity: Float = 1.0) {
        activeInstrument = instrument
        isPlaying = true

        let buffer: AVAudioPCMBuffer

        switch instrument {
        case .tibetanSingingBowl:
            let bowl = TibetanSingingBowl()
            buffer = bowl.synthesize(size: .medium, technique: .striking, duration: duration)

        case .crystalSingingBowl:
            let crystal = CrystalSingingBowl()
            buffer = crystal.synthesize(chakra: .heart, type: .clearQuartz, duration: duration)

        case .somachord:
            let somachord = Somachord()
            buffer = somachord.synthesize(preset: Somachord.presets[0], duration: duration, playingIntensity: intensity)

        case .therapeuticGong:
            let gong = TherapeuticGong()
            buffer = gong.synthesize(type: .tam_tam, planetary: .earth, duration: duration, strikeIntensity: intensity)

        case .tuningFork:
            let fork = TuningForks()
            buffer = fork.synthesize(fork: .om, duration: duration)

        default:
            // TODO: Implement remaining instruments
            print("⚠️ Instrument \(instrument.rawValue) not yet implemented")
            return
        }

        // Play the synthesized buffer
        playBuffer(buffer)
    }

    private func playBuffer(_ buffer: AVAudioPCMBuffer) {
        // TODO: Integrate with audio engine
        print("🔊 Playing therapy instrument: \(buffer.frameLength) frames")
    }
}

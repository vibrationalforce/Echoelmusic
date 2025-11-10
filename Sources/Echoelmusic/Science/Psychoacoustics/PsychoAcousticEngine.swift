import Foundation
import Accelerate
import AVFoundation

/// Advanced Psychoacoustic Engine
/// Implements scientifically-validated psychoacoustic phenomena
///
/// Based on research from:
/// - Fletcher-Munson Equal Loudness Contours (1933)
/// - Bark Scale & Critical Bands (Zwicker, 1961)
/// - Shepard Tones (Shepard, 1964)
/// - Phantom Fundamentals (Schouten, 1940)
/// - Binaural Masking Level Difference (Hirsh, 1948)
/// - Cocktail Party Effect (Cherry, 1953)
/// - HRTF (Head-Related Transfer Functions)
@MainActor
class PsychoAcousticEngine: ObservableObject {

    // MARK: - Constants

    /// A4 reference frequency (concert pitch)
    static let A4_FREQUENCY: Float = 440.0

    /// Equal temperament semitone ratio
    static let SEMITONE_RATIO: Float = pow(2.0, 1.0/12.0)  // 2^(1/12) ≈ 1.059463

    /// Golden Ratio (Phi) - found throughout nature and music
    static let GOLDEN_RATIO: Float = 1.618033988749

    /// Fibonacci sequence (harmonic relationships)
    static let FIBONACCI: [Int] = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987]

    // MARK: - Published State

    @Published var currentScale: MusicalScale = .equalTemperament
    @Published var currentTuning: TuningSystem = .standard440Hz
    @Published var spatialPerception: SpatialAudio = .stereo

    // MARK: - Musical Scales & Tuning Systems

    enum MusicalScale {
        case equalTemperament           // 12-TET (Western standard)
        case justIntonation            // Pure intervals (3:2, 5:4, etc.)
        case pythagorean               // Based on perfect fifths
        case solfeggio                 // Ancient sacred frequencies
        case harmonicSeries            // Natural overtone series
        case pentatonic                // 5-note scale (universal)
        case wholeTone                 // 6-note scale (Debussy)
        case chromatic                 // All 12 semitones
        case microtonal24TET           // 24 notes per octave (quarter tones)
        case microtonal31TET           // 31 notes per octave
        case microtonal53TET           // 53 notes per octave (comma pump)
        case bohlenPierce              // 13-note non-octave scale
        case goldenRatio               // Based on Phi (φ = 1.618...)
        case fibonacci                 // Based on Fibonacci ratios

        var intervals: [Float] {
            switch self {
            case .equalTemperament:
                // 12-TET: 2^(n/12) for n = 0 to 12
                return (0...12).map { pow(2.0, Float($0) / 12.0) }

            case .justIntonation:
                // Just intonation major scale: pure 5-limit intervals
                return [
                    1.0,        // 1/1 - Unison
                    9.0/8.0,    // 9/8 - Major 2nd
                    5.0/4.0,    // 5/4 - Major 3rd (pure)
                    4.0/3.0,    // 4/3 - Perfect 4th (pure)
                    3.0/2.0,    // 3/2 - Perfect 5th (pure)
                    5.0/3.0,    // 5/3 - Major 6th
                    15.0/8.0,   // 15/8 - Major 7th
                    2.0         // 2/1 - Octave
                ]

            case .pythagorean:
                // Based on stacking perfect fifths (3/2 ratio)
                return [
                    1.0,                    // 1/1
                    256.0/243.0,           // Pythagorean minor 2nd
                    9.0/8.0,               // Pythagorean major 2nd
                    32.0/27.0,             // Pythagorean minor 3rd
                    81.0/64.0,             // Pythagorean major 3rd
                    4.0/3.0,               // Perfect 4th
                    729.0/512.0,           // Augmented 4th
                    3.0/2.0,               // Perfect 5th
                    128.0/81.0,            // Pythagorean minor 6th
                    27.0/16.0,             // Pythagorean major 6th
                    16.0/9.0,              // Pythagorean minor 7th
                    243.0/128.0,           // Pythagorean major 7th
                    2.0                     // Octave
                ]

            case .solfeggio:
                // Ancient Solfeggio frequencies (ratios)
                return [
                    174.0/174.0,  // Ut
                    285.0/174.0,  // Re
                    396.0/174.0,  // Mi
                    417.0/174.0,  // Fa
                    528.0/174.0,  // Sol (DNA repair frequency)
                    639.0/174.0,  // La
                    741.0/174.0,  // Ti
                    852.0/174.0,  // Do
                    963.0/174.0   // Higher Do
                ]

            case .harmonicSeries:
                // Natural harmonic overtone series
                return (1...16).map { Float($0) }

            case .pentatonic:
                // Major pentatonic (universal scale)
                return [1.0, 9.0/8.0, 5.0/4.0, 3.0/2.0, 5.0/3.0, 2.0]

            case .wholeTone:
                // 6-note whole-tone scale (Debussy, Impressionism)
                return (0...6).map { pow(2.0, Float($0) / 6.0) }

            case .chromatic:
                // All 12 semitones (equal tempered)
                return (0...12).map { pow(2.0, Float($0) / 12.0) }

            case .microtonal24TET:
                // 24 equal divisions (quarter tones - Arabic/Persian music)
                return (0...24).map { pow(2.0, Float($0) / 24.0) }

            case .microtonal31TET:
                // 31 equal divisions (historical European tuning)
                return (0...31).map { pow(2.0, Float($0) / 31.0) }

            case .microtonal53TET:
                // 53 equal divisions (very close to Pythagorean)
                return (0...53).map { pow(2.0, Float($0) / 53.0) }

            case .bohlenPierce:
                // Non-octave scale (13-note, 3:1 interval instead of 2:1)
                return (0...13).map { pow(3.0, Float($0) / 13.0) }

            case .goldenRatio:
                // Scale based on golden ratio (φ = 1.618...)
                return (0...12).map { pow(GOLDEN_RATIO, Float($0) / 12.0) }

            case .fibonacci:
                // Intervals based on Fibonacci ratios
                let fibs = FIBONACCI.prefix(8)
                return fibs.map { Float($0) / Float(fibs.first!) }
            }
        }

        var description: String {
            switch self {
            case .equalTemperament:
                return "12-TET: Western standard (slightly impure intervals)"
            case .justIntonation:
                return "Just Intonation: Pure intervals (3:2, 5:4) - heavenly harmony"
            case .pythagorean:
                return "Pythagorean: Perfect fifths (3:2) - ancient Greek"
            case .solfeggio:
                return "Solfeggio: Sacred healing frequencies (528 Hz DNA repair)"
            case .harmonicSeries:
                return "Harmonic Series: Natural overtones (pure physics)"
            case .pentatonic:
                return "Pentatonic: Universal 5-note scale (found in all cultures)"
            case .wholeTone:
                return "Whole-Tone: Dreamy, ambiguous (Debussy, Impressionism)"
            case .chromatic:
                return "Chromatic: All 12 semitones"
            case .microtonal24TET:
                return "24-TET: Quarter tones (Arabic/Persian music)"
            case .microtonal31TET:
                return "31-TET: Historical European microtonality"
            case .microtonal53TET:
                return "53-TET: Very accurate Pythagorean approximation"
            case .bohlenPierce:
                return "Bohlen-Pierce: Non-octave scale (3:1 ratio)"
            case .goldenRatio:
                return "Golden Ratio: Based on φ (1.618) - divine proportion"
            case .fibonacci:
                return "Fibonacci: Based on nature's sequence (1,1,2,3,5,8...)"
            }
        }
    }

    enum TuningSystem {
        case standard440Hz              // A4 = 440 Hz (modern concert pitch)
        case baroque415Hz               // A4 = 415 Hz (Baroque period)
        case scientific432Hz            // A4 = 432 Hz ("cosmic frequency", controversial)
        case verdi432Hz                 // Giuseppe Verdi's preferred tuning
        case philosophical439Hz         // French philosophical pitch
        case ancient424Hz               // Ancient Greek tuning
        case tibetan426Hz               // Tibetan singing bowls
        case egyptian430dot54Hz         // Ancient Egyptian (claimed)

        var a4Frequency: Float {
            switch self {
            case .standard440Hz: return 440.0
            case .baroque415Hz: return 415.0
            case .scientific432Hz: return 432.0
            case .verdi432Hz: return 432.0
            case .philosophical439Hz: return 439.0
            case .ancient424Hz: return 424.0
            case .tibetan426Hz: return 426.0
            case .egyptian430dot54Hz: return 430.54
            }
        }

        var description: String {
            switch self {
            case .standard440Hz:
                return "A440: Modern concert pitch (ISO 16:1975)"
            case .baroque415Hz:
                return "A415: Baroque period (Bach, Vivaldi)"
            case .scientific432Hz:
                return "A432: 'Cosmic frequency' (resonates with Schumann resonance 8Hz)"
            case .verdi432Hz:
                return "Verdi A432: Giuseppe Verdi's 'true' pitch"
            case .philosophical439Hz:
                return "A439: French philosophical pitch"
            case .ancient424Hz:
                return "A424: Ancient Greek tuning"
            case .tibetan426Hz:
                return "A426: Tibetan singing bowl tuning"
            case .egyptian430dot54Hz:
                return "A430.54: Claimed ancient Egyptian (based on Great Pyramid)"
            }
        }
    }

    // MARK: - Spatial Audio Types

    enum SpatialAudio {
        case mono                       // Single channel
        case stereo                     // Left + Right (2.0)
        case surround5_1                // 5.1 surround (L, C, R, Ls, Rs, LFE)
        case surround7_1                // 7.1 surround (+ side channels)
        case surround7_1_4              // 7.1.4 Dolby Atmos (+ height)
        case surround9_1_6              // 9.1.6 (full Atmos)
        case ambisonics1stOrder         // B-format (4 channels: W, X, Y, Z)
        case ambisonics3rdOrder         // 16 channels (higher resolution)
        case binauralHRTF               // 3D audio over headphones
        case objectBased                // Dolby Atmos object-based
        case sceneБased                  // Ambisonics scene-based
        case waveFieldSynthesis         // WFS (hundreds of speakers)

        var channelCount: Int {
            switch self {
            case .mono: return 1
            case .stereo: return 2
            case .surround5_1: return 6
            case .surround7_1: return 8
            case .surround7_1_4: return 12
            case .surround9_1_6: return 16
            case .ambisonics1stOrder: return 4
            case .ambisonics3rdOrder: return 16
            case .binauralHRTF: return 2
            case .objectBased: return 128  // Up to 128 objects in Atmos
            case .sceneБased: return 16    // Typical 3rd-order ambisonics
            case .waveFieldSynthesis: return 256  // Depends on setup
            }
        }
    }

    // MARK: - Psychoacoustic Phenomena

    /// Shepard Tone (Auditory Illusion)
    /// Creates impression of continuously ascending/descending pitch
    /// Used in film scores (Dunkirk, The Dark Knight)
    func generateShepardTone(baseFrequency: Float, octaves: Int = 8) -> AVAudioPCMBuffer {
        let duration: Float = 1.0
        let sampleRate = 48000.0
        let frameCount = AVAudioFrameCount(sampleRate * Double(duration))

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            return buffer
        }

        // Generate multiple sine waves at octave intervals
        for i in 0..<Int(frameCount) {
            let time = Float(i) / Float(sampleRate)
            var sample: Float = 0.0

            for octave in 0..<octaves {
                let frequency = baseFrequency * pow(2.0, Float(octave))

                // Gaussian envelope to fade out high and low frequencies
                let logFreq = log2(frequency / baseFrequency)
                let center = Float(octaves) / 2.0
                let spread: Float = 1.5
                let envelope = exp(-pow(logFreq - center, 2) / (2 * spread * spread))

                // Sine wave
                sample += sin(2.0 * .pi * frequency * time) * envelope
            }

            // Normalize
            sample /= Float(octaves)

            leftChannel[i] = sample
            rightChannel[i] = sample
        }

        return buffer
    }

    /// Phantom Fundamental (Missing Fundamental)
    /// Brain perceives fundamental frequency even when it's not present
    /// E.g., play 800Hz + 1000Hz + 1200Hz → brain hears 200Hz
    func generatePhantomFundamental(fundamental: Float, harmonics: [Int]) -> AVAudioPCMBuffer {
        let duration: Float = 1.0
        let sampleRate = 48000.0
        let frameCount = AVAudioFrameCount(sampleRate * Double(duration))

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            return buffer
        }

        // Generate harmonics WITHOUT fundamental
        for i in 0..<Int(frameCount) {
            let time = Float(i) / Float(sampleRate)
            var sample: Float = 0.0

            for harmonic in harmonics {
                let frequency = fundamental * Float(harmonic)
                sample += sin(2.0 * .pi * frequency * time) / Float(harmonic)
            }

            // Normalize
            sample /= Float(harmonics.count)

            leftChannel[i] = sample
            rightChannel[i] = sample
        }

        // Brain will perceive fundamental frequency (e.g., 200Hz)
        // even though only harmonics are present!

        return buffer
    }

    /// Critical Bands (Bark Scale)
    /// Frequencies within same critical band interfere
    /// Used for masking, compression, psychoacoustic audio coding (MP3, AAC)
    func frequencyToBark(_ frequency: Float) -> Float {
        // Traunmüller formula (1990)
        let bark = (26.81 * frequency) / (1960 + frequency) - 0.53

        // Corrections for extreme frequencies
        if bark < 2 {
            return bark + 0.15 * (2 - bark)
        } else if bark > 20.1 {
            return bark + 0.22 * (bark - 20.1)
        }

        return bark
    }

    func barkToFrequency(_ bark: Float) -> Float {
        // Inverse Traunmüller formula
        return 1960 * (bark + 0.53) / (26.28 - bark)
    }

    /// Masking Threshold
    /// Louder sounds mask quieter sounds in nearby frequencies
    /// Basis of perceptual audio coding (MP3, AAC, Opus)
    func calculateMaskingThreshold(maskerFrequency: Float, maskerLevel: Float, testFrequency: Float) -> Float {
        let maskerBark = frequencyToBark(maskerFrequency)
        let testBark = frequencyToBark(testFrequency)

        let barkDistance = abs(testBark - maskerBark)

        // Simplified masking model
        // Real implementation would use more complex spreading function
        let masking: Float
        if barkDistance < 1.0 {
            // Within same critical band: strong masking
            masking = maskerLevel - 5.0
        } else if barkDistance < 3.0 {
            // Adjacent bands: moderate masking
            masking = maskerLevel - 10.0 - (barkDistance - 1.0) * 10.0
        } else {
            // Distant bands: minimal masking
            masking = maskerLevel - 40.0
        }

        return max(masking, 0.0)  // Threshold in dB SPL
    }

    /// Fletcher-Munson Equal Loudness Contours
    /// Human hearing is not equally sensitive at all frequencies
    /// Most sensitive around 2-5 kHz (speech range)
    func applyEqualLoudnessContour(spectrum: [Float], contourLevel: Float = 40.0) -> [Float] {
        // Simplified A-weighting approximation
        // Full implementation would use ISO 226:2003 standard

        var weighted = spectrum

        for (index, frequency) in stride(from: 20.0, through: 20000.0, by: 20.0).enumerated() {
            guard index < weighted.count else { break }

            // A-weighting approximation
            let ra = pow(12194, 2) * pow(frequency, 4) /
                    ((pow(frequency, 2) + pow(20.6, 2)) *
                     sqrt((pow(frequency, 2) + pow(107.7, 2)) * (pow(frequency, 2) + pow(737.9, 2))) *
                     (pow(frequency, 2) + pow(12194, 2)))

            let aWeight = 20 * log10(ra) + 2.0

            // Apply weighting
            weighted[index] *= pow(10, aWeight / 20.0)
        }

        return weighted
    }

    // MARK: - Sacred Geometry in Sound

    /// Cymatics Frequencies (Geometric Patterns)
    /// Certain frequencies create specific geometric patterns in matter
    /// Based on Hans Jenny's Cymatics research (1967)
    static let cymaticsFrequencies: [Float: String] = [
        // Water patterns
        24.0: "Hexagonal pattern (snowflake)",
        110.0: "Circular ripples",
        147.0: "Square pattern",
        200.0: "Octagon",
        440.0: "Complex mandala (A4)",
        528.0: "Star of David (Solfeggio)",
        639.0: "Flower pattern (Solfeggio)",

        // Sand/salt patterns
        50.0: "Simple circle",
        100.0: "Square with diagonals",
        150.0: "Triangle",
        300.0: "Hexagram",
        400.0: "Octagram",
        500.0: "Pentagon (rare)",

        // Platonic solids associations
        216.0: "Cube resonance",
        432.0: "Octahedron resonance (A432)",
        528.0: "Icosahedron/Dodecahedron (DNA repair)"
    ]

    /// Generate frequency based on sacred geometric ratio
    func frequencyForGeometry(_ geometry: SacredGeometry) -> Float {
        let baseFrequency = currentTuning.a4Frequency

        switch geometry {
        case .circle:
            return baseFrequency  // 1:1 ratio

        case .vesicaPiscis:
            return baseFrequency * sqrt(3.0)  // √3:1

        case .triangle:
            return baseFrequency * sqrt(3.0) / 2.0

        case .square:
            return baseFrequency * sqrt(2.0)  // √2:1

        case .pentagon:
            return baseFrequency * GOLDEN_RATIO  // φ:1

        case .hexagon:
            return baseFrequency * sqrt(3.0)

        case .heptagon:
            return baseFrequency * 2.0 * cos(.pi / 7.0)

        case .octagon:
            return baseFrequency * (1.0 + sqrt(2.0))

        case .goldenSpiral:
            return baseFrequency * GOLDEN_RATIO

        case .flowerOfLife:
            return 528.0  // Solfeggio frequency

        case .seedOfLife:
            return 639.0  // Solfeggio frequency

        case .metatronsCube:
            return 741.0  // Solfeggio frequency

        case .sriYantra:
            return 432.0  // Sacred tuning
        }
    }

    enum SacredGeometry {
        case circle
        case vesicaPiscis
        case triangle
        case square
        case pentagon
        case hexagon
        case heptagon
        case octagon
        case goldenSpiral
        case flowerOfLife
        case seedOfLife
        case metatronsCube
        case sriYantra
    }
}

// MARK: - Scientific References

extension PsychoAcousticEngine {
    static let scientificReferences = """
        PSYCHOACOUSTIC SCIENCE REFERENCES

        Foundational Research:
        • Fletcher & Munson (1933). "Loudness, its definition, measurement and calculation."
          Journal of the Acoustical Society of America, 5, 82-108.

        • Zwicker, E. (1961). "Subdivision of the audible frequency range into critical bands."
          Journal of the Acoustical Society of America, 33, 248.

        • Shepard, R. (1964). "Circularity in judgments of relative pitch."
          Journal of the Acoustical Society of America, 36, 2346-2353.

        • Schouten, J. F. (1940). "The residue, a new component in subjective sound analysis."
          Proceedings of the Koninklijke Nederlandse Akademie van Wetenschappen, 43, 356-365.

        • Jenny, H. (1967). Cymatics: A Study of Wave Phenomena and Vibration.
          Basel: Basilius Presse.

        Tuning & Temperament:
        • Duffin, R. W. (2007). How Equal Temperament Ruined Harmony.
          New York: W.W. Norton.

        • Partch, H. (1974). Genesis of a Music (2nd ed.).
          New York: Da Capo Press.

        Sacred Sound:
        • Beaulieu, J. (2010). Human Tuning: Sound Healing with Tuning Forks.
          BioSonic Enterprises.

        • Goldman, J. (1992). Healing Sounds: The Power of Harmonics.
          Element Books.
        """
}

import Foundation
import Accelerate

// MARK: - Voice Character Engine
// Comprehensive timbre and character system for harmonization
// Supports: Original, Choir, Synth, Acoustic Instruments

@MainActor
public final class VoiceCharacterEngine: ObservableObject {
    public static let shared = VoiceCharacterEngine()

    @Published public private(set) var activeCharacter: VoiceCharacter = .original
    @Published public private(set) var characterBlend: [VoiceCharacter: Double] = [:]
    @Published public private(set) var isProcessing = false

    // Character processors
    private var choirProcessor: ChoirCharacterProcessor
    private var synthProcessor: SynthCharacterProcessor
    private var acousticProcessor: AcousticInstrumentProcessor
    private var originalProcessor: OriginalVoiceProcessor

    // Morphing engine for smooth transitions
    private var morphEngine: CharacterMorphEngine

    public init() {
        self.choirProcessor = ChoirCharacterProcessor()
        self.synthProcessor = SynthCharacterProcessor()
        self.acousticProcessor = AcousticInstrumentProcessor()
        self.originalProcessor = OriginalVoiceProcessor()
        self.morphEngine = CharacterMorphEngine()
    }

    // MARK: - Character Selection

    public func setCharacter(_ character: VoiceCharacter) {
        activeCharacter = character
        characterBlend = [character: 1.0]
    }

    public func blendCharacters(_ blend: [VoiceCharacter: Double]) {
        // Normalize blend weights
        let total = blend.values.reduce(0, +)
        if total > 0 {
            characterBlend = blend.mapValues { $0 / total }
        }
    }

    public func morphTo(_ target: VoiceCharacter, duration: TimeInterval) async {
        await morphEngine.morph(from: activeCharacter, to: target, duration: duration)
        activeCharacter = target
        characterBlend = [target: 1.0]
    }

    // MARK: - Audio Processing

    public func processAudio(
        _ samples: [Float],
        voices: [HarmonizedVoice],
        sampleRate: Double
    ) -> [VoiceCharacterOutput] {
        isProcessing = true
        defer { isProcessing = false }

        var outputs: [VoiceCharacterOutput] = []

        for voice in voices {
            let characterParams = getCharacterParameters(for: activeCharacter, voice: voice)

            var processedSamples: [Float]

            switch activeCharacter.category {
            case .original:
                processedSamples = originalProcessor.process(samples, params: characterParams)
            case .choir:
                processedSamples = choirProcessor.process(samples, params: characterParams)
            case .synth:
                processedSamples = synthProcessor.process(samples, params: characterParams)
            case .acoustic:
                processedSamples = acousticProcessor.process(samples, params: characterParams)
            }

            // Apply character-specific envelope
            let envelope = generateEnvelope(for: activeCharacter, length: processedSamples.count)
            vDSP_vmul(processedSamples, 1, envelope, 1, &processedSamples, 1, vDSP_Length(processedSamples.count))

            outputs.append(VoiceCharacterOutput(
                voice: voice,
                character: activeCharacter,
                samples: processedSamples,
                parameters: characterParams
            ))
        }

        return outputs
    }

    // MARK: - Character Parameters

    private func getCharacterParameters(for character: VoiceCharacter, voice: HarmonizedVoice) -> CharacterParameters {
        var params = character.defaultParameters

        // Adjust based on voice type
        switch voice.voiceType {
        case .soprano:
            params.formantShift = 1.1
            params.brightness = min(1.0, params.brightness + 0.1)
        case .alto:
            params.formantShift = 1.0
        case .tenor:
            params.formantShift = 0.95
            params.warmth = min(1.0, params.warmth + 0.1)
        case .bass:
            params.formantShift = 0.85
            params.subHarmonics = min(1.0, params.subHarmonics + 0.2)
        }

        return params
    }

    private func generateEnvelope(for character: VoiceCharacter, length: Int) -> [Float] {
        var envelope = [Float](repeating: 1.0, count: length)
        let attack = character.defaultParameters.attackTime
        let release = character.defaultParameters.releaseTime

        // Attack phase
        let attackSamples = Int(attack * 44100)
        for i in 0..<min(attackSamples, length) {
            envelope[i] = Float(i) / Float(attackSamples)
        }

        // Release phase
        let releaseSamples = Int(release * 44100)
        let releaseStart = max(0, length - releaseSamples)
        for i in releaseStart..<length {
            let releaseProgress = Float(i - releaseStart) / Float(releaseSamples)
            envelope[i] *= 1.0 - releaseProgress
        }

        return envelope
    }
}

// MARK: - Voice Character Types

public enum VoiceCharacter: String, CaseIterable, Identifiable {
    public var id: String { rawValue }

    // Original/Clean
    case original = "Original"
    case naturalVoice = "Natural Voice"
    case pureHarmonic = "Pure Harmonic"
    case crystalClear = "Crystal Clear"

    // Choir Types
    case cathedralChoir = "Cathedral Choir"
    case gospelChoir = "Gospel Choir"
    case chamberChoir = "Chamber Choir"
    case boysChoir = "Boys Choir"
    case russianOrthodox = "Russian Orthodox"
    case africanChoir = "African Choir"
    case nordicChoir = "Nordic Choir"
    case medievalChant = "Medieval Chant"
    case barbershopQuartet = "Barbershop Quartet"
    case vocalJazz = "Vocal Jazz"
    case operaChorus = "Opera Chorus"
    case gregorianChant = "Gregorian Chant"

    // Synth Voices
    case analogWarm = "Analog Warm"
    case analogCold = "Analog Cold"
    case digitalPrecise = "Digital Precise"
    case wavetableMorph = "Wavetable Morph"
    case fmBright = "FM Bright"
    case fmBell = "FM Bell"
    case granularTexture = "Granular Texture"
    case supersaw = "Supersaw"
    case vocoder = "Vocoder"
    case talkbox = "Talkbox"
    case retrowave = "Retrowave"
    case ambientPad = "Ambient Pad"
    case synthBrass = "Synth Brass"
    case synthStrings = "Synth Strings"
    case modularDrone = "Modular Drone"

    // Acoustic Strings
    case violinSection = "Violin Section"
    case violaSolo = "Viola Solo"
    case celloSection = "Cello Section"
    case contrabass = "Contrabass"
    case fullOrchestra = "Full Orchestra"
    case chamberStrings = "Chamber Strings"
    case soloViolin = "Solo Violin"
    case pizzicato = "Pizzicato"
    case tremolo = "Tremolo Strings"

    // Acoustic Brass
    case trumpetSection = "Trumpet Section"
    case tromboneSection = "Trombone Section"
    case frenchHorns = "French Horns"
    case tubaBass = "Tuba Bass"
    case brassEnsemble = "Brass Ensemble"
    case soloTrumpet = "Solo Trumpet"
    case flugelhorn = "Flugelhorn"
    case muted = "Muted Brass"

    // Acoustic Woodwinds
    case fluteSection = "Flute Section"
    case oboeSection = "Oboe Section"
    case clarinetSection = "Clarinet Section"
    case bassoon = "Bassoon"
    case woodwindEnsemble = "Woodwind Ensemble"
    case soloFlute = "Solo Flute"
    case panFlute = "Pan Flute"
    case recorder = "Recorder"
    case saxophone = "Saxophone"

    // Acoustic Keyboards
    case grandPiano = "Grand Piano"
    case uprightPiano = "Upright Piano"
    case electricPiano = "Electric Piano"
    case harpsichord = "Harpsichord"
    case celesta = "Celesta"
    case organPipe = "Pipe Organ"
    case organHammond = "Hammond Organ"
    case accordion = "Accordion"

    // Acoustic Plucked
    case acousticGuitar = "Acoustic Guitar"
    case classicalGuitar = "Classical Guitar"
    case harp = "Harp"
    case mandolin = "Mandolin"
    case banjo = "Banjo"
    case sitar = "Sitar"
    case koto = "Koto"

    // Ethnic/World
    case didgeridoo = "Didgeridoo"
    case shakuhachi = "Shakuhachi"
    case erhu = "Erhu"
    case balalaika = "Balalaika"
    case bouzouki = "Bouzouki"
    case gamelan = "Gamelan"
    case steelDrum = "Steel Drum"

    public var category: CharacterCategory {
        switch self {
        case .original, .naturalVoice, .pureHarmonic, .crystalClear:
            return .original
        case .cathedralChoir, .gospelChoir, .chamberChoir, .boysChoir,
             .russianOrthodox, .africanChoir, .nordicChoir, .medievalChant,
             .barbershopQuartet, .vocalJazz, .operaChorus, .gregorianChant:
            return .choir
        case .analogWarm, .analogCold, .digitalPrecise, .wavetableMorph,
             .fmBright, .fmBell, .granularTexture, .supersaw, .vocoder,
             .talkbox, .retrowave, .ambientPad, .synthBrass, .synthStrings, .modularDrone:
            return .synth
        default:
            return .acoustic
        }
    }

    public var defaultParameters: CharacterParameters {
        switch self {
        // Original
        case .original:
            return CharacterParameters()
        case .naturalVoice:
            return CharacterParameters(warmth: 0.6, brightness: 0.5, breathiness: 0.2)
        case .pureHarmonic:
            return CharacterParameters(harmonicRichness: 0.9, brightness: 0.7)
        case .crystalClear:
            return CharacterParameters(brightness: 0.85, airiness: 0.6, harmonicRichness: 0.5)

        // Choir
        case .cathedralChoir:
            return CharacterParameters(
                reverbAmount: 0.8, reverbSize: 0.9, warmth: 0.7,
                chorusAmount: 0.4, stereoWidth: 0.9, attackTime: 0.15
            )
        case .gospelChoir:
            return CharacterParameters(
                warmth: 0.8, brightness: 0.7, vibrato: 0.5, vibratoRate: 5.5,
                chorusAmount: 0.3, harmonicRichness: 0.8
            )
        case .chamberChoir:
            return CharacterParameters(
                reverbAmount: 0.4, warmth: 0.6, brightness: 0.6,
                stereoWidth: 0.6, chorusAmount: 0.2
            )
        case .boysChoir:
            return CharacterParameters(
                brightness: 0.8, formantShift: 1.2, airiness: 0.4,
                reverbAmount: 0.6, vibrato: 0.2
            )
        case .russianOrthodox:
            return CharacterParameters(
                warmth: 0.9, subHarmonics: 0.5, reverbAmount: 0.7,
                reverbSize: 0.85, formantShift: 0.9, attackTime: 0.2
            )
        case .africanChoir:
            return CharacterParameters(
                warmth: 0.75, brightness: 0.65, harmonicRichness: 0.8,
                vibrato: 0.3, chorusAmount: 0.35, stereoWidth: 0.8
            )
        case .nordicChoir:
            return CharacterParameters(
                airiness: 0.5, brightness: 0.6, reverbAmount: 0.5,
                formantShift: 1.05, warmth: 0.5
            )
        case .medievalChant:
            return CharacterParameters(
                reverbAmount: 0.75, reverbSize: 0.8, warmth: 0.6,
                vibrato: 0.1, attackTime: 0.2, releaseTime: 0.3
            )
        case .barbershopQuartet:
            return CharacterParameters(
                harmonicRichness: 0.9, warmth: 0.7, brightness: 0.6,
                stereoWidth: 0.5, reverbAmount: 0.2, vibrato: 0.25
            )
        case .vocalJazz:
            return CharacterParameters(
                warmth: 0.65, brightness: 0.55, breathiness: 0.3,
                vibrato: 0.35, vibratoRate: 5.0, reverbAmount: 0.35
            )
        case .operaChorus:
            return CharacterParameters(
                vibrato: 0.6, vibratoRate: 6.0, harmonicRichness: 0.85,
                reverbAmount: 0.6, warmth: 0.7, formantShift: 1.05
            )
        case .gregorianChant:
            return CharacterParameters(
                reverbAmount: 0.8, reverbSize: 0.9, warmth: 0.5,
                brightness: 0.4, vibrato: 0.05, attackTime: 0.25
            )

        // Synth
        case .analogWarm:
            return CharacterParameters(
                warmth: 0.9, brightness: 0.4, filterCutoff: 0.6,
                filterResonance: 0.3, subHarmonics: 0.3, detuneAmount: 0.02
            )
        case .analogCold:
            return CharacterParameters(
                warmth: 0.3, brightness: 0.7, filterCutoff: 0.75,
                filterResonance: 0.5, detuneAmount: 0.01
            )
        case .digitalPrecise:
            return CharacterParameters(
                brightness: 0.8, harmonicRichness: 0.6, filterCutoff: 0.9,
                attackTime: 0.01, releaseTime: 0.1
            )
        case .wavetableMorph:
            return CharacterParameters(
                harmonicRichness: 0.7, brightness: 0.6, morphRate: 0.5,
                wavetablePosition: 0.5, filterCutoff: 0.7
            )
        case .fmBright:
            return CharacterParameters(
                brightness: 0.9, harmonicRichness: 0.8, fmRatio: 3.0,
                fmDepth: 0.6, attackTime: 0.02
            )
        case .fmBell:
            return CharacterParameters(
                brightness: 0.85, harmonicRichness: 0.7, fmRatio: 7.0,
                fmDepth: 0.4, attackTime: 0.001, releaseTime: 2.0
            )
        case .granularTexture:
            return CharacterParameters(
                grainSize: 0.05, grainDensity: 0.7, grainPitch: 1.0,
                stereoWidth: 0.9, reverbAmount: 0.4
            )
        case .supersaw:
            return CharacterParameters(
                detuneAmount: 0.15, unisonVoices: 7, stereoWidth: 1.0,
                brightness: 0.75, filterCutoff: 0.8
            )
        case .vocoder:
            return CharacterParameters(
                vocoderBands: 16, vocoderAttack: 0.01, vocoderRelease: 0.1,
                brightness: 0.6, formantShift: 1.0
            )
        case .talkbox:
            return CharacterParameters(
                formantShift: 1.0, filterCutoff: 0.7, filterResonance: 0.6,
                vowelBlend: 0.5, brightness: 0.65
            )
        case .retrowave:
            return CharacterParameters(
                warmth: 0.6, brightness: 0.7, chorusAmount: 0.5,
                detuneAmount: 0.03, reverbAmount: 0.4, stereoWidth: 0.8
            )
        case .ambientPad:
            return CharacterParameters(
                attackTime: 0.5, releaseTime: 1.5, reverbAmount: 0.7,
                reverbSize: 0.85, filterCutoff: 0.5, warmth: 0.6
            )
        case .synthBrass:
            return CharacterParameters(
                brightness: 0.75, filterCutoff: 0.7, filterResonance: 0.4,
                attackTime: 0.05, warmth: 0.5, unisonVoices: 3
            )
        case .synthStrings:
            return CharacterParameters(
                attackTime: 0.2, releaseTime: 0.4, chorusAmount: 0.4,
                warmth: 0.6, stereoWidth: 0.7, detuneAmount: 0.02
            )
        case .modularDrone:
            return CharacterParameters(
                subHarmonics: 0.4, harmonicRichness: 0.6, filterCutoff: 0.5,
                filterResonance: 0.5, lfoRate: 0.1, lfoDepth: 0.3
            )

        // Strings
        case .violinSection:
            return CharacterParameters(
                warmth: 0.6, brightness: 0.65, vibrato: 0.4, vibratoRate: 5.5,
                attackTime: 0.08, bowPressure: 0.6, stereoWidth: 0.7
            )
        case .violaSolo:
            return CharacterParameters(
                warmth: 0.7, brightness: 0.5, vibrato: 0.45, vibratoRate: 5.2,
                formantShift: 0.95, bowPressure: 0.55
            )
        case .celloSection:
            return CharacterParameters(
                warmth: 0.75, brightness: 0.45, vibrato: 0.35, vibratoRate: 5.0,
                subHarmonics: 0.2, bowPressure: 0.6, stereoWidth: 0.6
            )
        case .contrabass:
            return CharacterParameters(
                warmth: 0.8, brightness: 0.3, subHarmonics: 0.4,
                formantShift: 0.8, attackTime: 0.1, bowPressure: 0.7
            )
        case .fullOrchestra:
            return CharacterParameters(
                reverbAmount: 0.5, stereoWidth: 1.0, warmth: 0.65,
                brightness: 0.6, harmonicRichness: 0.75
            )
        case .chamberStrings:
            return CharacterParameters(
                warmth: 0.6, brightness: 0.6, reverbAmount: 0.35,
                stereoWidth: 0.6, vibrato: 0.35
            )
        case .soloViolin:
            return CharacterParameters(
                brightness: 0.7, vibrato: 0.5, vibratoRate: 5.8,
                bowPressure: 0.5, formantShift: 1.05
            )
        case .pizzicato:
            return CharacterParameters(
                attackTime: 0.005, releaseTime: 0.3, brightness: 0.6,
                warmth: 0.5, pluckPosition: 0.3
            )
        case .tremolo:
            return CharacterParameters(
                tremoloRate: 8.0, tremoloDepth: 0.6, brightness: 0.6,
                warmth: 0.6, stereoWidth: 0.7
            )

        // Brass
        case .trumpetSection:
            return CharacterParameters(
                brightness: 0.8, warmth: 0.5, attackTime: 0.03,
                breathiness: 0.15, harmonicRichness: 0.75, stereoWidth: 0.6
            )
        case .tromboneSection:
            return CharacterParameters(
                warmth: 0.7, brightness: 0.6, attackTime: 0.05,
                subHarmonics: 0.15, harmonicRichness: 0.7
            )
        case .frenchHorns:
            return CharacterParameters(
                warmth: 0.75, brightness: 0.5, reverbAmount: 0.4,
                attackTime: 0.08, harmonicRichness: 0.65
            )
        case .tubaBass:
            return CharacterParameters(
                warmth: 0.8, subHarmonics: 0.5, brightness: 0.35,
                attackTime: 0.1, formantShift: 0.75
            )
        case .brassEnsemble:
            return CharacterParameters(
                brightness: 0.7, warmth: 0.6, stereoWidth: 0.8,
                harmonicRichness: 0.75, attackTime: 0.04
            )
        case .soloTrumpet:
            return CharacterParameters(
                brightness: 0.85, vibrato: 0.3, vibratoRate: 5.0,
                breathiness: 0.2, attackTime: 0.02
            )
        case .flugelhorn:
            return CharacterParameters(
                warmth: 0.75, brightness: 0.55, breathiness: 0.2,
                attackTime: 0.04, vibrato: 0.25
            )
        case .muted:
            return CharacterParameters(
                filterCutoff: 0.5, brightness: 0.4, warmth: 0.6,
                nasalAmount: 0.4, attackTime: 0.03
            )

        // Woodwinds
        case .fluteSection:
            return CharacterParameters(
                airiness: 0.6, brightness: 0.75, breathiness: 0.35,
                attackTime: 0.04, stereoWidth: 0.6, vibrato: 0.3
            )
        case .oboeSection:
            return CharacterParameters(
                nasalAmount: 0.5, brightness: 0.65, vibrato: 0.35,
                vibratoRate: 5.5, reedBuzziness: 0.4
            )
        case .clarinetSection:
            return CharacterParameters(
                warmth: 0.7, brightness: 0.5, reedBuzziness: 0.25,
                breathiness: 0.2, attackTime: 0.03
            )
        case .bassoon:
            return CharacterParameters(
                warmth: 0.75, subHarmonics: 0.25, reedBuzziness: 0.4,
                formantShift: 0.85, brightness: 0.45
            )
        case .woodwindEnsemble:
            return CharacterParameters(
                brightness: 0.6, warmth: 0.55, stereoWidth: 0.75,
                breathiness: 0.25, harmonicRichness: 0.6
            )
        case .soloFlute:
            return CharacterParameters(
                airiness: 0.7, breathiness: 0.4, brightness: 0.8,
                vibrato: 0.4, vibratoRate: 5.5
            )
        case .panFlute:
            return CharacterParameters(
                airiness: 0.8, breathiness: 0.5, brightness: 0.6,
                warmth: 0.5, vibrato: 0.2
            )
        case .recorder:
            return CharacterParameters(
                airiness: 0.5, brightness: 0.7, breathiness: 0.3,
                formantShift: 1.1, vibrato: 0.15
            )
        case .saxophone:
            return CharacterParameters(
                warmth: 0.7, brightness: 0.6, breathiness: 0.25,
                reedBuzziness: 0.35, vibrato: 0.4, vibratoRate: 5.0
            )

        // Keyboards
        case .grandPiano:
            return CharacterParameters(
                brightness: 0.65, warmth: 0.6, attackTime: 0.005,
                releaseTime: 1.0, hammerHardness: 0.6, stereoWidth: 0.8
            )
        case .uprightPiano:
            return CharacterParameters(
                brightness: 0.55, warmth: 0.7, attackTime: 0.005,
                releaseTime: 0.8, hammerHardness: 0.5
            )
        case .electricPiano:
            return CharacterParameters(
                warmth: 0.65, brightness: 0.6, bellTone: 0.4,
                attackTime: 0.002, releaseTime: 0.6, tremoloRate: 4.0
            )
        case .harpsichord:
            return CharacterParameters(
                brightness: 0.8, attackTime: 0.001, releaseTime: 0.4,
                pluckPosition: 0.2, harmonicRichness: 0.7
            )
        case .celesta:
            return CharacterParameters(
                brightness: 0.85, bellTone: 0.7, attackTime: 0.002,
                releaseTime: 1.5, sparkle: 0.6
            )
        case .organPipe:
            return CharacterParameters(
                harmonicRichness: 0.8, reverbAmount: 0.6, reverbSize: 0.8,
                attackTime: 0.1, releaseTime: 0.15, warmth: 0.6
            )
        case .organHammond:
            return CharacterParameters(
                harmonicRichness: 0.75, drawbarConfig: [8, 8, 6, 0, 0, 0, 4, 0, 0],
                rotarySpeed: 0.0, attackTime: 0.01, warmth: 0.65
            )
        case .accordion:
            return CharacterParameters(
                reedBuzziness: 0.5, bellowsPressure: 0.6, warmth: 0.6,
                brightness: 0.55, tremoloRate: 5.0, tremoloDepth: 0.3
            )

        // Plucked
        case .acousticGuitar:
            return CharacterParameters(
                brightness: 0.6, warmth: 0.65, attackTime: 0.003,
                releaseTime: 0.5, pluckPosition: 0.4, bodyResonance: 0.6
            )
        case .classicalGuitar:
            return CharacterParameters(
                warmth: 0.75, brightness: 0.5, attackTime: 0.005,
                releaseTime: 0.6, pluckPosition: 0.5, bodyResonance: 0.65
            )
        case .harp:
            return CharacterParameters(
                brightness: 0.7, sparkle: 0.5, attackTime: 0.002,
                releaseTime: 1.2, stereoWidth: 0.85
            )
        case .mandolin:
            return CharacterParameters(
                brightness: 0.75, attackTime: 0.001, releaseTime: 0.3,
                tremoloRate: 8.0, tremoloDepth: 0.5, pluckPosition: 0.3
            )
        case .banjo:
            return CharacterParameters(
                brightness: 0.85, attackTime: 0.001, releaseTime: 0.2,
                twangAmount: 0.7, pluckPosition: 0.2
            )
        case .sitar:
            return CharacterParameters(
                sympatheticResonance: 0.6, brightness: 0.7, bendRange: 0.5,
                buzzAmount: 0.4, attackTime: 0.003
            )
        case .koto:
            return CharacterParameters(
                brightness: 0.7, attackTime: 0.002, releaseTime: 0.8,
                bendRange: 0.3, bodyResonance: 0.5
            )

        // Ethnic
        case .didgeridoo:
            return CharacterParameters(
                subHarmonics: 0.7, droneFrequency: 0.3, formantShift: 0.7,
                breathiness: 0.4, harmonicRichness: 0.6
            )
        case .shakuhachi:
            return CharacterParameters(
                airiness: 0.7, breathiness: 0.5, brightness: 0.55,
                vibrato: 0.35, bendRange: 0.4
            )
        case .erhu:
            return CharacterParameters(
                vibrato: 0.5, vibratoRate: 5.5, warmth: 0.65,
                brightness: 0.55, nasalAmount: 0.3, bowPressure: 0.5
            )
        case .balalaika:
            return CharacterParameters(
                brightness: 0.75, attackTime: 0.001, releaseTime: 0.25,
                tremoloRate: 10.0, tremoloDepth: 0.6
            )
        case .bouzouki:
            return CharacterParameters(
                brightness: 0.7, attackTime: 0.002, releaseTime: 0.35,
                tremoloRate: 8.0, tremoloDepth: 0.5
            )
        case .gamelan:
            return CharacterParameters(
                bellTone: 0.7, brightness: 0.65, releaseTime: 2.0,
                shimmer: 0.5, detuneAmount: 0.04
            )
        case .steelDrum:
            return CharacterParameters(
                bellTone: 0.6, brightness: 0.7, attackTime: 0.002,
                releaseTime: 0.8, harmonicRichness: 0.65
            )
        }
    }
}

public enum CharacterCategory: String, CaseIterable {
    case original = "Original"
    case choir = "Choir"
    case synth = "Synthesizer"
    case acoustic = "Acoustic"
}

// MARK: - Character Parameters

public struct CharacterParameters {
    // Basic timbre
    public var warmth: Double = 0.5
    public var brightness: Double = 0.5
    public var airiness: Double = 0.0
    public var breathiness: Double = 0.0
    public var harmonicRichness: Double = 0.5

    // Formants
    public var formantShift: Double = 1.0
    public var vowelBlend: Double = 0.0
    public var nasalAmount: Double = 0.0

    // Envelope
    public var attackTime: Double = 0.01
    public var releaseTime: Double = 0.2

    // Filter
    public var filterCutoff: Double = 1.0
    public var filterResonance: Double = 0.0

    // Modulation
    public var vibrato: Double = 0.0
    public var vibratoRate: Double = 5.0
    public var tremoloRate: Double = 0.0
    public var tremoloDepth: Double = 0.0
    public var lfoRate: Double = 0.0
    public var lfoDepth: Double = 0.0

    // Effects
    public var reverbAmount: Double = 0.0
    public var reverbSize: Double = 0.5
    public var chorusAmount: Double = 0.0
    public var stereoWidth: Double = 0.5

    // Synth-specific
    public var detuneAmount: Double = 0.0
    public var unisonVoices: Int = 1
    public var subHarmonics: Double = 0.0
    public var fmRatio: Double = 1.0
    public var fmDepth: Double = 0.0
    public var wavetablePosition: Double = 0.0
    public var morphRate: Double = 0.0
    public var grainSize: Double = 0.05
    public var grainDensity: Double = 0.5
    public var grainPitch: Double = 1.0
    public var vocoderBands: Int = 8
    public var vocoderAttack: Double = 0.01
    public var vocoderRelease: Double = 0.1

    // Acoustic-specific
    public var bowPressure: Double = 0.5
    public var pluckPosition: Double = 0.5
    public var hammerHardness: Double = 0.5
    public var reedBuzziness: Double = 0.0
    public var bellowsPressure: Double = 0.5
    public var bodyResonance: Double = 0.5
    public var sympatheticResonance: Double = 0.0
    public var bendRange: Double = 0.0
    public var twangAmount: Double = 0.0
    public var buzzAmount: Double = 0.0
    public var bellTone: Double = 0.0
    public var sparkle: Double = 0.0
    public var shimmer: Double = 0.0
    public var droneFrequency: Double = 0.0
    public var drawbarConfig: [Int] = [8, 8, 8, 0, 0, 0, 0, 0, 0]
    public var rotarySpeed: Double = 0.0

    public init(
        warmth: Double = 0.5,
        brightness: Double = 0.5,
        airiness: Double = 0.0,
        breathiness: Double = 0.0,
        harmonicRichness: Double = 0.5,
        formantShift: Double = 1.0,
        vowelBlend: Double = 0.0,
        nasalAmount: Double = 0.0,
        attackTime: Double = 0.01,
        releaseTime: Double = 0.2,
        filterCutoff: Double = 1.0,
        filterResonance: Double = 0.0,
        vibrato: Double = 0.0,
        vibratoRate: Double = 5.0,
        tremoloRate: Double = 0.0,
        tremoloDepth: Double = 0.0,
        lfoRate: Double = 0.0,
        lfoDepth: Double = 0.0,
        reverbAmount: Double = 0.0,
        reverbSize: Double = 0.5,
        chorusAmount: Double = 0.0,
        stereoWidth: Double = 0.5,
        detuneAmount: Double = 0.0,
        unisonVoices: Int = 1,
        subHarmonics: Double = 0.0,
        fmRatio: Double = 1.0,
        fmDepth: Double = 0.0,
        wavetablePosition: Double = 0.0,
        morphRate: Double = 0.0,
        grainSize: Double = 0.05,
        grainDensity: Double = 0.5,
        grainPitch: Double = 1.0,
        vocoderBands: Int = 8,
        vocoderAttack: Double = 0.01,
        vocoderRelease: Double = 0.1,
        bowPressure: Double = 0.5,
        pluckPosition: Double = 0.5,
        hammerHardness: Double = 0.5,
        reedBuzziness: Double = 0.0,
        bellowsPressure: Double = 0.5,
        bodyResonance: Double = 0.5,
        sympatheticResonance: Double = 0.0,
        bendRange: Double = 0.0,
        twangAmount: Double = 0.0,
        buzzAmount: Double = 0.0,
        bellTone: Double = 0.0,
        sparkle: Double = 0.0,
        shimmer: Double = 0.0,
        droneFrequency: Double = 0.0,
        drawbarConfig: [Int] = [8, 8, 8, 0, 0, 0, 0, 0, 0],
        rotarySpeed: Double = 0.0
    ) {
        self.warmth = warmth
        self.brightness = brightness
        self.airiness = airiness
        self.breathiness = breathiness
        self.harmonicRichness = harmonicRichness
        self.formantShift = formantShift
        self.vowelBlend = vowelBlend
        self.nasalAmount = nasalAmount
        self.attackTime = attackTime
        self.releaseTime = releaseTime
        self.filterCutoff = filterCutoff
        self.filterResonance = filterResonance
        self.vibrato = vibrato
        self.vibratoRate = vibratoRate
        self.tremoloRate = tremoloRate
        self.tremoloDepth = tremoloDepth
        self.lfoRate = lfoRate
        self.lfoDepth = lfoDepth
        self.reverbAmount = reverbAmount
        self.reverbSize = reverbSize
        self.chorusAmount = chorusAmount
        self.stereoWidth = stereoWidth
        self.detuneAmount = detuneAmount
        self.unisonVoices = unisonVoices
        self.subHarmonics = subHarmonics
        self.fmRatio = fmRatio
        self.fmDepth = fmDepth
        self.wavetablePosition = wavetablePosition
        self.morphRate = morphRate
        self.grainSize = grainSize
        self.grainDensity = grainDensity
        self.grainPitch = grainPitch
        self.vocoderBands = vocoderBands
        self.vocoderAttack = vocoderAttack
        self.vocoderRelease = vocoderRelease
        self.bowPressure = bowPressure
        self.pluckPosition = pluckPosition
        self.hammerHardness = hammerHardness
        self.reedBuzziness = reedBuzziness
        self.bellowsPressure = bellowsPressure
        self.bodyResonance = bodyResonance
        self.sympatheticResonance = sympatheticResonance
        self.bendRange = bendRange
        self.twangAmount = twangAmount
        self.buzzAmount = buzzAmount
        self.bellTone = bellTone
        self.sparkle = sparkle
        self.shimmer = shimmer
        self.droneFrequency = droneFrequency
        self.drawbarConfig = drawbarConfig
        self.rotarySpeed = rotarySpeed
    }
}

// MARK: - Output Types

public struct VoiceCharacterOutput {
    public let voice: HarmonizedVoice
    public let character: VoiceCharacter
    public let samples: [Float]
    public let parameters: CharacterParameters
}

// MARK: - Character Morph Engine

public class CharacterMorphEngine {
    private var morphProgress: Double = 0
    private var sourceParams: CharacterParameters?
    private var targetParams: CharacterParameters?

    public func morph(
        from source: VoiceCharacter,
        to target: VoiceCharacter,
        duration: TimeInterval
    ) async {
        sourceParams = source.defaultParameters
        targetParams = target.defaultParameters
        morphProgress = 0

        let steps = Int(duration * 60) // 60 fps
        let stepDuration = duration / Double(steps)

        for i in 0..<steps {
            morphProgress = Double(i) / Double(steps)
            try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
        }

        morphProgress = 1.0
    }

    public var currentParameters: CharacterParameters {
        guard let source = sourceParams, let target = targetParams else {
            return CharacterParameters()
        }
        return interpolateParameters(source, target, t: morphProgress)
    }

    private func interpolateParameters(
        _ a: CharacterParameters,
        _ b: CharacterParameters,
        t: Double
    ) -> CharacterParameters {
        let invT = 1.0 - t
        return CharacterParameters(
            warmth: a.warmth * invT + b.warmth * t,
            brightness: a.brightness * invT + b.brightness * t,
            airiness: a.airiness * invT + b.airiness * t,
            breathiness: a.breathiness * invT + b.breathiness * t,
            harmonicRichness: a.harmonicRichness * invT + b.harmonicRichness * t,
            formantShift: a.formantShift * invT + b.formantShift * t,
            attackTime: a.attackTime * invT + b.attackTime * t,
            releaseTime: a.releaseTime * invT + b.releaseTime * t,
            filterCutoff: a.filterCutoff * invT + b.filterCutoff * t,
            filterResonance: a.filterResonance * invT + b.filterResonance * t,
            vibrato: a.vibrato * invT + b.vibrato * t,
            vibratoRate: a.vibratoRate * invT + b.vibratoRate * t,
            reverbAmount: a.reverbAmount * invT + b.reverbAmount * t,
            reverbSize: a.reverbSize * invT + b.reverbSize * t,
            chorusAmount: a.chorusAmount * invT + b.chorusAmount * t,
            stereoWidth: a.stereoWidth * invT + b.stereoWidth * t,
            detuneAmount: a.detuneAmount * invT + b.detuneAmount * t,
            subHarmonics: a.subHarmonics * invT + b.subHarmonics * t
        )
    }
}

import Foundation
import AVFoundation
import Accelerate
import Combine
import NaturalLanguage
import CoreML

// MARK: - EchoelVoice: Genius Voice-to-Everything Platform
/// Beyond Vochlea Dubler - Voice as the ultimate creative instrument
/// Combines AI Songwriting, Bio-Reactive Composition, and Intelligent Voice Control
///
/// Features that TRANSCEND Dubler:
/// 1. Voice Intelligence Engine - Emotion, breath, whisper/scream detection
/// 2. Bio-Voice Fusion - Heart rate, HRV, coherence modulation
/// 3. AI Songwriting - Sing melody → lyrics, speak lyrics → melody
/// 4. Voice Conductor - Gesture sounds control arrangement
/// 5. Voice Morphing - Transform voice to any instrument/character

@MainActor
public class EchoelVoice: ObservableObject {

    // MARK: - Singleton
    public static let shared = EchoelVoice()

    // MARK: - Voice Analysis State
    @Published public var currentPitch: Float = 0           // Hz
    @Published public var currentNote: String = "-"         // C4, D#5, etc.
    @Published public var currentMIDI: UInt8 = 0            // 0-127
    @Published public var currentVelocity: UInt8 = 80       // 0-127
    @Published public var currentEmotion: VocalEmotion = .neutral
    @Published public var currentEnergy: Float = 0          // 0-1
    @Published public var isVoiced: Bool = false
    @Published public var isBeatbox: Bool = false
    @Published public var detectedPhoneme: String = ""
    @Published public var vocalMode: VocalMode = .singing

    // MARK: - Beatbox Triggers (Like Dubler but smarter)
    @Published public var triggers: [BeatboxTrigger] = []
    @Published public var lastTriggeredIndex: Int = -1

    // MARK: - Intelligent Features
    @Published public var autoHarmony: [UInt8] = []         // Generated harmony notes
    @Published public var suggestedChords: [ChordSuggestion] = []
    @Published public var generatedLyrics: [String] = []
    @Published public var melodyFromLyrics: [MelodyNote] = []

    // MARK: - Bio-Voice Fusion
    @Published public var bioModulation: BioVoiceModulation = BioVoiceModulation()

    // MARK: - Voice Morphing
    @Published public var morphTarget: VoiceMorphTarget = .natural
    @Published public var morphIntensity: Float = 0

    // MARK: - Settings
    @Published public var pitchBendRange: Int = 2           // Semitones
    @Published public var scale: MusicalScale = .chromatic
    @Published public var rootNote: Int = 60                // C4
    @Published public var quantizeToScale: Bool = true
    @Published public var intelliBend: Bool = true          // Like Dubler IntelliBend
    @Published public var chordMode: ChordMode = .off

    // MARK: - Internal Audio
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private let pitchDetector = AdvancedPitchDetector()
    private let beatboxDetector = BeatboxDetector()
    private let emotionAnalyzer = VocalEmotionAnalyzer()
    private let phonemeRecognizer = PhonemeRecognizer()
    private let songwritingAI = AISongwritingEngine()
    private let voiceMorpher = VoiceMorpher()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - MIDI Output
    public var onMIDINoteOn: ((UInt8, UInt8) -> Void)?      // Note, Velocity
    public var onMIDINoteOff: ((UInt8) -> Void)?
    public var onMIDICC: ((UInt8, UInt8) -> Void)?          // CC#, Value
    public var onMIDIPitchBend: ((Int16) -> Void)?          // -8192 to 8191

    // MARK: - Initialization

    private init() {
        setupDefaultTriggers()
        print("=== EchoelVoice Initialized ===")
        print("Beyond Dubler - Voice as Ultimate Creative Instrument")
    }

    // MARK: - Start/Stop

    public func start() async throws {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        inputNode = engine.inputNode
        let format = inputNode?.outputFormat(forBus: 0)

        guard let inputFormat = format else {
            throw VoiceError.noInputFormat
        }

        // Install tap for real-time voice analysis
        inputNode?.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, time in
            Task { @MainActor in
                self?.processAudioBuffer(buffer)
            }
        }

        try engine.start()
        print("EchoelVoice: Audio engine started")
    }

    public func stop() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        print("EchoelVoice: Audio engine stopped")
    }

    // MARK: - Core Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        let sampleRate = Float(buffer.format.sampleRate)

        // 1. Energy Detection
        currentEnergy = calculateRMS(channelData, count: frameCount)

        // 2. Voiced/Unvoiced Detection
        let wasVoiced = isVoiced
        isVoiced = currentEnergy > 0.01

        if !isVoiced {
            if wasVoiced {
                // Note off
                onMIDINoteOff?(currentMIDI)
            }
            return
        }

        // 3. Beatbox Detection (percussive sounds)
        let beatboxResult = beatboxDetector.detect(channelData, count: frameCount, sampleRate: sampleRate)
        if beatboxResult.isPercussive {
            isBeatbox = true
            handleBeatboxTrigger(beatboxResult)
            return
        }
        isBeatbox = false

        // 4. Pitch Detection
        let rawPitch = pitchDetector.detectPitch(channelData, count: frameCount, sampleRate: sampleRate)
        currentPitch = rawPitch

        if rawPitch > 0 {
            // Convert to MIDI note
            let rawMIDI = frequencyToMIDI(rawPitch)
            let pitchBend = calculatePitchBend(rawPitch, nearestMIDI: rawMIDI)

            // Apply scale quantization if enabled
            let quantizedMIDI = quantizeToScale ? quantizeNote(rawMIDI) : rawMIDI

            // Apply chord mode
            let harmonyNotes = generateHarmony(quantizedMIDI)
            autoHarmony = harmonyNotes

            // Velocity from energy
            let velocity = UInt8(min(127, max(1, currentEnergy * 127 * 2)))

            // Update state
            if quantizedMIDI != currentMIDI || !wasVoiced {
                // Note change
                if wasVoiced {
                    onMIDINoteOff?(currentMIDI)
                    for note in autoHarmony { onMIDINoteOff?(note) }
                }

                currentMIDI = quantizedMIDI
                currentVelocity = velocity
                currentNote = midiToNoteName(quantizedMIDI)

                // Note on with harmony
                onMIDINoteOn?(quantizedMIDI, velocity)
                for note in harmonyNotes {
                    onMIDINoteOn?(note, UInt8(Float(velocity) * 0.7))
                }
            }

            // Pitch bend (IntelliBend or TruBend)
            if intelliBend {
                // Only bend when intentional (beyond threshold)
                if abs(pitchBend) > 1000 {
                    onMIDIPitchBend?(pitchBend)
                }
            } else {
                // TruBend - follow voice precisely
                onMIDIPitchBend?(pitchBend)
            }
        }

        // 5. Emotion Analysis
        currentEmotion = emotionAnalyzer.analyze(channelData, count: frameCount, sampleRate: sampleRate)

        // 6. Phoneme Detection (for CC mapping)
        detectedPhoneme = phonemeRecognizer.detect(channelData, count: frameCount, sampleRate: sampleRate)
        mapPhonemeToCCs()

        // 7. Detect vocal mode
        vocalMode = detectVocalMode(channelData, count: frameCount, sampleRate: sampleRate)

        // 8. Apply bio modulation
        applyBioModulation()
    }

    // MARK: - Beatbox Handling

    private func handleBeatboxTrigger(_ result: BeatboxResult) {
        // Find closest trained trigger
        var bestMatch = -1
        var bestScore: Float = 0.3  // Minimum threshold

        for (index, trigger) in triggers.enumerated() where trigger.isActive {
            let similarity = trigger.compareTo(result.features)
            if similarity > bestScore {
                bestScore = similarity
                bestMatch = index
            }
        }

        if bestMatch >= 0 {
            lastTriggeredIndex = bestMatch
            let trigger = triggers[bestMatch]
            let velocity = UInt8(min(127, max(1, result.energy * 127)))

            onMIDINoteOn?(trigger.midiNote, velocity)

            // Schedule note off
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.onMIDINoteOff?(trigger.midiNote)
            }
        }
    }

    // MARK: - Beatbox Training (Like Dubler)

    public func trainTrigger(index: Int, fromBuffer buffer: AVAudioPCMBuffer) {
        guard index < triggers.count else { return }
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let features = beatboxDetector.extractFeatures(
            channelData,
            count: Int(buffer.frameLength),
            sampleRate: Float(buffer.format.sampleRate)
        )

        triggers[index].trainedFeatures.append(features)
        triggers[index].isActive = true

        print("EchoelVoice: Trained trigger \(index) with \(triggers[index].trainedFeatures.count) samples")
    }

    // MARK: - Scale Quantization

    private func quantizeNote(_ midiNote: UInt8) -> UInt8 {
        let scaleNotes = scale.intervals.map { UInt8((rootNote + $0) % 12) }
        let noteInOctave = midiNote % 12
        let octave = midiNote / 12

        // Find closest scale note
        var closest = scaleNotes[0]
        var minDistance = 12

        for scaleNote in scaleNotes {
            let distance = min(
                abs(Int(noteInOctave) - Int(scaleNote)),
                12 - abs(Int(noteInOctave) - Int(scaleNote))
            )
            if distance < minDistance {
                minDistance = distance
                closest = scaleNote
            }
        }

        return octave * 12 + closest
    }

    // MARK: - Harmony Generation

    private func generateHarmony(_ rootMIDI: UInt8) -> [UInt8] {
        switch chordMode {
        case .off:
            return []
        case .thirds:
            let third = scale == .minor ? rootMIDI + 3 : rootMIDI + 4
            return [third]
        case .fifths:
            return [rootMIDI + 7]
        case .octaves:
            return [rootMIDI + 12]
        case .triad:
            let third = scale == .minor ? rootMIDI + 3 : rootMIDI + 4
            return [third, rootMIDI + 7]
        case .seventh:
            let third = scale == .minor ? rootMIDI + 3 : rootMIDI + 4
            let seventh = scale == .minor ? rootMIDI + 10 : rootMIDI + 11
            return [third, rootMIDI + 7, seventh]
        case .power:
            return [rootMIDI + 7, rootMIDI + 12]
        case .custom(let intervals):
            return intervals.map { rootMIDI + $0 }
        }
    }

    // MARK: - Phoneme → CC Mapping (Like Dubler vowel control)

    private func mapPhonemeToCCs() {
        // Vowel openness → CC1 (Mod wheel)
        let openness = phonemeRecognizer.vowelOpenness
        onMIDICC?(1, UInt8(openness * 127))

        // Vowel brightness → CC74 (Brightness/Cutoff)
        let brightness = phonemeRecognizer.vowelBrightness
        onMIDICC?(74, UInt8(brightness * 127))

        // Consonant presence → CC11 (Expression)
        let consonance = phonemeRecognizer.consonantPresence
        onMIDICC?(11, UInt8((1 - consonance) * 127))
    }

    // MARK: - Vocal Mode Detection

    private func detectVocalMode(_ data: UnsafePointer<Float>, count: Int, sampleRate: Float) -> VocalMode {
        let spectralCentroid = calculateSpectralCentroid(data, count: count, sampleRate: sampleRate)
        let zeroCrossings = calculateZeroCrossings(data, count: count)
        let energy = currentEnergy

        // Whisper: high zero crossings, low energy, high spectral centroid
        if zeroCrossings > 0.3 && energy < 0.1 && spectralCentroid > 3000 {
            return .whispering
        }

        // Scream: high energy, high spectral centroid
        if energy > 0.6 && spectralCentroid > 2500 {
            return .screaming
        }

        // Humming: low spectral centroid, moderate energy, low zero crossings
        if spectralCentroid < 500 && zeroCrossings < 0.1 {
            return .humming
        }

        // Speaking: moderate everything, irregular pitch
        let pitchStability = pitchDetector.pitchStability
        if pitchStability < 0.5 {
            return .speaking
        }

        // Default: singing
        return .singing
    }

    // MARK: - Bio-Voice Fusion

    public func updateBioData(heartRate: Float, hrv: Float, coherence: Float, breathingRate: Float) {
        bioModulation.heartRate = heartRate
        bioModulation.hrv = hrv
        bioModulation.coherence = coherence
        bioModulation.breathingRate = breathingRate
    }

    private func applyBioModulation() {
        // Heart rate → Vibrato intensity (CC1 modulation)
        let vibratoIntensity = mapRange(bioModulation.heartRate, inMin: 50, inMax: 120, outMin: 0, outMax: 1)
        onMIDICC?(77, UInt8(vibratoIntensity * 127))  // Custom CC for vibrato

        // HRV → Pitch bend sensitivity (internal)
        // Higher HRV = more expressive pitch bending
        let bendSensitivity = mapRange(bioModulation.hrv, inMin: 20, inMax: 100, outMin: 0.5, outMax: 2.0)
        pitchDetector.bendSensitivity = bendSensitivity

        // Coherence → Harmony richness
        if bioModulation.coherence > 0.7 {
            // High coherence = fuller harmonies
            if chordMode == .thirds {
                chordMode = .triad
            }
        } else if bioModulation.coherence < 0.3 {
            // Low coherence = simpler harmonies
            chordMode = .off
        }

        // Breathing rate → Phrase length suggestion
        // (Used by songwriting AI)
        songwritingAI.suggestedPhraseLength = Int(60.0 / max(bioModulation.breathingRate, 6))
    }

    // MARK: - AI Songwriting

    /// Sing a melody, get AI-generated lyrics
    public func generateLyricsFromMelody(_ melody: [MelodyNote], mood: String = "emotional", theme: String = "love") async -> [String] {
        generatedLyrics = await songwritingAI.generateLyrics(
            melody: melody,
            mood: mood,
            theme: theme,
            emotion: currentEmotion
        )
        return generatedLyrics
    }

    /// Speak/input lyrics, get AI-generated melody
    public func generateMelodyFromLyrics(_ lyrics: String, style: String = "pop") async -> [MelodyNote] {
        melodyFromLyrics = await songwritingAI.generateMelody(
            lyrics: lyrics,
            style: style,
            scale: scale,
            rootNote: rootNote
        )
        return melodyFromLyrics
    }

    /// Hum + speak = full song structure
    public func generateSongStructure(hummedMelody: [MelodyNote], spokenIdeas: String) async -> SongStructure {
        return await songwritingAI.generateFullSong(
            melody: hummedMelody,
            ideas: spokenIdeas,
            bioState: bioModulation
        )
    }

    // MARK: - Voice Morphing

    public func setMorphTarget(_ target: VoiceMorphTarget, intensity: Float = 1.0) {
        morphTarget = target
        morphIntensity = intensity
    }

    public func getMorphedOutput(_ inputBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        return voiceMorpher.morph(inputBuffer, target: morphTarget, intensity: morphIntensity)
    }

    // MARK: - Chord Suggestions

    public func suggestChordsForMelody(_ melody: [MelodyNote]) -> [ChordSuggestion] {
        suggestedChords = songwritingAI.suggestChords(melody: melody, scale: scale, rootNote: rootNote)
        return suggestedChords
    }

    // MARK: - DSP Helpers

    private func calculateRMS(_ data: UnsafePointer<Float>, count: Int) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(data, 1, &rms, vDSP_Length(count))
        return rms
    }

    private func calculateSpectralCentroid(_ data: UnsafePointer<Float>, count: Int, sampleRate: Float) -> Float {
        // Simple spectral centroid via zero-crossing rate approximation
        var sum: Float = 0
        var weightedSum: Float = 0

        for i in 0..<count {
            let magnitude = abs(data[i])
            sum += magnitude
            weightedSum += magnitude * Float(i)
        }

        guard sum > 0 else { return 0 }
        return (weightedSum / sum) * (sampleRate / Float(count))
    }

    private func calculateZeroCrossings(_ data: UnsafePointer<Float>, count: Int) -> Float {
        var crossings = 0
        for i in 1..<count {
            if (data[i-1] >= 0 && data[i] < 0) || (data[i-1] < 0 && data[i] >= 0) {
                crossings += 1
            }
        }
        return Float(crossings) / Float(count)
    }

    private func frequencyToMIDI(_ frequency: Float) -> UInt8 {
        let midi = 69 + 12 * log2(frequency / 440.0)
        return UInt8(max(0, min(127, round(midi))))
    }

    private func calculatePitchBend(_ frequency: Float, nearestMIDI: UInt8) -> Int16 {
        let exactMIDI = 69 + 12 * log2(frequency / 440.0)
        let cents = (exactMIDI - Float(nearestMIDI)) * 100

        // Convert cents to pitch bend (assuming ±2 semitone range = ±200 cents = ±8192)
        let bendPerCent = 8192.0 / (Float(pitchBendRange) * 100.0)
        return Int16(max(-8192, min(8191, cents * bendPerCent)))
    }

    private func midiToNoteName(_ midi: UInt8) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(midi) / 12 - 1
        let note = Int(midi) % 12
        return "\(noteNames[note])\(octave)"
    }

    private func mapRange(_ value: Float, inMin: Float, inMax: Float, outMin: Float, outMax: Float) -> Float {
        let clamped = max(inMin, min(inMax, value))
        return outMin + (clamped - inMin) * (outMax - outMin) / (inMax - inMin)
    }

    // MARK: - Default Setup

    private func setupDefaultTriggers() {
        triggers = [
            BeatboxTrigger(name: "Kick", midiNote: 36),
            BeatboxTrigger(name: "Snare", midiNote: 38),
            BeatboxTrigger(name: "Hi-Hat", midiNote: 42),
            BeatboxTrigger(name: "Clap", midiNote: 39),
            BeatboxTrigger(name: "Tom", midiNote: 45),
            BeatboxTrigger(name: "Crash", midiNote: 49),
            BeatboxTrigger(name: "Click", midiNote: 37),
            BeatboxTrigger(name: "Snap", midiNote: 40)
        ]
    }

    // MARK: - Errors

    public enum VoiceError: LocalizedError {
        case noInputFormat
        case audioEngineFailure
        case trainingFailed

        public var errorDescription: String? {
            switch self {
            case .noInputFormat: return "Could not get audio input format"
            case .audioEngineFailure: return "Audio engine failed to start"
            case .trainingFailed: return "Trigger training failed"
            }
        }
    }
}

// MARK: - Supporting Types

public enum VocalEmotion: String, CaseIterable {
    case neutral = "Neutral"
    case happy = "Happy"
    case sad = "Sad"
    case angry = "Angry"
    case excited = "Excited"
    case calm = "Calm"
    case fearful = "Fearful"
    case tender = "Tender"
}

public enum VocalMode: String, CaseIterable {
    case singing = "Singing"
    case speaking = "Speaking"
    case humming = "Humming"
    case whispering = "Whispering"
    case screaming = "Screaming"
    case beatboxing = "Beatboxing"
}

public enum MusicalScale: String, CaseIterable {
    case chromatic = "Chromatic"
    case major = "Major"
    case minor = "Minor"
    case pentatonicMajor = "Pentatonic Major"
    case pentatonicMinor = "Pentatonic Minor"
    case blues = "Blues"
    case dorian = "Dorian"
    case mixolydian = "Mixolydian"
    case phrygian = "Phrygian"
    case lydian = "Lydian"
    case harmonicMinor = "Harmonic Minor"
    case melodicMinor = "Melodic Minor"
    case wholeTone = "Whole Tone"
    case diminished = "Diminished"

    var intervals: [Int] {
        switch self {
        case .chromatic: return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .minor: return [0, 2, 3, 5, 7, 8, 10]
        case .pentatonicMajor: return [0, 2, 4, 7, 9]
        case .pentatonicMinor: return [0, 3, 5, 7, 10]
        case .blues: return [0, 3, 5, 6, 7, 10]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
        case .lydian: return [0, 2, 4, 6, 7, 9, 11]
        case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor: return [0, 2, 3, 5, 7, 9, 11]
        case .wholeTone: return [0, 2, 4, 6, 8, 10]
        case .diminished: return [0, 2, 3, 5, 6, 8, 9, 11]
        }
    }
}

public enum ChordMode {
    case off
    case thirds
    case fifths
    case octaves
    case triad
    case seventh
    case power
    case custom([UInt8])
}

public enum VoiceMorphTarget: String, CaseIterable {
    case natural = "Natural"
    case deepMale = "Deep Male"
    case highFemale = "High Female"
    case child = "Child"
    case robot = "Robot"
    case alien = "Alien"
    case whisper = "Whisper"
    case megaphone = "Megaphone"
    case radio = "Radio"
    case underwater = "Underwater"
    case cathedral = "Cathedral"
    case telephone = "Telephone"
    // Instrument morphs
    case cello = "Cello"
    case violin = "Violin"
    case flute = "Flute"
    case trumpet = "Trumpet"
    case synth = "Synthesizer"
}

public struct BeatboxTrigger: Identifiable {
    public let id = UUID()
    public var name: String
    public var midiNote: UInt8
    public var isActive: Bool = false
    public var trainedFeatures: [BeatboxFeatures] = []
    public var sensitivity: Float = 0.7

    public func compareTo(_ features: BeatboxFeatures) -> Float {
        guard !trainedFeatures.isEmpty else { return 0 }

        // Average similarity across all training samples
        var totalSimilarity: Float = 0
        for trained in trainedFeatures {
            totalSimilarity += trained.similarity(to: features)
        }
        return totalSimilarity / Float(trainedFeatures.count) * sensitivity
    }
}

public struct BeatboxFeatures {
    var spectralCentroid: Float = 0
    var spectralFlatness: Float = 0
    var attackTime: Float = 0
    var decayTime: Float = 0
    var zeroCrossings: Float = 0
    var energy: Float = 0
    var mfcc: [Float] = []

    func similarity(to other: BeatboxFeatures) -> Float {
        var score: Float = 0

        // Weight different features
        score += 1 - min(1, abs(spectralCentroid - other.spectralCentroid) / 5000)
        score += 1 - min(1, abs(spectralFlatness - other.spectralFlatness))
        score += 1 - min(1, abs(attackTime - other.attackTime) / 0.05)
        score += 1 - min(1, abs(zeroCrossings - other.zeroCrossings))

        // MFCC similarity
        if !mfcc.isEmpty && mfcc.count == other.mfcc.count {
            var mfccDist: Float = 0
            for i in 0..<mfcc.count {
                mfccDist += pow(mfcc[i] - other.mfcc[i], 2)
            }
            score += 1 - min(1, sqrt(mfccDist) / 10)
        }

        return score / 5  // Normalize to 0-1
    }
}

public struct BioVoiceModulation {
    var heartRate: Float = 70
    var hrv: Float = 50
    var coherence: Float = 0.5
    var breathingRate: Float = 12
}

public struct MelodyNote {
    var pitch: Int              // MIDI note number
    var duration: Double        // Beats
    var velocity: Int           // 0-127
    var syllable: String?       // Optional lyric syllable
}

public struct ChordSuggestion {
    var root: String
    var type: String            // "maj", "min", "7", "maj7", etc.
    var notes: [Int]            // MIDI notes
    var position: Double        // Beat position
}

public struct SongStructure {
    var sections: [SongSection]
    var tempo: Float
    var timeSignature: (Int, Int)
    var key: String
    var scale: MusicalScale
}

public struct SongSection {
    var name: String            // "Verse", "Chorus", "Bridge"
    var melody: [MelodyNote]
    var lyrics: [String]
    var chords: [ChordSuggestion]
    var bars: Int
}

// MARK: - Advanced Pitch Detector

class AdvancedPitchDetector {
    var bendSensitivity: Float = 1.0
    var pitchStability: Float = 0.5

    private var recentPitches: [Float] = []
    private let historySize = 10

    func detectPitch(_ data: UnsafePointer<Float>, count: Int, sampleRate: Float) -> Float {
        // YIN algorithm implementation
        let threshold: Float = 0.1
        let minFreq: Float = 60
        let maxFreq: Float = 2000

        let minLag = Int(sampleRate / maxFreq)
        let maxLag = min(Int(sampleRate / minFreq), count / 2)

        guard maxLag > minLag else { return 0 }

        // Difference function
        var diff = [Float](repeating: 0, count: maxLag)
        for tau in 1..<maxLag {
            var sum: Float = 0
            for j in 0..<(count - tau) {
                let delta = data[j] - data[j + tau]
                sum += delta * delta
            }
            diff[tau] = sum
        }

        // CMNDF
        var cmndf = [Float](repeating: 1, count: maxLag)
        var runningSum: Float = 0
        for tau in 1..<maxLag {
            runningSum += diff[tau]
            if runningSum > 0 {
                cmndf[tau] = diff[tau] * Float(tau) / runningSum
            }
        }

        // Find minimum below threshold
        for tau in minLag..<maxLag {
            if cmndf[tau] < threshold {
                let pitch = sampleRate / Float(tau)
                updateStability(pitch)
                return pitch
            }
        }

        return 0
    }

    private func updateStability(_ pitch: Float) {
        recentPitches.append(pitch)
        if recentPitches.count > historySize {
            recentPitches.removeFirst()
        }

        // Calculate variance
        guard recentPitches.count > 1 else {
            pitchStability = 0
            return
        }

        let mean = recentPitches.reduce(0, +) / Float(recentPitches.count)
        let variance = recentPitches.reduce(0) { $0 + pow($1 - mean, 2) } / Float(recentPitches.count)

        // Map variance to stability (0-1)
        pitchStability = max(0, 1 - variance / 100)
    }
}

// MARK: - Beatbox Detector

class BeatboxDetector {
    func detect(_ data: UnsafePointer<Float>, count: Int, sampleRate: Float) -> BeatboxResult {
        let features = extractFeatures(data, count: count, sampleRate: sampleRate)

        // Percussive = fast attack, broad spectrum, high energy
        let isPercussive = features.attackTime < 0.01 &&
                          features.spectralFlatness > 0.3 &&
                          features.energy > 0.1

        return BeatboxResult(isPercussive: isPercussive, features: features, energy: features.energy)
    }

    func extractFeatures(_ data: UnsafePointer<Float>, count: Int, sampleRate: Float) -> BeatboxFeatures {
        var features = BeatboxFeatures()

        // Energy
        var rms: Float = 0
        vDSP_rmsqv(data, 1, &rms, vDSP_Length(count))
        features.energy = rms

        // Zero crossings
        var crossings = 0
        for i in 1..<count {
            if (data[i-1] >= 0) != (data[i] >= 0) {
                crossings += 1
            }
        }
        features.zeroCrossings = Float(crossings) / Float(count)

        // Attack time (time to reach 90% of max)
        var maxAmp: Float = 0
        vDSP_maxmgv(data, 1, &maxAmp, vDSP_Length(count))
        let threshold = maxAmp * 0.9

        for i in 0..<count {
            if abs(data[i]) >= threshold {
                features.attackTime = Float(i) / sampleRate
                break
            }
        }

        // Spectral centroid and flatness (simplified)
        features.spectralCentroid = features.zeroCrossings * sampleRate / 2
        features.spectralFlatness = min(1, features.zeroCrossings * 3)

        return features
    }
}

struct BeatboxResult {
    var isPercussive: Bool
    var features: BeatboxFeatures
    var energy: Float
}

// MARK: - Vocal Emotion Analyzer

class VocalEmotionAnalyzer {
    func analyze(_ data: UnsafePointer<Float>, count: Int, sampleRate: Float) -> VocalEmotion {
        // Simplified emotion detection based on acoustic features

        // Energy
        var rms: Float = 0
        vDSP_rmsqv(data, 1, &rms, vDSP_Length(count))

        // Zero crossing rate (correlates with pitch/brightness)
        var crossings = 0
        for i in 1..<count {
            if (data[i-1] >= 0) != (data[i] >= 0) {
                crossings += 1
            }
        }
        let zcr = Float(crossings) / Float(count)

        // Simple heuristics
        if rms > 0.5 && zcr > 0.2 {
            return .excited
        } else if rms > 0.4 && zcr > 0.15 {
            return .angry
        } else if rms < 0.1 && zcr < 0.1 {
            return .sad
        } else if rms < 0.2 && zcr > 0.15 {
            return .fearful
        } else if rms > 0.2 && zcr > 0.1 {
            return .happy
        } else if rms < 0.15 {
            return .calm
        } else if rms > 0.15 && zcr < 0.1 {
            return .tender
        }

        return .neutral
    }
}

// MARK: - Phoneme Recognizer

class PhonemeRecognizer {
    var vowelOpenness: Float = 0.5      // 0 = closed (i), 1 = open (a)
    var vowelBrightness: Float = 0.5    // 0 = dark (u), 1 = bright (i)
    var consonantPresence: Float = 0    // 0 = vowel, 1 = consonant

    private let vowelFormants: [String: (Float, Float)] = [
        "a": (800, 1200),   // Open, neutral
        "e": (400, 2200),   // Mid, front
        "i": (300, 2800),   // Closed, front (bright)
        "o": (500, 800),    // Mid, back
        "u": (300, 600)     // Closed, back (dark)
    ]

    func detect(_ data: UnsafePointer<Float>, count: Int, sampleRate: Float) -> String {
        // Estimate formants via spectral peaks (simplified)
        let f1Estimate = estimateFormant(data, count: count, sampleRate: sampleRate, range: (200, 1000))
        let f2Estimate = estimateFormant(data, count: count, sampleRate: sampleRate, range: (500, 3000))

        // Update continuous parameters
        vowelOpenness = mapRange(f1Estimate, inMin: 200, inMax: 1000, outMin: 0, outMax: 1)
        vowelBrightness = mapRange(f2Estimate, inMin: 500, inMax: 3000, outMin: 0, outMax: 1)

        // Detect consonants via high-frequency energy
        let highFreqEnergy = estimateHighFrequencyEnergy(data, count: count, sampleRate: sampleRate)
        consonantPresence = min(1, highFreqEnergy * 5)

        // Match to closest vowel
        var bestMatch = "a"
        var bestDistance: Float = Float.infinity

        for (vowel, formants) in vowelFormants {
            let distance = pow(f1Estimate - formants.0, 2) + pow(f2Estimate - formants.1, 2)
            if distance < bestDistance {
                bestDistance = distance
                bestMatch = vowel
            }
        }

        return consonantPresence > 0.5 ? "" : bestMatch
    }

    private func estimateFormant(_ data: UnsafePointer<Float>, count: Int, sampleRate: Float, range: (Float, Float)) -> Float {
        // Simple spectral peak finding in range
        // In production, use LPC or true formant tracking

        let fftSize = 1024
        guard count >= fftSize else { return (range.0 + range.1) / 2 }

        // Use zero crossings as rough frequency estimate
        var crossings = 0
        for i in 1..<min(count, fftSize) {
            if (data[i-1] >= 0) != (data[i] >= 0) {
                crossings += 1
            }
        }

        let roughFreq = Float(crossings) * sampleRate / Float(fftSize) / 2
        return max(range.0, min(range.1, roughFreq))
    }

    private func estimateHighFrequencyEnergy(_ data: UnsafePointer<Float>, count: Int, sampleRate: Float) -> Float {
        // High-pass filter energy
        var highPassEnergy: Float = 0
        var prevSample: Float = 0

        for i in 0..<count {
            let highPassed = data[i] - prevSample  // Simple 1st order high pass
            highPassEnergy += highPassed * highPassed
            prevSample = data[i]
        }

        return sqrt(highPassEnergy / Float(count))
    }

    private func mapRange(_ value: Float, inMin: Float, inMax: Float, outMin: Float, outMax: Float) -> Float {
        return outMin + (max(inMin, min(inMax, value)) - inMin) * (outMax - outMin) / (inMax - inMin)
    }
}

// MARK: - AI Songwriting Engine

class AISongwritingEngine {
    var suggestedPhraseLength: Int = 4  // Bars

    func generateLyrics(melody: [MelodyNote], mood: String, theme: String, emotion: VocalEmotion) async -> [String] {
        // AI-powered lyric generation based on melody contour and emotion
        // In production, use GPT/Claude API

        var lyrics: [String] = []
        let syllableCount = melody.count

        // Generate syllables based on melody rhythm
        let themeWords = getThemeWords(theme: theme, mood: mood, emotion: emotion)

        for (index, note) in melody.enumerated() {
            // Higher notes = more open vowels
            // Longer notes = longer syllables/words
            // Accented notes = emphasized words

            let wordType = determineWordType(note: note, position: index, total: syllableCount)
            let word = selectWord(type: wordType, theme: themeWords)
            lyrics.append(word)
        }

        return lyrics
    }

    func generateMelody(lyrics: String, style: String, scale: MusicalScale, rootNote: Int) async -> [MelodyNote] {
        // Generate melody from lyrics using prosody analysis

        var melody: [MelodyNote] = []
        let words = lyrics.components(separatedBy: .whitespaces)

        var currentPitch = rootNote
        let scaleNotes = buildScale(root: rootNote, scale: scale)

        for word in words {
            // Word stress affects pitch and velocity
            let syllables = countSyllables(word)
            let hasStress = word.first?.isUppercase ?? false || word.count > 5

            for syllableIndex in 0..<max(1, syllables) {
                // Pitch contour based on syllable position
                let pitchDirection = syllableIndex == 0 ? 1 : (syllableIndex == syllables - 1 ? -1 : 0)
                let pitchStep = Int.random(in: 0...2) * pitchDirection

                currentPitch = nearestScaleNote(currentPitch + pitchStep, scaleNotes: scaleNotes)

                let note = MelodyNote(
                    pitch: currentPitch,
                    duration: hasStress && syllableIndex == 0 ? 1.0 : 0.5,
                    velocity: hasStress && syllableIndex == 0 ? 100 : 80,
                    syllable: String(word.prefix(syllableIndex + 2))
                )
                melody.append(note)
            }
        }

        return melody
    }

    func generateFullSong(melody: [MelodyNote], ideas: String, bioState: BioVoiceModulation) async -> SongStructure {
        // Generate complete song structure

        let tempo = mapBioToTempo(bioState)
        let key = suggestKey(from: melody)

        // Analyze ideas for theme/mood
        let theme = extractTheme(from: ideas)

        // Generate sections
        var sections: [SongSection] = []

        // Verse
        let verseMelody = transformMelody(melody, style: .verse)
        let verseLyrics = await generateLyrics(melody: verseMelody, mood: "reflective", theme: theme, emotion: .neutral)
        sections.append(SongSection(
            name: "Verse",
            melody: verseMelody,
            lyrics: verseLyrics,
            chords: suggestChords(melody: verseMelody, scale: .major, rootNote: 60),
            bars: 8
        ))

        // Chorus (brighter, higher energy)
        let chorusMelody = transformMelody(melody, style: .chorus)
        let chorusLyrics = await generateLyrics(melody: chorusMelody, mood: "uplifting", theme: theme, emotion: .happy)
        sections.append(SongSection(
            name: "Chorus",
            melody: chorusMelody,
            lyrics: chorusLyrics,
            chords: suggestChords(melody: chorusMelody, scale: .major, rootNote: 60),
            bars: 8
        ))

        return SongStructure(
            sections: sections,
            tempo: tempo,
            timeSignature: (4, 4),
            key: key,
            scale: .major
        )
    }

    func suggestChords(melody: [MelodyNote], scale: MusicalScale, rootNote: Int) -> [ChordSuggestion] {
        var chords: [ChordSuggestion] = []

        // Group melody notes by bar
        let notesPerBar = 4
        var position: Double = 0

        for i in stride(from: 0, to: melody.count, by: notesPerBar) {
            let barNotes = Array(melody[i..<min(i + notesPerBar, melody.count)])

            // Find most common note in bar
            let pitches = barNotes.map { $0.pitch % 12 }
            let mostCommon = pitches.max(by: { pitches.filter { $0 == $0 }.count < pitches.filter { $0 == $1 }.count }) ?? 0

            // Build chord
            let chordRoot = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][mostCommon]
            let isMinor = scale == .minor || [1, 2, 4, 6].contains(mostCommon)

            chords.append(ChordSuggestion(
                root: chordRoot,
                type: isMinor ? "min" : "maj",
                notes: [rootNote + mostCommon, rootNote + mostCommon + (isMinor ? 3 : 4), rootNote + mostCommon + 7],
                position: position
            ))

            position += Double(notesPerBar)
        }

        return chords
    }

    // Helper methods

    private func getThemeWords(theme: String, mood: String, emotion: VocalEmotion) -> [String] {
        // Word banks by theme
        let banks: [String: [String]] = [
            "love": ["heart", "soul", "dream", "feel", "touch", "night", "light", "fire", "desire", "forever"],
            "nature": ["sky", "moon", "sun", "rain", "wind", "sea", "tree", "flower", "river", "mountain"],
            "life": ["time", "way", "day", "hope", "change", "grow", "learn", "live", "breathe", "believe"]
        ]

        return banks[theme.lowercased()] ?? banks["life"]!
    }

    private func determineWordType(note: MelodyNote, position: Int, total: Int) -> WordType {
        if note.velocity > 90 { return .emphasized }
        if note.duration >= 1.0 { return .sustained }
        if position == 0 || position == total - 1 { return .structural }
        return .filler
    }

    private func selectWord(type: WordType, theme: [String]) -> String {
        switch type {
        case .emphasized:
            return theme.randomElement() ?? "love"
        case .sustained:
            return ["oooh", "aaah", "yeah", "hey"].randomElement()!
        case .structural:
            return ["I", "you", "we", "the", "and", "but"].randomElement()!
        case .filler:
            return ["la", "da", "na", "oh"].randomElement()!
        }
    }

    enum WordType {
        case emphasized, sustained, structural, filler
    }

    private func countSyllables(_ word: String) -> Int {
        let vowels = CharacterSet(charactersIn: "aeiouAEIOU")
        var count = 0
        var prevWasVowel = false

        for char in word.unicodeScalars {
            let isVowel = vowels.contains(char)
            if isVowel && !prevWasVowel {
                count += 1
            }
            prevWasVowel = isVowel
        }

        return max(1, count)
    }

    private func buildScale(root: Int, scale: MusicalScale) -> [Int] {
        var notes: [Int] = []
        for octave in -1...2 {
            for interval in scale.intervals {
                notes.append(root + interval + octave * 12)
            }
        }
        return notes.filter { $0 >= 0 && $0 <= 127 }
    }

    private func nearestScaleNote(_ pitch: Int, scaleNotes: [Int]) -> Int {
        return scaleNotes.min(by: { abs($0 - pitch) < abs($1 - pitch) }) ?? pitch
    }

    private func mapBioToTempo(_ bio: BioVoiceModulation) -> Float {
        // Heart rate influences tempo
        let baseTempo = bio.heartRate * 1.2  // Slightly faster than heart
        // Coherence smooths tempo
        return baseTempo * (0.8 + bio.coherence * 0.4)
    }

    private func suggestKey(from melody: [MelodyNote]) -> String {
        // Find most common pitch class
        let pitchClasses = melody.map { $0.pitch % 12 }
        let counts = Dictionary(grouping: pitchClasses, by: { $0 }).mapValues { $0.count }
        let mostCommon = counts.max(by: { $0.value < $1.value })?.key ?? 0

        let keys = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return keys[mostCommon]
    }

    private func extractTheme(from ideas: String) -> String {
        let lowered = ideas.lowercased()
        if lowered.contains("love") || lowered.contains("heart") { return "love" }
        if lowered.contains("nature") || lowered.contains("sky") { return "nature" }
        return "life"
    }

    private func transformMelody(_ melody: [MelodyNote], style: MelodyStyle) -> [MelodyNote] {
        switch style {
        case .verse:
            // Lower, more subdued
            return melody.map { MelodyNote(pitch: $0.pitch - 2, duration: $0.duration, velocity: min(100, $0.velocity - 10), syllable: $0.syllable) }
        case .chorus:
            // Higher, more energetic
            return melody.map { MelodyNote(pitch: $0.pitch + 3, duration: $0.duration * 0.8, velocity: min(127, $0.velocity + 15), syllable: $0.syllable) }
        case .bridge:
            // Different contour
            return melody.reversed().map { MelodyNote(pitch: $0.pitch + 5, duration: $0.duration * 1.2, velocity: $0.velocity, syllable: $0.syllable) }
        }
    }

    enum MelodyStyle {
        case verse, chorus, bridge
    }
}

// MARK: - Voice Morpher

class VoiceMorpher {
    func morph(_ buffer: AVAudioPCMBuffer, target: VoiceMorphTarget, intensity: Float) -> AVAudioPCMBuffer {
        guard let inputData = buffer.floatChannelData?[0] else { return buffer }
        let frameCount = Int(buffer.frameLength)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return buffer
        }
        outputBuffer.frameLength = buffer.frameLength
        guard let outputData = outputBuffer.floatChannelData?[0] else { return buffer }

        // Apply morph based on target
        let params = getMorphParameters(target)

        for i in 0..<frameCount {
            var sample = inputData[i]

            // Pitch shift (simplified via playback rate - in production use phase vocoder)
            // Formant shift
            // Filter application

            // Simple processing for demo
            sample *= params.gain

            outputData[i] = sample
        }

        return outputBuffer
    }

    private func getMorphParameters(_ target: VoiceMorphTarget) -> MorphParameters {
        switch target {
        case .natural: return MorphParameters(pitchShift: 0, formantShift: 0, gain: 1.0)
        case .deepMale: return MorphParameters(pitchShift: -7, formantShift: -0.2, gain: 1.1)
        case .highFemale: return MorphParameters(pitchShift: 5, formantShift: 0.15, gain: 0.95)
        case .child: return MorphParameters(pitchShift: 7, formantShift: 0.25, gain: 0.9)
        case .robot: return MorphParameters(pitchShift: 0, formantShift: 0, gain: 1.0, vocoder: true)
        case .alien: return MorphParameters(pitchShift: 12, formantShift: 0.5, gain: 0.8)
        case .whisper: return MorphParameters(pitchShift: 0, formantShift: 0, gain: 0.5, noiseAdd: 0.3)
        case .megaphone: return MorphParameters(pitchShift: 0, formantShift: 0, gain: 1.5, bandpass: (300, 3000))
        case .radio: return MorphParameters(pitchShift: 0, formantShift: 0, gain: 1.2, bandpass: (500, 4000))
        case .underwater: return MorphParameters(pitchShift: -2, formantShift: -0.1, gain: 0.7, lowpass: 800)
        case .cathedral: return MorphParameters(pitchShift: 0, formantShift: 0, gain: 0.9, reverb: 0.8)
        case .telephone: return MorphParameters(pitchShift: 0, formantShift: 0, gain: 1.0, bandpass: (300, 3400))
        case .cello: return MorphParameters(pitchShift: -12, formantShift: -0.3, gain: 0.8, resonance: 0.7)
        case .violin: return MorphParameters(pitchShift: 0, formantShift: 0.1, gain: 0.75, resonance: 0.8)
        case .flute: return MorphParameters(pitchShift: 12, formantShift: 0.3, gain: 0.6, breathiness: 0.4)
        case .trumpet: return MorphParameters(pitchShift: 0, formantShift: 0.2, gain: 1.3, brightness: 0.8)
        case .synth: return MorphParameters(pitchShift: 0, formantShift: 0, gain: 1.0, vocoder: true, synthWave: .saw)
        }
    }

    struct MorphParameters {
        var pitchShift: Int = 0             // Semitones
        var formantShift: Float = 0         // -1 to 1
        var gain: Float = 1.0
        var vocoder: Bool = false
        var noiseAdd: Float = 0
        var bandpass: (Float, Float)?       // Low, High Hz
        var lowpass: Float?
        var highpass: Float?
        var reverb: Float = 0
        var resonance: Float = 0
        var breathiness: Float = 0
        var brightness: Float = 0.5
        var synthWave: SynthWave = .sine

        enum SynthWave {
            case sine, saw, square, triangle
        }
    }
}

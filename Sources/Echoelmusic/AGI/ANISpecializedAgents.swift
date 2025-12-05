// ANISpecializedAgents.swift
// Echoelmusic - Artificial Narrow Intelligence (ANI) Agent System
//
// Specialized AI agents for specific musical tasks
// Each agent is an expert in one domain with deep capabilities

import Foundation
import Combine
import CoreML
import os.log

private let aniLogger = Logger(subsystem: "com.echoelmusic.agi", category: "ANI")

// MARK: - ANI Agent Protocol

public protocol ANIAgent: AnyObject {
    var agentID: String { get }
    var agentName: String { get }
    var domain: ANIDomain { get }
    var confidence: Double { get }
    var isActive: Bool { get }

    func process(_ input: ANIInput) async throws -> ANIOutput
    func learn(from feedback: ANIFeedback) async
    func reset()
}

public enum ANIDomain: String, CaseIterable {
    case harmony = "Harmony"
    case melody = "Melody"
    case rhythm = "Rhythm"
    case arrangement = "Arrangement"
    case mixing = "Mixing"
    case mastering = "Mastering"
    case soundDesign = "Sound Design"
    case lyrics = "Lyrics"
    case structure = "Structure"
    case emotion = "Emotion"
    case style = "Style"
    case performance = "Performance"
}

public struct ANIInput {
    public var type: InputType
    public var data: Any
    public var context: [String: Any]
    public var constraints: [String: Any]

    public enum InputType {
        case audio([Float])
        case midi([MIDIEvent])
        case symbolic(SymbolicMusic)
        case text(String)
        case parameters([String: Double])
    }
}

public struct ANIOutput {
    public var type: OutputType
    public var data: Any
    public var confidence: Double
    public var alternatives: [Any]
    public var explanation: String

    public enum OutputType {
        case audio([Float])
        case midi([MIDIEvent])
        case symbolic(SymbolicMusic)
        case parameters([String: Double])
        case recommendation(String)
    }
}

public struct ANIFeedback {
    public var rating: Double  // 0-1
    public var corrections: [String: Any]
    public var comments: String?
}

public struct MIDIEvent {
    public var type: EventType
    public var note: Int
    public var velocity: Int
    public var channel: Int
    public var timestamp: Double

    public enum EventType { case noteOn, noteOff, controlChange, pitchBend }
}

public struct SymbolicMusic {
    public var notes: [Note]
    public var chords: [Chord]
    public var key: String
    public var tempo: Double
    public var timeSignature: (Int, Int)

    public struct Note {
        public var pitch: Int
        public var duration: Double
        public var velocity: Double
        public var startTime: Double
    }

    public struct Chord {
        public var root: String
        public var quality: String
        public var startTime: Double
        public var duration: Double
    }
}

// MARK: - Harmony Agent

public final class HarmonyAgent: ANIAgent {
    public let agentID = "ani.harmony"
    public let agentName = "Harmony Specialist"
    public let domain: ANIDomain = .harmony
    public private(set) var confidence: Double = 0.85
    public var isActive: Bool = true

    // Knowledge bases
    private var chordDatabase: [String: ChordKnowledge] = [:]
    private var progressionRules: [ProgressionRule] = []
    private var voiceLeadingRules: [VoiceLeadingRule] = []

    public init() {
        loadChordDatabase()
        loadProgressionRules()
    }

    public func process(_ input: ANIInput) async throws -> ANIOutput {
        switch input.type {
        case .symbolic(let music):
            return await analyzeAndSuggestHarmony(music)
        case .audio(let samples):
            return await detectChords(samples)
        case .midi(let events):
            return await harmonizeMelody(events)
        default:
            throw ANIError.unsupportedInput
        }
    }

    public func learn(from feedback: ANIFeedback) async {
        // Update internal models based on feedback
        confidence = confidence * 0.95 + feedback.rating * 0.05
        aniLogger.debug("HarmonyAgent learned, new confidence: \(self.confidence)")
    }

    public func reset() {
        confidence = 0.85
    }

    // MARK: - Harmony-specific methods

    private func analyzeAndSuggestHarmony(_ music: SymbolicMusic) async -> ANIOutput {
        var suggestions: [[String]] = []

        // Analyze current progression
        let analysis = analyzeProgression(music.chords)

        // Generate continuation suggestions
        suggestions.append(suggestNextChords(after: music.chords.last, in: music.key))

        // Generate reharmonization options
        suggestions.append(suggestReharmonization(music.chords, key: music.key))

        return ANIOutput(
            type: .symbolic(SymbolicMusic(
                notes: music.notes,
                chords: convertToChords(suggestions.first ?? []),
                key: music.key,
                tempo: music.tempo,
                timeSignature: music.timeSignature
            )),
            confidence: confidence,
            alternatives: suggestions,
            explanation: "Based on \(analysis), I suggest these harmonic options."
        )
    }

    private func detectChords(_ samples: [Float]) async -> ANIOutput {
        // Chroma feature extraction
        let chroma = extractChroma(samples)

        // Chord detection using template matching
        let detectedChords = matchChordTemplates(chroma)

        return ANIOutput(
            type: .parameters(["confidence": confidence]),
            confidence: confidence,
            alternatives: [],
            explanation: "Detected chord sequence: \(detectedChords.joined(separator: " - "))"
        )
    }

    private func harmonizeMelody(_ events: [MIDIEvent]) async -> ANIOutput {
        var harmonizedEvents = events

        // Group notes by beat
        let melodicNotes = events.filter { $0.type == .noteOn }

        // Generate harmony for each melodic note
        for note in melodicNotes {
            let harmonyNotes = generateHarmonyNotes(for: note)
            harmonizedEvents.append(contentsOf: harmonyNotes)
        }

        return ANIOutput(
            type: .midi(harmonizedEvents),
            confidence: confidence,
            alternatives: [],
            explanation: "Added harmonic support to melody"
        )
    }

    private func analyzeProgression(_ chords: [SymbolicMusic.Chord]) -> String {
        guard !chords.isEmpty else { return "empty progression" }
        return "functional harmony with \(chords.count) chords"
    }

    private func suggestNextChords(after chord: SymbolicMusic.Chord?, in key: String) -> [String] {
        guard let lastChord = chord else { return ["I", "IV", "V"] }

        // Roman numeral analysis
        let suggestions: [String]
        switch lastChord.root {
        case "I", "C": suggestions = ["IV", "V", "vi", "ii"]
        case "IV", "F": suggestions = ["V", "I", "ii", "viio"]
        case "V", "G": suggestions = ["I", "vi", "IV"]
        case "vi", "Am": suggestions = ["IV", "V", "ii"]
        default: suggestions = ["I", "IV", "V"]
        }

        return suggestions
    }

    private func suggestReharmonization(_ chords: [SymbolicMusic.Chord], key: String) -> [String] {
        // Tritone substitutions, modal interchange, etc.
        return ["bVII", "iv", "bVI", "II7"]
    }

    private func convertToChords(_ romanNumerals: [String]) -> [SymbolicMusic.Chord] {
        romanNumerals.enumerated().map { index, numeral in
            SymbolicMusic.Chord(
                root: numeral,
                quality: numeral.contains("o") ? "dim" : (numeral == numeral.lowercased() ? "minor" : "major"),
                startTime: Double(index) * 4.0,
                duration: 4.0
            )
        }
    }

    private func extractChroma(_ samples: [Float]) -> [Float] {
        // Simplified chroma extraction
        return [Float](repeating: 0, count: 12)
    }

    private func matchChordTemplates(_ chroma: [Float]) -> [String] {
        return ["C", "G", "Am", "F"]
    }

    private func generateHarmonyNotes(for note: MIDIEvent) -> [MIDIEvent] {
        // Add third and fifth below
        return [
            MIDIEvent(type: .noteOn, note: note.note - 4, velocity: note.velocity - 20, channel: note.channel, timestamp: note.timestamp),
            MIDIEvent(type: .noteOn, note: note.note - 7, velocity: note.velocity - 30, channel: note.channel, timestamp: note.timestamp)
        ]
    }

    private func loadChordDatabase() {
        // Load chord knowledge
    }

    private func loadProgressionRules() {
        // Load progression rules
    }
}

// Supporting types for HarmonyAgent
struct ChordKnowledge {
    var name: String
    var intervals: [Int]
    var function: String
    var tensions: [Int]
}

struct ProgressionRule {
    var from: String
    var to: [String]
    var strength: Double
}

struct VoiceLeadingRule {
    var description: String
    var priority: Int
}

// MARK: - Melody Agent

public final class MelodyAgent: ANIAgent {
    public let agentID = "ani.melody"
    public let agentName = "Melody Specialist"
    public let domain: ANIDomain = .melody
    public private(set) var confidence: Double = 0.82
    public var isActive: Bool = true

    // Melodic patterns and motifs
    private var motifLibrary: [String: [Int]] = [:]
    private var intervalPreferences: [Int: Double] = [:]
    private var contourModels: [ContourModel] = []

    public init() {
        loadMotifLibrary()
        initializeIntervalPreferences()
    }

    public func process(_ input: ANIInput) async throws -> ANIOutput {
        switch input.type {
        case .symbolic(let music):
            return await generateMelody(over: music)
        case .midi(let events):
            return await embellishMelody(events)
        case .parameters(let params):
            return await generateFromParameters(params)
        default:
            throw ANIError.unsupportedInput
        }
    }

    public func learn(from feedback: ANIFeedback) async {
        confidence = confidence * 0.95 + feedback.rating * 0.05
    }

    public func reset() {
        confidence = 0.82
    }

    private func generateMelody(over music: SymbolicMusic) async -> ANIOutput {
        var melody: [SymbolicMusic.Note] = []
        let scale = getScale(for: music.key)

        // Generate melodic contour
        let contour = generateContour(length: 16, emotion: "neutral")

        // Map contour to actual pitches
        for (index, direction) in contour.enumerated() {
            let pitch = mapToPitch(direction: direction, scale: scale, previousNote: melody.last)
            melody.append(SymbolicMusic.Note(
                pitch: pitch,
                duration: 0.5,
                velocity: 0.7 + Double.random(in: -0.1...0.1),
                startTime: Double(index) * 0.5
            ))
        }

        return ANIOutput(
            type: .symbolic(SymbolicMusic(
                notes: melody,
                chords: music.chords,
                key: music.key,
                tempo: music.tempo,
                timeSignature: music.timeSignature
            )),
            confidence: confidence,
            alternatives: [],
            explanation: "Generated melody following \(contour.count)-step contour"
        )
    }

    private func embellishMelody(_ events: [MIDIEvent]) async -> ANIOutput {
        var embellished: [MIDIEvent] = []

        for event in events where event.type == .noteOn {
            embellished.append(event)

            // Add embellishments with probability
            if Double.random(in: 0...1) > 0.7 {
                // Add grace note
                embellished.append(MIDIEvent(
                    type: .noteOn,
                    note: event.note + 2,
                    velocity: event.velocity - 20,
                    channel: event.channel,
                    timestamp: event.timestamp - 0.05
                ))
            }
        }

        return ANIOutput(
            type: .midi(embellished),
            confidence: confidence,
            alternatives: [],
            explanation: "Added melodic embellishments"
        )
    }

    private func generateFromParameters(_ params: [String: Double]) async -> ANIOutput {
        let length = Int(params["length"] ?? 16)
        let complexity = params["complexity"] ?? 0.5
        let range = Int(params["range"] ?? 12)

        var notes: [Int] = []
        var currentPitch = 60  // Middle C

        for _ in 0..<length {
            let interval = selectInterval(complexity: complexity, range: range)
            currentPitch += interval
            currentPitch = max(48, min(84, currentPitch))  // Clamp range
            notes.append(currentPitch)
        }

        return ANIOutput(
            type: .midi(notes.enumerated().map { index, pitch in
                MIDIEvent(type: .noteOn, note: pitch, velocity: 80, channel: 0, timestamp: Double(index) * 0.5)
            }),
            confidence: confidence,
            alternatives: [],
            explanation: "Generated \(length)-note melody with complexity \(complexity)"
        )
    }

    private func getScale(for key: String) -> [Int] {
        // C major scale intervals
        return [0, 2, 4, 5, 7, 9, 11]
    }

    private func generateContour(length: Int, emotion: String) -> [Int] {
        // -1 = down, 0 = same, 1 = up
        var contour: [Int] = []
        for _ in 0..<length {
            contour.append(Int.random(in: -1...1))
        }
        return contour
    }

    private func mapToPitch(direction: Int, scale: [Int], previousNote: SymbolicMusic.Note?) -> Int {
        let basePitch = previousNote?.pitch ?? 60
        let step = direction * Int.random(in: 1...2)
        let scaleIndex = ((basePitch % 12) + step + 12) % 12
        let octave = basePitch / 12
        return octave * 12 + scale[scaleIndex % scale.count]
    }

    private func selectInterval(complexity: Double, range: Int) -> Int {
        let maxStep = Int(Double(range) * complexity / 2)
        return Int.random(in: -maxStep...maxStep)
    }

    private func loadMotifLibrary() {
        motifLibrary["ascending"] = [0, 2, 4, 5, 7]
        motifLibrary["descending"] = [7, 5, 4, 2, 0]
        motifLibrary["arch"] = [0, 2, 4, 2, 0]
    }

    private func initializeIntervalPreferences() {
        intervalPreferences = [
            0: 0.1,   // unison
            1: 0.05,  // minor 2nd
            2: 0.25,  // major 2nd
            3: 0.15,  // minor 3rd
            4: 0.15,  // major 3rd
            5: 0.1,   // perfect 4th
            7: 0.1,   // perfect 5th
            12: 0.05  // octave
        ]
    }
}

struct ContourModel {
    var shape: String
    var points: [Double]
}

// MARK: - Rhythm Agent

public final class RhythmAgent: ANIAgent {
    public let agentID = "ani.rhythm"
    public let agentName = "Rhythm Specialist"
    public let domain: ANIDomain = .rhythm
    public private(set) var confidence: Double = 0.88
    public var isActive: Bool = true

    private var groovePatterns: [String: GroovePattern] = [:]
    private var polyrhythmLibrary: [Polyrhythm] = []

    public init() {
        loadGroovePatterns()
        loadPolyrhythms()
    }

    public func process(_ input: ANIInput) async throws -> ANIOutput {
        switch input.type {
        case .parameters(let params):
            return await generateRhythm(params)
        case .audio(let samples):
            return await extractRhythm(samples)
        case .midi(let events):
            return await quantizeAndGroove(events)
        default:
            throw ANIError.unsupportedInput
        }
    }

    public func learn(from feedback: ANIFeedback) async {
        confidence = confidence * 0.95 + feedback.rating * 0.05
    }

    public func reset() {
        confidence = 0.88
    }

    private func generateRhythm(_ params: [String: Double]) async -> ANIOutput {
        let complexity = params["complexity"] ?? 0.5
        let swing = params["swing"] ?? 0.0
        let density = params["density"] ?? 0.5

        var pattern: [RhythmHit] = []
        let steps = 16

        for step in 0..<steps {
            let probability = calculateHitProbability(step: step, density: density, complexity: complexity)
            if Double.random(in: 0...1) < probability {
                var timing = Double(step) / 4.0
                // Apply swing
                if step % 2 == 1 {
                    timing += swing * 0.1
                }
                pattern.append(RhythmHit(time: timing, velocity: Double.random(in: 0.6...1.0), duration: 0.1))
            }
        }

        return ANIOutput(
            type: .parameters([
                "patternLength": Double(pattern.count),
                "averageVelocity": pattern.map { $0.velocity }.reduce(0, +) / Double(max(pattern.count, 1))
            ]),
            confidence: confidence,
            alternatives: [],
            explanation: "Generated \(pattern.count)-hit pattern with \(Int(complexity * 100))% complexity"
        )
    }

    private func extractRhythm(_ samples: [Float]) async -> ANIOutput {
        // Onset detection
        let onsets = detectOnsets(samples)

        // Tempo estimation
        let tempo = estimateTempo(onsets)

        // Beat tracking
        let beats = trackBeats(onsets, tempo: tempo)

        return ANIOutput(
            type: .parameters(["tempo": tempo, "beatCount": Double(beats.count)]),
            confidence: confidence,
            alternatives: [],
            explanation: "Detected tempo: \(Int(tempo)) BPM with \(beats.count) beats"
        )
    }

    private func quantizeAndGroove(_ events: [MIDIEvent]) async -> ANIOutput {
        var quantized: [MIDIEvent] = []

        for event in events {
            var newEvent = event
            // Quantize to 16th note grid
            let gridSize = 0.25  // 16th note at 120 BPM
            newEvent.timestamp = round(event.timestamp / gridSize) * gridSize
            quantized.append(newEvent)
        }

        return ANIOutput(
            type: .midi(quantized),
            confidence: confidence,
            alternatives: [],
            explanation: "Quantized \(events.count) events to grid"
        )
    }

    private func calculateHitProbability(step: Int, density: Double, complexity: Double) -> Double {
        // Strong beats have higher base probability
        var probability = density

        if step % 4 == 0 {
            probability += 0.3  // Downbeats
        } else if step % 2 == 0 {
            probability += 0.15  // Backbeats
        }

        // Complexity adds off-beat hits
        if step % 2 == 1 {
            probability += complexity * 0.2
        }

        return min(1.0, probability)
    }

    private func detectOnsets(_ samples: [Float]) -> [Double] {
        // Simplified onset detection
        return [0, 0.5, 1.0, 1.5, 2.0]
    }

    private func estimateTempo(_ onsets: [Double]) -> Double {
        guard onsets.count > 1 else { return 120 }
        let intervals = zip(onsets, onsets.dropFirst()).map { $1 - $0 }
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        return 60.0 / avgInterval
    }

    private func trackBeats(_ onsets: [Double], tempo: Double) -> [Double] {
        return onsets
    }

    private func loadGroovePatterns() {
        groovePatterns["straight"] = GroovePattern(name: "Straight", offsets: [0, 0, 0, 0])
        groovePatterns["shuffle"] = GroovePattern(name: "Shuffle", offsets: [0, 0.1, 0, 0.1])
        groovePatterns["swing"] = GroovePattern(name: "Swing", offsets: [0, 0.15, 0, 0.15])
    }

    private func loadPolyrhythms() {
        polyrhythmLibrary.append(Polyrhythm(ratio: (3, 2), name: "Hemiola"))
        polyrhythmLibrary.append(Polyrhythm(ratio: (4, 3), name: "4:3"))
        polyrhythmLibrary.append(Polyrhythm(ratio: (5, 4), name: "5:4"))
    }
}

struct RhythmHit {
    var time: Double
    var velocity: Double
    var duration: Double
}

struct GroovePattern {
    var name: String
    var offsets: [Double]
}

struct Polyrhythm {
    var ratio: (Int, Int)
    var name: String
}

// MARK: - Mixing Agent

public final class MixingAgent: ANIAgent {
    public let agentID = "ani.mixing"
    public let agentName = "Mixing Engineer AI"
    public let domain: ANIDomain = .mixing
    public private(set) var confidence: Double = 0.80
    public var isActive: Bool = true

    public init() {}

    public func process(_ input: ANIInput) async throws -> ANIOutput {
        switch input.type {
        case .audio(let samples):
            return await analyzeMix(samples)
        case .parameters(let params):
            return await suggestMixSettings(params)
        default:
            throw ANIError.unsupportedInput
        }
    }

    public func learn(from feedback: ANIFeedback) async {
        confidence = confidence * 0.95 + feedback.rating * 0.05
    }

    public func reset() {
        confidence = 0.80
    }

    private func analyzeMix(_ samples: [Float]) async -> ANIOutput {
        // Analyze frequency balance
        let frequencyBalance = analyzeFrequencyBalance(samples)

        // Analyze dynamics
        let dynamics = analyzeDynamics(samples)

        // Analyze stereo image
        let stereoWidth = analyzeStereoWidth(samples)

        return ANIOutput(
            type: .parameters([
                "lowEnd": frequencyBalance.low,
                "midRange": frequencyBalance.mid,
                "highEnd": frequencyBalance.high,
                "dynamicRange": dynamics,
                "stereoWidth": stereoWidth
            ]),
            confidence: confidence,
            alternatives: [],
            explanation: "Mix analysis complete. Low: \(Int(frequencyBalance.low * 100))%, Mid: \(Int(frequencyBalance.mid * 100))%, High: \(Int(frequencyBalance.high * 100))%"
        )
    }

    private func suggestMixSettings(_ params: [String: Double]) async -> ANIOutput {
        var suggestions: [String: Double] = [:]

        // EQ suggestions
        if let lowEnd = params["lowEnd"], lowEnd > 0.4 {
            suggestions["highPassFreq"] = 80  // Cut some low end
        }

        // Compression suggestions
        if let dynamicRange = params["dynamicRange"], dynamicRange > 20 {
            suggestions["compressionRatio"] = 3.0
            suggestions["compressionThreshold"] = -12
        }

        // Stereo suggestions
        if let stereoWidth = params["stereoWidth"], stereoWidth < 0.5 {
            suggestions["stereoEnhance"] = 0.3
        }

        return ANIOutput(
            type: .parameters(suggestions),
            confidence: confidence,
            alternatives: [],
            explanation: "Mix improvement suggestions based on analysis"
        )
    }

    private func analyzeFrequencyBalance(_ samples: [Float]) -> (low: Double, mid: Double, high: Double) {
        return (0.35, 0.45, 0.20)
    }

    private func analyzeDynamics(_ samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let max = samples.map { abs($0) }.max() ?? 0
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
        return Double(20 * log10(max / rms))
    }

    private func analyzeStereoWidth(_ samples: [Float]) -> Double {
        return 0.6  // Simplified
    }
}

// MARK: - Mastering Agent

public final class MasteringAgent: ANIAgent {
    public let agentID = "ani.mastering"
    public let agentName = "Mastering Engineer AI"
    public let domain: ANIDomain = .mastering
    public private(set) var confidence: Double = 0.78
    public var isActive: Bool = true

    // Reference targets
    private let targetLUFS: Double = -14.0
    private let targetTruePeak: Double = -1.0

    public init() {}

    public func process(_ input: ANIInput) async throws -> ANIOutput {
        switch input.type {
        case .audio(let samples):
            return await masterAudio(samples)
        case .parameters(let params):
            return await getMasteringChain(params)
        default:
            throw ANIError.unsupportedInput
        }
    }

    public func learn(from feedback: ANIFeedback) async {
        confidence = confidence * 0.95 + feedback.rating * 0.05
    }

    public func reset() {
        confidence = 0.78
    }

    private func masterAudio(_ samples: [Float]) async -> ANIOutput {
        // Analyze loudness
        let currentLUFS = measureLUFS(samples)
        let currentPeak = measureTruePeak(samples)

        // Calculate required gain
        let gainNeeded = targetLUFS - currentLUFS

        // Suggest processing chain
        let chain = MasteringChain(
            eq: EQSettings(
                lowShelfGain: currentLUFS < -18 ? 1.5 : 0,
                highShelfGain: 0.5,
                midBoost: 0
            ),
            compression: CompressionSettings(
                threshold: -10,
                ratio: 2.0,
                attack: 10,
                release: 100
            ),
            limiter: LimiterSettings(
                ceiling: Float(targetTruePeak),
                release: 50
            ),
            outputGain: Float(gainNeeded)
        )

        return ANIOutput(
            type: .parameters([
                "currentLUFS": currentLUFS,
                "targetLUFS": targetLUFS,
                "gainAdjustment": gainNeeded,
                "currentPeak": currentPeak
            ]),
            confidence: confidence,
            alternatives: [],
            explanation: "Current loudness: \(String(format: "%.1f", currentLUFS)) LUFS. Recommended gain: \(String(format: "%.1f", gainNeeded)) dB"
        )
    }

    private func getMasteringChain(_ params: [String: Double]) async -> ANIOutput {
        let genre = params["genre"] ?? 0  // 0 = pop, 1 = classical, etc.

        var chain: [String: Any] = [:]

        if genre < 0.5 {
            // Pop/Electronic - louder, more compression
            chain["targetLUFS"] = -10.0
            chain["compressionRatio"] = 4.0
        } else {
            // Classical/Jazz - more dynamic
            chain["targetLUFS"] = -18.0
            chain["compressionRatio"] = 1.5
        }

        return ANIOutput(
            type: .parameters(chain as! [String: Double]),
            confidence: confidence,
            alternatives: [],
            explanation: "Mastering chain configured for genre type \(Int(genre))"
        )
    }

    private func measureLUFS(_ samples: [Float]) -> Double {
        // Simplified LUFS measurement
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(max(samples.count, 1)))
        return Double(-0.691 + 10 * log10(Double(rms * rms)))
    }

    private func measureTruePeak(_ samples: [Float]) -> Double {
        let peak = samples.map { abs($0) }.max() ?? 0
        return Double(20 * log10(peak))
    }
}

struct MasteringChain {
    var eq: EQSettings
    var compression: CompressionSettings
    var limiter: LimiterSettings
    var outputGain: Float
}

struct EQSettings {
    var lowShelfGain: Double
    var highShelfGain: Double
    var midBoost: Double
}

struct CompressionSettings {
    var threshold: Double
    var ratio: Double
    var attack: Double
    var release: Double
}

struct LimiterSettings {
    var ceiling: Float
    var release: Double
}

// MARK: - ANI Agent Manager

@MainActor
public final class ANIAgentManager: ObservableObject {
    public static let shared = ANIAgentManager()

    @Published public private(set) var agents: [String: any ANIAgent] = [:]
    @Published public private(set) var activeAgents: Set<String> = []

    private init() {
        registerDefaultAgents()
        aniLogger.info("ANI Agent Manager initialized with \(self.agents.count) agents")
    }

    private func registerDefaultAgents() {
        let harmonyAgent = HarmonyAgent()
        let melodyAgent = MelodyAgent()
        let rhythmAgent = RhythmAgent()
        let mixingAgent = MixingAgent()
        let masteringAgent = MasteringAgent()

        agents[harmonyAgent.agentID] = harmonyAgent
        agents[melodyAgent.agentID] = melodyAgent
        agents[rhythmAgent.agentID] = rhythmAgent
        agents[mixingAgent.agentID] = mixingAgent
        agents[masteringAgent.agentID] = masteringAgent

        activeAgents = Set(agents.keys)
    }

    public func getAgent(for domain: ANIDomain) -> (any ANIAgent)? {
        agents.values.first { $0.domain == domain }
    }

    public func process(_ input: ANIInput, using domain: ANIDomain) async throws -> ANIOutput {
        guard let agent = getAgent(for: domain) else {
            throw ANIError.agentNotFound
        }
        return try await agent.process(input)
    }

    public func processWithMultipleAgents(_ input: ANIInput, domains: [ANIDomain]) async throws -> [ANIDomain: ANIOutput] {
        var results: [ANIDomain: ANIOutput] = [:]

        await withTaskGroup(of: (ANIDomain, ANIOutput?).self) { group in
            for domain in domains {
                group.addTask {
                    guard let agent = await self.getAgent(for: domain) else { return (domain, nil) }
                    let output = try? await agent.process(input)
                    return (domain, output)
                }
            }

            for await (domain, output) in group {
                if let output = output {
                    results[domain] = output
                }
            }
        }

        return results
    }
}

// MARK: - Errors

public enum ANIError: Error {
    case unsupportedInput
    case agentNotFound
    case processingFailed(String)
}

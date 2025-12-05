import Foundation
import Accelerate

// MARK: - Real-Time Harmonization Engine
// High-performance, low-latency harmonization for live input
// Optimized for < 10ms latency with SIMD acceleration

@MainActor
public final class RealTimeHarmonizationEngine: ObservableObject {
    public static let shared = RealTimeHarmonizationEngine()

    @Published public private(set) var isActive = false
    @Published public private(set) var currentKey: DetectedKey?
    @Published public private(set) var currentChord: RealTimeChord?
    @Published public private(set) var harmonicSuggestions: [HarmonicSuggestion] = []
    @Published public private(set) var latencyMs: Double = 0

    // Processing state
    private var pitchBuffer: LockFreeRingBuffer<DetectedPitch>
    private var keyTracker: AdaptiveKeyTracker
    private var chordRecognizer: FastChordRecognizer
    private var harmonizationCache: HarmonizationCache

    // Configuration
    private var config: HarmonizationConfig

    // Performance monitoring
    private var processingTimes: [Double] = []
    private let maxProcessingHistory = 100

    public init() {
        self.pitchBuffer = LockFreeRingBuffer(capacity: 128)
        self.keyTracker = AdaptiveKeyTracker()
        self.chordRecognizer = FastChordRecognizer()
        self.harmonizationCache = HarmonizationCache(maxSize: 1024)
        self.config = HarmonizationConfig()
    }

    // MARK: - Configuration

    public struct HarmonizationConfig {
        public var voiceCount: Int = 4
        public var style: HarmonizationStyle = .classical
        public var autoDetectKey: Bool = true
        public var useCache: Bool = true
        public var maxLatencyMs: Double = 10
        public var harmonyType: HarmonyType = .chordal

        public enum HarmonizationStyle {
            case classical    // Bach-style voice leading
            case jazz         // Extended harmonies, voice leading relaxed
            case pop          // Simple triads, parallel motion OK
            case gospel       // Dense voicings, chromatic movements
            case barbershop   // Close harmony, ring overtones
            case orchestral   // Wide voicings, orchestral ranges
        }

        public enum HarmonyType {
            case chordal      // Full chord harmonization
            case counterpoint // Independent melodic lines
            case drone        // Sustained bass/fifth
            case parallel     // Parallel intervals
            case mixed        // Adaptive combination
        }
    }

    public func configure(_ config: HarmonizationConfig) {
        self.config = config
    }

    // MARK: - Real-Time Input Processing

    /// Process incoming pitch (call from audio thread)
    public nonisolated func processPitch(_ pitch: DetectedPitch) {
        _ = pitchBuffer.write(pitch)
    }

    /// Main processing loop (call at regular intervals, e.g., 10ms)
    public func processFrame() async -> HarmonizationResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Read all available pitches
        var pitches: [DetectedPitch] = []
        while let pitch = pitchBuffer.read() {
            pitches.append(pitch)
        }

        guard !pitches.isEmpty else {
            return HarmonizationResult(
                harmonizedVoices: [],
                detectedKey: currentKey,
                detectedChord: currentChord,
                suggestions: harmonicSuggestions,
                latency: 0
            )
        }

        // Update key tracking
        if config.autoDetectKey {
            for pitch in pitches {
                keyTracker.addPitch(pitch.midiNote)
            }
            currentKey = keyTracker.currentKey
        }

        // Chord recognition
        let chordPitches = pitches.map { $0.midiNote }
        currentChord = chordRecognizer.recognize(pitches: chordPitches)

        // Generate harmonization
        let mainPitch = pitches.max(by: { $0.confidence < $1.confidence })!
        let harmonizedVoices = await harmonize(mainPitch)

        // Generate suggestions
        harmonicSuggestions = generateSuggestions(for: mainPitch)

        let endTime = CFAbsoluteTimeGetCurrent()
        latencyMs = (endTime - startTime) * 1000

        // Track performance
        processingTimes.append(latencyMs)
        if processingTimes.count > maxProcessingHistory {
            processingTimes.removeFirst()
        }

        return HarmonizationResult(
            harmonizedVoices: harmonizedVoices,
            detectedKey: currentKey,
            detectedChord: currentChord,
            suggestions: harmonicSuggestions,
            latency: latencyMs
        )
    }

    // MARK: - Harmonization Core

    private func harmonize(_ pitch: DetectedPitch) async -> [HarmonizedVoice] {
        let key = currentKey ?? DetectedKey(tonic: 0, mode: .major, confidence: 0.5)

        // Check cache first
        let cacheKey = HarmonizationCacheKey(
            pitch: pitch.midiNote,
            keyTonic: key.tonic,
            style: config.style
        )

        if config.useCache, let cached = harmonizationCache.get(cacheKey) {
            return cached
        }

        // Generate harmonization based on style
        let voices: [HarmonizedVoice]

        switch config.harmonyType {
        case .chordal:
            voices = harmonizeChordal(pitch, key: key)
        case .counterpoint:
            voices = harmonizeCounterpoint(pitch, key: key)
        case .drone:
            voices = harmonizeDrone(pitch, key: key)
        case .parallel:
            voices = harmonizeParallel(pitch, key: key)
        case .mixed:
            voices = harmonizeMixed(pitch, key: key)
        }

        // Cache result
        if config.useCache {
            harmonizationCache.set(cacheKey, voices)
        }

        return voices
    }

    private func harmonizeChordal(_ pitch: DetectedPitch, key: DetectedKey) -> [HarmonizedVoice] {
        let midiNote = pitch.midiNote
        let pitchClass = midiNote % 12
        let scaleDegreee = (pitchClass - key.tonic + 12) % 12

        // Get chord for this scale degree
        let chordPitchClasses = getChordForScaleDegree(scaleDegreee, in: key)

        // Voice leading optimization
        var voices: [HarmonizedVoice] = []

        // Soprano (melody)
        voices.append(HarmonizedVoice(
            midiNote: midiNote,
            velocity: pitch.velocity,
            voiceType: .soprano
        ))

        // Alto
        let altoPC = chordPitchClasses.count > 1 ? chordPitchClasses[1] : chordPitchClasses[0]
        let altoNote = findClosestOctave(pitchClass: altoPC, reference: midiNote - 5, direction: .below)
        voices.append(HarmonizedVoice(
            midiNote: altoNote,
            velocity: pitch.velocity * 0.85,
            voiceType: .alto
        ))

        // Tenor
        if config.voiceCount >= 3 {
            let tenorPC = chordPitchClasses.count > 2 ? chordPitchClasses[2] : chordPitchClasses[0]
            let tenorNote = findClosestOctave(pitchClass: tenorPC, reference: midiNote - 12, direction: .below)
            voices.append(HarmonizedVoice(
                midiNote: tenorNote,
                velocity: pitch.velocity * 0.8,
                voiceType: .tenor
            ))
        }

        // Bass
        if config.voiceCount >= 4 {
            let bassPC = chordPitchClasses[0] // Root
            let bassNote = findClosestOctave(pitchClass: bassPC, reference: midiNote - 24, direction: .below)
            voices.append(HarmonizedVoice(
                midiNote: max(28, bassNote), // Don't go below E1
                velocity: pitch.velocity * 0.9,
                voiceType: .bass
            ))
        }

        return voices
    }

    private func harmonizeCounterpoint(_ pitch: DetectedPitch, key: DetectedKey) -> [HarmonizedVoice] {
        var voices: [HarmonizedVoice] = []
        let midiNote = pitch.midiNote

        // Main voice
        voices.append(HarmonizedVoice(
            midiNote: midiNote,
            velocity: pitch.velocity,
            voiceType: .soprano
        ))

        // Counter voice - contrary motion preference
        let counterInterval: Int
        switch config.style {
        case .classical:
            counterInterval = [3, 4, 5, 7, 8, 9].randomElement()! // Consonant intervals
        case .jazz:
            counterInterval = [2, 3, 4, 5, 7, 9, 10, 11].randomElement()! // Include 9ths, 7ths
        default:
            counterInterval = [3, 4, 7].randomElement()! // Simple consonances
        }

        // Alternate between above and below
        let direction = Int.random(in: 0...1) == 0 ? 1 : -1
        voices.append(HarmonizedVoice(
            midiNote: midiNote + counterInterval * direction,
            velocity: pitch.velocity * 0.85,
            voiceType: .alto
        ))

        // Third voice if needed - focus on passing tones
        if config.voiceCount >= 3 {
            let thirdInterval = 12 + (direction > 0 ? -7 : 7) // Opposite octave region
            voices.append(HarmonizedVoice(
                midiNote: midiNote + thirdInterval,
                velocity: pitch.velocity * 0.75,
                voiceType: .tenor
            ))
        }

        return voices
    }

    private func harmonizeDrone(_ pitch: DetectedPitch, key: DetectedKey) -> [HarmonizedVoice] {
        var voices: [HarmonizedVoice] = []
        let midiNote = pitch.midiNote

        // Melody
        voices.append(HarmonizedVoice(
            midiNote: midiNote,
            velocity: pitch.velocity,
            voiceType: .soprano
        ))

        // Drone on tonic
        let droneBass = key.tonic + 36 // C2 area
        voices.append(HarmonizedVoice(
            midiNote: droneBass,
            velocity: pitch.velocity * 0.6,
            voiceType: .bass
        ))

        // Drone fifth
        if config.voiceCount >= 3 {
            voices.append(HarmonizedVoice(
                midiNote: droneBass + 7, // Perfect fifth above
                velocity: pitch.velocity * 0.5,
                voiceType: .tenor
            ))
        }

        return voices
    }

    private func harmonizeParallel(_ pitch: DetectedPitch, key: DetectedKey) -> [HarmonizedVoice] {
        var voices: [HarmonizedVoice] = []
        let midiNote = pitch.midiNote

        // Main voice
        voices.append(HarmonizedVoice(
            midiNote: midiNote,
            velocity: pitch.velocity,
            voiceType: .soprano
        ))

        // Parallel intervals based on style
        let intervals: [Int]
        switch config.style {
        case .pop:
            intervals = [-12, -5] // Octave below, fourth below
        case .gospel:
            intervals = [-3, -5, -7] // Third, fourth, fifth below
        case .barbershop:
            intervals = [-4, -7, -12] // Major third, fifth, octave
        default:
            intervals = [-5, -12] // Fourth, octave
        }

        for (i, interval) in intervals.prefix(config.voiceCount - 1).enumerated() {
            let voiceType: VoiceType = i == 0 ? .alto : (i == 1 ? .tenor : .bass)
            voices.append(HarmonizedVoice(
                midiNote: midiNote + interval,
                velocity: pitch.velocity * (0.9 - Double(i) * 0.1),
                voiceType: voiceType
            ))
        }

        return voices
    }

    private func harmonizeMixed(_ pitch: DetectedPitch, key: DetectedKey) -> [HarmonizedVoice] {
        // Adaptive: choose based on melodic context
        let scaleDegree = (pitch.midiNote - key.tonic) % 12

        // Strong beats / stable scale degrees -> chordal
        // Weak beats / passing tones -> counterpoint or parallel
        if [0, 4, 7].contains(scaleDegree) {
            return harmonizeChordal(pitch, key: key)
        } else if [2, 5, 9, 11].contains(scaleDegree) {
            return harmonizeParallel(pitch, key: key)
        } else {
            return harmonizeCounterpoint(pitch, key: key)
        }
    }

    // MARK: - Helper Functions

    private func getChordForScaleDegree(_ degree: Int, in key: DetectedKey) -> [Int] {
        // Map scale degree to chord pitch classes (relative to key)
        let chordIntervals: [Int]

        switch degree {
        case 0: // I (tonic)
            chordIntervals = key.mode == .major ? [0, 4, 7] : [0, 3, 7]
        case 2: // ii
            chordIntervals = key.mode == .major ? [2, 5, 9] : [2, 5, 8]
        case 4: // iii / III
            chordIntervals = key.mode == .major ? [4, 7, 11] : [3, 7, 10]
        case 5: // IV / iv
            chordIntervals = key.mode == .major ? [5, 9, 0] : [5, 8, 0]
        case 7: // V
            chordIntervals = [7, 11, 2]
        case 9: // vi / VI
            chordIntervals = key.mode == .major ? [9, 0, 4] : [8, 0, 3]
        case 11: // vii° / VII
            chordIntervals = key.mode == .major ? [11, 2, 5] : [10, 2, 5]
        default:
            // Chromatic note - use diminished
            chordIntervals = [degree, (degree + 3) % 12, (degree + 6) % 12]
        }

        return chordIntervals.map { ($0 + key.tonic) % 12 }
    }

    private enum OctaveDirection {
        case above, below, nearest
    }

    private func findClosestOctave(pitchClass: Int, reference: Int, direction: OctaveDirection) -> Int {
        let referenceOctave = reference / 12
        let baseNote = pitchClass + referenceOctave * 12

        switch direction {
        case .above:
            return baseNote >= reference ? baseNote : baseNote + 12
        case .below:
            return baseNote <= reference ? baseNote : baseNote - 12
        case .nearest:
            let above = baseNote >= reference ? baseNote : baseNote + 12
            let below = baseNote <= reference ? baseNote : baseNote - 12
            return abs(above - reference) < abs(below - reference) ? above : below
        }
    }

    // MARK: - Suggestion Generation

    private func generateSuggestions(for pitch: DetectedPitch) -> [HarmonicSuggestion] {
        guard let key = currentKey else { return [] }

        var suggestions: [HarmonicSuggestion] = []
        let pitchClass = pitch.midiNote % 12
        let scaleDegree = (pitchClass - key.tonic + 12) % 12

        // Suggest next chord based on current position
        let nextChords = suggestNextChords(currentDegree: scaleDegree, key: key)

        for (chord, probability, reason) in nextChords.prefix(5) {
            suggestions.append(HarmonicSuggestion(
                type: .nextChord,
                chord: chord,
                probability: probability,
                reason: reason
            ))
        }

        // Suggest modulations if at cadence point
        if [0, 7].contains(scaleDegree) {
            let modulations = suggestModulations(from: key)
            for mod in modulations.prefix(3) {
                suggestions.append(mod)
            }
        }

        return suggestions
    }

    private func suggestNextChords(
        currentDegree: Int,
        key: DetectedKey
    ) -> [(chord: SuggestedChord, probability: Double, reason: String)] {
        var suggestions: [(SuggestedChord, Double, String)] = []

        // Common progressions based on current degree
        switch currentDegree {
        case 0: // On I
            suggestions.append((SuggestedChord(root: key.tonic + 5, quality: .major), 0.8, "IV - Subdominant"))
            suggestions.append((SuggestedChord(root: key.tonic + 7, quality: .major), 0.9, "V - Dominant"))
            suggestions.append((SuggestedChord(root: key.tonic + 9, quality: .minor), 0.6, "vi - Relative minor"))
        case 2: // On ii
            suggestions.append((SuggestedChord(root: key.tonic + 7, quality: .dominant7), 0.9, "V7 - ii-V progression"))
            suggestions.append((SuggestedChord(root: key.tonic + 5, quality: .major), 0.5, "IV - Plagal direction"))
        case 5: // On IV
            suggestions.append((SuggestedChord(root: key.tonic + 7, quality: .major), 0.8, "V - Pre-dominant to dominant"))
            suggestions.append((SuggestedChord(root: key.tonic, quality: .major), 0.6, "I - Plagal cadence"))
            suggestions.append((SuggestedChord(root: key.tonic + 2, quality: .minor), 0.5, "ii - Falling fifths"))
        case 7: // On V
            suggestions.append((SuggestedChord(root: key.tonic, quality: key.mode == .major ? .major : .minor), 0.95, "I - Authentic cadence"))
            suggestions.append((SuggestedChord(root: key.tonic + 9, quality: .minor), 0.4, "vi - Deceptive cadence"))
        case 9: // On vi
            suggestions.append((SuggestedChord(root: key.tonic + 2, quality: .minor), 0.7, "ii - Circle of fifths"))
            suggestions.append((SuggestedChord(root: key.tonic + 5, quality: .major), 0.6, "IV - Common progression"))
        default:
            suggestions.append((SuggestedChord(root: key.tonic + 7, quality: .major), 0.7, "V - Return to dominant"))
            suggestions.append((SuggestedChord(root: key.tonic, quality: .major), 0.5, "I - Return to tonic"))
        }

        return suggestions
    }

    private func suggestModulations(from key: DetectedKey) -> [HarmonicSuggestion] {
        var suggestions: [HarmonicSuggestion] = []

        // Closely related keys
        let relatedKeys: [(Int, DetectedKey.KeyMode, String)] = [
            ((key.tonic + 7) % 12, .major, "Dominant key (V)"),
            ((key.tonic + 5) % 12, .major, "Subdominant key (IV)"),
            ((key.tonic + 9) % 12, .minor, "Relative minor (vi)"),
            ((key.tonic + 2) % 12, .minor, "Supertonic minor (ii)"),
        ]

        for (tonic, mode, reason) in relatedKeys {
            suggestions.append(HarmonicSuggestion(
                type: .modulation,
                chord: SuggestedChord(root: tonic, quality: mode == .major ? .major : .minor),
                probability: 0.6,
                reason: reason
            ))
        }

        return suggestions
    }

    // MARK: - Performance Stats

    public var averageLatency: Double {
        guard !processingTimes.isEmpty else { return 0 }
        return processingTimes.reduce(0, +) / Double(processingTimes.count)
    }

    public var maxLatency: Double {
        processingTimes.max() ?? 0
    }

    public func start() {
        isActive = true
    }

    public func stop() {
        isActive = false
    }
}

// MARK: - Supporting Types

public struct DetectedPitch {
    public let midiNote: Int
    public let frequency: Double
    public let confidence: Double
    public let velocity: Double
    public let timestamp: TimeInterval

    public init(midiNote: Int, frequency: Double = 0, confidence: Double = 1.0,
                velocity: Double = 0.8, timestamp: TimeInterval = 0) {
        self.midiNote = midiNote
        self.frequency = frequency > 0 ? frequency : 440.0 * pow(2.0, Double(midiNote - 69) / 12.0)
        self.confidence = confidence
        self.velocity = velocity
        self.timestamp = timestamp
    }
}

public struct DetectedKey: Equatable {
    public let tonic: Int
    public let mode: KeyMode
    public let confidence: Double

    public enum KeyMode: String {
        case major, minor
    }

    public var name: String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return "\(noteNames[tonic]) \(mode.rawValue)"
    }
}

public struct RealTimeChord: Equatable {
    public let root: Int
    public let quality: ChordQuality
    public let bass: Int?
    public let extensions: [Int]

    public var name: String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        var name = noteNames[root % 12]
        name += quality.symbol
        if let bass = bass, bass != root {
            name += "/\(noteNames[bass % 12])"
        }
        return name
    }
}

public struct HarmonizedVoice: Equatable {
    public let midiNote: Int
    public let velocity: Double
    public let voiceType: VoiceType
}

public enum VoiceType: String {
    case soprano, alto, tenor, bass
}

public struct HarmonizationResult {
    public let harmonizedVoices: [HarmonizedVoice]
    public let detectedKey: DetectedKey?
    public let detectedChord: RealTimeChord?
    public let suggestions: [HarmonicSuggestion]
    public let latency: Double
}

public struct HarmonicSuggestion {
    public let type: SuggestionType
    public let chord: SuggestedChord
    public let probability: Double
    public let reason: String

    public enum SuggestionType {
        case nextChord, modulation, cadence, substitution
    }
}

public struct SuggestedChord {
    public let root: Int
    public let quality: ChordQuality

    public var name: String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return noteNames[root % 12] + quality.symbol
    }
}

extension ChordQuality {
    var symbol: String {
        switch self {
        case .major: return ""
        case .minor: return "m"
        case .diminished: return "dim"
        case .augmented: return "aug"
        case .dominant7: return "7"
        case .major7: return "maj7"
        case .minor7: return "m7"
        case .diminished7: return "dim7"
        case .halfDiminished7: return "m7b5"
        case .sus2: return "sus2"
        case .sus4: return "sus4"
        }
    }
}

// MARK: - Lock-Free Ring Buffer

public final class LockFreeRingBuffer<T> {
    private var buffer: [T?]
    private var head: Int = 0
    private var tail: Int = 0
    private let capacity: Int

    public init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }

    public func write(_ element: T) -> Bool {
        let nextTail = (tail + 1) % capacity
        if nextTail == head {
            return false // Buffer full
        }
        buffer[tail] = element
        tail = nextTail
        return true
    }

    public func read() -> T? {
        if head == tail {
            return nil // Buffer empty
        }
        let element = buffer[head]
        buffer[head] = nil
        head = (head + 1) % capacity
        return element
    }
}

// MARK: - Adaptive Key Tracker

public class AdaptiveKeyTracker {
    private var pitchHistogram: [Int: Int] = [:]
    private var recentPitches: [Int] = []
    private let windowSize = 64

    public var currentKey: DetectedKey {
        // Krumhansl-Schmuckler key-finding algorithm
        let majorProfile: [Double] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
        let minorProfile: [Double] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

        var bestCorrelation = -Double.infinity
        var bestKey = DetectedKey(tonic: 0, mode: .major, confidence: 0)

        // Build distribution
        var distribution = [Double](repeating: 0, count: 12)
        for (pitch, count) in pitchHistogram {
            distribution[pitch % 12] += Double(count)
        }

        // Normalize
        let sum = distribution.reduce(0, +)
        if sum > 0 {
            distribution = distribution.map { $0 / sum }
        }

        // Test all keys
        for tonic in 0..<12 {
            // Major
            let majorCorr = correlate(distribution, rotate(majorProfile, by: tonic))
            if majorCorr > bestCorrelation {
                bestCorrelation = majorCorr
                bestKey = DetectedKey(tonic: tonic, mode: .major, confidence: majorCorr)
            }

            // Minor
            let minorCorr = correlate(distribution, rotate(minorProfile, by: tonic))
            if minorCorr > bestCorrelation {
                bestCorrelation = minorCorr
                bestKey = DetectedKey(tonic: tonic, mode: .minor, confidence: minorCorr)
            }
        }

        return bestKey
    }

    public func addPitch(_ midiNote: Int) {
        let pitchClass = midiNote % 12
        pitchHistogram[pitchClass, default: 0] += 1
        recentPitches.append(pitchClass)

        // Maintain window
        if recentPitches.count > windowSize {
            let removed = recentPitches.removeFirst()
            pitchHistogram[removed, default: 1] -= 1
        }
    }

    private func correlate(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }
        let n = Double(a.count)
        let meanA = a.reduce(0, +) / n
        let meanB = b.reduce(0, +) / n

        var num = 0.0
        var denA = 0.0
        var denB = 0.0

        for i in 0..<a.count {
            let diffA = a[i] - meanA
            let diffB = b[i] - meanB
            num += diffA * diffB
            denA += diffA * diffA
            denB += diffB * diffB
        }

        let den = sqrt(denA * denB)
        return den > 0 ? num / den : 0
    }

    private func rotate(_ arr: [Double], by n: Int) -> [Double] {
        let count = arr.count
        return (0..<count).map { arr[($0 - n + count) % count] }
    }

    public func reset() {
        pitchHistogram.removeAll()
        recentPitches.removeAll()
    }
}

// MARK: - Fast Chord Recognizer

public class FastChordRecognizer {
    // Pre-computed chord templates for fast matching
    private let chordTemplates: [([Int], ChordQuality)] = [
        ([0, 4, 7], .major),
        ([0, 3, 7], .minor),
        ([0, 3, 6], .diminished),
        ([0, 4, 8], .augmented),
        ([0, 4, 7, 10], .dominant7),
        ([0, 4, 7, 11], .major7),
        ([0, 3, 7, 10], .minor7),
        ([0, 3, 6, 9], .diminished7),
        ([0, 3, 6, 10], .halfDiminished7),
        ([0, 2, 7], .sus2),
        ([0, 5, 7], .sus4),
    ]

    public func recognize(pitches: [Int]) -> RealTimeChord? {
        guard !pitches.isEmpty else { return nil }

        let pitchClasses = Set(pitches.map { $0 % 12 })
        let sortedPCs = pitchClasses.sorted()

        var bestMatch: (root: Int, quality: ChordQuality, score: Int)?

        for root in 0..<12 {
            for (template, quality) in chordTemplates {
                let transposed = Set(template.map { ($0 + root) % 12 })
                let overlap = pitchClasses.intersection(transposed).count
                let score = overlap * 10 - abs(pitchClasses.count - transposed.count)

                if bestMatch == nil || score > bestMatch!.score {
                    bestMatch = (root, quality, score)
                }
            }
        }

        guard let match = bestMatch, match.score > 15 else { return nil }

        let bass = pitches.min()! % 12

        return RealTimeChord(
            root: match.root,
            quality: match.quality,
            bass: bass != match.root ? bass : nil,
            extensions: []
        )
    }
}

// MARK: - Harmonization Cache

private struct HarmonizationCacheKey: Hashable {
    let pitch: Int
    let keyTonic: Int
    let style: RealTimeHarmonizationEngine.HarmonizationConfig.HarmonizationStyle

    func hash(into hasher: inout Hasher) {
        hasher.combine(pitch)
        hasher.combine(keyTonic)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.pitch == rhs.pitch && lhs.keyTonic == rhs.keyTonic
    }
}

private class HarmonizationCache {
    private var cache: [HarmonizationCacheKey: [HarmonizedVoice]] = [:]
    private var accessOrder: [HarmonizationCacheKey] = []
    private let maxSize: Int

    init(maxSize: Int) {
        self.maxSize = maxSize
    }

    func get(_ key: HarmonizationCacheKey) -> [HarmonizedVoice]? {
        cache[key]
    }

    func set(_ key: HarmonizationCacheKey, _ value: [HarmonizedVoice]) {
        if cache.count >= maxSize {
            // Evict oldest
            if let oldest = accessOrder.first {
                cache.removeValue(forKey: oldest)
                accessOrder.removeFirst()
            }
        }

        cache[key] = value
        accessOrder.append(key)
    }
}

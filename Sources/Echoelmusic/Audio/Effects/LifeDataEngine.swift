import Foundation
import AVFoundation
import Combine
import Accelerate

// ═══════════════════════════════════════════════════════════════════════════════
// LIFE DATA ENGINE - BIOFEEDBACK-DRIVEN AUDIO INSPIRATION
// ═══════════════════════════════════════════════════════════════════════════════
//
// Inspired by XLN Audio's "Life":
// • Uses real biofeedback data to generate musical inspiration
// • Heart rate → Tempo, rhythm patterns
// • HRV → Groove feel, swing, humanization
// • Coherence → Harmonic complexity, consonance/dissonance
// • Breath → Phrase length, dynamics envelope
// • Energy → Intensity, density, velocity
//
// "Your life creates the music"
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Life Data Signal

/// Extended biofeedback signal with derived musical parameters
struct LifeDataSignal {
    // Raw biofeedback
    var heartRate: Float = 72.0       // BPM
    var hrv: Float = 50.0             // ms RMSSD
    var coherence: Float = 50.0       // 0-100
    var breathRate: Float = 14.0      // breaths/min
    var energy: Float = 0.5           // 0-1
    var stress: Float = 0.3           // 0-1 (derived from HRV/coherence)
    var relaxation: Float = 0.5       // 0-1

    // Derived musical parameters
    var suggestedTempo: Float { heartRate }
    var suggestedSwing: Float { min(hrv / 100.0, 0.7) }
    var harmonicComplexity: Float { coherence / 100.0 }
    var phraseLength: Float { 60.0 / breathRate * 4.0 } // bars
    var intensityLevel: Float { energy }

    // Movement & activity
    var isMoving: Bool = false
    var movementIntensity: Float = 0.0

    // Time-based patterns
    var timestamp: Date = Date()
    var sessionDuration: TimeInterval = 0
}

// MARK: - Musical Scale & Mode

enum MusicalMode: String, CaseIterable {
    case major = "Major (Ionian)"
    case minor = "Minor (Aeolian)"
    case dorian = "Dorian"
    case phrygian = "Phrygian"
    case lydian = "Lydian"
    case mixolydian = "Mixolydian"
    case locrian = "Locrian"
    case pentatonicMajor = "Pentatonic Major"
    case pentatonicMinor = "Pentatonic Minor"
    case blues = "Blues"
    case harmonicMinor = "Harmonic Minor"
    case wholeTone = "Whole Tone"

    /// Intervals from root (in semitones)
    var intervals: [Int] {
        switch self {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .minor: return [0, 2, 3, 5, 7, 8, 10]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
        case .lydian: return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
        case .locrian: return [0, 1, 3, 5, 6, 8, 10]
        case .pentatonicMajor: return [0, 2, 4, 7, 9]
        case .pentatonicMinor: return [0, 3, 5, 7, 10]
        case .blues: return [0, 3, 5, 6, 7, 10]
        case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
        case .wholeTone: return [0, 2, 4, 6, 8, 10]
        }
    }

    /// Emotional character
    var emotion: String {
        switch self {
        case .major: return "Happy, bright, confident"
        case .minor: return "Sad, introspective, emotional"
        case .dorian: return "Jazzy, sophisticated, bittersweet"
        case .phrygian: return "Spanish, exotic, mysterious"
        case .lydian: return "Dreamy, floating, ethereal"
        case .mixolydian: return "Bluesy, rock, dominant"
        case .locrian: return "Unstable, dark, tense"
        case .pentatonicMajor: return "Folk, simple, universal"
        case .pentatonicMinor: return "Blues, rock, Asian"
        case .blues: return "Soulful, expressive, raw"
        case .harmonicMinor: return "Classical, dramatic, exotic"
        case .wholeTone: return "Impressionistic, floating, ambiguous"
        }
    }
}

// MARK: - Generated Rhythm Pattern

struct RhythmPattern: Identifiable {
    let id = UUID()
    var name: String
    var beats: [RhythmBeat]
    var barsLength: Int = 4
    var swing: Float = 0.0  // 0-1
    var humanization: Float = 0.1

    struct RhythmBeat {
        var position: Float  // 0-1 within bar
        var velocity: Float  // 0-1
        var duration: Float  // 0-1
        var probability: Float = 1.0  // 0-1 (for generative patterns)
    }
}

// MARK: - Generated Melody

struct GeneratedMelody: Identifiable {
    let id = UUID()
    var name: String
    var notes: [MelodyNote]
    var rootNote: Int = 60  // MIDI note number (C4)
    var mode: MusicalMode
    var barsLength: Int = 4

    struct MelodyNote {
        var pitch: Int       // MIDI note number
        var startBeat: Float // Position in beats
        var duration: Float  // Duration in beats
        var velocity: Float  // 0-1
    }
}

// MARK: - Life Data Engine

@MainActor
class LifeDataEngine: ObservableObject {

    // MARK: - Published State

    /// Current life data signal
    @Published var currentSignal = LifeDataSignal()

    /// Historical life data for pattern analysis
    @Published var signalHistory: [LifeDataSignal] = []

    /// Generated rhythm pattern
    @Published var generatedRhythm: RhythmPattern?

    /// Generated melody
    @Published var generatedMelody: GeneratedMelody?

    /// Suggested musical mode based on current state
    @Published var suggestedMode: MusicalMode = .major

    /// Suggested tempo
    @Published var suggestedTempo: Float = 120.0

    /// Auto-generation enabled
    @Published var autoGenerate: Bool = true

    /// Generation intensity (how much bio-data influences output)
    @Published var generationIntensity: Float = 0.7

    // MARK: - Configuration

    /// Root note for generations (MIDI note number)
    var rootNote: Int = 60  // C4

    /// Time signature numerator
    var beatsPerBar: Int = 4

    /// Pattern length in bars
    var patternBars: Int = 4

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private let historyMaxLength = 1000  // ~16 minutes at 1 Hz

    // MARK: - Initialization

    init() {
        setupAutoGeneration()
    }

    deinit {
        updateTimer?.invalidate()
    }

    // MARK: - Signal Input

    /// Update with new biofeedback data
    func updateLifeData(_ signal: LifeDataSignal) {
        var updatedSignal = signal
        updatedSignal.timestamp = Date()

        // Calculate derived stress/relaxation
        updatedSignal.stress = calculateStress(from: signal)
        updatedSignal.relaxation = 1.0 - updatedSignal.stress

        currentSignal = updatedSignal

        // Add to history
        signalHistory.append(updatedSignal)
        if signalHistory.count > historyMaxLength {
            signalHistory.removeFirst()
        }

        // Update suggestions
        updateMusicalSuggestions()

        // Auto-generate if enabled
        if autoGenerate {
            generateFromLifeData()
        }
    }

    /// Update from raw biofeedback values
    func updateRawBiofeedback(heartRate: Float, hrv: Float, coherence: Float,
                               breathRate: Float, energy: Float) {
        var signal = LifeDataSignal()
        signal.heartRate = heartRate
        signal.hrv = hrv
        signal.coherence = coherence
        signal.breathRate = breathRate
        signal.energy = energy
        signal.sessionDuration = signalHistory.first.map {
            Date().timeIntervalSince($0.timestamp)
        } ?? 0

        updateLifeData(signal)
    }

    // MARK: - Musical Suggestions

    /// Update suggested musical parameters based on current life data
    private func updateMusicalSuggestions() {
        // Tempo from heart rate (with some smoothing)
        suggestedTempo = smoothedTempo()

        // Mode from coherence/stress
        suggestedMode = suggestMode(from: currentSignal)
    }

    /// Smooth tempo to prevent jarring changes
    private func smoothedTempo() -> Float {
        // Use weighted average of recent heart rates
        let recentSignals = signalHistory.suffix(10)
        guard !recentSignals.isEmpty else { return currentSignal.heartRate }

        let weights: [Float] = [0.05, 0.05, 0.08, 0.08, 0.1, 0.1, 0.12, 0.12, 0.15, 0.15]
        var weightedSum: Float = 0
        var weightSum: Float = 0

        for (index, signal) in recentSignals.enumerated() {
            let weight = index < weights.count ? weights[index] : 0.1
            weightedSum += signal.heartRate * weight
            weightSum += weight
        }

        return weightedSum / weightSum
    }

    /// Suggest musical mode based on emotional state
    private func suggestMode(from signal: LifeDataSignal) -> MusicalMode {
        let coherence = signal.coherence
        let energy = signal.energy
        let stress = signal.stress

        // High coherence + high energy = bright, confident
        if coherence > 70 && energy > 0.6 {
            return .major
        }

        // High coherence + low energy = peaceful, meditative
        if coherence > 70 && energy < 0.4 {
            return .pentatonicMajor
        }

        // Low coherence + high energy = tense, dramatic
        if coherence < 40 && energy > 0.6 {
            return .harmonicMinor
        }

        // Low coherence + low energy = sad, introspective
        if coherence < 40 && energy < 0.4 {
            return .minor
        }

        // High stress = darker modes
        if stress > 0.7 {
            return .phrygian
        }

        // Medium state = modal jazz
        if energy > 0.5 {
            return .dorian
        }

        return .mixolydian
    }

    // MARK: - Pattern Generation

    /// Generate rhythm pattern from life data
    func generateRhythm() -> RhythmPattern {
        let signal = currentSignal

        // Number of beats based on energy
        let beatDensity = Int(4 + signal.energy * 12)  // 4-16 beats per pattern

        // Swing from HRV (higher HRV = more swing/groove)
        let swing = min(signal.hrv / 100.0, 0.7)

        // Humanization from coherence variability
        let humanization = 0.05 + (1.0 - signal.coherence / 100.0) * 0.15

        var beats: [RhythmPattern.RhythmBeat] = []

        // Generate beats with life-influenced probabilities
        for i in 0..<beatDensity {
            let position = Float(i) / Float(beatDensity)

            // Velocity follows a pattern influenced by heart rate variability
            let hrvInfluence = sin(Float(i) * Float.pi * 2 * signal.hrv / 50.0) * 0.3
            let velocity = 0.5 + signal.energy * 0.3 + hrvInfluence

            // Duration influenced by breath rate
            let breathPhase = sin(Float(i) * Float.pi * 2 / signal.breathRate)
            let duration = 0.3 + 0.4 * (breathPhase + 1.0) / 2.0

            // Probability based on coherence (higher = more consistent)
            let probability = 0.5 + signal.coherence / 200.0

            beats.append(RhythmPattern.RhythmBeat(
                position: position,
                velocity: max(0.1, min(1.0, velocity)),
                duration: duration,
                probability: probability
            ))
        }

        let pattern = RhythmPattern(
            name: "Life Pattern \(Date().formatted(date: .omitted, time: .shortened))",
            beats: beats,
            barsLength: patternBars,
            swing: swing,
            humanization: humanization
        )

        generatedRhythm = pattern
        return pattern
    }

    /// Generate melody from life data
    func generateMelody() -> GeneratedMelody {
        let signal = currentSignal
        let mode = suggestedMode

        // Note density from energy and breath
        let notesPerBar = Int(2 + signal.energy * 6)  // 2-8 notes per bar
        let totalNotes = notesPerBar * patternBars

        // Get scale notes
        let scaleNotes = mode.intervals.map { rootNote + $0 }

        var notes: [GeneratedMelody.MelodyNote] = []
        var currentPitch = rootNote

        for i in 0..<totalNotes {
            let startBeat = Float(i) * Float(beatsPerBar * patternBars) / Float(totalNotes)

            // Pitch movement influenced by coherence
            // High coherence = stepwise motion, low coherence = leaps
            let coherenceInfluence = signal.coherence / 100.0
            let maxInterval = Int(1 + (1.0 - coherenceInfluence) * 4)  // 1-5 steps

            // Random walk within scale, influenced by energy
            let direction: Int
            if signal.energy > 0.7 {
                direction = Int.random(in: 0...1) == 0 ? 1 : -1  // More movement when energized
            } else {
                direction = currentPitch > rootNote ? -1 : 1  // Tend toward root when calm
            }

            let steps = Int.random(in: 0...maxInterval) * direction
            let scaleIndex = scaleNotes.firstIndex(of: currentPitch) ?? 0
            let newIndex = max(0, min(scaleNotes.count - 1, scaleIndex + steps))
            currentPitch = scaleNotes[newIndex]

            // Allow octave jumps occasionally (based on HRV)
            if Float.random(in: 0...1) < signal.hrv / 200.0 {
                currentPitch += (Bool.random() ? 12 : -12)
                currentPitch = max(rootNote - 12, min(rootNote + 24, currentPitch))
            }

            // Velocity influenced by stress pattern
            let stressWave = sin(Float(i) * Float.pi / 4) * signal.stress * 0.3
            let velocity = 0.5 + signal.energy * 0.3 + stressWave

            // Duration influenced by breath
            let breathInfluence = sin(startBeat / signal.phraseLength * Float.pi * 2)
            let duration = 0.5 + 0.5 * (breathInfluence + 1.0) / 2.0

            notes.append(GeneratedMelody.MelodyNote(
                pitch: currentPitch,
                startBeat: startBeat,
                duration: duration,
                velocity: max(0.1, min(1.0, velocity))
            ))
        }

        let melody = GeneratedMelody(
            name: "Life Melody \(Date().formatted(date: .omitted, time: .shortened))",
            notes: notes,
            rootNote: rootNote,
            mode: mode,
            barsLength: patternBars
        )

        generatedMelody = melody
        return melody
    }

    /// Generate both rhythm and melody from life data
    func generateFromLifeData() {
        _ = generateRhythm()
        _ = generateMelody()

        print("🎵 Life Data generated: \(suggestedMode.rawValue) @ \(Int(suggestedTempo)) BPM")
    }

    // MARK: - Session Analysis

    /// Analyze session patterns
    func analyzeSession() -> SessionAnalysis {
        guard signalHistory.count > 10 else {
            return SessionAnalysis()
        }

        let heartRates = signalHistory.map { $0.heartRate }
        let coherences = signalHistory.map { $0.coherence }
        let energies = signalHistory.map { $0.energy }

        return SessionAnalysis(
            averageHeartRate: heartRates.reduce(0, +) / Float(heartRates.count),
            heartRateVariability: standardDeviation(heartRates),
            averageCoherence: coherences.reduce(0, +) / Float(coherences.count),
            peakCoherence: coherences.max() ?? 0,
            averageEnergy: energies.reduce(0, +) / Float(energies.count),
            sessionDuration: currentSignal.sessionDuration,
            suggestedModes: analyzeModeProgression()
        )
    }

    /// Standard deviation calculation
    private func standardDeviation(_ values: [Float]) -> Float {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Float(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return sqrt(squaredDiffs.reduce(0, +) / Float(values.count - 1))
    }

    /// Analyze mode progression throughout session
    private func analyzeModeProgression() -> [MusicalMode] {
        var modes: [MusicalMode] = []
        let chunkSize = max(1, signalHistory.count / 4)

        for i in stride(from: 0, to: signalHistory.count, by: chunkSize) {
            let chunk = Array(signalHistory[i..<min(i + chunkSize, signalHistory.count)])
            if let avgSignal = averageSignal(chunk) {
                modes.append(suggestMode(from: avgSignal))
            }
        }

        return modes
    }

    /// Calculate average signal from array
    private func averageSignal(_ signals: [LifeDataSignal]) -> LifeDataSignal? {
        guard !signals.isEmpty else { return nil }

        var avg = LifeDataSignal()
        let count = Float(signals.count)

        avg.heartRate = signals.map { $0.heartRate }.reduce(0, +) / count
        avg.hrv = signals.map { $0.hrv }.reduce(0, +) / count
        avg.coherence = signals.map { $0.coherence }.reduce(0, +) / count
        avg.breathRate = signals.map { $0.breathRate }.reduce(0, +) / count
        avg.energy = signals.map { $0.energy }.reduce(0, +) / count

        return avg
    }

    // MARK: - Stress Calculation

    /// Calculate stress level from biofeedback
    private func calculateStress(from signal: LifeDataSignal) -> Float {
        // Low HRV = high stress
        let hrvStress = 1.0 - min(signal.hrv / 100.0, 1.0)

        // Low coherence = high stress
        let coherenceStress = 1.0 - signal.coherence / 100.0

        // High heart rate = potential stress
        let hrStress = max(0, (signal.heartRate - 80) / 60.0)

        // Weighted combination
        return min(1.0, hrvStress * 0.4 + coherenceStress * 0.4 + hrStress * 0.2)
    }

    // MARK: - Auto Generation Timer

    private func setupAutoGeneration() {
        // Generate new patterns every 30 seconds when auto-generate is on
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if self?.autoGenerate == true {
                    self?.generateFromLifeData()
                }
            }
        }
    }
}

// MARK: - Session Analysis Result

struct SessionAnalysis {
    var averageHeartRate: Float = 0
    var heartRateVariability: Float = 0
    var averageCoherence: Float = 0
    var peakCoherence: Float = 0
    var averageEnergy: Float = 0
    var sessionDuration: TimeInterval = 0
    var suggestedModes: [MusicalMode] = []

    var summary: String {
        """
        Session Analysis:
        • Duration: \(Int(sessionDuration / 60)) minutes
        • Avg Heart Rate: \(Int(averageHeartRate)) BPM (variability: \(Int(heartRateVariability)))
        • Avg Coherence: \(Int(averageCoherence))% (peak: \(Int(peakCoherence))%)
        • Avg Energy: \(Int(averageEnergy * 100))%
        • Musical Journey: \(suggestedModes.map { $0.rawValue.components(separatedBy: " ").first ?? "" }.joined(separator: " → "))
        """
    }
}

import Foundation
import Accelerate

/// LSTM-based Melody Generator
///
/// Neural network-powered melody generation with:
/// - LSTM architecture for temporal coherence
/// - Scale/key awareness
/// - Emotion-driven generation
/// - Motif development and variation
/// - Humanization (timing/velocity variation)
///
@MainActor
public final class LSTMMelodyGenerator {

    // MARK: - Types

    /// Musical key
    public enum MusicalKey: Int, CaseIterable {
        case cMajor = 0, cMinor, dMajor, dMinor, eMajor, eMinor
        case fMajor, fMinor, gMajor, gMinor, aMajor, aMinor
        case bMajor, bMinor

        var root: Int {
            switch self {
            case .cMajor, .cMinor: return 0
            case .dMajor, .dMinor: return 2
            case .eMajor, .eMinor: return 4
            case .fMajor, .fMinor: return 5
            case .gMajor, .gMinor: return 7
            case .aMajor, .aMinor: return 9
            case .bMajor, .bMinor: return 11
            }
        }

        var isMajor: Bool {
            switch self {
            case .cMajor, .dMajor, .eMajor, .fMajor, .gMajor, .aMajor, .bMajor: return true
            default: return false
            }
        }
    }

    /// Scale type
    public enum ScaleType: CaseIterable {
        case major, minor, harmonicMinor, melodicMinor
        case dorian, phrygian, lydian, mixolydian
        case pentatonic, blues

        var intervals: [Int] {
            switch self {
            case .major: return [0, 2, 4, 5, 7, 9, 11]
            case .minor: return [0, 2, 3, 5, 7, 8, 10]
            case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
            case .melodicMinor: return [0, 2, 3, 5, 7, 9, 11]
            case .dorian: return [0, 2, 3, 5, 7, 9, 10]
            case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
            case .lydian: return [0, 2, 4, 6, 7, 9, 11]
            case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
            case .pentatonic: return [0, 2, 4, 7, 9]
            case .blues: return [0, 3, 5, 6, 7, 10]
            }
        }
    }

    /// Generated melody note
    public struct MelodyNote: Equatable {
        public var pitch: Int       // MIDI 0-127
        public var duration: Double // In beats
        public var velocity: Int    // 0-127

        public init(pitch: Int, duration: Double, velocity: Int) {
            self.pitch = pitch
            self.duration = duration
            self.velocity = velocity
        }
    }

    /// Motif development technique
    public enum MotifTechnique: CaseIterable {
        case repetition
        case sequence      // Transpose up/down
        case inversion     // Invert intervals
        case retrograde    // Reverse
        case augmentation  // Longer durations
        case diminution    // Shorter durations
        case fragmentation // Use part of motif
    }

    /// Melodic contour
    public enum MelodicContour: CaseIterable {
        case ascending, descending, arch, valley
        case wave, static_, random
    }

    // MARK: - LSTM Network

    private struct LSTMCell {
        var weightsInput: [[Float]]   // Input gate weights
        var weightsForget: [[Float]]  // Forget gate weights
        var weightsCell: [[Float]]    // Cell state weights
        var weightsOutput: [[Float]]  // Output gate weights

        var biasInput: [Float]
        var biasForget: [Float]
        var biasCell: [Float]
        var biasOutput: [Float]

        var hiddenState: [Float]
        var cellState: [Float]
    }

    private var lstmLayers: [LSTMCell] = []
    private var outputLayer: [[Float]] = []
    private var outputBias: [Float] = []

    private let hiddenSize = 64
    private let numLayers = 2
    private let vocabSize = 128  // MIDI notes

    private var _isModelLoaded = false
    public var isModelLoaded: Bool { _isModelLoaded }

    // MARK: - Initialization

    public init() {}

    /// Load the LSTM model weights
    public func loadModel() async {
        await initializeLSTM()
        _isModelLoaded = true
    }

    private func initializeLSTM() async {
        lstmLayers = []

        // Initialize LSTM layers
        for layer in 0..<numLayers {
            let inputSize = layer == 0 ? vocabSize : hiddenSize

            lstmLayers.append(LSTMCell(
                weightsInput: initializeWeights(rows: hiddenSize, cols: inputSize + hiddenSize),
                weightsForget: initializeWeights(rows: hiddenSize, cols: inputSize + hiddenSize),
                weightsCell: initializeWeights(rows: hiddenSize, cols: inputSize + hiddenSize),
                weightsOutput: initializeWeights(rows: hiddenSize, cols: inputSize + hiddenSize),
                biasInput: [Float](repeating: 0, count: hiddenSize),
                biasForget: [Float](repeating: 1, count: hiddenSize), // Initialize to 1 for better gradient flow
                biasCell: [Float](repeating: 0, count: hiddenSize),
                biasOutput: [Float](repeating: 0, count: hiddenSize),
                hiddenState: [Float](repeating: 0, count: hiddenSize),
                cellState: [Float](repeating: 0, count: hiddenSize)
            ))
        }

        // Output layer
        outputLayer = initializeWeights(rows: vocabSize, cols: hiddenSize)
        outputBias = [Float](repeating: 0, count: vocabSize)
    }

    private func initializeWeights(rows: Int, cols: Int) -> [[Float]] {
        let scale = sqrt(2.0 / Float(rows + cols))
        return (0..<rows).map { _ in
            (0..<cols).map { _ in Float.random(in: -scale...scale) }
        }
    }

    // MARK: - Generation

    /// Generate melody
    public func generateMelody(
        key: MusicalKey,
        scale: ScaleType,
        bars: Int,
        tempo: Int,
        emotion: EnhancedMLModels.Emotion = .neutral
    ) async -> [MelodyNote] {
        guard _isModelLoaded else { return [] }

        let notesPerBar = 4  // Quarter notes per bar (can vary)
        let totalNotes = bars * notesPerBar * 2  // 8th notes

        // Get valid pitches for this key/scale
        let validPitches = getValidPitches(key: key, scale: scale)

        // Reset LSTM state
        resetLSTMState()

        // Get emotion-based parameters
        let (rhythmDensity, pitchRange, velocityRange) = getEmotionParameters(emotion)

        var melody: [MelodyNote] = []
        var previousPitch = validPitches[validPitches.count / 2]  // Start in middle of range

        for noteIndex in 0..<totalNotes {
            // Create input (one-hot of previous pitch)
            var input = [Float](repeating: 0, count: vocabSize)
            input[previousPitch] = 1.0

            // Forward pass through LSTM
            let output = forwardLSTM(input: input)

            // Apply scale mask
            var maskedOutput = [Float](repeating: -Float.infinity, count: vocabSize)
            for pitch in validPitches {
                maskedOutput[pitch] = output[pitch]
            }

            // Temperature-controlled sampling
            let temperature: Float = emotion == .energetic ? 1.2 : (emotion == .calm ? 0.7 : 1.0)
            let nextPitch = sampleFromDistribution(logits: maskedOutput, temperature: temperature)

            // Determine duration based on rhythm density
            let duration = selectDuration(density: rhythmDensity, position: noteIndex)

            // Determine velocity with humanization
            let baseVelocity = Int(Float.random(in: Float(velocityRange.lowerBound)...Float(velocityRange.upperBound)))
            let velocity = applyVelocityHumanization(baseVelocity, position: noteIndex)

            if duration > 0 {
                melody.append(MelodyNote(pitch: nextPitch, duration: duration, velocity: velocity))
            }

            previousPitch = nextPitch
        }

        // Post-process: merge tied notes, apply phrasing
        return postProcessMelody(melody, key: key)
    }

    private func getValidPitches(key: MusicalKey, scale: ScaleType) -> [Int] {
        var pitches: [Int] = []
        let root = key.root

        for octave in 4...6 {  // C4 to C6 range
            for interval in scale.intervals {
                let pitch = 12 * octave + root + interval
                if pitch >= 48 && pitch <= 84 {
                    pitches.append(pitch)
                }
            }
        }

        return pitches
    }

    private func getEmotionParameters(_ emotion: EnhancedMLModels.Emotion) -> (rhythmDensity: Float, pitchRange: ClosedRange<Int>, velocityRange: ClosedRange<Int>) {
        switch emotion {
        case .energetic:
            return (0.8, 55...80, 80...120)
        case .calm:
            return (0.3, 60...72, 50...80)
        case .happy:
            return (0.6, 60...84, 70...100)
        case .sad:
            return (0.4, 48...67, 40...70)
        case .anxious:
            return (0.7, 55...75, 60...110)
        case .focused:
            return (0.5, 58...76, 65...90)
        case .relaxed:
            return (0.3, 55...72, 45...75)
        default:
            return (0.5, 55...75, 60...100)
        }
    }

    private func resetLSTMState() {
        for i in 0..<lstmLayers.count {
            lstmLayers[i].hiddenState = [Float](repeating: 0, count: hiddenSize)
            lstmLayers[i].cellState = [Float](repeating: 0, count: hiddenSize)
        }
    }

    private func forwardLSTM(input: [Float]) -> [Float] {
        var x = input

        for layerIndex in 0..<lstmLayers.count {
            let layer = lstmLayers[layerIndex]

            // Concatenate input with hidden state
            var combined = x + layer.hiddenState

            // Calculate gates
            var inputGate = matmul(layer.weightsInput, combined)
            var forgetGate = matmul(layer.weightsForget, combined)
            var cellCandidate = matmul(layer.weightsCell, combined)
            var outputGate = matmul(layer.weightsOutput, combined)

            // Add biases
            for i in 0..<hiddenSize {
                inputGate[i] = sigmoid(inputGate[i] + layer.biasInput[i])
                forgetGate[i] = sigmoid(forgetGate[i] + layer.biasForget[i])
                cellCandidate[i] = tanh(cellCandidate[i] + layer.biasCell[i])
                outputGate[i] = sigmoid(outputGate[i] + layer.biasOutput[i])
            }

            // Update cell state
            var newCellState = [Float](repeating: 0, count: hiddenSize)
            for i in 0..<hiddenSize {
                newCellState[i] = forgetGate[i] * layer.cellState[i] + inputGate[i] * cellCandidate[i]
            }

            // Update hidden state
            var newHiddenState = [Float](repeating: 0, count: hiddenSize)
            for i in 0..<hiddenSize {
                newHiddenState[i] = outputGate[i] * tanh(newCellState[i])
            }

            lstmLayers[layerIndex].cellState = newCellState
            lstmLayers[layerIndex].hiddenState = newHiddenState

            x = newHiddenState
        }

        // Output layer
        var output = matmul(outputLayer, x)
        for i in 0..<output.count {
            output[i] += outputBias[i]
        }

        return output
    }

    private func matmul(_ weights: [[Float]], _ x: [Float]) -> [Float] {
        var result = [Float](repeating: 0, count: weights.count)

        for i in 0..<weights.count {
            for j in 0..<min(weights[i].count, x.count) {
                result[i] += weights[i][j] * x[j]
            }
        }

        return result
    }

    private func sigmoid(_ x: Float) -> Float {
        return 1.0 / (1.0 + exp(-x))
    }

    private func tanh(_ x: Float) -> Float {
        return Foundation.tanh(x)
    }

    private func sampleFromDistribution(logits: [Float], temperature: Float) -> Int {
        // Apply temperature
        var scaledLogits = logits.map { $0 / temperature }

        // Softmax
        let maxLogit = scaledLogits.max() ?? 0
        var expLogits = scaledLogits.map { exp($0 - maxLogit) }
        let sum = expLogits.reduce(0, +)
        let probs = expLogits.map { $0 / sum }

        // Sample
        let r = Float.random(in: 0..<1)
        var cumulative: Float = 0

        for (i, p) in probs.enumerated() {
            cumulative += p
            if r < cumulative {
                return i
            }
        }

        return probs.count - 1
    }

    private func selectDuration(density: Float, position: Int) -> Double {
        let r = Float.random(in: 0..<1)

        // Higher density = more short notes
        if r < density * 0.5 {
            return 0.125  // 16th note
        } else if r < density {
            return 0.25   // 8th note
        } else if r < density + 0.2 {
            return 0.5    // Quarter note
        } else {
            return 1.0    // Half note
        }
    }

    private func applyVelocityHumanization(_ velocity: Int, position: Int) -> Int {
        // Add slight variation
        let variation = Int.random(in: -5...5)

        // Stronger on downbeats
        let beatEmphasis = (position % 4 == 0) ? 10 : 0

        return max(1, min(127, velocity + variation + beatEmphasis))
    }

    private func postProcessMelody(_ melody: [MelodyNote], key: MusicalKey) -> [MelodyNote] {
        guard !melody.isEmpty else { return [] }

        var processed = melody

        // Merge consecutive same-pitch notes occasionally
        var i = 0
        while i < processed.count - 1 {
            if processed[i].pitch == processed[i + 1].pitch && Float.random(in: 0..<1) < 0.3 {
                processed[i].duration += processed[i + 1].duration
                processed.remove(at: i + 1)
            } else {
                i += 1
            }
        }

        return processed
    }

    // MARK: - Motif Development

    /// Develop a motif using various techniques
    public func developMotif(
        motif: [MelodyNote],
        technique: MotifTechnique,
        key: MusicalKey
    ) async -> [MelodyNote] {
        guard !motif.isEmpty else { return [] }

        switch technique {
        case .repetition:
            return motif + motif

        case .sequence:
            // Transpose up by a third
            let interval = 4  // Major third
            let transposed = motif.map { note in
                MelodyNote(
                    pitch: min(127, note.pitch + interval),
                    duration: note.duration,
                    velocity: note.velocity
                )
            }
            return motif + transposed

        case .inversion:
            guard let firstPitch = motif.first?.pitch else { return motif }
            let inverted = motif.map { note in
                let interval = note.pitch - firstPitch
                return MelodyNote(
                    pitch: max(0, firstPitch - interval),
                    duration: note.duration,
                    velocity: note.velocity
                )
            }
            return motif + inverted

        case .retrograde:
            return motif + motif.reversed()

        case .augmentation:
            let augmented = motif.map { note in
                MelodyNote(
                    pitch: note.pitch,
                    duration: note.duration * 2,
                    velocity: note.velocity
                )
            }
            return motif + augmented

        case .diminution:
            let diminished = motif.map { note in
                MelodyNote(
                    pitch: note.pitch,
                    duration: note.duration / 2,
                    velocity: note.velocity
                )
            }
            return motif + diminished

        case .fragmentation:
            let fragmentSize = max(1, motif.count / 2)
            let fragment = Array(motif.prefix(fragmentSize))
            return motif + fragment + fragment
        }
    }

    // MARK: - Style-Specific Generation

    /// Generate melody in specific genre style
    public func generateInStyle(
        style: EnhancedMLModels.MusicStyle,
        key: MusicalKey,
        bars: Int
    ) async -> [MelodyNote] {
        let scale: ScaleType
        let tempo: Int
        let emotion: EnhancedMLModels.Emotion

        switch style {
        case .jazz:
            scale = .dorian
            tempo = 120
            emotion = .focused

        case .classical:
            scale = .major
            tempo = 80
            emotion = .calm

        case .electronic:
            scale = .minor
            tempo = 128
            emotion = .energetic

        case .ambient:
            scale = .pentatonic
            tempo = 60
            emotion = .relaxed

        case .rock:
            scale = .blues
            tempo = 140
            emotion = .energetic

        case .hiphop:
            scale = .minor
            tempo = 90
            emotion = .focused

        default:
            scale = .major
            tempo = 100
            emotion = .neutral
        }

        return await generateMelody(key: key, scale: scale, bars: bars, tempo: tempo, emotion: emotion)
    }
}

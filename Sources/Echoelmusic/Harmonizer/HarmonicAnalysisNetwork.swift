import Foundation
import Accelerate
#if canImport(CoreML)
import CoreML
#endif

// MARK: - Harmonic Analysis Neural Network
// Deep learning approach to harmonic analysis based on:
// - Transformer architecture for sequence modeling
// - Roman numeral analysis (Tymoczko 2011)
// - Schenkerian reduction principles (Schenker 1935)
// - Neo-Riemannian theory (Cohn 1998)

/// Neural network for harmonic analysis
@MainActor
public final class HarmonicAnalysisNetwork: ObservableObject {
    public static let shared = HarmonicAnalysisNetwork()

    @Published public private(set) var isAnalyzing = false
    @Published public private(set) var lastAnalysis: DeepHarmonicAnalysis?

    // Network parameters (pre-trained weights simulation)
    private var embeddingWeights: [[Float]]
    private var attentionWeights: AttentionWeights
    private var feedForwardWeights: FeedForwardWeights
    private var outputWeights: [[Float]]

    // Model dimensions
    private let embeddingDim = 64
    private let numHeads = 4
    private let ffDim = 256
    private let vocabSize = 144 // 12 pitch classes * 12 chord qualities

    public init() {
        // Initialize with pseudo-random weights (would be loaded from trained model)
        self.embeddingWeights = Self.initializeEmbeddings(vocabSize: 144, dim: 64)
        self.attentionWeights = AttentionWeights(dim: 64, numHeads: 4)
        self.feedForwardWeights = FeedForwardWeights(inputDim: 64, hiddenDim: 256)
        self.outputWeights = Self.initializeOutputLayer(inputDim: 64, outputDim: 24)
    }

    // MARK: - Analysis Entry Point

    /// Perform deep harmonic analysis on a chord sequence
    public func analyze(chords: [AnalyzableChord], key: MusicalKey) async -> DeepHarmonicAnalysis {
        isAnalyzing = true
        defer { isAnalyzing = false }

        // Convert chords to embeddings
        let embeddings = chords.map { chord in
            embedChord(chord)
        }

        // Apply transformer layers
        let contextualEmbeddings = applyTransformerEncoder(embeddings)

        // Decode to Roman numerals
        let romanNumerals = decodeRomanNumerals(contextualEmbeddings, key: key)

        // Detect cadences
        let cadences = detectCadences(chords: chords, romans: romanNumerals, key: key)

        // Perform Schenkerian reduction
        let reduction = performSchenkerianReduction(chords: chords, romans: romanNumerals)

        // Neo-Riemannian analysis
        let neoRiemannian = analyzeNeoRiemannianTransformations(chords: chords)

        // Tension analysis
        let tensionCurve = analyzeTensionCurve(chords: chords, romans: romanNumerals)

        // Build analysis result
        let analysis = DeepHarmonicAnalysis(
            romanNumerals: romanNumerals,
            cadences: cadences,
            schenkerianLevels: reduction,
            neoRiemannianTransformations: neoRiemannian,
            tensionCurve: tensionCurve,
            modulationPoints: detectModulations(romans: romanNumerals),
            harmonicRhythm: analyzeHarmonicRhythm(chords: chords),
            confidence: calculateConfidence(embeddings: contextualEmbeddings)
        )

        lastAnalysis = analysis
        return analysis
    }

    // MARK: - Embedding Layer

    private func embedChord(_ chord: AnalyzableChord) -> [Float] {
        // Chord to index mapping
        let rootIndex = chord.root % 12
        let qualityIndex = chord.quality.rawValue
        let chordIndex = rootIndex * 12 + qualityIndex

        // Get base embedding
        var embedding = embeddingWeights[min(chordIndex, embeddingWeights.count - 1)]

        // Add positional encoding (sinusoidal)
        for i in 0..<embedding.count {
            let pos = Float(chord.position)
            if i % 2 == 0 {
                embedding[i] += sin(pos / pow(10000, Float(i) / Float(embeddingDim)))
            } else {
                embedding[i] += cos(pos / pow(10000, Float(i-1) / Float(embeddingDim)))
            }
        }

        // Add bass note information
        if let bass = chord.bassNote {
            let bassOffset = (bass - chord.root + 12) % 12
            for i in 0..<min(12, embedding.count) {
                embedding[i] += Float(i == bassOffset ? 0.5 : 0)
            }
        }

        return embedding
    }

    // MARK: - Transformer Encoder

    private func applyTransformerEncoder(_ embeddings: [[Float]]) -> [[Float]] {
        var output = embeddings

        // Self-attention
        output = multiHeadAttention(output)

        // Add & Norm
        output = layerNorm(addResidual(embeddings, output))

        // Feed-forward
        let ffOutput = feedForward(output)

        // Add & Norm
        output = layerNorm(addResidual(output, ffOutput))

        return output
    }

    private func multiHeadAttention(_ x: [[Float]]) -> [[Float]] {
        let seqLen = x.count
        guard seqLen > 0 else { return x }

        let headDim = embeddingDim / numHeads
        var output = Array(repeating: [Float](repeating: 0, count: embeddingDim), count: seqLen)

        for head in 0..<numHeads {
            // Compute Q, K, V for this head
            var queries = [[Float]]()
            var keys = [[Float]]()
            var values = [[Float]]()

            for i in 0..<seqLen {
                let startIdx = head * headDim
                let endIdx = startIdx + headDim
                let slice = Array(x[i][startIdx..<min(endIdx, x[i].count)])
                queries.append(linearTransform(slice, weights: attentionWeights.wQ[head]))
                keys.append(linearTransform(slice, weights: attentionWeights.wK[head]))
                values.append(linearTransform(slice, weights: attentionWeights.wV[head]))
            }

            // Compute attention scores
            let scores = computeAttentionScores(queries: queries, keys: keys)

            // Apply softmax and compute weighted values
            let attended = applyAttention(scores: scores, values: values)

            // Add to output
            for i in 0..<seqLen {
                let startIdx = head * headDim
                for j in 0..<attended[i].count {
                    if startIdx + j < output[i].count {
                        output[i][startIdx + j] += attended[i][j]
                    }
                }
            }
        }

        return output
    }

    private func computeAttentionScores(queries: [[Float]], keys: [[Float]]) -> [[Float]] {
        let seqLen = queries.count
        var scores = Array(repeating: [Float](repeating: 0, count: seqLen), count: seqLen)

        let scale = 1.0 / sqrt(Float(queries[0].count))

        for i in 0..<seqLen {
            for j in 0..<seqLen {
                var dot: Float = 0
                for k in 0..<queries[i].count {
                    dot += queries[i][k] * keys[j][k]
                }
                scores[i][j] = dot * scale
            }
        }

        // Softmax per row
        for i in 0..<seqLen {
            let maxVal = scores[i].max() ?? 0
            var expSum: Float = 0
            for j in 0..<seqLen {
                scores[i][j] = exp(scores[i][j] - maxVal)
                expSum += scores[i][j]
            }
            for j in 0..<seqLen {
                scores[i][j] /= expSum
            }
        }

        return scores
    }

    private func applyAttention(scores: [[Float]], values: [[Float]]) -> [[Float]] {
        let seqLen = scores.count
        guard seqLen > 0, !values.isEmpty else { return values }

        var output = Array(repeating: [Float](repeating: 0, count: values[0].count), count: seqLen)

        for i in 0..<seqLen {
            for j in 0..<seqLen {
                for k in 0..<values[j].count {
                    output[i][k] += scores[i][j] * values[j][k]
                }
            }
        }

        return output
    }

    private func feedForward(_ x: [[Float]]) -> [[Float]] {
        return x.map { vec in
            // First linear layer + ReLU
            var hidden = linearTransform(vec, weights: feedForwardWeights.w1)
            hidden = hidden.map { max(0, $0) } // ReLU

            // Second linear layer
            return linearTransform(hidden, weights: feedForwardWeights.w2)
        }
    }

    private func linearTransform(_ x: [Float], weights: [[Float]]) -> [Float] {
        guard !weights.isEmpty else { return x }
        let outputDim = weights.count
        var result = [Float](repeating: 0, count: outputDim)

        for i in 0..<outputDim {
            for j in 0..<min(x.count, weights[i].count) {
                result[i] += x[j] * weights[i][j]
            }
        }

        return result
    }

    private func layerNorm(_ x: [[Float]]) -> [[Float]] {
        return x.map { vec in
            let mean = vec.reduce(0, +) / Float(vec.count)
            let variance = vec.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Float(vec.count)
            let std = sqrt(variance + 1e-6)
            return vec.map { ($0 - mean) / std }
        }
    }

    private func addResidual(_ a: [[Float]], _ b: [[Float]]) -> [[Float]] {
        return zip(a, b).map { (vecA, vecB) in
            zip(vecA, vecB).map { $0 + $1 }
        }
    }

    // MARK: - Output Decoding

    private func decodeRomanNumerals(_ embeddings: [[Float]], key: MusicalKey) -> [RomanNumeral] {
        return embeddings.enumerated().map { (index, emb) in
            // Project to Roman numeral space
            let logits = linearTransform(emb, weights: outputWeights)

            // Softmax
            let maxLogit = logits.max() ?? 0
            var probs = logits.map { exp($0 - maxLogit) }
            let sum = probs.reduce(0, +)
            probs = probs.map { $0 / sum }

            // Get top prediction
            let bestIdx = probs.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0

            return indexToRomanNumeral(bestIdx, key: key, position: index)
        }
    }

    private func indexToRomanNumeral(_ index: Int, key: MusicalKey, position: Int) -> RomanNumeral {
        // Index mapping: 0-6 diatonic, 7-13 secondary dominants, 14-20 borrowed, 21-23 special
        let degree: Int
        let quality: RomanNumeralQuality
        let isSecondary: Bool

        switch index {
        case 0: (degree, quality, isSecondary) = (1, .major, false)
        case 1: (degree, quality, isSecondary) = (2, .minor, false)
        case 2: (degree, quality, isSecondary) = (3, .minor, false)
        case 3: (degree, quality, isSecondary) = (4, .major, false)
        case 4: (degree, quality, isSecondary) = (5, .major, false)
        case 5: (degree, quality, isSecondary) = (6, .minor, false)
        case 6: (degree, quality, isSecondary) = (7, .diminished, false)
        case 7...13:
            degree = (index - 7) + 2
            quality = .major
            isSecondary = true
        case 14: (degree, quality, isSecondary) = (4, .minor, false) // iv borrowed
        case 15: (degree, quality, isSecondary) = (7, .major, false) // bVII borrowed
        case 16: (degree, quality, isSecondary) = (6, .major, false) // bVI borrowed
        case 17: (degree, quality, isSecondary) = (3, .major, false) // bIII borrowed
        case 18: (degree, quality, isSecondary) = (2, .major, false) // II (Neapolitan)
        case 19: (degree, quality, isSecondary) = (4, .major, false) // IV+ (augmented)
        case 20: (degree, quality, isSecondary) = (5, .augmented, false)
        case 21: (degree, quality, isSecondary) = (2, .halfDiminished, false) // iiø
        case 22: (degree, quality, isSecondary) = (7, .halfDiminished, false) // viiø
        case 23: (degree, quality, isSecondary) = (5, .dominant7, false) // V7
        default: (degree, quality, isSecondary) = (1, .major, false)
        }

        return RomanNumeral(
            degree: degree,
            quality: quality,
            isSecondary: isSecondary,
            secondaryTarget: isSecondary ? (degree + 1) % 7 + 1 : nil,
            inversion: 0,
            position: position
        )
    }

    // MARK: - Cadence Detection

    private func detectCadences(
        chords: [AnalyzableChord],
        romans: [RomanNumeral],
        key: MusicalKey
    ) -> [Cadence] {
        var cadences: [Cadence] = []

        for i in 1..<romans.count {
            let prev = romans[i - 1]
            let curr = romans[i]

            // Authentic cadence: V-I
            if prev.degree == 5 && curr.degree == 1 {
                let isPerfect = curr.inversion == 0 &&
                                prev.quality == .major || prev.quality == .dominant7
                cadences.append(Cadence(
                    type: isPerfect ? .perfectAuthentic : .imperfectAuthentic,
                    position: i,
                    strength: isPerfect ? 1.0 : 0.8
                ))
            }

            // Half cadence: X-V
            if curr.degree == 5 && prev.degree != 5 {
                cadences.append(Cadence(
                    type: .half,
                    position: i,
                    strength: 0.7
                ))
            }

            // Plagal cadence: IV-I
            if prev.degree == 4 && curr.degree == 1 {
                cadences.append(Cadence(
                    type: .plagal,
                    position: i,
                    strength: 0.6
                ))
            }

            // Deceptive cadence: V-vi
            if prev.degree == 5 && curr.degree == 6 {
                cadences.append(Cadence(
                    type: .deceptive,
                    position: i,
                    strength: 0.75
                ))
            }

            // Phrygian half cadence: iv6-V (in minor)
            if prev.degree == 4 && prev.quality == .minor &&
               prev.inversion == 1 && curr.degree == 5 {
                cadences.append(Cadence(
                    type: .phrygianHalf,
                    position: i,
                    strength: 0.65
                ))
            }
        }

        return cadences
    }

    // MARK: - Schenkerian Reduction

    private func performSchenkerianReduction(
        chords: [AnalyzableChord],
        romans: [RomanNumeral]
    ) -> SchenkerianReduction {
        // Foreground: all chords
        let foreground = romans

        // Middleground: structural harmonies (I, IV, V, vi)
        let middleground = romans.filter { r in
            [1, 4, 5, 6].contains(r.degree)
        }

        // Background: fundamental structure (I-V-I Ursatz)
        var background: [RomanNumeral] = []

        // Find first I
        if let firstTonic = romans.first(where: { $0.degree == 1 }) {
            background.append(firstTonic)
        }

        // Find structural dominant
        if let dominant = romans.last(where: { $0.degree == 5 }) {
            background.append(dominant)
        }

        // Find final I
        if let finalTonic = romans.reversed().first(where: { $0.degree == 1 }) {
            if background.last?.degree != 1 {
                background.append(finalTonic)
            }
        }

        // Prolongations
        var prolongations: [Prolongation] = []

        var currentProlongedChord: RomanNumeral?
        var prolongationStart = 0

        for (i, roman) in romans.enumerated() {
            if [1, 4, 5].contains(roman.degree) {
                if let prolonged = currentProlongedChord, i > prolongationStart + 1 {
                    prolongations.append(Prolongation(
                        chord: prolonged,
                        startPosition: prolongationStart,
                        endPosition: i - 1,
                        type: .arpeggiation
                    ))
                }
                currentProlongedChord = roman
                prolongationStart = i
            }
        }

        return SchenkerianReduction(
            foreground: foreground,
            middleground: middleground,
            background: background,
            prolongations: prolongations
        )
    }

    // MARK: - Neo-Riemannian Analysis

    private func analyzeNeoRiemannianTransformations(
        chords: [AnalyzableChord]
    ) -> [NeoRiemannianTransformation] {
        var transformations: [NeoRiemannianTransformation] = []

        for i in 1..<chords.count {
            let prev = chords[i - 1]
            let curr = chords[i]

            if let transform = detectNeoRiemannianTransform(from: prev, to: curr) {
                transformations.append(NeoRiemannianTransformation(
                    type: transform,
                    fromPosition: i - 1,
                    toPosition: i,
                    fromChord: prev,
                    toChord: curr
                ))
            }
        }

        return transformations
    }

    private func detectNeoRiemannianTransform(
        from a: AnalyzableChord,
        to b: AnalyzableChord
    ) -> NeoRiemannianType? {
        let rootInterval = (b.root - a.root + 12) % 12
        let aIsMajor = a.quality == .major || a.quality == .dominant7 || a.quality == .major7
        let bIsMajor = b.quality == .major || b.quality == .dominant7 || b.quality == .major7

        // P (Parallel): same root, quality change
        if rootInterval == 0 && aIsMajor != bIsMajor {
            return .parallel
        }

        // R (Relative): major up m3, minor down m3
        if (aIsMajor && rootInterval == 9 && !bIsMajor) ||
           (!aIsMajor && rootInterval == 3 && bIsMajor) {
            return .relative
        }

        // L (Leading-tone exchange)
        if (aIsMajor && rootInterval == 4 && !bIsMajor) ||
           (!aIsMajor && rootInterval == 8 && bIsMajor) {
            return .leadingTone
        }

        // Compound transformations
        // PR
        if (aIsMajor && rootInterval == 9 && bIsMajor) ||
           (!aIsMajor && rootInterval == 3 && !bIsMajor) {
            return .parallelRelative
        }

        // LP
        if (aIsMajor && rootInterval == 4 && bIsMajor) ||
           (!aIsMajor && rootInterval == 8 && !bIsMajor) {
            return .leadingToneParallel
        }

        // RL
        if rootInterval == 1 || rootInterval == 11 {
            return .relativeLeadingTone
        }

        return nil
    }

    // MARK: - Tension Analysis

    private func analyzeTensionCurve(
        chords: [AnalyzableChord],
        romans: [RomanNumeral]
    ) -> [TensionPoint] {
        return romans.enumerated().map { (i, roman) in
            var tension: Float = 0

            // Base tension by function
            switch roman.degree {
            case 1: tension = 0.1  // Tonic - lowest tension
            case 5: tension = 0.7  // Dominant - high tension
            case 4: tension = 0.4  // Subdominant - moderate
            case 2: tension = 0.5  // Supertonic
            case 6: tension = 0.3  // Submediant
            case 3: tension = 0.35 // Mediant
            case 7: tension = 0.85 // Leading tone - highest
            default: tension = 0.5
            }

            // Modifier for quality
            if roman.quality == .dominant7 { tension += 0.15 }
            if roman.quality == .diminished { tension += 0.2 }
            if roman.quality == .augmented { tension += 0.25 }

            // Modifier for secondary dominants
            if roman.isSecondary { tension += 0.1 }

            // Inversion affects stability
            if roman.inversion > 0 { tension += 0.05 * Float(roman.inversion) }

            // Context: approaching cadence increases tension
            if i > 0 && romans[i - 1].degree == 5 && roman.degree == 1 {
                tension = max(0, tension - 0.5) // Resolution
            }

            return TensionPoint(
                position: i,
                tension: min(1.0, tension),
                roman: roman
            )
        }
    }

    // MARK: - Modulation Detection

    private func detectModulations(romans: [RomanNumeral]) -> [ModulationPoint] {
        var modulations: [ModulationPoint] = []

        // Look for pivot chord patterns
        for i in 2..<romans.count {
            // Common pivot pattern: ii-V-I in new key
            if romans[i].degree == 1 &&
               romans[i - 1].degree == 5 &&
               romans[i - 2].degree == 2 {

                // Check if this looks like a new key area
                if i > 3 {
                    let prevTonics = romans[0..<(i-2)].filter { $0.degree == 1 }.count
                    if prevTonics > 0 {
                        modulations.append(ModulationPoint(
                            position: i - 2,
                            pivotChord: romans[i - 2],
                            type: .pivot,
                            confidence: 0.7
                        ))
                    }
                }
            }

            // Secondary dominant as pivot
            if romans[i - 1].isSecondary && romans[i].degree == romans[i - 1].secondaryTarget {
                modulations.append(ModulationPoint(
                    position: i - 1,
                    pivotChord: romans[i - 1],
                    type: .secondaryDominant,
                    confidence: 0.6
                ))
            }
        }

        return modulations
    }

    // MARK: - Harmonic Rhythm Analysis

    private func analyzeHarmonicRhythm(chords: [AnalyzableChord]) -> HarmonicRhythm {
        guard chords.count > 1 else {
            return HarmonicRhythm(
                averageRate: 1.0,
                variability: 0,
                patterns: []
            )
        }

        // Calculate chord durations
        var durations: [Double] = []
        for i in 1..<chords.count {
            let duration = Double(chords[i].position - chords[i - 1].position)
            durations.append(max(1, duration))
        }

        let avgRate = durations.reduce(0, +) / Double(durations.count)
        let variance = durations.map { ($0 - avgRate) * ($0 - avgRate) }.reduce(0, +) / Double(durations.count)

        // Detect patterns
        var patterns: [HarmonicRhythmPattern] = []

        // Check for regular rhythm
        if variance < 0.1 {
            patterns.append(.regular)
        }

        // Check for accelerating rhythm
        if durations.count > 3 {
            let firstHalf = durations.prefix(durations.count / 2).reduce(0, +) / Double(durations.count / 2)
            let secondHalf = durations.suffix(durations.count / 2).reduce(0, +) / Double(durations.count / 2)
            if secondHalf < firstHalf * 0.8 {
                patterns.append(.accelerating)
            } else if secondHalf > firstHalf * 1.2 {
                patterns.append(.decelerating)
            }
        }

        return HarmonicRhythm(
            averageRate: avgRate,
            variability: sqrt(variance),
            patterns: patterns
        )
    }

    private func calculateConfidence(embeddings: [[Float]]) -> Double {
        // Average embedding norm as confidence proxy
        let norms = embeddings.map { emb in
            sqrt(emb.map { $0 * $0 }.reduce(0, +))
        }
        let avgNorm = norms.reduce(0, +) / Float(norms.count)
        return Double(min(1.0, avgNorm / 10.0))
    }

    // MARK: - Weight Initialization

    private static func initializeEmbeddings(vocabSize: Int, dim: Int) -> [[Float]] {
        (0..<vocabSize).map { _ in
            (0..<dim).map { _ in Float.random(in: -0.1...0.1) }
        }
    }

    private static func initializeOutputLayer(inputDim: Int, outputDim: Int) -> [[Float]] {
        (0..<outputDim).map { _ in
            (0..<inputDim).map { _ in Float.random(in: -0.1...0.1) }
        }
    }
}

// MARK: - Supporting Types

public struct AnalyzableChord {
    public let root: Int
    public let quality: ChordQuality
    public let bassNote: Int?
    public let position: Int

    public init(root: Int, quality: ChordQuality, bassNote: Int? = nil, position: Int = 0) {
        self.root = root
        self.quality = quality
        self.bassNote = bassNote
        self.position = position
    }
}

public struct MusicalKey {
    public let tonic: Int
    public let mode: KeyMode

    public enum KeyMode {
        case major, minor
        case dorian, phrygian, lydian, mixolydian, aeolian, locrian
    }

    public init(tonic: Int, mode: KeyMode = .major) {
        self.tonic = tonic
        self.mode = mode
    }

    public static let cMajor = MusicalKey(tonic: 0, mode: .major)
    public static let aMinor = MusicalKey(tonic: 9, mode: .minor)
}

public struct RomanNumeral {
    public let degree: Int
    public let quality: RomanNumeralQuality
    public let isSecondary: Bool
    public let secondaryTarget: Int?
    public let inversion: Int
    public let position: Int

    public var symbol: String {
        let base: String
        switch degree {
        case 1: base = quality.isMajor ? "I" : "i"
        case 2: base = quality.isMajor ? "II" : "ii"
        case 3: base = quality.isMajor ? "III" : "iii"
        case 4: base = quality.isMajor ? "IV" : "iv"
        case 5: base = quality.isMajor ? "V" : "v"
        case 6: base = quality.isMajor ? "VI" : "vi"
        case 7: base = quality.isMajor ? "VII" : "vii"
        default: base = "?"
        }

        var suffix = ""
        if quality == .diminished { suffix = "°" }
        if quality == .halfDiminished { suffix = "ø" }
        if quality == .augmented { suffix = "+" }
        if quality == .dominant7 { suffix = "7" }

        if isSecondary, let target = secondaryTarget {
            let targetSymbol: String
            switch target {
            case 1: targetSymbol = "I"
            case 2: targetSymbol = "ii"
            case 3: targetSymbol = "iii"
            case 4: targetSymbol = "IV"
            case 5: targetSymbol = "V"
            case 6: targetSymbol = "vi"
            case 7: targetSymbol = "vii"
            default: targetSymbol = "?"
            }
            return "V\(suffix)/\(targetSymbol)"
        }

        return base + suffix
    }
}

public enum RomanNumeralQuality {
    case major, minor, diminished, augmented, halfDiminished, dominant7

    var isMajor: Bool {
        self == .major || self == .augmented || self == .dominant7
    }
}

public struct Cadence {
    public let type: CadenceType
    public let position: Int
    public let strength: Double

    public enum CadenceType: String {
        case perfectAuthentic = "PAC"
        case imperfectAuthentic = "IAC"
        case half = "HC"
        case plagal = "PC"
        case deceptive = "DC"
        case phrygianHalf = "Phrygian HC"
    }
}

public struct SchenkerianReduction {
    public let foreground: [RomanNumeral]
    public let middleground: [RomanNumeral]
    public let background: [RomanNumeral]
    public let prolongations: [Prolongation]
}

public struct Prolongation {
    public let chord: RomanNumeral
    public let startPosition: Int
    public let endPosition: Int
    public let type: ProlongationType

    public enum ProlongationType {
        case arpeggiation, passing, neighbor, pedal
    }
}

public struct NeoRiemannianTransformation {
    public let type: NeoRiemannianType
    public let fromPosition: Int
    public let toPosition: Int
    public let fromChord: AnalyzableChord
    public let toChord: AnalyzableChord
}

public enum NeoRiemannianType: String {
    case parallel = "P"
    case relative = "R"
    case leadingTone = "L"
    case parallelRelative = "PR"
    case leadingToneParallel = "LP"
    case relativeLeadingTone = "RL"
}

public struct TensionPoint {
    public let position: Int
    public let tension: Float
    public let roman: RomanNumeral
}

public struct ModulationPoint {
    public let position: Int
    public let pivotChord: RomanNumeral
    public let type: ModulationType
    public let confidence: Double

    public enum ModulationType {
        case pivot, direct, chromatic, enharmonic, secondaryDominant
    }
}

public struct HarmonicRhythm {
    public let averageRate: Double
    public let variability: Double
    public let patterns: [HarmonicRhythmPattern]
}

public enum HarmonicRhythmPattern {
    case regular, accelerating, decelerating, syncopated
}

public struct DeepHarmonicAnalysis {
    public let romanNumerals: [RomanNumeral]
    public let cadences: [Cadence]
    public let schenkerianLevels: SchenkerianReduction
    public let neoRiemannianTransformations: [NeoRiemannianTransformation]
    public let tensionCurve: [TensionPoint]
    public let modulationPoints: [ModulationPoint]
    public let harmonicRhythm: HarmonicRhythm
    public let confidence: Double

    public var summary: String {
        """
        Harmonic Analysis Summary:
        - \(romanNumerals.count) chords analyzed
        - \(cadences.count) cadences detected
        - \(modulationPoints.count) modulations
        - \(neoRiemannianTransformations.count) Neo-Riemannian transformations
        - Background structure: \(schenkerianLevels.background.map { $0.symbol }.joined(separator: "-"))
        - Confidence: \(String(format: "%.1f%%", confidence * 100))
        """
    }
}

// MARK: - Weight Structures

private struct AttentionWeights {
    let wQ: [[[Float]]]
    let wK: [[[Float]]]
    let wV: [[[Float]]]

    init(dim: Int, numHeads: Int) {
        let headDim = dim / numHeads
        wQ = (0..<numHeads).map { _ in
            (0..<headDim).map { _ in
                (0..<headDim).map { _ in Float.random(in: -0.1...0.1) }
            }
        }
        wK = (0..<numHeads).map { _ in
            (0..<headDim).map { _ in
                (0..<headDim).map { _ in Float.random(in: -0.1...0.1) }
            }
        }
        wV = (0..<numHeads).map { _ in
            (0..<headDim).map { _ in
                (0..<headDim).map { _ in Float.random(in: -0.1...0.1) }
            }
        }
    }
}

private struct FeedForwardWeights {
    let w1: [[Float]]
    let w2: [[Float]]

    init(inputDim: Int, hiddenDim: Int) {
        w1 = (0..<hiddenDim).map { _ in
            (0..<inputDim).map { _ in Float.random(in: -0.1...0.1) }
        }
        w2 = (0..<inputDim).map { _ in
            (0..<hiddenDim).map { _ in Float.random(in: -0.1...0.1) }
        }
    }
}

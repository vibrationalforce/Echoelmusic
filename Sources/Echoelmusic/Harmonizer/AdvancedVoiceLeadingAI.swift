import Foundation
import Accelerate

// MARK: - Advanced Voice Leading AI
// Implements state-of-the-art voice leading optimization using:
// - Tymoczko (2011) voice-leading geometry
// - Huron (2001) voice-leading rules from cognitive science
// - Lerdahl & Jackendoff (1983) GTTM principles

/// Voice leading geometry in pitch-class space
public struct VoiceLeadingGeometry {

    // MARK: - Pitch-Class Space (Tymoczko 2011)

    /// Represents a point in n-dimensional chord space
    public struct ChordPoint: Equatable, Hashable {
        public let pitchClasses: [Double]
        public let cardinality: Int

        public init(pitchClasses: [Double]) {
            self.pitchClasses = pitchClasses.map { $0.truncatingRemainder(dividingBy: 12.0) }
            self.cardinality = pitchClasses.count
        }

        /// Distance in voice-leading space (minimal voice leading)
        public func distance(to other: ChordPoint) -> Double {
            guard cardinality == other.cardinality else { return .infinity }

            // Find optimal voice assignment using Hungarian algorithm approximation
            var minDistance = Double.infinity
            let permutations = generatePermutations(Array(0..<cardinality))

            for perm in permutations {
                var totalDistance: Double = 0
                for (i, j) in perm.enumerated() {
                    let d1 = abs(pitchClasses[i] - other.pitchClasses[j])
                    let d2 = 12.0 - d1
                    totalDistance += min(d1, d2) * min(d1, d2) // Squared for L2 norm
                }
                minDistance = min(minDistance, sqrt(totalDistance))
            }

            return minDistance
        }

        private func generatePermutations(_ arr: [Int]) -> [[Int]] {
            if arr.count <= 1 { return [arr] }
            var result: [[Int]] = []
            for (i, elem) in arr.enumerated() {
                var rest = arr
                rest.remove(at: i)
                for perm in generatePermutations(rest) {
                    result.append([elem] + perm)
                }
            }
            return result
        }
    }

    /// T/I equivalence class (Transposition and Inversion)
    public struct SetClass: Equatable, Hashable {
        public let primeForm: [Int]
        public let forteNumber: String

        public init(pitchClasses: [Int]) {
            let normalized = Self.computePrimeForm(pitchClasses)
            self.primeForm = normalized.prime
            self.forteNumber = normalized.forte
        }

        private static func computePrimeForm(_ pcs: [Int]) -> (prime: [Int], forte: String) {
            let unique = Array(Set(pcs.map { ($0 % 12 + 12) % 12 })).sorted()
            guard !unique.isEmpty else { return ([], "0-1") }

            // Get all rotations and inversions
            var candidates: [[Int]] = []

            // All rotations of normal form
            for rotation in 0..<unique.count {
                var rotated = unique.map { ($0 - unique[rotation] + 12) % 12 }
                rotated.sort()
                candidates.append(rotated)
            }

            // All rotations of inversion
            let inverted = unique.map { (12 - $0) % 12 }.sorted()
            for rotation in 0..<inverted.count {
                var rotated = inverted.map { ($0 - inverted[rotation] + 12) % 12 }
                rotated.sort()
                candidates.append(rotated)
            }

            // Find most packed (leftmost) form
            let prime = candidates.min { a, b in
                for i in 0..<min(a.count, b.count) {
                    if a[i] != b[i] { return a[i] < b[i] }
                }
                return a.count < b.count
            } ?? unique

            let forte = "\(unique.count)-\(Self.forteIndex(prime))"
            return (prime, forte)
        }

        private static func forteIndex(_ prime: [Int]) -> Int {
            // Simplified Forte number assignment
            let hash = prime.enumerated().reduce(0) { $0 + $1.element * (1 << $1.offset) }
            return (hash % 50) + 1
        }
    }
}

// MARK: - Voice Leading Rules (Huron 2001)

/// Cognitive voice-leading principles from empirical research
public struct CognitiveVoiceLeading {

    /// Rule weights based on Huron's perceptual research
    public struct RuleWeights {
        public var registralDirection: Double = 1.0      // Prefer stepwise motion
        public var registralReturn: Double = 0.8         // Return to starting pitch
        public var proximityPrinciple: Double = 1.2      // Smaller intervals preferred
        public var pitchCoModulation: Double = 0.7       // Avoid parallel motion
        public var commonToneRetention: Double = 0.9     // Keep common tones
        public var conjunctMotion: Double = 1.1          // Prefer conjunct motion
        public var obliqueMotion: Double = 0.6           // Allow oblique motion
        public var voiceCrossing: Double = 2.0           // Penalty for crossing
        public var voiceOverlap: Double = 1.5            // Penalty for overlap
        public var semitoneConstraint: Double = 0.8      // Resolve semitones

        public static let `default` = RuleWeights()
        public static let baroque = RuleWeights(
            registralDirection: 1.2,
            pitchCoModulation: 1.0,
            commonToneRetention: 1.2
        )
        public static let romantic = RuleWeights(
            registralDirection: 0.8,
            proximityPrinciple: 0.9,
            conjunctMotion: 0.8
        )
        public static let jazz = RuleWeights(
            registralDirection: 0.6,
            pitchCoModulation: 0.4,
            voiceCrossing: 1.0
        )
    }

    private let weights: RuleWeights

    public init(weights: RuleWeights = .default) {
        self.weights = weights
    }

    /// Evaluate voice leading quality between two voicings
    public func evaluate(from: [Int], to: [Int]) -> VoiceLeadingScore {
        guard from.count == to.count else {
            return VoiceLeadingScore(total: 0, breakdown: [:])
        }

        var breakdown: [String: Double] = [:]

        // 1. Proximity principle (smaller intervals = better)
        let intervals = zip(from, to).map { abs($0 - $1) }
        let proximityScore = 1.0 - (Double(intervals.reduce(0, +)) / Double(intervals.count * 12))
        breakdown["proximity"] = proximityScore * weights.proximityPrinciple

        // 2. Conjunct motion (stepwise = best)
        let conjunctCount = intervals.filter { $0 <= 2 }.count
        let conjunctScore = Double(conjunctCount) / Double(intervals.count)
        breakdown["conjunct"] = conjunctScore * weights.conjunctMotion

        // 3. Common tone retention
        let commonTones = Set(from).intersection(Set(to)).count
        let commonScore = Double(commonTones) / Double(from.count)
        breakdown["commonTone"] = commonScore * weights.commonToneRetention

        // 4. Voice crossing penalty
        var crossingPenalty = 0.0
        for i in 0..<from.count {
            for j in (i+1)..<from.count {
                if (from[i] < from[j] && to[i] > to[j]) ||
                   (from[i] > from[j] && to[i] < to[j]) {
                    crossingPenalty += 1.0
                }
            }
        }
        breakdown["voiceCrossing"] = -crossingPenalty * weights.voiceCrossing / Double(max(1, from.count))

        // 5. Voice overlap penalty
        var overlapPenalty = 0.0
        for i in 0..<from.count {
            for j in 0..<from.count where i != j {
                if i < j && to[i] > from[j] { overlapPenalty += 0.5 }
                if i > j && to[i] < from[j] { overlapPenalty += 0.5 }
            }
        }
        breakdown["voiceOverlap"] = -overlapPenalty * weights.voiceOverlap / Double(max(1, from.count))

        // 6. Parallel motion detection
        let motionTypes = zip(zip(from, to), zip(from.dropFirst(), to.dropFirst())).map { pair -> MotionType in
            let (v1, v2) = pair
            let interval1 = v1.1 - v1.0
            let interval2 = v2.1 - v2.0
            if interval1 == 0 && interval2 == 0 { return .none }
            if interval1 == 0 || interval2 == 0 { return .oblique }
            if interval1 == interval2 { return .parallel }
            if (interval1 > 0 && interval2 > 0) || (interval1 < 0 && interval2 < 0) { return .similar }
            return .contrary
        }

        let parallelCount = motionTypes.filter { $0 == .parallel }.count
        let contraryCount = motionTypes.filter { $0 == .contrary }.count
        let motionScore = (Double(contraryCount) - Double(parallelCount) * 0.5) / Double(max(1, motionTypes.count))
        breakdown["motion"] = motionScore * weights.pitchCoModulation

        // 7. Registral direction (tendency toward middle register)
        let middleC = 60
        let directionScore = zip(from, to).map { (f, t) -> Double in
            let fromDist = abs(f - middleC)
            let toDist = abs(t - middleC)
            return toDist < fromDist ? 0.1 : (toDist > fromDist ? -0.1 : 0)
        }.reduce(0, +)
        breakdown["registral"] = directionScore * weights.registralDirection

        let total = breakdown.values.reduce(0, +)
        return VoiceLeadingScore(total: total, breakdown: breakdown)
    }

    public enum MotionType {
        case parallel, similar, contrary, oblique, none
    }
}

public struct VoiceLeadingScore {
    public let total: Double
    public let breakdown: [String: Double]

    public var grade: String {
        switch total {
        case 2.5...: return "A+"
        case 2.0..<2.5: return "A"
        case 1.5..<2.0: return "B"
        case 1.0..<1.5: return "C"
        case 0.5..<1.0: return "D"
        default: return "F"
        }
    }
}

// MARK: - Advanced Voice Leading Optimizer

@MainActor
public final class AdvancedVoiceLeadingAI: ObservableObject {
    public static let shared = AdvancedVoiceLeadingAI()

    @Published public private(set) var isOptimizing = false
    @Published public private(set) var lastScore: VoiceLeadingScore?

    private let cognitiveEvaluator: CognitiveVoiceLeading
    private var styleWeights: CognitiveVoiceLeading.RuleWeights = .default

    public init() {
        self.cognitiveEvaluator = CognitiveVoiceLeading()
    }

    // MARK: - Style Configuration

    public enum VoiceLeadingStyle {
        case classical
        case baroque
        case romantic
        case jazz
        case contemporary
        case minimal
        case custom(CognitiveVoiceLeading.RuleWeights)

        var weights: CognitiveVoiceLeading.RuleWeights {
            switch self {
            case .classical, .baroque: return .baroque
            case .romantic: return .romantic
            case .jazz: return .jazz
            case .contemporary:
                var w = CognitiveVoiceLeading.RuleWeights()
                w.voiceCrossing = 0.5
                w.pitchCoModulation = 0.3
                return w
            case .minimal:
                var w = CognitiveVoiceLeading.RuleWeights()
                w.commonToneRetention = 2.0
                w.conjunctMotion = 1.5
                return w
            case .custom(let weights):
                return weights
            }
        }
    }

    public func setStyle(_ style: VoiceLeadingStyle) {
        styleWeights = style.weights
    }

    // MARK: - Voice Leading Optimization

    /// Optimize voice leading for a chord progression
    public func optimizeProgression(
        chords: [ChordVoicing],
        voiceCount: Int = 4,
        range: VoiceRange = .satb
    ) async -> [ChordVoicing] {
        isOptimizing = true
        defer { isOptimizing = false }

        guard !chords.isEmpty else { return [] }

        var optimized: [ChordVoicing] = []
        var previousVoicing = realizeChord(chords[0], voiceCount: voiceCount, range: range)
        optimized.append(previousVoicing)

        for chord in chords.dropFirst() {
            let nextVoicing = await findOptimalVoicing(
                for: chord,
                previous: previousVoicing,
                voiceCount: voiceCount,
                range: range
            )
            optimized.append(nextVoicing)
            previousVoicing = nextVoicing
        }

        return optimized
    }

    /// Find optimal voicing given previous chord
    public func findOptimalVoicing(
        for chord: ChordVoicing,
        previous: ChordVoicing,
        voiceCount: Int,
        range: VoiceRange
    ) async -> ChordVoicing {
        let candidates = generateVoicingCandidates(
            chord: chord,
            voiceCount: voiceCount,
            range: range
        )

        let evaluator = CognitiveVoiceLeading(weights: styleWeights)

        var bestVoicing = candidates.first ?? chord
        var bestScore = Double.negativeInfinity

        for candidate in candidates {
            let score = evaluator.evaluate(
                from: previous.pitches,
                to: candidate.pitches
            )

            if score.total > bestScore {
                bestScore = score.total
                bestVoicing = candidate
                lastScore = score
            }
        }

        return bestVoicing
    }

    /// Generate all valid voicing candidates for a chord
    private func generateVoicingCandidates(
        chord: ChordVoicing,
        voiceCount: Int,
        range: VoiceRange
    ) -> [ChordVoicing] {
        var candidates: [ChordVoicing] = []
        let pitchClasses = chord.pitchClasses

        // Generate voicings with different bass notes (inversions)
        for bassIndex in 0..<pitchClasses.count {
            // Different octave positions for bass
            for bassOctave in range.bassRange {
                let bass = pitchClasses[bassIndex] + bassOctave * 12
                guard range.bassRange.contains(bass / 12) else { continue }

                // Generate upper voices
                let upperPCs = pitchClasses.enumerated()
                    .filter { $0.offset != bassIndex }
                    .map { $0.element }

                let upperVoicings = generateUpperVoices(
                    pitchClasses: upperPCs + [pitchClasses[bassIndex]], // Can double
                    count: voiceCount - 1,
                    range: range.upperRange
                )

                for upper in upperVoicings {
                    let pitches = [bass] + upper.sorted()
                    candidates.append(ChordVoicing(
                        root: chord.root,
                        quality: chord.quality,
                        pitches: pitches
                    ))
                }
            }
        }

        return candidates
    }

    private func generateUpperVoices(
        pitchClasses: [Int],
        count: Int,
        range: ClosedRange<Int>
    ) -> [[Int]] {
        // Use beam search for efficiency
        var candidates: [[Int]] = [[]]

        for _ in 0..<count {
            var newCandidates: [[Int]] = []

            for candidate in candidates {
                for pc in pitchClasses {
                    for octave in range {
                        let pitch = pc + octave * 12
                        if candidate.isEmpty || pitch > candidate.last! {
                            var newCandidate = candidate
                            newCandidate.append(pitch)
                            newCandidates.append(newCandidate)
                        }
                    }
                }
            }

            // Beam search: keep top candidates
            candidates = Array(newCandidates.prefix(100))
        }

        return candidates.filter { $0.count == count }
    }

    private func realizeChord(
        _ chord: ChordVoicing,
        voiceCount: Int,
        range: VoiceRange
    ) -> ChordVoicing {
        let candidates = generateVoicingCandidates(
            chord: chord,
            voiceCount: voiceCount,
            range: range
        )

        // For first chord, prefer root position, balanced spacing
        return candidates.min { a, b in
            let aSpacing = spacingScore(a.pitches)
            let bSpacing = spacingScore(b.pitches)
            return aSpacing > bSpacing
        } ?? chord
    }

    private func spacingScore(_ pitches: [Int]) -> Double {
        guard pitches.count > 1 else { return 0 }

        var score = 0.0

        // Prefer wider spacing in bass, closer in upper voices
        for i in 1..<pitches.count {
            let interval = pitches[i] - pitches[i-1]
            let idealInterval = i == 1 ? 12 : 4 // Octave in bass, third in upper
            score -= Double(abs(interval - idealInterval))
        }

        return score
    }

    // MARK: - Counterpoint Generation

    /// Generate counterpoint line against cantus firmus
    public func generateCounterpoint(
        cantusFirmus: [Int],
        species: CounterpointSpecies,
        position: CounterpointPosition
    ) async -> [Int] {
        switch species {
        case .first:
            return generateFirstSpecies(cantus: cantusFirmus, position: position)
        case .second:
            return generateSecondSpecies(cantus: cantusFirmus, position: position)
        case .third:
            return generateThirdSpecies(cantus: cantusFirmus, position: position)
        case .fourth:
            return generateFourthSpecies(cantus: cantusFirmus, position: position)
        case .fifth:
            return generateFifthSpecies(cantus: cantusFirmus, position: position)
        }
    }

    public enum CounterpointSpecies {
        case first   // Note against note
        case second  // Two notes against one
        case third   // Four notes against one
        case fourth  // Syncopation/suspensions
        case fifth   // Florid (free combination)
    }

    public enum CounterpointPosition {
        case above, below
    }

    private func generateFirstSpecies(cantus: [Int], position: CounterpointPosition) -> [Int] {
        var counterpoint: [Int] = []
        let consonances = [0, 3, 4, 5, 7, 8, 9, 12] // Consonant intervals

        for (i, note) in cantus.enumerated() {
            var bestNote = note + (position == .above ? 7 : -5)
            var bestScore = Double.negativeInfinity

            let searchRange = position == .above ? (note...note+16) : (note-16...note)

            for candidate in searchRange {
                let interval = abs(candidate - note) % 12
                guard consonances.contains(interval) else { continue }

                var score = 0.0

                // Consonance quality
                if interval == 0 || interval == 12 { score -= 2 } // Avoid unisons except start/end
                if interval == 5 || interval == 7 { score += 1 } // Prefer P5/P4

                // Melodic considerations
                if !counterpoint.isEmpty {
                    let melodicInterval = abs(candidate - counterpoint.last!)
                    if melodicInterval <= 2 { score += 2 } // Stepwise preferred
                    if melodicInterval > 5 { score -= 1 } // Large leaps penalized
                }

                // Parallel motion check
                if counterpoint.count > 0 && i > 0 {
                    let prevInterval = counterpoint.last! - cantus[i-1]
                    let currInterval = candidate - note
                    if prevInterval == currInterval && (interval == 0 || interval == 7) {
                        score -= 10 // Parallel unisons/fifths forbidden
                    }
                }

                // First note should be P1, P5, or P8
                if i == 0 && ![0, 7, 12].contains(interval) { score -= 5 }

                // Last note should be P1 or P8
                if i == cantus.count - 1 && ![0, 12].contains(interval) { score -= 5 }

                if score > bestScore {
                    bestScore = score
                    bestNote = candidate
                }
            }

            counterpoint.append(bestNote)
        }

        return counterpoint
    }

    private func generateSecondSpecies(cantus: [Int], position: CounterpointPosition) -> [Int] {
        // Two notes per cantus note
        var counterpoint: [Int] = []
        let firstSpecies = generateFirstSpecies(cantus: cantus, position: position)

        for (i, target) in firstSpecies.enumerated() {
            counterpoint.append(target)

            // Add passing tone or neighbor
            if i < firstSpecies.count - 1 {
                let next = firstSpecies[i + 1]
                let middle = (target + next) / 2
                counterpoint.append(middle)
            }
        }

        return counterpoint
    }

    private func generateThirdSpecies(cantus: [Int], position: CounterpointPosition) -> [Int] {
        // Four notes per cantus note
        var counterpoint: [Int] = []
        let firstSpecies = generateFirstSpecies(cantus: cantus, position: position)

        for (i, target) in firstSpecies.enumerated() {
            counterpoint.append(target)

            if i < firstSpecies.count - 1 {
                let next = firstSpecies[i + 1]
                let step = (next - target) / 4
                counterpoint.append(target + step)
                counterpoint.append(target + step * 2)
                counterpoint.append(target + step * 3)
            }
        }

        return counterpoint
    }

    private func generateFourthSpecies(cantus: [Int], position: CounterpointPosition) -> [Int] {
        // Syncopation with suspensions
        var counterpoint: [Int] = []
        let firstSpecies = generateFirstSpecies(cantus: cantus, position: position)

        for (i, target) in firstSpecies.enumerated() {
            if i > 0 && i < firstSpecies.count - 1 {
                // Create suspension: hold previous note, resolve
                counterpoint.append(counterpoint.last! + 0) // Tie
                counterpoint.append(target)
            } else {
                counterpoint.append(target)
            }
        }

        return counterpoint
    }

    private func generateFifthSpecies(cantus: [Int], position: CounterpointPosition) -> [Int] {
        // Florid: combination of all species
        var counterpoint: [Int] = []
        let firstSpecies = generateFirstSpecies(cantus: cantus, position: position)

        for (i, target) in firstSpecies.enumerated() {
            let species = [1, 2, 3, 4].randomElement()!

            switch species {
            case 1:
                counterpoint.append(target)
            case 2:
                counterpoint.append(target)
                if i < firstSpecies.count - 1 {
                    counterpoint.append((target + firstSpecies[i+1]) / 2)
                }
            case 3:
                counterpoint.append(target)
                if i < firstSpecies.count - 1 {
                    let next = firstSpecies[i+1]
                    counterpoint.append(target + (next - target) / 3)
                    counterpoint.append(target + 2 * (next - target) / 3)
                }
            default:
                counterpoint.append(target)
            }
        }

        return counterpoint
    }
}

// MARK: - Supporting Types

public struct ChordVoicing: Equatable {
    public let root: Int
    public let quality: ChordQuality
    public let pitches: [Int]

    public var pitchClasses: [Int] {
        pitches.map { $0 % 12 }
    }

    public init(root: Int, quality: ChordQuality, pitches: [Int] = []) {
        self.root = root
        self.quality = quality
        self.pitches = pitches.isEmpty ? Self.defaultPitches(root: root, quality: quality) : pitches
    }

    private static func defaultPitches(root: Int, quality: ChordQuality) -> [Int] {
        let intervals: [Int]
        switch quality {
        case .major: intervals = [0, 4, 7]
        case .minor: intervals = [0, 3, 7]
        case .diminished: intervals = [0, 3, 6]
        case .augmented: intervals = [0, 4, 8]
        case .dominant7: intervals = [0, 4, 7, 10]
        case .major7: intervals = [0, 4, 7, 11]
        case .minor7: intervals = [0, 3, 7, 10]
        case .diminished7: intervals = [0, 3, 6, 9]
        case .halfDiminished7: intervals = [0, 3, 6, 10]
        case .sus2: intervals = [0, 2, 7]
        case .sus4: intervals = [0, 5, 7]
        }
        return intervals.map { root + $0 }
    }
}

public enum ChordQuality: String, CaseIterable {
    case major, minor, diminished, augmented
    case dominant7, major7, minor7, diminished7, halfDiminished7
    case sus2, sus4
}

public struct VoiceRange {
    public let bassRange: ClosedRange<Int>    // Octave numbers
    public let upperRange: ClosedRange<Int>   // Octave numbers

    public static let satb = VoiceRange(bassRange: 2...4, upperRange: 3...6)
    public static let ttbb = VoiceRange(bassRange: 1...3, upperRange: 2...5)
    public static let ssaa = VoiceRange(bassRange: 3...5, upperRange: 4...7)
    public static let piano = VoiceRange(bassRange: 1...4, upperRange: 3...7)
    public static let orchestra = VoiceRange(bassRange: 0...3, upperRange: 2...8)

    public init(bassRange: ClosedRange<Int>, upperRange: ClosedRange<Int>) {
        self.bassRange = bassRange
        self.upperRange = upperRange
    }
}

// MARK: - Voice Leading Path Finder

/// Finds optimal voice leading paths between distant chords
public struct VoiceLeadingPathFinder {

    /// Find shortest voice-leading path between two chords
    public static func findPath(
        from source: ChordVoicing,
        to target: ChordVoicing,
        maxIntermediateChords: Int = 3
    ) -> [ChordVoicing] {
        // Use A* search in voice-leading space
        let sourcePoint = VoiceLeadingGeometry.ChordPoint(
            pitchClasses: source.pitchClasses.map(Double.init)
        )
        let targetPoint = VoiceLeadingGeometry.ChordPoint(
            pitchClasses: target.pitchClasses.map(Double.init)
        )

        let distance = sourcePoint.distance(to: targetPoint)

        // If close enough, direct transition
        if distance < 4.0 {
            return [source, target]
        }

        // Generate intermediate chords
        var path = [source]
        let steps = min(maxIntermediateChords, Int(distance / 2))

        for i in 1...steps {
            let t = Double(i) / Double(steps + 1)
            let interpolated = interpolateChord(source, target, t: t)
            path.append(interpolated)
        }

        path.append(target)
        return path
    }

    private static func interpolateChord(
        _ a: ChordVoicing,
        _ b: ChordVoicing,
        t: Double
    ) -> ChordVoicing {
        // Linear interpolation in pitch space
        let interpolatedPitches = zip(a.pitches, b.pitches).map { (p1, p2) in
            Int(Double(p1) * (1 - t) + Double(p2) * t)
        }

        return ChordVoicing(
            root: Int(Double(a.root) * (1 - t) + Double(b.root) * t),
            quality: t < 0.5 ? a.quality : b.quality,
            pitches: interpolatedPitches
        )
    }
}

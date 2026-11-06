import Foundation

/// Revoice: the upper notes of each chord the musician wrote moved by whole octaves, so the
/// voices travel as few semitones as possible from chord to chord — among those placements.
/// Nothing is added or removed: every note keeps its id, start, length, velocity and pitch class;
/// each chord's lowest note (its bass) and the first chord stay as written. One `updateNotes`
/// command, one undo step, like Quantize (`NoteTiming`).
///
/// What "as few as possible" means here, exactly (and the only thing the app may say about it):
/// - A chord is two or more notes starting within `chordWindow` ticks of the first of them.
/// - Each upper note may stay, go an octave down or an octave up: inside 0 … 127, above its
///   chord's bass, never onto a pitch another note of the chord already holds.
/// - The movement between two chords is the sum of |Δ| with their notes paired lowest to lowest
///   (an order-keeping matching leaves the larger chord's extra notes unpaired, at their best).
/// - The path is found by an exact search over every chord's placements (dynamic programming),
///   the first chord fixed — so its total is the smallest among them and never larger than the
///   written one, which is always among them. A chord with more than `maximumUpperNotes` upper
///   notes stays as written and is counted (`Result.keptAsWritten`).
/// It is not the shortest of all possible voicings (no inversions, no doubled or dropped notes),
/// and the chord menu's own voicing (`ChordSuggest.voicing`) stays nearest-note, not this.
public enum Revoice {
    /// Notes starting this close to the first note of a chord belong to it (Humanize's widest).
    public static let chordWindow: Tick = NoteTiming.maximumTiming
    /// Up to this many upper notes a chord is searched (3⁴ = 81 placements).
    public static let maximumUpperNotes = 4

    public struct Result: Equatable, Sendable {
        /// The command to perform; nil when nothing would move.
        public var command: Command?
        /// Semitones the voices travel, as written and as revoiced.
        public var writtenMovement: Int
        public var revoicedMovement: Int
        /// Chords left as written because they hold more than `maximumUpperNotes` upper notes.
        public var keptAsWritten: Int
    }

    /// The chords of `clip` in start order, each its notes lowest first.
    static func chords(in clip: Clip) -> [[Note]] {
        let sorted = clip.notes.sorted { ($0.start, $0.pitch, $0.id.rawValue.uuidString) < ($1.start, $1.pitch, $1.id.rawValue.uuidString) }
        var groups: [[Note]] = []
        var current: [Note] = []
        for note in sorted {
            if let first = current.first, note.start - first.start > chordWindow {
                groups.append(current)
                current = []
            }
            current.append(note)
        }
        if !current.isEmpty { groups.append(current) }
        return groups.filter { $0.count >= 2 }.map { $0.sorted { ($0.pitch, $0.id.rawValue.uuidString) < ($1.pitch, $1.id.rawValue.uuidString) } }
    }

    /// Every allowed placement of a chord's upper notes, as pitches in the chord's note order;
    /// the written one first.
    static func placements(of chord: [Note]) -> [[Int]] {
        let written = chord.map(\.pitch)
        guard let bass = written.first, chord.count - 1 <= maximumUpperNotes else { return [written] }
        let distinct = Set(written).count
        var result: [[Int]] = []
        func walk(_ index: Int, _ pitches: [Int]) {
            if index == written.count {
                if Set(pitches).count >= distinct { result.append(pitches) }
                return
            }
            for offset in [0, -12, 12] {
                let pitch = written[index] + offset
                guard Note.pitchRange.contains(pitch), offset == 0 || pitch > bass else { continue }
                walk(index + 1, pitches + [pitch])
            }
        }
        walk(1, [bass])
        return result.isEmpty ? [written] : result
    }

    /// The semitones from one chord to the next, paired lowest to lowest; with unequal sizes the
    /// order-keeping matching that moves least leaves the extra notes unpaired.
    static func movement(_ from: [Int], _ to: [Int]) -> Int {
        let a = from.sorted(), b = to.sorted()
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        if a.count == b.count { return zip(a, b).reduce(0) { $0 + Swift.abs($1.0 - $1.1) } }
        let (short, long) = a.count < b.count ? (a, b) : (b, a)
        // best[i][j]: the least movement pairing short[0..<i] into long[0..<j].
        let unreachable = Int.max / 4
        var best = Array(repeating: Array(repeating: unreachable, count: long.count + 1), count: short.count + 1)
        for j in 0...long.count { best[0][j] = 0 }
        for i in 1...short.count {
            for j in i...long.count {
                let skip = best[i][j - 1]
                let pair = best[i - 1][j - 1] + Swift.abs(short[i - 1] - long[j - 1])
                best[i][j] = Swift.min(skip, pair)
            }
        }
        return best[short.count][long.count]
    }

    public static func revoiced(_ clip: Clip) -> Result {
        let chords = chords(in: clip)
        let kept = chords.filter { $0.count - 1 > maximumUpperNotes }.count
        guard chords.count >= 2 else {
            return Result(command: nil, writtenMovement: 0, revoicedMovement: 0, keptAsWritten: kept)
        }
        var options: [[[Int]]] = []
        for (index, chord) in chords.enumerated() {
            options.append(index == 0 ? [chord.map(\.pitch)] : placements(of: chord))
        }
        // Exact search: cost[k][j] is the least movement from the first chord to placement j of
        // chord k. Ties keep the earlier placement (the written one first), so the result is the
        // same every time and moves nothing it need not.
        var cost: [[Int]] = [[0]]
        var back: [[Int]] = [[0]]
        for k in 1..<options.count {
            var row: [Int] = [], from: [Int] = []
            for candidate in options[k] {
                var bestCost = Int.max, bestIndex = 0
                for (i, previous) in options[k - 1].enumerated() {
                    let total = cost[k - 1][i] + movement(previous, candidate)
                    if total < bestCost {
                        bestCost = total
                        bestIndex = i
                    }
                }
                row.append(bestCost)
                from.append(bestIndex)
            }
            cost.append(row)
            back.append(from)
        }
        guard let last = cost.last, let end = last.indices.min(by: { (last[$0], $0) < (last[$1], $1) }) else {
            return Result(command: nil, writtenMovement: 0, revoicedMovement: 0, keptAsWritten: kept)
        }
        var chosen = Array(repeating: 0, count: options.count)
        chosen[options.count - 1] = end
        var k = options.count - 1
        while k > 0 {
            chosen[k - 1] = back[k][chosen[k]]
            k -= 1
        }
        var written = 0
        for k in 1..<chords.count { written += movement(chords[k - 1].map(\.pitch), chords[k].map(\.pitch)) }
        var changed: [Note] = []
        for (k, chord) in chords.enumerated() {
            let pitches = options[k][chosen[k]]
            for (note, pitch) in zip(chord, pitches) where pitch != note.pitch {
                var moved = note
                moved.pitch = pitch
                changed.append(moved)
            }
        }
        return Result(command: changed.isEmpty ? nil : .updateNotes(clip.id, changed),
                      writtenMovement: written, revoicedMovement: last[end], keptAsWritten: kept)
    }
}

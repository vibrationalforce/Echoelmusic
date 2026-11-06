import Foundation

/// Revoice: the upper notes of each chord the musician wrote moved by whole octaves, so the
/// voices travel as few semitones as possible from chord to chord — among those placements.
/// Nothing is added or removed: every note keeps its id, start, length, velocity and pitch class;
/// each chord's lowest notes (its bass) and the first chord stay as written. One `updateNotes`
/// command, one undo step, like Quantize (`NoteTiming`).
///
/// What "as few as possible" means here, exactly (and the only thing the app may say about it):
/// - A chord is three or more notes starting within `chordWindow` ticks of the first of them (a
///   chord humanized by one Humanize press stays one chord); two notes together — a bass under a
///   melody — are no chord, and single notes never move.
/// - Each upper note may stay, go an octave down or an octave up: inside 0 … 127, above its
///   chord's bass, never onto a pitch another note of the chord holds, nor onto the pitch of a
///   note outside the chord that sounds at the same time (playback would cut one of the two).
/// - The movement between two chords is the sum of |Δ| with their notes paired lowest to lowest
///   (an order-keeping matching leaves the larger chord's extra notes unpaired, at their best).
/// - The path is found by an exact search over every chord's placements (dynamic programming),
///   the first chord fixed: its total is the smallest among them and never larger than the
///   written one, which is always among them; among paths of that total, it moves the fewest
///   notes. A chord with more than `maximumUpperNotes` upper notes stays as written and is
///   counted (`Result.keptAsWritten`).
/// It is not the shortest of all possible voicings (no inversions, one octave at most, no doubled
/// or dropped notes), and the chord menu's own voicing (`ChordSuggest.voicing`) stays
/// nearest-note, not this.
public enum Revoice {
    /// Notes starting this close to the first note of a chord belong to it: one Humanize press
    /// at its widest spreads a chord over this many ticks.
    public static let chordWindow: Tick = NoteTiming.maximumTiming
    /// The fewest notes a chord has.
    public static let minimumChordNotes = 3
    /// Up to this many upper notes a chord is searched (3⁴ = 81 placements).
    public static let maximumUpperNotes = 4

    public struct Result: Equatable, Sendable {
        /// The command to perform; nil when nothing would move.
        public var command: Command?
        /// Semitones the voices travel, as written and as revoiced.
        public var writtenMovement: Int
        public var revoicedMovement: Int
        /// How many chords were found, and how many after the first (which always stays) were left
        /// as written because they hold more than `maximumUpperNotes` upper notes.
        public var chordCount: Int
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
        return groups.filter { $0.count >= minimumChordNotes }
            .map { $0.sorted { ($0.pitch, $0.id.rawValue.uuidString) < ($1.pitch, $1.id.rawValue.uuidString) } }
    }

    /// Every allowed placement of a chord's upper notes, as pitches in the chord's note order;
    /// the written one first. `outside` holds, per note, the pitches of the clip's other notes
    /// that sound while it does.
    static func placements(of chord: [Note], outside: [Set<Int>] = []) -> [[Int]] {
        let written = chord.map(\.pitch)
        guard let bass = written.first, chord.count - 1 <= maximumUpperNotes else { return [written] }
        // Every note at the bass's pitch is bass: a doubled bass stays.
        let fixed = written.prefix { $0 == bass }.count
        var result: [[Int]] = []
        func walk(_ index: Int, _ pitches: [Int]) {
            if index == written.count {
                result.append(pitches)
                return
            }
            for offset in [0, -12, 12] {
                let pitch = written[index] + offset
                if offset != 0 {
                    guard Note.pitchRange.contains(pitch), pitch > bass,
                          !written.contains(pitch), !pitches.contains(pitch),
                          !(index < outside.count && outside[index].contains(pitch)) else { continue }
                }
                walk(index + 1, pitches + [pitch])
            }
        }
        walk(fixed, Array(written.prefix(fixed)))
        // A moved note may still meet a later note's moved pitch: keep only placements whose
        // moved pitches are all their own.
        let clean = result.filter { pitches in
            for (index, pitch) in pitches.enumerated() where pitch != written[index] {
                if pitches.enumerated().contains(where: { $0.offset != index && $0.element == pitch }) { return false }
            }
            return true
        }
        return clean.isEmpty ? [written] : clean
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

    /// Per note of `chord`, the pitches of the clip's other notes that sound while it does.
    static func outsidePitches(of chord: [Note], in clip: Clip) -> [Set<Int>] {
        let members = Set(chord.map(\.id))
        return chord.map { note -> Set<Int> in
            let end = note.start + note.length
            return Set(clip.notes.filter { other in
                !members.contains(other.id) && other.start < end && note.start < other.start + other.length
            }.map(\.pitch))
        }
    }

    public static func revoiced(_ clip: Clip) -> Result {
        let chords = chords(in: clip)
        let kept = chords.dropFirst().filter { $0.count - 1 > maximumUpperNotes }.count
        guard chords.count >= 2 else {
            return Result(command: nil, writtenMovement: 0, revoicedMovement: 0, chordCount: chords.count, keptAsWritten: kept)
        }
        var options: [[[Int]]] = []
        for (index, chord) in chords.enumerated() {
            options.append(index == 0 ? [chord.map(\.pitch)]
                           : placements(of: chord, outside: outsidePitches(of: chord, in: clip)))
        }
        // Exact search: best[k][j] is the least (movement, notes moved) from the first chord to
        // placement j of chord k, compared in that order. Remaining ties keep the earlier
        // placement (the written one first), so the result is the same every time.
        func moved(_ k: Int, _ j: Int) -> Int {
            zip(options[k][j], chords[k]).filter { $0.0 != $0.1.pitch }.count
        }
        var best: [[(cost: Int, moved: Int)]] = [[(0, 0)]]
        var back: [[Int]] = [[0]]
        for k in 1..<options.count {
            var row: [(cost: Int, moved: Int)] = [], from: [Int] = []
            for (j, candidate) in options[k].enumerated() {
                var bestKey = (cost: Int.max, moved: Int.max), bestIndex = 0
                for (i, previous) in options[k - 1].enumerated() {
                    let key = (cost: best[k - 1][i].cost + movement(previous, candidate),
                               moved: best[k - 1][i].moved + moved(k, j))
                    if key.cost < bestKey.cost || (key.cost == bestKey.cost && key.moved < bestKey.moved) {
                        bestKey = key
                        bestIndex = i
                    }
                }
                row.append(bestKey)
                from.append(bestIndex)
            }
            best.append(row)
            back.append(from)
        }
        guard let last = best.last,
              let end = last.indices.min(by: { (last[$0].cost, last[$0].moved, $0) < (last[$1].cost, last[$1].moved, $1) })
        else {
            return Result(command: nil, writtenMovement: 0, revoicedMovement: 0, chordCount: chords.count, keptAsWritten: kept)
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
                var shifted = note
                shifted.pitch = pitch
                changed.append(shifted)
            }
        }
        return Result(command: changed.isEmpty ? nil : .updateNotes(clip.id, changed),
                      writtenMovement: written, revoicedMovement: last[end].cost, chordCount: chords.count,
                      keptAsWritten: kept)
    }

    /// What the app says after Revoice, sighted and spoken alike.
    public static func message(_ result: Result) -> String {
        let kept = result.keptAsWritten > 0
            ? " \(result.keptAsWritten) chord\(result.keptAsWritten == 1 ? "" : "s") of more than \(maximumUpperNotes + 1) notes left as written."
            : ""
        if result.chordCount < 2 { return "Revoice needs two chords of \(minimumChordNotes) or more notes in this clip." }
        guard result.command != nil else { return "No octave move of the upper notes shortens the path." + kept }
        return "Revoiced: the voices move \(result.revoicedMovement) semitones instead of \(result.writtenMovement)." + kept
    }
}

import Foundation

/// Revoice: the upper notes of each chord the musician wrote moved by whole octaves, so the
/// voices travel as few semitones as possible from chord to chord — among those placements.
/// Nothing is added or removed: every note keeps its id, start, length, velocity and pitch class;
/// each chord's lowest notes (its bass) and the first chord stay as written. One `updateNotes`
/// command, one undo step, like Quantize (`NoteTiming`).
///
/// What "as few as possible" means here, exactly (and the only thing the app may say about it):
/// - A chord is three or more notes starting within `chordWindow` ticks of the first of them (a
///   chord humanized by one Humanize press stays one chord), each sounding with another of them.
///   A note that sounds with none of the notes after it — a grace note, a pickup — is a note of
///   its own: it is no part of the chord and does not start its window. Two notes together — a
///   bass under a melody — are no chord, and single notes never move.
/// - The bass is the chord's lowest pitch, doubled or not; the notes above it are its upper notes.
///   Each may stay, go an octave down or an octave up: inside 0 … 127, above the bass, never onto
///   a pitch another note of the chord holds or takes, nor onto a pitch another note sounding at
///   the same time ends up on (playback would cut one of the two). For the notes of the chords
///   before and after, the search checks exactly that; for any other note it is held to its
///   pitch and, if Revoice may move it, to the octaves it could take.
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
        var result: [[Note]] = []
        var index = 0
        while index < sorted.count {
            let anchor = sorted[index]
            var end = index + 1
            while end < sorted.count, sorted[end].start - anchor.start <= chordWindow { end += 1 }
            let group = Array(sorted[index..<end])
            // A note sounding with none of the notes of its window (a grace note, a pickup) is a
            // note of its own; the window starts again at the next one.
            guard group.dropFirst().contains(where: { overlaps($0, anchor) }) else {
                index += 1
                continue
            }
            let chord = group.filter { note in group.contains { $0.id != note.id && overlaps($0, note) } }
            if chord.count >= minimumChordNotes {
                result.append(chord.sorted { ($0.pitch, $0.id.rawValue.uuidString) < ($1.pitch, $1.id.rawValue.uuidString) })
            }
            index = end
        }
        return result
    }

    /// Whether two notes sound at the same time.
    static func overlaps(_ a: Note, _ b: Note) -> Bool {
        a.start < b.start + b.length && b.start < a.start + a.length
    }

    /// How many of a chord's notes, lowest first, are its bass: every note at the lowest pitch.
    static func bassCount(_ chord: [Note]) -> Int {
        guard let bass = chord.first?.pitch else { return 0 }
        return chord.prefix { $0.pitch == bass }.count
    }

    /// Whether Revoice searches a chord's placements: it has at most `maximumUpperNotes` upper notes.
    static func isSearched(_ chord: [Note]) -> Bool {
        chord.count - bassCount(chord) <= maximumUpperNotes
    }

    /// Every allowed placement of a chord's upper notes, as pitches in the chord's note order;
    /// the written one first. `outside` holds, per note, the pitches its new pitch must not take:
    /// those that notes outside the chord hold, or may be moved to, while it sounds.
    static func placements(of chord: [Note], outside: [Set<Int>] = []) -> [[Int]] {
        let written = chord.map(\.pitch)
        guard let bass = written.first, isSearched(chord) else { return [written] }
        var result: [[Int]] = []
        // A moved pitch is never one the chord holds as written, nor one an earlier note took, so
        // no two notes of a placement share a pitch they did not share as written.
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
        let fixed = bassCount(chord)
        walk(fixed, Array(written.prefix(fixed)))
        return result
    }

    /// The semitones from one chord to the next, paired lowest to lowest; with unequal sizes the
    /// order-keeping matching that moves least leaves the extra notes unpaired.
    static func movement(_ from: [Int], _ to: [Int]) -> Int {
        sortedMovement(from.sorted(), to.sorted())
    }

    /// `movement` of two chords already lowest first: one row of the matching at a time, in a
    /// temporary buffer, so the search does not allocate per pair.
    static func sortedMovement(_ a: [Int], _ b: [Int]) -> Int {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        if a.count == b.count {
            var sum = 0
            for index in a.indices { sum += Swift.abs(a[index] - b[index]) }
            return sum
        }
        let (short, long) = a.count < b.count ? (a, b) : (b, a)
        let unreachable = Int.max / 4
        // row[j]: the least movement pairing short[0..<i] into long[0..<j], for the row i at hand.
        return withUnsafeTemporaryAllocation(of: Int.self, capacity: long.count + 1) { row in
            row.initialize(repeating: 0)
            for i in 1...short.count {
                var diagonal = row[i - 1]
                row[i - 1] = unreachable
                for j in i...long.count {
                    let above = row[j]
                    row[j] = Swift.min(row[j - 1], diagonal + Swift.abs(short[i - 1] - long[j - 1]))
                    diagonal = above
                }
            }
            return row[long.count]
        }
    }

    /// Per note of `chord`, the pitches its new pitch must not take: every other note of the clip
    /// that sounds while it does holds its pitch, and one Revoice may move (`movable`) could also
    /// take the octave below or above. The notes of the neighbouring chords (`checked`) are left
    /// out: the search checks those exactly (`clashes`).
    static func outsidePitches(of chord: [Note], in clip: Clip, movable: Set<NoteID> = [],
                               checked: Set<NoteID> = []) -> [Set<Int>] {
        let members = Set(chord.map(\.id))
        return chord.map { note -> Set<Int> in
            var taken = Set<Int>()
            for other in clip.notes
            where !members.contains(other.id) && !checked.contains(other.id) && overlaps(note, other) {
                taken.insert(other.pitch)
                if movable.contains(other.id) {
                    taken.insert(other.pitch - 12)
                    taken.insert(other.pitch + 12)
                }
            }
            return taken
        }
    }

    /// Whether two placements of neighbouring chords put two notes that sound together on one
    /// pitch, at least one of them moved (`touching`: their sounding pairs, earlier chord first).
    static func clashes(_ earlier: [Int], _ earlierChord: [Note], _ later: [Int], _ laterChord: [Note],
                        touching: [(Int, Int)]) -> Bool {
        for (a, b) in touching where earlier[a] == later[b] {
            if earlier[a] != earlierChord[a].pitch || later[b] != laterChord[b].pitch { return true }
        }
        return false
    }

    public static func revoiced(_ clip: Clip) -> Result {
        let chords = chords(in: clip)
        let kept = chords.dropFirst().filter { !isSearched($0) }.count
        guard chords.count >= 2 else {
            return Result(command: nil, writtenMovement: 0, revoicedMovement: 0, chordCount: chords.count, keptAsWritten: kept)
        }
        var movable = Set<NoteID>()
        for chord in chords.dropFirst() where isSearched(chord) {
            for note in chord.dropFirst(bassCount(chord)) { movable.insert(note.id) }
        }
        var options: [[[Int]]] = []
        for (index, chord) in chords.enumerated() {
            var checked = Set<NoteID>()
            if index > 0 { checked.formUnion(chords[index - 1].map(\.id)) }
            if index + 1 < chords.count { checked.formUnion(chords[index + 1].map(\.id)) }
            options.append(index == 0 ? [chord.map(\.pitch)]
                           : placements(of: chord, outside: outsidePitches(of: chord, in: clip, movable: movable,
                                                                          checked: checked)))
        }
        // The notes of each pair of neighbouring chords that sound together.
        var touching: [[(Int, Int)]] = [[]]
        for k in 1..<chords.count {
            var pairs: [(Int, Int)] = []
            for (a, earlier) in chords[k - 1].enumerated() {
                for (b, later) in chords[k].enumerated() where overlaps(earlier, later) { pairs.append((a, b)) }
            }
            touching.append(pairs)
        }
        // Each placement lowest first, and how many notes it moves, worked out once.
        let sortedOptions = options.map { $0.map { $0.sorted() } }
        var movedNotes: [[Int]] = []
        for (k, chord) in chords.enumerated() {
            movedNotes.append(options[k].map { pitches in zip(pitches, chord).filter { $0.0 != $0.1.pitch }.count })
        }
        // Exact search: best[k][j] is the least (movement, notes moved) from the first chord to
        // placement j of chord k, compared in that order, over steps that put no two sounding
        // notes on one pitch. The written path is always among them. Remaining ties keep the
        // earlier placement (the written one first), so the result is the same every time.
        var best: [[(cost: Int, moved: Int)]] = [[(0, 0)]]
        var back: [[Int]] = [[0]]
        for k in 1..<options.count {
            var row: [(cost: Int, moved: Int)] = [], from: [Int] = []
            for j in options[k].indices {
                var bestKey = (cost: Int.max, moved: Int.max), bestIndex = 0
                for i in options[k - 1].indices where best[k - 1][i].cost != Int.max {
                    if !touching[k].isEmpty,
                       clashes(options[k - 1][i], chords[k - 1], options[k][j], chords[k], touching: touching[k]) { continue }
                    let key = (cost: best[k - 1][i].cost + sortedMovement(sortedOptions[k - 1][i], sortedOptions[k][j]),
                               moved: best[k - 1][i].moved + movedNotes[k][j])
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
        if result.chordCount < 2 { return "Revoice needs two chords of \(minimumChordNotes) or more notes in this clip." }
        let count = result.keptAsWritten
        let kept = "\(count) chord\(count == 1 ? "" : "s") with more than \(maximumUpperNotes) notes above the bass left as written."
        if result.chordCount - 1 - count <= 0 { return "Nothing to revoice: " + kept }
        let note = count > 0 ? " " + kept : ""
        guard result.command != nil else { return "No octave move of the upper notes shortens the path." + note }
        return "Revoiced: the voices move \(result.revoicedMovement) semitones instead of \(result.writtenMovement)." + note
    }
}

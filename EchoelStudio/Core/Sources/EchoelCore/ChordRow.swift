import Foundation

/// The row of chord buttons on the play screen (founder 2026-11-11: one finger on one chord of the
/// song's key counts as PLAYING — it sounds only while the finger is down and writes nothing). The
/// order is keys, then chords, then strum; this is the chord step, as a pure rule the screen calls.
///
/// The row holds the key's own chords: one triad on each degree of the scale that holds one, in the
/// scale's order, the same chords `ChordSuggest` ranks — borrowed chords are not in this row. In a
/// seven-note scale that is the degree's third-stack wherever it has a name, as on every degree of
/// the church modes; otherwise, and in a pentatonic or any other scale, the first triad of the
/// vocabulary whose tones the scale holds (TH-5), so every button names its chord — C major
/// pentatonic plays C, Dsus2, Gsus2 and Am, and its E, on which no triad of the scale sits, has no
/// button. Each button shows the chord's name ("Dm", "B°"), never a roman numeral. A press
/// voice-leads from the chord pressed before it through `ChordSuggest.voicing`, so common tones
/// stay and the other voices take the smallest step, and keeps the three voices inside
/// `voiceRange`. Under them the chord's root sounds in `bassRange`. Nothing is stored and nothing
/// reaches the song: the screen holds the last `Press` while it shows the row, and forgets it with
/// the row.
public enum ChordRow {
    /// One button of the row.
    public struct Entry: Equatable, Sendable {
        public let chord: ChordSuggest.Chord
        /// What the button shows: the chord's name, never a roman numeral.
        public let label: String
    }

    /// What one finger on one chord sounds while it is down.
    public struct Press: Equatable, Sendable {
        /// The chord's three tones, ascending, each inside `voiceRange`, all different.
        public let voices: [Int]
        /// The chord's root in `bassRange`, under every voice.
        public let bass: Int
        /// Everything that sounds, lowest first: the bass, then the voices.
        public var notes: [Int] { [bass] + voices }
    }

    /// Where the three voices stay: E3 … E5, an octave either side of E4, where
    /// `ChordSuggest.voicing` places a chord when nothing sounded before. A voice that a long run of
    /// presses carries past an edge folds back by an octave, so the row never walks off the keys.
    /// Two octaves wide, so every pitch class has a place in it.
    public static let voiceRange: ClosedRange<Int> = 52...76

    /// Where the root sounds under the voices: E2 … E♭3, the octave just below `voiceRange`. One
    /// finger names one chord, and a voice-led triad is often an inversion (F after C is C-F-A); the
    /// root underneath makes the chord the button names the chord the ear hears. It is never a voice
    /// to lead from — leading from it would pull the voices down into the bass — and it sits below
    /// every voice by at least a whole tone, because no triad tone lies a semitone above its root.
    public static let bassRange: ClosedRange<Int> = 40...51

    /// The row for `context`: one chord per degree of its scale that holds one, in order. Empty for a
    /// song without a key (chromatic, or a scale this build does not know) and for a root outside
    /// 0 … 11, which names no key either (`MusicalContext.title` reads it as Chromatic too).
    public static func entries(in context: MusicalContext) -> [Entry] {
        guard MusicalContext.rootRange.contains(context.root) else { return [] }
        return ChordSuggest.candidates(in: context)
            .filter { !$0.borrowed }
            .map { Entry(chord: $0, label: $0.name) }
    }

    /// The most buttons one line of the row holds: seven buttons and their narrow gaps stay a finger
    /// wide on a phone held upright. A scale of eight notes or more can give a longer row (TH-5).
    public static let longestLine = 7

    /// Where the row's `count` buttons stand, line by line: one line up to `longestLine` buttons,
    /// otherwise as few lines as hold them, as even as they come, each a run of the row's order —
    /// eight buttons are two lines of four, nine a line of five over one of four, ten two of five.
    /// No line for an empty row.
    public static func lines(count: Int) -> [Range<Int>] {
        guard count > 0 else { return [] }
        let lineCount = (count + longestLine - 1) / longestLine
        let shortest = count / lineCount
        let longer = count % lineCount
        var out: [Range<Int>] = []
        var start = 0
        for line in 0..<lineCount {
            let length = shortest + (line < longer ? 1 : 0)
            out.append(start..<(start + length))
            start += length
        }
        return out
    }

    /// What pressing chord `index` of the row sounds after `previous` (nil when nothing was pressed
    /// before: the voices sit within a tritone of E4). Nil for an index outside the row. Notes of
    /// `previous` outside MIDI's range are ignored.
    public static func press(_ index: Int, in context: MusicalContext, after previous: Press?) -> Press? {
        let row = entries(in: context)
        guard row.indices.contains(index) else { return nil }
        let chord = row[index].chord
        guard let root = chord.pitchClasses.first else { return nil }
        let anchors = (previous?.voices ?? []).filter { Note.pitchRange.contains($0) }
        let voiced = ChordSuggest.voicing(of: chord, after: anchors).map { folded($0) }.sorted()
        let lowest = bassRange.lowerBound
        return Press(voices: voiced, bass: lowest + ChordSuggest.pitchClass(root - lowest))
    }

    /// `pitch` moved by octaves until it lies inside `voiceRange`; its pitch class stays.
    static func folded(_ pitch: Int) -> Int {
        var moved = pitch
        while moved > voiceRange.upperBound { moved -= 12 }
        while moved < voiceRange.lowerBound { moved += 12 }
        return moved
    }
}

extension ChordSuggest.Chord {
    /// The chord as VoiceOver says it: "D minor", "B diminished", "F sharp major", "C suspended
    /// fourth", spelled as its key writes it ("G sharp minor" in F♯ major); another stack names its
    /// tones, "C, E, A". `name` writes it short ("Dm", "B°").
    public var spokenName: String { spokenName(.english) }
}

import XCTest
@testable import EchoelCore

/// The Idea engine proposes chords for the song's key and writes nothing by itself: the same seed
/// is the same idea, every note lies in the scale and inside its bar, and accepting is three
/// commands the door takes.
final class IdeaEngineTests: XCTestCase {
    private let fourFour = TimeSignature(4, 4)
    private var bar: Tick { MusicalTime.ticksPerBar(fourFour) }

    private func request(_ root: Int = 0, _ scale: Scale = .major, bars: Int = 4, seed: UInt64 = 0, bass: Bool = false,
                         meter: TimeSignature? = nil) -> IdeaEngine.Request {
        IdeaEngine.Request(context: MusicalContext(root: root, scale: scale), meter: meter ?? fourFour, bars: bars,
                           seed: seed, bass: bass)
    }

    func testTheSameSeedIsTheSameIdeaAndOtherSeedsGiveOthers() {
        XCTAssertEqual(IdeaEngine.propose(request(seed: 7, bass: true)), IdeaEngine.propose(request(seed: 7, bass: true)))
        let progressions = Set((0..<12).map { (seed: Int) -> [String] in
            IdeaEngine.propose(request(bars: 8, seed: UInt64(seed))).chords.map(\.name)
        })
        XCTAssertGreaterThanOrEqual(progressions.count, 4, "twelve seeds give at least four different progressions")
    }

    func testAnIdeaStartsOnTheTonicAndTurnsBackBeforeItRepeats() throws {
        for seed in 0..<6 {
            let idea = IdeaEngine.propose(request(seed: UInt64(seed)))
            XCTAssertEqual(idea.chords.count, 4)
            XCTAssertEqual(idea.chords.first?.name, "C", "seed \(seed)")
            XCTAssertEqual(idea.chords.last?.function, .dominant, "seed \(seed): the last bar leads back")
            XCTAssertEqual(idea.length, 4 * bar)
            XCTAssertTrue(idea.remarks.isEmpty)
        }
        let minor = IdeaEngine.propose(request(9, .minor))
        XCTAssertEqual(minor.chords.first?.name, "Am")
        // No bar repeats the chord before it.
        let eight = IdeaEngine.propose(request(bars: 8, seed: 3)).chords
        for (before, after) in zip(eight, eight.dropFirst()) {
            XCTAssertNotEqual(before.pitchClasses, after.pitchClasses)
        }
    }

    /// In every scale that holds chords, in every key, with and without a bass: each note is a note
    /// of the scale, a playable pitch, and sounds inside its own bar.
    func testEveryNoteLiesInTheScaleAndInsideItsBar() {
        var ideas = 0
        for scale in Scale.allCases where scale != .chromatic {
            for root in MusicalContext.rootRange {
                for seed in 0..<2 {
                    let asked = request(root, scale, seed: UInt64(seed), bass: true)
                    let idea = IdeaEngine.propose(asked)
                    guard !idea.isEmpty else {
                        XCTAssertEqual(idea.remarks, [.tooFewChords], "\(scale) on \(root)")
                        continue
                    }
                    ideas += 1
                    XCTAssertEqual(idea.length, Tick(idea.chords.count) * bar)
                    for note in idea.notes {
                        XCTAssertTrue(asked.context.contains(note.pitch), "\(scale) on \(root): \(note.pitch)")
                        XCTAssertTrue(Note.pitchRange.contains(note.pitch))
                        XCTAssertGreaterThan(note.length, 0)
                        XCTAssertEqual(note.start / bar, (note.start + note.length - 1) / bar, "\(scale) on \(root): inside one bar")
                        XCTAssertLessThanOrEqual(note.start + note.length, idea.length)
                    }
                    for chord in idea.chords { XCTAssertFalse(chord.borrowed) }
                }
            }
        }
        XCTAssertGreaterThan(ideas, 1_000, "most scales hold chords")
    }

    func testTheBassPlaysTheRootsBelowTheChordsInEveryMeter() {
        for (numerator, denominator) in [(4, 4), (3, 4), (6, 8), (7, 8), (5, 4), (12, 8)] {
            let meter = TimeSignature(numerator, denominator)
            let ticks = MusicalTime.ticksPerBar(meter)
            for seed in 0..<6 {
                let plain = IdeaEngine.propose(request(seed: UInt64(seed), meter: meter))
                let withBass = IdeaEngine.propose(request(seed: UInt64(seed), bass: true, meter: meter))
                XCTAssertEqual(plain.chords, withBass.chords, "the bass changes no chord")
                let bass = withBass.notes.filter { $0.velocity == IdeaEngine.bassVelocity }
                XCTAssertFalse(bass.isEmpty)
                XCTAssertEqual(withBass.notes.count, plain.notes.count + bass.count)
                for note in bass {
                    XCTAssertTrue((IdeaEngine.bassFloor..<(IdeaEngine.bassFloor + 12 + 7)).contains(note.pitch))
                    XCTAssertEqual(note.start / ticks, (note.start + note.length - 1) / ticks, "\(numerator)/\(denominator)")
                    let chord = withBass.chords[Int(note.start / ticks)]
                    XCTAssertTrue(chord.pitchClasses.contains(ChordSuggest.pitchClass(note.pitch)), "a tone of its chord")
                }
                // Each bar's first bass note is its chord's root.
                for (index, chord) in withBass.chords.enumerated() {
                    let first = bass.first { $0.start == Tick(index) * ticks }
                    XCTAssertEqual(first.map { ChordSuggest.pitchClass($0.pitch) }, chord.pitchClasses.first)
                }
            }
        }
    }

    func testASongWithoutAKeyGetsNoNotesAndSaysWhy() {
        let idea = IdeaEngine.propose(request(0, .chromatic))
        XCTAssertTrue(idea.isEmpty)
        XCTAssertEqual(idea.remarks, [.noKey])
        XCTAssertEqual(idea.length, 0)
        XCTAssertGreaterThan(IdeaEngine.Remark.noKey.sentence.count, 20)
        XCTAssertEqual(IdeaEngine.propose(request(bars: 0)).chords.count, 1, "fewer than one bar is one bar")
        XCTAssertEqual(IdeaEngine.propose(request(bars: 99)).chords.count, IdeaEngine.maximumBars)
    }

    /// Accepting is create, add notes, place: on the first free bar of the track, under a name no
    /// clip of the track carries, and only on an instrument track.
    func testAcceptingIsThreeCommandsTheDoorTakes() throws {
        var project = Project()
        let keys = TrackID(), audio = TrackID()
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.addTrack(id: audio, name: "Voice", kind: .audio, index: nil).apply(to: &project)
        let idea = IdeaEngine.propose(IdeaEngine.Request(context: project.context.scale == .chromatic
                                                             ? MusicalContext(root: 0, scale: .major) : project.context,
                                                         meter: project.timeSignature, bars: 4, seed: 1, bass: true))
        XCTAssertFalse(idea.isEmpty)
        XCTAssertTrue(idea.commands(on: audio, in: project).isEmpty, "notes belong on an instrument track")
        XCTAssertTrue(IdeaEngine.propose(request(0, .chromatic)).commands(on: keys, in: project).isEmpty)

        let before = project
        let first = idea.commands(on: keys, in: project)
        XCTAssertEqual(first.count, 3)
        for command in first { try command.apply(to: &project) }
        var track = try XCTUnwrap(project.track(keys))
        XCTAssertEqual(track.clips.map(\.name), ["Idea"])
        XCTAssertEqual(track.clips.first?.notes.count, idea.notes.count)
        XCTAssertEqual(track.clips.first?.length, idea.length)
        XCTAssertEqual(track.placements.map(\.start), [0])
        XCTAssertEqual(project.context, before.context, "the key stays the musician's")
        XCTAssertEqual(project.tempo, before.tempo)

        // A second idea lands after the first, under its own name.
        for command in idea.commands(on: keys, in: project) { try command.apply(to: &project) }
        track = try XCTUnwrap(project.track(keys))
        XCTAssertEqual(track.clips.map(\.name), ["Idea", "Idea 2"])
        XCTAssertEqual(track.placements.map(\.start), [0, idea.length])
    }
}

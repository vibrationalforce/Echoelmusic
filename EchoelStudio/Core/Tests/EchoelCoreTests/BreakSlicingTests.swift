import XCTest
@testable import EchoelCore

/// The break slicer (EchoelTools A11): where a loop is cut, the pattern it played, and the one
/// door it goes through.
final class BreakSlicingTests: XCTestCase {
    private let rate = 48_000.0

    /// A song with a sampler track playing a two-second file.
    private func song() throws -> (project: Project, track: TrackID, file: MediaFile) {
        var project = Project(tempo: 120)
        let track = TrackID()
        let file = MediaFile(name: "Amen", path: "Media/amen.wav", frameCount: 96_000, sampleRate: rate)
        try Command.addTrack(id: track, name: "Break", kind: .instrument, index: nil).apply(to: &project)
        try Command.addMedia(file).apply(to: &project)
        try Command.setInstrumentDevice(track, .sampler).apply(to: &project)
        try Command.setInstrumentSample(track, file.id).apply(to: &project)
        return (project, track, file)
    }

    func testTheStartsAreZeroThenTheOnsets() {
        let starts = BreakSlicing.starts(onsets: [0.0, 0.25, 0.5, 0.51, 1.0, 1.75, .nan, 5], frameCount: 96_000, sampleRate: rate)
        // 0 first; an onset at the start, one 10 ms after another, one past the end and NaN are dropped.
        XCTAssertEqual(starts, [0, 12_000, 24_000, 48_000, 84_000])
    }

    func testAFileWithManyOnsetsKeepsSixteenSpreadAcrossIt() {
        let onsets = (1..<64).map { Double($0) * 0.03125 }
        let starts = BreakSlicing.starts(onsets: onsets, frameCount: 96_000, sampleRate: rate)
        XCTAssertEqual(starts.count, SampleSlice.maximumCount)
        XCTAssertEqual(starts.first, 0)
        XCTAssertEqual(starts, starts.sorted())
        XCTAssertGreaterThan(starts.last ?? 0, 80_000, "the end of the loop has pads too")
    }

    func testAFileWithoutOnsetsIsCutIntoEightEqualPads() {
        XCTAssertEqual(BreakSlicing.starts(onsets: [], frameCount: 96_000, sampleRate: rate),
                       [0, 12_000, 24_000, 36_000, 48_000, 60_000, 72_000, 84_000])
        XCTAssertEqual(BreakSlicing.starts(onsets: [0.5], frameCount: 96_000, sampleRate: rate).count, 8)
        XCTAssertEqual(BreakSlicing.starts(onsets: [], frameCount: 5, sampleRate: rate), [0, 1, 2, 3, 4])
        XCTAssertEqual(BreakSlicing.starts(onsets: [], frameCount: 0, sampleRate: rate), [])
    }

    func testTheLoopSpansThePowerOfTwoBeatsThatLandsBetween80And160BPM() {
        XCTAssertEqual(BreakSlicing.beats(forSeconds: 2), 4)        // 120
        XCTAssertEqual(BreakSlicing.beats(forSeconds: 1.4), 2)      // 86, not 171
        XCTAssertEqual(BreakSlicing.beats(forSeconds: 5.65), 8)     // 85, a two-bar break at 170 → half
        XCTAssertEqual(BreakSlicing.beats(forSeconds: 0.2), 1)      // 300, as short as a beat gets
        XCTAssertEqual(BreakSlicing.beats(forSeconds: .nan), 4)
    }

    /// Each slice is one note on its pad at its share of the loop, as long as its slice: at the song's
    /// tempo the break plays as it was cut, at another it follows.
    func testThePatternPlaysEachSliceOnItsPadAtItsShareOfTheLoop() {
        let made = BreakSlicing.pattern(starts: [0, 12_000, 48_000], frameCount: 96_000, sampleRate: rate)
        XCTAssertEqual(made.length, 4 * MusicalTime.ticksPerQuarter)
        XCTAssertEqual(made.notes.map(\.pitch), [36, 37, 38])
        XCTAssertEqual(made.notes.map(\.start), [0, 480, 1_920])
        XCTAssertEqual(made.notes.map(\.length), [480, 1_440, 1_920])
    }

    func testSliceToPadsIsOneUndoStepThroughTheDoor() async throws {
        let (project, track, file) = try song()
        try await MainActor.run {
            let store = ProjectStore(project: project)
            let starts = [0, 12_000, 48_000]
            try store.perform(BreakSlicing.commands(track: track, file: file, starts: starts, writePattern: true),
                              title: "Slice to Pads")
            let instrument = try XCTUnwrap(store.project.track(track)).instrument
            XCTAssertEqual(instrument.slices, starts.map { SampleSlice(start: $0) })
            let clip = try XCTUnwrap(store.project.track(track)?.clips.first)
            XCTAssertEqual(clip.name, "Amen")
            XCTAssertEqual(clip.notes.count, 3)
            XCTAssertEqual(store.project.track(track)?.placements.count, 1)
            store.undo()
            XCTAssertNil(store.project.track(track)?.instrument.slices)
            XCTAssertEqual(store.project.track(track)?.clips.count, 0, "one undo takes all of it back")
            try store.perform(BreakSlicing.commands(track: track, file: file, starts: starts, writePattern: false),
                              title: "Slice to Pads")
            XCTAssertEqual(store.project.track(track)?.clips.count, 0, "without the pattern no clip is written")
            XCTAssertEqual(store.project.track(track)?.instrument.slices?.count, 3)
        }
    }

    /// Editing a slice point is the same command with the new list; the door refuses a list that
    /// cannot cut the file and leaves the song as it was.
    func testTheDoorValidatesTheSlices() throws {
        var (project, track, _) = try song()
        try Command.setSamplerSlices(track, [SampleSlice(start: 0), SampleSlice(start: 30_000)]).apply(to: &project)
        try Command.setSamplerSlices(track, [SampleSlice(start: 0), SampleSlice(start: 31_000, tune: -3, reverse: true)])
            .apply(to: &project)
        XCTAssertEqual(project.track(track)?.instrument.slices?.last, SampleSlice(start: 31_000, tune: -3, reverse: true))
        let before = project
        let bad: [[SampleSlice]] = [
            [SampleSlice(start: 10), SampleSlice(start: 10)],
            [SampleSlice(start: -1)],
            [SampleSlice(start: 96_000)],
            [SampleSlice(start: 0, tune: .nan)],
            [SampleSlice(start: 0, tune: 25)],
            (0..<17).map { SampleSlice(start: $0 * 100) },
        ]
        for slices in bad {
            XCTAssertThrowsError(try Command.setSamplerSlices(track, slices).apply(to: &project), "\(slices)")
            XCTAssertEqual(project, before)
        }
        try Command.setSamplerSlices(track, []).apply(to: &project)
        XCTAssertNil(project.track(track)?.instrument.slices, "empty plays the file across the keys")
        var empty = Project()
        let lone = TrackID()
        try Command.addTrack(id: lone, name: "S", kind: .instrument, index: nil).apply(to: &empty)
        XCTAssertThrowsError(try Command.setSamplerSlices(lone, [SampleSlice(start: 0)]).apply(to: &empty), "no file to cut")
    }

    func testAnotherFileOrARemovedOneStartsUncut() throws {
        var (project, track, file) = try song()
        try Command.setSamplerSlices(track, [SampleSlice(start: 0), SampleSlice(start: 30_000)]).apply(to: &project)
        try Command.setInstrumentSample(track, file.id).apply(to: &project)
        XCTAssertEqual(project.track(track)?.instrument.slices?.count, 2, "the same file keeps its pads")
        let other = MediaFile(name: "Think", path: "Media/think.wav", frameCount: 48_000, sampleRate: rate)
        try Command.addMedia(other).apply(to: &project)
        try Command.setInstrumentSample(track, other.id).apply(to: &project)
        XCTAssertNil(project.track(track)?.instrument.slices)
        try Command.setInstrumentSample(track, file.id).apply(to: &project)
        try Command.setSamplerSlices(track, [SampleSlice(start: 0), SampleSlice(start: 30_000)]).apply(to: &project)
        try Command.removeMedia(file.id).apply(to: &project)
        XCTAssertNil(project.track(track)?.instrument.slices)
    }

    /// The slices are stored inside format 4: written only when there are some, tune and reverse
    /// only when set; a song without them reads none; a list that cannot cut its file refuses the song.
    func testTheSlicesRoundTripAndAreValidatedWhenASongOpens() throws {
        var (project, track, _) = try song()
        let plain = try ProjectCodec.encode(project)
        XCTAssertFalse(String(decoding: plain, as: UTF8.self).contains("\"slices\""))
        try Command.setSamplerSlices(track, [SampleSlice(start: 0), SampleSlice(start: 24_000, tune: 2.5, reverse: true)])
            .apply(to: &project)
        let data = try ProjectCodec.encode(project)
        XCTAssertEqual(try ProjectCodec.decode(data), project)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let stored = try XCTUnwrap((root["tracks"] as? [[String: Any]])?.first?["instrument"] as? [String: Any])
        let slices = try XCTUnwrap(stored["slices"] as? [[String: Any]])
        XCTAssertEqual(Set(slices[0].keys), ["start"])
        XCTAssertEqual(Set(slices[1].keys), ["start", "tune", "reverse"])
        let past = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "24000", with: "99000")
        XCTAssertNotEqual(Data(past.utf8), data, "the replacement must land")
        XCTAssertThrowsError(try ProjectCodec.decode(Data(past.utf8)))
    }
}

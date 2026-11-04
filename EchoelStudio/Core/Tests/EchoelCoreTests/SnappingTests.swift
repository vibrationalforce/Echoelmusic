import XCTest
@testable import EchoelCore

final class SnappingTests: XCTestCase {
    private let common = MeterMap(signature: .common)
    private let bar = MusicalTime.ticksPerBar(.common)

    // MARK: The magnet

    func testTheMagnetRunsFromOffThroughTheBarDownToAHundredTwentyEighthAndFourTriplets() {
        XCTAssertEqual(SnapGrid.allCases.map(\.title),
                       ["Off", "Bar", "Beat", "1/8", "1/16", "1/32", "1/64", "1/128", "1/4T", "1/8T", "1/16T", "1/32T"])
        XCTAssertEqual(SnapGrid.allCases.compactMap(\.noteValue), [480, 240, 120, 60, 30, 640, 320, 160, 80])
        XCTAssertEqual(SnapGrid.allCases.compactMap(\.noteValue).filter { bar % $0 != 0 }, [], "every value divides a 4/4 bar")
        XCTAssertEqual(SnapGrid.standard, .sixteenth, "a fresh install keeps the editor's earlier grid")
    }

    func testTheKeptChoiceReadsBackFromItsRawValue() {
        // Kept on the device as these strings; renaming one would drop a musician's choice.
        XCTAssertEqual(SnapGrid.allCases.map(\.rawValue),
                       ["off", "bar", "beat", "eighth", "sixteenth", "thirtySecond", "sixtyFourth",
                        "hundredTwentyEighth", "quarterTriplet", "eighthTriplet", "sixteenthTriplet",
                        "thirtySecondTriplet"])
        XCTAssertEqual(SnapGrid.storageKey, "edit.snap")
        for snap in SnapGrid.allCases { XCTAssertEqual(SnapGrid(rawValue: snap.rawValue), snap) }
    }

    func testOffPlacesToTheTick() {
        XCTAssertEqual(SnapGrid.off.nearest(1_234, meter: common), 1_234)
        XCTAssertEqual(SnapGrid.off.nearest(-7, meter: common), 0)
        XCTAssertEqual(SnapGrid.off.nearest(.max, meter: common), MusicalTime.maximumTick)
        XCTAssertNil(SnapGrid.off.step(at: 0, meter: common))
        XCTAssertEqual(SnapGrid.off.editorStep(meter: common), 0)
    }

    func testEachChoiceRoundsToItsNearestLineHalfWayUp() {
        XCTAssertEqual(SnapGrid.bar.nearest(1_919, meter: common), 0)
        XCTAssertEqual(SnapGrid.bar.nearest(1_920, meter: common), bar)
        XCTAssertEqual(SnapGrid.beat.nearest(1_500, meter: common), 1_920)
        XCTAssertEqual(SnapGrid.sixteenth.nearest(119, meter: common), 0)
        XCTAssertEqual(SnapGrid.sixteenth.nearest(120, meter: common), 240)
        XCTAssertEqual(SnapGrid.hundredTwentyEighth.nearest(44, meter: common), 30)
        XCTAssertEqual(SnapGrid.hundredTwentyEighth.nearest(45, meter: common), 60)
        XCTAssertEqual(SnapGrid.quarterTriplet.nearest(1_000, meter: common), 1_280)
        XCTAssertEqual(SnapGrid.thirtySecondTriplet.nearest(100, meter: common), 80)
    }

    func testTheGridCountsFromTheBarLineSoATripletNeverOverrunsAnOddBar() {
        // 7/8: a bar of 3,360 ticks; a quarter triplet (640) does not divide it.
        let seven = MeterMap(signature: TimeSignature(7, 8))
        XCTAssertEqual(SnapGrid.quarterTriplet.nearest(3_300, meter: seven), 3_360, "the bar line, not 3,840")
        XCTAssertEqual(SnapGrid.quarterTriplet.nearest(3_400, meter: seven), 3_360)
        XCTAssertEqual(SnapGrid.quarterTriplet.nearest(3_360 + 700, meter: seven), 3_360 + 640, "counted from bar 2")
        XCTAssertEqual(SnapGrid.beat.step(at: 0, meter: seven), 480)
        XCTAssertEqual(SnapGrid.bar.editorStep(meter: seven), 3_360)
    }

    func testTheBarMagnetNeverPassesTheLastTickASongHolds() {
        let snapped = SnapGrid.bar.nearest(MusicalTime.maximumTick, meter: common)
        XCTAssertLessThanOrEqual(snapped, MusicalTime.maximumTick)
        XCTAssertEqual(snapped, Arranging.nearestBar(MusicalTime.maximumTick, meter: common))
    }

    // MARK: The arrangement

    private func arrangement() -> (Track, Placement) {
        let clip = Clip(name: "A", length: bar)
        let placement = Placement(clip: clip.id, start: bar)
        var track = Track(name: "Keys", kind: .instrument)
        track.clips = [clip]
        track.placements = [placement]
        return (track, placement)
    }

    func testAMoveLandsOnTheMagnetAndOffMovesItToTheTick() throws {
        let (track, placement) = arrangement()
        XCTAssertEqual(Arranging.moved(placement, in: track, byTicks: 250, meter: common, snap: .sixteenth),
                       .movePlacement(track: track.id, placement.id, start: bar + 240))
        XCTAssertEqual(Arranging.moved(placement, in: track, byTicks: 37, meter: common, snap: .off),
                       .movePlacement(track: track.id, placement.id, start: bar + 37))
        XCTAssertNil(Arranging.moved(placement, in: track, byTicks: 250, meter: common, snap: .bar),
                     "a quarter of a bar on the bar magnet lands where it started")
        XCTAssertEqual(Arranging.moved(placement, in: track, byTicks: 250, meter: common),
                       Arranging.moved(placement, in: track, byTicks: 250, meter: common, snap: .bar),
                       "the bar move keeps its meaning (VoiceOver's Move One Bar)")
    }

    func testASplitCutsOnTheMagnet() throws {
        let (track, placement) = arrangement()
        let cut = try XCTUnwrap(Arranging.split(placement, in: track, at: bar + 1_000, meter: common, snap: .beat))
        guard case let .splitPlacement(_, _, at, _, _, _) = cut else { return XCTFail("\(cut)") }
        XCTAssertEqual(at, bar + 960)
        let free = try XCTUnwrap(Arranging.split(placement, in: track, at: bar + 1_001, meter: common, snap: .off))
        guard case let .splitPlacement(_, _, freeAt, _, _, _) = free else { return XCTFail("\(free)") }
        XCTAssertEqual(freeAt, bar + 1_001)
        XCTAssertNil(Arranging.split(placement, in: track, at: bar + 100, meter: common, snap: .bar),
                     "snapped onto the clip's own start is no cut")
    }

    // MARK: Quantize

    private func clip(_ notes: [Note]) -> Clip { Clip(name: "C", length: bar, notes: notes) }

    private func updated(_ command: Command?) -> [Note] {
        guard case let .updateNotes(_, notes)? = command else { return [] }
        return notes
    }

    func testQuantizeMovesStartsToTheGridByItsStrength() {
        let late = Note(pitch: 60, start: 260, length: 100)
        let early = Note(pitch: 62, start: 470, length: 100)
        let c = clip([late, early])
        XCTAssertEqual(updated(NoteTiming.quantized(c, snap: .sixteenth, meter: common, strength: 1)).map(\.start), [240, 480])
        XCTAssertEqual(updated(NoteTiming.quantized(c, snap: .sixteenth, meter: common, strength: 0.5)).map(\.start), [250, 475])
        XCTAssertEqual(updated(NoteTiming.quantized(c, snap: .sixteenth, meter: common, strength: 1)).map(\.length), [100, 100],
                       "lengths stay")
        XCTAssertNil(NoteTiming.quantized(c, snap: .sixteenth, meter: common, strength: 0))
        XCTAssertNil(NoteTiming.quantized(c, snap: .off, meter: common, strength: 1), "no grid with the magnet off")
        XCTAssertNil(NoteTiming.quantized(c, snap: .sixteenth, meter: common, strength: .nan))
    }

    func testQuantizeTakesOnlyTheChosenNotesAndLeavesNotesOnTheGridAlone() {
        let a = Note(pitch: 60, start: 10, length: 100), b = Note(pitch: 62, start: 250, length: 100)
        let onGrid = Note(pitch: 64, start: 480, length: 100)
        let c = clip([a, b, onGrid])
        XCTAssertEqual(updated(NoteTiming.quantized(c, chosen: [b.id], snap: .sixteenth, meter: common, strength: 1)).map(\.id), [b.id])
        XCTAssertEqual(updated(NoteTiming.quantized(c, snap: .sixteenth, meter: common, strength: 1)).map(\.id), [a.id, b.id])
    }

    func testSwingDelaysEverySecondLineUpToATriplet() {
        let notes = [Note(pitch: 60, start: 5, length: 60), Note(pitch: 60, start: 245, length: 60),
                     Note(pitch: 60, start: 485, length: 60), Note(pitch: 60, start: 725, length: 60)]
        let full = updated(NoteTiming.quantized(clip(notes), snap: .sixteenth, meter: common, strength: 1, swing: 1))
        XCTAssertEqual(full.map(\.start), [0, 320, 480, 800], "the off-sixteenths a third of a step late")
        let half = updated(NoteTiming.quantized(clip(notes), snap: .sixteenth, meter: common, strength: 1, swing: 0.5))
        XCTAssertEqual(half.map(\.start), [0, 280, 480, 760])
    }

    func testQuantizeNeverPutsAStartOutsideTheClip() {
        let last = Note(pitch: 60, start: bar - 10, length: 5)
        XCTAssertEqual(updated(NoteTiming.quantized(clip([last]), snap: .sixteenth, meter: common, strength: 1)).map(\.start),
                       [bar - 1], "the next line is the clip's end")
    }

    // MARK: Humanize

    private func run() -> [Note] {
        (0..<16).map { Note(pitch: 60 + $0 % 5, velocity: 100, start: Tick($0) * 240, length: 120) }
    }

    func testHumanizeIsTheSameForTheSameSeedAndBounded() {
        let c = clip(run())
        let first = updated(NoteTiming.humanized(c, timing: 20, velocity: 10, seed: 42))
        XCTAssertEqual(first, updated(NoteTiming.humanized(c, timing: 20, velocity: 10, seed: 42)))
        XCTAssertNotEqual(first, updated(NoteTiming.humanized(c, timing: 20, velocity: 10, seed: 43)))
        XCTAssertFalse(first.isEmpty)
        let before = Dictionary(uniqueKeysWithValues: c.notes.map { ($0.id, $0) })
        for note in first {
            let original = try? XCTUnwrap(before[note.id])
            XCTAssertLessThanOrEqual(abs(note.start - (original?.start ?? 0)), 20)
            XCTAssertLessThanOrEqual(abs(note.velocity - (original?.velocity ?? 0)), 10)
            XCTAssertEqual(note.length, original?.length)
            XCTAssertGreaterThanOrEqual(note.start, 0)
        }
    }

    func testHumanizeIsCappedAndKeepsVelocityAndStartInRange() {
        let edge = [Note(pitch: 60, velocity: 1, start: 0, length: 10), Note(pitch: 61, velocity: 127, start: bar - 1, length: 1)]
        for seed: UInt64 in 0..<50 {
            for note in updated(NoteTiming.humanized(clip(edge), timing: 10_000, velocity: 1_000, seed: seed)) {
                XCTAssertTrue(Note.velocityRange.contains(note.velocity))
                XCTAssertTrue((0..<bar).contains(note.start))
            }
        }
        let wide = updated(NoteTiming.humanized(clip(run()), timing: 10_000, velocity: 1_000, seed: 7))
        XCTAssertFalse(wide.isEmpty)
        for note in wide {
            XCTAssertLessThanOrEqual(abs(note.velocity - 100), NoteTiming.maximumVelocity)
            XCTAssertLessThanOrEqual(abs(note.start % 240 == 0 ? 0 : Swift.min(note.start % 240, 240 - note.start % 240)),
                                     NoteTiming.maximumTiming)
        }
        XCTAssertNil(NoteTiming.humanized(clip(run()), timing: 0, velocity: 0, seed: 1))
    }

    func testQuantizeAndHumanizeAreEachOneUndoStepAndRedoIsExact() async throws {
        let bar = bar, common = common
        try await MainActor.run {
            let store = ProjectStore()
            let track = TrackID(), id = ClipID()
            let notes = [Note(pitch: 60, start: 13, length: 100), Note(pitch: 64, start: 250, length: 100)]
            try store.perform([
                .addTrack(id: track, name: "Keys", kind: .instrument, index: nil),
                .createClip(track: track, id: id, name: "C", length: bar),
                .addNotes(id, notes),
            ], title: "Setup")
            let original = try XCTUnwrap(store.project.clip(id))

            let quantize = try XCTUnwrap(NoteTiming.quantized(original, snap: .sixteenth, meter: common, strength: 1))
            try store.perform([quantize], title: "Quantize")
            XCTAssertEqual(store.project.clip(id)?.notes.map(\.start), [0, 240])
            XCTAssertEqual(store.undoTitle, "Quantize")

            let quantizedClip = try XCTUnwrap(store.project.clip(id))
            let humanize = try XCTUnwrap(NoteTiming.humanized(quantizedClip, timing: 30, velocity: 15, seed: 9))
            try store.perform([humanize], title: "Humanize")
            let humanized = store.project.clip(id)?.notes
            store.undo()
            XCTAssertEqual(store.project.clip(id)?.notes, quantizedClip.notes)
            store.redo()
            XCTAssertEqual(store.project.clip(id)?.notes, humanized, "redo puts back exactly the same notes")
            store.undo()
            store.undo()
            XCTAssertEqual(store.project.clip(id)?.notes, original.notes)
        }
    }

    // MARK: The note editor off the grid

    func testWithTheMagnetOffATapWritesASixteenthWhereTheFingerIs() throws {
        let command = try XCTUnwrap(NoteEditing.tap(in: clip([]), pitch: 60, tick: 333, grid: 0))
        guard case let .addNotes(_, notes) = command else { return XCTFail("\(command)") }
        XCTAssertEqual(notes.map(\.start), [333])
        XCTAssertEqual(notes.map(\.length), [NoteEditing.freeNoteLength])
        XCTAssertEqual(NoteEditing.moved(notes[0], byTicks: 7, semitones: 0, grid: 0, in: clip([])).start, 340)
    }

    func testSpeechNeverCountsInTicks() {
        XCTAssertEqual(NoteEditing.spokenStep(for: 0), 240)
        XCTAssertEqual(NoteEditing.spokenStep(for: 3_840), 240, "a bar is no note value said")
        XCTAssertEqual(NoteEditing.spokenStep(for: 30), 30)
        XCTAssertEqual(NoteEditing.spokenLength(60, grid: 30), "2 hundred-twenty-eighths")
    }
}

// TheSessionReplacesTheSongWholeTests.swift
// Echoel — WA4-S1: the two stores can take a restored song WHOLE.
//
// WHAT THIS PINS. Opening a Session must put ITS song in place of the current one. Before this
// slice neither store could: `TimelineStore.document` had no writer outside init/bootstrap and
// `ClipStore` could only set one slot at a time, so Open left the previous timeline and clips in
// place — the "leak" the WA4 forensic review named (`SESSION_OWNERSHIP_CENSUS.md` §E).
//
// 1. END-TO-END over a REAL `TimelineStore`: `replaceDocument` installs the song, clears an
//    undo history that belonged to the previous song, and WRITES THROUGH — a freshly
//    constructed store (what the next launch does) reads the same document back.
// 2. END-TO-END over a REAL `ClipStore`: `replaceSlots` refuses a mis-sized grid and changes
//    nothing; an 8-cell grid is installed positionally and reads back from a fresh store.
//
// ⚠️ Both tests replace PERSISTED state of the test host and restore the original in a
// `defer`, through the same API. They assert on their own fixture values, never on counts.
//
// Grading (§0, no Swift toolchain in a web session): transcribed into Python over a model of
// the two stores' replace/undo/persist paths. On the parent (5bdcd2b71) neither method exists,
// so the bundle does not build there — ONE absence (#486); both claims are FORWARD guards.
// NOT covered: the Open path that will call these (WA4-S3) and anything on a device.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheSessionReplacesTheSongWholeTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar

    func testTheTimelineTakesARestoredSongWholeAndWritesItThrough() throws {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }

        let lane = TimelineLane(name: "S1 guard \(UUID().uuidString.prefix(8))", kind: .audio)
        let part = TimelineRegion(laneID: lane.id, clipID: UUID(),
                                  startTick: Self.bar, lengthTicks: 2 * Self.bar)
        let restored = TimelineDocument(lanes: [lane], regions: [part])

        // Give the CURRENT song an undo step, so the replace has a history to clear.
        timeline.replaceDocument(restored)
        timeline.removeRegion(id: part.id)
        XCTAssertTrue(timeline.canUndo, "fixture premise: the edit left an undo step")

        timeline.replaceDocument(restored)
        XCTAssertEqual(timeline.document, restored)
        XCTAssertFalse(timeline.canUndo, """
            an Undo after Open would restore the previous song's parts into this one — the \
            history belongs to the song that was replaced
            """)
        XCTAssertFalse(timeline.canRedo)

        // Written through at once: the next launch reads this song, not a debounced older one.
        XCTAssertEqual(TimelineStore().document, restored,
                       "a fresh store must read back the replaced song")
    }

    func testTheClipGridIsReplacedWholeOrNotAtAll() throws {
        let clips = ClipStore()
        let original = clips.slots
        defer { clips.replaceSlots(original) }

        let take = Clip(name: "S1 guard", kind: .midi,
                        melody: MelodyClip(notes: [Note(pitch: 60, startStep: 0)]))
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[3] = take

        XCTAssertFalse(clips.replaceSlots(Array(grid.prefix(ClipStore.slotCount - 1))),
                       "a short grid would re-seat every clip after the gap")
        XCTAssertFalse(clips.replaceSlots(grid + [nil]))
        XCTAssertEqual(clips.slots, original, "a refused replace changes nothing")

        XCTAssertTrue(clips.replaceSlots(grid))
        XCTAssertEqual(clips.slots, grid)
        XCTAssertEqual(clips.slots[3]?.id, take.id, "positional: the clip stays in its cell")
        XCTAssertEqual(ClipStore().slots, grid, "a fresh store must read back the replaced grid")
    }
}

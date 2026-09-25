// TheComposerReusesItsOrphanedClipTests.swift
// Echoel — WA4 review condition (MEDIUM #1): the composer must not leak clip slots.
//
// WHAT THIS PINS. `TimelineStore.ensureComposerRegion` minted a NEW composer clip whenever the
// Echoel track had no composer part inside the loop window. Since WA4.3/WA4.4 a user can remove
// that part, Undo its creation, or move it Later — and nothing clears a slot
// (`ClipStore.clear(at:)` has no production caller). Every remove → Start cycle therefore spent
// one of the eight slots for good, until the full grid refused every import. The store now
// reuses an ORPHANED composer clip — composer-owned, played by no region — by id.
//
// 1. END-TO-END (pure) over `TimelineStore.orphanedComposerClip`: only composer-owned clips
//    that no region plays are candidates; a user clip never is; the lane's own name wins.
// 2. END-TO-END over REAL stores: remove the composer part, call again, and the grid has not
//    grown — the new part plays the SAME clip; an Undo that brings the old part back finds it.
//    Both stores are replaced with a known fixture through the WA4-S1 APIs and restored in a
//    `defer`, so the assertion never depends on what an earlier run persisted.
//
// Grading (§0, no Swift toolchain in a web session): transcribed into Python over a model of
// `ensureComposerRegion`, the orphan rule and the store's region undo. On the parent
// (a924cd4fb) `orphanedComposerClip` does not exist, so the bundle does not build there — ONE
// absence (#486). Claim 2 is a REGRESSION in substance (the parent grows the grid by one per
// cycle — driven in the transcription) but can only be observed once the file compiles.
// NOT covered: the Start button that calls this on a device.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheComposerReusesItsOrphanedClipTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar

    // MARK: 1 — the rule

    func testOnlyAnUnplayedComposerClipIsReusable() {
        let lane = TimelineLane(name: "Keys", kind: .midi)
        let played = Clip(name: "Composed · Keys", kind: .midi, composerOwned: true)
        let orphanOther = Clip(name: "Composed · Lead", kind: .midi, composerOwned: true)
        let orphanOwn = Clip(name: "Composed · Keys", kind: .midi, composerOwned: true)
        let user = Clip(name: "MIDI · Keys", kind: .midi, composerOwned: false)
        let part = TimelineRegion(laneID: lane.id, clipID: played.id, startTick: 0, lengthTicks: Self.bar)
        let doc = TimelineDocument(lanes: [lane], regions: [part])

        XCTAssertEqual(TimelineStore.orphanedComposerClip(
            in: doc, clips: [user, played, orphanOther, orphanOwn], preferring: "Composed · Keys")?.id,
            orphanOwn.id, "the lane's own orphan wins over an earlier one")
        XCTAssertEqual(TimelineStore.orphanedComposerClip(
            in: doc, clips: [user, played, orphanOther], preferring: "Composed · Keys")?.id,
            orphanOther.id, "any orphan beats spending a new slot")
        XCTAssertNil(TimelineStore.orphanedComposerClip(
            in: doc, clips: [user, played], preferring: "MIDI · Keys"),
            "a user clip is never taken, and a played composer clip is not an orphan")
    }

    // MARK: 2 — the real stores

    func testRemovingTheComposerPartDoesNotSpendASlot() throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            timeline.replaceDocument(originalDocument)
            clips.replaceSlots(originalSlots)
        }

        let lane = TimelineLane(name: "Leak guard", kind: .midi)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: []))
        XCTAssertTrue(clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount)))

        XCTAssertTrue(timeline.ensureComposerRegion(for: lane.id, clipStore: clips, loopBars: 4))
        let first = try XCTUnwrap(timeline.document.regions(in: lane.id).first)
        XCTAssertEqual(clips.filledClips.count, 1, "premise: the first call mints one clip")

        for cycle in 1...3 {
            let parts = timeline.document.regions(in: lane.id)
            for part in parts { timeline.removeRegion(id: part.id) }
            XCTAssertTrue(timeline.ensureComposerRegion(for: lane.id, clipStore: clips, loopBars: 4))
            XCTAssertEqual(clips.filledClips.count, 1, """
                cycle \(cycle): removing the composer part and starting again grew the clip grid. \
                Nothing clears a slot, so this fills all eight and then refuses every import.
                """)
            XCTAssertEqual(timeline.document.regions(in: lane.id).map(\.clipID), [first.clipID],
                           "the new part plays the orphaned clip, reused by id")
        }

        // Undo the last automatic add, then the removal: the old part comes back and still
        // finds its clip — reuse never deleted what an Undo can restore.
        timeline.undo()
        timeline.undo()
        let restored = timeline.document.regions(in: lane.id)
        XCTAssertFalse(restored.isEmpty, "premise: undo restored a part")
        for part in restored {
            XCTAssertNotNil(clips.clip(id: part.clipID), "a restored part must find its clip")
        }
    }
}

// ANoteEndIsAFingerWideTests.swift
// Echoel — EP-2 (founder on device, 2026-10-15: „Midi und Clips sowie editing View sind bisher
// komplett unbrauchbar und zu ungenau"). A note's length was grabbed only in the last 8 pt INSIDE
// it — a sliver, and on a one-step note at the smallest zoom (11 pt) barely 5 pt.
//
// THE CLAIMS. END-TO-END BEHAVIOUR (`NoteGridGesture.resolve`, Foundation-only, internal):
//   1. A hold up to `edgeReach` points PAST a note's right end, in its own row, on empty grid,
//      grabs that note's length — and a slide from there stretches it by the steps slid.
//   2. COUNTERWEIGHTS: past the reach, or one row off, it is still a box; a point on ANOTHER note
//      is that note's (the reach never covers the next note); the inside zone is wider than 8 pt
//      but a two-step note still has a body to move.
//
// ⚠️ HONEST GRADING (#433): claim 1 is a REGRESSION on the parent for its named reason (a point
// past the end was a box there); claim 2's cases are counterweights, green on both trees except
// the "wider than 8" floor, red there by name. `reachingEdge` is new — that one absence (#486) is
// why the file does not compile against the parent; transcribed by hand instead.
// ⚠️ THE LIMIT: whether a finger now finds note ends is a DEVICE PROBE (NEEDS-FOUNDER-VERIFY:
// hold just right of a short note's end and slide right — the note grows).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ANoteEndIsAFingerWideTests: XCTestCase {

    private static let grid = NoteGridGesture.Grid(stepWidth: 22, rowHeight: 24, rows: 48...72,
                                                   partSteps: 16)
    private func rowY(_ pitch: Int) -> Double { Double(72 - pitch) * 24 + 4 }

    func testAHoldJustPastTheEndGrabsTheLength() {
        let a = Note(pitch: 60, startStep: 2)                     // x 44…66
        let g = Self.grid
        XCTAssertEqual(NoteGridGesture.resolve(startX: 66 + 6, startY: rowY(60), dx: 44, dy: 0,
                                               visible: [a], picked: [], grid: g),
                       .resize(id: a.id, dSteps: 2), "6 pt past the end, slid two steps → two steps longer")
        XCTAssertEqual(NoteGridGesture.resolve(startX: 66 + 6, startY: rowY(60), dx: 0, dy: 0,
                                               visible: [a], picked: [], grid: g),
                       .resize(id: a.id, dSteps: 0), "a hold without a slide stretches nothing")
    }

    func testTheReachStopsAtItsEdgeItsRowAndTheNextNote() {
        let a = Note(pitch: 60, startStep: 2)                     // x 44…66
        let b = Note(pitch: 60, startStep: 3)                     // x 66…88, right behind it
        let g = Self.grid
        guard case .marquee = NoteGridGesture.resolve(startX: 66 + NoteGridGesture.edgeReach + 1,
                                                      startY: rowY(60), dx: 10, dy: 10,
                                                      visible: [a], picked: [], grid: g) else {
            return XCTFail("past the reach the grid is a box again")
        }
        guard case .marquee = NoteGridGesture.resolve(startX: 66 + 4, startY: rowY(61), dx: 10, dy: 10,
                                                      visible: [a], picked: [], grid: g) else {
            return XCTFail("one row off is not this note's end")
        }
        XCTAssertEqual(NoteGridGesture.resolve(startX: 66 + 4, startY: rowY(60), dx: 22, dy: 0,
                                               visible: [a, b], picked: [], grid: g),
                       .move(ids: [b.id], dPitch: 0, dStep: 1),
                       "a point on the next note is the next note's — the reach never covers it")
        XCTAssertGreaterThan(NoteGridGesture.edgeSlop, 8, "the inside zone is wider than the old sliver")
        let two = Note(pitch: 62, startStep: 4, lengthSteps: 2)   // x 88…132
        XCTAssertEqual(NoteGridGesture.resolve(startX: 92, startY: rowY(62), dx: 0, dy: 0,
                                               visible: [two], picked: [], grid: g),
                       .move(ids: [two.id], dPitch: 0, dStep: 0), "a two-step note still has a body")
    }
}

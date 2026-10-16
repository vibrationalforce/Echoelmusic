//
//  LaneOrder.swift
//  Echoelmusic — Sequencer (A4c: move a track up or down)
//
//  WHY THIS EXISTS. Live and Logic let you put the tracks in the order you think in (founder
//  2026-10-16, "Arrangement auf Ableton-Level", gap list item 4). This is the pure rule for one
//  step up or down.
//
//  ⚠️ THE ORDER IS ROUTING, NOT ONLY DISPLAY (measured 2026-10-16). `TimelineDocument.rollLaneID`
//  is the first non-bio MIDI lane, and two more places repeat that rule inline (the `rollSlot*`
//  getters, `EchoelStudioView`'s lane overrides): that lane plays the Echoel instrument. So a move
//  is REFUSED when it would change which lane that is — the Echoel track never changes hands by a
//  reorder. A move is also refused when it would move the bio lane or move a lane past it: the
//  body's curve keeps its place.
//  What a move DOES change, on purpose, because that is what an order means: the voice ranks of the
//  other MIDI tracks (with more tracks than voices, the upper ones sound — "top lanes win"), the
//  channel each MIDI track exports on, which video track's picture is in front, and the audio
//  track an import lands on. The player treats an order change as structural and re-primes.
//

import Foundation

public enum LaneOrder {

    /// The lanes after moving `id` one place up (`delta` −1) or down (+1), or nil when the move is
    /// refused: an unknown id, a step other than ±1, the edge of the list, the bio lane on either
    /// side, or a move that would hand the Echoel instrument to another lane. Pure.
    public static func moved(_ lanes: [TimelineLane], id: UUID, by delta: Int) -> [TimelineLane]? {
        guard delta == -1 || delta == 1, let i = lanes.firstIndex(where: { $0.id == id }) else { return nil }
        let j = i + delta
        guard lanes.indices.contains(j), !lanes[i].isBio, !lanes[j].isBio else { return nil }
        var out = lanes
        out.swapAt(i, j)
        guard rollLane(out) == rollLane(lanes) else { return nil }
        return out
    }

    /// `lanes` in the order `ids` names; a lane `ids` does not name (added since) keeps its place
    /// after them, and an id naming no lane (removed since) is skipped. Pure.
    public static func ordered(_ lanes: [TimelineLane], as ids: [UUID]) -> [TimelineLane] {
        let byID = Dictionary(lanes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let named = ids.compactMap { byID[$0] }
        let namedIDs = Set(named.map(\.id))
        return named + lanes.filter { !namedIDs.contains($0.id) }
    }

    /// The lane that plays the Echoel instrument — `TimelineDocument.rollLaneID`'s rule, asked of
    /// the document itself so there is no fourth copy (#416).
    private static func rollLane(_ lanes: [TimelineLane]) -> UUID? {
        TimelineDocument(lanes: lanes, regions: []).rollLaneID
    }
}

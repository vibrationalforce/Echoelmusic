//
//  RegionClipboard.swift
//  Echoelmusic — Sequencer (A9: where copied parts land)
//
//  WHY THIS EXISTS. Live and Logic copy several clips at once and paste them at the insert marker,
//  keeping their spacing and their tracks (founder 2026-10-16, gap list item 3). This is the pure
//  half of that paste: given the parts as they were copied and the bar Play starts from, it names
//  the new parts. The earliest copied part lands on `tick`; every other keeps its distance from it
//  and its own track. A part whose track is gone since the copy is left out — never moved to
//  another track. Each new part gets a fresh identity and SHARES its clip, as "Copy" and Repeat do
//  (`TimelineRegion.duplicated`), so a paste needs no new clip slot.
//
//  The one writer is `TimelineStore.pasteRegions` — one `.regions` Undo step for the whole paste.
//

import Foundation

public enum RegionClipboard {

    /// The parts a paste of `copied` at `tick` places in `document`, sorted by start. Empty when
    /// nothing copied still has its track, or a copy would land past the tick ceiling. Pure.
    public static func pasted(_ copied: [TimelineRegion], atTick tick: Int,
                              in document: TimelineDocument) -> [TimelineRegion] {
        let lanes = Set(document.lanes.map(\.id))
        let kept = copied.filter { lanes.contains($0.laneID) }
        guard let earliest = kept.map(\.startTick).min() else { return [] }
        let anchor = Swift.max(0, tick)
        var placed: [TimelineRegion] = []
        for region in kept {
            let start = anchor + (region.startTick - earliest)
            // A corrupt length must refuse, not overflow (trap) — `repeatRegion`'s guard.
            guard Double(start) + Double(region.lengthTicks) <= TimelineTime.tickMagnitudeCeiling else { return [] }
            placed.append(region.duplicated(atStartTick: start))
        }
        return placed.sorted { ($0.startTick, $0.laneID.uuidString) < ($1.startTick, $1.laneID.uuidString) }
    }
}

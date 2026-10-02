//
//  WorkstationSelection.swift
//  Echoelmusic — Studio (WA4: ONE owner of what is selected in the Workstation)
//
//  WHY THIS EXISTS. The Arrange canvas, the track rows, the inspector and the parts list all
//  need to agree on "which track, which part". Until now the selected track was `@State` in
//  `WorkstationView` — fine for one surface, a second truth the moment a canvas or a device
//  inspector wants it. This is the one owner: constructed once by the app (beside the
//  timeline player), injected, never persisted.
//
//  THE RULES:
//  · A selected PART always implies its TRACK (`selectRegion` sets both), so no surface can
//    show a part selected on a track that is not.
//  · Stale ids are RESOLVED ON READ, never pruned inside a `body`: after an Open, an Undo or
//    a track removal the id may point at nothing, and `resolvedTrack/Region(in:)` answer nil.
//  · Low-frequency by construction — it changes on a tap. Never a playhead, never a meter:
//    reading it from any body is cold (the 10.76.41/50 freeze law).
//  · Medium-neutral: it holds ids of a track and a part, not of an audio channel or a clip.
//

import Foundation
import Observation

@MainActor
@Observable
public final class WorkstationSelection {

    public private(set) var trackID: UUID?
    public private(set) var regionID: UUID?
    /// A8 — which page the open track's detail shows. DAW shell S4a (founder 2026-10-02, "ein
    /// Detailbereich, der der Auswahl folgt") made it the ONE detail area: Track · Part · Notes ·
    /// Automation · Device, one page at a time, where the note grid and the automation row used
    /// to be two more switches of their own under the canvas. View state like the ids: cold (a
    /// tap), never persisted, and kept across a change of track — the inspector is rebuilt per
    /// track (`.id(row.id)`), so `@State` there would forget it on every tap of another header.
    /// A track without the chosen page shows Track (`TrackInspectorPage.shown`).
    public private(set) var inspectorPage: TrackInspectorPage = .track
    /// DMMW Phase 2 · slice 1 — whether the selected part's notes are open, so the compose
    /// guide's "Write notes" and "New MIDI Part" can open them (before, "Tap Notes" was a hidden
    /// step). Since S4a this is not a second switch beside the page: the Notes PAGE is the open
    /// grid, so the flag is read off `inspectorPage` and there is one fact, not two that could
    /// disagree. Kept across a change of part, as the old switch was.
    public var notesOpen: Bool { inspectorPage == .notes }

    public init() {}

    /// Select a track (its inspector opens); selecting the open one closes it. A part that
    /// does not sit on the newly selected track is deselected with it.
    public func toggleTrack(_ id: UUID) {
        if trackID == id {
            clear()
        } else {
            trackID = id
            regionID = nil
        }
    }

    /// Select a track WITHOUT toggling — a door that just made the track ("Add MIDI Track")
    /// must open it, never close it. A part on another track is deselected with it.
    public func selectTrack(_ id: UUID) {
        guard trackID != id else { return }
        trackID = id
        regionID = nil
    }

    /// Select a part — and, with it, the track it sits on. Unknown ids select nothing.
    public func selectRegion(_ id: UUID, in document: TimelineDocument) {
        guard let region = document.regions.first(where: { $0.id == id }) else { return }
        regionID = region.id
        trackID = region.laneID
    }

    /// Open or close the selected part's notes — the doors that promise the notes ("Write
    /// notes", "New MIDI Part"). Opening shows the Notes page; closing an open grid falls back
    /// to Track, the page every track has. Closing while another page is shown leaves it alone.
    public func setNotesOpen(_ open: Bool) {
        if open {
            inspectorPage = .notes
        } else if inspectorPage == .notes {
            inspectorPage = .track
        }
    }

    /// A8 — the detail's page control, the one writer of a chosen page.
    public func showInspectorPage(_ page: TrackInspectorPage) {
        inspectorPage = page
    }

    public func clear() {
        trackID = nil
        regionID = nil
    }

    /// The selected track, if it still exists in `document`.
    public nonisolated static func resolvedTrack(_ id: UUID?, in document: TimelineDocument) -> UUID? {
        guard let id, document.lanes.contains(where: { $0.id == id }) else { return nil }
        return id
    }

    /// The selected part, if it still exists in `document` AND still sits on the selected
    /// track (a part moved to another track by an Undo is not silently re-homed).
    public nonisolated static func resolvedRegion(_ id: UUID?, track: UUID?,
                                                  in document: TimelineDocument) -> UUID? {
        guard let id, let region = document.regions.first(where: { $0.id == id }),
              region.laneID == track else { return nil }
        return id
    }
}

/// A8 — the pages of the open track's detail; DAW shell S4a added Notes and Automation, which
/// were switches of their own under the canvas until then. A plain value: the inspector asks
/// `shown(_:offered:)` from its body, and a guard drives it without an actor.
public enum TrackInspectorPage: Hashable, Sendable {
    case track, part, notes, automation, device

    /// The page actually drawn: the chosen one when this track has it, else Track — every
    /// track has a Track page (its name).
    public static func shown(_ chosen: TrackInspectorPage, offered: [TrackInspectorPage]) -> TrackInspectorPage {
        offered.contains(chosen) ? chosen : .track
    }
}

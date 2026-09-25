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

    /// Select a part — and, with it, the track it sits on. Unknown ids select nothing.
    public func selectRegion(_ id: UUID, in document: TimelineDocument) {
        guard let region = document.regions.first(where: { $0.id == id }) else { return }
        regionID = region.id
        trackID = region.laneID
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

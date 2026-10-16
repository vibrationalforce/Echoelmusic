//
//  TrackCopy.swift
//  Echoelmusic — Sequencer (A7: duplicate a track)
//
//  WHY THIS EXISTS. "Duplicate track" is how a producer tries a variation without losing the
//  original — Live and Logic both have it (founder 2026-10-16, "Arrangement auf Ableton-Level").
//  This is the pure rule: what a copy of a track is, and which tracks can be copied.
//
//  What a copy carries: every setting of the track (sound, sample, devices, mix, colour, space) under
//  a new id and the name "<name> copy", right below the original; every part of the track, placed
//  where it stands; and the track's own automation curves, re-keyed to the copy.
//  ⚠️ A copied part plays the SAME clip, as a duplicated part does (`TimelineRegion.duplicated`), so
//  an edit to the notes plays in both tracks. A copy is never record-armed.
//  ⚠️ REFUSED for the Echoel track and the bio track: the Echoel instrument is one voice owned by one
//  lane (`TimelineDocument.rollLaneID`), the body's curve is one. A copy that would hand the Echoel
//  instrument to another lane is refused too (the `LaneOrder` rule).
//

import Foundation

public enum TrackCopy {

    /// A copy ready to insert: the new lane, the index it goes to, its parts and its curves.
    public struct Copy: Equatable, Sendable {
        public let lane: TimelineLane
        public let index: Int
        public let regions: [TimelineRegion]
        public let automation: [AutomationLane]
    }

    /// Whether track `laneID` can be copied: it exists, is not the bio track, and does not play the
    /// Echoel instrument. Pure.
    public static func offered(_ laneID: UUID, in document: TimelineDocument) -> Bool {
        guard let lane = document.lanes.first(where: { $0.id == laneID }) else { return false }
        return !lane.isBio && document.rollLaneID != laneID
    }

    /// The copy of track `laneID`, or nil when it is refused (see `offered`). `newID` is the copy's
    /// id — passed in so the rule stays pure. Pure.
    public static func copy(of laneID: UUID, in document: TimelineDocument, newID: UUID = UUID()) -> Copy? {
        guard offered(laneID, in: document),
              let i = document.lanes.firstIndex(where: { $0.id == laneID }) else { return nil }
        var lane = document.lanes[i]
        lane.id = newID
        lane.name = "\(lane.name) copy"
        lane.isArmed = false
        var lanes = document.lanes
        lanes.insert(lane, at: i + 1)
        guard TimelineDocument(lanes: lanes, regions: []).rollLaneID == document.rollLaneID else { return nil }
        let regions = document.regions.filter { $0.laneID == laneID }.map { region -> TimelineRegion in
            var copy = region.duplicated(atStartTick: region.startTick)
            copy.laneID = newID
            return copy
        }
        let automation = document.automation.compactMap { curve -> AutomationLane? in
            guard let key = PerTrackParameterKeyPath.parse(curve.parameter), key.laneID == laneID else { return nil }
            return AutomationLane(parameter: PerTrackParameterKeyPath.make(laneID: newID, base: key.base),
                                  points: curve.points)
        }
        return Copy(lane: lane, index: i + 1, regions: regions, automation: automation)
    }
}

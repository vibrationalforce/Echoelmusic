// TimelineScheduling.swift
// Echoel — the PURE region-playback logic for the arrange timeline (reorg P2).
// Given a TimelineDocument + a transport position (song-absolute ticks), it decides
// which region each lane should be playing and — crucially — WHEN the playhead
// crosses into a new region (the onset that (re)loads that lane's content).
//
// No audio, no clock, no state: the @MainActor TimelineRegionPlayer (P3) rides the
// one shared PatternEngine transport (the SAME clock ArrangementPlayer uses) and
// calls these to load region clips into the live pattern/roll — exactly the launch
// path ArrangementPlayer/the Session grid already use. Pure value logic → fully
// unit-tested on every platform (no AVFoundation).
//
// Granularity: the player samples at each transport 16th-step (120 ticks). A region
// shorter than one step that falls entirely between two steps is not triggered —
// the same step resolution the 16-step sequencer already works at. Regions are
// bar/beat sized in practice, so this is not a real limitation.
//
// ⭐ SINCE #1439 THAT PARAGRAPH IS ALSO A FUNCTION: `isSampleable(_:)`. It had been true
// and unasked for a year — the Workstation's Play button enabled itself on a region the
// scheduler provably never looks at, which is a silent transport start rather than a
// rounding detail. A documented limit that no caller can query is a limit only the author
// knows about; the predicate is how the UI finds out.
//
// ⭐ AND SINCE #1440 THE GRANULARITY IS ONLY HALF OF WHAT A PREFLIGHT HAS TO ASK. Owning a
// grid tick is not the same as WINNING it: `activeRegion` hands every tick to the
// latest-starting containing region, so an overlapping neighbour can shadow a perfectly
// executable region out of existence. `candidateSampleTicks(in:laneID:)` is the bounded set
// of ticks at which that answer can change, so a caller can ask the SELECTOR rather than
// re-deriving precedence. **Overlap precedence is defined once, in `activeRegion`, and this
// file is the only place that may define it.**

import Foundation

public enum TimelineScheduling {

    /// What a lane should do at a playhead transition — the event the player acts on.
    public enum LaneEvent: Equatable {
        /// The active region did not change (still the same region, or still a gap).
        case unchanged
        /// The playhead entered (or switched to) this region → load its clip.
        case load(TimelineRegion)
        /// The playhead fell into a gap (no region) → silence this lane.
        case clear
    }

    /// The region active in `laneID` at song-absolute `tick`: the region whose
    /// half-open span `[startTick, endTick)` contains `tick`. On overlap the
    /// LATEST-starting containing region wins (the most-recently placed / top-most),
    /// so a region dropped over another takes over cleanly. `nil` in a gap.
    ///
    /// Tie-break: when two containing regions share the same `startTick` (a clip
    /// dropped on top at the same bar — common with grid snap), the most-recently
    /// PLACED one must win. Regions are appended in placement order (newest last),
    /// so the tie breaks toward the later array element — hence the lexicographic
    /// `(startTick, offset)` max. Plain `max(by: startTick)` keeps the FIRST
    /// maximal element and would play the stale (older) clip on a tie.
    public static func activeRegion(in document: TimelineDocument,
                                    laneID: UUID, at tick: Int) -> TimelineRegion? {
        document.regions
            .filter { $0.laneID == laneID && tick >= $0.startTick && tick < $0.endTick }
            .enumerated()
            .max(by: { ($0.element.startTick, $0.offset) < ($1.element.startTick, $1.offset) })?
            .element
    }

    /// The first tick of the transport's SAMPLING GRID at or after `tick`. The player never
    /// asks about an arbitrary position: `TimelinePlaybackCursor.advance` returns
    /// `(bar * 16 + step) * ticksPerTransportStep` and `play`/`seek` fold their start to a
    /// BAR, so every tick this file is ever handed is a multiple of `ticksPerTransportStep`.
    /// Named rather than inlined because it is the grid's ONE definition (#416) and the
    /// schedulability rule below is meaningless without it.
    public static func firstSampleTick(atOrAfter tick: Int) -> Int {
        let step = TimelineTime.ticksPerTransportStep
        let floored = Swift.max(0, tick)
        return (floored + step - 1) / step * step
    }

    /// Whether the transport's grid ever lands INSIDE this region — i.e. whether
    /// `activeRegion` can ever return it. **A region no sample tick falls in is not
    /// playable, however much content it holds** (#1439).
    ///
    /// ⚠️ THIS IS NOT A NEW POLICY; IT IS THIS FILE'S OWN HEADER, MADE ASKABLE. The header
    /// has said since P2 that "a region shorter than one step that falls entirely between two
    /// steps is not triggered", and the Play predicate had no way to ask it — so a one-tick
    /// region at tick 121 enabled the button and then never loaded. Phase 4c makes the UI
    /// honest about the scheduler that EXISTS; it does not raise the resolution, and raising
    /// it would be a transport change, not a predicate change.
    ///
    /// EXCLUSIVE END, deliberately and by REUSE rather than by restatement: the test below is
    /// `activeRegion`'s own containment (`t >= startTick && t < endTick`) applied to the first
    /// candidate tick. A region ending exactly ON a sample boundary does not own that tick —
    /// the next region does — so `[119, 120)` is NOT schedulable while `[120, 121)` is.
    public static func isSampleable(_ region: TimelineRegion) -> Bool {
        let t = firstSampleTick(atOrAfter: region.startTick)
        return t >= region.startTick && t < region.endTick
    }

    /// Every transport sample tick at which this lane's ACTIVE REGION can differ from the
    /// tick before it — the COMPLETE decision set for any question of the form "does the
    /// scheduler ever select, on this lane, a region with property P?" (#1440).
    ///
    /// ⭐ WHY A PREFLIGHT NEEDS THIS AND NOT `isSampleable(_:)`. A region can own grid ticks
    /// and still never be selected: `activeRegion` hands every one of them to an OVERLAPPING
    /// region that starts LATER, or — on an equal start — to the one placed later. Judging
    /// each region on its own therefore approves songs the transport plays as silence, which
    /// is the same class of claim #1439 removed one layer down. The WINNER is the question,
    /// so the winner is what gets asked.
    ///
    /// ⭐ WHY IT IS BOUNDED BY THE DOCUMENT AND NOT BY THE SONG LENGTH — no per-tick sweep,
    /// no simulation, no cache. `activeRegion` is piecewise constant: its answer can only
    /// change where a region starts or ends. So the first grid tick of each piece is enough,
    /// and every piece begins at a region boundary. Two sources, each O(regions on the lane):
    ///   · a region's OWN first grid tick — `isSampleable` decides whether it has one;
    ///   · the first grid tick after another region ENDS strictly inside this one — the
    ///     moment a shadow lifts, which is the only way a region that lost at its own start
    ///     can win later.
    /// A boundary where another region STARTS is deliberately NOT a source: a start can only
    /// TAKE the lane away from this region, and the taker's own first grid tick is already in
    /// the set under its own name. Checked against a full grid scan rather than argued:
    /// 200 000 random documents (1–5 regions, off-grid starts, sub-step lengths, three lanes),
    /// zero disagreements.
    ///
    /// ⚠️ EVERY EMITTED TICK LIES INSIDE A REGION ON THIS LANE, and that is the one thing
    /// `isSampleable` decides here that a caller can observe. A looser enumeration would
    /// still give every caller the same VERDICT, because `activeRegion` re-checks containment
    /// itself — the set would simply stop meaning what its name says. `TheWorkstation
    /// PlaysTheTimelineTests` asserts the property rather than the verdict for exactly that
    /// reason; a gate whose removal changes no answer has to be pinned where it is visible.
    public static func candidateSampleTicks(in document: TimelineDocument,
                                            laneID: UUID) -> [Int] {
        let lane = document.regions.filter { $0.laneID == laneID }
        var ticks = Set<Int>()
        for (i, region) in lane.enumerated() {
            if isSampleable(region) {
                ticks.insert(firstSampleTick(atOrAfter: region.startTick))
            }
            for (j, other) in lane.enumerated() where j != i {
                guard other.endTick > region.startTick,
                      other.endTick < region.endTick else { continue }
                let t = firstSampleTick(atOrAfter: other.endTick)
                if t >= region.startTick, t < region.endTick { ticks.insert(t) }
            }
        }
        return ticks.sorted()
    }

    /// Whether the lane's active region CHANGED moving from `fromTick` to `toTick` —
    /// the onset that should (re)load content. `.load` when a new region became
    /// active, `.clear` when the playhead left a region into a gap, `.unchanged`
    /// otherwise. Order-independent, so it also handles a loop wrap (end → 0) when
    /// the player passes the real from/to ticks.
    public static func laneEvent(in document: TimelineDocument, laneID: UUID,
                                 fromTick: Int, toTick: Int) -> LaneEvent {
        let before = activeRegion(in: document, laneID: laneID, at: fromTick)
        let after = activeRegion(in: document, laneID: laneID, at: toTick)
        if before?.id == after?.id { return .unchanged }
        if let after { return .load(after) }
        return .clear
    }

    /// One lane's scheduling event — the multi-roll fan-out unit (Equatable so the
    /// whole per-lane list is unit-testable).
    public struct LaneScheduleEvent: Equatable {
        public let laneID: UUID
        public let event: LaneEvent
        public init(laneID: UUID, event: LaneEvent) {
            self.laneID = laneID
            self.event = event
        }
    }

    /// The scheduling event for EVERY non-bio MIDI lane moving `fromTick`→`toTick`,
    /// in lane order — the multi-roll fan-out of `laneEvent`. Today only the single
    /// `rollLaneID` is played; the playback fan-out cycle rides this to drive one
    /// roll+voice per lane. Pure — no audio, no per-lane state yet.
    public static func laneEvents(in document: TimelineDocument,
                                  fromTick: Int, toTick: Int) -> [LaneScheduleEvent] {
        document.midiLaneIDs.map { id in
            LaneScheduleEvent(laneID: id,
                              event: laneEvent(in: document, laneID: id,
                                               fromTick: fromTick, toTick: toTick))
        }
    }

    /// The scheduling event for every VIDEO lane moving `fromTick`→`toTick`, in lane
    /// order — the video analog of `laneEvents`. Pure/additive; no live consumer
    /// today (the video-lane playback engine was removed in the pure-instrument cut;
    /// the residual video-lane model retires with the DAW model in a later slice).
    public static func videoLaneEvents(in document: TimelineDocument,
                                       fromTick: Int, toTick: Int) -> [LaneScheduleEvent] {
        document.videoLaneIDs.map { id in
            LaneScheduleEvent(laneID: id,
                              event: laneEvent(in: document, laneID: id,
                                               fromTick: fromTick, toTick: toTick))
        }
    }
}

public extension TimelineDocument {

    /// The MIDI lane that owns the ONE shared piano-roll/pattern slot: the first
    /// non-bio MIDI lane (mirrors `rollSlotGain`'s ownership rule). `nil` when the
    /// timeline has no MIDI lane. Multi-roll (every MIDI lane its own voice) is the
    /// later A1 step; today one MIDI lane drives the roll, like ArrangementPlayer.
    var rollLaneID: UUID? {
        lanes.first(where: { $0.kind == .midi && !$0.isBio })?.id
    }

    /// The audio lanes (in order). Each gets its own `AudioRegionSink`; the production sink
    /// is `TimelineAudioSink` (`EchoelmusicApp` injects it as `makeSink`).
    /// ⛔ This line said "on its own AudioClipPlayer" (#1379). That type has ZERO callers and
    /// ZERO tests — naming it here sent anyone debugging timeline audio into a file that has
    /// never executed. A comment mention is not a caller, and thirteen of them across eight
    /// files made a dead 380-line class read as the engine.
    var audioLaneIDs: [UUID] {
        lanes.filter { $0.kind == .audio && !$0.isBio }.map(\.id)
    }

    /// Founder v287/v288 "Es wird kein midi Clip erzeugt": transport ▶ must engage
    /// the ARRANGEMENT engine (TimelineRegionPlayer) only when there is arrangement
    /// content BEYOND the primary roll lane's auto-composer mirror — the visible,
    /// editable MIDI-clip tile that Generate now places on the roll lane. A project
    /// whose ONLY region is that mirror still plays the LIVE bio-generative loop on ▶
    /// (`pattern.play()`), so the core "the music evolves with the body" behaviour is
    /// NEVER replaced by a frozen region. Any real arrangement content — a region on
    /// a secondary lane, an audio/video region, or a USER (non-composer) clip on the
    /// roll lane — engages the arrangement exactly as before. `isComposerOwned` maps a
    /// clipID to its ownership (from ClipStore); an unknown clip counts as content.
    func hasArrangementContent(isComposerOwned: (UUID) -> Bool) -> Bool {
        let roll = rollLaneID
        return regions.contains { region in
            !(region.laneID == roll && isComposerOwned(region.clipID))
        }
    }

    /// The video lanes (in order), mirroring `audioLaneIDs`. Pure/additive; the
    /// video-lane playback engine that read this was removed in the pure-instrument
    /// cut — the residual accessor retires with the DAW model in a later slice.
    var videoLaneIDs: [UUID] {
        lanes.filter { $0.kind == .video && !$0.isBio }.map(\.id)
    }

    /// Every non-bio MIDI lane, in order — the fan-out set for multi-roll playback.
    /// `rollLaneID` (the first) stays the single-slot owner until the fan-out lands.
    /// ⛔ This sentence ended "so this is additive: nothing reads it on the playback path
    /// yet", and that was already false when it was written: `MultiRollFanout.activeLoads`
    /// reads it, and `primeSecondaryLanes` calls that on every play and every locate.
    /// ⛔ #1437 added "`TimelineRegionPlayer.canPlay` is the third reader — this accessor
    /// plus `audioLaneIDs` IS that answer", and #1438 made it FALSE in the same week: the
    /// repaired predicate walks `document.lanes` itself, because it needs each driven lane's
    /// KIND to check it against its clip's, and a list of ids has thrown that away. The
    /// `!isBio` + kind filter is now written twice — deliberately, and the two must stay in
    /// step; `TheWorkstationPlaysTheTimelineTests` drives a bio lane against both.
    var midiLaneIDs: [UUID] {
        lanes.filter { $0.kind == .midi && !$0.isBio }.map(\.id)
    }
}

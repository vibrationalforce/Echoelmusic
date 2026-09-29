// WorkstationSummary.swift
// Echoel — #1436, founder Phase 3. The READ-ONLY projection of `TimelineDocument` that the
// Workstation surface renders.
//
// ⭐ WHY A VALUE TYPE AND NOT A `View` COMPUTING THIS INLINE, which is the shorter thing to
// write. `EchoelStudioView` is `private` SwiftUI the blocking bundle cannot construct, so
// every claim about a computed-in-the-body summary would be a SOURCE-TEXT SCAN — the weak
// kind (`Tests/CISmoke/CLAUDE.md` §1). Pulled out here, Foundation-only and `public`, the
// arithmetic is DRIVEN end to end: empty document, orphaned region, song length, the honest
// per-kind playability. The view then only lays out numbers it was handed.
//
// ⚠️ IT OWNS NOTHING. No document, no store, no persistence, no clock, no mutation — it is a
// pure function of the document it is given, recomputed on each render of a cold surface.
// `TimelineStore` remains the one owner of timeline state (founder Phase 3 §2).
//
// ⛔ AND IT MUST NOT INVENT A CAPABILITY. Every field below is already represented in the
// current models; nothing here is a placeholder for a feature that does not exist. The one
// field that looks like an opinion — `playsOnTheTimeline` — is `ClipKind.isPlayable`, whose
// own declaration says it in as many words: *"the arrangement may show the other lanes, but
// must not pretend they play."* Reading that flag is the opposite of inventing one.

import Foundation

/// What the Workstation surface shows: lanes, their regions, and the song's extent.
public struct WorkstationSummary: Equatable, Sendable {

    /// One lane, flattened with the numbers the surface needs beside it.
    public struct LaneRow: Equatable, Sendable, Identifiable {
        public let id: UUID
        public let name: String
        public let kind: ClipKind
        /// The bio lane renders a recorded automation curve rather than media regions.
        public let isBio: Bool
        /// Regions filed against THIS lane. Zero is a real answer and is shown as one.
        public let regionCount: Int
        /// Where this lane's content starts and ends, in song-absolute ticks. `nil` when the
        /// lane is empty — deliberately optional rather than `0…0`, because "starts at bar 1
        /// and is empty" and "has nothing" are different sentences and only one is true.
        public let firstTick: Int?
        public let lastTick: Int?
        public let isMuted: Bool
        public let isSoloed: Bool
        /// Persisted record-arm INTENT. Arming never records by itself — `TimelineLane.isArmed`
        /// says so at its own declaration, and the surface must not upgrade it to "recording".
        public let isArmed: Bool
        public let instrument: TrackInstrument?
        /// `ClipKind.isPlayable` — whether a shipped engine drives this kind on the timeline.
        public let playsOnTheTimeline: Bool
    }

    public let lanes: [LaneRow]
    /// Every region in the document, including any the lane rows cannot show.
    public let regionCount: Int
    /// Regions whose `laneID` names no lane in this document.
    ///
    /// ⚠️ THIS FIELD IS WHY THE TWO COUNTS CAN BE READ TOGETHER. Without it a surface showing
    /// "3 lanes · 12 regions" beside per-lane rows summing to 9 would simply be wrong on
    /// screen, with nothing naming the missing three. A decoded document CAN carry them: the
    /// lane decode is `try?`-tolerant (a lane whose instrument case no longer exists is
    /// dropped) while its regions are not, which is exactly the #167 shape.
    public let orphanRegionCount: Int
    /// Song-absolute end of the last region, in ticks. `0` for a document with no regions.
    public let lengthTicks: Int
    /// Arrangement automation lanes (`TimelineDocument.automation`), counted, not rendered.
    public let automationLaneCount: Int

    /// Nothing to show. Both halves are required: a document can carry lanes and no regions
    /// (the bootstrap migration seeds an empty `Audio 1` on purpose), and that is NOT empty —
    /// it is a song with two tracks and no parts yet.
    public var isEmpty: Bool { lanes.isEmpty && regionCount == 0 }

    /// Length rounded UP to whole bars, which is how a musician reads a song's extent. A
    /// region ending mid-bar still occupies that bar.
    public var lengthBars: Int {
        guard lengthTicks > 0 else { return 0 }
        let perBar = TimelineTime.ticksPerBar
        guard perBar > 0 else { return 0 }
        return (lengthTicks + perBar - 1) / perBar
    }

    public init(document: TimelineDocument) {
        var perLane: [UUID: (count: Int, first: Int, last: Int)] = [:]
        var end = 0
        var orphans = 0
        let laneIDs = Set(document.lanes.map(\.id))

        for region in document.regions {
            let regionEnd = region.startTick + region.lengthTicks
            end = Swift.max(end, regionEnd)
            guard laneIDs.contains(region.laneID) else { orphans += 1; continue }
            if var seen = perLane[region.laneID] {
                seen.count += 1
                seen.first = Swift.min(seen.first, region.startTick)
                seen.last = Swift.max(seen.last, regionEnd)
                perLane[region.laneID] = seen
            } else {
                perLane[region.laneID] = (1, region.startTick, regionEnd)
            }
        }

        self.lanes = document.lanes.map { lane in
            let seen = perLane[lane.id]
            return LaneRow(id: lane.id,
                           name: lane.name,
                           kind: lane.kind,
                           isBio: lane.isBio,
                           regionCount: seen?.count ?? 0,
                           firstTick: seen?.first,
                           lastTick: seen?.last,
                           isMuted: lane.isMuted,
                           isSoloed: lane.isSoloed,
                           isArmed: lane.isArmed,
                           instrument: lane.builtinInstrument,
                           playsOnTheTimeline: lane.kind.isPlayable)
        }
        self.regionCount = document.regions.count
        self.orphanRegionCount = orphans
        self.lengthTicks = end
        self.automationLaneCount = document.automation.count
    }

    // MARK: - Spoken and printed forms

    /// One-bar-indexed bar number for a song-absolute tick — what a musician calls that spot.
    /// Bar 1 is tick 0; a negative tick cannot occur (`TimelineRegion` clamps `startTick` at
    /// its own initialiser) and is folded to bar 1 rather than producing a bar 0 or −1.
    public static func barNumber(forTick tick: Int) -> Int {
        let perBar = TimelineTime.ticksPerBar
        guard perBar > 0, tick > 0 else { return 1 }
        return tick / perBar + 1
    }

    /// The bar a region ENDING at `tick` last occupies.
    ///
    /// ⛔ THIS EXISTS BECAUSE THE OBVIOUS VERSION WAS OFF BY ONE BAR, caught by driving the
    /// arithmetic rather than reading it. `lastTick` is the EXCLUSIVE end — a one-bar part
    /// starting at bar 3 ends at tick 4·ticksPerBar, so `barNumber(forTick:)` called on it
    /// answers "bar 4" and the surface printed "bars 3–4" for a part that occupies exactly
    /// one bar. The end is a BOUNDARY, not a position: the last bar with content in it is the
    /// bar holding the final tick, one before the boundary.
    ///
    /// ⚠️ `TimelineRegion` clamps `lengthTicks` to at least 1 at its own initialiser, so
    /// `end - 1` can never fall below its own start; the `max(0,…)` is for a hand-built or
    /// legacy-decoded 0 rather than for anything this build can construct.
    public static func endBarNumber(forTick tick: Int) -> Int {
        barNumber(forTick: Swift.max(0, tick - 1))
    }

    /// "Bar 12 · Beat 3" — where the playing song IS (design D1, `SongPositionReadout`). Always
    /// names the beat, unlike `SessionGrid.label`, which drops it on a bar line: a readout that
    /// changes WIDTH on every downbeat jitters beside the button it sits next to. The bar comes
    /// from `barNumber(forTick:)`, the one bar-number rule (#416); a negative tick folds to the
    /// top like it does there.
    public static func positionText(forTick tick: Int) -> String {
        let t = Swift.max(0, tick)
        let perBar = TimelineTime.ticksPerBar
        let perBeat = TimelineTime.ticksPerBeat
        let beat = perBar > 0 && perBeat > 0 ? (t % perBar) / perBeat + 1 : 1
        return "Bar \(barNumber(forTick: t)) · Beat \(beat)"
    }

    /// "bar 3" or "bars 3 to 7" — the span a lane's content occupies, said once so the printed
    /// and spoken forms cannot disagree (#416).
    public static func barSpan(firstTick: Int, lastTick: Int, joiner: String) -> String {
        let from = barNumber(forTick: firstTick)
        let to = endBarNumber(forTick: lastTick)
        return from >= to ? "bar \(from)" : "bars \(from)\(joiner)\(to)"
    }

    /// The lane row as one sentence, for VoiceOver — the visual row is several small pieces of
    /// text and a symbol, which a screen reader would otherwise announce as disconnected
    /// fragments. Says only what the models say.
    /// Say WHY, not just that it is off. "Play timeline, dimmed" tells a VoiceOver user
    /// nothing they can act on; "no parts on a track that plays" does. Lives HERE rather
    /// than on the view for the reason the rest of this type does: a `public` Foundation-only
    /// function is DRIVEN by the blocking bundle, while the same words inside a `private`
    /// SwiftUI body would only ever be scanned (#1436's split, kept).
    public static func transportHint(playing: Bool, startable: Bool) -> String {
        // The Workstation's Stop is the ONE Stop (`ProjectTransport.stop`) since the project
        // header — so its hint is the one Stop's hint, not a narrower sentence that said
        // nothing about the instrument or the session it also ends (review of 09d35f56e, MED-2).
        if playing { return ProjectTransport.stopHint }
        if startable { return "Plays the arrangement from the top on the shared transport." }
        return "Unavailable: this song has no parts on a track that plays."
    }

    /// The Click switch's hint (design slice 10). Says what the switch does and no more: the
    /// click plays at the current tempo, and while the song plays it lands on the transport's
    /// beats (54b2e28cf). It does not promise a count-in or a pre-roll — there is none.
    public static func clickHint(on: Bool) -> String {
        on ? "Turns the click off."
           : "Plays a steady click at the current tempo, on the song's beats while it plays."
    }

    /// The sentence beside the button: what Play does, and nothing it cannot. ⛔ Until Phase 3 /
    /// M1 it ended "— this view still does not edit them", and that denial had been false since
    /// WA4 put move, trim and split on the part bar; with the note editor it would deny the
    /// surface's own purpose. A caption states what the BUTTON does — it is not where the
    /// editing boundary is kept (that is each editor's own refusal sentence).
    ///
    /// ⛔ The playing line said "from the top" whatever the start (design D1b): Play from a part
    /// and a scene launch both start mid-song, and the caption denied it beside the position
    /// readout that showed otherwise. `fromTick` is where THIS take was started; the transport
    /// starts on that tick's bar, so the bar is named through the one bar-number rule.
    public static func transportCaption(playing: Bool, startable: Bool, fromTick: Int) -> String {
        if playing {
            let bar = barNumber(forTick: fromTick)
            return bar > 1 ? "Playing from bar \(bar) on the shared transport."
                           : "Playing from the top on the shared transport."
        }
        if startable { return "Plays the song's parts from the top." }
        return "Nothing to play yet."
    }

    public static func spokenDescription(of row: LaneRow) -> String {
        var parts: [String] = [row.name, row.kind.displayName]
        if let instrument = row.instrument { parts.append(instrument.displayName) }
        if row.isBio { parts.append("bio automation lane") }
        switch row.regionCount {
        case 0:  parts.append("no parts")
        case 1:  parts.append("1 part")
        default: parts.append("\(row.regionCount) parts")
        }
        if let first = row.firstTick, let last = row.lastTick, row.regionCount > 0 {
            parts.append(barSpan(firstTick: first, lastTick: last, joiner: " to "))
        }
        if row.isMuted { parts.append("muted") }
        if row.isSoloed { parts.append("soloed") }
        if row.isArmed { parts.append("armed to record") }
        // Said LAST and only when it is the bad news, so the common case is not padded with a
        // reassurance nobody asked for.
        if !row.playsOnTheTimeline && row.regionCount > 0 {
            parts.append("no timeline engine plays this kind yet")
        }
        return parts.joined(separator: ", ")
    }
}

// TheWorkstationHasADoorTests.swift
// Echoel — #1436 founder Phase 3, amended by #1437 (Phase 4). The Workstation surface is
// REACHABLE, it projects the song faithfully, and it still cannot EDIT it.
//
// WHAT THIS FILE PROVES: a production path `launch → Instrument → Workstation → back to
// Instrument` exists, it shows the arrangement `TimelineStore` already owns, and it changes
// nothing about that document.
//
// ⛔ CLAIM H USED TO LIVE HERE AND ASSERTED THE OPPOSITE OF TODAY'S TRUTH — "the timeline
// player still has no production caller". #1437 is the commit its own failure message named,
// so it was INVERTED rather than deleted or routed around: the new invariant is "exactly the
// Workstation path may call it, and nothing else", and it lives in
// `TheWorkstationPlaysTheTimelineTests`. A counterweight that would have to be aliased past
// is not a counterweight; retiring it in the commit that falsifies it is the only honest
// move, and leaving this tombstone is what stops the next reader hunting for a claim H that
// was silently dropped.
//
// ⚠️ WHICH HALF IS WHICH (§1). Claims 1–7 are END-TO-END BEHAVIOUR: `WorkstationSummary` is
// `public`, Foundation-only and a pure function of the document handed to it, so the
// arithmetic a reviewer would otherwise have to trust — empty vs. seeded, per-lane counts,
// the orphaned region, bar rounding, the spoken row — is DRIVEN. Claims A–H are SOURCE-TEXT
// SCANS: `EchoelStudioView` is a 12 000-line `private` SwiftUI view this bundle cannot
// construct, and `WorkstationView` is `@Environment`-resolving SwiftUI behind
// `#if canImport(SwiftUI)`. **That the chip renders, that a tap swaps the plate, and that
// VoiceOver reads the rows in order is a DEVICE PROBE and is OPEN.**
//
// ⭐ THE SPLIT IS A DESIGN DECISION IN THE SOURCE, NOT LUCK. The summary was pulled out of
// the view precisely so these seven claims could be behaviour rather than seven more scans —
// the weak kind. If a later slice moves the arithmetic back into a `body`, these go with it
// and the file loses most of its value; that is the trade, stated so it is made knowingly.
//
// ⚠️ HONEST GRADING (#433/#464). This file **cannot be graded against the parent tree at
// all**: every behaviour claim names `WorkstationSummary`, which does not exist at
// `22816c9fd`, so the bundle does not compile there and NO claim has a verdict — the #488
// ambiguity said out loud rather than left to read as "green against its own tree".
// Transcribed by hand instead (a Python rebuild of the summary's arithmetic and of
// `SourceText.codeOnly`, each needle driven separately against `git show HEAD:` and the
// worktree):
//   · claims 1–7 — FORWARD guards. They drive a type this same commit adds and could never
//     have been red. Booking them as regressions would be the flattering-direction defect.
//   · claims A, B, C — RED on the parent for their named reasons (no `.workstation` case, no
//     `workstationPanel`, no `WorkstationView.swift`). ONE absence reported three times
//     (#486), not three findings.
//   · claims D, E, F — could not have run on the parent: their subject files do not exist.
//     They are the ones that matter going FORWARD, which is why they are here at all.
//   · claim G — GREEN on BOTH trees, and it is the content (#343): the counterweight
//     against a Workstation that hides the instrument. #1437 deepened it from "the strip
//     still lists `.sound`" to "tapping a chip actually routes to it" — an array membership
//     check cannot fail for the reason the claim's NAME gives (#367), and the mutation that
//     proves the difference is written at the assertion.
//
// ⚠️ `SourceText.codeOnly` stays in use, but its load-bearing CASE moved with claim H. It
// used to be: `WorkstationView`'s header named `TimelineRegionPlayer.play(…)` while claim F's
// negative scanned for that spelling. The header still names it and the file now genuinely
// calls it, so that particular flip is gone from here — it reappears, sharper, in
// `TheWorkstationPlaysTheTimelineTests`, where the question is HOW MANY call sites exist and
// a comment would be counted as one. Measured on this file's needles today — all thirteen of
// them, not a sample: PROPHYLAKTISCH, 0 of 13 verdicts flip raw vs. stripped. It stays in use
// because claims D and E are ABSENCE scans over two files whose headers are free to start
// naming a forbidden spelling at any time.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheWorkstationHasADoorTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let view = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let summary = "Sources/Echoelmusic/Studio/WorkstationSummary.swift"
    private static let player = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"

    // MARK: - 1. BEHAVIOUR — an untouched install shows an empty state, not a fake song

    func testAnEmptyDocumentReadsAsEmpty() {
        let summary = WorkstationSummary(document: TimelineDocument())
        XCTAssertTrue(summary.isEmpty)
        XCTAssertEqual(summary.lanes.count, 0)
        XCTAssertEqual(summary.regionCount, 0)
        XCTAssertEqual(summary.lengthBars, 0, """
            An empty song is 0 bars long, not 1. Rounding UP must not manufacture a bar that \
            contains nothing — the surface would then claim a song where there is none.
            """)
    }

    // MARK: - 2. BEHAVIOUR — lanes without parts are NOT an empty song

    func testSeededLanesWithNoPartsAreNotEmpty() {
        // This is the shape `TimelineStore.migrate(sections:)` produces on a fresh install: it
        // seeds an empty `Audio 1` beside the MIDI lane on purpose (founder: "mehrere").
        let doc = TimelineDocument(lanes: [TimelineLane(name: "MIDI 1", kind: .midi),
                                           TimelineLane(name: "Audio 1", kind: .audio)])
        let summary = WorkstationSummary(document: doc)
        XCTAssertFalse(summary.isEmpty, """
            Two tracks and no parts is a SONG WITH TWO TRACKS, not an empty document. Showing \
            the empty state here would hide the multi-lane shape the bootstrap deliberately \
            seeds, and the user would see "no arrangement" over an arrangement.
            """)
        XCTAssertEqual(summary.lanes.map(\.regionCount), [0, 0])
        XCTAssertEqual(summary.lengthBars, 0, "…and it is still 0 bars long.")
    }

    // MARK: - 3. BEHAVIOUR — parts are counted against their own lane

    func testPartsAreCountedAgainstTheirOwnLane() throws {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        let audio = TimelineLane(name: "Audio 1", kind: .audio)
        let bar = TimelineTime.ticksPerBar
        let doc = TimelineDocument(
            lanes: [midi, audio],
            regions: [TimelineRegion(laneID: midi.id, clipID: UUID(),
                                     startTick: 0, lengthTicks: bar * 2),
                      TimelineRegion(laneID: midi.id, clipID: UUID(),
                                     startTick: bar * 4, lengthTicks: bar),
                      TimelineRegion(laneID: audio.id, clipID: UUID(),
                                     startTick: bar * 2, lengthTicks: bar)])
        let summary = WorkstationSummary(document: doc)

        let midiRow = try XCTUnwrap(summary.lanes.first { $0.id == midi.id })
        let audioRow = try XCTUnwrap(summary.lanes.first { $0.id == audio.id })
        XCTAssertEqual(midiRow.regionCount, 2)
        XCTAssertEqual(audioRow.regionCount, 1)
        XCTAssertEqual(summary.regionCount, 3)
        XCTAssertEqual(summary.orphanRegionCount, 0)

        XCTAssertEqual(midiRow.firstTick, 0)
        XCTAssertEqual(midiRow.lastTick, bar * 5, """
            A lane's extent is the END of its last region, not that region's start. A surface \
            reading the start would say a two-bar part occupies one point in time.
            """)
        XCTAssertEqual(WorkstationSummary.barNumber(forTick: midiRow.firstTick ?? -1), 1,
                       "Tick 0 is bar ONE — musicians count from 1, arrays from 0.")
        XCTAssertEqual(WorkstationSummary.barNumber(forTick: bar * 4), 5)
        XCTAssertEqual(summary.lengthBars, 5)

        // ⛔ THE END IS A BOUNDARY, NOT A POSITION, and the obvious reading was off by one bar.
        // `lastTick` is EXCLUSIVE: this lane's last part starts at bar 5 and is one bar long,
        // so it ends at the tick where bar 6 begins. `barNumber` on that answers 6 and the
        // surface printed "bars 1–6" for content that stops at the end of bar 5.
        XCTAssertEqual(WorkstationSummary.endBarNumber(forTick: midiRow.lastTick ?? 0), 5, """
            The last OCCUPIED bar must be the one holding the final tick, not the one the \
            exclusive end points at.
            """)
        XCTAssertEqual(WorkstationSummary.barSpan(firstTick: bar * 2, lastTick: bar * 3,
                                                  joiner: " to "), "bar 3", """
            A one-bar part occupies ONE bar and must say so. "bars 3 to 4" would describe two.
            """)
        XCTAssertEqual(WorkstationSummary.barSpan(firstTick: 0, lastTick: bar * 5,
                                                  joiner: " to "), "bars 1 to 5")
    }

    // MARK: - 4. BEHAVIOUR — an orphaned part is counted and NOT hidden

    func testAnOrphanedPartIsCountedRatherThanSilentlyDropped() {
        let midi = TimelineLane(name: "MIDI 1", kind: .midi)
        let bar = TimelineTime.ticksPerBar
        let doc = TimelineDocument(
            lanes: [midi],
            regions: [TimelineRegion(laneID: midi.id, clipID: UUID(),
                                     startTick: 0, lengthTicks: bar),
                      // A region whose lane is gone — reachable today, because the lane decode
                      // is `try?`-tolerant (an unknown instrument case drops the LANE) while
                      // the region decode is not. That is the #167 shape exactly.
                      TimelineRegion(laneID: UUID(), clipID: UUID(),
                                     startTick: bar, lengthTicks: bar)])
        let summary = WorkstationSummary(document: doc)

        XCTAssertEqual(summary.regionCount, 2)
        XCTAssertEqual(summary.lanes.map(\.regionCount).reduce(0, +), 1)
        XCTAssertEqual(summary.orphanRegionCount, 1, """
            Without this the surface prints "1 track · 2 parts" beside rows summing to 1, and \
            NOTHING on screen names the missing one. A total that disagrees with the rows under \
            it is worse than either number alone.
            """)
        XCTAssertEqual(summary.lengthBars, 2, """
            …and the song is still as long as its furthest part. An orphan occupies time even \
            though no row shows it.
            """)
    }

    // MARK: - 5. BEHAVIOUR — a part ending mid-bar still occupies that bar

    func testLengthRoundsUpToWholeBars() {
        let lane = TimelineLane(name: "MIDI 1", kind: .midi)
        let bar = TimelineTime.ticksPerBar
        let doc = TimelineDocument(
            lanes: [lane],
            regions: [TimelineRegion(laneID: lane.id, clipID: UUID(),
                                     startTick: 0, lengthTicks: bar + 1)])
        XCTAssertEqual(WorkstationSummary(document: doc).lengthBars, 2, """
            One tick past bar 1 is a two-bar song. Truncating would print "1 bar" over content \
            that visibly runs past the bar line.
            """)
    }

    // MARK: - 6. BEHAVIOUR — the surface never claims a lane plays when no engine drives it

    func testALaneOnlyClaimsToPlayWhenAnEngineDrivesItsKind() {
        let doc = TimelineDocument(lanes: [TimelineLane(name: "MIDI 1", kind: .midi),
                                           TimelineLane(name: "Audio 1", kind: .audio),
                                           TimelineLane(name: "Visual", kind: .visual)])
        let flags = WorkstationSummary(document: doc).lanes.map(\.playsOnTheTimeline)
        XCTAssertEqual(flags, [ClipKind.midi.isPlayable,
                               ClipKind.audio.isPlayable,
                               ClipKind.visual.isPlayable], """
            The flag must be `ClipKind.isPlayable` and never a second opinion (#416). That \
            declaration already says it: "the arrangement may show the other lanes, but must \
            not pretend they play." Restating the set here would be a copy that can drift the \
            day an engine ships.
            """)
        XCTAssertTrue(flags.contains(false), """
            …and at least one kind must currently read FALSE, or this claim is comparing a \
            constant with itself and would survive `isPlayable` becoming `true` everywhere.
            """)
    }

    // MARK: - 7. BEHAVIOUR — the spoken row carries the states a sighted user sees

    func testTheSpokenRowNamesTheStatesTheBadgesShow() {
        let lane = TimelineLane(name: "Bass", kind: .midi, isMuted: true, isSoloed: false,
                                builtinInstrument: .subBass, isArmed: true)
        let bar = TimelineTime.ticksPerBar
        let doc = TimelineDocument(
            lanes: [lane],
            regions: [TimelineRegion(laneID: lane.id, clipID: UUID(),
                                     startTick: bar * 2, lengthTicks: bar)])
        let row = WorkstationSummary(document: doc).lanes[0]
        let spoken = WorkstationSummary.spokenDescription(of: row)

        XCTAssertTrue(spoken.contains("Bass"), spoken)
        XCTAssertTrue(spoken.contains(TrackInstrument.subBass.displayName), spoken)
        XCTAssertTrue(spoken.contains("1 part"), spoken)
        XCTAssertTrue(spoken.contains("bar 3"), spoken)
        XCTAssertFalse(spoken.contains("bar 4"), """
            One bar starting at bar 3 occupies bar 3 and nothing else. Saying "bar 3 to bar 4" \
            describes twice the music — the exclusive-end off-by-one, spoken. (Spoken: \(spoken))
            """)
        XCTAssertTrue(spoken.contains("muted"), """
            The MUTE badge is a three-letter tag on screen. If the spoken form drops it, a \
            VoiceOver user is told a track is in the mix that is not. (Spoken: \(spoken))
            """)
        XCTAssertTrue(spoken.contains("armed to record"), """
            ARM is persisted INTENT, not recording — `TimelineLane.isArmed` says so at its own \
            declaration. It must be spoken, and it must not be spoken as "recording".
            """)
        XCTAssertFalse(spoken.contains("soloed"), """
            Only states that are ON may be announced. Reading "not soloed, not muted" on every \
            row is the audio equivalent of three greyed-out badges — noise that trains the \
            listener to skip the line that will one day carry information.
            """)
    }

    // MARK: - A. SCAN — a production door exists

    func testTheStripCarriesAWorkstationChip() throws {
        let src = try code(at: Self.studio)

        guard src.contains("private static let studioChips: [StudioMenu]") else {
            throw AnchorMissing(reason: """
                `studioChips` is gone or renamed; every claim in this section is anchored on \
                it. Re-anchor rather than letting the absence read as a pass.
                """)
        }
        XCTAssertTrue(Self.chipList(in: src).contains(".workstation"), """
            The Workstation has no chip in the standing strip (extracted: \
            \(Self.chipList(in: src))). A `StudioMenu` case that is NOT in this array is not \
            unreachable — the chrome doors reach filtered cases — but nothing else opens this \
            one, so filtering it out makes the surface doorless.
            """)
        XCTAssertTrue(src.contains("case .workstation: return \"Workstation\""), """
            The chip must be LABELLED, and with the founder's own word: the phase brief names \
            the path "Instrument → Workstation → back", and a chip saying anything else makes \
            that path unfindable by the name it was specified under.
            """)
        XCTAssertTrue(src.contains("case .workstation: return \"Workstation — the arrangement: tracks and parts, read-only\""), """
            The SPOKEN name must say read-only. A door that only looks is the one kind a \
            VoiceOver user cannot discover by feeling around inside it (#482).
            """)
    }

    // MARK: - B. SCAN — the door reaches the surface

    func testTheChipReachesTheWorkstationView() throws {
        let src = try code(at: Self.studio)
        XCTAssertTrue(src.contains("case .workstation: return AnyView(workstationPanel)"), """
            `dropdownContent` must route the case to a panel. Without the routing the chip \
            selects a menu the plate cannot render — the "lying tab" shape.
            """)
        let panel = try declarationBody(of: "private var workstationPanel: some View {",
                                        in: Self.studio)
        XCTAssertTrue(panel.contains("WorkstationView()"), """
            The panel must construct the real surface. A panel that inlined the arrangement \
            here would put the whole thing in the 12 000-line view whose ROOT body evaluates \
            `dropdownContent` permanently (#479).
            """)
    }

    // MARK: - C. SCAN — the surface reads TimelineStore.document

    func testTheSurfaceReadsTheOneTimelineOwner() throws {
        let src = try code(at: Self.view)
        XCTAssertTrue(src.contains("@Environment(TimelineStore.self) private var timeline"), """
            The surface must read the injected `TimelineStore` — the one owner of timeline \
            state (founder Phase 3 §2), injected once in `EchoelmusicApp`.
            """)
        XCTAssertTrue(src.contains("WorkstationSummary(document: timeline.document)"), """
            …and it must read that owner's DOCUMENT through the pure projection, so what the \
            surface shows and what claims 1–7 drive are the same arithmetic (#416).
            """)
    }

    // MARK: - D. SCAN — no second timeline model or store is created

    func testTheSurfaceCreatesNoSecondTimelineTruth() throws {
        for path in [Self.view, Self.summary] {
            let src = try code(at: path)
            for forbidden in ["TimelineStore(", "Arrangement(", "ArrangementStore(",
                              "TimelineDocument(", "TimelineLane(", "TimelineRegion("] {
                XCTAssertFalse(src.contains(forbidden), """
                    \(path) constructs `\(forbidden)`. A read-only surface may PROJECT the \
                    document it is handed and must never mint one: a second `TimelineDocument` \
                    is the Ω21 fork, and it would diverge from the persisted one silently.
                    """)
            }
        }
    }

    // MARK: - E. SCAN — no new persistence root

    func testTheSurfaceIntroducesNoPersistenceRoot() throws {
        for path in [Self.view, Self.summary] {
            let src = try code(at: path)
            for forbidden in ["AppGroupStore", "UserDefaults", "@AppStorage", "@SceneStorage",
                              "JSONEncoder", "JSONDecoder", "FileManager"] {
                XCTAssertFalse(src.contains(forbidden), """
                    \(path) names `\(forbidden)`. Phase 3 is explicitly a HOLD on persistence: \
                    a sixth root would have to be chosen between, migrated, and versioned, and \
                    none of that is this slice's to decide. ⭐ Audio Import V1 persists a clip \
                    and a region and does NOT break this: it writes through the EXISTING \
                    `ClipStore`/`TimelineStore` roots, from `AudioImport`, and the file copy \
                    goes through `MediaLibrary`, which has owned `Media/Audio` since before \
                    this surface existed. A NEW root is still the thing forbidden here.
                    """)
            }
        }
    }

    // MARK: - F. SCAN — no timeline EDITING api becomes reachable

    func testNoEditingApiIsReachableFromTheSurface() throws {
        let src = try code(at: Self.view)

        // Structural rather than a blacklist of `TimelineStore`'s ~40 mutators: ANY message to
        // the store other than reading `document` is out of bounds, so a mutator added
        // tomorrow is covered without this list being maintained (#367 — it must be able to
        // fail for its named reason, and a stale blacklist cannot).
        let messages = Self.messages(to: "timeline", in: src)
        XCTAssertFalse(messages.isEmpty, """
            The surface sends NOTHING to `timeline` — claim C says it must read `document`, so \
            this extraction is mis-anchored rather than the code being clean. Re-anchor.
            """)
        XCTAssertEqual(Set(messages), ["document"], """
            The surface reaches `timeline` for \(Set(messages).sorted()). Read-only means \
            exactly one of those: `document`. Every other member of `TimelineStore` either \
            mutates the song or drives undo, and a read-only surface that can do either is not \
            the surface Phase 3 authorised.
            """)
        // ⛔ A `XCTAssertFalse(src.contains(".play("))` stood here and was correct for Phase 3.
        // #1437 is the commit that makes it false BY DESIGN, so it is retired here and
        // REPLACED — not weakened — by the caller invariant in
        // `TheWorkstationPlaysTheTimelineTests`, which pins the exact opposite with a number:
        // one call site, on the player binding, in this file. The boundary this claim owns is
        // narrower and unchanged: the surface may start the song, never EDIT it.
        //
        // ⭐ AND AUDIO IMPORT V1 (2026-09-22) ADDED A WRITE TO THE SONG WITHOUT MOVING THIS
        // LINE, WHICH IS WORTH SAYING OUT LOUD BECAUSE IT LOOKS LIKE A MISS. The Workstation
        // now has an "Import Audio" row that ends with a `Clip` in `ClipStore` and a
        // `TimelineRegion` in `TimelineStore` — and the set above is still exactly
        // `["document"]`, measured, not assumed. The reason is the shape of the seam: the
        // view HANDS BOTH STORES OVER to `AudioImport.perform(pickedURL:clipStore:timeline:
        // bpm:)` and reads back a `Result`; every mutation is `AudioImport.commit`'s, in
        // `Sequencer/AudioImport.swift`, pinned there by
        // `TheWorkstationImportsAudioTests.testTheClipIsCommittedBeforeTheRegionAndOnlyOnSuccess`.
        //
        // ⚠️ SO READ THIS CLAIM FOR WHAT IT MEASURES, not for more. It proves this FILE sends
        // the store nothing but `document` — a real and useful boundary, because a mutator
        // called from a `body` is the shape that edits the song by accident. It does NOT
        // prove the surface causes no write; since the import door it demonstrably does. A
        // future slice that adds timeline EDITING must fail here, and it still would: an edit
        // is a message to the store, whoever ultimately sends it, and handing the store to a
        // helper that edits would be caught by that helper's own guard, not by this one.
    }

    // MARK: - G. COUNTERWEIGHT — the instrument stays reachable

    func testTheInstrumentIsStillWhereItWas() throws {
        let src = try code(at: Self.studio)
        XCTAssertTrue(src.contains("private var displayedMenu: StudioMenu { activeMenu ?? .sound }"), """
            An untouched launch must still land on Sound — the timbre panel, i.e. the \
            instrument itself. A Workstation that became the default plate would turn a \
            bio-reactive instrument into a project browser on first run.
            """)
        let list = Self.chipList(in: src)
        XCTAssertTrue(list.contains(".sound") && list.contains(".export"), """
            The rest of the strip must be untouched (extracted: \(list)). The Workstation is \
            ONE more chip in the existing selector, not a second shell: the path back to the \
            instrument is the same tap it always was.
            """)
        XCTAssertFalse(src.contains("activeMenu = .workstation"), """
            Nothing may force the plate to the Workstation. That would be a surface opening \
            itself — the shape #1298/#1300 had to make asymmetric on the bio source.
            """)

        // ⭐ #1437 — THE PART AN ARRAY-MEMBERSHIP CHECK CANNOT SEE. Everything above proves
        // the Sound chip is LISTED. It does not prove that TAPPING it goes anywhere: a chip
        // strip that renders `.sound` and routes it nowhere passes every assertion so far,
        // and "the path back to the instrument is the same tap it always was" is precisely
        // the sentence that would then be false. #367 — a claim must be able to fail for the
        // reason its NAME gives.
        //
        // The mutation this catches, and it was written down before the assertion was:
        //     if menu != .sound { activeMenu = menu }
        // i.e. every chip routes EXCEPT the one that leads home. Any conditional in the tap
        // action is that shape, so the check is "no branch stands between the tap and the
        // assignment" rather than a list of forbidden spellings.
        let action = try Self.tapAction(ofChipIn: src)
        XCTAssertTrue(action.contains("activeMenu = menu"), """
            The chip's tap action no longer assigns `activeMenu = menu` (it reads: \
            \(action.trimmingCharacters(in: .whitespacesAndNewlines))). Selecting a chip is \
            how every panel in the instrument is reached, the Workstation included, and the \
            way BACK from the Workstation is the Sound chip. If the routing moved, re-anchor \
            this on wherever it moved to — do not delete it.
            """)
        for branch in ["if ", "guard ", "switch ", " ? "] {
            XCTAssertFalse(action.contains(branch), """
                The chip's tap action contains `\(branch.trimmingCharacters(in: .whitespaces))`, \
                so the assignment is CONDITIONAL: some chip does not route. Which one is \
                invisible from here and that is the point — a selector that silently refuses \
                one destination is worse than one that refuses all, because it looks like it \
                works. Action read: \(action.trimmingCharacters(in: .whitespacesAndNewlines))
                """)
        }
    }

    /// The chip Button's ACTION closure — `return Button { … } label:` — comment-stripped.
    /// Scoped to the action on purpose: the LABEL legitimately carries ternaries (active vs.
    /// inactive styling), so a branch scan over the whole declaration would be red on correct
    /// code — measured, 3 hits of ` ? ` in the label today.
    private static func tapAction(ofChipIn source: String) throws -> String {
        guard let head = source.range(of: "private func menuChip(_ menu: StudioMenu) -> some View {"),
              let open = source.range(of: "return Button {", range: head.upperBound..<source.endIndex),
              let close = source.range(of: "} label:", range: open.upperBound..<source.endIndex)
        else {
            throw AnchorMissing(reason: """
                `menuChip`'s `return Button { … } label:` shape is gone, so the tap action \
                cannot be extracted and this claim would pass VACUOUSLY (#926). Re-anchor on \
                whatever builds a chip now.
                """)
        }
        return String(source[open.upperBound..<close.lowerBound])
    }

    // MARK: - Helpers

    private struct AnchorMissing: Error { let reason: String }

    /// The chip array's literal, or "" when the shape changed — claim A's anchor guard is what
    /// makes that distinguishable from an emptied strip (the `TheBioPanelDoorIsThePulsePill`
    /// form, reused rather than re-invented).
    private static func chipList(in source: String) -> String {
        guard let head = source.range(of: "private static let studioChips: [StudioMenu]"),
              let open = source.range(of: "[", range: head.upperBound..<source.endIndex),
              let close = source.range(of: "]", range: open.upperBound..<source.endIndex)
        else { return "" }
        return String(source[open.upperBound..<close.lowerBound])
    }

    /// Every member reached on `receiver` — the identifier written after each `receiver.`.
    /// Deliberately blunt: it over-collects rather than under-collects, because a member this
    /// missed would be the one that slipped through.
    private static func messages(to receiver: String, in source: String) -> [String] {
        var found: [String] = []
        var cursor = source.startIndex
        let needle = receiver + "."
        while let hit = source.range(of: needle, range: cursor..<source.endIndex) {
            cursor = hit.upperBound
            // Not a message if the character before the receiver continues an identifier
            // (`myTimeline.` is a different variable).
            if hit.lowerBound > source.startIndex {
                let before = source[source.index(before: hit.lowerBound)]
                if before.isLetter || before.isNumber || before == "_" || before == "." { continue }
            }
            var member = ""
            var index = hit.upperBound
            while index < source.endIndex, source[index].isLetter || source[index].isNumber
                    || source[index] == "_" {
                member.append(source[index])
                index = source.index(after: index)
            }
            if !member.isEmpty { found.append(member) }
        }
        return found
    }

    private func declarationBody(of key: String, in relativePath: String) throws -> String {
        let text = try code(at: relativePath)
        guard let start = text.range(of: key) else {
            throw AnchorMissing(reason: """
                \(relativePath) no longer declares `\(key)`. This scan is anchored on it; \
                re-anchor rather than deleting the assertion.
                """)
        }
        var depth = 0
        var index = text.index(before: start.upperBound)   // the opening brace itself
        while index < text.endIndex {
            if text[index] == "{" { depth += 1 }
            if text[index] == "}" {
                depth -= 1
                if depth == 0 { return String(text[start.upperBound..<index]) }
            }
            index = text.index(after: index)
        }
        throw AnchorMissing(reason: "Unbalanced braces after `\(key)` in \(relativePath).")
    }

    /// Comment-stripped source (#453 — the ONE definition of "code, not prose"). ⛔ This doc
    /// said the stripper is LOAD-BEARING here because claim F's `.play(` negative would read
    /// `WorkstationView`'s header sentence as a call site. That negative is retired (#1437),
    /// so on THIS file the stripper is now PROPHYLAKTISCH — measured, 0 of 10 verdicts flip.
    /// It is still required: the load-bearing case moved to the caller COUNT in
    /// `TheWorkstationPlaysTheTimelineTests`, where a comment counted as a call site would
    /// turn one caller into two and redden a correct tree.
    private func code(at relativePath: String) throws -> String {
        let path = try Self.treeRootStatic().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: """
                \(relativePath) is missing while the tree is present — it was renamed or moved. \
                Re-anchor this scan; do not let it skip.
                """)
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    /// Directory-gated, never per-file (#475): a `fileExists` bracket around each read turns
    /// the very catastrophe this file guards against into a green SKIP.
    private static func treeRootStatic() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Sources").path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
        }
        throw XCTSkip("No source tree next to the test bundle — nothing to scan.")
    }
}

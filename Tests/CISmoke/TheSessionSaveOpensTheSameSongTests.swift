// TheSessionSaveOpensTheSameSongTests.swift
// Echoel — WA4-S3: Save captures the Workstation's song, Open restores it (Acceptance Test A).
//
// WHAT THIS PINS. Before this slice "Save Project" kept only the Echoel take, and opening a
// saved project played whatever song was loaded before it (`SESSION_OWNERSHIP_CENSUS.md` §E).
// Acceptance Test A of the WA4 override: create → import → save → reopen → the SAME lane,
// region and clip (with its media reference). The risks:
// · the song is not captured, or is captured and not restored;
// · a project saved before Sessions existed opens onto the PREVIOUS project's song (the leak);
// · a Session this build cannot open changes anything before refusing;
// · the recovery slot skips a song with no composed take, so Open destroys it for good (H3);
// · a take that ARRIVES (Live Colabo, a shared file) replaces the user's song.
//
// 1. END-TO-END over REAL stores and a REAL `ProjectStore` on an isolated directory:
//    save → change the song → fresh store (the next launch) → Open → the saved song is back,
//    region, clip and media reference included; a legacy project opens on an empty song; a
//    refused project leaves both stores untouched. The app-wide stores are restored in `defer`
//    through the WA4-S1 replace APIs.
// 2. END-TO-END (pure): the rescue counts only the user's parts, never the composer's.
// 3. SOURCE: the library row is the one door that restores a song, and it asks for a refusal
//    BEFORE `open(_:)` and restores AFTER it; Live Colabo still calls `open(_:)` alone; Save and
//    the recovery slot both capture through `withSession`.
//
// Grading (§0, no Swift toolchain in a web session): claims 1–2 HAND-TRACED against
// `capturing`/`refusal`/`restoreSong` and the two stores' replace paths (not machine-
// transcribed — say so rather than imply it); claim 3's needles grepped against this tree. On the parent `SessionSaveOpen` does not exist, so the bundle does not build there —
// ONE absence (#486); every claim is a FORWARD guard. NOT covered: that the restored song
// SOUNDS (a device run) and the Open sheet's refusal line reading well.
// NEEDS-FOUNDER-VERIFY: Workstation → Import Audio → Save → change or clear the song → Open the
// saved project → the track, the part and its sound come back; then Open a project saved by an
// older build → the Workstation shows an empty song.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheSessionSaveOpensTheSameSongTests: XCTestCase {

    private static let studioPath = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let bar = TimelineTime.ticksPerBar

    // One fixture VALUE per identity — a factory mints fresh ids per call (#1419).
    private static let loopLane = TimelineLane(name: "Loop", kind: .audio)
    private static let loopClip = Clip(name: "Loop", kind: .audio, mediaRef: "Media/Audio/loop.wav")
    private static let loopPart = TimelineRegion(laneID: loopLane.id, clipID: loopClip.id,
                                                 startTick: bar, lengthTicks: 4 * bar)
    private static let take = Project(
        name: "Acceptance A", styleRaw: "ambient", keyRoot: 0, scaleRaw: "major", bpm: 96,
        modeRaw: "flowFree", fxCharacterRaw: "warm", loopBars: 4, a4Hz: 440,
        toneSystemID: nil, moodFields: nil, artist: "",
        patch: SynthPatch(name: "Default"), notes: [], rawTake: nil,
        drumSteps: [], drumAccents: [])

    private static var savedGrid: [Clip?] {
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[1] = loopClip
        return grid
    }

    // MARK: 1 — the real stores

    func testASavedSongComesBackOnOpen() throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        let disk = AppGroupStore(subdirectory: "S3Guard-\(UUID().uuidString)")
        defer {
            timeline.replaceDocument(originalDocument)
            clips.replaceSlots(originalSlots)
            disk.delete(name: "projects.json")
        }

        // The song the user made: one audio track, one imported part.
        let song = TimelineDocument(lanes: [Self.loopLane], regions: [Self.loopPart])
        timeline.replaceDocument(song)
        XCTAssertTrue(clips.replaceSlots(Self.savedGrid))

        // SAVE — through the same capture the Studio's Save uses.
        let saved = SessionSaveOpen.capturing(Self.take, timeline: timeline.document,
                                              clipSlots: clips.slots, songForm: Arrangement(),
                                              playerAutomation: [], sampleRate: 48_000)
        ProjectStore(store: disk).save(saved)

        // The song changes after the save — another project, or a cleared Workstation.
        timeline.replaceDocument(TimelineStore.migrate(sections: []))
        XCTAssertTrue(clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount)))

        // REOPEN from a fresh store, the way the next launch reads the library.
        let row = try XCTUnwrap(ProjectStore(store: disk).projects.first { $0.id == saved.id })
        XCTAssertNil(SessionSaveOpen.refusal(for: row))
        XCTAssertTrue(SessionSaveOpen.restoreSong(of: row, timeline: timeline, clips: clips,
                                                  player: TimelineRegionPlayer()))

        XCTAssertEqual(timeline.document, song, "the same lane and the same part come back")
        XCTAssertEqual(clips.slots, Self.savedGrid, "the same clip, in the same cell")
        let part = try XCTUnwrap(timeline.document.regions.first)
        XCTAssertEqual(clips.clip(id: part.clipID)?.mediaRef, Self.loopClip.mediaRef,
                       "the part still finds its clip, and the clip still names its media")
        XCTAssertFalse(timeline.canUndo, "Open is not an edit — no Undo back into the old song")
    }

    func testALegacyProjectDoesNotInheritThePreviousSong() throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            timeline.replaceDocument(originalDocument)
            clips.replaceSlots(originalSlots)
        }

        timeline.replaceDocument(TimelineDocument(lanes: [Self.loopLane], regions: [Self.loopPart]))
        XCTAssertTrue(clips.replaceSlots(Self.savedGrid))

        XCTAssertEqual(Self.take.readSession(), .absent, "premise: saved before Sessions existed")
        XCTAssertNil(SessionSaveOpen.refusal(for: Self.take), "a legacy take always opens")
        XCTAssertTrue(SessionSaveOpen.restoreSong(of: Self.take, timeline: timeline, clips: clips,
                                                  player: TimelineRegionPlayer()))

        XCTAssertTrue(timeline.document.regions.isEmpty, """
            a project saved before Sessions existed carries no song; opening it must not leave \
            the previous project's parts playing under its name
            """)
        XCTAssertFalse(timeline.document.lanes.contains { $0.id == Self.loopLane.id })
        XCTAssertEqual(timeline.document.lanes.map(\.kind), [.midi, .audio],
                       "the fresh song is the default shape — the one migrate(sections:) builds")
        XCTAssertTrue(clips.filledClips.isEmpty, "and no previous clip rides along")
    }

    func testARefusedOpenChangesNothing() throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            timeline.replaceDocument(originalDocument)
            clips.replaceSlots(originalSlots)
        }
        let song = TimelineDocument(lanes: [Self.loopLane], regions: [Self.loopPart])
        timeline.replaceDocument(song)
        XCTAssertTrue(clips.replaceSlots(Self.savedGrid))

        var newer = Self.take
        newer.setSessionEnvelope(Data(#"{"envelopeVersion":42}"#.utf8))
        let refusal = try XCTUnwrap(SessionSaveOpen.refusal(for: newer))
        XCTAssertTrue(refusal.contains("newer version"), "the refusal says why: \(refusal)")
        XCTAssertFalse(SessionSaveOpen.restoreSong(of: newer, timeline: timeline, clips: clips,
                                                   player: TimelineRegionPlayer()))
        XCTAssertEqual(timeline.document, song, "a refused Open leaves the song exactly as it was")
        XCTAssertEqual(clips.slots, Self.savedGrid)
    }

    // MARK: 2 — the rescue

    func testTheRescueCountsOnlyTheUsersParts() {
        let composed = Clip(name: "Composed · MIDI 1", kind: .midi, composerOwned: true)
        let lane = TimelineLane(name: "MIDI 1", kind: .midi)
        let composerPart = TimelineRegion(laneID: lane.id, clipID: composed.id,
                                          startTick: 0, lengthTicks: Self.bar)
        let onlyComposer = TimelineDocument(lanes: [lane], regions: [composerPart])
        XCTAssertFalse(SessionSaveOpen.songHasUserParts(onlyComposer, clips: [composed]),
                       "the composer's part is re-made on the next Start — nothing to rescue")

        let withLoop = TimelineDocument(lanes: [lane, Self.loopLane],
                                        regions: [composerPart, Self.loopPart])
        XCTAssertTrue(SessionSaveOpen.songHasUserParts(withLoop, clips: [composed, Self.loopClip]),
                      "an imported part is the user's — the recovery slot must keep it (H3)")

        let orphan = TimelineDocument(lanes: [Self.loopLane], regions: [Self.loopPart])
        XCTAssertFalse(SessionSaveOpen.songHasUserParts(orphan, clips: []),
                       "a part whose clip is gone holds nothing to recover")
    }

    // MARK: 3 — source: one door restores a song, in the right order

    func testTheLibraryRowIsTheOneDoorThatReplacesTheSong() throws {
        let code = try studio()
        XCTAssertEqual(code.components(separatedBy: "SessionSaveOpen.restoreSong(").count - 1, 1,
                       "exactly one call site restores a song")
        XCTAssertEqual(code.components(separatedBy: "openFromLibrary(p)").count - 1, 1,
                       "the library row opens through openFromLibrary")
        XCTAssertTrue(code.contains("onLoadShared: { open($0) })"), """
            a take arriving over Live Colabo must load into the instrument WITHOUT replacing \
            the song — it carries none
            """)
        guard let head = code.range(of: "private func openFromLibrary(_ p: Project) {"),
              let refusal = code.range(of: "SessionSaveOpen.refusal(for: p)",
                                       range: head.upperBound..<code.endIndex),
              let open = code.range(of: "open(p)", range: refusal.upperBound..<code.endIndex),
              let restore = code.range(of: "SessionSaveOpen.restoreSong(",
                                       range: head.upperBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: openFromLibrary moved (#454)")
            return
        }
        XCTAssertLessThan(refusal.lowerBound, open.lowerBound,
                          "the refusal is asked BEFORE anything changes")
        XCTAssertLessThan(open.lowerBound, restore.lowerBound, """
            `open(_:)` runs first so its rescue records the song being replaced; restoring \
            before it would put the NEW song into the recovery slot
            """)
    }

    func testSaveAndTheRecoverySlotBothCaptureTheSong() throws {
        let code = try studio()
        XCTAssertTrue(code.contains("projects.save(withSession(currentProject()))"),
                      "Save captures the song")
        XCTAssertTrue(code.contains("projects.save(withSession(take))"),
                      "the recovery slot captures the song it is rescuing")
        XCTAssertTrue(code.contains("currentSession: { currentProject(named: \"Shared session\") }"),
                      "Live Colabo shares the take WITHOUT the song (no withSession there)")
        XCTAssertTrue(code.contains("SessionSaveOpen.songHasUserParts("),
                      "the recovery slot keeps a song with the user's parts even with no take (H3)")
    }

    // MARK: Source helpers

    private func studio() throws -> String {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        let url = dir.appendingPathComponent(Self.studioPath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(Self.studioPath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }
}

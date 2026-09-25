// TheSessionTravelsInTheProjectRowTests.swift
// Echoel — WA4-S2: the canonical Session (`DMMWProject`) is stored in the project row.
//
// WHAT THIS PINS. "Save Project" persisted only the Echoel take; the Workstation's song lived
// in two app-wide files Open never touched (`SESSION_OWNERSHIP_CENSUS.md` §E). The approved
// ownership (census §O) puts the envelope INSIDE the existing `projects.json` row — no new
// persistence root, no new Session type. The risks this file exists for:
// · H1 — the whole library is re-encoded on every save, so a Session this build cannot read
//   (newer, or damaged) must survive a rewrite untouched, not be erased by the next save;
// · the unknown-future rule — a newer envelope is REFUSED, never decoded as if it were ours;
// · a damaged `session` value must never take the Echoel take down with it;
// · H5 — the Session (this device's media paths, the clip grid) does not leave with a share.
//
// 1. END-TO-END (pure) over `Project` + `DMMWProject`: attach → encode → decode → restorable
//    and equal; a legacy row reads `.absent`; a newer or damaged envelope is refused and its
//    BYTES survive a round-trip; a mis-typed `session` key leaves the take readable.
// 2. END-TO-END over a REAL `ProjectStore` on an isolated `AppGroupStore` directory: a saved
//    Session reads back from a fresh store; a newer envelope in one row survives the rewrite
//    caused by saving ANOTHER project.
// 3. The shared document carries the take and not the Session.
//
// Grading (§0, no Swift toolchain in a web session): transcribed into Python over a model of
// the row codec (base64 bytes, version peek, `try?` on the key). On the parent (3da618ede)
// `attachSession`/`readSession`/`sessionEnvelope` do not exist, so the bundle does not build
// there — ONE absence (#486); every claim is a FORWARD guard. NOT covered: Save/Open wiring
// (WA4-S3) and anything on a device.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheSessionTravelsInTheProjectRowTests: XCTestCase {

    // One fixture VALUE — `Project.init` mints a fresh id and date per call (#1419).
    private static let take = Project(
        name: "Row Take", styleRaw: "ambient", keyRoot: 2, scaleRaw: "dorian", bpm: 101,
        modeRaw: "flowFree", fxCharacterRaw: "warm", loopBars: 4, a4Hz: 440,
        toneSystemID: nil, moodFields: nil, artist: "Echoel",
        patch: SynthPatch(name: "Row Pad"),
        notes: [Note(pitch: 62, startStep: 0, lengthSteps: 2, velocity: 0.6, role: .lead)],
        rawTake: nil, drumSteps: [], drumAccents: [])

    private static let lane = TimelineLane(name: "Loop", kind: .audio)
    private static let clip = Clip(name: "Loop", kind: .audio, mediaRef: "Media/Audio/loop.wav")

    // A `let`, not a computed `var`: the region mints a fresh id per construction, and a
    // factory compared with itself compares two different songs (#1419).
    private static let session: DMMWProject = {
        var slots = [Clip?](repeating: nil, count: ClipStore.slotCount)
        slots[2] = clip
        let part = TimelineRegion(laneID: lane.id, clipID: clip.id,
                                  startTick: TimelineTime.ticksPerBar, lengthTicks: 2 * TimelineTime.ticksPerBar)
        return DMMWProjectImport.envelope(
            project: take, timeline: TimelineDocument(lanes: [lane], regions: [part]),
            clipSlots: slots, songForm: Arrangement(sections: []), playerAutomation: [],
            ppq: Note.ticksPerQuarter, sampleRate: 48_000)
    }()

    private func roundTrip(_ project: Project) throws -> Project {
        try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project))
    }

    // MARK: 1 — the row codec

    func testASavedSessionComesBackWhole() throws {
        var project = Self.take
        XCTAssertEqual(project.readSession(), .absent, "a take without a Session opens the take only")
        XCTAssertTrue(project.attachSession(Self.session))
        let back = try roundTrip(project)
        XCTAssertEqual(back.readSession(), .restorable(Self.session))
        XCTAssertEqual(back.notes, Self.take.notes, "the legacy take rides beside it, untouched")
    }

    func testALegacyRowHasNoSession() throws {
        let legacy = try JSONEncoder().encode(Self.take)
        let text = try XCTUnwrap(String(data: legacy, encoding: .utf8))
        XCTAssertFalse(text.contains("\"session\""), "no Session writes NO key (encodeIfPresent)")
        XCTAssertEqual(try JSONDecoder().decode(Project.self, from: legacy).readSession(), .absent)
    }

    func testANewerSessionIsRefusedAndKept() throws {
        let newer = Data(#"{"envelopeVersion":99,"content":"a shape this build has never seen"}"#.utf8)
        var project = Self.take
        project.setSessionEnvelope(newer)
        XCTAssertEqual(project.readSession(), .newer(version: 99),
                       "a newer envelope is refused by its version, never decoded as ours")
        let back = try roundTrip(project)
        XCTAssertEqual(back.sessionEnvelope, newer, """
            the bytes of a Session this build cannot open must survive the row's rewrite — \
            the library is re-encoded on every save, and anything else erases it
            """)
    }

    func testADamagedSessionIsRefusedAndKept() throws {
        let damaged = Data("not an envelope".utf8)
        var project = Self.take
        project.setSessionEnvelope(damaged)
        XCTAssertEqual(project.readSession(), .unreadable)
        XCTAssertEqual(try roundTrip(project).sessionEnvelope, damaged)

        let current = Data(#"{"envelopeVersion":1,"meta":"truncated"}"#.utf8)
        project.setSessionEnvelope(current)
        XCTAssertEqual(project.readSession(), .unreadable,
                       "a current-version envelope that does not decode is refused, not emptied")
    }

    func testAMistypedSessionKeyCannotTakeTheTakeDown() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(Self.take)) as? [String: Any])
        object["session"] = 42
        let row = try JSONSerialization.data(withJSONObject: object)
        let back = try JSONDecoder().decode(Project.self, from: row)
        XCTAssertEqual(back.name, Self.take.name)
        XCTAssertEqual(back.notes, Self.take.notes)
        XCTAssertNil(back.sessionEnvelope)
    }

    // MARK: 2 — the real store

    func testTheStoreKeepsEveryRowsSessionAcrossARewrite() throws {
        let directory = "S2Guard-\(UUID().uuidString)"
        let disk = AppGroupStore(subdirectory: directory)
        defer { disk.delete(name: "projects.json") }

        var saved = Self.take
        XCTAssertTrue(saved.attachSession(Self.session))
        var future = Project(
            name: "Future Take", styleRaw: "ambient", keyRoot: 0, scaleRaw: "major", bpm: 90,
            modeRaw: "flowFree", fxCharacterRaw: "warm", loopBars: 4, a4Hz: 440,
            toneSystemID: nil, moodFields: nil, artist: "",
            patch: SynthPatch(name: "Default"), notes: [], rawTake: nil,
            drumSteps: [], drumAccents: [])
        let newer = Data(#"{"envelopeVersion":7}"#.utf8)
        future.setSessionEnvelope(newer)

        let store = ProjectStore(store: disk)
        store.save(future)
        store.save(saved)          // rewrites the whole library, `future` included

        let reread = ProjectStore(store: disk)
        let savedBack = try XCTUnwrap(reread.projects.first { $0.id == saved.id })
        let futureBack = try XCTUnwrap(reread.projects.first { $0.id == future.id })
        XCTAssertEqual(savedBack.readSession(), .restorable(Self.session),
                       "a fresh store (the next launch) must read the Session back")
        XCTAssertEqual(futureBack.sessionEnvelope, newer,
                       "saving another project must not erase a Session this build cannot open")
        XCTAssertEqual(futureBack.readSession(), .newer(version: 7))
    }

    // MARK: 3 — the shared document

    func testTheSharedDocumentCarriesTheTakeNotTheSession() throws {
        var project = Self.take
        XCTAssertTrue(project.attachSession(Self.session))
        let shared = try JSONDecoder().decode(Project.self, from: project.sharedDocumentData())
        XCTAssertNil(shared.sessionEnvelope, """
            the Session carries this device's media paths and clip grid; on another phone they \
            resolve to nothing, and opening it there would replace that user's song with silence
            """)
        XCTAssertEqual(shared.notes, Self.take.notes)
        XCTAssertNotNil(project.sessionEnvelope, "sharing must not strip the SAVED row")
    }
}

// TheSpatialSceneTravelsWithThePieceTests.swift
// Echoel — Restructure A3a (2026-10-04, `scratchpads/PLAN_RESTRUCTURE_2026-10-04.md`).
//
// WHAT WAS WRONG. Save captured the song — timeline, clip grid, song form — and left the
// spatial scene out. The scene's objects are keyed by the document's LANE ids, so a scene left
// in the app's memory pointed at nothing once another piece opened; opening fell back to the
// per-instrument default positions every time, and an ADM-OSC rig lost its layout with the song.
// The session census puts spatial positions inside the Session
// (`docs/dev/SESSION_OWNERSHIP_CENSUS.md`), so the scene rides in the envelope.
//
// WHAT DOES NOT MOVE, on purpose: the modulation matrix and the signal routes stay APP roots
// (`TheProjectEnvelopeImportsWithoutRestructuringTests` claim 6). Claim 8 here re-reads that
// boundary from this side, so the A3a move cannot be widened into "the envelope swallows the
// app" without one of the two files going red.
//
// HONEST GRADING (Tests/CISmoke/CLAUDE.md §1/§3). Against the parent this file does NOT
// compile: `DMMWProject.spatial`, the `capturing(…, spatial:)` overload,
// `SpatialSceneStore.restore` and `SessionSaveOpen.restoreSpatialScene` do not exist there — ONE
// absence (#486), no assertion has a verdict on the parent. Graded by Python transcription
// against the worktree instead:
//   · claims 1–5 — END-TO-END over shipped value types and the `@MainActor` store; FORWARD
//     guards (they drive symbols this commit creates and could never have been red).
//   · claim 6 — SOURCE-TEXT SCAN, a REGRESSION guard: on the parent the one Studio capture
//     call writes no `spatial:` (1 of 1 call sites without it).
//   · claim 7 — SOURCE-TEXT SCAN, a REGRESSION guard: on the parent `openFromLibrary` does not
//     restore a scene.
//   · claim 8 — its app-root half is the COUNTERWEIGHT, green on both trees; its first needle
//     (the `spatial` compartment) is red on the parent only because this commit declares it.
// NOT covered: that an ADM-OSC receiver sees the restored positions after reopening — a
// device probe, open.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheSpatialSceneTravelsWithThePieceTests: XCTestCase {

    // One fixture VALUE each — `Project.init` and `TimelineLane.init` mint fresh ids (#1419).
    private static let take = Project(
        name: "Space Take", styleRaw: "ambient", keyRoot: 0, scaleRaw: "major", bpm: 96,
        modeRaw: "flowFree", fxCharacterRaw: "warm", loopBars: 4, a4Hz: 440,
        toneSystemID: nil, moodFields: nil, artist: "Echoel",
        patch: SynthPatch(name: "Space Pad"),
        notes: [Note(pitch: 60, startStep: 0, lengthSteps: 2, velocity: 0.6, role: .lead)],
        rawTake: nil, drumSteps: [], drumAccents: [])

    private static let laneA = TimelineLane(name: "A", kind: .midi)
    private static let laneB = TimelineLane(name: "B", kind: .midi)
    private static let laneC = TimelineLane(name: "C", kind: .midi)

    private static let movedA = SpatialPosition(azimuth: -120, elevation: 30, distance: 0.4)
    private static let movedB = SpatialPosition(azimuth: 75, elevation: -10, distance: 0.9)

    /// A scene with two moved objects, a stale object for a lane no piece has, and a room that
    /// is not the default — every part a restore has to keep, fit or drop.
    private static let scene: SpatialScene = {
        var s = SpatialScene(room: RoomModel(width: 12, depth: 9, height: 4))
        s.upsert(SpatialObject(id: laneA.id.uuidString, position: movedA, extent: 0.3))
        s.upsert(SpatialObject(id: laneB.id.uuidString, position: movedB))
        s.upsert(SpatialObject(id: UUID().uuidString, position: .front))
        return s
    }()

    private static let timeline = TimelineDocument(lanes: [laneA, laneB])

    private static func envelope(spatial: SpatialScene?) -> DMMWProject {
        var e = DMMWProjectImport.envelope(
            project: take, timeline: timeline,
            clipSlots: [Clip?](repeating: nil, count: ClipStore.slotCount),
            songForm: Arrangement(sections: []), playerAutomation: [],
            ppq: Note.ticksPerQuarter, sampleRate: 48_000)
        e.spatial = spatial
        return e
    }

    private func session(of project: Project, file: StaticString = #filePath,
                         line: UInt = #line) throws -> DMMWProject {
        guard case .restorable(let s) = project.readSession() else {
            XCTFail("the project carries no restorable Session", file: file, line: line)
            throw AnchorMissing(name: "readSession")
        }
        return s
    }

    // MARK: 1 — a saved scene comes back with the piece

    func testASavedSceneComesBackWithThePiece() throws {
        var saved = Self.take
        XCTAssertTrue(saved.attachSession(Self.envelope(spatial: Self.scene)))
        let data = try JSONEncoder().encode(saved)
        let reopened = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertEqual(try session(of: reopened).spatial, Self.scene,
                       "the spatial scene did not survive save → encode → decode → open")
    }

    // MARK: 2 — an envelope written before A3a still opens, whole

    func testAnEnvelopeWithoutASceneStillOpens() throws {
        let old = Self.envelope(spatial: nil)
        let data = try JSONEncoder().encode(old)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(text.contains("\"spatial\""), """
            an envelope with no scene writes a `spatial` key — a build before A3a would then \
            meet a key it never wrote, and `nil` would no longer mean "never saved one"
            """)
        let decoded = try JSONDecoder().decode(DMMWProject.self, from: data)
        XCTAssertNil(decoded.spatial)
        XCTAssertEqual(decoded, old, "an envelope without a scene lost a compartment on the way in")
    }

    // MARK: 3 — a damaged scene cannot take the song down

    func testADamagedSceneCannotTakeTheSongDown() throws {
        // Built by text insertion, not by a JSONSerialization round trip: re-serialising would
        // re-print every Float and could change the song the assertion compares (#442).
        let good = Self.envelope(spatial: nil)
        let text = try XCTUnwrap(String(data: JSONEncoder().encode(good), encoding: .utf8))
        XCTAssertTrue(text.hasPrefix("{"), "the envelope does not encode as a JSON object")
        let damaged = Data(("{\"spatial\":\"not a scene\"," + text.dropFirst()).utf8)
        let decoded = try JSONDecoder().decode(DMMWProject.self, from: damaged)
        XCTAssertNil(decoded.spatial, "a scene this build cannot read must open as no scene")
        XCTAssertEqual(decoded.content, good.content, "a damaged scene took the song with it")
        XCTAssertEqual(decoded.musical, good.musical)
    }

    // MARK: 4 — the Studio's capture form writes the scene; the older form writes none

    func testTheCaptureWithASceneWritesItAndTheOldFormWritesNone() throws {
        let withScene = SessionSaveOpen.capturing(
            Self.take, timeline: Self.timeline,
            clipSlots: [Clip?](repeating: nil, count: ClipStore.slotCount),
            songForm: Arrangement(sections: []), playerAutomation: [], sampleRate: 48_000,
            spatial: Self.scene)
        XCTAssertEqual(try session(of: withScene).spatial, Self.scene)

        let without = SessionSaveOpen.capturing(
            Self.take, timeline: Self.timeline,
            clipSlots: [Clip?](repeating: nil, count: ClipStore.slotCount),
            songForm: Arrangement(sections: []), playerAutomation: [], sampleRate: 48_000)
        XCTAssertNil(try session(of: without).spatial,
                     "the capture form that holds no scene invented one")
    }

    // MARK: 5 — a restore keeps the saved positions and fits them to the piece's tracks

    @MainActor
    func testARestoreKeepsSavedPositionsAndFitsTheTracks() throws {
        let store = SpatialSceneStore()
        // The piece that opened has A and C; B was removed since the save, C is new.
        let lanes = [Self.laneA, Self.laneC]
        store.rebuild(from: lanes)   // what installing the song already did

        var saved = Self.take
        XCTAssertTrue(saved.attachSession(Self.envelope(spatial: Self.scene)))
        SessionSaveOpen.restoreSpatialScene(of: saved, into: store, lanes: lanes)

        XCTAssertEqual(store.scene.objects.map(\.id), lanes.map { $0.id.uuidString },
                       "the restored scene is not one object per track, in track order")
        let a = try XCTUnwrap(store.object(forLane: Self.laneA.id))
        XCTAssertEqual(a.position, Self.movedA, "a saved position was not put back")
        XCTAssertEqual(a.extent, 0.3, accuracy: 1e-6)
        let c = try XCTUnwrap(store.object(forLane: Self.laneC.id))
        XCTAssertEqual(c, ImmersiveObjectDefaults.defaultObject(
            for: .polySynth, laneID: Self.laneC.id, laneIndex: 1, laneCount: 2),
            "a track the saved scene did not know did not get its default")
        XCTAssertNil(store.object(forLane: Self.laneB.id), "a removed track kept its object")
        XCTAssertEqual(store.scene.room, Self.scene.room, "the saved room was dropped by the fit")

        // A project saved before A3a leaves the scene the song install built.
        let before = store.scene
        var legacy = Self.take
        XCTAssertTrue(legacy.attachSession(Self.envelope(spatial: nil)))
        SessionSaveOpen.restoreSpatialScene(of: legacy, into: store, lanes: lanes)
        XCTAssertEqual(store.scene, before, "a piece with no saved scene changed the scene")
    }

    // MARK: 6 — every capture in Sources/ passes the scene

    func testEveryCaptureInSourcesPassesTheScene() throws {
        var calls = 0
        for (path, code) in try swiftSources() {
            var cursor = code.startIndex
            while let hit = code.range(of: "SessionSaveOpen.capturing(", range: cursor..<code.endIndex) {
                calls += 1
                let args = try balancedArguments(in: code, openingAt: code.index(before: hit.upperBound),
                                                 path: path)
                XCTAssertTrue(args.contains("spatial:"), """
                    \(path) captures a Session without the spatial scene — a piece saved there \
                    reopens with every track at its default position.
                    """)
                cursor = hit.upperBound
            }
        }
        XCTAssertGreaterThan(calls, 0, "no `SessionSaveOpen.capturing(` call found — the scan cannot speak")
    }

    // MARK: 7 — Open puts the scene back AFTER the song

    func testOpenRestoresTheSceneAfterTheSong() throws {
        let code = try read("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        let marker = "private func openFromLibrary("
        XCTAssertEqual(code.components(separatedBy: marker).count - 1, 1,
                       "`\(marker)` is not unique — the anchor cannot name one function")
        let body = try functionBody(in: code, after: marker)
        let song = try XCTUnwrap(body.range(of: "SessionSaveOpen.restoreSong("),
                                 "openFromLibrary no longer installs the song")
        let space = try XCTUnwrap(body.range(of: "SessionSaveOpen.restoreSpatialScene("),
                                  "openFromLibrary does not put the saved scene back")
        XCTAssertLessThan(song.lowerBound, space.lowerBound, """
            the scene is restored BEFORE the song — installing the song rebuilds the scene from \
            defaults and would overwrite it.
            """)
    }

    // MARK: 8 — COUNTERWEIGHT: the envelope still carries no app root

    func testTheEnvelopeStillCarriesNoAppRoot() throws {
        let envelope = try read("Sources/Echoelmusic/Core/DMMWProject.swift")
        XCTAssertTrue(envelope.contains("public var spatial: SpatialScene?"),
                      "the envelope lost its spatial compartment")
        for appRoot in ["ModulationMatrix", "ModulationEngine", "SignalRouter", "SpatialSceneStore"] {
            XCTAssertFalse(envelope.contains(appRoot), """
                DMMWProject names `\(appRoot)`. The piece carries the scene VALUE; the store, \
                the modulation matrix and the signal routes are app state (claim 6 of \
                `TheProjectEnvelopeImportsWithoutRestructuringTests`).
                """)
        }
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    private func root() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }

    private func read(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: root().appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    /// The text between the `(` at `open` and its matching `)`.
    private func balancedArguments(in code: String, openingAt open: String.Index,
                                   path: String) throws -> String {
        var depth = 0
        var index = open
        while index < code.endIndex {
            let ch = code[index]
            if ch == "(" { depth += 1 }
            if ch == ")" {
                depth -= 1
                if depth == 0 { return String(code[code.index(after: open)..<index]) }
            }
            index = code.index(after: index)
        }
        XCTFail("unbalanced call in \(path)")
        throw AnchorMissing(name: path)
    }

    /// The brace-matched body of the first function declared after `marker` (#408).
    private func functionBody(in code: String, after marker: String) throws -> String {
        guard let start = code.range(of: marker),
              let open = code.range(of: "{", range: start.upperBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: \(marker)")
            throw AnchorMissing(name: marker)
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let ch = code[index]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return String(code[open.lowerBound...index]) }
            }
            index = code.index(after: index)
        }
        XCTFail("unbalanced body after \(marker)")
        throw AnchorMissing(name: marker)
    }

    /// Every `.swift` file under `Sources/`, comment-stripped. A walk that finds nothing FAILS.
    private func swiftSources() throws -> [(String, String)] {
        let sources = root().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            XCTFail("ANCHOR MISSING: cannot walk Sources/ (#454)")
            throw AnchorMissing(name: "Sources/")
        }
        var out: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            guard let cut = url.path.range(of: "/Sources/", options: .backwards) else { continue }
            out.append(("Sources/" + String(url.path[cut.upperBound...]), SourceText.codeOnly(text)))
        }
        guard out.count > 100 else {
            XCTFail("the Sources/ walk found only \(out.count) Swift files — the scan cannot be trusted")
            throw AnchorMissing(name: "Sources/ walk")
        }
        return out
    }
}

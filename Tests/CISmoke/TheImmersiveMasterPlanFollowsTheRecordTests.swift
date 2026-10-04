//
//  TheImmersiveMasterPlanFollowsTheRecordTests.swift
//  Spatial S-A1. ADR-007 (accepted 2026-10-04, founder: "Du machst und entscheidest alles")
//  fixes WHAT an immersive master of a piece contains: every audio track is one mono object
//  placed from the spatial scene, the generated voices are one stereo bed (BS.2051 0+2+0),
//  bio lanes are neither, no LFE in v1, 48 kHz / 24 bit, ADM `ITU-R_BS.2076-2`. This guard is
//  the record's executable half: `ImmersiveMasterPlan.make` must answer exactly that, the same
//  way every time, so the stem capture (S-A3), the export folder (S-A4) and the BW64 writer
//  (S-A5) read ONE answer.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–6) — `ImmersiveMasterPlan`, `TimelineLane`, `SpatialScene`
//    and `SpatialSceneStore.defaultPosition` are shipped, Foundation-only values; nothing is
//    mocked. Claim 2's fallback asks the store's OWN rule, so the plan and a scene rebuild can
//    never disagree (#416).
//  · SOURCE-TEXT SCAN (claim 7) — the plan's code reads no clock and draws no random number:
//    the same piece must give the same bytes (ADR-007 §1, L6 determinism).
//  · NOT PINNED, and said so: that anything CONSTRUCTS a plan in the app. Nothing does yet —
//    S-A3/S-A4 will. Built: yes · wired: no · device: no · studio: no.
//
//  ⚠️ WHAT MUST NOT BE READ INTO THIS (#364): it forbids no later layout. A plan with an LFE,
//  a height bed or positioned generated voices is a NEW decision — update ADR-007 and this
//  guard in the same commit; the messages say so.
//
//  GRADING (#433/#464): the file does NOT compile on the parent tree — `ImmersiveMasterPlan`,
//  `ChannelRole` and `BS2051Channel` are created by this commit — so no assertion has a verdict
//  there (ONE absence, #486). Every claim was transcribed by reading `make`,
//  `sanitizedProgrammeName` and `defaultPosition(forLane:in:)`; claim 7's scan was driven in
//  Python against the new file (0 hits) and against a mutant carrying `Date()` (1 hit).
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheImmersiveMasterPlanFollowsTheRecordTests: XCTestCase {

    private static let planFile = "Sources/Echoelmusic/Core/ImmersiveMasterPlan.swift"

    private func piece() -> [TimelineLane] {
        [TimelineLane(name: "Drums loop", kind: .audio),
         TimelineLane(name: "Keys", kind: .midi),
         TimelineLane(name: "Pulse", kind: .audio, isBio: true),
         TimelineLane(name: "  Voice take  ", kind: .audio)]
    }

    // MARK: 1 — audio tracks are objects, generated voices one stereo bed, bio and MIDI neither

    func testTheLayoutIsTheRecordsLayout() {
        let lanes = piece()
        let plan = ImmersiveMasterPlan.make(programmeName: "Night piece",
                                            lanes: lanes, scene: SpatialScene())

        XCTAssertEqual(plan.channels.map(\.role),
                       [.bed(channel: .frontLeft), .bed(channel: .frontRight), .object, .object],
                       "ADR-007 §2: the stereo bed first, then one object per AUDIO track")
        XCTAssertEqual(plan.channels.map(\.trackIndex), [1, 2, 3, 4],
                       "track indexes are the chna order: contiguous from 1")
        XCTAssertEqual(plan.channels.compactMap(\.laneID), [lanes[0].id, lanes[3].id], """
            Only audio tracks become objects. A MIDI lane sounds through the generated voices \
            (the bed); a bio lane modulates and never sounds.
            """)
        XCTAssertEqual(plan.channels[3].name, "Voice take", "a track name is trimmed")
        XCTAssertEqual(plan.objectCount, 2)
        XCTAssertEqual(plan.bedChannelCount, 2)
        XCTAssertFalse(plan.channels.contains { $0.role == .lfe }, """
            No LFE in v1 (ADR-007 §2). Adding one is a new decision: update the ADR and this \
            guard in the same commit.
            """)
        XCTAssertTrue(plan.channels.filter { $0.role != .object }.allSatisfy {
            $0.laneID == nil && $0.position == nil
        }, "a bed channel has a loudspeaker label, not a track or a position")
    }

    // MARK: 2 — an object starts where the scene has it; an unknown track where a rebuild puts it

    func testAnObjectStartsWhereTheSceneHasIt() {
        let lanes = piece()
        let moved = SpatialPosition(azimuth: 90, elevation: 20, distance: 0.5)
        let scene = SpatialScene(objects: [SpatialObject(id: lanes[0].id.uuidString, position: moved)])
        let plan = ImmersiveMasterPlan.make(programmeName: "x", lanes: lanes, scene: scene)

        let objects = plan.channels.filter { $0.role == .object }
        XCTAssertEqual(objects.first?.position, moved,
                       "a placed track keeps the place the scene gives it")
        XCTAssertEqual(objects.last?.position,
                       SpatialSceneStore.defaultPosition(forLane: lanes[3].id, in: lanes), """
            A track the scene does not know yet starts where a scene rebuild would place it — \
            the store's own rule, never a copy of it (#416).
            """)
    }

    // MARK: 3 — without generated voices there is no bed; without tracks nothing at all

    func testABedOnlyWhenTheVoicesSound() {
        let lanes = piece()
        let noBed = ImmersiveMasterPlan.make(programmeName: "x", lanes: lanes, scene: SpatialScene(),
                                             includesGeneratedVoices: false)
        XCTAssertEqual(noBed.bedChannelCount, 0)
        XCTAssertEqual(noBed.channels.map(\.trackIndex), [1, 2], "objects renumber from 1")

        let empty = ImmersiveMasterPlan.make(programmeName: "x", lanes: [], scene: SpatialScene(),
                                             includesGeneratedVoices: false)
        XCTAssertTrue(empty.isEmpty, "an empty plan says so; the export must not write an empty file")
    }

    // MARK: 4 — the programme name is never empty and never a Dolby profile's own

    func testTheProgrammeNameIsOpenProfile() {
        XCTAssertEqual(ImmersiveMasterPlan.sanitizedProgrammeName("  Night piece "), "Night piece")
        XCTAssertEqual(ImmersiveMasterPlan.sanitizedProgrammeName("   "),
                       ImmersiveMasterPlan.fallbackProgrammeName)
        for reserved in ["Atmos_Master", "atmos_master", " ATMOS_MASTER "] {
            XCTAssertEqual(ImmersiveMasterPlan.sanitizedProgrammeName(reserved),
                           ImmersiveMasterPlan.fallbackProgrammeName, """
                "\(reserved)" is how a Dolby profile names itself. Whether an Echoel file may \
                carry it is open (ADR-007 F-E); the open profile never writes it.
                """)
        }
    }

    // MARK: 5 — the format constants are the record's

    func testTheFormatIsTheRecordsFormat() {
        XCTAssertEqual(ImmersiveMasterPlan.sampleRate, 48_000, "ADR-007 F-C")
        XCTAssertEqual(ImmersiveMasterPlan.bitDepth, 24, "ADR-007 F-C")
        XCTAssertEqual(ImmersiveMasterPlan.admVersion, "ITU-R_BS.2076-2", "ADR-007 §1")
        XCTAssertEqual(ImmersiveMasterPlan.stereoBedPackFormatID, "AP_00010002",
                       "BS.2094 common definition for 0+2+0, referenced, not re-declared")
        XCTAssertEqual(BS2051Channel.allCases.map(\.rawValue), ["M+030", "M-030"])
        XCTAssertEqual(BS2051Channel.allCases.map(\.admChannelFormatID),
                       ["AC_00010001", "AC_00010002"])
    }

    // MARK: 6 — same piece, same bytes; and the JSON reads back to the same plan

    func testTheSamePieceGivesTheSameBytes() throws {
        let lanes = piece()
        let scene = SpatialScene(objects: [SpatialObject(id: lanes[0].id.uuidString,
                                                         position: SpatialPosition(azimuth: -45, elevation: 0, distance: 1))])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let first = try encoder.encode(ImmersiveMasterPlan.make(programmeName: "p", lanes: lanes, scene: scene))
        let second = try encoder.encode(ImmersiveMasterPlan.make(programmeName: "p", lanes: lanes, scene: scene))
        XCTAssertEqual(first, second, "the plan is a function of the piece: same input, same bytes")

        let decoded = try JSONDecoder().decode(ImmersiveMasterPlan.self, from: first)
        XCTAssertEqual(decoded, ImmersiveMasterPlan.make(programmeName: "p", lanes: lanes, scene: scene),
                       "Codable round-trip")
        XCTAssertEqual(decoded.version, ImmersiveMasterPlan.formatVersion)
    }

    // MARK: 7 — the plan reads no clock and draws no random number

    func testThePlanReadsNoClockAndNoDice() throws {
        let code = SourceText.codeOnly(try text(Self.planFile))
        for needle in ["Date()", "Date.now", "UUID()", ".random", "CFAbsoluteTimeGetCurrent",
                       "ProcessInfo"] {
            XCTAssertFalse(code.contains(needle), """
                \(Self.planFile) contains `\(needle)` in code. The plan must be a pure function \
                of the piece (ADR-007 §1, determinism): a clock or a dice makes two exports of \
                the same piece differ.
                """)
        }
        let imports = code.split(separator: "\n").filter { $0.hasPrefix("import ") }
        XCTAssertEqual(imports, ["import Foundation"], "the plan is Foundation-only")
    }

    private func text(_ relative: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        let file = url.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("\(relative) not on disk — this run has no source tree")
        }
        return try String(contentsOf: file, encoding: .utf8)
    }
}

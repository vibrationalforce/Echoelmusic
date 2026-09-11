// TheFacePresetsAreStarterRoutesTests.swift
// Echoel — #1261 (K4b of `scratchpads/PLAN_KAMERA_EINGANG_2026-09-11.md`). Blocking bundle.
//
// WHAT THIS GUARDS. The prompt asks for "2–3 mitgelieferte Presets als Startpunkt" and
// forbids hard-wiring ("kein `jawOpen → Cutoff` im Code"). `FXModPreset.facePresets` is
// the reconciliation: named sets of ORDINARY `FXModRoute`s, appended by a menu the FX
// bio-mod section already had, then owned by the row editor. Claims 1–3 are BEHAVIOUR on
// the shipped type; claim 4 is a SOURCE-TEXT scan of the door. Whether a preset SOUNDS
// right is the founder's ear (device ask in the publisher's header).
//
// ⚠️ HONEST GRADING (#433/#464), transcribed in Python against the parent (4f87ba3) and
// this tree. Claims 1–3 cannot compile against the parent (no `FXModPreset`) — per §3 ONE
// finding; claim 4 is RED on the parent (no menu). The "targets are real stages" half of
// claim 2 is a COUNTERWEIGHT on `FXModTarget.allCases`, green wherever the type exists.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheFacePresetsAreStarterRoutesTests: XCTestCase {

    private static let fxView = "Sources/Echoelmusic/Studio/EchoelFXView.swift"

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    // MARK: - claim 1 (BEHAVIOUR) — two to three named presets, each a real starter

    func testThereAreTwoToThreeNamedPresets() {
        let presets = FXModPreset.facePresets
        XCTAssertTrue((2...3).contains(presets.count), "the prompt asks for 2–3 starter presets; \(presets.count) shipped")
        XCTAssertEqual(Set(presets.map(\.name)).count, presets.count, "preset names are the menu's ids — unique")
        for p in presets {
            XCTAssertFalse(p.name.isEmpty)
            XCTAssertFalse(p.summary.isEmpty, "a preset says what it does — the menu is the only place the player learns it")
            XCTAssertGreaterThanOrEqual(p.routes.count, 2, "'\(p.name)' is a single route, not a starter SET")
            XCTAssertFalse(p.name.lowercased().contains("emotion") || p.summary.lowercased().contains("emotion"),
                           "movement, never a feeling (EU AI Act framing)")
        }
    }

    // MARK: - claim 2 (BEHAVIOUR) — every route is on a producing face channel, at a real stage

    func testEveryPresetRouteIsAFaceChannelOntoARealStage() {
        for p in FXModPreset.facePresets {
            for r in p.routes {
                guard case .bio(let source) = r.carrier else {
                    XCTFail("'\(p.name)' carries an LFO — a face preset is the face, not a clock")
                    continue
                }
                XCTAssertTrue(ModSource.faceChannels.contains(source), "'\(p.name)' routes `\(source)`, which is not a face channel")
                XCTAssertTrue(source.hasProducer, "`\(source)` has no producer — a preset on it is a control that lies")
                XCTAssertTrue(FXModTarget.allCases.contains(r.target), "'\(p.name)' targets a stage the chain does not have")
                XCTAssertTrue(r.depth > 0 && r.depth <= 1, "depth \(r.depth) would be inaudible or over-range")
                XCTAssertTrue(r.enabled, "a starter route arrives switched on")
                // Unipolar channels lift from the base; centred head channels swing around it.
                let centred: Set<ModSource> = [.headYaw, .headPitch, .headRoll]
                if !centred.contains(source) {
                    XCTAssertFalse(r.bipolar, "`\(source)` is unipolar (0 = rest): a bipolar route would sit at −½·depth at rest")
                }
            }
        }
    }

    // MARK: - claim 3 (BEHAVIOUR) — fresh ids on every access

    func testEachApplicationGetsFreshRouteIds() {
        let a = FXModPreset.facePresets.flatMap(\.routes).map(\.id)
        let b = FXModPreset.facePresets.flatMap(\.routes).map(\.id)
        XCTAssertTrue(Set(a).isDisjoint(with: Set(b)), """
            Two accesses of `facePresets` handed out the same route ids. Applying a preset \
            twice would then put duplicate ids into `modulator.routes`, and `ForEach` over \
            them is undefined — build the routes on access, never in a `static let`.
            """)
        XCTAssertEqual(Set(a).count, a.count, "ids are unique within one access too")
    }

    // MARK: - claim 4 (SOURCE-TEXT) — the door is in the existing add-route menu, capability-gated

    func testTheDoorIsInTheAddRouteMenu() throws {
        let text = try String(contentsOf: try repoRoot().appendingPathComponent(Self.fxView), encoding: .utf8)
        let code = SourceText.codeOnly(text)
        guard let section = code.range(of: "private struct FXBioModSection: View {") else {
            XCTFail("FXBioModSection declaration moved — re-anchor (#454).")
            return
        }
        let body = String(code[section.upperBound...]).components(separatedBy: "\n}\n")[0]
        XCTAssertTrue(body.contains("FXModPreset.facePresets"), "the bio-mod section no longer offers the face presets")
        XCTAssertTrue(body.contains("if FaceExpressionBioPublisher.isSupported {"), """
            The face presets are offered on every device. On a phone without face tracking a \
            preset appends routes on channels that can never be measured — every row then \
            shows "—" and the player cannot tell it from a body that has not settled.
            """)
        XCTAssertTrue(body.contains("modulator.routes.append(contentsOf: preset.routes)"),
                      "a preset APPENDS ordinary routes; replacing the player's own routes would be the hard-wiring the prompt forbids")
        XCTAssertEqual(body.components(separatedBy: "Menu {").count - 1, 1, "still ONE add-route menu (the presets nest inside it)")
    }
}

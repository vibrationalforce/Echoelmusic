// TheFaceSourceShowsTheCameraOnceTests.swift
// Echoel — #1297 (device finding on v10.79.470, build 2590).
//
// WHAT THIS GUARDS. The founder chose the Face source and reported: "Die frontkamera wird
// nicht eingeblendet für die Mimik und gestig Steuerung". Nothing in the chain was broken.
// K5 (#1262) built it end to end — the ARKit session stores each `capturedImage` in
// `CameraFrameSlot`, the renderer has a camera pass, both mounts bind the three
// `visual.camera.*` keys — and `visualCameraOpacity` ships at 0.0, with its only door a
// number field inside `visualPanel`, behind the Field chip, below the blend Picker. So the
// picture existed on every frame and was fully transparent, and a performer who never found
// that row concluded the front camera does not come on.
//
// ⭐ THE SHAPE OF THE REPAIR IS A ONE-SHOT LATCH, AND THE TWO REJECTED SHAPES ARE THE POINT.
// Raising the STORED DEFAULT would paint the front camera over a camera-light take (a finger
// on the BACK lens), a Bluetooth-strap take and the simulation — three sources with no face
// in front of them. Raising it on EVERY `.face` start would overwrite the choice of a
// performer who deliberately dialled the layer back to 0; that is an override, not an
// introduction. `visualCameraIntroduced` fires once, and from then on the number field owns
// the value in both directions.
//
// ⚠️ ORDER IS LOAD-BEARING, NOT COSMETIC. The raise sits BEFORE `faceExpression.start(...)`.
// `FaceExpressionBioPublisher` only stores a frame while a renderer says it wants one
// (`CameraFrameSlot.wantedViewports()`), and the renderer only wants one while
// `lookCameraOpacity > 0.001`. Raising after the start would open a window in which the
// session runs and stores nothing. Claim 2 pins the order.
//
// ⚠️ LIMIT — SOURCE-TEXT SCAN (§1). Nothing here runs ARKit, renders a frame or proves the
// layer is legible at 0.6 over the generative field. Whether the founder can SEE his face
// and still see the instrument is a device probe; the marker for it sits at the write site.
// This file proves the latch exists, fires once, fires early, and that the stored default
// for every other source is still 0.
//
// ⚠️ HONEST GRADING (#433/#464) — transcribed in Python against the parent (6403f1c) and this
// tree. 9 assertions in 4 tests: claims 1 (2) + 2 (4) + 3 (1) + 4 (2). Against the PARENT,
// claims 1–3 are red as ONE finding (#486) — seven needles naming lines born with this commit,
// all FORWARD. Claim 4's two are COUNTERWEIGHTS, green on BOTH trees: the stored default is
// still 0.0 and the `Camera layer` door still exists exactly once, which is what makes the
// one-shot honest instead of a hidden new default. Seven mutations driven; each reddened
// exactly its own claim. `SourceText.codeOnly` is PROPHYLAKTISCH here, MEASURED: 0 of 18
// verdicts (9 × 2 trees) flip raw-vs-stripped — after an eighth needle that DID flip was
// deleted for the #491 reason recorded inside claim 1.

import Foundation
import XCTest

final class TheFaceSourceShowsTheCameraOnceTests: XCTestCase {

    private static let keys = "Sources/Echoelmusic/Core/StudioDefaultKeys.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"

    // MARK: - claim 1 — the two keys exist, with the values the decision names

    func testTheIntroductionHasItsOwnKeyAndItsOwnValue() throws {
        let code = try source(Self.keys)
        XCTAssertTrue(code.contains("""
            public static let visualCameraIntroduced = StudioDefault(key: "visual.camera.introduced", value: false)
            """), """
            `visualCameraIntroduced` is gone or changed shape. It is the ONLY thing separating \
            "show the camera the first time someone plays with their face" from "show the \
            camera always" — without it the choice collapses into the stored default, which \
            would paint a face over a back-lens pulse take, a strap take and the simulation.
            """)
        XCTAssertTrue(code.contains("public static let visualCameraIntroOpacity = 0.6"), """
            The introduction opacity moved or changed. It is deliberately NOT 1.0: at full \
            opacity the camera covers the generative field the instrument exists to show, and \
            the ask was to SEE the face for expression control, not to replace the visual.
            """)
        // ⛔ A THIRD ASSERTION STOOD HERE AND WAS DELETED BEFORE IT EVER RAN — RECORDED, NOT
        // SILENTLY DROPPED, because it is the #491 trap in its purest form. It asserted that
        // `visualCameraOpacity`'s doc no longer says "the Face source alone never shows a
        // picture". TRANSCRIBED, it failed twice over: the sentence lives in a COMMENT, so
        // `codeOnly` strips it and the needle could never match on EITHER tree — a parser that
        // matches nothing is a finding, never a pass — and against RAW text it was RED on the
        // CORRECT tree, because the repaired doc QUOTES the retracted sentence inside its own
        // ⛔ retraction. A negative scan on a retraction hits the retraction. The doc repair
        // itself stands; it simply cannot be guarded from here.
    }

    // MARK: - claim 2 — it fires in the face branch, ONCE, and BEFORE the session starts

    func testTheLatchFiresOnceAndBeforeTheSessionStarts() throws {
        let code = try source(Self.studio)
        // Three separate needles instead of one indented block: a multi-line literal would
        // pin WHITESPACE as much as code, and `codeOnly` keeps a stripped comment's
        // indentation (#898) — so a doc line added inside the branch would redden a correct
        // tree. The guard is the same: the assignment must sit behind the negated latch.
        XCTAssertTrue(code.contains("if !visualCameraIntroduced {"), """
            The one-shot latch in `startBioSource`'s `.face` branch is gone or no longer \
            guarded. Unguarded, every Face start would overwrite a performer who dialled the \
            layer back to 0 — the override this slice explicitly rejected.
            """)
        XCTAssertTrue(code.contains("visualCameraIntroduced = true"), """
            Nothing sets the latch, so the introduction would fire on EVERY Face start — see \
            the message above: that is an override, not an introduction.
            """)
        XCTAssertTrue(code.contains("visualCameraOpacity = StudioDefaultKeys.visualCameraIntroOpacity"), """
            The raise itself is gone, or it writes a literal instead of the named constant. \
            The value lives in `StudioDefaultKeys` on purpose — a literal here and a different \
            literal in the doc is how a number becomes a date (#818).
            """)
        guard let latch = code.range(of: "visualCameraOpacity = StudioDefaultKeys.visualCameraIntroOpacity"),
              let start = code.range(of: "faceExpression.start(publishing: bus)") else {
            return XCTFail("""
                Either the latch or `faceExpression.start(publishing: bus)` is missing from \
                EchoelStudioView — re-anchor this scan; do not let it pass (#454).
                """)
        }
        XCTAssertTrue(latch.lowerBound < start.lowerBound, """
            The camera-layer raise now happens AFTER the ARKit session starts. \
            `FaceExpressionBioPublisher` stores a frame only while a renderer wants one, and \
            the renderer wants one only while the opacity is above zero — so this order leaves \
            a window in which the session runs and stores nothing.
            """)
    }

    // MARK: - claim 3 — the studio binds the latch key

    func testTheStudioBindsTheLatchKey() throws {
        let code = try source(Self.studio)
        XCTAssertTrue(code.contains("@AppStorage(StudioDefaultKeys.visualCameraIntroduced.key)"), """
            `EchoelStudioView` no longer binds `visual.camera.introduced`, so the latch is \
            either reading a local that resets every launch (the camera would be re-introduced \
            forever) or it is gone entirely.
            """)
    }

    // MARK: - claim 4 (COUNTERWEIGHTS, #343) — what must NOT have changed

    func testTheStoredDefaultAndTheDoorAreUnchanged() throws {
        let keys = try source(Self.keys)
        let studio = try source(Self.studio)
        XCTAssertTrue(keys.contains("""
            public static let visualCameraOpacity = StudioDefault(key: "visual.camera.opacity", value: 0.0)
            """), """
            The STORED camera-layer default is no longer 0.0. That is the shortcut this slice \
            rejected: it shows the front camera on a camera-light take (finger on the BACK \
            lens), on a strap take and in the simulation — three sources that have no face in \
            front of them. If the founder ever asks for an always-on camera layer, this \
            assertion and the whole latch come out together, in one commit.
            """)
        XCTAssertEqual(studio.components(separatedBy: "label: \"Camera layer\"").count - 1, 1, """
            The `Camera layer` number row is gone or duplicated. The one-shot introduction is \
            only honest while the user can see and change the value afterwards — without the \
            row, 0.6 would be an undoable new default wearing a latch's clothes.
            """)
    }

    // MARK: - source access (§0/§2 — one stripper, skip on no tree, FAIL on a moved anchor)

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: """
                \(relativePath) is missing while the tree is present — renamed or moved. \
                Re-anchor this scan; do not let it skip (#454).
                """)
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}

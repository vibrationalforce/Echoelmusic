// TheFieldTurnsTheFaceOnTests.swift
// Echoel — #1298 (founder correction, 2026-09-12). Blocking bundle. SOURCE-TEXT scan.
//
// WHAT THIS GUARDS. The founder sent a screenshot of the pulse pill's source menu with
// "Play with your face — front camera, no pul…" circled in red and wrote: "es soll nicht dort
// angeschaltet werden sondern im Field und den Field Sound modulieren". #1257 had shipped the
// face as the FOURTH BIO SOURCE, i.e. as an alternative to camera-light, strap and simulation,
// reachable only from that menu — while its whole visible effect (the camera layer, opacity,
// blend, mirror, cut-out) lives in the Field panel, whose caption then sent the reader BACK to
// the pulse pill to switch it on. Same wrong-door shape as #1296 and #1297 in the same day:
// the capability was built and the way in was somewhere else.
//
// ⭐ ONE OWNER, TWO CALLERS — the distinction this file exists to keep. The Field switch does
// NOT call `faceExpression.start`/`stop`. It routes through `selectBioSource(_:)`, the single
// owner of every bio-source lifecycle, exactly as the pill's menu does. That is the
// `MIDIOutput.applyOutputPreferences()` form the law file praises, and the opposite of the
// BLE-3 mistake, where a second lifecycle owner killed a running strap on an unrelated edit
// mid-performance. Claim 2 pins the routing; claim 3 pins the absence of a direct call.
//
// ⚠️ IT SWITCHES THE SOURCE, IT DOES NOT ADD A LAYER — measured, not chosen.
// `FaceExpressionBioPublisher` builds its frame with `heartRateBPM: 0` under the comment
// "faceCam carries NO pulse (coexistence deferred)". Running the face BESIDE a pulse source
// would write that 0 into the one `latestBio` slot at 10 Hz, which is the #1015 interleave
// that three separate slices have already paid for. So Face TAKES the source, and OFF hands it
// back to whatever was playing before — which is why `bio.sourceBeforeFace` exists and why it
// is written only from a non-face source (claim 4: a second ON must not overwrite the real
// answer with "face" and strand the user on the front camera).
//
// ⚠️ LIMIT — SOURCE-TEXT SCAN (§1). Nothing here runs ARKit, renders the row or proves the
// hand-back actually restores a Bluetooth strap. That is a DEVICE probe; the marker sits at
// the switch. This file proves the switch exists in the Field row, routes through the one
// owner, and remembers the right thing.
//
// ⚠️ HONEST GRADING (#433/#464) — transcribed in Python against the parent (7390b9e) and this
// tree. 8 assertions in 5 tests: claims 1 (1) + 2 (2) + 3 (1) + 4 (1) + 5 (3), plus the
// anchor XCTFail in claim 1. Against the PARENT exactly FOUR are red — 1a, 2a, 2b and 4a —
// as ONE finding (#486), all FORWARD, naming lines born with this commit. The other FOUR are
// COUNTERWEIGHTS, green on BOTH trees: the studio already called `faceExpression.start(`
// exactly once, the row was already device-gated, `selectBioSource` already had this
// signature, and the publisher already published a zero pulse.
//
// ⭐ CLAIM 3 IS THE COUNTERWEIGHT THAT MATTERS MOST, and it is worth naming why a green-on-
// both-trees assertion earns its place here rather than reading as filler: the ONE-owner
// property it pins was free before this slice (only `startBioSource` could reach the
// publisher) and is now something a future edit can plausibly break, because there is a
// second control in a second file-region that obviously WANTS to call start directly. The
// mutation "ON bypasses owner" reddens 2a and 3a together, which is exactly the shape of the
// mistake it is there to catch. Six mutations driven; each reddened its own claim.
// `SourceText.codeOnly` is PROPHYLAKTISCH, MEASURED: 0 of 16 verdicts flip raw-vs-stripped.
//
// ⛔ WHAT THIS FILE DELIBERATELY DOES NOT ASSERT (#364). It does NOT forbid the pulse pill's
// menu from continuing to offer the face entry. Removing that entry is its own slice — it
// reddens two existing guards (`TheBioSourceChooserHasOneDefinitionTests` pins the chooser
// label, `TheFaceSourceHasADoorTests` pins the offer) and those must move in the SAME commit
// as the removal, not this one. Two doors onto ONE owner is not the BLE-3 defect; two OWNERS
// would be, and claim 3 is what actually stands guard over that.

import Foundation
import XCTest

final class TheFieldTurnsTheFaceOnTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let publisher = "Sources/Echoelmusic/Bio/FaceExpressionBioPublisher.swift"

    // MARK: - claim 1 — the switch is in the Field's camera row

    func testTheFieldRowCarriesTheFaceSwitch() throws {
        let code = try source(Self.studio)
        guard let row = code.range(of: "private var cameraLayerRow: some View {"),
              let next = code.range(of: "\n    private var ", range: row.upperBound..<code.endIndex)
                ?? code.range(of: "\n    // musicColourRow", range: row.upperBound..<code.endIndex) else {
            return XCTFail("""
                `cameraLayerRow` is missing or its member boundary moved — re-anchor this scan; \
                do not let it pass (#454).
                """)
        }
        let body = String(code[row.upperBound..<next.lowerBound])
        XCTAssertTrue(body.contains("Text(\"Play with your face\")"), """
            The Field's camera row no longer carries the "Play with your face" switch. That \
            switch IS the founder's 2026-09-12 correction: everything the face does visibly \
            lives in this row, so this is where it is turned on. Without it the row's own \
            caption is the only pointer left, and it points at a menu the founder asked to \
            stop using for this.
            """)
    }

    // MARK: - claim 2 — it routes through the ONE lifecycle owner, both ways

    func testTheSwitchRoutesThroughTheOneOwner() throws {
        let code = try source(Self.studio)
        XCTAssertTrue(code.contains("selectBioSource(BioSourceKind.face.rawValue)"), """
            The ON path no longer calls `selectBioSource`. Starting the publisher directly \
            from this row would make the Field a SECOND lifecycle owner beside the pulse \
            pill's menu — the BLE-3 defect verbatim, where the second owner tore down a \
            running strap on an unrelated edit in the middle of a performance.
            """)
        XCTAssertTrue(code.contains("selectBioSource(bioSourceBeforeFace)"), """
            The OFF path no longer hands the source back through `selectBioSource`. Turning \
            the face off must return the bus to the source that was playing before, through \
            the same owner — otherwise OFF either strands the user with no pulse source or \
            races the owner from outside.
            """)
    }

    // MARK: - claim 3 — and never reaches past it into the publisher

    func testTheStudioNeverStartsTheFacePublisherDirectly() throws {
        let code = try source(Self.studio)
        XCTAssertEqual(code.components(separatedBy: "faceExpression.start(").count - 1, 1, """
            `EchoelStudioView` calls `faceExpression.start(` more than once (or not at all). \
            Exactly ONE call may exist, inside `startBioSource`'s `.face` branch — that \
            function IS the owner. A second call anywhere, and most plausibly in the new Field \
            switch, is the second-owner defect this whole slice was shaped to avoid.
            """)
    }

    // MARK: - claim 4 — OFF remembers the right source

    func testTheReturnSourceIsNeverOverwrittenWithFace() throws {
        let code = try source(Self.studio)
        XCTAssertTrue(code.contains("if bioSourceRaw != BioSourceKind.face.rawValue {"), """
            The guard around writing `bioSourceBeforeFace` is gone. Without it, switching the \
            face ON while it is already the source stores "face" as the source to return to — \
            and OFF then hands the bus back to the front camera, stranding the performer on it \
            with no way back except the menu this slice exists to stop needing.
            """)
    }

    // MARK: - claim 5 (COUNTERWEIGHTS, #343) — what must NOT have changed

    func testTheRowStaysDeviceGatedAndTheOwnerStillExists() throws {
        let code = try source(Self.studio)
        XCTAssertTrue(code.contains("if FaceExpressionBioPublisher.isSupported, !donutIsThePicture {"), """
            The camera row lost its device gate. The switch now lives inside it, so removing \
            the gate offers "Play with your face" on a phone with no TrueDepth camera — a \
            control that cannot do anything, which is the doorless-surface defect inverted.
            """)
        XCTAssertTrue(code.contains("private func selectBioSource(_ id: String?) {"), """
            `selectBioSource(_:)` is gone or changed signature. It is the one owner both \
            doors call; claim 2's needles are written against exactly this spelling and must \
            be re-pointed in the same commit as any rename.
            """)
        XCTAssertTrue(try source(Self.publisher).contains("heartRateBPM: 0"), """
            The face frame no longer publishes a zero pulse. That zero is the MEASUREMENT \
            behind this slice's central decision — that Face SWITCHES the source instead of \
            running beside one. If the publisher learned to carry a real pulse, the switch \
            can become an additive layer, and this file's ⚠️ block plus the row's comment \
            must be rewritten in that same commit rather than left claiming a constraint that \
            has lifted.
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

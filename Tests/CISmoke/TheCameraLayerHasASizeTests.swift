// TheCameraLayerHasASizeTests.swift
// Echoel — #1299 (founder 2026-09-12: "das Gesicht kann in der Größe angepasst werden").
// Blocking bundle. SOURCE-TEXT scan plus one pure arithmetic claim.
//
// WHAT THIS GUARDS. K5 (#1262) gave the camera layer opacity, mirror, blend and (K7) a
// cut-out. It gave it no SIZE, so the face filled whatever box the viewport transform handed
// over and the performer could not decide how much of the field it should take. This adds one
// number and threads it through the same five places opacity already travels: the shared key,
// the renderer's `setLook`, both mounts, and the Field row.
//
// ⭐ WHY THE SCALE IS COMPOSED ON THE CPU AND THE SHADER IS UNTOUCHED. The camera pass already
// receives a viewport→image affine (`camA…camTy`) in normalised image space. Magnifying the
// picture by `s` is the same thing as sampling a smaller box about the centre —
// `uv' = (uv − ½)/s + ½` — which is six multiplies on the linear part plus a re-centred
// translation. A shader uniform and a per-pixel branch would buy nothing and cost every pixel.
// Claim 3 is the arithmetic, driven rather than asserted by eye.
//
// ⚠️ THE RE-APPLICATION EVERY FRAME IS THE LOAD-BEARING DETAIL, not the formula.
// `viewportToImage` is refreshed ONLY when a new camera frame binds. Composing the scale in
// there would leave a size change invisible until the next frame — fine at 30 fps, NOT fine at
// the `.low` governor tier or while the session is momentarily stalled, which is exactly when
// a performer reaches for a dial. So the raw transform is stored (`cameraRawTransform`) and
// the scale is composed on every draw. Claim 2 pins that split; without it the feature would
// work on the bench and feel broken in the room.
//
// ⚠️ TWO CLAMPS, DIFFERENT JOBS, deliberately different numbers. The renderer clamps to
// 0.25…4 at the ONE boundary the value crosses into it, because a NaN or a zero from a
// corrupted default would divide the affine; the Field row offers 0.5…2.5, the musical range.
// A single shared constant would read tidier and would merge a safety net with a taste
// decision — claim 4 pins both, separately, so a later "unify these" edit has to face that.
//
// ⚠️ LIMIT — SOURCE-TEXT SCAN (§1) for claims 1, 2, 4, 5. Nothing here runs Metal or renders a
// pixel; whether 2.5 is far enough and 0.5 is small enough is a DEVICE probe, and the marker
// sits at the row. Claim 3 is real arithmetic and holds on any machine.
//
// ⚠️ HONEST GRADING (#433/#464) — transcribed in Python against the parent (c8bf48c) and this
// tree. 12 assertions in 5 tests, hand-counted: claim 1 (3 — one plus a two-iteration loop)
// + 2 (2, plus an anchor XCTFail) + 3 (4) + 4 (2) + 5 (1). SEVEN needles are red against the
// PARENT as ONE finding (#486) — 1a/1b/1c, 2a/2b, 4a/4b, every one naming a line born with
// this commit, all FORWARD, no regression claimed. Claim 3 is green on both trees because it
// tests a FORMULA rather than a tree, and claim 5 is a COUNTERWEIGHT, green on both. SEVEN
// mutations driven; each reddened exactly its own claim and nothing else.
// `SourceText.codeOnly` is PROPHYLAKTISCH, MEASURED: 0 of 18 verdicts flip raw-vs-stripped.

import Foundation
import XCTest

final class TheCameraLayerHasASizeTests: XCTestCase {

    private static let keys = "Sources/Echoelmusic/Core/StudioDefaultKeys.swift"
    private static let renderer = "Sources/Echoelmusic/Views/MetalBioView.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let window = "Sources/Echoelmusic/Studio/FloatingVisualWindow.swift"
    private static let stage = "Sources/Echoelmusic/Studio/ExternalDisplayScene.swift"

    // MARK: - claim 1 — one shared key, and BOTH mounts pass it explicitly (#431)

    func testTheSizeIsOneSharedKeyBothMountsPass() throws {
        let keys = try source(Self.keys)
        XCTAssertTrue(keys.contains("""
            public static let visualCameraSize = StudioDefault(key: "visual.camera.size", value: 1.0)
            """), """
            `visualCameraSize` is gone or changed shape. It must be a SHARED key like the other \
            four `visual.camera.*`: the phone's floating window and the external stage are two \
            renderers, and a size that lives in only one of them means the beamer shows a \
            different picture from the phone.
            """)
        for path in [Self.window, Self.stage] {
            let code = try source(path)
            XCTAssertTrue(code.contains("cameraSize: Float("), """
                \(path) does not pass `cameraSize:` to `MetalBioView(`. The struct property \
                carries a default of 1, so this does not fail to COMPILE — it fails silently, \
                rendering the literal for no caller, which is the #431 defect this project has \
                already paid for once on these same camera dials.
                """)
        }
    }

    // MARK: - claim 2 — the raw transform is stored and the scale re-applied every frame

    func testTheScaleIsReappliedOnEveryDrawNotOnlyOnANewFrame() throws {
        let code = try source(Self.renderer)
        XCTAssertTrue(code.contains("cameraRawTransform = latest.viewportToImage"), """
            The renderer no longer STORES the raw viewport→image affine. If the camera uniforms \
            are written where the frame binds, a size change is invisible until the next camera \
            frame arrives — imperceptible at 30 fps and very perceptible at the `.low` governor \
            tier or during a stall, which is exactly when a performer reaches for the dial.
            """)
        guard let scale = code.range(of: "let camScale = Double(lookCameraSize)"),
              let present = code.range(of: "uniforms.camPresent = cameraTexturesCurrent == nil ? 0 : 1") else {
            return XCTFail("""
                The per-frame camera-uniform block moved — re-anchor this scan; do not let it \
                pass (#454).
                """)
        }
        XCTAssertTrue(scale.lowerBound < present.lowerBound, """
            The size scale is no longer composed in the per-frame block beside `camPresent`, \
            `camMirror` and `camBlend`. Those three are written on EVERY draw precisely because \
            a user can change them between frames; the size is the same kind of value and \
            belongs in the same place.
            """)
    }

    // MARK: - claim 3 — the arithmetic actually magnifies about the centre

    func testTheAffineScaleSamplesASmallerBoxAboutTheCentre() {
        // The renderer's composition, verbatim: a' = a/s, tx' = (tx − ½)/s + ½.
        func compose(_ t: (a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double),
                     _ s: Double) -> (Double, Double, Double, Double, Double, Double) {
            (t.a / s, t.b / s, t.c / s, t.d / s, (t.tx - 0.5) / s + 0.5, (t.ty - 0.5) / s + 0.5)
        }
        func map(_ m: (Double, Double, Double, Double, Double, Double),
                 _ x: Double, _ y: Double) -> (Double, Double) {
            (m.0 * x + m.2 * y + m.4, m.1 * x + m.3 * y + m.5)
        }
        let identity = (a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 0.0, ty: 0.0)
        // s = 1 must be a no-op, or every existing take changes the day this ships.
        let unity = compose(identity, 1)
        let corner = map(unity, 0, 0), far = map(unity, 1, 1)
        XCTAssertEqual(corner.0, 0, accuracy: 1e-12)
        XCTAssertEqual(far.1, 1, accuracy: 1e-12)
        // s = 2 must sample the middle HALF of the image — the face twice as big on screen.
        let doubled = compose(identity, 2)
        let a = map(doubled, 0, 0), b = map(doubled, 1, 1), mid = map(doubled, 0.5, 0.5)
        XCTAssertEqual(mid.0, 0.5, accuracy: 1e-12, """
            The centre of the viewport no longer maps to the centre of the image. Magnifying \
            must happen ABOUT THE CENTRE; scaling the linear part without re-centring the \
            translation slides the face into a corner as it grows.
            """)
        XCTAssertTrue(a.0 > 0.2499 && a.0 < 0.2501 && b.0 > 0.7499 && b.0 < 0.7501, """
            At size 2 the viewport must sample the image box 0.25…0.75, i.e. the middle half. \
            Got \(a.0)…\(b.0). A box larger than that shrinks the face while claiming to \
            enlarge it — the dial would run backwards.
            """)
    }

    // MARK: - claim 4 — two clamps, two jobs, two numbers

    func testTheSafetyClampAndTheMusicalRangeStaySeparate() throws {
        let renderer = try source(Self.renderer)
        let studio = try source(Self.studio)
        XCTAssertTrue(renderer.contains("min(max(cameraSize, 0.25), 4) : 1"), """
            The renderer's own clamp is gone or changed. It exists for the NON-FINITE and \
            zero cases — the affine divides by this number, so a NaN or a 0 arriving from a \
            corrupted stored default would destroy the transform for the rest of the session. \
            That is a safety net, not a taste decision, and it must not be merged into the \
            row's range below.
            """)
        XCTAssertTrue(studio.contains("""
            EchoelValueField(label: "Camera size", value: $visualCameraSize, range: 0.5...2.5, decimals: 2)
            """), """
            The `Camera size` row is gone or changed. It is an `EchoelValueField` and never a \
            `Slider` — the app-wide one-control law for a NUMERIC parameter — and its 0.5…2.5 \
            is the musical range, deliberately narrower than the renderer's safety clamp.
            """)
    }

    // MARK: - claim 5 (COUNTERWEIGHT, #343) — the layer is still the Face source's alone

    func testTheLayerStillDrawsOnlyForTheFaceSource() throws {
        let code = try source(Self.studio)
        XCTAssertTrue(code.contains("if FaceExpressionBioPublisher.isSupported, !donutIsThePicture {"), """
            The camera row lost its device gate, so `Camera size` now appears on phones that \
            cannot track a face and under the donut renderer, which no texture reaches. A size \
            dial for a layer that cannot draw is the doorless-surface defect inverted — a door \
            onto nothing.
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

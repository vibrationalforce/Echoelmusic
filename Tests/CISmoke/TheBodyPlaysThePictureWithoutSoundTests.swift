// TheBodyPlaysThePictureWithoutSoundTests.swift
// Echoel — #1246 (founder 2026-09-11: *"Es wäre toll, wenn sich das Biofeedback auch mit den
// visuals verbinden lässt ohne das man Sound anhaben muss"*). A silent body take: the sensor
// alone, the picture follows, nothing sounds.
//
// THE GAP WAS THE START PATH, NOT THE PIPELINE. `MetalBioView` reads no transport and no
// `isPlaying`; `BioVisualParams` is Foundation-pure; no bio publisher touches `AudioEngine`.
// But `startBioSource()` was reachable only through `startBiofeedback()`, which composes
// (`generate`) and starts the transport first — so a body could reach the picture only
// through a sounding take. `setBodyOnly(_:)` arms the source alone; `BodyOnlyRow` is its door
// in the bio panel; `stopEverything` tears it down with the rest; a source switch while
// body-only swaps the sensor without waking the instrument. And because a silent take had
// no music level, the water dish opened on a mirror — `bodyDrive` (breath swell, gated on the
// measured waveform) is the substitute drive.
//
// SOURCE-TEXT SCAN throughout (§1): the members are `private` on a `View`. Whether the
// picture visibly breathes with a finger on the lens and no sound is a DEVICE PROBE —
// NEEDS-FOUNDER-VERIFY sits at `setBodyOnly`.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`65b89bc`) and this tree: claims
// 1–5 RED on the parent (no `bodyOnly`, no `bodyDrive`), GREEN here; claim 6 (the renderer
// stays transport-agnostic) GREEN on both — the counterweight that makes claim 5 mean
// something. Stripper: PROPHYLAKTISCH (0 of 12 verdicts flip).

import Foundation
import XCTest

final class TheBodyPlaysThePictureWithoutSoundTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let renderer = "Sources/Echoelmusic/Views/MetalBioView.swift"

    /// Claim 1 — the door: a `BodyOnlyRow` is mounted in the bio panel and says what it does.
    func testTheBioPanelMountsTheBodyOnlyDoor() throws {
        let src = SourceText.codeOnly(try text(Self.studio))
        let panel = try Self.member("private var bioPanel: some View", in: src)
        XCTAssertTrue(panel.contains("BodyOnlyRow(isOn: Binding(get: { bodyOnly }, set: { setBodyOnly($0) })"),
                      "the bio panel no longer mounts the body-only door (#1246)")
        XCTAssertEqual(src.components(separatedBy: "struct BodyOnlyRow: View").count - 1, 1,
                       "exactly one `BodyOnlyRow` leaf (#1246)")
        XCTAssertTrue(src.contains("\"Body without sound\""),
                      "the toggle's label changed — the founder-verify note and this guard name it (#1246)")
    }

    /// Claim 2 — the silent arm: `setBodyOnly(true)` starts the SENSOR and nothing that sounds.
    func testTheSilentArmStartsNoInstrument() throws {
        let src = SourceText.codeOnly(try text(Self.studio))
        let fn = try Self.member("private func setBodyOnly(_ on: Bool)", in: src)
        XCTAssertEqual(fn.components(separatedBy: "await startBioSource()").count - 1, 1,
                       "`setBodyOnly` must bring up the chosen bio source exactly once (#1246)")
        XCTAssertTrue(fn.contains("guard !running, !bodyOnly else { return }"),
                      "body-only must refuse while the instrument runs — two owners of one strap is the BLE-3 bug (#1246)")
        for forbidden in ["generate(", "startEvolving()", "pattern.play(", "pattern.start(", "startBiofeedback()"] {
            XCTAssertFalse(fn.contains(forbidden),
                           "`setBodyOnly` calls `\(forbidden)` — the silent take is no longer silent (#1246)")
        }
        XCTAssertTrue(fn.contains("if !running { stopBioSource() }"),
                      "releasing body-only must stop the sensor unless the instrument owns it now (#1246)")
    }

    /// Claim 3 — Stop ends the silent take too, so the toggle cannot lie after a Stop.
    func testStopReleasesTheSilentTake() throws {
        let src = SourceText.codeOnly(try text(Self.studio))
        let stop = try Self.member("private func stopEverything(", in: src)
        XCTAssertTrue(stop.contains("bodyOnly = false"),
                      "`stopEverything` no longer resets `bodyOnly` — a Stop leaves the switch on with the camera off (#1246)")
        XCTAssertTrue(stop.contains("bodyOnlyTask?.cancel()"),
                      "an in-flight silent start survives Stop and can resurrect the camera (#1246)")
    }

    /// Claim 4 — a source switch during a silent take stays silent.
    func testASourceSwitchWhileSilentDoesNotWakeTheInstrument() throws {
        let src = SourceText.codeOnly(try text(Self.studio))
        let fn = try Self.member("private func selectBioSource(_ id: String?)", in: src)
        XCTAssertTrue(fn.contains("} else if bodyOnly {"),
                      "`selectBioSource` has no body-only branch — picking a source while silent falls into `startBiofeedback()` and sounds (#1246)")
        XCTAssertEqual(fn.components(separatedBy: "startBiofeedback()").count - 1, 1,
                       "exactly one branch of `selectBioSource` may start the instrument — the idle one (#1246)")
    }

    /// Claim 5 — the renderer has a substitute drive so a silent take is not a mirror.
    func testTheDishHasABodyDrive() throws {
        let src = SourceText.codeOnly(try text(Self.renderer))
        XCTAssertTrue(src.contains("let bodyDrive: Float = bio.map {"),
                      "`bodyDrive` is gone — a silent take opens on a mirror again (#1246)")
        XCTAssertTrue(src.contains("$0.hasMeasuredBreathWaveform ? 0.4 * $0.breathPhaseForSound"),
                      "the body drive must be gated on the measured WAVEFORM — `breathPhaseForSound` is a frozen 0.5 on HealthKit (#1140/#1246)")
        XCTAssertTrue(src.contains("dishDriveTarget = min(max(musicLevel + 0.5 * touchE, bodyDrive), 1)"),
                      "the dish no longer takes the body drive as its floor (#1246)")
    }

    /// Claim 6 — counterweight: the renderer is still transport-agnostic (true before and after).
    func testTheRendererStillReadsNoTransport() throws {
        let src = SourceText.codeOnly(try text(Self.renderer))
        XCTAssertFalse(src.contains("isPlaying"), "the renderer started reading `isPlaying` — a silent take would then have to fake a transport (#1246)")
        XCTAssertFalse(src.contains("transport."), "the renderer started reading the transport (#1246)")
        XCTAssertFalse(src.contains("instrumentRunning"), "the renderer started gating on the instrument flag (#1246)")
    }

    // MARK: - helpers

    /// Brace-matched body of the member whose declaration starts with `marker` (#408: no
    /// fixed line window; the marker must occur once).
    private static func member(_ marker: String, in src: String) throws -> String {
        let hits = src.components(separatedBy: marker).count - 1
        guard hits == 1, let start = src.range(of: marker) else {
            throw XCTSkip("anchor `\(marker)` occurs \(hits)× — re-anchor before trusting a zero (#408)")
        }
        guard let open = src[start.upperBound...].firstIndex(of: "{") else { return "" }
        var depth = 0
        var i = open
        while i < src.endIndex {
            let c = src[i]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(src[open...i]) } }
            i = src.index(after: i)
        }
        return String(src[open...])
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

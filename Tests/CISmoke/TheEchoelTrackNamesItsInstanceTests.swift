// TheEchoelTrackNamesItsInstanceTests.swift
// Echoel — WA4 path 9 follow-up: the Echoel track says what its instance is set to.
//
// WHAT THIS PINS. The Echoel track's device row named the device and opened its editor, and
// said nothing about the instance. `EchoelInstanceLine` shows its genre and FX character,
// read-only, from the SAME keys the instrument writes, resolved through their types — the
// `EchoelInstanceState.assemble` rule, not a second one.
//
// 1. SOURCE: the leaf reads exactly those two keys, through the typed owners' names, and
//    WRITES NOTHING — no assignment, no binding, no `UserDefaults`, no literal key.
// 2. COUNTERWEIGHT: the instrument still writes the same two keys (`style` / `fxCharacter`
//    in `EchoelStudioView`), and `EchoelInstanceState.fxCharacterKey` still names the
//    instrument's literal — otherwise the line would read a key nobody writes and show the
//    default forever.
// 3. SOURCE: the line is mounted once, on the Echoel track only, and the inspector itself still
//    owns no persistence (the ban in `TheTrackInspectorShowsOnlyWiredControlsTests` claim 4 is
//    why the leaf is its own file).
// 4. SOURCE: no hot state in the leaf — it sits in the Workstation plate, under the menu host.
//
// Grading (§0, no Swift toolchain in a web session): all claims driven in Python against this
// tree and against be933a627. On be933a627 claims 1, 3 and 4 are red by ABSENCE of
// `Studio/EchoelInstanceLine.swift` — one absence (#486); they are FORWARD guards. Claim 2 is a
// COUNTERWEIGHT, green on both. NOT covered: that the line renders legibly at large type and
// changes when the genre picker does — a device probe.
// NEEDS-FOUNDER-VERIFY: Workstation → tap the Echoel track → the inspector shows
// "Genre <the genre> FX <the character>" → change the genre on the instrument → back on the
// Workstation the line shows the new genre; with the largest text size the two facts stack
// instead of truncating.

import Foundation
import XCTest

final class TheEchoelTrackNamesItsInstanceTests: XCTestCase {

    private static let linePath = "Sources/Echoelmusic/Studio/EchoelInstanceLine.swift"
    private static let inspectorPath = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"
    private static let studioPath = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let statePath = "Sources/Echoelmusic/Core/EchoelInstanceState.swift"

    // MARK: 1 — the same two keys, read, never written

    func testTheLineReadsTheInstrumentsTwoKeysAndWritesNothing() throws {
        let line = try code(Self.linePath)
        for needle in ["@AppStorage(StudioDefaultKeys.genre.key) private var genre: MusicStyle = StudioDefaultKeys.genre.value",
                       "@AppStorage(EchoelInstanceState.fxCharacterKey) private var character: FXCharacter = .auto",
                       "genre.displayName", "character.displayName"] {
            XCTAssertTrue(line.contains(needle), "the instance line lost `\(needle)`")
        }
        XCTAssertEqual(line.components(separatedBy: "@AppStorage(").count - 1, 2,
                       "the line reads exactly two keys — a third is a second editor growing")
        for banned in ["genre =", "character =", "$genre", "$character", "UserDefaults",
                       "\"studio.fxCharacter\"", "Picker(", "Button("] {
            XCTAssertFalse(line.contains(banned),
                           "the instance line contains `\(banned)` — it is read-only; the editor is the Sound plate behind Open")
        }
    }

    // MARK: 2 — counterweight: the instrument writes the keys the line reads

    func testTheInstrumentStillWritesTheKeysTheLineReads() throws {
        let studio = try code(Self.studioPath)
        XCTAssertTrue(studio.contains("@AppStorage(StudioDefaultKeys.genre.key) private var style: MusicStyle = StudioDefaultKeys.genre.value"),
                      "the instrument's genre moved off `StudioDefaultKeys.genre` — the line would show a genre nobody plays")
        XCTAssertTrue(studio.contains("@AppStorage(\"studio.fxCharacter\") private var fxCharacter: FXCharacter = .auto"),
                      "the instrument's FX character moved off its key — the line would show `.auto` forever")
        let state = try code(Self.statePath)
        XCTAssertTrue(state.contains("public static let fxCharacterKey = \"studio.fxCharacter\""),
                      "`EchoelInstanceState.fxCharacterKey` must name the instrument's literal")
    }

    // MARK: 3 — mounted once, on the Echoel track, in an inspector that owns no persistence

    func testTheLineIsMountedOnceOnTheEchoelTrack() throws {
        let inspector = try code(Self.inspectorPath)
        XCTAssertEqual(inspector.components(separatedBy: "EchoelInstanceLine()").count - 1, 1,
                       "the line is mounted once, in the track inspector")
        guard let mount = inspector.range(of: "EchoelInstanceLine()") else {
            return XCTFail("ANCHOR MISSING: the EchoelInstanceLine mount (#454)")
        }
        let before = String(inspector[inspector.startIndex..<mount.lowerBound])
        guard let gate = before.range(of: "if controls.role == .echoelInstrument {", options: .backwards) else {
            return XCTFail("ANCHOR MISSING: the Echoel-track gate before the mount (#454)")
        }
        let between = String(before[gate.upperBound...])
        XCTAssertFalse(between.contains("}"),
                       "the line must sit directly inside `if controls.role == .echoelInstrument` — a rack voice has no genre")
        XCTAssertFalse(inspector.contains("@AppStorage"),
                       "the inspector owns no persistence; the line is its own file for exactly that reason")
    }

    // MARK: 4 — no hot state in a leaf under the menu host

    func testTheLineReadsNoHotState() throws {
        let line = try code(Self.linePath)
        for hot in ["latestBio", "EngineBus", "currentTick", "CameraRPPGBioPublisher",
                    "masterLevel", "TimelineView(", "Timer"] {
            XCTAssertFalse(line.contains(hot), "the instance line reads `\(hot)` — a clock-rate read churns the Workstation plate")
        }
    }

    // MARK: helpers

    private func code(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: repoRoot().appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }

    private func repoRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }
}

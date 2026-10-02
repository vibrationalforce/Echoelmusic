// TheMixerEndsInTheMasterStripTests.swift
// Echoel — DAW shell S5 (founder 2026-10-02, "DAW look mit allen Features"): the Mixer ends in its
// master. `MasterStripView` is the last strip of the Mixer view and carries the master volume, the
// stereo level bars with the four EBU R128 numbers, and their Clear.
//
// WHY: until S5 the master level and the loudness meters stood in the Instrument stage's Master
// panel — behind a chip, on a different stage from the track strips they sum. Balancing a song
// meant leaving the Mixer to read what the balance did.
//
// THE FIVE CLAIMS:
// 1. SOURCE: the strip mounts the fader leaf, the loudness leaf and the Clear, once each, in that
//    order; its own code reads NO engine property (the hot reads stay in the two leaves — the
//    10.76.41/50 law) and presents no modal.
// 2. SOURCE: ONE DOOR — the three MOVED. `MasterVolumeField()` is built only on the strip;
//    `MasterLoudnessGrid()` nowhere in the Instrument file; `resetMastering()` is called only by
//    the strip and by the grid's own appear. (The absence inside `masterPanel` is pinned a second
//    time, at the panel, by `MasterPanelReflowsTests` claim 3.)
// 3. SOURCE: the Workstation mounts the strip once, under `if pieceView == .mixer {`, AFTER the
//    track strips and OUTSIDE the empty-song branch — brace depth of that `if` equals the depth of
//    `if summary.isEmpty {`. An empty song still plays the instrument; its master stays reachable.
// 4. END-TO-END: the metering owner is named for the READOUT (`.masterReadout`), not for the panel
//    the readout left; the set of owners is exactly the two readers.
// 5. CATALOG: the strip's sentence, the panel's new subtitle and the transport meter's corrected
//    hint are keys; the three sentences they replace are gone (StringCatalogIsHonestTests' orphan
//    rule would also catch a stale key, this names the three on purpose).
//
// GRADING (§0/§3, no Swift toolchain in a web session — transcribed in Python against both trees):
// against the parent (7bcf13c37) `MasterStripView.swift` does not exist and `.masterReadout` is not
// a case, so this file does NOT COMPILE there — no assertion has a verdict on the parent. Hand-
// transcribed, claims 1, 3 and 5's new-key half are red there by ONE absence (the strip, #486);
// claim 2 is a REGRESSION guard (red there: `EchoelStudioView` still builds the fader, the grid and
// the Clear); claim 4 is FORWARD (it names a case this commit creates). Counterweights green on
// both trees: `PieceMixerView(` still drawn in the Mixer branch, the grid's own `resetMastering()`
// on appear. DEVICE PROBE, open: the master strip reads under the track strips at 375–440 pt, the
// fader is heard, the numbers move while the song plays, and Clear restarts the integration.

import XCTest
@testable import Echoelmusic

final class TheMixerEndsInTheMasterStripTests: XCTestCase {

    private static let strip = "Sources/Echoelmusic/Studio/MasterStripView.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let grid = "Sources/Echoelmusic/Studio/MasterLoudnessGrid.swift"
    private static let catalog = "Sources/Echoelmusic/Resources/Localizable.xcstrings"

    // MARK: 1 — the strip carries the master's level, and reads nothing hot itself

    func testTheStripCarriesTheFaderTheNumbersAndTheirClear() throws {
        let code = SourceText.codeOnly(try text(Self.strip))
        let body = try member("var body: some View {", in: code)
        let parts = ["MasterVolumeField()", "MasterLoudnessGrid()", "audioEngine.resetMastering()"]
        for part in parts {
            XCTAssertEqual(body.components(separatedBy: part).count - 1, 1,
                           "the master strip mounts `\(part)` exactly once")
        }
        let positions = parts.compactMap { body.range(of: $0)?.lowerBound }
        XCTAssertEqual(positions.count, parts.count, "ANCHOR MISSING: one of the strip's three parts (#454)")
        if positions.count == parts.count {
            XCTAssertTrue(positions[0] < positions[1] && positions[1] < positions[2],
                          "reading order: the fader, then what it did, then the Clear for the numbers")
        }
        // The strip's own body reads no engine property — the only engine use is the Clear ACTION.
        XCTAssertEqual(code.components(separatedBy: "audioEngine.").count - 1, 1, """
            the master strip touches the engine somewhere besides the Clear action. Every hot read \
            (masterVolume rewritten per transport step, the 60 Hz meters) belongs in its own leaf — \
            `MasterVolumeField`, `MasterLoudnessGrid` — never in a body the Mixer scrolls (10.76.41/50)
            """)
        for hot in ["masterLevel", "masterVolume", "masterOutput", "cameraRPPG", "latestBio", "currentTick"] {
            XCTAssertFalse(code.contains(hot), "the master strip reads `\(hot)` in its own body")
        }
        for modal in [".sheet(", ".fullScreenCover(", ".popover(", ".alert(", ".confirmationDialog("] {
            XCTAssertFalse(code.contains(modal), "the master strip is a view of the plate, never a modal: `\(modal)`")
        }
    }

    // MARK: 2 — one door: the fader, the numbers and the Clear moved, they were not copied

    func testTheMastersLevelHasOneDoor() throws {
        let fader = try filesMatching { $0.contains("MasterVolumeField()") }
        XCTAssertEqual(fader, [Self.strip], "the master volume field is built on the master strip and nowhere else")
        let numbers = try filesMatching { $0.contains("MasterLoudnessGrid()") }
        XCTAssertTrue(numbers.contains(Self.strip), "the loudness numbers are on the master strip")
        XCTAssertFalse(numbers.contains(Self.studio), "the Instrument file mounts the loudness numbers again — a second door")
        let clear = try filesMatching { $0.contains(".resetMastering()") }
        XCTAssertEqual(clear, [Self.grid, Self.strip], """
            `resetMastering()` is CALLED by the master strip's Clear and by the grid's own appear — \
            nothing else (the needle carries the receiver's dot, so the engine's own `func \
            resetMastering()` declaration is not a call site). Found: \(clear)
            """)
        // counterweight: the grid still resets its integration window when it appears.
        let grid = SourceText.codeOnly(try text(Self.grid))
        XCTAssertTrue(grid.contains("audioEngine.resetMastering()"), "the grid's fresh-window reset on appear")
    }

    // MARK: 3 — the Workstation ends the Mixer in the master, on every song

    func testTheMixerEndsInTheMasterOnEverySong() throws {
        let workstation = SourceText.codeOnly(try text(Self.workstation))
        XCTAssertEqual(try filesMatching { $0.contains("MasterStripView()") }, [Self.workstation],
                       "the master strip has one construction, on the piece's plate")
        XCTAssertEqual(workstation.components(separatedBy: "MasterStripView()").count - 1, 1,
                       "the Workstation mounts the master strip once")
        guard let strip = workstation.range(of: "MasterStripView()"),
              let mixer = workstation.range(of: "PieceMixerView(voiceCapacity: player.laneVoiceCapacity)"),
              let empty = workstation.range(of: "if summary.isEmpty {") else {
            return XCTFail("ANCHOR MISSING: the strip, the mixer or the empty-song branch (#454)")
        }
        XCTAssertLessThan(mixer.lowerBound, strip.lowerBound, "the master comes after the track strips")
        let gateNeedle = "if pieceView == .mixer {"
        guard let gate = workstation.range(of: gateNeedle, options: .backwards, range: workstation.startIndex..<strip.lowerBound) else {
            return XCTFail("the master strip is not under `\(gateNeedle)`")
        }
        let between = workstation[gate.upperBound..<strip.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(between, "", "the master strip is the first thing in its Mixer gate: `\(between.prefix(80))`")
        XCTAssertEqual(depth(at: gate.lowerBound, in: workstation), depth(at: empty.lowerBound, in: workstation), """
            the master strip's Mixer gate is not a sibling of the empty-song branch. Nested inside \
            it, an empty song (which still plays the instrument) would hide the master level.
            """)
    }

    // MARK: 4 — the metering owner is named for the readout, not for where it is mounted

    func testTheMeteringOwnerIsNamedForTheReadout() {
        XCTAssertEqual(Set(DetailedMeteringOwner.allCases), [.masterReadout, .scope],
                       "exactly two readers keep the expensive meters running: the loudness readout and the scope")
        var claims = DetailedMeteringClaims()
        XCTAssertTrue(claims.claim(.masterReadout))
        XCTAssertFalse(claims.release(.masterReadout), "the last reader left — the meters stop")
    }

    // MARK: 5 — the sentences that moved, in the catalog

    func testTheMovedSentencesAreCatalogued() throws {
        let data = try Data(contentsOf: repoRoot().appendingPathComponent(Self.catalog))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        for key in ["These numbers are the mix, not the delivered file. The loudness Target sets the auto-gain and the export.",
                    "Loudness target · tone · audio output",
                    "Share of the meter, measured before the master chain. The Mixer's master strip shows the loudness of the output."] {
            XCTAssertNotNil(strings[key], "missing catalog key: \(key)")
        }
        for gone in ["The Target above sets the auto-gain and the export; the numbers are the mix, not the delivered file.",
                     "Master level · EBU R128 loudness",
                     "Share of the meter, measured before the master chain. The Master panel shows the loudness of the output."] {
            XCTAssertNil(strings[gone], "a retired sentence is still a catalog key: \(gone)")
        }
    }

    // MARK: helpers

    /// The brace-matched body after `anchor` (#408); string-literal aware.
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            XCTFail("ANCHOR MISSING: `\(anchor)` (#454)")
            return ""
        }
        var depth = 1
        var index = start.upperBound
        var inString = false
        while index < code.endIndex {
            let ch = code[index]
            if inString, ch == "\\" {
                index = code.index(after: index)
                if index < code.endIndex { index = code.index(after: index) }
                continue
            }
            if ch == "\"" { inString.toggle() }
            if !inString {
                if ch == "{" { depth += 1 }
                if ch == "}" {
                    depth -= 1
                    if depth == 0 { return String(code[start.upperBound..<index]) }
                }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: `\(anchor)` never closes (#454)")
        return ""
    }

    /// Brace depth of `code` just before `offset`, string-literal aware — the same walk as `member`.
    private func depth(at offset: String.Index, in code: String) -> Int {
        var depth = 0
        var index = code.startIndex
        var inString = false
        while index < offset {
            let ch = code[index]
            if inString, ch == "\\" {
                index = code.index(after: index)
                if index < offset { index = code.index(after: index) }
                continue
            }
            if ch == "\"" { inString.toggle() }
            if !inString {
                if ch == "{" { depth += 1 }
                if ch == "}" { depth -= 1 }
            }
            index = code.index(after: index)
        }
        return depth
    }

    /// Comment-stripped files under `Sources/Echoelmusic` for which `matches` holds, repo-relative, sorted.
    private func filesMatching(_ matches: (String) -> Bool) throws -> [String] {
        let base = "Sources/Echoelmusic"
        let root = repoRoot().appendingPathComponent(base)
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            XCTFail("cannot enumerate \(base) — a scan that saw nothing is not a pass")
            return []
        }
        var hits: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8) else { continue }
            if matches(SourceText.codeOnly(text)) { hits.append(base + "/" + relative) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        return hits.sorted()
    }

    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func text(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }
}

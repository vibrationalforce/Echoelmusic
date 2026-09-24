// TheNoteIdentityHasOneSpellingTests.swift
// Echoel — 2026-09-24 (overnight P8n): the key a MIDI message names is decided ONCE,
// `EchoelMIDIDecode.noteNumber(_:)`, and both the pitch and the AUv3's last-note tracker ask it.
// Blocking bundle.
//
// THE DEFECT (measured before the repair). `frequency(forNote:)` masked data1 with `& 0x7F`; the
// AUv3 render block stored and compared `Int32(midi.data.1)`, unmasked — two spellings of one
// decision (#416). A note-on whose data1 is 0xBC played key 60 and tracked 188, so a note-off for
// 60 never released it. Only malformed MIDI reaches the difference. Found by tonight's read-only
// audit agent (WA3 device-model audit, its finding 7).
//
// THE REPAIR. `EchoelMIDIDecode.noteNumber(_:)` (scalar mask, audio-thread safe); `frequency`
// and both tracker sites use it.
//
// WHAT KIND OF GREEN (§1), PER CLAIM:
// · claim 1 is END-TO-END BEHAVIOUR of the shipped decoder (Foundation-only).
// · claim 2 is a SOURCE-TEXT SCAN of the AUv3 render block, which this bundle cannot instantiate.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `d62441b8e`:
// `noteNumber` does not exist, so this file does not COMPILE there — no assertion has a verdict.
// Claim 1 is a FORWARD guard (its frequency half is a counterweight: masked pitch was already
// equal on the parent). Claim 2's scan would be red there (two raw `Int32(midi.data.1)` sites) —
// one finding.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheNoteIdentityHasOneSpellingTests: XCTestCase {

    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"

    // MARK: - claim 1

    func testAMalformedKeyIsTrackedAsTheKeyItPlays() {
        for key in [UInt8(0), 60, 69, 127] {
            XCTAssertEqual(EchoelMIDIDecode.noteNumber(key), Int32(key), "a legal key \(key) is not tracked as itself")
            let malformed = key | 0x80
            XCTAssertEqual(EchoelMIDIDecode.noteNumber(malformed), Int32(key), """
                data1 \(malformed) is tracked as a different key than the one it plays.
                """)
            // COUNTERWEIGHT — the pitch already masked; tracker and pitch now agree.
            XCTAssertEqual(EchoelMIDIDecode.frequency(forNote: malformed),
                           EchoelMIDIDecode.frequency(forNote: key))
        }
    }

    // MARK: - claim 2 (SOURCE-TEXT SCAN)

    func testTheTrackerAsksTheDecoder() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        let render = try XCTUnwrap(Self.body(startingWith: "public override var internalRenderBlock", in: code),
                                   "the render block is not found — re-anchor this guard (#456)")
        XCTAssertEqual(render.components(separatedBy: "EchoelMIDIDecode.noteNumber(midi.data.1)").count - 1, 2, """
            The note-on store and the note-off compare must both ask `EchoelMIDIDecode.noteNumber`.
            """)
        XCTAssertFalse(render.contains("Int32(midi.data.1)"),
                       "the render block spells the key from the raw byte again — a second spelling (#416)")
    }

    // MARK: - helpers

    private static func body(startingWith anchor: String, in code: String) -> String? {
        guard let start = code.range(of: anchor) else { return nil }
        var depth = 0
        var out = ""
        for ch in code[start.lowerBound...] {
            if ch == "{" { depth += 1 }
            if depth > 0 { out.append(ch) }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return out }
            }
        }
        return nil
    }

    private func text(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relative) is not present — source-text claim cannot run (#454)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

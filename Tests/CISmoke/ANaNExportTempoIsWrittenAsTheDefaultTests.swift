// ANaNExportTempoIsWrittenAsTheDefaultTests.swift
// Echoel — overnight P8 (2026-09-25). Blocking bundle. END-TO-END BEHAVIOUR
// (`Tests/CISmoke/CLAUDE.md` §1): it drives the shipped MIDI exporter on value inputs, with no
// engine and no view.
//
// ⭐ THE DEFECT. `MIDIFileExporter.tempoMeta` is the one tempo encoder every export takes (grid,
// notes, combined, clip). It clamped with `Swift.min(Swift.max(tempo, 1), 1000)`, and
// `Swift.max(NaN, 1)` is NaN — the argument-order trap the root CLAUDE.md names ("`min(max(v,
// lo), hi)` passes NaN straight through"). `UInt32(60_000_000.0 / NaN)` is then a Swift TRAP,
// on a public path whose own doc said "clamped to 1...1000". A NaN tempo is now written as
// `Transport.defaultTempo` — the repo's one fallback tempo, and the tempo a reader assumes when
// a file has no tempo meta at all. ±inf is unchanged (1000 and 1).
//
// ⚠️ LATENT, NOT LIVE — measured, not assumed. The export door passes the transport's tempo,
// which is finite. This closes the boundary.
//
// ⚠️ HONEST GRADING (transcribed in Python against both trees; no toolchain, §0).
//   · claims 1 and 2 are REGRESSIONS: both TRAP on the parent (`UInt32(NaN)`), which kills the
//     test clone instead of failing an assertion (#1174). One finding, one mechanism, two
//     entry points (#486).
//   · claim 3 is a COUNTERWEIGHT: every non-NaN tempo encodes exactly as before, on both trees.
//     The byte values are derived from the arithmetic (60 000 000 / bpm, big-endian, capped at
//     0xFFFFFF), not read off a run (#442).
//   · Not executed (no toolchain); what `Build for Testing` proves is compilation only.

import XCTest
@testable import Echoelmusic

final class ANaNExportTempoIsWrittenAsTheDefaultTests: XCTestCase {

    /// claim 1 — the encoder writes a NaN tempo as the default tempo instead of trapping.
    func testANaNTempoEncodesAsTheDefaultTempo() {
        XCTAssertEqual(MIDIFileExporter.tempoMeta(.nan),
                       MIDIFileExporter.tempoMeta(Transport.defaultTempo), """
            `tempoMeta(.nan)` no longer encodes `Transport.defaultTempo`. The bare \
            `Swift.min(Swift.max(tempo, 1), 1000)` passes NaN through (`Swift.max(NaN, 1)` is \
            NaN), and `UInt32(60_000_000.0 / NaN)` traps. Replace NaN before the clamp.
            """)
    }

    /// claim 2 — the public grid export carries that same meta event for a NaN tempo.
    func testTheGridExportSurvivesANaNTempo() {
        let file = [UInt8](MIDIFileExporter.export(steps: [[true]], tempo: .nan))
        let expected = MIDIFileExporter.tempoMeta(Transport.defaultTempo)
        let found = file.count >= expected.count
            && (0...(file.count - expected.count)).contains { start in
                Array(file[start..<(start + expected.count)]) == expected
            }
        XCTAssertTrue(found, """
            `MIDIFileExporter.export(steps:tempo:)` with a NaN tempo does not carry the default \
            tempo's meta event. Every export takes `tempoMeta`; its NaN rule is the whole fix.
            """)
    }

    /// claim 3 — COUNTERWEIGHT: every non-NaN tempo encodes exactly as before.
    func testEveryNonNaNTempoEncodesAsBefore() {
        // 60 000 000 / 120 = 500 000 = 0x07A120.
        XCTAssertEqual(MIDIFileExporter.tempoMeta(120), [0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20])
        // 60 000 000 / 1000 = 60 000 = 0x00EA60.
        XCTAssertEqual(MIDIFileExporter.tempoMeta(1000), [0x00, 0xFF, 0x51, 0x03, 0x00, 0xEA, 0x60])
        // 60 000 000 / 1 exceeds the 3-byte field and saturates at 0xFFFFFF.
        XCTAssertEqual(MIDIFileExporter.tempoMeta(1), [0x00, 0xFF, 0x51, 0x03, 0xFF, 0xFF, 0xFF])
        XCTAssertEqual(MIDIFileExporter.tempoMeta(.infinity), MIDIFileExporter.tempoMeta(1000))
        XCTAssertEqual(MIDIFileExporter.tempoMeta(-.infinity), MIDIFileExporter.tempoMeta(1))
        XCTAssertEqual(MIDIFileExporter.tempoMeta(5_000), MIDIFileExporter.tempoMeta(1000))
    }
}

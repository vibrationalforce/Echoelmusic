// TheMIDIInputIgnoresItsOwnSourcesTests.swift
//
// Echoel — audit 2026-10-03, slice hpp-1.
//
// THE DEFECT. `MIDIOutput` publishes up to two virtual sources ("Echoelmusic" and
// "Echoelmusic (MIDI 2.0)"). A virtual source is visible to EVERY CoreMIDI client, our own
// input port included, and `MIDIInput.connectAllSources()` connected every source it could
// see. With MIDI out on, every generated note came back in through `controllerEvents` as a
// performer note on the body voice — and a host with MIDI Thru turned that into a loop. The
// setup-changed notification that creating the source fires is exactly what re-ran the
// connect, so switching MIDI out on was enough.
//
// THE REPAIR. The two unique IDs `MIDIOutput` stamps on its sources ("ECHO", "ECH2") are
// stated ONCE, as constants on `MIDIOutput`; `MIDIInput.isOwnSource` reads a source's
// `kMIDIPropertyUniqueID` back and the connect loop skips a match. A source whose ID cannot be
// read is connected, never dropped — a missing property must not silence a real keyboard.
//
// ⚠️ THE LIMIT. Claims 1 and 4 are END-TO-END on the shipped types (constant values; an
// unreadable endpoint is not ours). Claims 2 and 3 are SOURCE-TEXT SCANS — this bundle cannot
// create a CoreMIDI virtual source and watch the input port refuse it. That the loop is gone
// with MIDI out on is a DEVICE PROBE, open.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheMIDIInputIgnoresItsOwnSourcesTests: XCTestCase {

    private static let input = "Sources/Echoelmusic/Audio/MIDIInput.swift"
    private static let output = "Sources/Echoelmusic/Audio/MIDIOutput.swift"

    /// Claim 1 — the two IDs are the persisted ones and both are on the skip list. Changing a
    /// value re-binds every host to a "new device"; dropping one from the list reopens the loop
    /// for that source.
    func testTheOwnIDsAreTheStampedOnes() {
        XCTAssertEqual(MIDIOutput.virtualSourceUniqueID, 0x4543_484F,
                       "the MIDI 1.0 source's unique ID moved — hosts re-bind to a new device (hpp-1)")
        XCTAssertEqual(MIDIOutput.virtualSource2UniqueID, 0x4543_4832,
                       "the MIDI 2.0 source's unique ID moved — hosts re-bind to a new device (hpp-1)")
        XCTAssertTrue(MIDIOutput.ownSourceUniqueIDs.contains(MIDIOutput.virtualSourceUniqueID))
        XCTAssertTrue(MIDIOutput.ownSourceUniqueIDs.contains(MIDIOutput.virtualSource2UniqueID),
                      "the MIDI 2.0 source is not on the skip list — the input hears it again (hpp-1)")
    }

    /// Claim 2 — the stamp and the skip list are ONE number each. A literal at the stamp site
    /// can drift from the constant the input compares against, and the loop comes back silently.
    func testTheStampUsesTheConstants() throws {
        let src = SourceText.codeOnly(try text(Self.output))
        XCTAssertTrue(src.contains("kMIDIPropertyUniqueID, Self.virtualSourceUniqueID)"),
                      "the MIDI 1.0 source is not stamped from the shared constant (hpp-1)")
        XCTAssertTrue(src.contains("kMIDIPropertyUniqueID, Self.virtualSource2UniqueID)"),
                      "the MIDI 2.0 source is not stamped from the shared constant (hpp-1)")
        XCTAssertEqual(src.components(separatedBy: "0x4543_").count - 1, 2,
                       "a unique-ID literal exists outside the two constant declarations (hpp-1)")
    }

    /// Claim 3 — the ONE connect call sits behind the own-source check, and the check reads the
    /// unique ID against the shared list.
    func testTheConnectLoopSkipsOwnSources() throws {
        let src = SourceText.codeOnly(try text(Self.input))
        XCTAssertEqual(src.components(separatedBy: "MIDIPortConnectSource(").count - 1, 1,
                       "a second connect site exists — it must carry the own-source check too (hpp-1)")
        guard let skip = src.range(of: "guard !Self.isOwnSource(source) else { continue }"),
              let connect = src.range(of: "MIDIPortConnectSource(") else {
            XCTFail("ANCHOR MISSING: the own-source skip or the connect call moved — re-anchor "
                    + "rather than trust a zero (#408)")
            return
        }
        XCTAssertLessThan(skip.lowerBound, connect.lowerBound,
                          "the own-source check sits after the connect — it skips nothing (hpp-1)")
        guard let check = src.range(of: "nonisolated static func isOwnSource(") else {
            XCTFail("ANCHOR MISSING: `isOwnSource` moved — re-anchor (#408)")
            return
        }
        let body = String(src[check.lowerBound...].prefix(400))
        XCTAssertTrue(body.contains("kMIDIPropertyUniqueID"),
                      "the check no longer reads the unique ID (hpp-1)")
        XCTAssertTrue(body.contains("MIDIOutput.ownSourceUniqueIDs.contains("),
                      "the check no longer compares against the shared list (hpp-1)")
    }

    #if canImport(CoreMIDI)
    /// Claim 4 — an endpoint whose ID cannot be read is NOT ours. Failing closed here would
    /// drop a real keyboard that lacks the property.
    func testAnUnreadableSourceIsNotOurs() {
        XCTAssertFalse(MIDIInput.isOwnSource(0),
                       "an unreadable endpoint counts as ours — real devices would be dropped (hpp-1)")
    }
    #endif

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

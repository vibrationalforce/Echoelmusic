// Echoel — overnight P8 (2026-09-25). `MIDIInput.handleMIDIEvents` read a packet's first two
// words with `withUnsafeBytes(of: packetPtr.pointee.words)`. That argument is a VALUE: it loads
// the whole 64-word (256-byte) tuple into a temporary. A packet inside a CoreMIDI event list is
// only `wordCount` words long, so for the last packet of a short list the load reads past the
// list's storage — the same read-past-storage class as the `MIDIEventPacketNext(&localCopy)`
// repair already documented one comment above it. Now the two words are loaded in place from
// `UnsafeRawPointer(packetPtr)` at `MIDIInput.packetWordsOffset`, and only the ones that exist.
//
// WHAT THIS PINS.
// (1) END-TO-END: the imported layout reports the offset, it equals the header layout the
//     fallback assumes (so the fallback can never read the wrong bytes), it is UInt32-aligned,
//     and reading a packet through it returns exactly the words written into its tuple.
// (2) SOURCE-TEXT SCAN: the handler no longer names `pointee.words` and reads via the offset.
// DEVICE PROBE, open: a real controller still plays notes (the parse after the read is
// unchanged; nothing here drives CoreMIDI).
//
// ⚠️ HONEST GRADING (transcribed §0, parent = the commit before this one): claim 1 does not
// COMPILE there (`packetWordsOffset` is new) — no verdict, it is a FORWARD guard. Claim 2 is RED
// on the parent (one finding: the handler names `pointee.words`) and green here.

import CoreMIDI
import Foundation
import XCTest
@testable import Echoelmusic

final class TheMIDIPacketIsReadInPlaceTests: XCTestCase {

    private static let input = "Sources/Echoelmusic/Audio/MIDIInput.swift"

    /// Claim 1 — the offset exists and reads the words that were written.
    func testTheOffsetReadsThePacketsOwnWords() throws {
        let offset = MIDIInput.packetWordsOffset
        XCTAssertNotNil(MemoryLayout<MIDIEventPacket>.offset(of: \MIDIEventPacket.words),
                        "the imported layout no longer reports the words offset — the handler runs on its fallback")
        XCTAssertEqual(offset, MemoryLayout<MIDITimeStamp>.size + MemoryLayout<UInt32>.size, """
            the words offset \(offset) disagrees with the header layout (timeStamp + wordCount) — \
            the fallback in MIDIInput.packetWordsOffset would read the wrong bytes
            """)
        XCTAssertEqual(offset % MemoryLayout<UInt32>.alignment, 0,
                       "the words offset \(offset) is not UInt32-aligned — `load(as:)` would trap")

        var packet = MIDIEventPacket()
        packet.wordCount = 2
        packet.words.0 = 0x2093_3C64
        packet.words.1 = 0x0000_1234
        let (first, second): (UInt32, UInt32) = withUnsafePointer(to: &packet) { pointer in
            let words = UnsafeRawPointer(pointer).advanced(by: offset)
            return (words.load(as: UInt32.self),
                    words.load(fromByteOffset: MemoryLayout<UInt32>.stride, as: UInt32.self))
        }
        XCTAssertEqual(first, 0x2093_3C64, "word 0 read through the offset is not the packet's word 0")
        XCTAssertEqual(second, 0x0000_1234, "word 1 read through the offset is not the packet's word 1")
    }

    /// Claim 2 — the handler reads in place, never the whole tuple.
    func testTheHandlerNoLongerCopiesTheWordTuple() throws {
        let code = SourceText.codeOnly(try text(Self.input))
        guard let body = Self.body(startingWith: "func handleMIDIEvents(", in: code) else {
            return XCTFail("`handleMIDIEvents(` is gone from MIDIInput.swift — re-anchor this claim (#1240)")
        }
        XCTAssertFalse(body.contains("pointee.words"), """
            handleMIDIEvents reads `pointee.words` again — that loads the full 256-byte tuple from \
            a packet that is only `wordCount` words long
            """)
        XCTAssertTrue(body.contains("packetWordsOffset"),
                      "handleMIDIEvents no longer reads the words through `packetWordsOffset`")
        XCTAssertTrue(body.contains("unsafeSequence()"),
                      "counterweight: the handler no longer walks the list in place (`unsafeSequence()`)")
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

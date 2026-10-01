// TheTrackLevelIsReadInDecibelsTests.swift
// Echoel — modes census 2026-09-26, design slice 8: the track level is also read in decibels.
//
// WHAT THIS PINS. The inspector's Level is a linear 0…2 field ("1.00 unchanged, 2.00 is +6 dB"),
// and dB appeared only inside that hint. A mixing engineer reads a fader in dB, so the stored
// gain is now also printed as "−6.0 dB" / "+6.0 dB" under the field. It is a static READING of
// the stored value, never a meter. The live per-track meter is `TrackLevelMeter` (B5), which reads
// the poly-slot voice in its own leaf — a live read here would be a hot read.
//
// 1. END-TO-END BEHAVIOUR (`TrackMix.decibelText`, pure): 20·log10, one decimal, a real minus
//    sign, "0.0 dB" at unity, and "−∞ dB" for silence or any non-finite level.
// 2. SOURCE: the inspector prints it under the Level field, inside the same `controls.level`
//    gate, from the same stored lane level the field reads.
//
// Grading (§0, no Swift toolchain): `decibelText` does not exist on the parent (`645b056c0`), so
// this file does not compile there — every claim is a FORWARD guard, one absence (#486). Claim 1
// transcribed into Python and driven on the cases below; claim 2 against this tree: green.
// NOT covered: how the caption sits under the field at large text sizes — a device look.
// NEEDS-FOUNDER-VERIFY: Workstation → a track → Level 0.50: the line under it reads "−6.0 dB";
// 1.00 reads "0.0 dB"; 0 reads "−∞ dB".

import Foundation
import XCTest
@testable import Echoelmusic

final class TheTrackLevelIsReadInDecibelsTests: XCTestCase {

    private static let inspector = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"

    // MARK: 1 — the reading, pure

    func testTheLevelReadsInDecibels() {
        XCTAssertEqual(TrackMix.decibelText(1), "0.0 dB", "unity gain is 0 dB, unsigned")
        XCTAssertEqual(TrackMix.decibelText(2), "+6.0 dB", "the top of the field, as its hint says")
        XCTAssertEqual(TrackMix.decibelText(0.5), "−6.0 dB", "a real minus sign, not a hyphen")
        XCTAssertEqual(TrackMix.decibelText(0.001), "−60.0 dB")
        XCTAssertEqual(TrackMix.decibelText(0.99999), "0.0 dB", "a hair under unity rounds to 0.0, never −0.0")
    }

    func testSilenceAndNonsenseReadAsMinusInfinity() {
        XCTAssertEqual(TrackMix.decibelText(0), "−∞ dB")
        XCTAssertEqual(TrackMix.decibelText(-1), "−∞ dB")
        XCTAssertEqual(TrackMix.decibelText(.nan), "−∞ dB", "a corrupt level never prints \"nan dB\"")
        XCTAssertEqual(TrackMix.decibelText(.infinity), "−∞ dB")
    }

    // MARK: 2 — the inspector prints it under the field

    func testTheInspectorPrintsItUnderTheLevelField() throws {
        let code = try source(Self.inspector)
        guard let gate = code.range(of: "if controls.level {"),
              let field = code.range(of: "label: \"Level\",", range: gate.upperBound..<code.endIndex),
              let caption = code.range(of: "Text(TrackMix.decibelText(level))", range: gate.upperBound..<code.endIndex),
              let pan = code.range(of: "if controls.pan {", range: gate.upperBound..<code.endIndex) else {
            return XCTFail("the inspector no longer prints `TrackMix.decibelText(level)` under its Level field")
        }
        XCTAssertLessThan(field.lowerBound, caption.lowerBound, "the reading sits under the field")
        XCTAssertLessThan(caption.lowerBound, pan.lowerBound, "inside the Level gate, before Pan")
        XCTAssertTrue(code[gate.upperBound..<field.lowerBound].contains(
            "let level = Double(timeline.document.lanes.first(where: { $0.id == laneID })?.level ?? TimelineLane.defaultLevel)"),
                      "the reading comes from the same stored lane level the field shows")
        XCTAssertEqual(code.components(separatedBy: "TrackMix.decibelText(").count - 1, 2,
                       "one printed reading and its VoiceOver value — nothing else formats the level")
    }

    // MARK: helpers

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }
}

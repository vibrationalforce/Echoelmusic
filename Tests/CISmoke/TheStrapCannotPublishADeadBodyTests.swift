// TheStrapCannotPublishADeadBodyTests.swift
// Echoel — #1216 (audit 2026-09-10 `bio-pipeline-1`). A BLE strap that stopped talking, or
// whose electrodes left the skin, is not published as a live body.
//
// THE DEFECT, two halves. (1) `PolarH10BioPublisher`'s publish loop re-published `latestHR`
// every second for as long as it held a plausible number; between a link loss and iOS's
// `didDisconnectPeripheral` (the BLE supervision timeout) the bus received a FROZEN pulse that
// `freshBio`/`usableBio` accepted as live — music, visual, OSC egress and the Health writer
// (`HealthKitWriter` writes `bus.freshBio()` every 5 s) ran on a dead body. (2) The HRM parser
// ignored the Sensor-Contact flag bits, so a strap reporting "contact supported, NOT detected"
// with a stale HR was read as a measurement, RR intervals included (phantom heartbeat events).
//
// WHAT THIS PINS. (1) PARSER, by behaviour: "supported + not detected" yields HR 0 and no RR;
// "supported + detected" and "not supported" parse as before — the counterweight that keeps
// straps without contact reporting alive. (2) LOOP, by text: the handler stamps a receipt clock
// and the loop gates on it, with the constant between one missed notification and the
// supervision timeout. The loop itself needs a peripheral to drive; the text pin is the limit.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`18b5615`) and this tree: claim 1
// RED on the parent (the flags are ignored — 0x06 with HR 70 parses as 70), GREEN here; claim 2
// RED on the parent (no receipt clock), GREEN here; claim 3 green on both (counterweight).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheStrapCannotPublishADeadBodyTests: XCTestCase {

    /// Claim 1 — contact supported but not detected is NOT a measurement.
    func testContactLostParsesAsNoMeasurement() {
        // flags 0x02 = contact supported, bit 2 clear = not detected; uint8 HR 70.
        let lost = PolarH10BioPublisher.parseHRMeasurement(Data([0x02, 70]))
        XCTAssertEqual(lost.hr, 0, "a strap with the electrodes off the skin published HR 70 (#1216)")
        XCTAssertTrue(lost.rrIntervals.isEmpty)
        // Same with RR present (0x10): no phantom beats either.
        let lostWithRR = PolarH10BioPublisher.parseHRMeasurement(Data([0x12, 70, 0x00, 0x04]))
        XCTAssertEqual(lostWithRR.hr, 0)
        XCTAssertTrue(lostWithRR.rrIntervals.isEmpty, "RR intervals from a strap without skin contact became heartbeat events (#1216)")
    }

    /// Claim 2 — the loop only publishes while the strap has spoken recently.
    func testTheLoopGatesOnTheReceiptClock() throws {
        let src = SourceText.codeOnly(try text("Sources/Echoelmusic/Bio/PolarH10BioPublisher.swift"))
        XCTAssertTrue(src.contains("self.lastNotificationAt = CFAbsoluteTimeGetCurrent()"),
                      "the HRM handler no longer stamps the receipt clock (#1216)")
        XCTAssertTrue(src.contains("CFAbsoluteTimeGetCurrent() - self.lastNotificationAt <= Self.maxNotificationAgeSeconds"),
                      "the publish loop no longer gates on the receipt clock — a frozen HR is re-stamped every second again (#1216)")
        XCTAssertGreaterThanOrEqual(PolarH10BioPublisher.maxNotificationAgeSeconds, 1.5,
                                    "below ~1.5 s a single late ~1 Hz notification would drop live frames")
        XCTAssertLessThanOrEqual(PolarH10BioPublisher.maxNotificationAgeSeconds, 10,
                                 "above the BLE supervision timeout the gate protects nothing")
    }

    /// Claim 3 — counterweight: contact detected, and straps without contact support, still parse.
    func testContactDetectedAndUnsupportedStillParse() {
        let detected = PolarH10BioPublisher.parseHRMeasurement(Data([0x06, 70]))
        XCTAssertEqual(detected.hr, 70)
        let unsupported = PolarH10BioPublisher.parseHRMeasurement(Data([0x00, 70]))
        XCTAssertEqual(unsupported.hr, 70, "a strap that does not report contact must still publish (#1216)")
        let unsupportedRR = PolarH10BioPublisher.parseHRMeasurement(Data([0x10, 70, 0x00, 0x04]))
        XCTAssertEqual(unsupportedRR.rrIntervals.count, 1)
        XCTAssertEqual(unsupportedRR.rrIntervals[0], 1.0, accuracy: 1e-9)
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

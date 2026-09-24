// TheBridgeReadsAnUnmeasuredChannelAsNeutralTests.swift
// Echoel — 2026-09-24 (overnight P8r): the App-Group bridge into the AUv3 applies the app's rule
// "a channel that measured nothing reads neutral 0.5", through `BioVitals`' own spelling of it,
// and that spelling agrees with `BioSampleFrame`'s over the same frames. Blocking bundle.
//
// THE DEFECT (measured before the repair). `BioVitals` uses 0 for unmeasured coherence and HRV
// and 0 BPM for no pulse. `pullSharedVitals` mapped all four channels RAW into the host
// parameters: an unmeasured coherence became 0 (filter cutoff factor 0.75, texture rule 90),
// an unmeasured pulse became the bottom of the heart-rate range. The app reads all four through
// `BioSampleFrame.…ForSound` (0.5 when unmeasured) — two spellings of one rule, two answers.
// `AnUnmeasuredChannelReadsNeutralTests` could not see it: its needles name `frame.`, the AU
// wrote `vitals.`. Found by tonight's read-only audit agent (WA3 device-model audit, finding 1).
// DORMANT today: the extension carries no App Group entitlement, so the bridge delivers nothing.
//
// THE REPAIR. `BioVitals.coherenceForSound` / `hrvForSound` / `heartRateForSound` /
// `breathPhaseForSound` (+ `plausibleBreathRate`), and `pullSharedVitals` writes those.
// `BioFeedbackManager.swift` compiles standalone into the Widget, Watch and AUv3, which cannot
// see `BioSampleFrame`, so the rule is written twice ON PURPOSE; claim 1 is what keeps the two
// spellings one decision (#416).
//
// WHAT KIND OF GREEN (§1), PER CLAIM:
// · claims 1–3 are END-TO-END BEHAVIOUR of shipped Foundation-only types, including the real
//   frame→payload mapping `BioFeedbackPublisher.vitals(from:)`.
// · claim 4 is a SOURCE-TEXT SCAN of the AUv3's `pullSharedVitals`, which this bundle cannot run.
// · HOST/DEVICE: nothing — the bridge is dormant until the entitlement exists (founder hold).
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `a87e59692`: the four
// accessors do not exist, so this file does not COMPILE there — no assertion has a verdict.
// Claims 1–3 are FORWARD guards; claim 4's scan would be red there (the raw
// `min(max(vitals.coherence, 0), 1)` spelling) — one finding.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheBridgeReadsAnUnmeasuredChannelAsNeutralTests: XCTestCase {

    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"

    // MARK: - claim 1

    @MainActor
    func testTheBridgeAndTheFrameGiveTheSameSoundValue() {
        let coherences: [Float] = [0, 0.3, 1, 1.4, -0.2]
        let hrvs: [Float] = [0, 0.6, 1.3]
        let pulses: [Float] = [0, 30, 72, 250]
        let breathRates: [Float] = [0, 2, 12, 45]
        let phases: [Float] = [0, 0.4, 1.2, -0.1]
        var compared = 0
        for c in coherences { for h in hrvs { for bpm in pulses { for br in breathRates { for ph in phases {
            let frame = BioSampleFrame(timestamp: 1, heartRateBPM: bpm, hrvNormalized: h,
                                       breathRate: br, breathPhase: ph, coherence: c,
                                       motionEnergy: 0, source: .fallback)
            let vitals = BioFeedbackPublisher.vitals(from: frame)
            XCTAssertEqual(vitals.coherenceForSound, frame.coherenceForSound, "coherence \(c)")
            XCTAssertEqual(vitals.hrvForSound, frame.hrvForSound, "hrv \(h)")
            XCTAssertEqual(vitals.heartRateForSound, frame.heartRateForSound, "pulse \(bpm)")
            XCTAssertEqual(vitals.breathPhaseForSound, frame.breathPhaseForSound, "breath \(br) / \(ph)")
            compared += 1
        } } } } }
        XCTAssertEqual(compared, 5 * 3 * 4 * 4 * 4, "the grid did not run — the parity claim would be vacuous")
    }

    // MARK: - claim 2

    func testBothSpellingsBelieveTheSameBreathBand() {
        XCTAssertEqual(BioVitals.plausibleBreathRate, BioSampleFrame.plausibleBreathRate, """
            The bridge and the frame disagree on which respiration rates carry a real breath \
            phase. One rule, two constants — move them together.
            """)
    }

    // MARK: - claim 3

    func testAnUnmeasuredPayloadReadsNeutralOnAllFourChannels() {
        let unmeasured = BioVitals(heartRateBPM: 0, hrvNormalized: 0, breathPhase: 0, coherence: 0,
                                   timestamp: 1, breathRate: 0)
        XCTAssertEqual(unmeasured.coherenceForSound, 0.5)
        XCTAssertEqual(unmeasured.hrvForSound, 0.5)
        XCTAssertEqual(unmeasured.heartRateForSound, 0.5)
        XCTAssertEqual(unmeasured.breathPhaseForSound, 0.5)
        // COUNTERWEIGHT — a measured payload is NOT neutralised.
        let measured = BioVitals(heartRateBPM: 120, hrvNormalized: 0.8, breathPhase: 0.25,
                                 coherence: 0.9, timestamp: 1, breathRate: 12)
        XCTAssertEqual(measured.coherenceForSound, 0.9)
        XCTAssertEqual(measured.hrvForSound, 0.8)
        XCTAssertEqual(measured.heartRateForSound, 0.5, accuracy: 1e-6)   // (120 − 40) / 160
        XCTAssertEqual(measured.breathPhaseForSound, 0.25)
    }

    // MARK: - claim 4 (SOURCE-TEXT SCAN)

    func testTheAUv3WritesTheNeutralisedValues() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        let pull = try XCTUnwrap(Self.body(startingWith: "private func pullSharedVitals() {", in: code),
                                 "`pullSharedVitals` not found — re-anchor this guard (#456)")
        for accessor in ["coherenceForSound", "hrvForSound", "heartRateForSound", "breathPhaseForSound"] {
            XCTAssertTrue(pull.contains("vitals.\(accessor)"),
                          "`pullSharedVitals` no longer writes `vitals.\(accessor)`")
        }
        XCTAssertFalse(pull.contains("vitals.coherence, 0"),
                       "the raw coherence mapping is back — unmeasured would sound as the lowest reading")
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

//
//  TheLoopbackCalibrationRejectsWhatItCannotMeasureTests.swift
//  Live-jam J0 (founder 2026-10-07): the pure core of a loopback latency calibration —
//  `Audio/LoopbackCalibration.swift`. A burst goes out, a recording comes back, and the core
//  either names the delay or refuses. This guard pins both halves: a clean delay is found to
//  the sample (and between samples), and every way the detector can be fooled is a NAMED
//  refusal, never a number.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · BEHAVIOUR (claims 1–5) — the shipped `CalibrationStimulus`, `CalibrationDetector`,
//    `CalibrationQualityGate` and `LatencyBudgetReport`, driven with synthetic arrays at 8 kHz
//    (stimulus 512 samples, window 501 lags — small on purpose, the detector is O(lags × length)).
//  · SOURCE (claim 6) — the core imports Foundation only, touches no audio API, and nothing in
//    `Sources/` constructs it yet.
//  · NOT PINNED, and said so: any real number. Nothing here has run on a phone. The device
//    runner that would feed this core (stop the master engine, claim the route, play + record,
//    restart in `defer`) is a separate slice and needs the microphone decision in
//    docs/dev/FOUNDER_INBOX.md J0 first.
//
//  ⚠️ WHAT MUST NOT BE READ INTO THIS (#364): claim 6 does not forbid wiring the core — it
//  fails loudly when a caller appears, so the wiring commit updates the file header ("Wired:
//  NO") and this claim in the same breath.
//
//  GRADING (#433/#464): the file does NOT compile on the parent tree — every type it names is
//  created by this commit (ONE absence, #486). The core was transcribed in Python (numpy,
//  float32 where Swift uses Float) and every scenario below was driven through it: all fifteen
//  detector scenarios land on the expected verdict, the half-sample delay interpolates to
//  300.499. Mutants, each caught: signed instead of absolute correlation (claim 2, inverted),
//  no interpolation (claim 2, half-sample), no clip check, no edge check, no ambiguity check,
//  no SNR check, no rate check, no first-arrival rule, no silent-floor check, a floor of 32
//  frames instead of 10 ms (claim 3 — the matching scenario each), no accepted-share rule and
//  no spread rule (claim 4).
//
//  ⚠️ A LIMIT THE TRANSCRIPTION FOUND, NOT PINNED HERE (#364): the stimulus is white, so a
//  chain that strips much of its band lowers the correlation peak below `minimumPeak`. At
//  48 kHz a 300 Hz–10 kHz chain is found (peak 0.75), an 800 Hz–6 kHz fourth-order chain is
//  REFUSED as noPeak. Refusal is the safe direction — never a wrong number — but a narrow
//  speaker may never calibrate. A band-limited stimulus does not fix it (its correlation
//  side lobes trip the first-arrival rule); the next step is a whitened correlation, measured
//  on the device first. Stated in the core's header too.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheLoopbackCalibrationRejectsWhatItCannotMeasureTests: XCTestCase {

    private static let rate = 8_000.0
    private static let searchWindow = 100...600

    private static func stimulus() throws -> [Float] {
        try XCTUnwrap(CalibrationStimulus.burst(sampleRate: rate, duration: 0.064))
    }

    /// 1,200 samples of a different burst — a noise floor with no fade at its start.
    private static func noiseFloor(_ scale: Float) throws -> [Float] {
        let long = try XCTUnwrap(CalibrationStimulus.burst(sampleRate: rate, duration: 0.25, seed: 7))
        return Array(long[100..<1_300]).map { $0 * scale }
    }

    private static func recording(_ copies: [(lag: Int, gain: Float)], noise: Float) throws -> [Float] {
        let burst = try stimulus()
        var samples = try noiseFloor(noise)
        for copy in copies {
            for index in burst.indices { samples[copy.lag + index] += burst[index] * copy.gain }
        }
        return samples
    }

    private static func detect(_ recording: [Float], recordingRate: Double = rate,
                               window: ClosedRange<Int> = searchWindow) throws -> CalibrationVerdict {
        CalibrationDetector.detect(stimulus: try stimulus(), stimulusRate: rate,
                                   recording: recording, recordingRate: recordingRate,
                                   lagWindow: window)
    }

    private static func estimate(_ verdict: CalibrationVerdict) -> CalibrationEstimate? {
        if case .accepted(let estimate) = verdict { return estimate }
        return nil
    }

    // MARK: 1 — the stimulus is deterministic, quiet and faded

    func testTheBurstIsDeterministicQuietAndFaded() throws {
        let burst = try Self.stimulus()
        XCTAssertEqual(burst.count, 512)
        XCTAssertEqual(burst, try Self.stimulus(), "the same seed is the same burst")
        XCTAssertNotEqual(Array(burst.prefix(64)),
                          Array(try XCTUnwrap(CalibrationStimulus.burst(sampleRate: Self.rate, duration: 0.064, seed: 1)).prefix(64)))
        let loudest = burst.reduce(Float(0)) { max($0, abs($1)) }
        XCTAssertEqual(loudest, CalibrationStimulus.peak, accuracy: 1e-6, "peak is −12 dBFS, no louder")
        XCTAssertEqual(burst.first, 0, "the fade starts from silence — no click")
        XCTAssertEqual(burst.last, 0)

        XCTAssertNil(CalibrationStimulus.burst(sampleRate: 7_999, duration: 0.1))
        XCTAssertNil(CalibrationStimulus.burst(sampleRate: 192_001, duration: 0.1))
        XCTAssertNil(CalibrationStimulus.burst(sampleRate: .nan, duration: 0.1))
        XCTAssertNil(CalibrationStimulus.burst(sampleRate: Self.rate, duration: .nan))
        XCTAssertEqual(CalibrationStimulus.burst(sampleRate: Self.rate, duration: 0.001)?.count, 80,
                       "a too-short request is lengthened to the 10 ms floor")
        XCTAssertEqual(CalibrationStimulus.burst(sampleRate: Self.rate, duration: 5)?.count, 2_000,
                       "a too-long request is cut to the 250 ms ceiling")
    }

    // MARK: 2 — a clean delay is found to the sample, and between samples

    func testACleanDelayIsFoundToTheSample() throws {
        let clean = try XCTUnwrap(Self.estimate(try Self.detect(try Self.recording([(300, 1)], noise: 0.004))))
        XCTAssertEqual(clean.lagFrames, 300, accuracy: 0.05)
        XCTAssertGreaterThan(clean.peak, 0.95)
        XCTAssertGreaterThan(clean.snrDB, CalibrationDetector.minimumSNRdB)

        let inverted = try XCTUnwrap(Self.estimate(try Self.detect(try Self.recording([(300, -1)], noise: 0.004))),
                                     "a speaker wired in reverse polarity delays the burst just the same")
        XCTAssertEqual(inverted.lagFrames, 300, accuracy: 0.05)

        let half = try XCTUnwrap(Self.estimate(try Self.detect(try Self.recording([(300, 0.5), (301, 0.5)], noise: 0.004))))
        XCTAssertEqual(half.lagFrames, 300.5, accuracy: 0.1, "the peak is interpolated, not snapped to a sample")
    }

    // MARK: 3 — every way to be fooled is a named refusal

    func testEveryWayToBeFooledIsARefusal() throws {
        var poisoned = try Self.recording([(300, 1)], noise: 0.004)
        poisoned[10] = .nan
        XCTAssertEqual(try Self.detect(poisoned), .rejected(.nonFinite))
        XCTAssertEqual(try Self.detect(try Self.recording([(300, 4)], noise: 0.004)), .rejected(.clipped),
                       "a recording at full scale was too loud to trust")
        XCTAssertEqual(try Self.detect(try Self.recording([(300, 1)], noise: 0.004), recordingRate: 48_000),
                       .rejected(.rateMismatch), "a rate that changed under the recording is not a delay")
        XCTAssertEqual(try Self.detect(try Self.recording([(300, 1)], noise: 0.004), window: 40...600),
                       .rejected(.tooShort), "the window must leave 10 ms of noise floor before its first lag")
        XCTAssertEqual(try Self.detect(Array(try Self.recording([(300, 1)], noise: 0.004).prefix(1_000))),
                       .rejected(.tooShort), "the recording must cover the whole window")
        XCTAssertEqual(try Self.detect(try Self.recording([], noise: 0.004)), .rejected(.noPeak))
        XCTAssertEqual(try Self.detect(try Self.recording([(600, 1)], noise: 0.004)), .rejected(.lagOutOfWindow),
                       "a peak on the window edge may belong to a lag outside it")
        XCTAssertEqual(try Self.detect(try Self.recording([(200, 1), (400, 1)], noise: 0.004)), .rejected(.ambiguous),
                       "a reflection as strong as the direct sound makes the delay a guess")
        XCTAssertEqual(try Self.detect(try Self.recording([(300, 1)], noise: Float(1 / 3.0.squareRoot()))),
                       .rejected(.lowSNR), "a peak that clears the threshold over a loud floor is still refused")
        XCTAssertEqual(try Self.detect(try Self.recording([(300, 0.6), (305, 0.9)], noise: 0.004)), .rejected(.ambiguous),
                       "an earlier arrival inside the guard band means the strongest lag is not the first")
        var silent = try Self.recording([(300, 1)], noise: 0.004)
        for index in 0..<Self.searchWindow.lowerBound { silent[index] = 0 }
        XCTAssertEqual(try Self.detect(silent), .rejected(.silentFloor), "an unknown floor is not a quiet one")
        let burst = try Self.stimulus()
        XCTAssertEqual(CalibrationDetector.detect(stimulus: burst, stimulusRate: 7_999,
                                                  recording: try Self.recording([(300, 1)], noise: 0.004),
                                                  recordingRate: 7_999, lagWindow: Self.searchWindow),
                       .rejected(.rateMismatch), "a rate outside the supported range is refused even when both sides agree")
    }

    // MARK: 4 — repeats must agree before a number is given

    func testRepeatsMustAgreeBeforeANumberIsGiven() throws {
        func accepted(_ lags: [Double]) -> [CalibrationVerdict] {
            lags.map { .accepted(CalibrationEstimate(lagFrames: $0, peak: 1, runnerUp: 0, snrDB: 40)) }
        }
        let gate = CalibrationQualityGate.self

        guard case .accepted(let five) = gate.combine(accepted([300, 300.2, 299.9, 300.1, 300]), sampleRate: Self.rate) else {
            return XCTFail("five agreeing repeats give a number")
        }
        XCTAssertEqual(five.medianLagFrames, 300, accuracy: 1e-9)
        XCTAssertEqual(five.spreadFrames, 0.3, accuracy: 1e-9)
        XCTAssertEqual(five.accepted, 5)

        XCTAssertEqual(gate.combine(accepted([300, 300, 300, 300]), sampleRate: Self.rate), .rejected(.tooFewRepeats))
        let refusedTwice = accepted([300, 300, 300, 300, 300]) + [.rejected(.ambiguous), .rejected(.lowSNR)]
        XCTAssertEqual(gate.combine(refusedTwice, sampleRate: Self.rate), .rejected(.tooFewRepeats),
                       "five of seven is not four in five — something in the room kept interfering")
        guard case .accepted(let sixth) = gate.combine(accepted([300, 300, 300, 300, 300]) + [.rejected(.ambiguous)],
                                                        sampleRate: Self.rate) else {
            return XCTFail("five of six is enough")
        }
        XCTAssertEqual(sixth.attempted, 6)

        XCTAssertEqual(gate.combine(accepted([300, 300, 300, 300, 305]), sampleRate: Self.rate),
                       .rejected(.inconsistentRepeats), "5 frames at 8 kHz is past the 0.5 ms spread")
        guard case .accepted(let even) = gate.combine(accepted([300, 301, 302, 303, 304, 305]), sampleRate: 48_000) else {
            return XCTFail("six repeats inside 0.5 ms at 48 kHz give a number")
        }
        XCTAssertEqual(even.medianLagFrames, 302.5, accuracy: 1e-9)

        XCTAssertEqual(gate.combine(accepted([300, 300, 300, 300, 300]), sampleRate: .nan), .rejected(.nonFinite))
        XCTAssertEqual(gate.combine(accepted([300, 300, 300, 300, 300]), sampleRate: 0), .rejected(.rateMismatch))
    }

    // MARK: 5 — the report keeps four numbers apart and never halves a round trip

    func testTheReportKeepsFourNumbersApart() {
        let network = LinkLatencySummary(sent: 40, received: 40, lost: 0, samples: 40,
                                         p50: 8, p95: 12, p99: nil, max: 14)
        let series = CalibrationSeries(medianLagFrames: 384, spreadFrames: 4.8, accepted: 5, attempted: 5,
                                       sampleRate: 48_000)
        let report = LatencyBudgetReport(route: "Speaker>MicrophoneBuiltIn", sampleRate: 48_000, ioBufferFrames: 256,
                                         reportedMilliseconds: 12.4, series: .accepted(series), network: network)
        XCTAssertEqual(report.acousticRoundTripMilliseconds ?? -1, 8, accuracy: 1e-9)
        let line = report.logLine()
        XCTAssertTrue(line.hasPrefix("calib: route=Speaker>MicrophoneBuiltIn sr=48000 io=256 reported=12.4ms"), line)
        XCTAssertTrue(line.contains("acousticRoundTrip=8.0ms spread=0.1ms n=5/5 (includes the speaker-to-mic air path)"), line)
        XCTAssertTrue(line.contains("netRTT p50=8.0 p95=12.0ms"), line)
        XCTAssertTrue(line.hasSuffix("heard=UNMEASURED"), "nothing in this app measures the heard latency: \(line)")
        XCTAssertFalse(line.contains("measuredAt="), "the rate has not changed: \(line)")
        let lower = line.lowercased()
        for halved in ["one-way", "oneway", "one way"] {
            XCTAssertFalse(lower.contains(halved), "a round trip is never printed as a one-way figure: \(line)")
        }

        let refused = LatencyBudgetReport(route: "Speaker", sampleRate: 48_000, ioBufferFrames: 256,
                                          reportedMilliseconds: nil, series: .rejected(.ambiguous), network: nil)
        XCTAssertNil(refused.acousticRoundTripMilliseconds)
        XCTAssertTrue(refused.logLine().contains("reported=-ms acousticRoundTrip=- rejected=ambiguous"), refused.logLine())
        XCTAssertTrue(refused.logLine().contains("netRTT p50=- p95=-ms"), "an unmeasured link prints as absent, never 0")
        let notRun = LatencyBudgetReport(route: "", sampleRate: .nan, ioBufferFrames: 0,
                                         reportedMilliseconds: .nan, series: nil, network: nil)
        XCTAssertNil(notRun.acousticRoundTripMilliseconds)
        XCTAssertTrue(notRun.logLine().hasPrefix("calib: route=- sr=- io=0 reported=-ms acousticRoundTrip=- (not run)"),
                      notRun.logLine())

        let moved = CalibrationSeries(medianLagFrames: 441, spreadFrames: 0, accepted: 5, attempted: 5, sampleRate: 44_100)
        let afterRouteChange = LatencyBudgetReport(route: "Speaker", sampleRate: 48_000, ioBufferFrames: 256,
                                                   reportedMilliseconds: nil, series: .accepted(moved), network: nil)
        XCTAssertEqual(afterRouteChange.acousticRoundTripMilliseconds ?? -1, 10, accuracy: 1e-9,
                       "frames are converted with the rate they were measured at, not the rate of the report")
        XCTAssertTrue(afterRouteChange.logLine().contains("acousticRoundTrip=10.0ms"), afterRouteChange.logLine())
        XCTAssertTrue(afterRouteChange.logLine().contains("measuredAt=44100 (the rate has changed since)"),
                      afterRouteChange.logLine())

        XCTAssertEqual(LatencyBudgetReport.sanitised("Someone's iPhone>MicrophoneBuiltIn"), "other>MicrophoneBuiltIn",
                       "the exported log never carries a port NAME — only known port types")
        XCTAssertEqual(LatencyBudgetReport.sanitised("Someone's iPhone\nSpeaker"), "other")
        XCTAssertEqual(LatencyBudgetReport.sanitised(""), "-")
        XCTAssertEqual(LatencyBudgetReport.sanitised("Speaker>Speaker>Speaker>Speaker>Speaker>Speaker"),
                       "Speaker>Speaker>Speaker>Speaker", "at most four tokens")
    }

    // MARK: 6 — the core touches no audio API, and nothing calls it yet

    func testTheCoreTouchesNoAudioAndIsNotWired() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let relative = "Sources/Echoelmusic/Audio/LoopbackCalibration.swift"
        let text = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        let code = SourceText.codeOnly(text)
        let imports = code.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("import ") }
        XCTAssertEqual(imports, ["import Foundation"], "the core computes on arrays; it imports nothing that plays or records")
        for audio in ["AVAudio", "AVAudioRecorder", "inputNode", "installTap", "requestRecordPermission",
                      "recordPermission", "availableInputs", "setCategory", "claimRecordRoute"] {
            XCTAssertFalse(code.contains(audio), """
                `\(relative)` reaches for `\(audio)`. The microphone path is a founder decision (FOUNDER_INBOX \
                J0, the #1302 input-node crash family); the device runner is its own slice, not this file.
                """)
        }
        XCTAssertTrue(text.contains("Wired: NO"), "the header must say whether the core is wired")

        let sources = root.appendingPathComponent("Sources")
        let walker = try XCTUnwrap(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        var scanned = 0
        var callers: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            scanned += 1
            guard !url.path.hasSuffix(relative) else { continue }
            let other = SourceText.codeOnly((try? String(contentsOf: url, encoding: .utf8)) ?? "")
            for name in ["CalibrationStimulus", "CalibrationDetector", "CalibrationQualityGate", "LatencyBudgetReport"]
            where other.contains(name) {
                callers.append("\(url.lastPathComponent): \(name)")
            }
        }
        XCTAssertGreaterThan(scanned, 100, "ANCHOR MISSING: the walk over Sources/ found almost nothing (#454)")
        XCTAssertEqual(callers, [], """
            The calibration core has a caller now: \(callers). Good — then change the header line \
            "Wired: NO" in `\(relative)` and this claim in the same commit, and say on which device it ran.
            """)
    }
}

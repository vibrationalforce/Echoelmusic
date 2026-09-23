// TheDetectedTempoIsHonestTests.swift
// Echoel — the native-tempo estimator (#B1, founder 2026-09-23 "WARP / NATIVE BPM: Approved").
//
// WHAT KIND OF GUARD THIS IS (§1). Claims 1–13 are END-TO-END BEHAVIOUR: they drive the shipped,
// public, Foundation-only `TempoOnsetEnvelope` + `TempoDetector` on synthetic PCM built in this
// file from a deterministic LCG. Claim 14 is a SOURCE-TEXT SCAN. Claims 15–16 are #B2: 15 drives
// the pure adoption policy with values (the real `ClipStore` persists to the App Group, so no
// guard writes through it), 16 is a SOURCE-TEXT SCAN of the detection writer and the door. Whether real recordings get the
// right tempo is a DEVICE question, open, and marked at `TempoDetector.confidenceFloor`.
//
// HONEST GRADING (§3). Every behavioural claim names a type this commit creates, so the file does
// NOT COMPILE against the parent and no assertion has a verdict there. They were graded instead by
// TRANSCRIPTION: `TempoDetector.swift` re-written line by line in Python (float32 samples, Swift's
// `.toNearestOrEven` rounding) and the fixtures below re-built identically — the mirror agreed with
// the calibration prototype to four decimals on every case. Measured values the claims rest on:
//
//   claim  fixture                       bpm      conf   loop  known
//   1      clicks 97.3 BPM, 12 s          97.260   0.935   —     yes
//   2      drum loop 128 BPM × 4 bars    128.000   0.988   4     yes
//   3      drum loop 128 BPM × 1 bar     127.999   0.741   1     yes   (1.875 s — short)
//   4      clicks 120 BPM, 3.0 s         119.976   0.766   —     NO    (short, not a loop)
//   5      LCG noise, 10 s                87.790   0.043   —     NO
//   6      silence 8 s / clicks 1.2 s       nil
//   7      clicks 72 BPM, 16 s            72.020   0.998   —     yes
//   8      clicks 174 BPM, 12 s           86.998   0.942   —     yes   (alternative 174.00)
//   9      sustained three-note chord    100.858   0.056   —     NO
//   10     five-length melody, seed 6       —      0.218   —     NO
//
// MUTANTS, each driven through the mirror (a claim that cannot fail for its named reason is not a
// claim, #367): folding UP as well as down → claim 7 reads 144.04 (and still KNOWN at conf 0.50 —
// a wrong number that passes, which is why claim 7 pins the TEMPO) · one-hop energy frames →
// claim 9 reads conf 0.743, KNOWN · single-lag confidence → claim 10 reads conf 0.602, KNOWN ·
// no short-media rule → claim 4 is KNOWN. Claim 10's fixture was SELECTED for disagreeing: the two
// confidence definitions disagree on 17 of 30 seeds (comb names a tempo on 1/30, single-lag on
// 18/30); seed 6 is the widest gap.
//
// COUNTERWEIGHTS (§2 #343): claims 1, 2, 3, 7 and 8 are the half that keeps "refuse more" from
// passing — a detector that returned nil for everything would pass 4, 5, 6, 9 and 10.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheDetectedTempoIsHonestTests: XCTestCase {

    private static let sampleRate = 22_050.0
    private static let analysisFile = "Sources/Echoelmusic/Sequencer/AudioTempoAnalysis.swift"
    private static let detectorFile = "Sources/Echoelmusic/Core/TempoDetector.swift"

    // MARK: - Fixtures (mirrored exactly in the transcription)

    private struct LCG {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / 9_007_199_254_740_992.0
        }
        mutating func signed() -> Float { Float(next() * 2 - 1) }
    }

    private static func place(_ source: [Float], at seconds: Double,
                              into buffer: inout [Float], gain: Float = 1) {
        let start = Swift.max(0, Int((seconds * sampleRate).rounded(.toNearestOrEven)))
        for (k, v) in source.enumerated() {
            let j = start + k
            guard j < buffer.count else { break }
            buffer[j] += gain * v
        }
    }

    private static func click() -> [Float] {
        let n = Int(sampleRate * 0.004)
        return (0..<n).map { i -> Float in
            let t = Double(i) / sampleRate
            return Float(Foundation.sin(2 * Double.pi * 3000 * t) * Foundation.exp(-t / 0.001))
        }
    }

    private static func clickTrack(bpm: Double, seconds: Double) -> [Float] {
        var buffer = [Float](repeating: 0, count: Int(seconds * sampleRate))
        let c = click()
        let period = 60.0 / bpm
        var t = 0.0
        while t < seconds {
            place(c, at: t, into: &buffer)
            t += period
        }
        return buffer
    }

    private static func kick() -> [Float] {
        let n = Int(sampleRate * 0.15)
        return (0..<n).map { i -> Float in
            let t = Double(i) / sampleRate
            let f = 55 + 90 * Foundation.exp(-t / 0.02)
            return Float(Foundation.sin(2 * Double.pi * f * t) * Foundation.exp(-t / 0.05))
        }
    }

    private static func snare(_ rng: inout LCG) -> [Float] {
        let n = Int(sampleRate * 0.12)
        var out: [Float] = []
        out.reserveCapacity(n)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            out.append(Float(Double(rng.signed()) * Foundation.exp(-t / 0.03) * 0.7))
        }
        return out
    }

    private static func hat(_ rng: inout LCG) -> [Float] {
        let n = Int(sampleRate * 0.04)
        var out: [Float] = []
        out.reserveCapacity(n)
        var previous = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let v = Double(rng.signed())
            let d = v - previous
            previous = v
            out.append(Float(d * Foundation.exp(-t / 0.008) * 0.25))
        }
        return out
    }

    private static func drumLoop(bpm: Double, bars: Int, seed: UInt64) -> [Float] {
        var rng = LCG(state: seed)
        let seconds = Double(bars * 4) * 60.0 / bpm
        var buffer = [Float](repeating: 0,
                             count: Int((seconds * sampleRate).rounded(.toNearestOrEven)))
        let quarter = 60.0 / bpm
        let k = kick()
        for bar in 0..<bars {
            for beat in 0..<4 {
                let t0 = Double(bar * 4 + beat) * quarter
                if beat == 0 || beat == 2 { place(k, at: t0, into: &buffer) }
                if beat == 1 || beat == 3 {
                    let s = snare(&rng)
                    place(s, at: t0, into: &buffer)
                }
                let onBeat = hat(&rng)
                place(onBeat, at: t0, into: &buffer)
                let offBeat = hat(&rng)
                place(offBeat, at: t0 + quarter / 2, into: &buffer, gain: 0.6)
            }
        }
        return buffer
    }

    private static func noise(seconds: Double, seed: UInt64) -> [Float] {
        var rng = LCG(state: seed)
        return (0..<Int(seconds * sampleRate)).map { _ in Float(Double(rng.signed()) * 0.3) }
    }

    private static func pad(seconds: Double) -> [Float] {
        (0..<Int(seconds * sampleRate)).map { i -> Float in
            let t = Double(i) / sampleRate
            let fade = Swift.max(0, Swift.min(1, t / 1.5, (seconds - t) / 1.5))
            let tones = Foundation.sin(2 * Double.pi * 220 * t)
                + Foundation.sin(2 * Double.pi * 277.18 * t)
                + Foundation.sin(2 * Double.pi * 329.63 * t)
            return Float(tones * 0.2 * fade)
        }
    }

    /// Notes whose lengths come from a FIXED set of five: the same interval recurs, but onsets
    /// do not land on the multiples of any period — an interval, not a pulse.
    private static func intervalMelody(seconds: Double, seed: UInt64) -> [Float] {
        var rng = LCG(state: seed)
        var buffer = [Float](repeating: 0, count: Int(seconds * sampleRate))
        let lengths: [Double] = [0.13, 0.21, 0.34, 0.55, 0.89]
        var t = 0.0
        while t < seconds {
            let length = lengths[Int(rng.next() * 5) % 5]
            let semitone = Double(Int(rng.next() * 12) % 12)
            let f = 220 * Foundation.pow(2, semitone / 12)
            let n = Int(length * sampleRate)
            let tone = (0..<n).map { i -> Float in
                let u = Double(i) / sampleRate
                return Float(Foundation.sin(2 * Double.pi * f * u) * Foundation.exp(-u / 0.3) * 0.4)
            }
            place(tone, at: t, into: &buffer)
            t += length
        }
        return buffer
    }

    private func analyse(_ samples: [Float]) -> DetectedTempo? {
        guard var envelope = TempoOnsetEnvelope(sampleRate: Self.sampleRate, maxSeconds: 90) else {
            XCTFail("a finite positive sample rate must build an envelope")
            return nil
        }
        envelope.append(samples)
        return TempoDetector.estimate(envelope: envelope.values,
                                      envelopeRate: envelope.rate,
                                      mediaDurationSeconds: Double(samples.count) / Self.sampleRate)
    }

    // MARK: - Claims

    /// 1. A steady pulse is found at its own tempo, and it is not mistaken for a loop.
    func testASteadyPulseIsFoundAtItsOwnTempo() throws {
        let tempo = try XCTUnwrap(analyse(Self.clickTrack(bpm: 97.3, seconds: 12)))
        XCTAssertTrue(tempo.isKnown, "a clean 97.3 BPM pulse must be KNOWN; conf \(tempo.confidence)")
        XCTAssertEqual(tempo.bpm / 97.3, 1, accuracy: 0.005, "read \(tempo.bpm) BPM for a 97.3 BPM pulse")
        XCTAssertNil(tempo.loopBars, "12 s at 97.3 BPM is 4.87 bars — not a whole loop, nothing to snap to")
    }

    /// 2. A whole loop takes the EXACT tempo its length implies, not the autocorrelation's estimate.
    func testAWholeLoopTakesTheExactTempoItsLengthImplies() throws {
        let loop = Self.drumLoop(bpm: 128, bars: 4, seed: 11)
        let tempo = try XCTUnwrap(analyse(loop))
        let seconds = Double(loop.count) / Self.sampleRate
        XCTAssertEqual(tempo.loopBars, 4, "a 4-bar loop must be recognised as one")
        XCTAssertEqual(tempo.bpm, 60.0 * Double(TimelineTime.beatsPerBar) * 4 / seconds, accuracy: 1e-9,
                       "a snapped loop's tempo is DERIVED from its length — that is the point of snapping")
        XCTAssertTrue(tempo.isKnown)
    }

    /// 3. A one-bar loop is shorter than the short-media threshold and is still KNOWN — because it
    /// is a whole loop. This is the counterweight to claim 4.
    func testAOneBarLoopIsKnownDespiteBeingShort() throws {
        let loop = Self.drumLoop(bpm: 128, bars: 1, seed: 12)
        let tempo = try XCTUnwrap(analyse(loop))
        XCTAssertLessThan(tempo.mediaDurationSeconds, TempoDetector.shortMediaSeconds,
                          "premise: this fixture must be SHORT, or the claim tests nothing")
        XCTAssertEqual(tempo.loopBars, 1)
        XCTAssertTrue(tempo.isKnown, "a whole 1-bar loop is the commonest thing a person imports")
    }

    /// 4. A short slice that is NOT a whole loop is unclear — even though its pulse is strong.
    func testAShortSliceThatIsNotALoopIsUnclear() throws {
        let tempo = try XCTUnwrap(analyse(Self.clickTrack(bpm: 120, seconds: 3.0)))
        XCTAssertGreaterThanOrEqual(tempo.confidence, TempoDetector.confidenceFloor,
            "premise: the pulse is strong, so the refusal below is the SHORT-MEDIA rule and not low confidence")
        XCTAssertNil(tempo.loopBars, "premise: 3 s at 120 BPM is 1.5 bars — not a loop")
        XCTAssertFalse(tempo.isKnown,
            "under 4 s, a few periods of anything autocorrelate by chance (20–40 % of noise and speech "
            + "did); only a whole loop's length is independent evidence")
    }

    /// 5. Noise is not given a tempo.
    func testNoiseIsNotGivenATempo() {
        let tempo = analyse(Self.noise(seconds: 10, seed: 13))
        let read = tempo?.bpm ?? 0
        XCTAssertFalse(tempo?.isKnown ?? false, "white noise was named \(read) BPM")
    }

    /// 6. Nothing to analyse returns nothing, rather than a number.
    func testSilenceAndTooShortMediaReturnNothing() {
        XCTAssertNil(analyse([Float](repeating: 0, count: Int(8 * Self.sampleRate))),
                     "silence has no onsets; a tempo for it would be invented")
        XCTAssertNil(analyse(Self.clickTrack(bpm: 120, seconds: 1.2)),
                     "media under minimumSeconds must return nil, not a guess")
    }

    /// 7. A slow pulse is reported at its own tempo — never doubled.
    func testASlowPulseIsReportedAtItsOwnTempoNotDoubled() throws {
        let tempo = try XCTUnwrap(analyse(Self.clickTrack(bpm: 72, seconds: 16)))
        XCTAssertEqual(tempo.bpm / 72, 1, accuracy: 0.005,
            "read \(tempo.bpm) BPM for a 72 BPM pulse on quarter notes. Doubling puts the period BETWEEN "
            + "beats; the fold goes DOWN only (see foldCeilingBPM)")
        XCTAssertTrue(tempo.isKnown)
    }

    /// 8. A fast pulse is halved by rule, and the other octave is offered, not lost.
    func testAFastPulseIsHalvedAndOffersTheOtherOctave() throws {
        let tempo = try XCTUnwrap(analyse(Self.clickTrack(bpm: 174, seconds: 12)))
        XCTAssertEqual(tempo.bpm / 87, 1, accuracy: 0.005, "174 BPM folds to 87 by the stated rule")
        XCTAssertEqual(tempo.octaveAlternativeBPM / 174, 1, accuracy: 0.005,
                       "the other reading of the same pulse must reach the person who knows which they meant")
        XCTAssertLessThan(tempo.bpm, TempoDetector.foldCeilingBPM)
    }

    /// 9. A sustained chord with no onsets has no tempo.
    func testASteadyToneHasNoTempo() {
        let tempo = analyse(Self.pad(seconds: 12))
        let scored = tempo?.confidence ?? 0
        XCTAssertFalse(tempo?.isKnown ?? false,
            "a steady chord scored \(scored). With one-hop energy frames it scores 0.743: "
            + "~5 ms of a 220 Hz tone spans a non-integer number of cycles, so the energy of a STEADY tone "
            + "oscillates (see TempoOnsetEnvelope.frameHops)")
    }

    /// 10. A recurring interval is not a pulse.
    func testARepeatedIntervalIsNotAPulse() {
        let tempo = analyse(Self.intervalMelody(seconds: 12, seed: 6))
        let scored = tempo?.confidence ?? 0
        XCTAssertFalse(tempo?.isKnown ?? false,
            "notes drawn from five fixed lengths repeat an INTERVAL; a tempo means onsets at its "
            + "MULTIPLES. Confidence at the first lag alone reads 0.602 here; the comb reads \(scored)")
    }

    /// 11. The envelope does not depend on how the sample stream was cut.
    func testTheEnvelopeDoesNotDependOnHowTheStreamWasCut() throws {
        let samples = Self.clickTrack(bpm: 97.3, seconds: 6)
        var whole = try XCTUnwrap(TempoOnsetEnvelope(sampleRate: Self.sampleRate, maxSeconds: 90))
        whole.append(samples)
        var chunked = try XCTUnwrap(TempoOnsetEnvelope(sampleRate: Self.sampleRate, maxSeconds: 90))
        var start = 0
        while start < samples.count {
            let end = Swift.min(samples.count, start + 777)
            chunked.append(samples[start..<end])
            start = end
        }
        XCTAssertEqual(whole.values, chunked.values,
                       "the file adapter reads in chunks; the first difference and the frame must carry across them")
        XCTAssertFalse(whole.values.isEmpty)
    }

    /// 12. Degenerate input is refused rather than guessed.
    func testADegenerateInputIsRefusedRatherThanGuessed() {
        XCTAssertNil(TempoOnsetEnvelope(sampleRate: 0, maxSeconds: 90))
        XCTAssertNil(TempoOnsetEnvelope(sampleRate: .nan, maxSeconds: 90))
        XCTAssertNil(TempoOnsetEnvelope(sampleRate: -44_100, maxSeconds: 90))
        XCTAssertNil(TempoOnsetEnvelope(sampleRate: 44_100, maxSeconds: 0))
        let envelope = [Double](repeating: 0.5, count: 1_000)
        XCTAssertNil(TempoDetector.estimate(envelope: envelope, envelopeRate: 0, mediaDurationSeconds: 10))
        XCTAssertNil(TempoDetector.estimate(envelope: envelope, envelopeRate: .nan, mediaDurationSeconds: 10))
        XCTAssertNil(TempoDetector.estimate(envelope: envelope, envelopeRate: 200, mediaDurationSeconds: .nan))
        XCTAssertNil(TempoDetector.estimate(envelope: envelope, envelopeRate: 200, mediaDurationSeconds: 10),
                     "a constant envelope has no onsets after detrending — nothing to estimate")
    }

    /// 13. KNOWN needs the floor AND either enough length or a whole loop.
    func testKnownNeedsTheFloorAndEitherLengthOrALoop() {
        let floor = TempoDetector.confidenceFloor
        let long = TempoDetector.shortMediaSeconds + 10
        let short = TempoDetector.shortMediaSeconds - 1
        func tempo(_ conf: Double, _ seconds: Double, _ bars: Int?) -> DetectedTempo {
            DetectedTempo(bpm: 120, confidence: conf, octaveAlternativeBPM: 60,
                          loopBars: bars, mediaDurationSeconds: seconds)
        }
        XCTAssertTrue(tempo(floor, long, nil).isKnown)
        XCTAssertFalse(tempo(floor - 0.01, long, nil).isKnown, "below the floor is UNKNOWN")
        XCTAssertFalse(tempo(0.99, short, nil).isKnown, "short and not a loop is UNKNOWN at any confidence")
        XCTAssertTrue(tempo(floor, short, 1).isKnown, "short AND a whole loop is KNOWN")
        XCTAssertFalse(DetectedTempo(bpm: .nan, confidence: 0.99, octaveAlternativeBPM: 60,
                                     loopBars: nil, mediaDurationSeconds: long).isKnown)
    }

    /// 14. SOURCE-TEXT SCAN: the analysis writes nothing, and its sentence asks the verdict.
    func testTheAnalysisWritesNothingAndAsksTheVerdict() throws {
        let analysis = try code(Self.analysisFile)
        XCTAssertTrue(analysis.contains("tempo.isKnown"),
                      "summarise must ask isKnown — never confidence alone (the #F3 lesson)")
        for forbidden in ["ClipStore", "TimelineStore", "SessionContext", "setTempo", "nativeBPM ="] {
            XCTAssertFalse(analysis.contains(forbidden),
                           "AudioTempoAnalysis must return a value and write nothing; found \(forbidden)")
        }
        let detector = try code(Self.detectorFile)
        XCTAssertFalse(detector.contains("import AVFoundation"),
                       "the estimator stays pure so every claim above runs without a file or a device")
    }

    /// 15. (#B2) Adoption is NEVER-CLOBBER and KNOWN-only — driven with plain values, because the
    /// real `ClipStore` persists into the shared App Group and a guard must not write there.
    func testAClipAdoptsOnlyAKnownTempoAndNeverReplacesOne() {
        let known = DetectedTempo(bpm: 124, confidence: 0.9, octaveAlternativeBPM: 62,
                                  loopBars: 4, mediaDurationSeconds: 7.74)
        let unknown = DetectedTempo(bpm: 124, confidence: TempoDetector.confidenceFloor - 0.05,
                                    octaveAlternativeBPM: 62, loopBars: nil, mediaDurationSeconds: 30)
        XCTAssertTrue(known.isKnown && !unknown.isKnown, "premise: one of each")

        XCTAssertEqual(AudioTempoAnalysis.adoptableNativeBPM(current: 0, detected: known), 124,
                       "a clip with no native tempo adopts a KNOWN detection — that is the whole slice")
        XCTAssertNil(AudioTempoAnalysis.adoptableNativeBPM(current: 98, detected: known),
                     "NEVER-CLOBBER: a clip that already has a native tempo keeps it")
        XCTAssertNil(AudioTempoAnalysis.adoptableNativeBPM(current: 0, detected: unknown),
                     "an UNKNOWN estimate must never become a warp rate")
        XCTAssertNil(AudioTempoAnalysis.adoptableNativeBPM(current: 0, detected: nil))
        XCTAssertNil(AudioTempoAnalysis.adoptableNativeBPM(current: .nan, detected: known),
                     "a corrupt current value is not 'empty' — leave it for a person to look at")

        let wild = DetectedTempo(bpm: 1_000, confidence: 0.9, octaveAlternativeBPM: 500,
                                 loopBars: nil, mediaDurationSeconds: 30)
        XCTAssertEqual(AudioTempoAnalysis.adoptableNativeBPM(current: 0, detected: wild),
                       AudioClipRegion.nativeBPMRange.upperBound,
                       "an adopted tempo goes through the ONE clamp `Clip` already owns (#416)")
    }

    /// 16. (#B2) SOURCE-TEXT SCAN: the DETECTION writer asks the policy; the door runs the analysis
    /// behind the hop and writes the CLIP; the synchronous import transaction stays out of it.
    func testTheTempoIsAdoptedByTheClipStoreFromBehindTheHop() throws {
        let store = try code("Sources/Echoelmusic/Core/ClipStore.swift")
        XCTAssertTrue(store.contains("func adoptDetectedNativeBPM"), "the writer is gone")
        XCTAssertTrue(store.contains("AudioTempoAnalysis.adoptableNativeBPM("),
                      "the writer must ask the pure policy, not re-decide (#416)")
        XCTAssertTrue(store.contains("clip.kind == .audio"),
                      "only an AUDIO clip has a native tempo; a MIDI clip ignores it")

        let door = try code("Sources/Echoelmusic/Studio/WorkstationView.swift")
        guard let hop = door.range(of: "Task.detached(priority: .utility)"),
              let end = door.range(of: ".value", range: hop.upperBound..<door.endIndex) else {
            XCTFail("ANCHOR MISSING: the door's detached analysis hop")
            return
        }
        XCTAssertTrue(door[hop.upperBound..<end.lowerBound].contains("AudioTempoAnalysis.analyse(url: url)"),
                      "the tempo analysis is seconds of work and must run INSIDE the detached hop")
        XCTAssertTrue(door.contains("clipStore.adoptDetectedNativeBPM("),
                      "the door must write through the store's detection writer")
        XCTAssertFalse(door.contains("nativeBPM ="), "the door must not assign the field itself")
        XCTAssertFalse(door.contains("setTempo("), "a detected tempo must never reach the transport")

        let transaction = try code("Sources/Echoelmusic/Sequencer/AudioImport.swift")
        XCTAssertFalse(transaction.contains("AudioTempoAnalysis"),
                       "AudioImport.perform is @MainActor and synchronous; the analysis there is the freeze")
    }

    // MARK: - Source helpers

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func code(_ relative: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relative)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) could not be read — a missing anchor is a finding (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }
}

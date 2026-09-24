// TheAUv3ReverbFollowsTheHostRateTests.swift
// Echoel — 2026-09-24 (overnight P1): the AUv3's reverb (`EchoelReverb`, the WA3.3 consumer of
// host address 6) is sized for the rate the host actually runs at. Blocking bundle.
//
// THE DEFECT (measured before the repair). `EchoelReverb` sizes its eight comb and four
// allpass tanks from the rate given to `init` (Freeverb tunings are samples at 44.1 kHz, scaled
// to the rate). The AUv3 built it at a 48000 literal and had no way to change it — the class
// had no rate setter — while #1407 re-points both engines to `outputBus.format.sampleRate`. In
// a 96 kHz host every delay line was half as long IN SECONDS as tuned (the shortest comb's first
// echo at 12.6 ms instead of 25.3 ms); at 44.1 kHz about 9 % longer.
//
// THE REPAIR. `EchoelReverb.setSampleRate` rebuilds the tanks with `init`'s own sizing rule and
// empties them; the AUv3 calls it in `allocateRenderResources`, next to the two engine setters,
// before `noteOn`.
//
// WHAT KIND OF GREEN (§1), PER CLAIM:
// · claims 1–5 are BEHAVIOUR on the real `EchoelReverb`: rendered samples, not property reads.
// · claim 6 is a SOURCE-TEXT SCAN of the extension, which this bundle cannot instantiate.
// · HOST — the room sounding the same at 44.1 and 96 kHz in AUM/Logic — stays owed.
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It does not freeze the Freeverb tunings; it
// freezes that a room keeps its size in SECONDS whatever the rate, that re-pointing equals
// constructing, and that re-pointing to the current rate is a no-op.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `98f5d8f7e`: `setSampleRate`
// and `sampleRate` do not exist on `EchoelReverb`, so claims 1–5 do not COMPILE there —
// FORWARD guards. The DEFECT was driven in Python on the parent's sizing rule: a 48 kHz tank's
// first echo is at sample 1214, which is 12.6 ms at 96 kHz. Claim 6 is a REGRESSION: its anchor
// is absent in the parent.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheAUv3ReverbFollowsTheHostRateTests: XCTestCase {

    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"
    /// The shortest Freeverb comb, in samples at 44.1 kHz: the first echo arrives this late.
    private static let shortestCombAt44k1 = 1116

    // MARK: - claim 1

    func testARePointedReverbIsIndistinguishableFromAConstructedOne() {
        let built = EchoelReverb(sampleRate: 96000)
        let repointed = EchoelReverb(sampleRate: 48000)
        _ = Self.wetResponse(of: repointed, count: 3000)   // dirty the old tanks first
        repointed.setSampleRate(96000)
        XCTAssertEqual(repointed.sampleRate, 96000)
        XCTAssertEqual(Self.wetResponse(of: built, count: 20000),
                       Self.wetResponse(of: repointed, count: 20000), """
            A reverb re-pointed to 96 kHz does not sound like one built there. Either the \
            tanks are not rebuilt with `init`'s rule, or state from the old rate survives.
            """)
    }

    // MARK: - claim 2

    func testTheRoomKeepsItsSizeInSecondsAtEveryHostRate() {
        let tuned = Double(Self.shortestCombAt44k1) / 44100
        for rate in [44100.0, 48000, 88200, 96000] as [Float] {
            let reverb = EchoelReverb(sampleRate: 48000)
            reverb.setSampleRate(rate)
            let arrival = Self.firstEcho(of: reverb)
            XCTAssertNotNil(arrival, "no echo at \(rate) Hz — the claim would be vacuous")
            guard let arrival else { continue }
            XCTAssertEqual(Double(arrival) / Double(rate), tuned, accuracy: 1.0 / Double(rate), """
                At \(rate) Hz the first echo arrives after \(arrival) samples — not the \
                \(tuned * 1000) ms the room is tuned for. The tanks were not sized for the rate.
                """)
        }

        // COUNTERWEIGHT — the pre-repair state, reproduced: a tank sized at 48 kHz, run at
        // 96 kHz, answers after the 48 kHz sample count, i.e. at half the tuned time.
        let unrepointed = EchoelReverb(sampleRate: 48000)
        let early = Self.firstEcho(of: unrepointed)
        XCTAssertEqual(early.map { Double($0) / 96000 } ?? 0, tuned / 2, accuracy: 2.0 / 96000,
                       "the counterweight no longer reproduces the defect — this guard went vacuous")
    }

    // MARK: - claim 3

    func testRePointingToTheCurrentRateChangesNothing() {
        let reference = EchoelReverb(sampleRate: 48000)
        let touched = EchoelReverb(sampleRate: 48000)
        let first = Self.wetResponse(of: reference, count: 2000)
        XCTAssertEqual(Self.wetResponse(of: touched, count: 2000), first)
        touched.setSampleRate(48000)
        XCTAssertEqual(Self.wetResponse(of: reference, count: 5000, impulse: false),
                       Self.wetResponse(of: touched, count: 5000, impulse: false), """
            `setSampleRate` at the rate the tanks already have cleared or rebuilt them. The \
            48 kHz path must stay bit-identical — a host at 48 kHz must hear no change.
            """)
    }

    // MARK: - claim 4

    func testADegenerateRateCannotTrapOrPoisonTheTank() {
        for rate in [0, -1, .nan, .infinity, -.infinity, 1e12] as [Float] {
            let built = EchoelReverb(sampleRate: rate)
            let repointed = EchoelReverb(sampleRate: 48000)
            repointed.setSampleRate(rate)
            for reverb in [built, repointed] {
                XCTAssertTrue(reverb.sampleRate.isFinite && reverb.sampleRate >= 1,
                              "rate \(rate) left the tank sized for \(reverb.sampleRate)")
                XCTAssertTrue(Self.wetResponse(of: reverb, count: 2000).allSatisfy(\.isFinite),
                              "rate \(rate) produced a non-finite sample")
                XCTAssertTrue(reverb.decayTimeSeconds.isFinite && reverb.decayTimeSeconds >= 0,
                              "rate \(rate) produced decay \(reverb.decayTimeSeconds)")
            }
        }
    }

    // MARK: - claim 5

    func testTheDecayTimeIsTheSameRoomAtEveryRate() {
        let times = ([44100, 48000, 96000] as [Float]).map { rate -> Double in
            let reverb = EchoelReverb(sampleRate: 48000)
            reverb.setSampleRate(rate)
            return reverb.decayTimeSeconds
        }
        guard let first = times.first else { return XCTFail("no rates measured") }
        for t in times {
            XCTAssertEqual(t, first, accuracy: first * 0.002,
                           "the decay time moves with the rate (\(times)) — the room changed size")
        }
        // The old AUv3 tail (2.0 s) was the synth release alone; the room is longer than zero.
        XCTAssertGreaterThan(first, 1.0, "decay \(first) s — the formula lost its tank length")
        XCTAssertLessThan(first, 10.0, "decay \(first) s — the formula lost its feedback")
    }

    // MARK: - claim 6 (SOURCE-TEXT SCAN)

    func testTheAudioUnitRePointsTheReverbBeforePlaying() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        let allocate = try XCTUnwrap(Self.body(
            startingWith: "public override func allocateRenderResources() throws {", in: code),
            "allocateRenderResources not found — re-anchor this guard (#456)")
        let repoint = try XCTUnwrap(allocate.range(of: "reverb.setSampleRate(hostRate)"), """
            `allocateRenderResources` no longer re-points the reverb. Its tanks then stay sized \
            for the 48 kHz placeholder in every host that is not at 48 kHz.
            """)
        let noteOn = try XCTUnwrap(allocate.range(of: "synth.noteOn("),
                                   "the idle voice is no longer armed here — move this check (#456)")
        XCTAssertLessThan(repoint.lowerBound, noteOn.lowerBound, """
            The reverb is re-pointed after `noteOn`: the first block would ring in the old room.
            """)
    }

    // MARK: - helpers

    /// Fully wet output (left channel) for an impulse, or for a fixed ramp when `impulse` is
    /// false (so a comparison also covers the tank's CURRENT state, not just a fresh one).
    private static func wetResponse(of reverb: EchoelReverb, count: Int,
                                    impulse: Bool = true) -> [Float] {
        reverb.mix = 1
        var out: [Float] = []
        out.reserveCapacity(count)
        for n in 0..<count {
            let x: Float = impulse ? (n == 0 ? 1 : 0) : Float(n % 97) / 97 - 0.5
            out.append(reverb.processStereo(x, x).0)
        }
        return out
    }

    /// Index of the first clearly audible wet sample after an impulse (the anti-denormal DC
    /// floor, ~1e-19, sits far below the threshold).
    private static func firstEcho(of reverb: EchoelReverb) -> Int? {
        wetResponse(of: reverb, count: 8000).firstIndex { abs($0) > 1e-6 }
    }

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

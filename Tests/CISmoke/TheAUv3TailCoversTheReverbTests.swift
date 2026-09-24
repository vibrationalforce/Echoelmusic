// TheAUv3TailCoversTheReverbTests.swift
// Echoel — 2026-09-24 (overnight P1): the AUv3's `tailTime` covers what it actually plays after
// its input stops — the synth's release AND the reverb WA3.3 made audible. Blocking bundle.
//
// THE DEFECT (measured before the repair). `tailTime` was a literal `2.0`: exactly the synth's
// release (`EchoelDDSP.release`, a −60 dB exponential over 2 s). Since WA3.3 the synth runs
// through `EchoelReverb` (host address 6, default 0.3), whose slowest mode needs about 2.5 s to
// fall 60 dB after its input ends. A host that stops rendering at the reported tail (a bounce,
// an offline export, a freeze) cut the room off. Driven in Python on a transcription of
// `EchoelReverb` with the release curve of `EchoelDDSP.applyCurve`: a 55 Hz tone at full mix
// was still at −37 dB two seconds after note-off (−54 dB at the default 0.3).
//
// THE REPAIR. `EchoelBodyVibeDevice.tailSeconds` = release + `EchoelReverb.decayTimeSeconds`
// (T60 of the longest comb at DC, the slowest mode), and the AUv3's `tailTime` returns it.
//
// WHAT KIND OF GREEN (§1), PER CLAIM:
// · claims 1–2 are RENDERED AUDIO through the real `EchoelDDSP` and the same `renderSpace`
//   the AUv3 render block calls, at the worst case the host allows (mix 1).
// · claim 3 is the arithmetic of the one function the AUv3 calls, including its edges.
// · claim 4 is a SOURCE-TEXT SCAN of the extension, which this bundle cannot instantiate.
// · HOST — a bounce in Logic/AUM that keeps the full room — stays owed.
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). The bound is deliberately CONSERVATIVE (release +
// room, while the room's input already fades during the release); a later slice may tighten
// it, and should keep claim 1 green when it does. It does not freeze the release or the room
// size.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `98f5d8f7e`: `tailSeconds`
// and `decayTimeSeconds` do not exist, so claims 1–3 do not COMPILE there — FORWARD guards.
// Claim 4 is a REGRESSION: the parent's `tailTime` body is the literal `2.0`.
// The rendered claims run at 24 kHz to halve their cost; the law is in seconds and
// `TheAUv3ReverbFollowsTheHostRateTests` pins that it does not move with the rate.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheAUv3TailCoversTheReverbTests: XCTestCase {

    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"
    private static let rate: Float = 24000
    /// −60 dB as an amplitude ratio.
    private static let minus60dB: Double = 1e-3

    // MARK: - claim 1

    func testTheReportedTailCoversTheReleaseAndTheRoom() {
        for base: Float in [55, 220] {
            let run = Self.renderNoteThroughTheRoom(base: base, hostMix: 1)
            XCTAssertGreaterThan(run.reference, 1e-4, "the note is silent — the check would be vacuous")
            let end = run.level(endingSecondsAfterNoteOff: run.tail)
            XCTAssertLessThanOrEqual(end, run.reference * Self.minus60dB, """
                At \(base) Hz, full reverb, the output \(run.tail) s after note-off (the \
                reported tail) is only \(20 * log10(end / run.reference)) dB below the note. \
                A host that stops there cuts the room off.
                """)
        }
    }

    // MARK: - claim 2 (COUNTERWEIGHT — the old literal)

    func testTheReleaseAloneWasTooShortOnceTheRoomWasAudible() {
        let run = Self.renderNoteThroughTheRoom(base: 55, hostMix: 1)
        let atOldTail = run.level(endingSecondsAfterNoteOff: 2.0)
        XCTAssertGreaterThan(atOldTail, run.reference * Self.minus60dB, """
            Two seconds after note-off the room is already 60 dB down. Then the old 2.0 s tail \
            was not short, and this guard no longer demonstrates the defect it exists for.
            """)
        XCTAssertGreaterThan(run.tail, 2.0)
    }

    // MARK: - claim 3

    func testTheTailIsTheReleasePlusTheRoomAndAlwaysFinite() {
        let synth = EchoelDDSP(sampleRate: 48000)
        let reverb = EchoelReverb(sampleRate: 48000)
        XCTAssertEqual(EchoelBodyVibeDevice.tailSeconds(synth: synth, reverb: reverb),
                       Double(synth.release) + reverb.decayTimeSeconds)

        synth.release = .nan
        XCTAssertEqual(EchoelBodyVibeDevice.tailSeconds(synth: synth, reverb: reverb),
                       reverb.decayTimeSeconds, "a NaN release must count as none, not poison the tail")

        reverb.roomSize = 1.2   // feedback above 1: nothing sets this, the edge must still hold
        let runaway = EchoelBodyVibeDevice.tailSeconds(synth: synth, reverb: reverb)
        XCTAssertTrue(runaway.isFinite, "a host must never be handed a non-finite tail")
        XCTAssertEqual(runaway, .greatestFiniteMagnitude)
    }

    // MARK: - claim 4 (SOURCE-TEXT SCAN)

    func testTheAudioUnitReportsTheSharedTail() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        let tail = try XCTUnwrap(Self.body(
            startingWith: "public override var tailTime: TimeInterval {", in: code), """
            `tailTime` is no longer a computed property with a body. The parent wrote \
            `{ 2.0 }` — if a literal came back, this is the regression this guard exists for.
            """)
        XCTAssertTrue(tail.contains("EchoelBodyVibeDevice.tailSeconds("), """
            `tailTime` no longer asks `EchoelBodyVibeDevice.tailSeconds`. The rendered claims \
            above prove THAT function; a tail computed anywhere else is unproven.
            """)
    }

    // MARK: - helpers

    private struct Run {
        var samples: [Float]      // L and R interleaved per block, as rendered
        var reference: Double     // RMS of the last 50 ms before note-off
        var noteOffIndex: Int     // in frames
        var tail: Double
        var blockFrames: Int
        var rate: Double

        /// RMS of the 50 ms window that ends `seconds` after note-off (both channels).
        func level(endingSecondsAfterNoteOff seconds: Double) -> Double {
            let end = noteOffIndex + Int(seconds * rate)
            return blockInterleavedRMS(samples, frames: (end - Int(0.05 * rate))..<end,
                                       block: blockFrames)
        }
    }

    /// The AUv3 render order for one note: synth, then the space stage; note-off after 0.6 s;
    /// then render until the reported tail has passed.
    private static func renderNoteThroughTheRoom(base: Float, hostMix: Float) -> Run {
        let synth = EchoelDDSP(sampleRate: rate)
        let texture = EchoelCellular(cellCount: 128, sampleRate: rate)
        let reverb = EchoelReverb(sampleRate: rate)
        EchoelBodyVibeDevice.apply(.synthReverbMix, value: hostMix, synth: synth, texture: texture)
        synth.amplitude = 0.6
        synth.noteOn(frequency: base)

        let tail = EchoelBodyVibeDevice.tailSeconds(synth: synth, reverb: reverb)
        let block = 512
        let noteOff = Int(0.6 * Double(rate)) / block * block
        let total = noteOff + Int((tail + 0.1) * Double(rate))
        var left = [Float](repeating: 0, count: block)
        var right = [Float](repeating: 0, count: block)
        var out: [Float] = []
        out.reserveCapacity(total * 2 + block * 2)
        var frame = 0
        while frame < total {
            if frame == noteOff { synth.noteOff() }
            synth.render(buffer: &left, frameCount: block)
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    EchoelBodyVibeDevice.renderSpace(reverb, synth: synth, left: l, right: r, count: block)
                }
            }
            out.append(contentsOf: left)
            out.append(contentsOf: right)
            frame += block
        }
        let reference = blockInterleavedRMS(out, frames: (noteOff - Int(0.05 * Double(rate)))..<noteOff,
                                            block: block)
        return Run(samples: out, reference: reference, noteOffIndex: noteOff, tail: tail,
                   blockFrames: block, rate: Double(rate))
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

/// RMS over a frame range of a block-interleaved buffer (a block of L, then a block of R).
/// File-level and nonisolated so the value type above can call it.
private func blockInterleavedRMS(_ samples: [Float], frames: Range<Int>, block: Int) -> Double {
    var sum = 0.0
    var n = 0
    for f in frames where f >= 0 {
        let l = (f / block) * block * 2 + f % block
        let r = l + block
        guard r < samples.count else { break }
        sum += Double(samples[l]) * Double(samples[l]) + Double(samples[r]) * Double(samples[r])
        n += 2
    }
    return n > 0 ? (sum / Double(n)).squareRoot() : 0
}

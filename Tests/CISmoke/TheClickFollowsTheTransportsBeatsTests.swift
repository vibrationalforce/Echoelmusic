// TheClickFollowsTheTransportsBeatsTests.swift
// Echoel — modes census 2026-09-26, design slice 10 (the click), first half: the click follows
// the transport's beats.
//
// WHAT THIS PINS. The click ran on its own sample clock and was lined up once, by a `resync()`
// called right after `PatternEngine.play` in the instrument's generate path. That instant is the
// transport's DECISION to play; step 0 SOUNDS one step later (`PatternEngine.play` schedules its
// first `advance` one step on — the one-16th-early defect #300 found in MIDI Start). So the
// click's downbeat led the music by a sixteenth, then kept its own clock while the notes kept the
// transport's timer, and a song started from the Workstation was never lined up at all. Now the
// transport's step subscriber anchors the click on every beat it plays.
//
// 1. END-TO-END BEHAVIOUR (`MetronomeVoice.anchored`, `anchorWord`, pure): an anchor that
//    arrives just after the click struck the same beat keeps that click and measures the next
//    beat from the anchor (no flam); any other anchor strikes now, as the named beat; the count
//    follows the transport only while "Accent every" IS the bar; bad beat lengths change
//    nothing, a NaN counter strikes (and heals).
// 2. END-TO-END BEHAVIOUR (the real render block, through `_testRender`): an anchor mid-beat
//    strikes the downbeat there, accented; an anchor just after the click's own downbeat does not
//    strike twice and moves the next beat to one beat after the anchor; an anchor left pending
//    when the click was switched off does not move the fresh bar of the next arm.
// 3. SOURCE: the app registers ONE step subscriber under "metronome" that anchors on every beat
//    with `Transport`'s own constants (#416); the render applies `anchored` once, after the arm
//    and before the frame loop; no `resync()` remains; and the premise the whole repair stands
//    on — `PatternEngine.play` sounds step 0 one step after the call — is pinned.
//
// Grading (§0, no Swift toolchain): `anchorBeat`, `anchorWord` and `anchored` do not exist on the
// parent (`13cdb3572`), so this file does not compile there — every claim is a FORWARD guard, one
// absence (#486). The render loop was transcribed into Python (`click_sim.py`, scratchpad) with
// the strike detector below, and driven: tree — strikes at 0 / 10 000 (accent) / 34 000 for
// claim 2a, 0 / 26 000 for 2b, a 0.595 first peak (accent) for 2c. Mutants: absorb removed → an
// extra strike at 2 000 in 2b; the pending anchor not cleared on arm → a 0.416 first peak (not
// the accent) in 2c. Each red.
// NOT covered: the timing on glass — the anchor lands at the next render buffer (5–21 ms) and
// carries the main-actor timer's jitter, the same jitter the notes carry; whether that reads as
// "with the music" is a device listen.
// NEEDS-FOUNDER-VERIFY: Tempo panel → Click on → Play (instrument): the first click is the
// accented one and lands WITH the first note, not a sixteenth before; let it run a minute — the
// click stays with the beat. Then the Workstation's Play with the click on: the accent lands on
// each bar's first beat.

import AVFoundation
import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheClickFollowsTheTransportsBeatsTests: XCTestCase {

    private static let level: Float = 0.6
    private static let perBeat = MetronomeVoice.samplesPerBeat(bpm: 120)   // 24 000 at 48 kHz

    // MARK: 1 — the decision, pure

    func testAnAnchorKeepsAClickItJustStruckAndStrikesOtherwise() {
        let pb = 24_000.0
        let share = MetronomeVoice.anchorAbsorbShare
        XCTAssertGreaterThan(share, 0)
        XCTAssertLessThan(share, 0.5, "absorbing half a beat or more would swallow the beat itself")
        let edge = pb * share

        func land(_ word: Int, _ index: Int, _ counter: Double, perBeat: Double = 24_000,
                  bars: Int = 4) -> (Int, Double) {
            let r = MetronomeVoice.anchored(word: word, beatIndex: index, sampleCounter: counter,
                                            perBeat: perBeat, bars: bars)
            return (r.beatIndex, r.sampleCounter)
        }
        // No anchor: nothing moves.
        XCTAssertTrue(land(MetronomeVoice.noAnchor, 2, 1_234) == (2, 1_234))
        // The click struck this very beat a moment ago: keep it, measure from now.
        XCTAssertTrue(land(0, 0, 100) == (0, 0), "a flam is two strikes for one beat")
        XCTAssertTrue(land(0, 0, edge - 1) == (0, 0))
        // Too long ago, or a different beat: strike now, as the named beat.
        XCTAssertTrue(land(0, 0, edge) == (3, pb), "the share is a strict bound")
        XCTAssertTrue(land(0, 0, 20_000) == (3, pb))
        XCTAssertTrue(land(2, 0, 100) == (1, pb), "it struck beat 0 — beat 2 is struck now")
        XCTAssertTrue(land(6, 3, 30_000, bars: 4) == (1, pb), "a named beat is taken modulo the bar")
        // Timing only (the accent keeps its own cycle): the count is never rewritten.
        XCTAssertTrue(land(MetronomeVoice.timingOnlyAnchor, 2, 100) == (2, 0))
        XCTAssertTrue(land(MetronomeVoice.timingOnlyAnchor, 2, 20_000) == (2, pb))
        // A beat length that cannot be one changes nothing; a NaN counter strikes and heals.
        for bad in [0.0, -5, .nan, .infinity] as [Double] {
            XCTAssertTrue(land(1, 2, 500, perBeat: bad) == (2, 500), "perBeat \(bad)")
        }
        let healed = land(1, 2, .nan)
        XCTAssertEqual(healed.0, 0)
        XCTAssertEqual(healed.1, pb)
        XCTAssertTrue(land(1, 2, 500, bars: 0) == (2, 500))
    }

    func testTheCountFollowsTheTransportOnlyWhileTheAccentIsTheBar() {
        XCTAssertEqual(MetronomeVoice.anchorWord(beat: 1, of: 4, accentEvery: 4), 1)
        XCTAssertEqual(MetronomeVoice.anchorWord(beat: 5, of: 4, accentEvery: 4), 1)
        XCTAssertEqual(MetronomeVoice.anchorWord(beat: -1, of: 4, accentEvery: 4), 3)
        XCTAssertEqual(MetronomeVoice.anchorWord(beat: 0, of: 4, accentEvery: 3),
                       MetronomeVoice.timingOnlyAnchor,
                       "\"Accent every 3\" keeps its own cycle across 4/4 bars")
        XCTAssertEqual(MetronomeVoice.anchorWord(beat: 0, of: 0, accentEvery: 4), MetronomeVoice.noAnchor)
        XCTAssertNotEqual(MetronomeVoice.noAnchor, MetronomeVoice.timingOnlyAnchor)
        XCTAssertLessThan(MetronomeVoice.noAnchor, 0, "a named beat is never mistaken for 'none'")
        XCTAssertLessThan(MetronomeVoice.timingOnlyAnchor, 0)
    }

    // MARK: 2 — the real render block

    func testAnAnchorMidBeatStrikesTheDownbeatThere() {
        let m = armed()
        var x = render(m, frames: 10_000)            // the arm's own fresh bar strikes at 0
        m.anchorBeat(0, of: 4)                       // the transport's downbeat sounds now
        x += render(m, frames: 30_000)
        let found = strikes(in: x)
        XCTAssertEqual(found.count, 3, "strikes at \(found)")
        guard found.count == 3 else { return }
        XCTAssertLessThan(abs(found[1] - 10_000), 64, "struck at the anchor: \(found)")
        XCTAssertLessThan(abs(found[2] - (10_000 + Int(Self.perBeat))), 64,
                          "the next beat is one beat after the anchor: \(found)")
        XCTAssertGreaterThan(peak(in: x, from: 10_000, width: 400), Self.level * 0.85,
                             "the anchored downbeat is the ACCENT (full envelope), not a plain beat")
    }

    func testAnAnchorJustAfterTheClicksOwnDownbeatDoesNotStrikeTwice() {
        let m = armed()
        var x = render(m, frames: 2_000)             // struck its downbeat 2 000 frames ago
        m.anchorBeat(0, of: 4)                       // the transport's downbeat, a little late
        x += render(m, frames: 30_000)
        let found = strikes(in: x)
        XCTAssertEqual(found.count, 2, "one strike for the downbeat, one for the next beat: \(found)")
        guard found.count == 2 else { return }
        XCTAssertLessThan(found[0], 64)
        XCTAssertLessThan(abs(found[1] - (2_000 + Int(Self.perBeat))), 64,
                          "the next beat is measured from the ANCHOR, not from the early strike: \(found)")
    }

    func testAnAnchorLeftPendingDoesNotMoveTheNextArmsFreshBar() {
        let m = armed()
        _ = render(m, frames: 5_000)
        m.anchorBeat(2, of: 4)                       // pending, never rendered…
        m.enabled = false                            // …because the click goes off
        m.enabled = true                             // and comes back: a fresh bar
        let x = render(m, frames: 30_000)
        XCTAssertGreaterThan(peak(in: x, from: 0, width: 400), Self.level * 0.85,
                             "the re-armed click opens on its accented downbeat, not on a stale beat 2")
        let found = strikes(in: x)
        XCTAssertEqual(found.count, 2, "strikes at \(found)")
        guard found.count == 2 else { return }
        XCTAssertLessThan(abs(found[1] - Int(Self.perBeat)), 64)
    }

    // MARK: 3 — the wiring, source

    func testTheTransportAnchorsTheClickOnEveryBeatAndNothingElseLinesItUp() throws {
        let app = try source("Sources/Echoelmusic/EchoelmusicApp.swift")
        XCTAssertEqual(app.components(separatedBy: "addStepSubscriber(\"metronome\"").count - 1, 1,
                       "ONE beat subscriber for the click")
        guard let sub = app.range(of: "transport.addStepSubscriber(\"metronome\", priority: 990) { [weak metronome] pos in"),
              let end = app.range(of: "}\n", range: sub.upperBound..<app.endIndex),
              let close = app.range(of: "}\n", range: end.upperBound..<app.endIndex) else {
            return XCTFail("ANCHOR MISSING: the click's step subscriber (#454)")
        }
        let body = String(app[sub.upperBound..<close.upperBound])
        XCTAssertTrue(body.contains("guard pos.step % Transport.stepsPerBeat == 0 else { return }"),
                      "every BEAT of the transport, counted with its own constant (#416)")
        XCTAssertTrue(body.contains("metronome?.anchorBeat(pos.step / Transport.stepsPerBeat, of: Transport.beatsPerBar)"))

        let studio = try source("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        XCTAssertFalse(studio.contains("metronome.resync("),
                       "a resync after play strikes the downbeat a sixteenth before step 0 sounds")
        let voice = try source("Sources/Echoelmusic/Audio/MetronomeVoice.swift")
        XCTAssertFalse(voice.contains("func resync("), "the click is lined up by the transport, not by a caller")
        guard let anchorBeat = voice.range(of: "public func anchorBeat(_ beat: Int, of beatsInBar: Int) {"),
              let anchorEnd = voice.range(of: "\n    }\n", range: anchorBeat.upperBound..<voice.endIndex) else {
            return XCTFail("ANCHOR MISSING: `anchorBeat` (#454)")
        }
        XCTAssertTrue(voice[anchorBeat.upperBound..<anchorEnd.lowerBound].contains("guard enabled else { return }"),
                      "a switched-off click takes no anchor, so none waits for the next arm")

        guard let render = voice.range(of: "private func renderOnAudioThread("),
              let arm = voice.range(of: "if pendingResync {", range: render.upperBound..<voice.endIndex),
              let applied = voice.range(of: "Self.anchored(word: anchor,", range: render.upperBound..<voice.endIndex),
              let loop = voice.range(of: "for frame in 0..<frameCount {", range: render.upperBound..<voice.endIndex) else {
            return XCTFail("ANCHOR MISSING: the render's arm, anchor and frame loop (#454)")
        }
        XCTAssertLessThan(arm.lowerBound, applied.lowerBound, "the anchor is applied after the arm's fresh bar")
        XCTAssertLessThan(applied.lowerBound, loop.lowerBound, "…and before the first frame, so it moves this buffer")
        XCTAssertEqual(voice.components(separatedBy: "Self.anchored(").count - 1, 1)

        // Premise (#343): step 0 sounds one step AFTER `play` is called — the reason the anchor
        // has to come from the step and never from the play decision.
        let pattern = try source("Sources/Echoelmusic/Sequencer/PatternEngine.swift")
        guard let play = pattern.range(of: "public func play(cause: PlayCause = .unspecified) {"),
              let stop = pattern.range(of: "public func stop() {", range: play.upperBound..<pattern.endIndex) else {
            return XCTFail("ANCHOR MISSING: `PatternEngine.play` (#454)")
        }
        XCTAssertTrue(pattern[play.upperBound..<stop.lowerBound]
            .contains("scheduleTick(after: Transport.stepDuration(atTempo: tempo), from: .now)"))
    }

    // MARK: helpers

    /// One voice, armed at 120 BPM with a 4-beat accent. `enabled`'s `didSet` sets the fresh
    /// bar, so the first rendered frame strikes the downbeat — the app's own entry point.
    private func armed() -> MetronomeVoice {
        let m = MetronomeVoice()
        m.level = Self.level
        m.beatsPerBar = 4
        m.accentDownbeat = true
        m.bpm = 120
        m.enabled = true
        return m
    }

    /// Through the raw `AudioBufferList` seam the `AVAudioSourceNode` closure uses (the
    /// `ATempoJumpDoesNotPullTheAccentForwardTests` harness).
    private func render(_ m: MetronomeVoice, frames: Int) -> [Float] {
        let out = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        out.initialize(repeating: 1234.5, count: frames)
        let abl = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        abl.pointee.mNumberBuffers = 1
        abl.pointee.mBuffers.mNumberChannels = 1
        abl.pointee.mBuffers.mDataByteSize = UInt32(frames * MemoryLayout<Float>.size)
        abl.pointee.mBuffers.mData = UnsafeMutableRawPointer(out)
        defer {
            out.deinitialize(count: frames)
            out.deallocate()
            abl.deallocate()
        }
        m._testRender(frameCount: frames, audioBufferList: abl)
        return Array(UnsafeBufferPointer(start: out, count: frames))
    }

    /// Where the click STRIKES, including inside another click's tail — the case a zero-gap
    /// onset detector cannot see. The envelope only ever decays between strikes (0.9992 per
    /// sample, about 5 % over 64 frames), so a strike is the next 48 frames' peak rising
    /// clearly above the previous 64 frames' peak. Strikes closer than 200 frames are one.
    private func strikes(in x: [Float]) -> [Int] {
        var found: [Int] = []
        var last = -1_000_000
        var i = 0
        while i < x.count {
            let before = x[Swift.max(0, i - 64)..<i].reduce(Float(0)) { Swift.max($0, abs($1)) }
            let after = x[i..<Swift.min(x.count, i + 48)].reduce(Float(0)) { Swift.max($0, abs($1)) }
            if after > 1.25 * before + 0.001, i - last > 200 {
                found.append(i)
                last = i
                i += 48
                continue
            }
            i += 1
        }
        return found
    }

    private func peak(in x: [Float], from start: Int, width: Int) -> Float {
        let lo = Swift.max(0, start)
        let hi = Swift.min(x.count, start + width)
        guard lo < hi else { return 0 }
        return x[lo..<hi].reduce(Float(0)) { Swift.max($0, abs($1)) }
    }

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

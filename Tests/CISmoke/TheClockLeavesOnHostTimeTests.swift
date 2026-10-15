// TheClockLeavesOnHostTimeTests.swift
// Echoel — HW-1 (founder 2026-10-15: iPhone → Xone:96, Eventide H90 delays on the iPhone's MIDI
// clock). Every clock pulse leaves with a host-time stamp — its ideal moment plus the session's
// output path — instead of timestamp 0 from a main-queue timer, whose jitter was the main thread's.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR (`MIDIClockSchedule`, pure): ns → host ticks is the exact floor for
//      Apple-silicon's 125/3 timebase and the identity for 1/1, with no overflow at 2^63 ns; the
//      lookahead is latency + one buffer, clamped to 2…50 ms, and falls back on nothing usable.
//   2. SOURCE-TEXT SCAN (`MIDIOutput`): the timer's deadline seeds the ideal moment, each pulse
//      advances it by one spacing, Start and Clock carry the stamp, the stamp reaches
//      `MIDIEventListAdd` in both protocol lists, and Stop is stamped BEFORE the ideal moment is
//      cleared — so it can never arrive between pulses already scheduled ahead of it.
//
// ⚠️ HONEST GRADING (#433). `MIDIClockSchedule` and the stamp are created by this commit: the
// file does not compile on the parent (one absence, #486); every claim FORWARD. Golden values
// derived in Python (`(ns // n) * d + (ns % n) * d // n`).
//
// ⚠️ THE LIMIT. Whether the H90's tempo readout stays steady while a menu is open is a DEVICE
// PROBE (NEEDS-FOUNDER-VERIFY: Routing → MIDI out on, H90 on MIDI clock, Play at 126 BPM, open the
// genre menu and hold it — the H90 tempo must not wobble). A timer fire later than the lookahead
// still leaves late, exactly as before.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheClockLeavesOnHostTimeTests: XCTestCase {

    // MARK: 1 — the arithmetic

    func testHostTicksAndLookaheadHaveTheirGoldenValues() {
        XCTAssertEqual(MIDIClockSchedule.hostTicks(nanoseconds: 1_000_000_000, numer: 125, denom: 3), 24_000_000)
        XCTAssertEqual(MIDIClockSchedule.hostTicks(nanoseconds: 123_456_789, numer: 125, denom: 3), 2_962_962,
                       "the exact floor of ns × 3 / 125")
        XCTAssertEqual(MIDIClockSchedule.hostTicks(nanoseconds: 1 << 63, numer: 125, denom: 3), 221_360_928_884_514_619,
                       "no overflow at any uptime")
        XCTAssertEqual(MIDIClockSchedule.hostTicks(nanoseconds: 7, numer: 1, denom: 1), 7, "an Intel 1/1 timebase is the identity")
        XCTAssertEqual(MIDIClockSchedule.hostTicks(nanoseconds: 7, numer: 0, denom: 3), 7, "a broken timebase does not divide by zero")

        XCTAssertEqual(MIDIClockSchedule.lookahead(outputLatency: 0.005, ioBufferDuration: 0.0106667), 0.0156667, accuracy: 1e-9)
        XCTAssertEqual(MIDIClockSchedule.lookahead(outputLatency: 1, ioBufferDuration: 1), 0.050, "held under 50 ms")
        XCTAssertEqual(MIDIClockSchedule.lookahead(outputLatency: 0.0001, ioBufferDuration: 0), 0.002, "never below 2 ms")
        XCTAssertEqual(MIDIClockSchedule.lookahead(outputLatency: .nan, ioBufferDuration: 0.01),
                       MIDIClockSchedule.fallbackLookahead, "a non-finite report falls back")
        XCTAssertEqual(MIDIClockSchedule.lookahead(outputLatency: 0, ioBufferDuration: 0),
                       MIDIClockSchedule.fallbackLookahead, "no route yet falls back")
        XCTAssertTrue(MIDIClockSchedule.lookaheadRange.contains(MIDIClockSchedule.fallbackLookahead))

        XCTAssertEqual(MIDIClockSchedule.arrivalNanoseconds(idealNanoseconds: 1_000, lookahead: 0.012), 12_001_000)
        XCTAssertEqual(MIDIClockSchedule.arrivalNanoseconds(idealNanoseconds: 0, lookahead: .infinity),
                       UInt64(MIDIClockSchedule.fallbackLookahead * 1_000_000_000), "an infinite lookahead is not a stamp")
    }

    // MARK: 2 — the wiring

    func testEveryPulseCarriesItsStampAndStopFollowsThem() throws {
        let out = try code("Sources/Echoelmusic/Audio/MIDIOutput.swift")
        let arm = try body(of: "private func armClockTimer(interval: Double, firstAfter: Double) {", in: out)
        XCTAssertTrue(arm.contains("idealPulseNs = deadline.uptimeNanoseconds"), "the timer's deadline is the first ideal moment")
        let emit = try body(of: "private func emitPulse() {", in: out)
        XCTAssertTrue(emit.contains("let stamp = pulseStamp()"))
        XCTAssertTrue(emit.contains("sendRealTime(.start, at: stamp)"), "Start lands on the first pulse's moment")
        XCTAssertTrue(emit.contains("sendRealTime(.clock, at: stamp)"))
        XCTAssertTrue(emit.contains("idealPulseNs = ideal &+ pulseSpacingNs"), "each pulse advances the ideal moment")
        let stamp = try body(of: "private func pulseStamp() -> UInt64 {", in: out)
        XCTAssertTrue(stamp.contains("MIDIClockSchedule.arrivalNanoseconds(idealNanoseconds: ideal, lookahead: clockLookahead)"))
        XCTAssertTrue(stamp.contains("MIDIClockSchedule.hostTicks(nanoseconds: arrival"))
        let send = try body(of: "private func sendSystemWord(_ systemWord: UInt32, at time: UInt64) {", in: out)
        XCTAssertEqual(send.components(separatedBy: ", time, 1, &word)").count - 1, 2,
                       "both protocol lists carry the stamp")
        XCTAssertFalse(send.contains(", 0, 1, &word)"), "no list is stamped 'now' any more")
        let stop = try body(of: "public func stopClock() {", in: out)
        guard let stamped = stop.range(of: "let stopStamp = pulseStamp()"),
              let cleared = stop.range(of: "idealPulseNs = nil") else {
            return XCTFail("ANCHOR MISSING: Stop's stamp or the clear of the ideal moment")
        }
        XCTAssertLessThan(stamped.lowerBound, cleared.lowerBound, "Stop is stamped before the ideal moment is cleared")
        XCTAssertTrue(stop.contains("sendRealTime(.stop, at: stopStamp)"))
        let start = try body(of: "public func startClock(bpm: Double, startingIn delay: TimeInterval = 0, fromSixteenth: Int) {", in: out)
        XCTAssertTrue(start.contains("clockLookahead = Self.sessionLookahead()"), "the lookahead is read on every start")
    }

    // MARK: 3 — HW-2: a piece started past bar 1 says where

    func testTheSongPositionHasItsGoldenWords() {
        XCTAssertEqual(UMPEncoder.songPosition(sixteenths: 80), 0x10F2_5000, "bar 6 = 80 sixteenths, LSB first")
        XCTAssertEqual(UMPEncoder.songPosition(sixteenths: 200, group: 3), 0x13F2_4801, "the group nibble and a two-byte position")
        XCTAssertEqual(UMPEncoder.songPosition(sixteenths: 0x3FFF), 0x10F2_7F7F, "the 14-bit maximum")
        XCTAssertEqual(UMPEncoder.songPosition(sixteenths: 99_999), 0x10F2_7F7F, "clamped above")
        XCTAssertEqual(UMPEncoder.songPosition(sixteenths: -5), 0x10F2_0000, "clamped below")

        XCTAssertEqual(MIDIClockSchedule.songPositionSixteenths(forTick: 0), 0)
        XCTAssertEqual(MIDIClockSchedule.songPositionSixteenths(forTick: 4 * TimelineTime.ticksPerBar), 64, "bar 5")
        XCTAssertEqual(MIDIClockSchedule.songPositionSixteenths(forTick: TimelineTime.ticksPerTransportStep + 1), 1,
                       "between two sixteenths, the one before")
        XCTAssertNil(MIDIClockSchedule.songPositionSixteenths(forTick: -1))
        XCTAssertEqual(MIDIClockSchedule.songPositionSixteenths(forTick: 0x3FFF * TimelineTime.ticksPerTransportStep), 0x3FFF)
        XCTAssertNil(MIDIClockSchedule.songPositionSixteenths(forTick: 0x4000 * TimelineTime.ticksPerTransportStep),
                     "past 1024 bars the pointer cannot say it — no clock rather than a wrong one")
    }

    // MARK: helpers

    private func code(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 where !FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relativePath) not on disk — this run has no source tree")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }

    /// The brace-matched body after `signature` (#408), which must occur exactly once.
    private func body(of signature: String, in text: String) throws -> String {
        XCTAssertEqual(text.components(separatedBy: signature).count - 1, 1, "`\(signature)` must occur exactly once")
        guard let head = text.range(of: signature) else {
            throw XCTSkip("ANCHOR MISSING: \(signature)")
        }
        var depth = 1
        var i = head.upperBound
        while i < text.endIndex {
            if text[i] == "{" { depth += 1 }
            if text[i] == "}" { depth -= 1; if depth == 0 { return String(text[head.upperBound..<i]) } }
            i = text.index(after: i)
        }
        throw XCTSkip("no closing brace after \(signature)")
    }
}

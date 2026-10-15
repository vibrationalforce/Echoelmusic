// MIDIClockSchedule.swift
// Echoel — HW-1 (founder 2026-10-15: Xone:96 live set, Eventide H90 delays synced to the iPhone's
// MIDI clock). Pure arithmetic for WHEN a clock pulse leaves the phone.
//
// Until HW-1 every pulse went out with timestamp 0 ("send now") from a main-queue timer, so its
// jitter was the main thread's latency — a menu opening, a view rebuilding — and it left the
// phone one output latency BEFORE the matching sound did. Now each pulse carries a host-time stamp
// in the near future: its ideal moment plus the session's output latency. CoreMIDI holds it and
// delivers on time, so a late timer fire up to that lookahead costs nothing, and the clock lines up
// with what comes out of the mixer rather than with what the engine computed.
//
// ⚠️ A fire later than the lookahead still goes out late (the stamp is then in the past and
// CoreMIDI sends at once) — the same as before, never worse.

import Foundation

enum MIDIClockSchedule {

    /// The lookahead is the session's output path, held to a sane window: never 0 (no jitter
    /// absorbed at all), never more than 50 ms (a receiver that also listens to audio would hear
    /// the clock lag).
    static let lookaheadRange: ClosedRange<Double> = 0.002...0.050
    /// Used when the session reports nothing usable (no route yet, a non-finite value).
    static let fallbackLookahead: Double = 0.012

    /// Seconds between a pulse's ideal moment and when it should arrive: the session's output
    /// latency plus one IO buffer, clamped to `lookaheadRange`.
    static func lookahead(outputLatency: Double, ioBufferDuration: Double) -> Double {
        let sum = outputLatency + ioBufferDuration
        guard sum.isFinite, sum > 0 else { return fallbackLookahead }
        return Swift.min(Swift.max(sum, lookaheadRange.lowerBound), lookaheadRange.upperBound)
    }

    /// Nanoseconds → host ticks (`mach_absolute_time` units, what `MIDITimeStamp` counts) for a
    /// timebase `numer/denom` (ticks × numer / denom = ns). Exact integer arithmetic, no overflow
    /// for any uptime: the quotient and the remainder are scaled separately.
    static func hostTicks(nanoseconds: UInt64, numer: UInt32, denom: UInt32) -> UInt64 {
        guard numer > 0, denom > 0 else { return nanoseconds }
        let n = UInt64(numer), d = UInt64(denom)
        return (nanoseconds / n) * d + (nanoseconds % n) * d / n
    }

    /// HW-2 — the Song Position Pointer for a piece that starts at `tick`: whole sixteenths since
    /// bar 1. nil when the position cannot be said — before the start, or past the 14-bit range
    /// (1024 bars of 4/4) — in which case no clock is better than a wrong one. A start between
    /// two sixteenths reports the one before it.
    static func songPositionSixteenths(forTick tick: Int) -> Int? {
        let step = TimelineTime.ticksPerTransportStep
        guard tick >= 0, step > 0 else { return nil }
        let sixteenths = tick / step
        return sixteenths <= 0x3FFF ? sixteenths : nil
    }

    /// The moment, in uptime nanoseconds, a pulse due at `idealNanoseconds` should arrive.
    static func arrivalNanoseconds(idealNanoseconds: UInt64, lookahead: Double) -> UInt64 {
        let clamped = Swift.min(Swift.max(lookahead.isFinite ? lookahead : fallbackLookahead,
                                          lookaheadRange.lowerBound), lookaheadRange.upperBound)
        return idealNanoseconds &+ UInt64((clamped * 1_000_000_000).rounded())
    }
}

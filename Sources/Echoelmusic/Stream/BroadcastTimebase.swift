//
//  BroadcastTimebase.swift
//  Echoelmusic — Stream
//
//  THE ONE CLOCK sound and picture share on the way to a stream encoder: the host clock
//  (mach ticks). Pure arithmetic, no AVFoundation, so every rule here is testable on its own.
//
//  WHY A SHARED START AND NOT JUST SHARED TIMESTAMPS. An RTMP stream carries two tracks, and
//  each track's message timestamps count from ITS OWN first message (HaishinKit 2.2.5,
//  `RTMPTimestamp.update`: `startedAt` is set per track by the first sample it sees). Two
//  tracks stamped on the same clock but STARTED 120 ms apart therefore play 120 ms apart at
//  the viewer, for the whole stream. So both media are gated on one start instant `T0`:
//  the first audio frame sent is the ring frame rendered at `T0`, and the first picture sent
//  carries `T0` as its stamp. After that each track advances on its own real time.
//
//  ⚠️ WHAT THIS DOES NOT CLAIM. The audio encoder advances by SAMPLE COUNT after its first
//  buffer (HaishinKit `AudioTime.anchor`), the picture by host time. Both clocks come from
//  the same device; their drift over a long stream is not measured here (NEEDS-FOUNDER-VERIFY
//  on a one-hour stream against a receiver). A gap in the audio would skew the two, which is
//  why `BroadcastMasterPump` fills an overrun with silence instead of skipping it.
//

import Foundation

/// Converts between host ticks and seconds. `ticksPerSecond` comes from `mach_timebase_info`
/// on device; tests construct their own.
struct BroadcastTimebase: Sendable, Equatable {
    let ticksPerSecond: Double

    init(ticksPerSecond: Double) {
        self.ticksPerSecond = (ticksPerSecond.isFinite && ticksPerSecond > 0) ? ticksPerSecond : 1e9
    }

    /// The device's host clock. On Apple silicon one tick is 125/3 ns; never assume 1 ns.
    static let host: BroadcastTimebase = {
        var info = mach_timebase_info_data_t()
        guard mach_timebase_info(&info) == KERN_SUCCESS, info.numer > 0, info.denom > 0 else {
            return BroadcastTimebase(ticksPerSecond: 1e9)
        }
        // ticks × numer / denom = nanoseconds  ⇒  ticks per second = 1e9 × denom / numer
        return BroadcastTimebase(ticksPerSecond: 1e9 * Double(info.denom) / Double(info.numer))
    }()

    func seconds(ticks: UInt64) -> Double { Double(ticks) / ticksPerSecond }

    func ticks(seconds: Double) -> UInt64 {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        let t = seconds * ticksPerSecond
        return t < Double(UInt64.max) ? UInt64(t) : UInt64.max
    }
}

/// "Frame `frame` of the master ring was rendered at host time `hostTicks`, at `sampleRate`."
/// Written by the master tap (`RetroCapture`) once per buffer; read by the broadcast pump.
struct BroadcastAudioAnchor: Sendable, Equatable {
    let frame: Int64
    let hostTicks: UInt64
    let sampleRate: Double

    var isUsable: Bool { sampleRate.isFinite && sampleRate > 0 && hostTicks > 0 && frame >= 0 }

    /// Host time at which ring frame `f` was rendered. Frames BEFORE the anchor are allowed —
    /// the ring holds 30 s of history behind the newest anchor.
    func hostTicks(forFrame f: Int64, timebase: BroadcastTimebase) -> UInt64? {
        guard isUsable else { return nil }
        let deltaSeconds = Double(f - frame) / sampleRate
        let deltaTicks = deltaSeconds * timebase.ticksPerSecond
        let result = Double(hostTicks) + deltaTicks
        guard result.isFinite, result > 0, result < Double(UInt64.max) else { return nil }
        return UInt64(result)
    }

    /// The ring frame rendered at host time `t` (rounded UP, so the frame returned is never
    /// earlier than `t` — the start gate must not send audio from before the picture's `T0`).
    func frame(atHostTicks t: UInt64, timebase: BroadcastTimebase) -> Int64? {
        guard isUsable else { return nil }
        let deltaSeconds = (Double(t) - Double(hostTicks)) / timebase.ticksPerSecond
        let deltaFrames = (deltaSeconds * sampleRate).rounded(.up)
        guard deltaFrames.isFinite, abs(deltaFrames) < 1e15 else { return nil }
        return frame + Int64(deltaFrames)
    }
}

/// The shared start instant for both tracks.
enum BroadcastStartGate {

    /// How far in the future `T0` is placed when going live. The ring already holds audio up
    /// to "now"; placing `T0` slightly ahead means the first audio frame and the first picture
    /// are both produced AFTER the decision, so neither track starts on stale material.
    static let leadSeconds: Double = 0.1

    static func startTicks(now: UInt64, timebase: BroadcastTimebase) -> UInt64 {
        now &+ timebase.ticks(seconds: leadSeconds)
    }

    /// First ring frame to send, or nil until the master tap has written a usable anchor.
    static func firstAudioFrame(anchor: BroadcastAudioAnchor?, startTicks: UInt64,
                                timebase: BroadcastTimebase) -> Int64? {
        guard let anchor else { return nil }
        return anchor.frame(atHostTicks: startTicks, timebase: timebase)
    }

    /// The stamp a picture is sent with. A picture rendered before `T0` is not sent at all; the
    /// FIRST picture at or after `T0` is stamped exactly `T0`, so the picture track's zero is
    /// the audio track's zero (see the file header).
    static func videoStamp(renderedAt stamp: UInt64, startTicks: UInt64, isFirst: Bool) -> UInt64? {
        guard stamp >= startTicks else { return nil }
        return isFirst ? startTicks : stamp
    }
}

/// One consistent look at the master ring (`RetroCapture.masterRingView()`): the absolute frame
/// the tap has written up to, the ring's size in frames, and the newest host-time anchor.
struct MasterRingView: Sendable, Equatable {
    let writeFrame: Int64
    let capacity: Int
    let anchor: BroadcastAudioAnchor?
}

/// Where a live reader of the master ring should read next — pure, so the overrun rule is
/// testable without audio.
///
/// ⭐ AN OVERRUN BECOMES SILENCE, NEVER A JUMP. The audio encoder counts samples after its
/// first buffer (see the file header), so skipping frames would move the sound EARLIER than
/// the picture for the rest of the stream. When the reader has fallen too far behind, the
/// frames it can no longer read are replaced by the same number of zero frames: the gap is
/// audible as a dropout, the sync survives it.
enum MasterRingReadPlan: Equatable {
    /// Nothing new yet.
    case wait
    /// Read `count` frames starting at `from`.
    case read(from: Int64, count: Int)
    /// The frames `from ..< from+silence` are gone; send that many zero frames, then read on
    /// from `from + silence`.
    case silence(from: Int64, count: Int)

    /// Keep this much distance from the tap's write head when the reader falls behind, so the
    /// next read is not immediately overwritten again.
    static let safetyFraction: Double = 0.5

    static func next(readFrame: Int64, view: MasterRingView, maxChunk: Int) -> MasterRingReadPlan {
        guard maxChunk > 0, view.capacity > 0 else { return .wait }
        let available = view.writeFrame - readFrame
        if available <= 0 { return .wait }
        let limit = Int64(Double(view.capacity) * safetyFraction)
        if available > limit {
            // Fallen behind: everything older than (write − limit) is at risk. Silence it.
            let gap = available - limit
            return .silence(from: readFrame, count: Int(Swift.min(gap, Int64(maxChunk))))
        }
        return .read(from: readFrame, count: Int(Swift.min(available, Int64(maxChunk))))
    }
}

/// The size and rate the stream wants pictures at.
struct BroadcastVideoSpec: Sendable, Equatable {
    let width: Int
    let height: Int
    let framesPerSecond: Double

    static let standard = BroadcastVideoSpec(width: 1280, height: 720, framesPerSecond: 30)

    var isValid: Bool {
        width >= 16 && height >= 16 && width <= 3840 && height <= 2160
            && framesPerSecond.isFinite && framesPerSecond >= 1 && framesPerSecond <= 60
    }
}

// Ported from the earlier app (Sources/Echoelmusic/Bio/CameraRPPGBioPublisher.swift,
// `manageExposure` and its pure predicates) for Echoel Studio 1.0, wave W1 "body": the decision
// WHEN the camera's exposure is frozen on the fingertip and when it is handed back to auto, as a
// pure tick-driven machine so it is tested without a camera. Foundation only. The camera owner
// turns each `Action` into the AVFoundation calls.

import Foundation

/// The exposure-lock policy for finger-on-lens rPPG, stepped once per owner tick (~10 Hz).
///
/// Why it exists: locking exposure against the dim, finger-less scene froze a high-gain setting
/// that saturated the moment the finger arrived (red 0.82, no pulse all take); never locking let
/// the auto-gain write a slow ramp into the signal. So the lock waits for a finger that has covered
/// the lit lens for ~1.2 s with a DARK enough scene (strict 0.28 for the first ~6 s, since the
/// good takes all locked dark; permissive 0.6 after that), and it lets go again when the locked
/// scene washes out for ~2 s, when a bright lock shows a full window with no periodicity for ~12 s
/// (at most twice per placement), or when the finger has been gone for ~3 s. A lock that dies
/// within ~6 s was ambient flicker, not a hand: each such quick-fail stretches the stable time the
/// next lock must earn, so the lock–unlock oscillation extinguishes itself.
public struct RPPGExposureLock: Sendable, Equatable {

    /// What the owner feeds the machine each tick, from the analyzer's newest state.
    public struct Input: Sendable, Equatable {
        public var fingerDetected: Bool
        public var brightness: Float
        public var red: Float
        public var autoStrength: Float
        public var confidence: Float
        /// Whether the analyzer's window is essentially full (~140 of 150 samples): weakness is
        /// not diagnostic on a window still filling.
        public var windowFull: Bool
        /// Whether the pulse is trusted right now; a trusted lock is never disturbed.
        public var settled: Bool

        public init(fingerDetected: Bool, brightness: Float, red: Float, autoStrength: Float,
                    confidence: Float, windowFull: Bool, settled: Bool) {
            self.fingerDetected = fingerDetected
            self.brightness = brightness
            self.red = red
            self.autoStrength = autoStrength
            self.confidence = confidence
            self.windowFull = windowFull
            self.settled = settled
        }
    }

    /// How the analyzer's window is flushed with an unlock.
    public enum Flush: Sendable, Equatable {
        /// The window is too short to be worth refilling.
        case none
        /// The finger stayed on the lens through a re-settle: keep the rate, halve its confidence.
        case keepEstimate
        /// A new placement, or a signal that was never a pulse: forget the rate.
        case dropEstimate
    }

    /// What the owner does this tick.
    public enum Action: Sendable, Equatable {
        case none
        /// Freeze exposure (and white balance) on the current fingertip scene, re-assert the torch.
        case lock
        /// Hand exposure back to continuous auto, flushing the analyzer window as told.
        case unlock(flush: Flush)
        /// Budget spent and still dead: flush the analyzer window, forgetting the estimate; the
        /// exposure stays as it is.
        case flushWindow
    }

    public private(set) var isLocked = false
    private var fingerStableTicks = 0
    private var fingerPresentTicks = 0
    private var lockAgeTicks = 0
    private var quickFailLocks = 0
    private var saturatedTicks = 0
    private var fingerLostTicks = 0
    private var weakTicks = 0
    private var weakRelocksUsed = 0

    public init() {}

    // MARK: - Constants (ticks at the owner's ~10 Hz)

    /// Stable finger ticks before the first lock (~1.2 s).
    public static let lockAfterTicks = 12
    /// Saturated ticks before a locked scene is handed back to auto (~2 s).
    public static let resettleAfterTicks = 20
    /// Finger-less ticks before the lock is dropped for the next placement (~3 s).
    public static let relockOnLossTicks = 30
    /// A lock that loses its finger inside this many ticks (~6 s) was a phantom.
    public static let quickFailWindowTicks = 60
    /// Finger-present ticks during which only a dark lock is taken (~6 s).
    public static let strictLockWindowTicks = 60
    /// Weak-periodicity ticks on a full window before a bright lock is re-settled (~12 s).
    public static let weakRelockAfterTicks = 120
    /// Re-settles per placement.
    public static let maxWeakRelocks = 2
    /// Weak ticks after the re-settle budget is spent before the window is flushed (~30 s).
    public static let deadWindowFlushAfterTicks = 300
    /// Scene brightness a lock must stay under; healthy fingertip PPG sits at 0.1 … 0.4.
    public static let maxLockBrightness: Float = 0.6
    /// The dark ceiling of the first seconds: the good takes all locked here.
    public static let strictLockBrightness: Float = 0.28
    public static let weakRelockAcfFloor: Float = 0.2
    public static let weakRelockAcfStrong: Float = 0.4
    public static let weakRelockConfidenceFloor: Float = 0.35
    public static let weakRelockConfidenceStrong: Float = 0.6

    // MARK: - Steps

    /// One owner tick.
    public mutating func tick(_ input: Input) -> Action {
        let saturating = Self.isWashedOut(brightness: input.brightness, red: input.red)

        if !isLocked {
            fingerPresentTicks = input.fingerDetected ? fingerPresentTicks + 1 : 0
            let ceiling = Self.lockBrightnessCeiling(fingerPresentTicks: fingerPresentTicks)
            let eligible = Self.canLockNow(fingerDetected: input.fingerDetected, brightness: input.brightness)
                && input.brightness < ceiling
            fingerStableTicks = eligible ? fingerStableTicks + 1 : 0
            let needed = Self.requiredStableTicks(base: Self.lockAfterTicks, quickFails: quickFailLocks)
            guard fingerStableTicks >= needed else { return .none }
            isLocked = true
            saturatedTicks = 0
            fingerLostTicks = 0
            weakTicks = 0
            lockAgeTicks = 0
            return .lock
        }

        lockAgeTicks += 1
        // A lock that survives the phantom window proves a real placement: clear the backoff.
        if lockAgeTicks == Self.quickFailWindowTicks { quickFailLocks = 0 }

        if saturating {
            saturatedTicks += 1
            if saturatedTicks >= Self.resettleAfterTicks {
                isLocked = false
                lockAgeTicks = 0
                fingerStableTicks = 0
                saturatedTicks = 0
                // Only a full window is worth flushing: an unbudgeted flush of a short window
                // could pin it below "full" and make the weak-lock ladder unreachable.
                return .unlock(flush: input.windowFull ? .keepEstimate : .none)
            }
        } else {
            saturatedTicks = Swift.max(0, saturatedTicks - 1)
        }

        weakTicks = Self.weakTicksStep(current: weakTicks, windowFull: input.windowFull,
                                       acf: input.autoStrength, confidence: input.confidence,
                                       settled: input.settled)

        if Self.deadWindowNeedsFlush(weakTicks: weakTicks, relocksUsed: weakRelocksUsed) {
            weakTicks = 0
            return .flushWindow
        }

        if Self.weakLockNeedsResettle(weakTicks: weakTicks, relocksUsed: weakRelocksUsed) {
            weakRelocksUsed += 1
            isLocked = false
            lockAgeTicks = 0
            fingerStableTicks = 0
            fingerPresentTicks = 0   // restart the strict dark window — the point of the re-lock
            saturatedTicks = 0
            weakTicks = 0
            return .unlock(flush: .dropEstimate)
        }

        fingerLostTicks = input.fingerDetected ? 0 : fingerLostTicks + 1
        if fingerLostTicks >= Self.relockOnLossTicks {
            if lockAgeTicks < Self.quickFailWindowTicks {
                quickFailLocks += 1
            } else {
                quickFailLocks = 0
            }
            isLocked = false
            lockAgeTicks = 0
            fingerStableTicks = 0
            saturatedTicks = 0
            fingerLostTicks = 0
            fingerPresentTicks = 0
            weakTicks = 0
            weakRelocksUsed = 0   // a new placement earns a fresh re-lock budget
            return .unlock(flush: .dropEstimate)
        }
        return .none
    }

    /// The camera session was rebuilt or resumed under the owner: exposure is auto again, and a
    /// fresh session is a fresh phantom-backoff and re-lock budget.
    public mutating func sessionReset() {
        self = RPPGExposureLock()
    }

    /// A take boundary: everything forgotten.
    public mutating func reset() {
        self = RPPGExposureLock()
    }

    // MARK: - Pure predicates

    /// A tick counts toward a lock only with a finger present and a scene dark enough for PPG.
    public static func canLockNow(fingerDetected: Bool, brightness: Float) -> Bool {
        fingerDetected && brightness < maxLockBrightness
    }

    /// The brightness ceiling a lock must satisfy, given how long the finger has been present.
    public static func lockBrightnessCeiling(fingerPresentTicks: Int) -> Float {
        fingerPresentTicks < strictLockWindowTicks ? strictLockBrightness : maxLockBrightness
    }

    /// Stable ticks the next lock must earn: the base, plus one base step per consecutive
    /// quick-failed lock, capped at six times.
    public static func requiredStableTicks(base: Int, quickFails: Int) -> Int {
        base * (1 + Swift.min(Swift.max(quickFails, 0), 5))
    }

    /// One step of the weak-periodicity counter: nothing until the window is full, nothing on a
    /// trusted pulse; weakness is NO pulse evidence on either witness, and strong evidence on
    /// either pays the counter down twice as fast.
    public static func weakTicksStep(current: Int, windowFull: Bool, acf: Float, confidence: Float,
                                     settled: Bool) -> Int {
        guard windowFull, !settled else { return 0 }
        if acf >= weakRelockAcfStrong || confidence >= weakRelockConfidenceStrong {
            return Swift.max(0, current - 2)
        }
        if acf < weakRelockAcfFloor && confidence < weakRelockConfidenceFloor { return current + 1 }
        return current
    }

    /// Whether a locked-but-weak exposure should be handed back to auto.
    public static func weakLockNeedsResettle(weakTicks: Int, relocksUsed: Int) -> Bool {
        weakTicks >= weakRelockAfterTicks && relocksUsed < maxWeakRelocks
    }

    /// Whether an exhausted-budget lock has been dead long enough to flush the window. Mutually
    /// exclusive with `weakLockNeedsResettle` by construction.
    public static func deadWindowNeedsFlush(weakTicks: Int, relocksUsed: Int) -> Bool {
        relocksUsed >= maxWeakRelocks && weakTicks >= deadWindowFlushAfterTicks
    }

    /// A locked scene is washed out (the pulse swamped) once it drifts too bright or the red
    /// channel clips. The one definition of washout — the exposure and the on-screen cue read it.
    public static func isWashedOut(brightness: Float, red: Float) -> Bool {
        brightness > 0.72 || red > 0.92
    }
}

//
//  FaceExpressionMapping.swift
//  Echoelmusic — Core control-plane (pure value type)
//
//  Smooths normalized facial-EXPRESSION coefficients (smile, browRaise,
//  jawOpen ∈ [0..1]) into stable modulation channels.
//
//  IMPORTANT — legal + product framing (EU AI Act):
//  These coefficients are treated strictly as EXPRESSION / MOVEMENT used as a
//  CONTROL signal for the instrument — never as inferred "emotion" or an
//  affective state. A raised brow moves a parameter; it is NOT read as a
//  feeling. Keep all copy here and downstream on "Ausdruck/Bewegung als
//  Steuerung", never "Emotion".
//
//  Source-agnostic: the raw coefficients may come from ARKit face blendShapes
//  OR (later) a Vision fallback — this type never imports ARKit/AVFoundation/
//  Vision. It is a pure, deterministic Foundation value type, safe to evaluate
//  anywhere on the control plane.
//
//  Smoothing is a rate-based one-pole EMA driven by wall-clock `dt` (seconds),
//  NOT a frame count — so the response is identical regardless of the producer's
//  frame rate. A neutral face (all zeros) keeps every channel at 0.
//

import Foundation

/// Smoothed, clamped facial-expression control channels.
///
/// All three channels are normalized to [0..1]. The struct carries its own
/// smoothed state; `updated(...)` returns the next state and is a pure function
/// of the current state, the raw targets, and `dt`.
public struct FaceExpressionMapping: Sendable, Equatable {

    /// Default one-pole time constant in seconds. At this τ the channel reaches
    /// ~63 % of a step within one τ. Small enough to feel responsive, large
    /// enough to reject per-frame jitter from the tracker.
    public static let defaultTimeConstant: Double = 0.15

    /// Smile expression as a control value, [0..1]. Not an emotion reading.
    public private(set) var smile: Float

    /// Brow-raise expression as a control value, [0..1]. Not an emotion reading.
    public private(set) var browRaise: Float

    /// Jaw-open expression as a control value, [0..1]. Not an emotion reading.
    public private(set) var jawOpen: Float

    /// One-pole EMA time constant in seconds (≥ 0). 0 = no smoothing (instant).
    public let timeConstant: Double

    /// #1258 — DEADZONE WITH HYSTERESIS, per channel, BEFORE the EMA. A tracked, genuinely
    /// still face never reads an exact 0 from ARKit; it flickers a few hundredths, and a
    /// route on that channel turns the flicker into a parameter that never rests. Below
    /// `deadzone` a channel is 0. It becomes ACTIVE when the raw value exceeds `deadzone`
    /// and stays active until the raw value falls under half of it (the exit), so a value
    /// hovering at the threshold cannot chatter. While active the output is rescaled from
    /// the exit up to 1, so the usable range still starts at 0 rather than at a step.
    /// `0` disables the gate (the pure-EMA behaviour the 2026-07 tests pin).
    public let deadzone: Float
    /// The production gate: 0.06 of the ARKit range — measured on nothing yet (device ask
    /// in `FaceExpressionBioPublisher`), chosen as "clearly above tracker jitter, clearly
    /// below the smallest deliberate movement".
    public static let defaultDeadzone: Float = 0.06

    private var smileActive = false
    private var browActive = false
    private var jawActive = false

    public init(
        smile: Float = 0,
        browRaise: Float = 0,
        jawOpen: Float = 0,
        timeConstant: Double = FaceExpressionMapping.defaultTimeConstant,
        deadzone: Float = 0
    ) {
        self.smile = Self.clamp01(smile)
        self.browRaise = Self.clamp01(browRaise)
        self.jawOpen = Self.clamp01(jawOpen)
        self.timeConstant = Swift.max(0, timeConstant)
        self.deadzone = Swift.min(0.5, Self.clamp01(deadzone))
    }

    /// Returns the next state after advancing `dt` seconds toward the given raw
    /// targets. Deterministic and side-effect free.
    ///
    /// - `dt <= 0` returns an unchanged copy (no time elapsed).
    /// - Raw targets are clamped to [0..1] before smoothing.
    /// - Convergence is monotonic toward each (constant) target.
    public func updated(
        rawSmile: Float,
        rawBrowRaise: Float,
        rawJawOpen: Float,
        dt: Double
    ) -> FaceExpressionMapping {
        let alpha = Self.alpha(dt: dt, tau: timeConstant)
        var copy = self
        let s = Self.gate(Self.clamp01(rawSmile), active: &copy.smileActive, deadzone: deadzone)
        let b = Self.gate(Self.clamp01(rawBrowRaise), active: &copy.browActive, deadzone: deadzone)
        let j = Self.gate(Self.clamp01(rawJawOpen), active: &copy.jawActive, deadzone: deadzone)
        copy.smile = Self.ema(current: smile, target: s, alpha: alpha)
        copy.browRaise = Self.ema(current: browRaise, target: b, alpha: alpha)
        copy.jawOpen = Self.ema(current: jawOpen, target: j, alpha: alpha)
        return copy
    }

    /// The deadzone-with-hysteresis gate (see `deadzone`). Pure apart from the `active`
    /// flag it carries between calls. `deadzone <= 0` passes the value through.
    static func gate(_ raw: Float, active: inout Bool, deadzone: Float) -> Float {
        guard deadzone > 0 else { return raw }
        let exit = deadzone * 0.5
        if active {
            if raw < exit { active = false }
        } else if raw > deadzone {
            active = true
        }
        guard active else { return 0 }
        return clamp01((raw - exit) / (1 - exit))
    }

    // MARK: - Pure helpers

    /// One-pole smoothing coefficient for elapsed `dt` and time constant `tau`.
    /// `alpha = 1 - exp(-dt / tau)`, in [0..1]. `dt <= 0` → 0 (hold);
    /// `tau <= 0` → 1 (instant).
    static func alpha(dt: Double, tau: Double) -> Float {
        guard dt > 0 else { return 0 }
        guard tau > 0 else { return 1 }
        let a = 1 - exp(-dt / tau)
        if a.isNaN { return 0 }
        return Float(Swift.min(1, Swift.max(0, a)))
    }

    /// One EMA step: `current + alpha * (target - current)`, clamped to [0..1].
    static func ema(current: Float, target: Float, alpha: Float) -> Float {
        clamp01(current + alpha * (target - current))
    }

    static func clamp01(_ v: Float) -> Float {
        if v.isNaN { return 0 }
        return Swift.min(1, Swift.max(0, v))
    }

    // MARK: - ARKit blendShape → channel mapping (pure, ARKit-free)

    /// The ARKit `ARFaceAnchor.BlendShapeLocation` raw keys we read. Kept as plain
    /// strings so this Core type never imports ARKit — the device-side publisher
    /// builds a `[String: Float]` from the anchor and calls `rawChannels(from:)`.
    /// ARKit blendShape coefficients are already normalized to [0..1].
    public enum BlendShapeKey {
        public static let mouthSmileLeft = "mouthSmileLeft"
        public static let mouthSmileRight = "mouthSmileRight"
        public static let browInnerUp = "browInnerUp"
        public static let browOuterUpLeft = "browOuterUpLeft"
        public static let browOuterUpRight = "browOuterUpRight"
        public static let jawOpen = "jawOpen"
    }

    /// Reduces a bag of ARKit blendShape coefficients to the three EXPRESSION
    /// control channels. Pure, deterministic, ARKit-free — the raw feed for
    /// `updated(rawSmile:rawBrowRaise:rawJawOpen:dt:)`.
    ///
    /// - smile = mean(mouthSmileLeft, mouthSmileRight) — symmetric mouth corners.
    /// - browRaise = mean(browInnerUp, browOuterUpLeft, browOuterUpRight) — the
    ///   whole brow lifting, center + both outer edges.
    /// - jawOpen = jawOpen — the mouth opening directly.
    ///
    /// Missing keys count as `0` (that muscle simply not tracked / at rest); every
    /// output is clamped to [0..1]. A neutral / empty bag yields all zeros, so a
    /// lost face reads as "no expression", never a spike.
    public static func rawChannels(
        from blendShapes: [String: Float]
    ) -> (smile: Float, browRaise: Float, jawOpen: Float) {
        func value(_ key: String) -> Float { clamp01(blendShapes[key] ?? 0) }
        let smile = (value(BlendShapeKey.mouthSmileLeft)
                     + value(BlendShapeKey.mouthSmileRight)) / 2
        let brow = (value(BlendShapeKey.browInnerUp)
                    + value(BlendShapeKey.browOuterUpLeft)
                    + value(BlendShapeKey.browOuterUpRight)) / 3
        let jaw = value(BlendShapeKey.jawOpen)
        return (clamp01(smile), clamp01(brow), clamp01(jaw))
    }
}

// MARK: - Calibration (#1258)

/// Per-channel NEUTRAL baseline from a short hold of a still face, applied to the raw
/// ARKit channels before the deadzone and the EMA. Without it the channels differ per
/// person and per lighting: one performer's resting mouth reads 0.15 smile, another's 0.
/// `identity` (all baselines 0) is the un-calibrated state and maps raw to raw.
///
/// Span is `1 − baseline`, floored at `minimumSpan`: a full ARKit excursion still reaches
/// 1, and a baseline that is somehow near 1 (a tracker fault) cannot divide by ~0. Only
/// the neutral hold is asked for — asking for "your biggest expression" as well would be
/// a second instruction for a gain the deadzone and route depth already provide.
public struct FaceCalibration: Sendable, Equatable, Codable {
    public var smileBaseline: Float
    public var browBaseline: Float
    public var jawBaseline: Float

    public static let identity = FaceCalibration(smileBaseline: 0, browBaseline: 0, jawBaseline: 0)
    public static let minimumSpan: Float = 0.2
    /// The `UserDefaults` key the publisher persists under (JSON of this struct).
    public static let defaultsKey = "face.calibration"

    public init(smileBaseline: Float, browBaseline: Float, jawBaseline: Float) {
        self.smileBaseline = FaceExpressionMapping.clamp01(smileBaseline)
        self.browBaseline = FaceExpressionMapping.clamp01(browBaseline)
        self.jawBaseline = FaceExpressionMapping.clamp01(jawBaseline)
    }

    public var isIdentity: Bool { self == .identity }

    /// Raw → calibrated, each channel `(raw − baseline) / span`, clamped to [0..1].
    public func apply(smile: Float, browRaise: Float, jawOpen: Float)
        -> (smile: Float, browRaise: Float, jawOpen: Float) {
        (Self.rescale(smile, baseline: smileBaseline),
         Self.rescale(browRaise, baseline: browBaseline),
         Self.rescale(jawOpen, baseline: jawBaseline))
    }

    static func rescale(_ raw: Float, baseline: Float) -> Float {
        let b = FaceExpressionMapping.clamp01(baseline)
        let span = Swift.max(minimumSpan, 1 - b)
        return FaceExpressionMapping.clamp01((FaceExpressionMapping.clamp01(raw) - b) / span)
    }

    /// Baselines = the MEAN of the samples collected while the face was held still. An
    /// empty channel keeps baseline 0 (identity on that channel), so a hold that produced
    /// no frames — face left the picture — cannot write a calibration from nothing.
    public static func fromNeutral(smile: [Float], browRaise: [Float], jawOpen: [Float]) -> FaceCalibration {
        func mean(_ xs: [Float]) -> Float {
            let finite = xs.filter { $0.isFinite }
            guard !finite.isEmpty else { return 0 }
            return finite.reduce(0, +) / Float(finite.count)
        }
        return FaceCalibration(smileBaseline: mean(smile), browBaseline: mean(browRaise), jawBaseline: mean(jawOpen))
    }
}

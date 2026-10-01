// VisualCreativeState.swift
// Echoel — Workstation redesign C1 (2026-10-01): the creative VISUAL level, as a canonical parameter.
//
// ⭐ WHAT THIS IS. One creative scalar ABOVE the picture the renderer already makes: the draw
// loop multiplies the look intensity its mount hands it (the `visual.intensity` setting after
// the shared weather mix, `WeatherMood.visualValues`) by `intensity` here. It is the visual twin
// of `LightingStore.lookIntensity` (P2 Proof #1) and keeps its three rules:
//   · IDENTITY IS 1. `x * 1` is exact in IEEE-754, so at the default the uniforms stay
//     byte-identical and the #1244 unchanged-frame skip still holds.
//   · ATTENUATE ONLY. 0…1, clamped HERE — the router's `applyReal` bypasses the descriptor
//     range on purpose, so the owner clamps. A non-finite input is the identity, never a NaN
//     in a uniform.
//   · NO WRITER CONFLICT. This parameter never writes `visual.intensity`; that setting keeps
//     exactly the writers it had (the Visual panel's Intensity field, the look presets, the mood
//     pad, a media seed). This is a SECOND factor with ONE writer of its own (the router
//     binding), so a curve and a finger never fight over one stored number.
//
// ⭐ NOT `@Observable`, NOT `@AppStorage`, NOT PERSISTED. The reader is the 60 fps draw loop,
// off the SwiftUI graph — the `TouchVisualEnergy` / `AudioFeatureChannel` shape. An automation
// curve would write this at transport rate; an observable store would carry that rate into
// every body that read it (the 10.76.41/50 law), and `@AppStorage` would turn a performance
// value into a setting that survives a relaunch. It is process state and starts at 1.
//
// ⚠️ NO PRODUCTION WRITER YET, ON PURPOSE. `VisualParameterCatalog` denies automation AND
// modulation, so only a direct router dispatch reaches `setIntensity`, and nothing in the app
// makes one. C1 is the PATH, not the capability: the picture is unchanged. C2 flips
// `automationEligible` together with its editor, never before.
//
// ⭐ FLASH LAW (WCAG 2.3.1, ≤ 3 Hz). The renderer does not jump to a new value; it SLEWS toward
// it at `maxIntensityChangePerSecond` = `FlashGuard.luminanceDeltaThreshold ×
// FlashGuard.maxFlashHz` (0.10 × 3 = 0.30 per second). A 3 Hz square wave has a half-cycle of
// 1/6 s, so THIS FACTOR moves at most 0.05 inside one — the guaranteed layer, and the one the
// guard pins. ⚠️ It is not by itself the bound on the PICTURE: the gain stages after it
// (`lookIntensity` ≤ 1.5, `1 + 0.45·liveE + 0.30·musicLevel` ≤ 1.75, `1 + 0.5·autoTerm` ≈ 1.075)
// can multiply it by up to ~2.8 below the uniform's 1.5 clamp, so the intensity TARGET can move
// ~0.14 per half-cycle; the renderer's intensity easing (τ 0.4 s) then passes about 21 % of a
// 3 Hz swing (`FlashGuard.squareWaveSurvival(hz: 3, tau: 0.4)`), leaving ≲ 0.03. NEITHER layer
// carries the argument alone — the easing alone passes ~20 % of a full step, the slew alone
// leaves the gain. And the uniform is not relative luminance: whether 0.30/s is also
// photometrically comfortable on a phone at full brightness is a device question.

import Foundation

@MainActor
public final class VisualCreativeState {

    /// The one instance. A singleton rather than an app-owned store because the reader is a
    /// Metal renderer with no environment, and every `MetalBioView` mount (the floating window
    /// and the external screen) must show the same level — the `TouchVisualEnergy.shared` shape.
    public static let shared = VisualCreativeState()

    /// The creative visual level, 0…1. 1 = the picture exactly as the look settings make it.
    public private(set) var intensity: Float = VisualCreativeState.defaultIntensity

    /// The identity. ONE literal: the stored default above, the non-finite fallback below and
    /// the descriptor default in `VisualParameterCatalog` all read it (#416).
    public nonisolated static let defaultIntensity: Float = 1

    /// The slew ceiling, derived from the flash law rather than chosen (see the header).
    public nonisolated static let maxIntensityChangePerSecond: Double =
        FlashGuard.luminanceDeltaThreshold * FlashGuard.maxFlashHz

    public init() {}

    /// The router's setter. Clamps 0…1; a non-finite value is the identity.
    public func setIntensity(_ value: Float) {
        intensity = VisualCreativeState.sanitizedIntensity(value)
    }

    /// 0…1, non-finite → identity. NaN-safe by the guard, not by `min`/`max` argument order.
    public nonisolated static func sanitizedIntensity(_ value: Float) -> Float {
        guard value.isFinite else { return defaultIntensity }
        return Swift.min(Swift.max(value, 0), 1)
    }

    /// One frame of the slew: `current` moves toward `target` by at most
    /// `maxIntensityChangePerSecond × dt`. The dt rule (capped at 1 s, 0.1 s when not finite or
    /// not positive) is `FlashGuard.maxDelta`'s, not a second one. A non-finite `current` has
    /// nothing to slew from and lands on the target.
    public nonisolated static func slewedIntensity(from current: Float, toward target: Float,
                                                   dt: Double) -> Float {
        let goal = sanitizedIntensity(target)
        guard current.isFinite else { return goal }
        let step = FlashGuard.maxDelta(perSecond: maxIntensityChangePerSecond, dt: dt)
        return Float(FlashGuard.limitedLuminance(from: Double(sanitizedIntensity(current)),
                                                 to: Double(goal), maxDelta: step))
    }
}

//
//  LightingStore.swift
//  Echoelmusic — Core (creative lighting state)
//
//  FOUNDER DECISION 2026-09-22 — "Lighting Creative State": Echoelmusic owns
//  protocol-independent creative lighting state. Lighting is no longer permanently
//  limited to a stateless projection of bio/music.
//
//  ⭐ WHY THIS TYPE EXISTS, and why it is NOT the Grand Master. Until this slice the
//  lighting chain had exactly two stored values, and BOTH of them belong to the operator:
//  `grandMaster` (the desk's first fader) and `blackout` (the safety cut). Everything else
//  was recomputed per tick from a `BioSampleFrame` or a `MusicalFrame` — a pure projection
//  with nothing a composition could own. This is the missing third thing: the CREATIVE level
//  of the look Echoelmusic generates, before any operator or safety stage touches it.
//
//  THE THREE CONCEPTS, kept apart on purpose (they were measured as one gap):
//    · Look Intensity (here) — part of the composition/performance. May be automated,
//      modulated, saved and recalled.
//    · Grand Master (`ArtNetSender`/`SACNSender`) — the live operator's control over the
//      FINISHED output. Must never be raised by bio or automation. Not persisted.
//    · Blackout — absolute show/safety control. Always wins.
//
//  THE ORDER, and nothing may reorder it:
//
//      bio / music  →  generated target        (existing mapping, unchanged)
//                   →  × lookIntensity         (THIS TYPE)
//                   →  operator grandMaster
//                   →  blackout
//                   →  FlashGuard slew
//                   →  Art-Net / sACN packet
//
//  ⚠️ NO WRITER CONFLICT, and that is the whole point of the shape. The per-tick generator
//  keeps producing `generatedTarget`; this value is a SEPARATE creative scalar that scales
//  it. Making the generated target itself settable would have given it two writers — the
//  generator every tick and a route whenever it moves — racing last-writer-wins. That was
//  measured and rejected before this file existed.
//
//  ⚠️ PROTOCOL-INDEPENDENT BY CONSTRUCTION: Foundation only. No `Network` import, no packet
//  knowledge, no Art-Net or sACN type. Both senders READ it; neither owns it. A future
//  adapter (or a renderer) reads the same value. `TheLightingLookIntensityIsOwnedAboveTheSendersTests`
//  pins that.
//
//  ⚠️ THIS SLICE IS OWNERSHIP ONLY. No `ParameterDescriptor`, no registry registration, no
//  modulation destination, no UI, no persistence. `lighting.look.intensity` becomes the P2
//  parameter in a LATER slice, and the setter below is already written for it — see
//  `setLookIntensity`.
//

import Foundation
import Observation

/// The creative lighting state Echoelmusic owns, above both transport adapters.
///
/// One instance per running session (`EchoelmusicApp`), `@MainActor` control plane — nothing
/// here is reachable from an audio render block or a DSP kernel.
@MainActor
@Observable
public final class LightingStore {

    /// Creative intensity of the generated lighting look, 0…1, applied BEFORE the operator
    /// master and before any safety stage.
    ///
    /// **1.0 is the identity and the default**, so a build with this type behaves exactly as
    /// the build before it did: `creativeTarget(g, lookIntensity: 1) == g` for every `g`.
    ///
    /// `private(set)` with a clamping setter rather than a plain `var`, deliberately: when
    /// this becomes the P2 parameter `lighting.look.intensity`, `ParameterApplyRouter.applyReal`
    /// BYPASSES the descriptor's range clamp, so the range has to be enforced by the owner or
    /// not at all — and this value reaches a physical fixture.
    public private(set) var lookIntensity: Float = Self.defaultLookIntensity

    /// The identity value. Named rather than repeated as a literal, because three places
    /// (the property, the NaN fallback, the future descriptor default) must agree (#416).
    ///
    /// ⚠️ `nonisolated` although the class is `@MainActor`: Xcode's toolchain isolates a
    /// `static let` on a `@MainActor` type even when it is immutable, and SwiftPM's does not
    /// (the two disagree on SE-0434 inference, recorded in CLAUDE.md's build-error table).
    /// The three pure members here carry no state, so isolating them buys nothing and costs a
    /// compile error in exactly one of the two gates. `PolySynthVoice.automatableBases` is
    /// marked the same way for the same reason.
    public nonisolated static let defaultLookIntensity: Float = 1

    public init() {}

    /// Set the creative look intensity. Out-of-range input clamps to 0…1; a non-finite input
    /// falls back to the identity (see `creativeTarget` for why that direction).
    public func setLookIntensity(_ value: Float) {
        lookIntensity = Self.sanitizedLookIntensity(value)
    }

    // MARK: - Pure kernel (no state, no socket, unit-testable)

    /// The creative stage of the lighting chain: scale the generated target by the creative
    /// look level. Pure, so both senders apply the identical arithmetic and neither owns it.
    ///
    /// - Parameters:
    ///   - generated: the existing bio/music mapping's 0…1 luminance target, UNCHANGED.
    ///   - lookIntensity: the creative level; 1 is the identity.
    /// - Returns: `generated × lookIntensity`, clamped to 0…1.
    ///
    /// ⚠️ **IT CAN ONLY ATTENUATE.** Both factors are clamped into 0…1, so the result is
    /// never greater than `generated`. That is not a stylistic limit — it is what keeps the
    /// flash guarantee intact without re-deriving it: a stage that can only reduce luminance
    /// cannot raise the luminance velocity `FlashGuard.slewedDimmer` bounds downstream.
    ///
    /// ⚠️ **NaN FALLS BACK TO THE IDENTITY (1), NOT TO 0**, and the direction is a decision,
    /// not an oversight. `FloatingPointClamp.clamped(to:)` maps NaN to the range's LOWER bound,
    /// which is right for a bio value that must fail quiet — here it would black out a rig
    /// mid-show on one bad frame. A creative multiplier that has no valid instruction should
    /// leave the generated look alone, so the fallback is the identity. This matches
    /// `ArtNetSender.masteredDimmer`'s own `grandMaster.isFinite ? … : 1` for a different but
    /// compatible reason. A NaN `generated` still fails to 0 — that one IS a bio-derived value.
    public nonisolated static func creativeTarget(_ generated: Float, lookIntensity: Float) -> Float {
        let g = generated.isFinite ? Swift.min(Swift.max(generated, 0), 1) : 0
        return Swift.min(Swift.max(g * sanitizedLookIntensity(lookIntensity), 0), 1)
    }

    /// 0…1, non-finite → the identity. Shared by the setter and the kernel so a value stored
    /// through the store and a value handed straight to `creativeTarget` cannot disagree.
    public nonisolated static func sanitizedLookIntensity(_ value: Float) -> Float {
        guard value.isFinite else { return defaultLookIntensity }
        return Swift.min(Swift.max(value, 0), 1)
    }
}

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
//  ⭐ AND SINCE P2 PROOF #1 IT IS A REGISTRY PARAMETER — but the dependency runs ONE way, and
//  that is the thing to preserve. `LightingParameterCatalog` (in `Core/EchoelParameterRegistry
//  .swift`) describes `lighting.look.intensity` and READS `defaultLookIntensity` from here;
//  `EchoelmusicApp` binds the router to `setLookIntensity`. Nothing flows back: this file names
//  no descriptor, no registry, no modulation key and no persistence root, which is what keeps
//  it a plain Foundation value type two protocol adapters can share.
//  ⭐ SINCE RESTRUCTURE P2 (2026-10-04) THE LOOK HAS A DOOR AND IS SAVED — but NOT here, and
//  that keeps this paragraph's one-way rule intact. The PIECE owns it
//  (`TimelineDocument.lightLookIntensity`, nil = never set = 1.0); the Project plate's
//  `PieceLightLookField` edits it through `TimelineStore.editLightLook`/`commitLightLook` (one
//  Undo step per gesture); `EchoelmusicApp` projects the document into this store through the
//  canonical parameter (`applyReal` → the one bind → `setLookIntensity`) at launch and on every
//  document change — an edit, an Undo, an Open, a switch between two pieces. This file still
//  knows nothing about persistence; it only receives the value.
//  ⚠️ STILL ABSENT, DELIBERATELY: modulation and automation — and
//  since P2 Proof #1.1 that absence is STATED rather than arranged. The descriptor carries
//  `automationEligible: false` and `modulationEligible: false`; `AutomationPlayer` dispatches
//  through `ParameterApplyRouter.applyAutomation`, which asks, and the app's modulation loop
//  filters on `modulatableDescriptors()`. The earlier version kept the look out of the
//  modulation engine by placing one statement after another — correct, invisible, and one
//  tidy-up away from silently untrue. `TheLightingLookIsACanonicalParameterTests` pins the
//  path and the two denials; nothing pins line order any more, because nothing depends on it.
//
//  ⭐ SINCE WORKSTATION C3a THE LOOK CANNOT MOVE FASTER THAN THE FLASH LAW — the safety half
//  of an automatable look, landed BEFORE anything may write it. A song curve would step this
//  value once per transport step (a sixteenth: 125 ms at 120 BPM), and `FlashGuard.slewedDimmer`
//  downstream lets the dimmer move ~2.4 per second: a curve alternating 0 and 1 on successive
//  sixteenths would still swing a rig by ~0.3 four times a second — a WCAG general flash above
//  3 Hz. So neither sender reads this value raw any more. Each SLEWS it per tick from the look
//  its network last ACCEPTED (`slewedLookIntensity` at `maxLookChangePerSecond`, 0.10 × 3 =
//  0.30 per second — the #1446 anchor discipline, so an outage freezes this ramp exactly as it
//  freezes the dimmer's). A 3 Hz half-cycle (1/6 s) then moves the factor by at most 0.05.
//  With nothing accepted yet there is nothing on the wire to ramp from, and the look lands
//  with the dimmer's own first edge — the "no history" rule `slewedDimmer` already applies.
//  ⚠️ WHAT THIS BOUNDS IS THE LOOK'S CONTRIBUTION, NOT THE OUTPUT. The generated target has
//  its own rate: while music sounds it is `0.3 + 0.7·masterLevel`, and `masterLevel` is the
//  unsmoothed sum of the sounding velocities, so it can step per sequencer tick. That path is
//  bounded by the dimmer slew alone and is NOT covered here. ⚠️ Per NOMINAL tick, too: the
//  late-timer residual `FlashGuard.senderLuminancePerSecond` documents applies unchanged.
//  Until Restructure P2 nothing wrote the look, so every slew ran from 1 to 1. Since P2 the
//  piece's field writes it, and this slew is what turns a typed jump into a fade on the rig.
//  Pinned by `TheLightLookMovesNoFasterThanTheFlashLawTests`; a song CURVE and the
//  automation-eligibility flip are still the next slice (C3b), together.
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
    /// `private(set)` with a clamping setter rather than a plain `var`, deliberately — and
    /// P2 Proof #1 turned that from foresight into load-bearing: as the parameter
    /// `lighting.look.intensity` it is reached by `ParameterApplyRouter.applyReal`, which
    /// BYPASSES the descriptor's range clamp, so the range is enforced by this owner or not at
    /// all — and this value reaches a physical fixture.
    /// ⚠️ `LightingStore.` and not `Self.`: Swift rejects a covariant `Self` in a STORED
    /// property initializer, even on a `final class` — `error: covariant 'Self' type cannot be
    /// referenced from a stored property initializer`, which is what `Xcode Compile Check` said
    /// about the first version of this line. `Self.` inside a method body (below) is fine.
    public private(set) var lookIntensity: Float = LightingStore.defaultLookIntensity

    /// The identity value. Named rather than repeated as a literal, because three places
    /// (the property, the NaN fallback, the future descriptor default) must agree (#416).
    ///
    /// ⚠️ `nonisolated` although the class is `@MainActor`: Xcode's toolchain isolates a
    /// `static let` on a `@MainActor` type even when it is immutable, and SwiftPM's does not
    /// (the two disagree on SE-0434 inference, recorded in CLAUDE.md's build-error table).
    /// The pure members here carry no state, so isolating them buys nothing and costs a
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
    /// never greater than `generated`. That bounds the LEVEL, not the RATE: a factor that
    /// itself steps 1 → 0 → 1 moves the output as fast as it steps. ⛔ This doc used to say
    /// attenuation "keeps the flash guarantee intact without re-deriving it" — true only while
    /// the factor is still, which is why the senders hand this kernel a SLEWED look
    /// (`slewedLookIntensity`, Workstation C3a) and never the store's raw value.
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

    // MARK: - The flash ceiling on the creative factor (Workstation C3a)

    /// How fast the creative level may move on the wire, derived from the flash law rather than
    /// chosen: one flash threshold per cycle at the ceiling, `0.10 × 3 = 0.30` per second, so a
    /// 3 Hz half-cycle moves it by at most half the threshold. The same derivation as
    /// `VisualCreativeState.maxIntensityChangePerSecond`, written out here rather than read
    /// from there — light must not depend on the picture's owner.
    ///
    /// ⚠️ `nonisolated` for the reason `defaultLookIntensity` gives above.
    public nonisolated static let maxLookChangePerSecond: Double =
        FlashGuard.luminanceDeltaThreshold * FlashGuard.maxFlashHz

    /// One sender tick of the creative factor: `current` (the look the network last ACCEPTED)
    /// moves toward `target` (this store's value) by at most `maxLookChangePerSecond × dt`.
    /// The dt rule — capped at 1 s, 0.1 s when not finite or not positive — is
    /// `FlashGuard.maxDelta`'s, not a second one. `target` is sanitised the owner's way, so a
    /// non-finite target moves toward the identity.
    ///
    /// `current == nil` is NO HISTORY — nothing accepted on the wire yet — and the look lands
    /// on the goal: the rule `FlashGuard.slewedDimmer` applies to the dimmer in the same tick
    /// (a negative anchor returns the target). A non-finite `current` is read the same way.
    ///
    /// ⭐ EXACT AT THE IDENTITY: `slewedLookIntensity(from: 1, toward: 1, dt:)` is exactly 1,
    /// which is what keeps a build in which nothing writes the look byte-identical on the wire.
    public nonisolated static func slewedLookIntensity(from current: Float?, toward target: Float,
                                                       dt: Double) -> Float {
        let goal = sanitizedLookIntensity(target)
        guard let current, current.isFinite else { return goal }
        let step = FlashGuard.maxDelta(perSecond: maxLookChangePerSecond, dt: dt)
        return Float(FlashGuard.limitedLuminance(from: Double(sanitizedLookIntensity(current)),
                                                 to: Double(goal), maxDelta: step))
    }
}

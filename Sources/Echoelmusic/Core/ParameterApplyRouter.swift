// ParameterApplyRouter.swift
// Echoel — Automation-in-track cycle 1. The one missing wire between the
// EchoelParameterRegistry catalog ("what can be automated") and the live engine
// ("what actually moves audio"): a keyPath → live-setter dispatch table. This is
// the concrete body of the `apply:` closure that ParameterToolCore.set() and the
// automation playback path have always taken as an injected hole.
//
// Identity: a lane/tool targets a parameter purely by its registry keyPath
// ("modul.sektion.parameter"); the descriptor supplies the range so a normalized
// 0…1 automation value maps to the real value at the write site.
//
// Audio-thread law: this is @MainActor CONTROL-PLANE code. It is fed at the
// transport step rate (≤16/bar), never from a render/DSP block. Each bound setter
// is expected to write the voice's own `nonisolated(unsafe)` atomic-Float mirror
// (e.g. EchoelDDSP.setCutoffScale, AudioEngine.masterVolume, PatternEngine.setTempo)
// which the render thread reads lock-free — so no lock/alloc/ObjC ever reaches audio.
// It lives in Core/ (never DSP/) so the AUv3 target, which compiles DSP/ in
// isolation, never sees it.
//
// Placebo law: the picker offers ONLY keyPaths that are actually bound to a live
// setter (`automatableDescriptors()`), so a user can never author a lane that moves
// nothing. Binding happens at app wiring time (later cycle); this type is pure.
//
// ⭐ AND SINCE P2 PROOF #1.1 THE PLACEBO LAW IS NO LONGER THE WHOLE RULE. Binding means
// exactly one thing — "this router knows how to dispatch this key to its real owner" — and
// says nothing about whether a drawn lane or a body route MAY own it. Those are explicit,
// deny-by-default capabilities on the descriptor. See the eligibility section at the bottom
// of this file for the four concepts and why the gate sits at `applyAutomation` rather than
// inside `applyNormalized`.

import Foundation

/// Routes a parameter keyPath to the live engine setter bound for it. Pure,
/// control-plane, deterministic — no clock, no RNG, no audio-thread reach.
@MainActor
public final class ParameterApplyRouter {

    private let registry: EchoelParameterRegistry
    /// keyPath → live setter (takes the REAL, already-in-range value).
    private var setters: [String: (Float) -> Void] = [:]

    /// Live runtime context for resolving a per-track keyPath ("track.<laneID>.<base>")
    /// to a physical rack slot. Supplied at app-wiring time via `bindPerTrack`; nil
    /// until then, so a per-track keyPath is a safe no-op and the global automation
    /// path stays byte-identical (the L2/L4 golden gate).
    public struct PerTrackContext {
        public let document: TimelineDocument
        public let rollLane: UUID?
        public let capacity: Int
        public init(document: TimelineDocument, rollLane: UUID?, capacity: Int) {
            self.document = document
            self.rollLane = rollLane
            self.capacity = capacity
        }
    }

    /// Provides the CURRENT document/roll/capacity at dispatch time — laneID→slot is
    /// rank-unstable between plays, so this is read per apply, never cached.
    private var perTrackContext: (() -> PerTrackContext)?
    /// Writes a resolved per-track value to the lane's rack voice slot; returns
    /// whether it was applied (false = no live voice for that slot). Injected at
    /// app-wiring time so the audio engine coupling stays out of Core.
    private var perTrackSetter: ((_ slot: Int, _ base: String, _ real: Float) -> Bool)?

    public init(registry: EchoelParameterRegistry) {
        self.registry = registry
    }

    /// Wire the per-track dispatch path (L2/L4 S2b). Until this is called, per-track
    /// keyPaths resolve to a no-op and behavior is byte-identical to the global-only
    /// router. `context` yields the live document each apply; `setter` writes the
    /// resolved (slot, base, real value) to the rack voice.
    public func bindPerTrack(context: @escaping () -> PerTrackContext,
                             setter: @escaping (_ slot: Int, _ base: String, _ real: Float) -> Bool) {
        perTrackContext = context
        perTrackSetter = setter
    }

    /// Bind (or replace) the live setter for a keyPath. Called at app wiring time,
    /// e.g. `router.bind("ddsp.filter.cutoff") { voice.setCutoffScale($0) }`.
    public func bind(_ keyPath: String, _ setter: @escaping (Float) -> Void) {
        setters[keyPath] = setter
    }

    /// Remove the live setter for a keyPath (e.g. a hosted AU is unloaded). The
    /// registry descriptor may linger, but with no setter it drops out of
    /// `automatableDescriptors()` and `applyNormalized` becomes a safe no-op.
    public func unbind(_ keyPath: String) {
        setters[keyPath] = nil
    }

    /// Apply a NORMALIZED 0…1 value (the automation-lane / tool value): denormalize
    /// through the registry descriptor, then dispatch the real value to the bound
    /// setter. Returns the applied real value, or nil (a safe no-op) when there is no
    /// descriptor to map the value or no setter bound — never a crash.
    @discardableResult
    public func applyNormalized(_ keyPath: String, _ normalized: Float) -> Float? {
        // Per-track automation ("track.<laneID>.<base>") dispatches to the specific
        // lane's rack voice slot, not a global setter. Intercept BEFORE the global
        // lookup (a per-track keyPath has no global registry descriptor). Byte-
        // identical no-op until `bindPerTrack` wires the context + setter.
        if PerTrackParameterKeyPath.isPerTrack(keyPath) {
            return applyPerTrack(keyPath, normalized)
        }
        guard let descriptor = registry.descriptor(for: keyPath),
              let setter = setters[keyPath] else { return nil }
        let real = descriptor.denormalized(normalized)
        setter(real)
        return real
    }

    /// Resolve a per-track keyPath against the live document and write to the lane's
    /// rack voice slot. Returns the applied real value, or nil (safe no-op) when the
    /// per-track path is unwired, the lane has no physical voice (deleted / foreign /
    /// overflow), the base parameter is unknown, or no live voice took the write.
    private func applyPerTrack(_ keyPath: String, _ normalized: Float) -> Float? {
        guard let context = perTrackContext, let setter = perTrackSetter else { return nil }
        let ctx = context()
        guard let resolved = PerTrackAutomationResolver.resolve(
            keyPath: keyPath, normalized: normalized,
            document: ctx.document, rollLane: ctx.rollLane, capacity: ctx.capacity,
            descriptor: { registry.descriptor(for: $0) }) else { return nil }
        return setter(resolved.slot, resolved.base, resolved.value) ? resolved.value : nil
    }

    /// Apply a REAL value directly (already in the parameter's units/range) — used
    /// where the caller has computed the real value itself. Returns whether a setter
    /// was bound to receive it.
    @discardableResult
    public func applyReal(_ keyPath: String, _ real: Float) -> Bool {
        guard let setter = setters[keyPath] else { return false }
        setter(real)
        return true
    }

    /// Whether a live setter is bound for this keyPath.
    public func isBound(_ keyPath: String) -> Bool { setters[keyPath] != nil }

    /// Every keyPath that currently has a live setter.
    public var boundKeyPaths: Set<String> { Set(setters.keys) }

    // MARK: - Eligibility (P2 Proof #1.1) — four concepts, kept apart

    /// ⭐ THE CONFLATION THIS SECTION REMOVES, stated once so it cannot come back. Until now
    /// `automatableDescriptors()` meant *registry ∩ bound setter*, and it was read by BOTH the
    /// automation surface and the app's modulation-registration loop. So `bind(...)` — the only
    /// way to teach this router how to reach a parameter's real owner at all — silently also
    /// granted that parameter to drawn automation AND to body routes. Four different facts were
    /// riding on one predicate:
    ///
    ///   REGISTERED            the registry describes it (identity, range, unit)
    ///   BOUND / DISPATCHABLE  this router knows how to reach its real owner
    ///   AUTOMATION ELIGIBLE   a drawn lane MAY own it          ← policy, on the descriptor
    ///   MODULATION ELIGIBLE   a body route MAY own it          ← policy, on the descriptor
    ///
    /// Binding now means ONLY the second. The last two are explicit descriptor metadata, deny
    /// by default, and neither is inferred from `domain`, from the keyPath's spelling, from
    /// whether a setter happens to exist, or from the order in which the app wires things up.

    /// Whether an AUTOMATION LANE is authorised to drive this keyPath.
    ///
    /// ⚠️ A PER-TRACK LANE INHERITS ITS BASE PARAMETER'S ANSWER. `track.<uuid>.<base>` has no
    /// descriptor of its own — the namespace is resolved at dispatch — so the question is
    /// forwarded to `<base>`. That is the only answer that keeps the two paths consistent: a
    /// parameter a global lane may not own must not become ownable by addressing it per track.
    public func isAutomationEligible(_ keyPath: String) -> Bool {
        eligibilityDescriptor(for: keyPath)?.automationEligible ?? false
    }

    /// Whether a MODULATION ROUTE is authorised to drive this keyPath. Same rules as above.
    public func isModulationEligible(_ keyPath: String) -> Bool {
        eligibilityDescriptor(for: keyPath)?.modulationEligible ?? false
    }

    /// The descriptor whose POLICY governs `keyPath` — itself, or, for a per-track keyPath,
    /// the global base it clones. nil for a keyPath the registry does not describe, which is
    /// how an unknown key ends up denied rather than defaulted.
    private func eligibilityDescriptor(for keyPath: String) -> ParameterDescriptor? {
        if let parsed = PerTrackParameterKeyPath.parse(keyPath) {
            return registry.descriptor(for: parsed.base)
        }
        return registry.descriptor(for: keyPath)
    }

    /// The AUTOMATION dispatch: apply a normalized lane value only if automation is authorised
    /// for this keyPath, then go through the ordinary `applyNormalized`. Returns the applied
    /// real value, or nil — which is the same safe no-op an unbound or unknown key already
    /// produced, so an unauthorised lane behaves exactly like a lane nobody drew.
    ///
    /// ⚠️ THIS IS THE ONLY GATE, AND IT IS HERE RATHER THAN INSIDE `applyNormalized` ON
    /// PURPOSE. `applyNormalized` / `applyReal` stay the generic canonical dispatch — a direct
    /// caller that has already decided is still allowed to write any bound parameter, which is
    /// what makes the path canonical in the first place. Automation is a SOURCE with a policy,
    /// not a synonym for writing. Putting the check in the generic entry point would have made
    /// the two ideas one again, in the other direction.
    @discardableResult
    public func applyAutomation(_ keyPath: String, _ normalized: Float) -> Float? {
        guard isAutomationEligible(keyPath) else { return nil }
        return applyNormalized(keyPath, normalized)
    }

    /// The registry descriptors an AUTOMATION surface may offer: registered, bound to a live
    /// setter (the Placebo law — a lane must move something), AND explicitly automation
    /// eligible. Registry insertion order is preserved so a picker stays stable.
    ///
    /// ⚠️ All three conditions are required and none implies another. A descriptor may be
    /// eligible and unbound (policy says yes, nothing is listening — excluded), or bound and
    /// ineligible (the router can reach it directly, a lane may not own it — excluded here,
    /// still dispatchable through `applyNormalized`).
    public func automatableDescriptors() -> [ParameterDescriptor] {
        registry.all().filter { isBound($0.keyPath) && $0.automationEligible }
    }

    /// The registry descriptors a MODULATION surface may offer — the same three conditions
    /// against the other capability. Separate from `automatableDescriptors()` because the two
    /// questions are separate; that they return the same set today is a measurement.
    ///
    /// ⭐ THIS IS WHAT RETIRES THE LINE-ORDER POLICY. The app used to keep lighting out of the
    /// modulation engine by registering destinations BEFORE the lighting bind — correct only
    /// as long as nobody moved two statements, and invisible in review. The answer no longer
    /// depends on when this is called.
    public func modulatableDescriptors() -> [ParameterDescriptor] {
        registry.all().filter { isBound($0.keyPath) && $0.modulationEligible }
    }
}

// EchoelParameterRegistry.swift
// Echoel — EchoelAI N2: the queryable parameter registry (ADR
// scratchpads/ECHOELAI_ADR_2026-07-12.md). Foundation of the later tool
// surface: an on-device planner never gets parameter DUMPS in its prompt —
// it queries THIS registry through a few generic tools (listParameters /
// searchParameters / setParameter). Today: internal engine parameters only
// (first real inventory = EchoelDDSP), read-only, no UI, no model.
//
// Identity law: a parameter's `keyPath` ("modul.sektion.parameter", e.g.
// "ddsp.filter.cutoff") is the STABLE persisted identity — never a numeric
// AU address, never a display name.
//
// LATER (AUv3 hosting cycle — design note, no code): external plugin
// parameters join this same registry by observing the host's
// `AUAudioUnit.parameterTree` via KVO (plugins REPLACE the tree at runtime,
// so the observation must re-enumerate on change), mapping each
// AUParameter's stable `keyPath` into a descriptor with a "au.<plugin>."
// prefix. Writes to those descriptors go through `setValue(_:originator:)`
// on the control plane — or, while the graph runs and the parameter carries
// flag_CanRamp, through a cached `scheduleParameterBlock`. The registry
// itself stays exactly this shape.

import Foundation

// ⭐ WA3.2 (2026-09-24): `ParameterDomain` and `ParameterDescriptor` MOVED, unchanged, to
// `DSP/ParameterDescriptor.swift`. Reason: the AUv3 extension compiles `DSP/` and not this file
// (this file reaches app types — `PolySynthVoice`, `LightingStore`), and one descriptor type
// must serve the app AND the plug-in. The registry, the catalogs and every call site are
// unchanged; the types are in the same module for the app.

/// The queryable registry. Modules register their descriptors at startup;
/// tools (and later the AUv3 KVO bridge) only ever READ. @MainActor —
/// registration and queries are control-plane; nothing here is called from
/// audio code.
@MainActor
public final class EchoelParameterRegistry {

    /// keyPath → descriptor; insertion order preserved for stable `all()`.
    private var descriptors: [ParameterDescriptor] = []
    private var indexByKeyPath: [String: Int] = [:]

    public init() {}

    /// Register (or replace, by keyPath) a module's descriptors. Replacing
    /// keeps the original position so `all()` stays stable across re-inits.
    public func register(_ newDescriptors: [ParameterDescriptor]) {
        for d in newDescriptors {
            if let i = indexByKeyPath[d.keyPath] {
                descriptors[i] = d
            } else {
                indexByKeyPath[d.keyPath] = descriptors.count
                descriptors.append(d)
            }
        }
    }

    public func all() -> [ParameterDescriptor] { descriptors }

    public func descriptor(for keyPath: String) -> ParameterDescriptor? {
        indexByKeyPath[keyPath].map { descriptors[$0] }
    }

    /// Substring + token match over keyPath, displayName and unit — every
    /// whitespace-separated query token must match somewhere. Empty query
    /// returns everything (that IS listParameters).
    ///
    /// RANKING HOOK (deliberately not implemented today): the semantic
    /// vocabulary (Resources/echoelai-vocabulary.json) will later re-rank
    /// these hits — "dunkler" boosting cutoff/air/damping — via a scoring
    /// closure injected here. Keep the exact-match semantics as the base.
    public func search(query: String) -> [ParameterDescriptor] {
        let tokens = query.lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard !tokens.isEmpty else { return descriptors }
        return descriptors.filter { d in
            let haystack = "\(d.keyPath) \(d.displayName) \(d.unit)".lowercased()
            return tokens.allSatisfy { haystack.contains($0) }
        }
    }
}

// MARK: - First real inventory: EchoelDDSP (the bio-reactive synth core)

/// The DDSP voice's musically meaningful control-plane parameters, described
/// against the REAL ranges/defaults in DSP/EchoelDDSP.swift. This is data
/// about the engine, not a second source of truth for DSP behaviour — the
/// voice's own clamps still apply at the write site.
public enum DDSPParameterCatalog {

    /// The described inventory — RANGES and NAMES only. Capability is decided once, below, so
    /// no entry here can grant itself automation or modulation by being edited.
    private static let inventory: [ParameterDescriptor] = [
        ParameterDescriptor(keyPath: "ddsp.osc.frequency", displayName: "Oscillator frequency",
                            min: 20, max: 2000, defaultValue: 110, unit: "Hz"),
        ParameterDescriptor(keyPath: "ddsp.osc.harmonicity", displayName: "Harmonicity",
                            min: 0, max: 1, defaultValue: 0.88),
        ParameterDescriptor(keyPath: "ddsp.osc.brightness", displayName: "Brightness",
                            min: 0, max: 1, defaultValue: 0.25),
        ParameterDescriptor(keyPath: "ddsp.osc.noiseLevel", displayName: "Noise level",
                            min: 0, max: 1, defaultValue: 0.01),
        ParameterDescriptor(keyPath: "ddsp.amp.level", displayName: "Amplitude",
                            min: 0, max: 1, defaultValue: 0.5),
        ParameterDescriptor(keyPath: "ddsp.env.attack", displayName: "Envelope attack",
                            min: 0.001, max: 10, defaultValue: 0.5, unit: "s"),
        ParameterDescriptor(keyPath: "ddsp.env.decay", displayName: "Envelope decay",
                            min: 0.001, max: 10, defaultValue: 0.5, unit: "s"),
        ParameterDescriptor(keyPath: "ddsp.env.sustain", displayName: "Envelope sustain",
                            min: 0, max: 1, defaultValue: 0.8),
        ParameterDescriptor(keyPath: "ddsp.env.release", displayName: "Envelope release",
                            min: 0.001, max: 10, defaultValue: 2.0, unit: "s"),
        ParameterDescriptor(keyPath: "ddsp.filter.cutoff", displayName: "Filter cutoff",
                            min: 20, max: 18_000, defaultValue: 220, unit: "Hz"),
        ParameterDescriptor(keyPath: "ddsp.fx.reverbMix", displayName: "Reverb mix",
                            min: 0, max: 1, defaultValue: 0.25),
        ParameterDescriptor(keyPath: "ddsp.fx.reverbDecay", displayName: "Reverb decay",
                            min: 0.1, max: 10, defaultValue: 2.0, unit: "s"),
        ParameterDescriptor(keyPath: "ddsp.mod.vibratoRate", displayName: "Vibrato rate",
                            min: 0, max: 12, defaultValue: 0, unit: "Hz"),
        ParameterDescriptor(keyPath: "ddsp.mod.vibratoDepth", displayName: "Vibrato depth",
                            min: 0, max: 1, defaultValue: 0),
        ParameterDescriptor(keyPath: "ddsp.warmth.drive", displayName: "Warmth drive",
                            min: 0, max: 1, defaultValue: 0),
    ]

    /// The catalog as the registry sees it: the inventory above, with capability stamped on.
    ///
    /// ⭐ THE ELIGIBLE SET IS A PROJECTION, NOT A SECOND LIST (#416). `PolySynthVoice
    /// .automatableBases` already IS this build's answer to "which parameters may a control
    /// source own" — it is the list `bindAutomatable` iterates, and the rule behind its
    /// membership (automation may own a parameter only where it is the ONLY writer; everywhere
    /// else it owns the ANCHOR) is guarded three times over at that list. Writing the eleven
    /// names again here would be a second home for one decision, and the copy would be the one
    /// that rots. `ModDestinationKey.all` reads the same list from the same file for the same
    /// reason, so this is the established direction, not a new coupling.
    ///
    /// ⚠️ THE FOUR PARAMETERS NOT IN THAT LIST STAY DENIED, and that is exactly today's
    /// behaviour rather than a new restriction: `ddsp.osc.frequency`, `ddsp.filter.cutoff`,
    /// `ddsp.fx.reverbMix` and `ddsp.fx.reverbDecay` have no router binding, so before this
    /// slice they were already unreachable by automation and by the matrix. Denying them
    /// changes nothing; it only says so out loud. `ddsp.fx.reverbMix` in particular must STAY
    /// denied while its stage is off (#546) — `TheDisabledReverbStageIsNotOfferedForAutomation`
    /// carries that reason.
    ///
    /// ⚠️ The two capabilities come from ONE predicate because they agree for every parameter
    /// in this build. That is a measurement of today, not a definition: they are separate
    /// fields precisely so the next parameter that needs them to differ can say so.
    public static let descriptors: [ParameterDescriptor] = DDSPParameterCatalog.inventory.map {
        var d = $0
        let mayBeOwned = PolySynthVoice.automatableBases.contains(d.keyPath)
        d.automationEligible = mayBeOwned
        d.modulationEligible = mayBeOwned
        return d
    }
}

// MARK: - Second inventory: the creative LIGHTING state (P2 Proof #1)

/// The one non-audio parameter this build describes, and the point of the whole P2 exercise:
/// the canonical parameter infrastructure — registry, descriptor, router — was built for the
/// synth and had never addressed another medium. `lighting.look.intensity` proves it can,
/// without a second registry, a second descriptor type or a lighting-specific framework.
///
/// ⚠️ ONE DESCRIPTOR, DELIBERATELY. The lighting chain has exactly three stored values and
/// only ONE of them is creative: `grandMaster` is the live operator's control over finished
/// output and `blackout` is a safety cut, so neither may ever become a parameter a
/// composition, an automation lane or a body route can move. The reasons live at
/// `LightingStore`'s header, where they were decided; this catalog only obeys them.
///
/// ⚠️ THE DEFAULT IS READ FROM THE OWNER, not written again here (#416). `LightingStore`'s
/// own doc predicted this line: the stored property, the NaN fallback and this descriptor
/// default are three places that must agree, so there is one literal and two references.
public enum LightingParameterCatalog {

    /// The canonical keyPath. One home for the string: the registration below and the router
    /// binding in `EchoelmusicApp` both read THIS, so a rename cannot leave a descriptor
    /// registered under a name nothing is bound to (the placebo the router's own law forbids).
    public static let lookIntensity = "lighting.look.intensity"

    /// ⚠️ `unit` is empty ON PURPOSE. Dimensionless 0…1 values read as raw decimals in this
    /// app ("0.50", never "50 %") — the Uncodixfy parameter-row law — and an empty unit is how
    /// a descriptor says so. `valueLabels` stays nil: this is a continuous level, not a
    /// stepped choice, so it is a number field and never a Picker.
    public static let descriptors: [ParameterDescriptor] = [
        ParameterDescriptor(keyPath: lookIntensity, displayName: "Look intensity",
                            min: 0, max: 1,
                            defaultValue: LightingStore.defaultLookIntensity,
                            domain: .lighting,
                            automationEligible: false,
                            modulationEligible: false),
    ]
}

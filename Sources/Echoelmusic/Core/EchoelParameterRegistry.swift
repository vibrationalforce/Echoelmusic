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

/// The creative domain that OWNS a parameter — P2's one new fact about parameter
/// identity. A `keyPath` is a STRING, and a string that begins "light." is a naming
/// convention, not a typed statement. This is the typed statement.
///
/// ⚠️ THIS IS NOT `SignalKind`, AND FOLDING THE TWO WOULD BE WRONG — although
/// `Core/SignalRouting.swift` already declares `audio`, `light`, `spatial` and `visual`
/// as cases, so the temptation is real and this paragraph exists to answer it once.
/// The two answer different questions:
///   · `SignalKind` = what FLOWS on a graph edge; its own doc says "the class of signal
///     carried on an edge", and `.audio` there means "an audio bus". SIX of its eleven
///     cases — `controlBio`, `controlMusical`, `controlMacro`, `note`, `controlChange`,
///     `clock` — name a PAYLOAD CLASS, and every parameter in this registry is reached by
///     one of those whatever its domain, so they cannot distinguish domains at all.
///     `ddsp.filter.cutoff` is not an audio bus; it is a control parameter that shapes one.
///   · `ParameterDomain` = which creative medium a parameter BELONGS to.
/// Reusing `SignalKind` would also import its `isLive` flag, which reports `visual` as not
/// live — true of an ENGINE on an edge, and false as a statement about a visual parameter
/// the moment P2 registers one. Two questions, two types: that is separation, not duplicate
/// truth. #416 asks for one definition per DECISION, not one enum per word.
///
/// ⚠️ FOUR CASES DELIBERATELY, and the omissions are the measurement, not an oversight.
/// These are the creative output domains the 2026-09-22 DMMW audit measured as having a
/// live egress stage. `midi` and `transport` are absent because no registry descriptor
/// needs them today and this repo does not declare what it has not measured. Adding a case
/// later is additive and free; removing one is not.
///
/// ⚠️ A CASE IS A VOCABULARY ENTRY, NOT A CAPABILITY CLAIM. As of this slice EVERY
/// registered descriptor is `.audio` (`DDSPParameterCatalog`); nothing carries `.visual`,
/// `.lighting` or `.spatial` yet, and `TheParameterDescriptorNamesItsDomainTests` pins
/// that the catalog is audio-only rather than pinning that the REGISTRY is — the second
/// form would forbid the very next slice (#364).
public enum ParameterDomain: String, Codable, Sendable, CaseIterable {
    case audio
    case visual
    case lighting
    case spatial
}

/// One adjustable engine parameter, described for query + typed writes.
/// Codable so tool transcripts / presets can carry descriptors verbatim.
public struct ParameterDescriptor: Codable, Sendable, Equatable, Identifiable {
    /// Stable identity, "modul.sektion.parameter" (see identity law above).
    public var keyPath: String
    public var displayName: String
    public var min: Float
    public var max: Float
    public var defaultValue: Float
    /// Physical unit for display ("Hz", "s"); empty = dimensionless 0–1 style.
    public var unit: String
    /// Optional labels for stepped/enum-like parameters (index = value).
    public var valueLabels: [String]?
    /// Whether an AUTOMATION LANE may drive this parameter. **DENY BY DEFAULT.**
    ///
    /// ⭐ WHY THIS IS NOT "is a setter bound" (P2 Proof #1.1). Until this field existed,
    /// `automatableDescriptors()` meant *registry ∩ bound setter*, so BINDING a key into the
    /// router — the only way to make the canonical path able to dispatch it at all — silently
    /// also granted it to automation and, through the app's registration loop, to modulation.
    /// Three different questions answered by one predicate: *can the router reach the owner*,
    /// *may a drawn lane own it*, *may a body route own it*. The first is a wiring fact; the
    /// other two are POLICY, and policy must be written down rather than inferred.
    ///
    /// ⚠️ IT IS ORTHOGONAL TO `domain`. `if domain == .audio` would have been shorter and
    /// would have encoded today's inventory as law — blocking lighting automation, visual
    /// modulation and spatial automation, all of which are legitimate later work. A future
    /// lighting parameter becomes automatable by setting THIS flag, not by changing its medium.
    ///
    /// ⚠️ ELIGIBILITY IS NOT EXECUTION. A descriptor may be eligible and still move nothing,
    /// because the owner setter is unbound — the Placebo law is unchanged and still applies on
    /// top of this flag. Both conditions are required, in that order.
    public var automationEligible: Bool

    /// Whether a MODULATION ROUTE (the body → parameter matrix) may drive this parameter.
    /// **DENY BY DEFAULT**, and a separate field from `automationEligible` on purpose: the two
    /// answer different questions and a future parameter may legitimately allow a drawn lane
    /// and refuse a live body route, or the reverse. They happen to agree for every parameter
    /// in this build; that is a measurement, not a definition.
    public var modulationEligible: Bool

    /// Which creative medium owns this parameter (see `ParameterDomain`). Defaults to
    /// `.audio` so every existing descriptor and every existing call site is unchanged.
    /// NOTHING reads it yet — it is identity metadata, deliberately not apply semantics:
    /// the safety/apply envelope stays with the domain's own setter (a lighting value goes
    /// through `ArtNetSender.masteredDimmer` + `FlashGuard`; a DDSP value through the
    /// voice's atomic mirror), and `ParameterApplyRouter` stays the one runtime applier.
    public var domain: ParameterDomain

    public var id: String { keyPath }

    /// ⚠️ THE TWO ELIGIBILITY DEFAULTS ARE `false`, AND THAT IS THE SAFETY LAW OF THIS TYPE:
    /// a parameter described by a call site that has not thought about capability grants none.
    /// The opposite default would make every future cross-domain descriptor automatable and
    /// modulatable the moment someone registers it, which is the defect this field exists to
    /// remove. Adding a capability is a visible edit; losing one can only be a visible edit too.
    public init(keyPath: String, displayName: String,
                min: Float, max: Float, defaultValue: Float,
                unit: String = "", valueLabels: [String]? = nil,
                domain: ParameterDomain = .audio,
                automationEligible: Bool = false,
                modulationEligible: Bool = false) {
        self.keyPath = keyPath
        self.displayName = displayName
        self.min = min
        self.max = max
        self.defaultValue = defaultValue
        self.unit = unit
        self.valueLabels = valueLabels
        self.domain = domain
        self.automationEligible = automationEligible
        self.modulationEligible = modulationEligible
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case keyPath, displayName, min, max, defaultValue, unit, valueLabels, domain
        case automationEligible, modulationEligible
    }

    /// Hand-written ONLY so a payload without `domain` — or with a domain string this build
    /// does not know — decodes to `.audio` instead of throwing. Swift's synthesized
    /// `init(from:)` does NOT fall back to a stored property's default value; it throws
    /// `keyNotFound`. Nothing persists a descriptor today (measured: the single encode/decode
    /// in the tree is a symmetric round-trip inside `EchoelParameterRegistryTests`), so this
    /// costs nothing now and makes the field free forever if that ever changes — the same
    /// `decodeIfPresent ?? default` discipline `Sync/LightFixtureGroup` already follows.
    /// Every OTHER key reproduces synthesis exactly, so this is not a widening of tolerance.
    /// `encode(to:)` stays synthesized against these same keys.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.keyPath = try c.decode(String.self, forKey: .keyPath)
        self.displayName = try c.decode(String.self, forKey: .displayName)
        self.min = try c.decode(Float.self, forKey: .min)
        self.max = try c.decode(Float.self, forKey: .max)
        self.defaultValue = try c.decode(Float.self, forKey: .defaultValue)
        self.unit = try c.decode(String.self, forKey: .unit)
        self.valueLabels = try c.decodeIfPresent([String].self, forKey: .valueLabels)
        self.domain = (try? c.decode(ParameterDomain.self, forKey: .domain)) ?? .audio
        // ⚠️ A PAYLOAD THAT DOES NOT SAY GRANTS NOTHING. `decodeIfPresent ?? false` is the same
        // tolerance the `domain` line above takes, pointed the other way: there it keeps an old
        // payload WORKING, here it keeps an old — or a forged, or a newer — payload from
        // acquiring a capability it never stated. Measured before choosing the direction:
        // nothing in `Sources/` encodes or decodes a `ParameterDescriptor`, so no production
        // payload exists to break, and the strict default costs zero behaviour today. If
        // descriptors ever become persisted or network-carried, THIS is the line that must stay
        // deny — and `domain`'s permissive fallback is the one that must then be fixed first.
        // A wrong-TYPE value still throws, exactly like every other key here: `decodeIfPresent`
        // tolerates absence, never nonsense. Only the missing case is answered, and it is
        // answered with "no capability".
        self.automationEligible = try c.decodeIfPresent(Bool.self, forKey: .automationEligible) ?? false
        self.modulationEligible = try c.decodeIfPresent(Bool.self, forKey: .modulationEligible) ?? false
    }

    /// Map a normalized 0…1 tool value into the parameter's real range
    /// (clamped — a planner can never push a parameter out of bounds).
    public func denormalized(_ normalized: Float) -> Float {
        let t = Swift.max(0, Swift.min(1, normalized))
        return min + t * (max - min)
    }

    /// Inverse of `denormalized` (0 when the range is degenerate).
    public func normalized(_ value: Float) -> Float {
        guard max > min else { return 0 }
        return Swift.max(0, Swift.min(1, (value - min) / (max - min)))
    }
}

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

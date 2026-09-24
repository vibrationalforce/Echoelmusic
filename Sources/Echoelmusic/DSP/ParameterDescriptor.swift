// ParameterDescriptor.swift
// Echoel — WA3.2 (2026-09-24). The ONE parameter descriptor type, moved here verbatim from
// `Core/EchoelParameterRegistry.swift` (the registry, the catalogs and the router stay there).
//
// ⚠️ WHY `DSP/` AND NOT `Core/Device/` (founder decision #95: no EchoelCore target yet). The
// AUv3 extension compiles `DSP/` as a directory plus three named `Core/` files
// (`project.yml`, founder-gated). A new `Core/Device/` file would be app-only, so the plug-in
// could not build its parameter tree from the canonical descriptors without a build-definition
// edit. `DSP/` already carries the one other state value both targets share (`SynthPatch`),
// and this file obeys the layer's law: Foundation only, no control-plane type in code
// (`TheDSPLayerStaysFoundationOnlyTests`). DEBT: when #95 lands, this file and
// `EchoelBodyVibeDevice.swift` move to the Core/Device boundary.
//
// Identity law (unchanged): a parameter's `keyPath` ("modul.sektion.parameter") is the STABLE
// identity — never a numeric host address (AU, VST3, CLAP), never array order, never a display
// name. Host numbers live in adapter mapping tables (see `EchoelBodyVibeAUv3Mapping`).

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

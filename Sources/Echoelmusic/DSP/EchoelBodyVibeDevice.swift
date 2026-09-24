// EchoelBodyVibeDevice.swift
// Echoel — WA3.2 (2026-09-24): canonical parameter identity for the AUv3 instrument
// "EchoelBodyVibe", its AUv3 adapter mapping, and the minimal shared device-state value.
//
// ⭐ THE LAYERS, IN THE ORDER A HOST NUMBER IS ALLOWED TO APPEAR:
//   1. `EchoelBodyVibeDevice.creativeDescriptors` — the canonical identity: `ParameterDescriptor`
//      values (the ONE descriptor type, `ParameterDescriptor.swift`) keyed by a stable string.
//      No host number, no array-order meaning.
//   2. `EchoelBodyVibeAUv3Mapping.entries` — the AUv3 ADAPTER: canonical ID → AU identifier +
//      AU address, with every address written as a LITERAL. A future VST3 or CLAP adapter adds
//      its own table next to this one and never touches layer 1.
//   3. The AUv3 builds its `AUParameterTree` from `EchoelBodyVibeAUv3Mapping.resolve()`.
//
// ⚠️ THE FOUR BIO PARAMETERS ARE NOT CANONICAL DESCRIPTORS. Coherence, HRV, heart rate and
// breath phase are LIVE CONTROL SOURCES (WA3 law), yet they occupy public AU addresses 0…3 that
// host projects and automation lanes may reference. They stay host-visible as
// `LegacyLiveControl` adapter entries — with their range and default written in the ADAPTER —
// and they are excluded from creative device state, presets and saved plugin state
// (`AUv3StateContract`, WA3.1). They are never Session-automation targets.
//
// ⚠️ WHY THIS FILE IS IN `DSP/`: the same reason `ParameterDescriptor.swift` is (read its
// header). Foundation only; it names `EchoelDDSP`, `EchoelCellular`, `EchoelReverb` (WA3.3)
// and `SynthPatch`, which are `DSP/` types, and no control-plane type.

import Foundation

/// A live physiological control source that still occupies a host-visible AUv3 parameter.
/// NOT a creative device parameter: never in device state, presets or saved plugin state.
public enum LegacyLiveControl: String, CaseIterable, Sendable {
    case coherence
    case hrv
    case heartRate
    case breathPhase
}

// MARK: - Layer 1: canonical identity

public enum EchoelBodyVibeDevice {

    /// The device TYPE. A format-neutral name: the plug-in format is an adapter, not the device.
    public static let typeID = "echoel.bodyvibe"

    /// Canonical base parameter IDs. `device.<instanceID>.<base>` is the future instance
    /// address (a contract only — no instance runtime exists yet).
    public enum BaseID {
        public static let baseFrequency = "bodyvibe.osc.baseFrequency"
        public static let textureAmount = "bodyvibe.texture.amount"
        public static let reverbMix = "bodyvibe.fx.reverbMix"
        public static let masterGain = "bodyvibe.out.masterGain"
    }

    /// The creative parameters. Array order carries NO meaning — host addresses come from the
    /// adapter's literals, never from here (`resolve` is order-independent).
    ///
    /// ⚠️ ELIGIBILITY STAYS DENIED (P2 law: registered ≠ bound ≠ automationEligible ≠
    /// modulationEligible). No Session automation lane or modulation route is bound to these
    /// in the app; in the plug-in they are driven by the HOST's own automation through the AU
    /// tree, which is an adapter concern and grants nothing here.
    ///
    /// ⚠️ Names, ranges and defaults are the values the AUv3 has always published; changing
    /// one changes a host-visible fact (`TheParameterIdentityIsFormatNeutralTests` pins them).
    public static let creativeDescriptors: [ParameterDescriptor] = [
        ParameterDescriptor(keyPath: BaseID.baseFrequency, displayName: "Base Frequency",
                            min: 40, max: 440, defaultValue: 220, unit: "Hz"),
        ParameterDescriptor(keyPath: BaseID.textureAmount, displayName: "Texture",
                            min: 0, max: 1, defaultValue: 0.3),
        ParameterDescriptor(keyPath: BaseID.reverbMix, displayName: "Reverb",
                            min: 0, max: 1, defaultValue: 0.3),
        ParameterDescriptor(keyPath: BaseID.masterGain, displayName: "Master Gain",
                            min: 0, max: 1, defaultValue: 0.7),
    ]

    // MARK: DSP binding

    /// Where a creative value lands. Resolved once, outside render; applying it is plain
    /// scalar assignment on the control thread, exactly what the AUv3 observer always did.
    public enum Binding: Sendable, Equatable {
        /// `synth.frequency = v`, `texture.frequency = v · 0.5`.
        case pitch
        /// `texture.gain = v`.
        case textureGain
        /// ⭐ WA3.3: `synth.bioBaseReverbMix = v` AND `synth.reverbMix = v`, the same pair
        /// `SynthPatch.apply` writes. The host value is the ANCHOR; the render-side
        /// `applyBioReactive` moves the effective value only by a bounded offset around it
        /// (`EchoelDDSP.bioModulatedReverbMix`), and `renderSpace` feeds that effective value
        /// to the AUv3's reverb (`EchoelReverb`).
        /// ⛔ Until WA3.3 this wrote `reverbMix` alone. That value was overwritten within about
        /// 100 ms from an anchor nothing had set (the 0.25 default), and its only reader, the
        /// convolution stage, is gated off. So the host value was neither kept nor audible.
        case synthReverbMix
        /// The plug-in's own output stage (the render-side gain mirror). No engine field.
        case outputGain
    }

    /// The binding for a canonical ID; nil for an ID this device does not own.
    public static func binding(for baseID: String) -> Binding? {
        switch baseID {
        case BaseID.baseFrequency: return .pitch
        case BaseID.textureAmount: return .textureGain
        case BaseID.reverbMix: return .synthReverbMix
        case BaseID.masterGain: return .outputGain
        default: return nil
        }
    }

    /// Apply a creative value to the engines. `.outputGain` writes nothing here — the adapter
    /// owns its output stage. NOT for the render thread (the AUv3 calls it from its parameter
    /// observer, where the same assignments always ran).
    public static func apply(_ binding: Binding, value: Float,
                             synth: EchoelDDSP, texture: EchoelCellular) {
        switch binding {
        case .pitch:
            synth.frequency = value
            texture.frequency = value * 0.5
        case .textureGain:
            texture.gain = value
        case .synthReverbMix:
            synth.bioBaseReverbMix = value
            synth.reverbMix = value
        case .outputGain:
            break
        }
    }

    /// ⭐ 2026-09-24 (overnight P2) — THE ONE SEEDING PATH. Writes every creative value to the
    /// engines, keyed by canonical base ID; a missing or non-finite value takes the descriptor
    /// default, and every value is clamped to its descriptor's range. Returns the output gain,
    /// because `.outputGain` lands on the adapter's own stage, not on an engine.
    ///
    /// ⛔ WHY IT EXISTS. `apply` runs only when a value CHANGES (the AUv3's parameter observer),
    /// and the tree's defaults are written before that observer is installed — so a fresh
    /// instance played whatever the engines were constructed with. The texture gain was a
    /// literal 0.15 in the AUv3's `init` while the host showed 0.3; the output gain was a second
    /// spelling of the 0.7 default (#416). A displayed value must be the value that sounds.
    ///
    /// NOT for the render thread: it may allocate nothing, but `apply` is a control-plane write
    /// and the AUv3 calls this only from `init` and `allocateRenderResources`.
    @discardableResult
    public static func seed(_ values: [String: Float],
                            synth: EchoelDDSP, texture: EchoelCellular) -> Float {
        var outputGain: Float = 0
        for descriptor in creativeDescriptors {
            guard let target = binding(for: descriptor.keyPath),
                  descriptor.min <= descriptor.max else { continue }
            let raw = values[descriptor.keyPath] ?? descriptor.defaultValue
            let value = raw.isFinite
                ? raw.clamped(to: descriptor.min...descriptor.max)
                : descriptor.defaultValue
            if target == .outputGain {
                outputGain = value
            } else {
                apply(target, value: value, synth: synth, texture: texture)
            }
        }
        return outputGain
    }

    // MARK: The space stage (render thread)

    /// ⭐ WA3.3 — the AUv3's audible reverb consumer. The synth's mono block goes in as `left`;
    /// it comes out as the reverb's stereo pair in `left` / `right`, wet by the synth's
    /// EFFECTIVE mix (anchor + bounded bio offset, already computed render-side by
    /// `applyBioReactive`). The texture stays dry: the old convolution stage it replaces
    /// also sat on the synth only.
    ///
    /// RENDER-THREAD SAFE: one scalar store, then `EchoelReverb.processStereo` per sample, whose
    /// tanks are pre-allocated in its `init` (the same stage the app's FX chain runs on its
    /// audio thread). No allocation, lock, dictionary, string, actor or I/O. At mix 0,
    /// `processStereo` returns its input unchanged, so `left == right ==` the dry synth.
    @inline(__always)
    public static func renderSpace(_ reverb: EchoelReverb, synth: EchoelDDSP,
                                   left: UnsafeMutableBufferPointer<Float>,
                                   right: UnsafeMutableBufferPointer<Float>, count: Int) {
        reverb.mix = synth.reverbMix
        let n = Swift.min(count, Swift.min(left.count, right.count))
        guard n > 0 else { return }
        for i in 0..<n {
            let dry = left[i]
            let (l, r) = reverb.processStereo(dry, dry)
            left[i] = l
            right[i] = r
        }
    }

    // MARK: The tail

    /// How long the AUv3 keeps sounding after its input stops — its `tailTime`: the synth's own
    /// release, then the reverb's slowest mode falling 60 dB (`EchoelReverb.decayTimeSeconds`).
    /// An upper bound by construction, because the reverb's input is already fading during the
    /// release; `TheAUv3TailCoversTheReverbTests` renders it.
    /// ⛔ The AUv3 reported a literal 2.0 s — the release alone — after WA3.3 made the reverb
    /// audible. At full mix on a 55 Hz note the output two seconds after note-off was still far
    /// above −60 dB, so a host bouncing to the tail cut the room off.
    /// A non-finite reverb decay (a feedback of 1 or more, which nothing sets) returns the
    /// largest finite value: "keep rendering", without handing a host infinity. A NaN release
    /// counts as none (`max(0, ·)` in the NaN-safe argument order).
    public static func tailSeconds(synth: EchoelDDSP, reverb: EchoelReverb) -> Double {
        let total = Double(Swift.max(0, synth.release)) + reverb.decayTimeSeconds
        return total.isFinite ? total : .greatestFiniteMagnitude
    }

    // MARK: Factory presets

    /// A factory preset as creative state, keyed by canonical ID.
    public struct Preset: Sendable, Equatable {
        public let number: Int
        public let name: String
        public let creativeValues: [String: Float]
        /// ⛔ HOLD-FOR-FOUNDER (WA3.2). The three presets have always set `coherence`, a live
        /// control source. Removing it changes the sound of two of them (0.7 and 0.8 against
        /// the neutral 0.5): the synth's filter-cutoff factor `1 + (c − 0.5)·0.5`, its
        /// brightness and harmonicity deviations, and the texture's cellular-automaton rule
        /// (`Int(c · 7)`: rule 184 / 73 instead of 105). No creative parameter reproduces any
        /// of the three. So the value is kept, isolated here and applied by the AUv3 as a live
        /// seed, never as creative state, until the founder decides. `nil` = no seed.
        public let legacyCoherenceSeed: Float?
    }

    public static let factoryPresets: [Preset] = [
        Preset(number: 0, name: "Ambient Calm",
               creativeValues: [BaseID.baseFrequency: 220, BaseID.textureAmount: 0.2,
                                BaseID.reverbMix: 0.4],
               legacyCoherenceSeed: 0.7),
        Preset(number: 1, name: "Deep Sleep",
               creativeValues: [BaseID.baseFrequency: 55, BaseID.textureAmount: 0.1,
                                BaseID.reverbMix: 0.6],
               legacyCoherenceSeed: 0.8),
        Preset(number: 2, name: "Active Focus",
               creativeValues: [BaseID.baseFrequency: 330, BaseID.textureAmount: 0.4,
                                BaseID.reverbMix: 0.2],
               legacyCoherenceSeed: 0.5),
    ]
}

// MARK: - Layer 2: the AUv3 adapter mapping

/// One host-visible AUv3 parameter. The address is the host contract and is written as a
/// literal; it is never computed from a position.
public struct AUv3ParameterEntry: Sendable, Equatable {
    public enum Target: Sendable, Equatable {
        case creative(String)
        case legacyLiveControl(LegacyLiveControl)
    }
    public enum Unit: Sendable, Equatable { case generic, hertz, linearGain }
    public enum Group: String, Sendable, Equatable { case bio, sound }

    public let address: UInt64
    public let identifier: String
    public let target: Target
    public let unit: Unit
    public let group: Group

    public init(address: UInt64, identifier: String, target: Target, unit: Unit, group: Group) {
        self.address = address
        self.identifier = identifier
        self.target = target
        self.unit = unit
        self.group = group
    }
}

/// A fully resolved AUv3 parameter, ready to become an `AUParameter`.
public struct AUv3ResolvedParameter: Sendable, Equatable {
    public let address: UInt64
    public let identifier: String
    public let name: String
    public let min: Float
    public let max: Float
    public let defaultValue: Float
    public let unit: AUv3ParameterEntry.Unit
    public let group: AUv3ParameterEntry.Group
    public let target: AUv3ParameterEntry.Target
}

/// Why a mapping cannot be resolved. Every case STOPS resolution: a broken table must fail
/// loudly rather than hand a host a parameter that silently drives a different one.
public enum AUv3MappingError: Error, Equatable {
    case duplicateCanonicalID(String)
    case duplicateAddress(UInt64)
    case duplicateIdentifier(String)
    case unknownCanonicalID(String)
    case unmappedCreativeDescriptor(String)
    /// ⭐ WA3.3: a creative parameter that is mapped to a host address but has no runtime
    /// binding. Before WA3.3 the AUv3 skipped such an entry with `if let`, and the knob
    /// moved nothing.
    case unboundCreativeParameter(String)
}

public enum EchoelBodyVibeAUv3Mapping {

    /// The host contract, frozen since the plug-in shipped. Array order IS the host-visible
    /// tree order within each group; the addresses are literals. Do not renumber, rename or
    /// reorder: host projects and automation lanes reference these.
    public static let entries: [AUv3ParameterEntry] = [
        AUv3ParameterEntry(address: 0, identifier: "coherence",
                           target: .legacyLiveControl(.coherence), unit: .generic, group: .bio),
        AUv3ParameterEntry(address: 1, identifier: "hrv",
                           target: .legacyLiveControl(.hrv), unit: .generic, group: .bio),
        AUv3ParameterEntry(address: 2, identifier: "heartRate",
                           target: .legacyLiveControl(.heartRate), unit: .generic, group: .bio),
        AUv3ParameterEntry(address: 3, identifier: "breathPhase",
                           target: .legacyLiveControl(.breathPhase), unit: .generic, group: .bio),
        AUv3ParameterEntry(address: 4, identifier: "baseFrequency",
                           target: .creative(EchoelBodyVibeDevice.BaseID.baseFrequency),
                           unit: .hertz, group: .sound),
        AUv3ParameterEntry(address: 5, identifier: "textureAmount",
                           target: .creative(EchoelBodyVibeDevice.BaseID.textureAmount),
                           unit: .generic, group: .sound),
        AUv3ParameterEntry(address: 6, identifier: "reverbMix",
                           target: .creative(EchoelBodyVibeDevice.BaseID.reverbMix),
                           unit: .generic, group: .sound),
        AUv3ParameterEntry(address: 7, identifier: "masterGain",
                           target: .creative(EchoelBodyVibeDevice.BaseID.masterGain),
                           unit: .linearGain, group: .sound),
    ]

    /// Legacy live-control parameters are adapter-only, so their host-visible name, range and
    /// default live here, not in a descriptor.
    public static let legacyLiveControlRange: ClosedRange<Float> = 0...1
    public static let legacyLiveControlDefault: Float = 0.5

    public static func legacyName(_ control: LegacyLiveControl) -> String {
        switch control {
        case .coherence: return "Coherence"
        case .hrv: return "HRV"
        case .heartRate: return "Heart Rate"
        case .breathPhase: return "Breath Phase"
        }
    }

    /// Joins the canonical descriptors to the adapter table. Order-independent in
    /// `descriptors`; output order is `entries` order. Throws on any ambiguity.
    public static func resolve(
        descriptors: [ParameterDescriptor] = EchoelBodyVibeDevice.creativeDescriptors,
        entries: [AUv3ParameterEntry] = EchoelBodyVibeAUv3Mapping.entries
    ) throws -> [AUv3ResolvedParameter] {
        var byID: [String: ParameterDescriptor] = [:]
        for descriptor in descriptors {
            guard byID[descriptor.keyPath] == nil else {
                throw AUv3MappingError.duplicateCanonicalID(descriptor.keyPath)
            }
            byID[descriptor.keyPath] = descriptor
        }
        var addresses = Set<UInt64>()
        var identifiers = Set<String>()
        var mapped = Set<String>()
        var resolved: [AUv3ResolvedParameter] = []
        for entry in entries {
            guard addresses.insert(entry.address).inserted else {
                throw AUv3MappingError.duplicateAddress(entry.address)
            }
            guard identifiers.insert(entry.identifier).inserted else {
                throw AUv3MappingError.duplicateIdentifier(entry.identifier)
            }
            switch entry.target {
            case .creative(let id):
                guard let descriptor = byID[id] else {
                    throw AUv3MappingError.unknownCanonicalID(id)
                }
                guard mapped.insert(id).inserted else {
                    throw AUv3MappingError.duplicateCanonicalID(id)
                }
                resolved.append(AUv3ResolvedParameter(
                    address: entry.address, identifier: entry.identifier,
                    name: descriptor.displayName, min: descriptor.min, max: descriptor.max,
                    defaultValue: descriptor.defaultValue, unit: entry.unit,
                    group: entry.group, target: entry.target))
            case .legacyLiveControl(let control):
                resolved.append(AUv3ResolvedParameter(
                    address: entry.address, identifier: entry.identifier,
                    name: legacyName(control),
                    min: legacyLiveControlRange.lowerBound,
                    max: legacyLiveControlRange.upperBound,
                    defaultValue: legacyLiveControlDefault, unit: entry.unit,
                    group: entry.group, target: entry.target))
            }
        }
        for descriptor in descriptors where !mapped.contains(descriptor.keyPath) {
            throw AUv3MappingError.unmappedCreativeDescriptor(descriptor.keyPath)
        }
        return resolved
    }

    /// ⭐ WA3.3 — the runtime binding for EVERY creative host parameter, keyed by address;
    /// throws `unboundCreativeParameter` if one is missing. Legacy live controls need no
    /// creative binding and are skipped. `binder` is injectable so the failure path can be
    /// driven; production passes nothing. Control thread only (the AUv3 calls it at setup).
    public static func resolveBindings(
        _ resolved: [AUv3ResolvedParameter],
        binder: (String) -> EchoelBodyVibeDevice.Binding? = EchoelBodyVibeDevice.binding(for:)
    ) throws -> [UInt64: EchoelBodyVibeDevice.Binding] {
        var bindings: [UInt64: EchoelBodyVibeDevice.Binding] = [:]
        for r in resolved {
            guard case .creative(let id) = r.target else { continue }
            guard let binding = binder(id) else {
                throw AUv3MappingError.unboundCreativeParameter(id)
            }
            bindings[r.address] = binding
        }
        return bindings
    }
}

// MARK: - The minimal shared device state

/// A versioned, format-neutral snapshot of ONE device instance's creative state.
///
/// ⚠️ A FOUNDATION, NOT THE DEVICE. It holds the sound component (`SynthPatch` — one
/// COMPONENT of a device's state, never the whole of it) and canonical creative parameter
/// values. Mood, genre, FX chain, role mixer, modulation routes, Field settings, visual
/// response, track identity and Session automation are NOT here yet (WA3 migration map).
///
/// ⛔ NEVER HOLDS: heart rate, HRV, coherence, breath phase or any bio history, host or Session
/// transport, host automation, routing endpoints. `sanitized(against:)` keeps only keys that
/// name a creative descriptor, so a live-control name can never survive it.
///
/// ⚠️ NO PRODUCTION CALLER YET (WA3.2). The AUv3's saved state keeps its WA3.1 format; nothing
/// in the app writes this value. It is exercised by `TheParameterIdentityIsFormatNeutralTests`.
/// A future caller reads through `restored(from:into:)` and writes through `encodedForStorage()` —
/// the boundary below (P3) — never through a bare `JSONDecoder`/`JSONEncoder`
/// (`TheDeviceStateBoundaryFailsClosedTests`).
public struct EchoelDeviceState: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var deviceType: String
    public var patch: SynthPatch?
    public var parameterValues: [String: Float]

    public init(deviceType: String, patch: SynthPatch? = nil,
                parameterValues: [String: Float] = [:]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.deviceType = deviceType
        self.patch = patch
        self.parameterValues = parameterValues
    }

    /// Only creative values the descriptors name, finite, clamped to their range.
    public func sanitized(against descriptors: [ParameterDescriptor]) -> EchoelDeviceState {
        var copy = self
        var kept: [String: Float] = [:]
        for descriptor in descriptors {
            guard let value = parameterValues[descriptor.keyPath], value.isFinite else { continue }
            kept[descriptor.keyPath] = Swift.min(Swift.max(value, descriptor.min), descriptor.max)
        }
        copy.parameterValues = kept
        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, deviceType, patch, parameterValues
    }

    /// Lossy per field: an unreadable patch or value map costs only that field.
    ///
    /// ⚠️ SCHEMA VERSION (2026-09-24, P3): a MISSING key reads as `firstSchemaVersion`. Every
    /// build writes the key, so a document without it was written by hand or by something else;
    /// reading it as the oldest version is the conservative choice. A key that is PRESENT but not an
    /// integer reads as `unreadableSchemaVersion` and `validated()` refuses it. ⛔ It used to
    /// read as the CURRENT version, so a corrupted or foreign document was treated as a
    /// well-formed one of this build.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.schemaVersion) {
            self.schemaVersion = (try? c.decode(Int.self, forKey: .schemaVersion))
                ?? Self.unreadableSchemaVersion
        } else {
            self.schemaVersion = Self.firstSchemaVersion
        }
        self.deviceType = try c.decode(String.self, forKey: .deviceType)
        self.patch = try? c.decodeIfPresent(SynthPatch.self, forKey: .patch)
        self.parameterValues = (try? c.decodeIfPresent([String: Float].self,
                                                        forKey: .parameterValues)) ?? [:]
    }
}

// MARK: - The state boundary (2026-09-24, P3)

/// Why a device state was refused. Every case FAILS CLOSED: the caller keeps its current or
/// default state; nothing from the refused document becomes active.
public enum EchoelDeviceStateError: Error, Equatable, Sendable {
    /// The type names no device this build knows. Its values cannot be checked against any
    /// descriptor set, so none of them may become active.
    case unknownDeviceType(String)
    /// A known type, but not the device the state is being loaded into. Rejected, never
    /// coerced: a BodyVibe value map applied to another device would drive the wrong engine.
    case wrongDeviceType(expected: String, found: String)
    /// Written by a NEWER build. Never silently downgraded — a field this build cannot read
    /// would be dropped and the next write would erase it from the user's document.
    case futureSchema(Int)
    /// Below the first version, or present but not an integer.
    case invalidSchema(Int)
}

extension EchoelDeviceState {
    /// The first schema version. A document without the key is read as this one.
    public static let firstSchemaVersion = 1
    /// What an unreadable `schemaVersion` decodes to; below `firstSchemaVersion` on purpose.
    public static let unreadableSchemaVersion = 0

    /// The creative parameter set of a known device type, or nil for an unknown type. The ONE
    /// place a device type is resolved to the descriptors its values are checked against.
    public static func creativeDescriptors(forDeviceType type: String) -> [ParameterDescriptor]? {
        switch type {
        case EchoelBodyVibeDevice.typeID: return EchoelBodyVibeDevice.creativeDescriptors
        default: return nil
        }
    }

    /// THE MIGRATION ENTRY POINT. Brings a state of any supported older version up to
    /// `currentSchemaVersion`; refuses a future or invalid one. v1 is current, so today the only
    /// step is the identity — a new version adds its step HERE, in order, never in a caller.
    public static func migrated(_ state: EchoelDeviceState) throws -> EchoelDeviceState {
        guard state.schemaVersion >= firstSchemaVersion else {
            throw EchoelDeviceStateError.invalidSchema(state.schemaVersion)
        }
        guard state.schemaVersion <= currentSchemaVersion else {
            throw EchoelDeviceStateError.futureSchema(state.schemaVersion)
        }
        var out = state
        // (future: `if out.schemaVersion == 1 { …; out.schemaVersion = 2 }`)
        out.schemaVersion = currentSchemaVersion
        return out
    }

    /// Migrate, check the device type, then keep only finite, in-range values of that type's
    /// creative descriptors and fold the patch into its bounds. Bio and live-control names,
    /// unknown IDs and non-finite values cannot survive: no descriptor names them.
    public func validated() throws -> EchoelDeviceState {
        let current = try Self.migrated(self)
        guard let descriptors = Self.creativeDescriptors(forDeviceType: current.deviceType) else {
            throw EchoelDeviceStateError.unknownDeviceType(current.deviceType)
        }
        var out = current.sanitized(against: descriptors)
        out.patch?.clampToBounds()
        return out
    }

    /// THE READ BOUNDARY: decode, check the state belongs to the device it is loaded INTO,
    /// then `validated()`. Throws rather than returning a state that failed a check. The target
    /// type is REQUIRED (no default, #431): a loader always knows which device it is filling.
    public static func restored(from data: Data, into deviceType: String) throws -> EchoelDeviceState {
        let decoded = try JSONDecoder().decode(EchoelDeviceState.self, from: data)
        guard decoded.deviceType == deviceType else {
            throw EchoelDeviceStateError.wrongDeviceType(expected: deviceType, found: decoded.deviceType)
        }
        return try decoded.validated()
    }

    /// THE WRITE BOUNDARY: `validated()`, then encode. A state that would be refused on read is
    /// never written (and a non-finite value, which `JSONEncoder` rejects, never reaches it).
    public func encodedForStorage() throws -> Data {
        try JSONEncoder().encode(validated())
    }
}

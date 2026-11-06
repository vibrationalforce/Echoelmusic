import EchoelCore
import Foundation

/// One fader per process of a vocal chain: De-Ess, Level, Air and Space, each 0…1, each moving
/// the one or two parameters of its effect that decide that process.
///
/// Nothing is stored for it. A track gets a strip when its inserts carry the effect kinds of a
/// `VocalChain` in the chain's order — other effects may sit in between — however they got
/// there: applied from the menu or added by hand. The faders read where the sound is from the
/// effects' own values (`Control.position(from:)`), so a value changed in the effect's panel
/// moves its fader too. What a fader writes is the effects' ordinary parameters.
public struct VocalStrip: Equatable, Sendable {
    /// One process of the chain and the curve from its fader to its effect's parameters.
    public enum Control: CaseIterable, Sendable, Identifiable {
        case deEss, level, air, space

        public var id: Self { self }

        public var title: String {
            switch self {
            case .deEss: "De-Ess"
            case .level: "Level"
            case .air: "Air"
            case .space: "Space"
            }
        }

        /// One line on what the fader does, for VoiceOver.
        public var summary: String {
            switch self {
            case .deEss: "How much the de-esser takes off sharp s sounds."
            case .level: "How firmly the compressor holds the voice level, with the level given back."
            case .air: "How much brightness the high shelf adds."
            case .space: "How much of the room is heard."
            }
        }

        /// The undo step's name.
        public var actionTitle: String { "Set Vocal \(title)" }

        /// The effect whose parameters this fader moves.
        public var effect: StandardEffect {
            switch self {
            case .deEss: .deEsser
            case .level: .compressor
            case .air: .equalizer
            case .space: .reverb
            }
        }

        /// The parameter the fader is read back from: the first of `settings(at:)`.
        var lead: String {
            switch self {
            case .deEss: "range"
            case .level: "threshold"
            case .air: "highGain"
            case .space: "mix"
            }
        }

        /// The values at `position` (0…1; outside it, or not a number, is held to the nearest
        /// end), the lead parameter first. The curves:
        /// - De-Ess: range 0…12 dB and threshold −20…−40 dB, both linear — further up takes more
        ///   off, and from quieter "s" sounds.
        /// - Level: threshold −10…−30 dB, linear, and makeup 0…10 dB — half of what the threshold
        ///   went down, so the voice gets steadier without getting quieter.
        /// - Air: high shelf gain 0…+6 dB, linear.
        /// - Space: reverb mix 0…0.3 on a square law — the first half of the travel stays under
        ///   0.075, where a vocal room usually sits, so the fine range gets the most travel.
        public func settings(at position: Float) -> [VocalChain.Stage.Setting] {
            let p = VocalStrip.unit(position)
            switch self {
            case .deEss:
                return [.init(identifier: "range", value: 12 * p),
                        .init(identifier: "threshold", value: -20 - 20 * p)]
            case .level:
                return [.init(identifier: "threshold", value: -10 - 20 * p),
                        .init(identifier: "makeup", value: 10 * p)]
            case .air:
                return [.init(identifier: "highGain", value: 6 * p)]
            case .space:
                return [.init(identifier: "mix", value: 0.3 * p * p)]
            }
        }

        /// Where the fader stands for the effect's current values (`value` gives one by
        /// identifier), read from the lead parameter and held to 0…1; nil when that value is
        /// unknown or not a number.
        public func position(from value: (String) -> Float?) -> Float? {
            guard let current = value(lead), current.isFinite else { return nil }
            let place: Float
            switch self {
            case .deEss: place = current / 12
            case .level: place = (-10 - current) / 20
            case .air: place = current / 6
            case .space: place = (Swift.max(current, 0) / 0.3).squareRoot()
            }
            return VocalStrip.unit(place)
        }

        /// The same, read from the settings an insert stores; nil when it stores none for the lead
        /// parameter (a state only its Audio Unit can read, or none yet).
        public func position(in insert: Insert) -> Float? {
            guard let state = insert.state else { return nil }
            let parameters = EffectKernel.parameters(for: effect)
            var values: [String: Float] = [:]
            for stored in StandardEffectSettings.values(in: state, for: effect) {
                if let parameter = parameters.first(where: { $0.address == stored.address }) {
                    values[parameter.identifier] = stored.value
                }
            }
            return position(from: { values[$0] })
        }

        /// This process takes `stage` of a chain: the de-esser, the compressor, the equalizer
        /// that sets the high shelf (not the low cut before it), the reverb.
        func takes(_ stage: VocalChain.Stage) -> Bool {
            guard stage.effect == effect else { return false }
            if self == .air { return stage.settings.contains { $0.identifier == lead } }
            return true
        }
    }

    /// A fader of this strip and the insert it moves.
    public struct Fader: Equatable, Sendable, Identifiable {
        public let control: Control
        public let insert: InsertID
        public var id: Control { control }
    }

    /// In the chain's order; never empty.
    public let faders: [Fader]

    /// The strip for a chain of inserts, or nil when it carries no vocal chain. When more than one
    /// chain's effect kinds are present, the one with the most faders wins (a chain with its room
    /// over one without).
    public init?(inserts: [Insert]) {
        let kinds = inserts.map { StandardEffect(component: $0.plugin) }
        var best: [Fader] = []
        for chain in VocalChain.allCases {
            let stages = chain.stages
            guard let matched = Self.places(of: stages.map(\.effect), in: kinds) else { continue }
            var faders: [Fader] = []
            for (stage, place) in zip(stages, matched) {
                if let control = Control.allCases.first(where: { $0.takes(stage) }),
                   !faders.contains(where: { $0.control == control }) {
                    faders.append(Fader(control: control, insert: inserts[place].id))
                }
            }
            if faders.count > best.count { best = faders }
        }
        guard !best.isEmpty else { return nil }
        faders = best
    }

    /// The strip for `track`'s effects.
    public init?(track: Track) {
        self.init(inserts: track.inserts)
    }

    /// Where each of `wanted` sits in `kinds`, in order, each after the one before; nil when one
    /// is missing. The earliest match leaves the most room for the effects after it.
    static func places(of wanted: [StandardEffect], in kinds: [StandardEffect?]) -> [Int]? {
        var found: [Int] = []
        var next = 0
        for effect in wanted {
            guard next <= kinds.count, let index = kinds[next...].firstIndex(where: { $0 == effect }) else { return nil }
            found.append(index)
            next = index + 1
        }
        return found
    }

    /// `value` held to 0…1; not a number goes to 0. (`min(max(…))` lets NaN through.)
    static func unit(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return Swift.min(Swift.max(value, 0), 1)
    }
}

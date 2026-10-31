import Foundation

/// A third-party Audio Unit by its component identity — the three four-character codes the
/// system finds it by — plus the names shown while it is missing. A song from another device
/// keeps the reference even when the plugin is not installed here; the track then stays silent
/// and says which plugin it needs.
public struct PluginComponent: Codable, Equatable, Hashable, Sendable {
    public var type: UInt32
    public var subtype: UInt32
    public var manufacturer: UInt32
    public var name: String
    public var manufacturerName: String

    public init(type: UInt32, subtype: UInt32, manufacturer: UInt32, name: String, manufacturerName: String) {
        self.type = type
        self.subtype = subtype
        self.manufacturer = manufacturer
        self.name = name
        self.manufacturerName = manufacturerName
    }

    /// A unit is recognised by its component description — type, subtype, manufacturer — never by
    /// its names. The names are what the system reported when the song saved them and are kept as
    /// written (Law 3), but a unit renamed since (the Echoel units went from "Echoel Synth" to
    /// "Synth", 2026-10-31) is the same unit: choosing it again keeps its saved state, and a loaded
    /// unit is not reloaded because its name changed.
    public static func == (lhs: PluginComponent, rhs: PluginComponent) -> Bool {
        lhs.type == rhs.type && lhs.subtype == rhs.subtype && lhs.manufacturer == rhs.manufacturer
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(subtype)
        hasher.combine(manufacturer)
    }

    /// The name to show under the manufacturer: the unit's own name without the maker in front
    /// ("EQ" under "Echoel", where the song stores "Echoel EQ"). Derived for display, never stored.
    public var displayName: String {
        let maker = manufacturerName.trimmingCharacters(in: .whitespaces)
        guard !maker.isEmpty else { return name }
        for separator in [": ", " "] where name.hasPrefix(maker + separator) {
            let rest = name.dropFirst(maker.count + separator.count).trimmingCharacters(in: .whitespaces)
            if !rest.isEmpty { return rest }
        }
        return name
    }

    /// What the unit does, from its component type.
    public enum Role: Sendable, Equatable {
        case instrument, effect, midiEffect
    }

    /// `aumu` instrument · `aufx` effect · `aumf` music effect (plays MIDI and processes audio) ·
    /// `aumi` MIDI processor. Nil for any other type.
    public var role: Role? {
        switch type {
        case Self.code("aumu"): .instrument
        case Self.code("aufx"), Self.code("aumf"): .effect
        case Self.code("aumi"): .midiEffect
        default: nil
        }
    }

    /// The four characters of `text` as a component code; 0 when it is not exactly four ASCII
    /// characters.
    public static func code(_ text: String) -> UInt32 {
        let bytes = Array(text.utf8)
        guard bytes.count == 4, bytes.allSatisfy({ $0 < 128 }) else { return 0 }
        return bytes.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
    }

    /// The largest saved plugin state a song accepts: a plugin's settings, not its samples.
    public static let maximumStateBytes = 8 * 1_024 * 1_024
}

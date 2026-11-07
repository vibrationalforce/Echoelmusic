import AudioToolbox
import Foundation

/// The presets a loaded Audio Unit offers its host, as Echoel's plugin page lists them: the unit's
/// factory presets (a number of 0 or more) in the unit's own order, then the musician's own user
/// presets (a negative number) by name. The mirror of `InstrumentPresets`, which is the same menu
/// seen from inside Echoel's own plugin.
///
/// Main thread only: `factoryPresets`, `userPresets`, `currentPreset` and `saveUserPreset` are a
/// unit's control API, never touched by a render call. A unit that applies a preset on a thread of
/// its own does its own hop.
public enum HostedPresets {
    /// One entry of the menu. The number is the unit's own; a user preset's is negative.
    public struct Entry: Hashable, Sendable, Identifiable {
        public let number: Int
        public let name: String

        public init(number: Int, name: String) {
            self.number = number
            self.name = name
        }

        public var id: Int { number }
        public var isUser: Bool { number < 0 }
    }

    /// Factory first, in the order given, then the user presets by name. A factory entry with a
    /// negative number, a user entry with a number of 0 or more, a second entry with a number already
    /// listed and an entry without a name are dropped: the menu never offers one number twice, and
    /// never a row the musician cannot read.
    public static func menu(factory: [Entry], user: [Entry]) -> [Entry] {
        let listedFactory = factory.filter { $0.number >= 0 && named($0) }
        let sortedUser = user.filter { $0.number < 0 && named($0) }.sorted { lhs, rhs in
            let order = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            return order == .orderedSame ? lhs.number > rhs.number : order == .orderedAscending
        }
        var seen = Set<Int>()
        var merged: [Entry] = []
        for entry in listedFactory + sortedUser {
            guard !seen.contains(entry.number) else { continue }
            seen.insert(entry.number)
            merged.append(entry)
        }
        return merged
    }

    /// The entry `number` names in `menu`, nil for none or a number the menu does not list — a song
    /// saved with a preset this device's copy of the plugin no longer has.
    public static func resolve(_ number: Int?, in menu: [Entry]) -> Entry? {
        guard let number else { return nil }
        return menu.first { $0.number == number }
    }

    /// The entry `offset` places from `current` — the page's previous and next arrows — wrapping
    /// at either end. With nothing chosen (or a current preset the menu does not list) the first
    /// step forward is the first entry and the first step back the last. Nil for an empty menu.
    public static func step(from current: Entry?, by offset: Int, in menu: [Entry]) -> Entry? {
        guard !menu.isEmpty else { return nil }
        guard let current, let index = menu.firstIndex(of: current) else {
            return offset < 0 ? menu.last : menu.first
        }
        let count = menu.count
        return menu[((index + offset) % count + count) % count]
    }

    /// The number the next user preset takes: one below the lowest user number, −1 for the first.
    public static func nextUserNumber(after user: [Entry]) -> Int {
        Swift.min(user.map(\.number).min() ?? 0, 0) - 1
    }

    /// The name a typed one saves under, trimmed; nil when nothing is left.
    public static func userName(_ typed: String) -> String? {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func named(_ entry: Entry) -> Bool {
        !entry.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func entries(_ presets: [AUAudioUnitPreset]) -> [Entry] {
        presets.map { Entry(number: $0.number, name: $0.name) }
    }

    // MARK: - On a loaded unit (main thread)

    /// The unit's menu: its factory presets, and its user presets when it keeps any.
    public static func menu(of unit: AUAudioUnit) -> [Entry] {
        let user = unit.supportsUserPresets ? entries(unit.userPresets) : []
        return menu(factory: entries(unit.factoryPresets ?? []), user: user)
    }

    /// The preset the unit says it plays, when its menu lists it.
    public static func current(of unit: AUAudioUnit) -> Entry? {
        resolve(unit.currentPreset?.number, in: menu(of: unit))
    }

    /// Chooses the preset `number` names, handing the unit its OWN preset object (a unit may compare
    /// by identity). False for a number the unit does not list, which leaves it as it was.
    @discardableResult
    public static func choose(_ number: Int, on unit: AUAudioUnit) -> Bool {
        let user = unit.supportsUserPresets ? unit.userPresets : []
        let offered = number < 0 ? user : (unit.factoryPresets ?? [])
        guard let preset = offered.first(where: { $0.number == number }) else { return false }
        unit.currentPreset = preset
        return true
    }

    /// Saves the unit's current sound as a user preset named `typed`. A name the unit already keeps
    /// is saved over, under its number, as the system's preset store does by name. Nil when the unit
    /// keeps no user presets or the name is empty; throws what the unit throws.
    public static func saveUserPreset(named typed: String, on unit: AUAudioUnit) throws -> Entry? {
        guard unit.supportsUserPresets, let name = userName(typed) else { return nil }
        let existing = entries(unit.userPresets).filter { $0.number < 0 }
        let number = existing.first { $0.name == name }?.number ?? nextUserNumber(after: existing)
        let preset = AUAudioUnitPreset()
        preset.number = number
        preset.name = name
        try unit.saveUserPreset(preset)
        return Entry(number: number, name: name)
    }
}

import EchoelCore
import Foundation

/// A standard effect's settings by parameter IDENTIFIER (pairs of identifier and number), inside
/// the state an insert stores (`Insert.state`, a property list). The base Audio Unit state keeps its values by address in an
/// opaque blob only the unit itself can write; this key lets Echoel write an insert's settings
/// without loading the unit — the master suggestion builds its chain this way — and lets the unit
/// read them back (`StandardEffectUnit.fullState`). A state with both restores the blob first and
/// then these values over it, so the two can never disagree in what plays.
///
/// The key and the identifiers are stored in songs: never rename them (`EffectKernel.parameters`).
public enum StandardEffectSettings {
    public static let valuesKey = "echoel.values"

    /// The property list for `values` on `effect`: only identifiers the effect has, each a finite
    /// number clamped to its range. Nil when the list cannot be written.
    public static func state(_ values: [String: Float], for effect: StandardEffect) -> Data? {
        let settings = sanitised(values, for: effect)
        // In address order, as pairs: a dictionary's order changes from run to run, and the same
        // settings must store the same bytes (a capture compares them, `PluginStateCapture`).
        let pairs: [[Any]] = settings.map { [$0.identifier, Double($0.value)] }
        let list: [String: Any] = [valuesKey: pairs]
        return try? PropertyListSerialization.data(fromPropertyList: list, format: .binary, options: 0)
    }

    /// The settings a state carries under `valuesKey`, as (address, value), by address; empty for
    /// a state that has none.
    public static func values(in state: [String: Any], for effect: StandardEffect) -> [(address: Int, value: Float)] {
        guard let stored = state[valuesKey] as? [Any] else { return [] }
        var numbers: [String: Float] = [:]
        for case let pair as [Any] in stored {
            guard pair.count == 2, let identifier = pair[0] as? String else { continue }
            let value = pair[1]
            if let number = value as? Double { numbers[identifier] = Float(number) }
            else if let number = value as? Float { numbers[identifier] = number }
            else if let number = value as? Int { numbers[identifier] = Float(number) }
            else if let number = value as? NSNumber { numbers[identifier] = number.floatValue }
        }
        return sanitised(numbers, for: effect).map { (address: $0.address, value: $0.value) }
    }

    /// The same, read from stored data.
    public static func values(in data: Data, for effect: StandardEffect) -> [(address: Int, value: Float)] {
        guard let list = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return []
        }
        return values(in: list, for: effect)
    }

    private static func sanitised(_ values: [String: Float], for effect: StandardEffect)
        -> [(address: Int, identifier: String, value: Float)] {
        EffectKernel.parameters(for: effect).compactMap { parameter in
            guard let value = values[parameter.identifier], value.isFinite else { return nil }
            let clamped = Swift.min(Swift.max(value, parameter.range.lowerBound), parameter.range.upperBound)
            return (address: parameter.address, identifier: parameter.identifier, value: clamped)
        }
    }
}

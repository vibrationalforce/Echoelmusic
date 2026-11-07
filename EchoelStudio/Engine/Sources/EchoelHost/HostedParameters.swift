import AudioToolbox
import Foundation

/// The parameters of a loaded Audio Unit as rows the plugin page can show when the unit brings no
/// interface of its own: name, unit and range, and a named choice where the unit names its values.
/// Setting one goes through the same clamp every time, so a NaN or a value past either end never
/// reaches the unit.
///
/// Main thread only: a unit's parameter tree is its control API, never touched by a render call.
public enum HostedParameters {
    /// One parameter the musician can move: writable, with a real range.
    public struct Row: Hashable, Sendable, Identifiable {
        public let address: UInt64
        public let name: String
        /// What follows the number ("Hz", "dB"); empty for a plain amount.
        public let unitName: String
        public let range: ClosedRange<Float>
        /// The value names of a stepped parameter, the first for the range's lower end; empty for a
        /// continuous one.
        public let choices: [String]

        public init(address: UInt64, name: String, unitName: String, range: ClosedRange<Float>, choices: [String]) {
            self.address = address
            self.name = name
            self.unitName = unitName
            self.range = range
            self.choices = choices
        }

        public var id: UInt64 { address }

        /// The value inside the range, nil for one that is not a number.
        public func clamped(_ value: Float) -> Float? {
            guard value.isFinite else { return nil }
            return Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
        }

        /// The value at `position` (0…1) of the travel; a position past either end is that end, a
        /// NaN is nil.
        public func value(atPosition position: Double) -> Float? {
            guard position.isFinite else { return nil }
            let place = Float(Swift.min(Swift.max(position, 0), 1))
            return range.lowerBound + place * (range.upperBound - range.lowerBound)
        }

        /// Where `value` sits along the travel, 0…1; nil for one that is not a number.
        public func position(of value: Float) -> Double? {
            guard let inside = clamped(value) else { return nil }
            return Double((inside - range.lowerBound) / (range.upperBound - range.lowerBound))
        }

        /// The name of the choice `value` falls on, nil for a continuous parameter.
        public func choice(at value: Float) -> String? {
            guard !choices.isEmpty, let inside = clamped(value) else { return nil }
            let index = Int((inside - range.lowerBound).rounded())
            return choices.indices.contains(index) ? choices[index] : nil
        }

        /// The position of the choice at `index`, nil for one the row does not name.
        public func position(ofChoice index: Int) -> Double? {
            guard choices.indices.contains(index) else { return nil }
            return position(of: range.lowerBound + Float(index))
        }
    }

    /// The unit's writable parameters with a finite range, in the unit's order.
    public static func rows(of unit: AUAudioUnit) -> [Row] {
        (unit.parameterTree?.allParameters ?? []).compactMap(row)
    }

    /// The row for `parameter`, nil when the musician cannot move it.
    public static func row(_ parameter: AUParameter) -> Row? {
        let low = parameter.minValue, high = parameter.maxValue
        guard parameter.flags.contains(.flag_IsWritable), low.isFinite, high.isFinite, high > low else { return nil }
        return Row(address: parameter.address, name: parameter.displayName, unitName: unitName(of: parameter),
                   range: low...high, choices: choices(of: parameter))
    }

    /// The parameter's own unit name, else the short name of its standard unit.
    public static func unitName(of parameter: AUParameter) -> String {
        if let own = parameter.unitName?.trimmingCharacters(in: .whitespacesAndNewlines), !own.isEmpty { return own }
        switch parameter.unit {
        case .hertz: return "Hz"
        case .decibels: return "dB"
        case .seconds: return "s"
        case .milliseconds: return "ms"
        case .percent: return "%"
        case .cents: return "cents"
        case .octaves: return "oct"
        case .degrees: return "°"
        default: return ""
        }
    }

    /// A switch is Off and On; a stepped parameter with one name per step is its names.
    static func choices(of parameter: AUParameter) -> [String] {
        let low = parameter.minValue, high = parameter.maxValue
        if parameter.unit == .boolean, low == 0, high == 1 { return ["Off", "On"] }
        guard parameter.unit == .indexed, let names = parameter.valueStrings, !names.isEmpty,
              Float(names.count - 1) == (high - low).rounded() else { return [] }
        return names
    }

    /// Moves the parameter at `address` of `unit` to `value`, clamped to its range. Returns what it
    /// set; nil — and the unit as it was — for a NaN or a parameter the musician cannot move.
    @discardableResult
    public static func set(_ address: UInt64, to value: Float, on unit: AUAudioUnit,
                           originator: AUParameterObserverToken? = nil) -> Float? {
        guard let parameter = unit.parameterTree?.parameter(withAddress: address), let row = row(parameter),
              let target = row.clamped(value) else { return nil }
        apply(target, to: parameter, originator: originator)
        return target
    }

    /// Moves `parameter` to `position` (0…1) of its travel — a field, a mapped controller. Returns
    /// what it set; nil, and nothing changed, for a NaN or a parameter without a range.
    @discardableResult
    public static func set(_ parameter: AUParameter, toPosition position: Double,
                           originator: AUParameterObserverToken? = nil) -> Float? {
        guard let row = row(parameter), let target = row.value(atPosition: position) else { return nil }
        apply(target, to: parameter, originator: originator)
        return target
    }

    private static func apply(_ value: Float, to parameter: AUParameter, originator: AUParameterObserverToken?) {
        if let originator { parameter.setValue(value, originator: originator) } else { parameter.value = value }
    }
}

import Foundation

/// Audio node parameter definition
/// Represents a controllable parameter of an audio processing node
public struct NodeParameter: Identifiable, Sendable {
    public let id = UUID()

    /// Parameter name (unique within node)
    public let name: String

    /// Display label
    public let label: String

    /// Current value
    public var value: Float

    /// Minimum value
    public let min: Float

    /// Maximum value
    public let max: Float

    /// Default value
    public let defaultValue: Float

    /// Unit (Hz, dB, ms, %, etc.)
    public let unit: String?

    /// Whether this parameter can be automated
    public let isAutomatable: Bool

    /// Parameter type for UI rendering
    public let type: ParameterType

    public init(
        name: String,
        label: String,
        value: Float,
        min: Float,
        max: Float,
        defaultValue: Float,
        unit: String? = nil,
        isAutomatable: Bool = true,
        type: ParameterType = .continuous
    ) {
        self.name = name
        self.label = label
        self.value = value
        self.min = min
        self.max = max
        self.defaultValue = defaultValue
        self.unit = unit
        self.isAutomatable = isAutomatable
        self.type = type
    }

    public enum ParameterType: Sendable {
        case continuous  // Slider
        case discrete    // Stepped values
        case toggle      // On/off switch
        case selection   // Dropdown/picker
    }
}

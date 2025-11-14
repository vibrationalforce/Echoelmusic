import Foundation

/// Unified Control Hub Protocol
/// Central coordination point for all input/output modalities
public protocol UnifiedControlHubProtocol: AnyObject {

    /// Start the control hub
    func start()

    /// Stop the control hub
    func stop()

    /// Register an input provider
    /// - Parameter provider: Input provider to register
    func registerInput(_ provider: InputProviderProtocol)

    /// Register an output receiver
    /// - Parameter receiver: Output receiver to register
    func registerOutput(_ receiver: OutputReceiverProtocol)

    /// Enable a specific input modality
    /// - Parameter modality: Input modality to enable
    func enableInput(_ modality: InputModality) async throws

    /// Disable a specific input modality
    /// - Parameter modality: Input modality to disable
    func disableInput(_ modality: InputModality)
}

/// Input provider protocol
public protocol InputProviderProtocol: AnyObject {

    /// Input modality type
    var modality: InputModality { get }

    /// Priority level (higher = processed first)
    var priority: Int { get }

    /// Start providing input
    func start() async throws

    /// Stop providing input
    func stop()
}

/// Output receiver protocol
public protocol OutputReceiverProtocol: AnyObject {

    /// Receive control output
    /// - Parameter output: Control output data
    func receive(_ output: ControlOutput)
}

/// Input modality types
public enum InputModality: String, Sendable, CaseIterable {
    case touch = "Touch"
    case voice = "Voice"
    case gesture = "Gesture"
    case face = "Face"
    case gaze = "Gaze"
    case bio = "Biometric"
    case midi = "MIDI"
    case motion = "Motion"
}

/// Control output
public struct ControlOutput: Sendable {

    /// Output type
    public enum OutputType: Sendable {
        case audio
        case visual
        case lighting
        case haptic
    }

    public let type: OutputType
    public let timestamp: Date
    public let parameters: [String: Float]

    public init(type: OutputType, parameters: [String: Float]) {
        self.type = type
        self.timestamp = Date()
        self.parameters = parameters
    }
}

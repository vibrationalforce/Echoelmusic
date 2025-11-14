import Foundation
import AVFoundation

/// Protocol for all audio processing nodes in Echoelmusic
/// Every audio effect, generator, or processor must conform to this protocol
///
/// Design Philosophy:
/// - Each node is a self-contained audio processor
/// - Nodes can react to bio-signals in real-time
/// - Nodes are chain-able for complex signal flows
/// - Thread-safe for real-time audio processing
public protocol EchoelmusicNode: AnyObject {

    // MARK: - Identity

    /// Unique identifier for this node
    var id: UUID { get }

    /// Human-readable name
    var name: String { get }

    /// Node type (effect, generator, analyzer, etc.)
    var type: NodeType { get }


    // MARK: - State

    /// Whether this node is currently bypassed
    var isBypassed: Bool { get set }

    /// Whether this node is currently active/running
    var isActive: Bool { get }


    // MARK: - Audio Processing

    /// Process an audio buffer
    /// - Parameters:
    ///   - buffer: Input audio buffer (may be modified in-place)
    ///   - time: Audio time for synchronization
    /// - Returns: Processed audio buffer
    func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer


    // MARK: - Bio-Reactivity

    /// React to bio-signal changes (HRV, heart rate, etc.)
    /// This method is called on main thread, must be non-blocking
    /// - Parameter signal: Bio-signal data
    func react(to signal: BioSignal)


    // MARK: - Configuration

    /// Get all parameters for this node
    var parameters: [NodeParameter] { get }

    /// Set parameter value by name
    /// - Parameters:
    ///   - name: Parameter name
    ///   - value: New value
    func setParameter(name: String, value: Float)

    /// Get parameter value by name
    /// - Parameter name: Parameter name
    /// - Returns: Current value or nil if parameter doesn't exist
    func getParameter(name: String) -> Float?


    // MARK: - Lifecycle

    /// Prepare node for processing (allocate resources)
    func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount)

    /// Start processing
    func start()

    /// Stop processing
    func stop()

    /// Reset node state
    func reset()
}


// MARK: - Supporting Types

/// Node type classification
public enum NodeType: String, Codable {
    case generator  // Generates audio (oscillators, samplers)
    case effect     // Processes audio (reverb, delay, filter)
    case analyzer   // Analyzes audio (FFT, pitch detection)
    case mixer      // Mixes multiple audio sources
    case utility    // Utility functions (gain, pan, etc.)
}


/// Bio-signal data for node reactivity
public struct BioSignal {
    /// Heart rate variability (ms)
    public var hrv: Double

    /// Heart rate (BPM)
    public var heartRate: Double

    /// HRV coherence score (0-100, HeartMath)
    public var coherence: Double

    /// Respiratory rate (breaths per minute)
    public var respiratoryRate: Double?

    /// Audio level (0.0 - 1.0)
    public var audioLevel: Float

    /// Voice pitch (Hz)
    public var voicePitch: Float

    /// Custom data for extensibility
    public var customData: [String: Any]

    public init(
        hrv: Double = 0,
        heartRate: Double = 60,
        coherence: Double = 50,
        respiratoryRate: Double? = nil,
        audioLevel: Float = 0,
        voicePitch: Float = 0,
        customData: [String: Any] = [:]
    ) {
        self.hrv = hrv
        self.heartRate = heartRate
        self.coherence = coherence
        self.respiratoryRate = respiratoryRate
        self.audioLevel = audioLevel
        self.voicePitch = voicePitch
        self.customData = customData
    }
}


/// Node parameter definition
public struct NodeParameter: Identifiable {
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

    public enum ParameterType {
        case continuous  // Slider
        case discrete    // Stepped values
        case toggle      // On/off switch
        case selection   // Dropdown/picker
    }
}


/// Node manifest for serialization and loading
public struct NodeManifest: Codable {
    /// Node ID
    public let id: String

    /// Node type
    public let type: NodeType

    /// Node class name (for dynamic loading)
    public let className: String

    /// Version
    public let version: String

    /// Parameters and their current values
    public let parameters: [String: Float]

    /// Is bypassed
    public let isBypassed: Bool

    /// Custom metadata
    public let metadata: [String: String]?
}


// MARK: - Base Implementation

/// Base class for nodes with common functionality
@MainActor
public class BaseEchoelmusicNode: EchoelmusicNode {

    // MARK: - EchoelmusicNode Protocol

    public let id: UUID
    public let name: String
    public let type: NodeType

    public var isBypassed: Bool = false
    public var isActive: Bool = false

    public var parameters: [NodeParameter] = []


    // MARK: - Initialization

    public init(name: String, type: NodeType) {
        self.id = UUID()
        self.name = name
        self.type = type
    }


    // MARK: - Audio Processing (to be overridden)

    public func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        // Base implementation: pass-through
        // Subclasses should override
        return buffer
    }


    // MARK: - Bio-Reactivity (to be overridden)

    public func react(to signal: BioSignal) {
        // Base implementation: no reaction
        // Subclasses can override to implement bio-reactivity
    }


    // MARK: - Parameters

    public func setParameter(name: String, value: Float) {
        if let index = parameters.firstIndex(where: { $0.name == name }) {
            let parameter = parameters[index]
            // Clamp value to range
            let clampedValue = max(parameter.min, min(parameter.max, value))
            parameters[index].value = clampedValue
        }
    }

    public func getParameter(name: String) -> Float? {
        return parameters.first(where: { $0.name == name })?.value
    }


    // MARK: - Lifecycle (to be overridden)

    public func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        // Base implementation: no-op
        // Subclasses should override to allocate resources
    }

    public func start() {
        isActive = true
    }

    public func stop() {
        isActive = false
    }

    public func reset() {
        // Reset all parameters to default
        for i in 0..<parameters.count {
            parameters[i].value = parameters[i].defaultValue
        }
    }


    // MARK: - Serialization

    /// Create manifest for this node
    public func createManifest() -> NodeManifest {
        let parameterDict = parameters.reduce(into: [String: Float]()) { dict, param in
            dict[param.name] = param.value
        }

        return NodeManifest(
            id: id.uuidString,
            type: type,
            className: String(describing: Swift.type(of: self)),
            version: "1.0",
            parameters: parameterDict,
            isBypassed: isBypassed,
            metadata: nil
        )
    }
}

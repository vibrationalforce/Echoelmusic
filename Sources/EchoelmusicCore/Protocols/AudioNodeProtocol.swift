import Foundation
import AVFoundation

/// Core protocol for all audio processing nodes in Echoelmusic
/// Defines the fundamental contract for audio processing units
public protocol AudioNodeProtocol: AnyObject {

    // MARK: - Identity

    /// Unique identifier for this node
    var id: UUID { get }

    /// Human-readable name
    var name: String { get }

    /// Node type classification
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
    /// - Parameter signal: Bio-signal data
    func react(to signal: BioSignal)


    // MARK: - Configuration

    /// Get all parameters for this node
    var parameters: [NodeParameter] { get }

    /// Set parameter value by name
    func setParameter(name: String, value: Float)

    /// Get parameter value by name
    func getParameter(name: String) -> Float?


    // MARK: - Lifecycle

    /// Prepare node for processing
    func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount)

    /// Start processing
    func start()

    /// Stop processing
    func stop()

    /// Reset node state
    func reset()
}

/// Node type classification
public enum NodeType: String, Codable, Sendable {
    case generator  // Generates audio
    case effect     // Processes audio
    case analyzer   // Analyzes audio
    case mixer      // Mixes audio sources
    case utility    // Utility functions
}

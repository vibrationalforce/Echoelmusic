import Foundation
import AVFoundation

/// Protocol for audio engine implementations
/// Defines the contract for central audio processing coordination
public protocol AudioEngineProtocol: AnyObject {

    /// Whether the engine is currently running
    var isRunning: Bool { get }

    /// Current sample rate
    var sampleRate: Double { get }

    /// Start the audio engine
    func start() throws

    /// Stop the audio engine
    func stop()

    /// Process audio buffer through the engine
    /// - Parameter buffer: Input audio buffer
    /// - Returns: Processed buffer
    func process(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer
}

/// Audio engine configuration
public struct AudioEngineConfiguration: Sendable {

    /// Preferred sample rate (Hz)
    public let sampleRate: Double

    /// Preferred buffer size (frames)
    public let bufferSize: AVAudioFrameCount

    /// Number of input channels
    public let inputChannels: UInt32

    /// Number of output channels
    public let outputChannels: UInt32

    /// Enable low-latency mode
    public let lowLatency: Bool

    public init(
        sampleRate: Double = 48000.0,
        bufferSize: AVAudioFrameCount = 512,
        inputChannels: UInt32 = 2,
        outputChannels: UInt32 = 2,
        lowLatency: Bool = true
    ) {
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        self.inputChannels = inputChannels
        self.outputChannels = outputChannels
        self.lowLatency = lowLatency
    }
}

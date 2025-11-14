import Foundation
import Metal

/// Visual renderer protocol
/// Defines contract for rendering visual modes
public protocol VisualRendererProtocol: AnyObject {

    /// Initialize renderer with Metal device
    /// - Parameter device: MTLDevice for rendering
    func initialize(device: MTLDevice) throws

    /// Render a frame
    /// - Parameters:
    ///   - drawable: Metal drawable
    ///   - parameters: Visual parameters
    func render(drawable: MTLDrawable, parameters: VisualParameters) throws
}

/// Visual parameters for rendering
public struct VisualParameters: Sendable {

    /// Audio level (0-1)
    public var audioLevel: Float

    /// Frequency data (FFT bins)
    public var frequencies: [Float]

    /// HRV coherence (0-100)
    public var coherence: Float

    /// Heart rate (BPM)
    public var heartRate: Float

    /// Time delta for animations
    public var deltaTime: Float

    /// Custom parameters
    public var customParameters: [String: Float]

    public init(
        audioLevel: Float = 0,
        frequencies: [Float] = [],
        coherence: Float = 50,
        heartRate: Float = 60,
        deltaTime: Float = 0.016,
        customParameters: [String: Float] = [:]
    ) {
        self.audioLevel = audioLevel
        self.frequencies = frequencies
        self.coherence = coherence
        self.heartRate = heartRate
        self.deltaTime = deltaTime
        self.customParameters = customParameters
    }
}

/// Visual rendering mode
public enum VisualMode: String, CaseIterable, Sendable {
    case particles = "Particles"
    case cymatics = "Cymatics"
    case waveform = "Waveform"
    case spectral = "Spectral"
    case mandala = "Mandala"
    case xr = "XR"
}

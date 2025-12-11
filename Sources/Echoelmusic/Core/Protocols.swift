// Protocols.swift
// Echoelmusic - Architecture Protocol Definitions
// Wise Mode Implementation

import Foundation
import AVFoundation
import Combine
import simd

// MARK: - Audio Processing Protocols

/// Protocol for all audio processing nodes
public protocol AudioProcessable {
    /// Input audio format
    var inputFormat: AVAudioFormat? { get }

    /// Output audio format
    var outputFormat: AVAudioFormat? { get }

    /// Process an audio buffer
    func process(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer?

    /// Reset internal state
    func reset()

    /// Bypass processing
    var isBypassed: Bool { get set }
}

/// Protocol for audio nodes with parameters
public protocol Parameterizable {
    associatedtype ParameterType: Hashable

    /// Current parameter values
    var parameters: [ParameterType: Float] { get }

    /// Set a parameter value
    func setParameter(_ param: ParameterType, value: Float)

    /// Get a parameter value
    func getParameter(_ param: ParameterType) -> Float

    /// Get parameter range
    func getParameterRange(_ param: ParameterType) -> ClosedRange<Float>

    /// Reset parameters to defaults
    func resetParameters()
}

/// Protocol for components that respond to audio input
public protocol AudioReactive {
    /// Update with audio level (0.0-1.0)
    func onAudioLevel(_ level: Float)

    /// Update with frequency spectrum data
    func onSpectrum(_ bins: [Float])

    /// Update with waveform data
    func onWaveform(_ samples: [Float])
}

// MARK: - Biofeedback Protocols

/// Protocol for components that respond to biofeedback
public protocol BioReactive {
    /// Called when heart rate updates
    func onHeartRateUpdate(_ bpm: Double)

    /// Called when HRV (RMSSD) updates
    func onHRVUpdate(_ rmssd: Double)

    /// Called when coherence score updates
    func onCoherenceUpdate(_ score: Double)
}

/// Protocol for biofeedback data sources
public protocol BiofeedbackSource {
    /// Whether the source is currently active
    var isActive: Bool { get }

    /// Start collecting biofeedback data
    func start() async throws

    /// Stop collecting biofeedback data
    func stop()

    /// Current heart rate in BPM
    var heartRate: Double { get }

    /// Current HRV (RMSSD) in milliseconds
    var hrv: Double { get }

    /// Current coherence score (0-100)
    var coherence: Double { get }

    /// Publisher for heart rate updates
    var heartRatePublisher: AnyPublisher<Double, Never> { get }
}

// MARK: - MIDI Protocols

/// Protocol for MIDI input handlers
public protocol MIDIInputHandler {
    /// Handle note on event
    func handleNoteOn(note: UInt8, velocity: UInt8, channel: UInt8)

    /// Handle note off event
    func handleNoteOff(note: UInt8, channel: UInt8)

    /// Handle control change
    func handleControlChange(controller: UInt8, value: UInt8, channel: UInt8)

    /// Handle pitch bend
    func handlePitchBend(value: UInt16, channel: UInt8)

    /// Handle aftertouch
    func handleAftertouch(pressure: UInt8, channel: UInt8)
}

/// Protocol for MIDI output
public protocol MIDIOutputProvider {
    /// Send note on
    func sendNoteOn(note: UInt8, velocity: UInt8, channel: UInt8)

    /// Send note off
    func sendNoteOff(note: UInt8, channel: UInt8)

    /// Send control change
    func sendControlChange(controller: UInt8, value: UInt8, channel: UInt8)

    /// Send pitch bend
    func sendPitchBend(value: UInt16, channel: UInt8)
}

/// Protocol for MPE-aware components
public protocol MPEAware {
    /// Zone configuration
    var mpeZone: MPEZone { get set }

    /// Per-note pitch bend range in semitones
    var pitchBendRange: Int { get set }

    /// Handle per-note pitch bend
    func handlePerNotePitchBend(note: UInt8, bend: Float, channel: UInt8)

    /// Handle per-note pressure
    func handlePerNotePressure(note: UInt8, pressure: Float, channel: UInt8)

    /// Handle per-note slide (CC74)
    func handlePerNoteSlide(note: UInt8, slide: Float, channel: UInt8)
}

/// MPE Zone configuration
public struct MPEZone {
    public let masterChannel: UInt8
    public let memberChannels: ClosedRange<UInt8>
    public let pitchBendRange: Int

    public init(masterChannel: UInt8 = 0, memberChannels: ClosedRange<UInt8> = 1...15, pitchBendRange: Int = 48) {
        self.masterChannel = masterChannel
        self.memberChannels = memberChannels
        self.pitchBendRange = pitchBendRange
    }
}

// MARK: - Spatial Audio Protocols

/// Protocol for spatial audio sources
public protocol SpatialSource: AnyObject {
    /// Unique identifier
    var id: String { get }

    /// 3D position
    var position: SIMD3<Float> { get set }

    /// Audio gain (0.0-1.0)
    var gain: Float { get set }

    /// Update position with animation
    func moveTo(_ position: SIMD3<Float>, duration: TimeInterval)
}

/// Protocol for spatial audio renderers
public protocol SpatialRenderer {
    /// Current spatial mode
    var mode: SpatialMode { get set }

    /// Listener position
    var listenerPosition: SIMD3<Float> { get set }

    /// Listener orientation (quaternion)
    var listenerOrientation: simd_quatf { get set }

    /// Add a spatial source
    func addSource(_ source: SpatialSource)

    /// Remove a spatial source
    func removeSource(_ source: SpatialSource)

    /// Update rendering (call each frame)
    func update()
}

// MARK: - Visual Protocols

/// Protocol for visualization renderers
public protocol VisualizationRenderer {
    /// Render a frame
    func render(to texture: MTLTexture, audioData: [Float])

    /// Update parameters
    func setParameter(_ name: String, value: Float)

    /// Reset state
    func reset()
}

/// Protocol for components that can be visualized
public protocol Visualizable {
    /// Get current visualization data
    func getVisualizationData() -> VisualizationData
}

/// Visualization data container
public struct VisualizationData {
    public let waveform: [Float]
    public let spectrum: [Float]
    public let level: Float
    public let dominantFrequency: Float

    public init(waveform: [Float] = [], spectrum: [Float] = [], level: Float = 0, dominantFrequency: Float = 0) {
        self.waveform = waveform
        self.spectrum = spectrum
        self.level = level
        self.dominantFrequency = dominantFrequency
    }
}

// MARK: - LED Control Protocols

/// Protocol for LED controllers
public protocol LEDController {
    /// Number of LEDs
    var ledCount: Int { get }

    /// Set all LEDs to a single color
    func setAllColor(_ color: RGBColor)

    /// Set individual LED color
    func setLEDColor(index: Int, color: RGBColor)

    /// Set multiple LED colors
    func setColors(_ colors: [RGBColor])

    /// Clear all LEDs
    func clear()

    /// Refresh/send update
    func refresh()
}

/// RGB color structure
public struct RGBColor: Equatable {
    public let r: UInt8
    public let g: UInt8
    public let b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    public static let black = RGBColor(r: 0, g: 0, b: 0)
    public static let white = RGBColor(r: 255, g: 255, b: 255)
    public static let red = RGBColor(r: 255, g: 0, b: 0)
    public static let green = RGBColor(r: 0, g: 255, b: 0)
    public static let blue = RGBColor(r: 0, g: 0, b: 255)
}

/// Protocol for bio-reactive LED patterns
public protocol BioReactiveLED: LEDController, BioReactive {
    /// Set the reactive mode
    var reactiveMode: LEDReactiveMode { get set }
}

/// LED reactive modes
public enum LEDReactiveMode {
    case heartRate      // Pulse with heart rate
    case coherence      // Color based on coherence
    case hrv            // Intensity based on HRV
    case combined       // All factors combined
}

// MARK: - Input Protocols

/// Protocol for input sources
public protocol InputSource {
    /// Input source identifier
    var sourceId: String { get }

    /// Input priority (higher = more important)
    var priority: Int { get }

    /// Whether the source is active
    var isActive: Bool { get }

    /// Start receiving input
    func start() async throws

    /// Stop receiving input
    func stop()
}

/// Protocol for gesture recognition
public protocol GestureRecognizer {
    /// Recognized gesture publisher
    var gesturePublisher: AnyPublisher<GestureEventType, Never> { get }

    /// Start recognition
    func startRecognition() async throws

    /// Stop recognition
    func stopRecognition()
}

/// Protocol for face tracking
public protocol FaceTracker {
    /// Whether tracking is active
    var isTracking: Bool { get }

    /// Current face blend shapes
    var blendShapes: [String: Float] { get }

    /// Face position
    var facePosition: SIMD3<Float> { get }

    /// Face orientation
    var faceOrientation: simd_quatf { get }

    /// Blend shapes publisher
    var blendShapesPublisher: AnyPublisher<[String: Float], Never> { get }

    /// Start tracking
    func startTracking() async throws

    /// Stop tracking
    func stopTracking()
}

// MARK: - Recording Protocols

/// Protocol for recording sessions
public protocol RecordingSession {
    /// Session identifier
    var id: String { get }

    /// Session name
    var name: String { get set }

    /// Creation date
    var createdAt: Date { get }

    /// Session duration
    var duration: TimeInterval { get }

    /// Tracks in this session
    var tracks: [RecordingTrack] { get }

    /// Add a new track
    func addTrack() -> RecordingTrack

    /// Remove a track
    func removeTrack(_ track: RecordingTrack)

    /// Export the session
    func export(format: AudioExportFormat) async throws -> URL
}

/// Protocol for recording tracks
public protocol RecordingTrack {
    /// Track identifier
    var id: String { get }

    /// Track name
    var name: String { get set }

    /// Track volume (0.0-1.0)
    var volume: Float { get set }

    /// Track pan (-1.0 to 1.0)
    var pan: Float { get set }

    /// Whether track is muted
    var isMuted: Bool { get set }

    /// Whether track is soloed
    var isSoloed: Bool { get set }

    /// Audio file URL
    var audioURL: URL? { get }
}

/// Audio export formats
public enum AudioExportFormat: String, CaseIterable {
    case wav = "WAV"
    case aiff = "AIFF"
    case m4a = "M4A"
    case mp3 = "MP3"
    case flac = "FLAC"
}

// MARK: - Lifecycle Protocols

/// Protocol for components with lifecycle management
public protocol LifecycleManaged {
    /// Initialize the component
    func initialize() async throws

    /// Prepare for use
    func prepare()

    /// Cleanup resources
    func cleanup()

    /// Handle memory warning
    func handleMemoryWarning()
}

/// Protocol for pausable components
public protocol Pausable {
    /// Whether component is paused
    var isPaused: Bool { get }

    /// Pause the component
    func pause()

    /// Resume the component
    func resume()
}

// MARK: - Serialization Protocols

/// Protocol for saveable state
public protocol StatePersistable {
    associatedtype State: Codable

    /// Get current state
    func getState() -> State

    /// Restore from state
    func restoreState(_ state: State) throws
}

/// Protocol for preset management
public protocol PresetManageable {
    associatedtype Preset: Codable & Identifiable

    /// Available presets
    var presets: [Preset] { get }

    /// Current preset
    var currentPreset: Preset? { get }

    /// Load a preset
    func loadPreset(_ preset: Preset)

    /// Save current state as preset
    func saveAsPreset(name: String) -> Preset

    /// Delete a preset
    func deletePreset(_ preset: Preset)
}

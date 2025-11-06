import Foundation

/// Central configuration for Echoelmusic app
/// Replaces hardcoded values with configurable constants
public struct AppConfiguration {

    // MARK: - Control Loop Configuration

    /// Target frequency for UnifiedControlHub update loop
    public static let controlLoopFrequency: Double = 60.0 // 60 Hz

    /// Control loop queue QoS
    public static let controlLoopQoS: DispatchQoS.QoSClass = .userInteractive


    // MARK: - Audio Processing Configuration

    public struct Audio {
        /// Default sample rate for audio processing
        public static let sampleRate: Double = 48000.0

        /// Buffer size for real-time audio processing
        public static let bufferSize: AVAudioFrameCount = 512

        /// Maximum number of audio channels
        public static let maxChannels: Int = 2

        /// Master volume range
        public static let volumeRange: ClosedRange<Float> = 0.0...1.0

        /// FFT size for frequency analysis
        public static let fftSize: Int = 2048
    }


    // MARK: - Filter Configuration

    public struct Filter {
        /// Minimum cutoff frequency (Hz)
        public static let minFrequency: Float = 200.0

        /// Maximum cutoff frequency (Hz)
        public static let maxFrequency: Float = 8000.0

        /// Default cutoff frequency (Hz)
        public static let defaultFrequency: Float = 1000.0

        /// Minimum resonance (Q factor)
        public static let minResonance: Float = 0.5

        /// Maximum resonance (Q factor)
        public static let maxResonance: Float = 10.0

        /// Default resonance (Q factor)
        public static let defaultResonance: Float = 0.707
    }


    // MARK: - Biofeedback Configuration

    public struct Biofeedback {
        /// Heart rate ranges (BPM)
        public static let minHeartRate: Double = 40.0
        public static let maxHeartRate: Double = 180.0
        public static let normalHeartRate: Double = 70.0

        /// HRV coherence thresholds (0-100)
        public static let lowCoherenceThreshold: Double = 40.0
        public static let highCoherenceThreshold: Double = 60.0

        /// Breathing rate ranges (breaths per minute)
        public static let minBreathingRate: Double = 4.0
        public static let maxBreathingRate: Double = 30.0
        public static let optimalBreathingRate: Double = 6.0

        /// HRV buffer size (number of RR intervals)
        public static let hrvBufferSize: Int = 120

        /// Minimum samples needed for coherence calculation
        public static let minCoherenceSamples: Int = 30

        /// Minimum samples needed for breathing rate calculation
        public static let minBreathingRateSamples: Int = 40

        /// Respiratory frequency band (Hz)
        public static let respiratoryBandLow: Double = 0.15  // 9 breaths/min
        public static let respiratoryBandHigh: Double = 0.4  // 24 breaths/min
    }


    // MARK: - Spatial Audio Configuration

    public struct SpatialAudio {
        /// Number of spatial audio sources
        public static let maxSources: Int = 16

        /// Head tracking update frequency (Hz)
        public static let headTrackingFrequency: Double = 60.0

        /// Spatial audio modes
        public enum Mode: String, CaseIterable {
            case stereo = "Stereo"
            case threeD = "3D"
            case fourD = "4D Orbital"
            case afa = "AFA"
            case binaural = "Binaural"
            case ambisonics = "Ambisonics"
        }

        /// AFA field geometries
        public static let afaGeometries = ["grid", "circle", "fibonacci"]
    }


    // MARK: - MIDI Configuration

    public struct MIDI {
        /// MIDI 2.0 enabled by default
        public static let midi2Enabled: Bool = true

        /// MPE zone configuration
        public static let mpeMemberChannels: Int = 15

        /// Pitch bend range (semitones)
        public static let pitchBendRange: Int = 48  // ±4 octaves

        /// Per-note brightness CC
        public static let brightnessCCIndex: Int = 74

        /// Per-note timbre CC
        public static let timbreCCIndex: Int = 71
    }


    // MARK: - LED/Lighting Configuration

    public struct Lighting {
        /// DMX universe size
        public static let dmxUniverseSize: Int = 512

        /// Art-Net default address
        public static let artNetAddress: String = "192.168.1.100"

        /// Art-Net port
        public static let artNetPort: UInt16 = 6454

        /// LED update rate (Hz)
        public static let ledUpdateRate: Double = 30.0

        /// Push 3 LED grid size
        public static let push3GridSize: (rows: Int, cols: Int) = (8, 8)
    }


    // MARK: - Visual Configuration

    public struct Visual {
        /// Visualization modes
        public enum Mode: String, CaseIterable {
            case cymatics = "Cymatics"
            case mandala = "Mandala"
            case waveform = "Waveform"
            case spectral = "Spectral"
            case particles = "Particles"
        }

        /// Frame rate for visual rendering
        public static let targetFrameRate: Int = 60

        /// Particle system max particles
        public static let maxParticles: Int = 1000
    }


    // MARK: - Recording Configuration

    public struct Recording {
        /// Maximum number of tracks per session
        public static let maxTracksPerSession: Int = 8

        /// Default recording format
        public static let defaultFormat: RecordingFormat = .wav

        /// Default bit depth
        public static let defaultBitDepth: Int = 24

        /// Default sample rate for recording
        public static let defaultSampleRate: Double = 48000.0

        public enum RecordingFormat: String {
            case wav = "WAV"
            case aiff = "AIFF"
            case caf = "CAF"
        }

        /// Session storage path
        public static let sessionStoragePath = "sessions"
    }


    // MARK: - Performance Configuration

    public struct Performance {
        /// Enable performance monitoring
        public static let enablePerfMonitoring: Bool = true

        /// Memory warning threshold (MB)
        public static let memoryWarningThreshold: Int = 150

        /// CPU usage warning threshold (%)
        public static let cpuWarningThreshold: Double = 80.0
    }


    // MARK: - Debug Configuration

    public struct Debug {
        /// Enable debug logging
        public static let enableDebugLogging: Bool = false

        /// Enable performance metrics logging
        public static let enablePerfLogging: Bool = false

        /// Enable parameter change logging
        public static let enableParameterLogging: Bool = false
    }


    // MARK: - Network Configuration

    public struct Network {
        /// UDP socket timeout (seconds)
        public static let udpTimeout: TimeInterval = 5.0

        /// Network queue QoS
        public static let networkQoS: DispatchQoS.QoSClass = .userInitiated
    }


    // MARK: - UI Configuration

    public struct UI {
        /// Default color scheme
        public static let defaultColorScheme: ColorScheme = .dark

        /// Animation duration (seconds)
        public static let animationDuration: Double = 0.3

        /// Haptic feedback enabled
        public static let hapticFeedbackEnabled: Bool = true

        public enum ColorScheme {
            case light
            case dark
            case auto
        }
    }


    // MARK: - Environment

    /// Current app environment
    public enum Environment {
        case development
        case staging
        case production

        var name: String {
            switch self {
            case .development: return "Development"
            case .staging: return "Staging"
            case .production: return "Production"
            }
        }
    }

    #if DEBUG
    public static let currentEnvironment: Environment = .development
    #else
    public static let currentEnvironment: Environment = .production
    #endif


    // MARK: - Feature Flags

    public struct FeatureFlags {
        /// Enable AI composition layer (Phase 5)
        public static let enableAIComposition: Bool = false

        /// Enable cloud sync
        public static let enableCloudSync: Bool = false

        /// Enable gaze tracking
        public static let enableGazeTracking: Bool = false

        /// Enable advanced spatial audio (iOS 19+)
        public static let enableAdvancedSpatialAudio: Bool = false
    }
}

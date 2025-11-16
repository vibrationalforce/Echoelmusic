import Foundation
import SwiftUI
import Combine
import simd

/// Central coordinator for biometric-to-visual mappings
/// Transforms physiological signals into visual parameters in real-time
///
/// **Mappings:**
/// - Heart Rate → Color Hue (Red @ rest → Purple @ elevated)
/// - HRV Coherence → Particle Count & Behavior
/// - Breathing Rate → Fractal Generation Speed
/// - Stress Level → Visual Intensity
///
/// **Usage:**
/// ```swift
/// let mapper = BiometricVisualMapper(healthKitManager: healthKitManager)
/// mapper.startMapping()
///
/// // Access mapped parameters
/// let particleConfig = mapper.particleConfiguration
/// let colorScheme = mapper.colorScheme
/// ```
@MainActor
public class BiometricVisualMapper: ObservableObject {

    // MARK: - Published State

    /// Current particle system configuration based on HRV
    @Published public private(set) var particleConfiguration: ParticleConfiguration

    /// Current color scheme based on heart rate
    @Published public private(set) var colorScheme: BiometricColorScheme

    /// Current fractal parameters based on breathing
    @Published public private(set) var fractalParameters: FractalParameters

    /// Visual intensity (0.0 - 1.0) based on overall arousal
    @Published public private(set) var visualIntensity: Double = 0.5

    /// Whether mapping is active
    @Published public private(set) var isActive: Bool = false

    // MARK: - Dependencies

    private let healthKitManager: HealthKitManager?
    private let breathingDetector: BreathingRateDetector

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Update Timer

    private var updateTimer: Timer?
    private let updateFrequency: TimeInterval = 1.0 / 30.0 // 30 Hz

    // MARK: - Initialization

    public init(healthKitManager: HealthKitManager? = nil) {
        self.healthKitManager = healthKitManager
        self.breathingDetector = BreathingRateDetector()

        // Initialize with default configurations
        self.particleConfiguration = ParticleConfiguration()
        self.colorScheme = BiometricColorScheme()
        self.fractalParameters = FractalParameters()

        setupHealthKitObservation()
    }

    // MARK: - Public Methods

    /// Start real-time biometric-to-visual mapping
    public func startMapping() {
        guard !isActive else { return }

        isActive = true
        breathingDetector.startDetection(healthKitManager: healthKitManager)

        // Start 30 Hz update loop
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateFrequency, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMappings()
            }
        }

        print("🎨 BiometricVisualMapper: Mapping started")
    }

    /// Stop mapping
    public func stopMapping() {
        isActive = false
        updateTimer?.invalidate()
        updateTimer = nil
        breathingDetector.stopDetection()

        print("🎨 BiometricVisualMapper: Mapping stopped")
    }

    // MARK: - Private Methods

    private func setupHealthKitObservation() {
        guard let healthKitManager = healthKitManager else { return }

        // Observe heart rate changes
        healthKitManager.$heartRate
            .sink { [weak self] heartRate in
                self?.updateColorScheme(heartRate: heartRate)
            }
            .store(in: &cancellables)

        // Observe HRV coherence changes
        healthKitManager.$hrvCoherence
            .sink { [weak self] coherence in
                self?.updateParticleConfiguration(coherence: coherence)
            }
            .store(in: &cancellables)
    }

    private func updateMappings() {
        guard let healthKitManager = healthKitManager else { return }

        let heartRate = healthKitManager.heartRate
        let hrvCoherence = healthKitManager.hrvCoherence
        let breathingRate = breathingDetector.currentBreathingRate

        // Update all mappings
        updateColorScheme(heartRate: heartRate)
        updateParticleConfiguration(coherence: hrvCoherence)
        updateFractalParameters(breathingRate: breathingRate)
        updateVisualIntensity(heartRate: heartRate, coherence: hrvCoherence)
    }

    /// Map heart rate to color hue (0-360 degrees)
    /// Rest (50-70 BPM) = Blue-Green (180-210°)
    /// Normal (70-90 BPM) = Green-Yellow (120-60°)
    /// Elevated (90-120 BPM) = Orange-Red (30-0°)
    /// High (120+ BPM) = Red-Purple (360-300°)
    private func updateColorScheme(heartRate: Double) {
        let hue: Double
        let saturation: Double
        let brightness: Double

        switch heartRate {
        case 0..<50:
            // Very low (unusual) - Deep blue
            hue = 240
            saturation = 0.7
            brightness = 0.6

        case 50..<70:
            // Resting - Blue-green (calm)
            let t = (heartRate - 50) / 20
            hue = 240 - (t * 60) // 240° → 180° (blue → cyan)
            saturation = 0.6 + (t * 0.2) // 0.6 → 0.8
            brightness = 0.7 + (t * 0.1) // 0.7 → 0.8

        case 70..<90:
            // Normal - Green-yellow (balanced)
            let t = (heartRate - 70) / 20
            hue = 180 - (t * 120) // 180° → 60° (cyan → yellow)
            saturation = 0.7 + (t * 0.1) // 0.7 → 0.8
            brightness = 0.8

        case 90..<120:
            // Elevated - Orange-red (active)
            let t = (heartRate - 90) / 30
            hue = 60 - (t * 60) // 60° → 0° (yellow → red)
            saturation = 0.8
            brightness = 0.85 + (t * 0.1) // 0.85 → 0.95

        case 120...:
            // High - Red-purple (intense)
            let t = min((heartRate - 120) / 30, 1.0)
            hue = 360 - (t * 60) // 360° → 300° (red → magenta)
            saturation = 0.85 + (t * 0.1) // 0.85 → 0.95
            brightness = 0.9 + (t * 0.1) // 0.9 → 1.0

        default:
            hue = 180
            saturation = 0.7
            brightness = 0.8
        }

        colorScheme = BiometricColorScheme(
            hue: hue,
            saturation: saturation,
            brightness: brightness,
            heartRate: heartRate
        )
    }

    /// Map HRV coherence to particle behavior
    /// Low coherence (0-40) = Chaotic, scattered particles
    /// Medium coherence (40-60) = Organized patterns
    /// High coherence (60-100) = Harmonious, flowing motion
    private func updateParticleConfiguration(coherence: Double) {
        let count: Int
        let speed: Float
        let coherenceFactor: Float
        let attractorStrength: Float

        switch coherence {
        case 0..<40:
            // Low coherence - Many chaotic particles
            count = 800 + Int((40 - coherence) * 5)
            speed = 2.5 + Float((40 - coherence) / 40) * 2.0 // 2.5 → 4.5
            coherenceFactor = 0.1 + Float(coherence / 40) * 0.3 // 0.1 → 0.4
            attractorStrength = 0.05

        case 40..<60:
            // Medium coherence - Organized patterns
            count = 600 + Int((coherence - 40) * 5)
            speed = 1.8 + Float((coherence - 40) / 20) * 0.7 // 1.8 → 2.5
            coherenceFactor = 0.4 + Float((coherence - 40) / 20) * 0.3 // 0.4 → 0.7
            attractorStrength = 0.15

        case 60...:
            // High coherence - Harmonious flow
            let t = min((coherence - 60) / 40, 1.0)
            count = 400 + Int(t * 200)
            speed = 1.2 + Float(t) * 0.6 // 1.2 → 1.8
            coherenceFactor = 0.7 + Float(t) * 0.3 // 0.7 → 1.0
            attractorStrength = 0.25 + Float(t) * 0.25 // 0.25 → 0.5

        default:
            count = 500
            speed = 2.0
            coherenceFactor = 0.5
            attractorStrength = 0.2
        }

        particleConfiguration = ParticleConfiguration(
            particleCount: count,
            baseSpeed: speed,
            coherenceFactor: coherenceFactor,
            attractorStrength: attractorStrength,
            hrvCoherence: coherence
        )
    }

    /// Map breathing rate to fractal generation
    /// Slow breathing (4-8 BPM) = Slow, deep fractals
    /// Normal breathing (12-16 BPM) = Balanced generation
    /// Fast breathing (20+ BPM) = Rapid, energetic fractals
    private func updateFractalParameters(breathingRate: Double) {
        let iterationSpeed: Double
        let complexity: Int
        let depth: Int

        switch breathingRate {
        case 0..<8:
            // Slow breathing - Deep, meditative fractals
            iterationSpeed = 0.3 + (breathingRate / 8) * 0.4 // 0.3 → 0.7
            complexity = 4 + Int(breathingRate / 2) // 4 → 8
            depth = 6 + Int(breathingRate / 2) // 6 → 10

        case 8..<16:
            // Normal breathing - Balanced fractals
            let t = (breathingRate - 8) / 8
            iterationSpeed = 0.7 + t * 0.5 // 0.7 → 1.2
            complexity = 8 + Int(t * 4) // 8 → 12
            depth = 5 + Int(t * 3) // 5 → 8

        case 16...:
            // Fast breathing - Rapid, energetic fractals
            let t = min((breathingRate - 16) / 10, 1.0)
            iterationSpeed = 1.2 + t * 0.8 // 1.2 → 2.0
            complexity = 10 + Int(t * 6) // 10 → 16
            depth = 4 + Int(t * 2) // 4 → 6

        default:
            iterationSpeed = 1.0
            complexity = 8
            depth = 6
        }

        fractalParameters = FractalParameters(
            iterationSpeed: iterationSpeed,
            complexity: complexity,
            depth: depth,
            breathingRate: breathingRate
        )
    }

    /// Calculate overall visual intensity from multiple biometric signals
    private func updateVisualIntensity(heartRate: Double, coherence: Double) {
        // Normalize heart rate (50-150 BPM → 0.0-1.0)
        let hrIntensity = min(max((heartRate - 50) / 100, 0.0), 1.0)

        // Normalize coherence (0-100 → 0.0-1.0)
        let coherenceIntensity = coherence / 100

        // Weighted average (70% HR, 30% coherence)
        visualIntensity = (hrIntensity * 0.7) + (coherenceIntensity * 0.3)
    }
}

// MARK: - Configuration Models

/// Particle system configuration
public struct ParticleConfiguration {
    public var particleCount: Int
    public var baseSpeed: Float
    public var coherenceFactor: Float  // How organized the motion is (0.0 - 1.0)
    public var attractorStrength: Float  // Strength of attractor points
    public var hrvCoherence: Double

    public init(
        particleCount: Int = 500,
        baseSpeed: Float = 2.0,
        coherenceFactor: Float = 0.5,
        attractorStrength: Float = 0.2,
        hrvCoherence: Double = 50.0
    ) {
        self.particleCount = particleCount
        self.baseSpeed = baseSpeed
        self.coherenceFactor = coherenceFactor
        self.attractorStrength = attractorStrength
        self.hrvCoherence = hrvCoherence
    }
}

/// Color scheme derived from biometrics
public struct BiometricColorScheme {
    public var hue: Double          // 0-360 degrees
    public var saturation: Double   // 0.0-1.0
    public var brightness: Double   // 0.0-1.0
    public var heartRate: Double

    public init(
        hue: Double = 180.0,
        saturation: Double = 0.7,
        brightness: Double = 0.8,
        heartRate: Double = 70.0
    ) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        self.heartRate = heartRate
    }

    /// Convert to SwiftUI Color
    public var color: Color {
        Color(hue: hue / 360.0, saturation: saturation, brightness: brightness)
    }

    /// Generate complementary color
    public var complementaryColor: Color {
        let complementaryHue = (hue + 180).truncatingRemainder(dividingBy: 360)
        return Color(hue: complementaryHue / 360.0, saturation: saturation, brightness: brightness)
    }

    /// Generate triadic colors
    public var triadicColors: [Color] {
        [
            color,
            Color(hue: ((hue + 120).truncatingRemainder(dividingBy: 360)) / 360.0, saturation: saturation, brightness: brightness),
            Color(hue: ((hue + 240).truncatingRemainder(dividingBy: 360)) / 360.0, saturation: saturation, brightness: brightness)
        ]
    }
}

/// Fractal generation parameters
public struct FractalParameters {
    public var iterationSpeed: Double  // How fast the fractal evolves
    public var complexity: Int         // Number of iterations
    public var depth: Int              // Recursion depth
    public var breathingRate: Double

    public init(
        iterationSpeed: Double = 1.0,
        complexity: Int = 8,
        depth: Int = 6,
        breathingRate: Double = 12.0
    ) {
        self.iterationSpeed = iterationSpeed
        self.complexity = complexity
        self.depth = depth
        self.breathingRate = breathingRate
    }
}

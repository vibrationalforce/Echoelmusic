import Foundation
import Combine

/// Maps gaze tracking data to audio parameters
/// Gaze direction controls filter cutoff, reverb, spatial position, etc.
@MainActor
class GazeToAudioMapper: ObservableObject {

    // MARK: - Published State

    /// Whether gaze mapping is enabled
    @Published var isEnabled: Bool = false

    /// Current mapped filter cutoff (Hz)
    @Published var filterCutoff: Float = 1000.0

    /// Current mapped reverb size
    @Published var reverbSize: Float = 0.5

    /// Current mapped spatial position
    @Published var spatialPosition: SIMD3<Float> = .zero

    /// Current mapped parameter value (0.0-1.0, for custom mapping)
    @Published var customParameter: Float = 0.5

    // MARK: - Dependencies

    private var gazeTracker: GazeTrackingManager?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Mapping Parameters

    /// Filter cutoff range (min, max in Hz)
    private var filterRange: (min: Float, max: Float) = (200.0, 8000.0)

    /// Reverb size range (0.0-1.0)
    private var reverbRange: (min: Float, max: Float) = (0.0, 1.0)

    /// Spatial position range (meters)
    private var spatialRange: Float = 2.0

    // MARK: - Mapping Modes

    private var mappingMode: MappingMode = .filterCutoff

    enum MappingMode {
        case filterCutoff       // Horizontal gaze → filter cutoff
        case reverbSize         // Vertical gaze → reverb size
        case spatialPosition    // Gaze direction → 3D sound position
        case custom             // User-defined mapping
    }

    // MARK: - Initialization

    init() {
        // Will be connected to GazeTrackingManager later
    }

    // MARK: - Setup

    func connect(gazeTracker: GazeTrackingManager) {
        self.gazeTracker = gazeTracker

        // Subscribe to gaze direction changes
        gazeTracker.$gazeDirection
            .sink { [weak self] direction in
                self?.updateMappings(gazeDirection: direction)
            }
            .store(in: &cancellables)

        gazeTracker.$gazeTargetPoint
            .sink { [weak self] targetPoint in
                self?.updateSpatialMapping(targetPoint: targetPoint)
            }
            .store(in: &cancellables)

        print("[GazeToAudioMapper] Connected to GazeTrackingManager")
    }

    // MARK: - Mapping Logic

    private func updateMappings(gazeDirection: SIMD3<Float>) {
        guard isEnabled else { return }

        // Get gaze angles
        let horizontal = atan2(gazeDirection.x, -gazeDirection.z)
        let vertical = atan2(gazeDirection.y, -gazeDirection.z)

        // Normalize angles to 0.0-1.0 range
        // Horizontal: -π to π → 0 to 1
        let normalizedHorizontal = (horizontal + .pi) / (2.0 * .pi)
        // Vertical: -π/2 to π/2 → 0 to 1
        let normalizedVertical = (vertical + .pi / 2.0) / .pi

        // Apply mappings based on mode
        switch mappingMode {
        case .filterCutoff:
            // Horizontal gaze controls filter cutoff
            filterCutoff = mapToRange(
                normalizedHorizontal,
                min: filterRange.min,
                max: filterRange.max
            )

        case .reverbSize:
            // Vertical gaze controls reverb size
            reverbSize = mapToRange(
                normalizedVertical,
                min: reverbRange.min,
                max: reverbRange.max
            )

        case .spatialPosition:
            // Gaze direction controls 3D sound position
            spatialPosition = gazeDirection * spatialRange

        case .custom:
            // Custom parameter mapping (average of both axes)
            customParameter = (normalizedHorizontal + normalizedVertical) / 2.0
        }
    }

    private func updateSpatialMapping(targetPoint: SIMD3<Float>) {
        guard isEnabled, mappingMode == .spatialPosition else { return }

        // Map gaze target point to spatial position
        spatialPosition = targetPoint
    }

    /// Map normalized value (0-1) to custom range
    private func mapToRange(_ value: Float, min: Float, max: Float) -> Float {
        return min + value * (max - min)
    }

    // MARK: - Gaze Region Detection

    /// Check if user is gazing at specific regions for discrete control
    func getGazedRegion() -> GazeTrackingManager.GazeRegion? {
        guard let tracker = gazeTracker else { return nil }

        if tracker.isGazingAt(region: .center) { return .center }
        if tracker.isGazingAt(region: .left) { return .left }
        if tracker.isGazingAt(region: .right) { return .right }
        if tracker.isGazingAt(region: .up) { return .up }
        if tracker.isGazingAt(region: .down) { return .down }

        return nil
    }

    // MARK: - Public Configuration

    /// Set mapping mode
    func setMappingMode(_ mode: MappingMode) {
        self.mappingMode = mode
        print("[GazeToAudioMapper] Mapping mode set to: \(mode)")
    }

    /// Configure filter cutoff range
    func setFilterRange(min: Float, max: Float) {
        self.filterRange = (min, max)
    }

    /// Configure reverb size range
    func setReverbRange(min: Float, max: Float) {
        self.reverbRange = (min, max)
    }

    /// Configure spatial range
    func setSpatialRange(_ range: Float) {
        self.spatialRange = range
    }

    // MARK: - Preset Mappings

    /// Apply preset mapping configuration
    func applyPreset(_ preset: MappingPreset) {
        switch preset {
        case .filterSweep:
            mappingMode = .filterCutoff
            filterRange = (100.0, 10000.0)
            print("[GazeToAudioMapper] Applied preset: Filter Sweep")

        case .spatialExploration:
            mappingMode = .spatialPosition
            spatialRange = 3.0
            print("[GazeToAudioMapper] Applied preset: Spatial Exploration")

        case .reverbDepth:
            mappingMode = .reverbSize
            reverbRange = (0.0, 1.0)
            print("[GazeToAudioMapper] Applied preset: Reverb Depth")
        }
    }

    enum MappingPreset {
        case filterSweep
        case spatialExploration
        case reverbDepth
    }
}

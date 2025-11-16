import Foundation
import Combine

/// Manages smooth transitions between activity contexts
/// Prevents jarring audio changes during context switches
/// Implements crossfading, parameter morphing, and phase coherence
@MainActor
class ContextTransitionEngine: ObservableObject {

    // MARK: - Published State

    /// Current active context
    @Published var activeContext: BioParameterMapper.BioPreset

    /// Transition progress (0.0 - 1.0)
    @Published var transitionProgress: Float = 1.0

    /// Is currently transitioning
    @Published var isTransitioning: Bool = false


    // MARK: - Configuration

    /// Default transition duration (seconds)
    var defaultTransitionDuration: TimeInterval = 3.0

    /// Minimum transition duration for urgent changes (seconds)
    var minimumTransitionDuration: TimeInterval = 0.5

    /// Maximum transition duration for gradual changes (seconds)
    var maximumTransitionDuration: TimeInterval = 10.0

    /// Transition curve type
    var transitionCurve: TransitionCurve = .easeInOut


    // MARK: - Internal State

    private var sourceContext: BioParameterMapper.BioPreset
    private var targetContext: BioParameterMapper.BioPreset?
    private var transitionStartTime: Date?
    private var transitionDuration: TimeInterval = 3.0

    private var updateTimer: Timer?

    private weak var bioMapper: BioParameterMapper?


    // MARK: - Initialization

    init(initialContext: BioParameterMapper.BioPreset = .focus, bioMapper: BioParameterMapper) {
        self.activeContext = initialContext
        self.sourceContext = initialContext
        self.bioMapper = bioMapper
        self.bioMapper?.applyPreset(initialContext)

        print("🔄 ContextTransitionEngine initialized with \(initialContext.rawValue)")
    }


    // MARK: - Transition Control

    /// Transition to new context with automatic duration calculation
    func transition(to newContext: BioParameterMapper.BioPreset) {
        let duration = calculateOptimalDuration(from: activeContext, to: newContext)
        transition(to: newContext, duration: duration)
    }

    /// Transition to new context with custom duration
    func transition(to newContext: BioParameterMapper.BioPreset, duration: TimeInterval) {
        guard newContext != activeContext || isTransitioning else {
            print("⏭️  Already in \(newContext.rawValue), skipping transition")
            return
        }

        // Cancel any ongoing transition
        cancelTransition()

        // Setup new transition
        sourceContext = activeContext
        targetContext = newContext
        transitionDuration = max(minimumTransitionDuration, min(maximumTransitionDuration, duration))
        transitionStartTime = Date()
        isTransitioning = true
        transitionProgress = 0.0

        print("🎬 Starting transition: \(sourceContext.rawValue) → \(newContext.rawValue) (\(transitionDuration)s)")

        // Start update loop (60 Hz)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTransition()
            }
        }
    }

    /// Cancel current transition immediately
    func cancelTransition() {
        updateTimer?.invalidate()
        updateTimer = nil

        if let target = targetContext {
            // Jump to target immediately
            activeContext = target
            bioMapper?.applyPreset(target)
        }

        isTransitioning = false
        transitionProgress = 1.0
        targetContext = nil
    }

    /// Instant context change (no transition)
    func setImmediate(_ context: BioParameterMapper.BioPreset) {
        cancelTransition()
        activeContext = context
        sourceContext = context
        bioMapper?.applyPreset(context)
        print("⚡ Instant context: \(context.rawValue)")
    }


    // MARK: - Transition Update Loop

    private func updateTransition() {
        guard isTransitioning,
              let startTime = transitionStartTime,
              let target = targetContext else {
            return
        }

        // Calculate elapsed time
        let elapsed = Date().timeIntervalSince(startTime)
        let rawProgress = Float(elapsed / transitionDuration)

        // Clamp and apply curve
        let linearProgress = min(1.0, rawProgress)
        transitionProgress = applyTransitionCurve(linearProgress)

        // Interpolate audio parameters
        interpolateParameters(from: sourceContext, to: target, progress: transitionProgress)

        // Check if complete
        if rawProgress >= 1.0 {
            completeTransition()
        }
    }

    private func completeTransition() {
        guard let target = targetContext else { return }

        updateTimer?.invalidate()
        updateTimer = nil

        activeContext = target
        sourceContext = target
        isTransitioning = false
        transitionProgress = 1.0
        targetContext = nil

        // Apply final preset to ensure exact parameters
        bioMapper?.applyPreset(target)

        print("✅ Transition complete: \(target.rawValue)")
    }


    // MARK: - Parameter Interpolation

    /// Interpolate all audio parameters during transition
    private func interpolateParameters(
        from source: BioParameterMapper.BioPreset,
        to target: BioParameterMapper.BioPreset,
        progress: Float
    ) {
        guard let mapper = bioMapper else { return }

        // Get source parameters
        let tempMapper = BioParameterMapper()
        tempMapper.applyPreset(source)
        let sourceParams = extractParameters(from: tempMapper)

        // Get target parameters
        tempMapper.applyPreset(target)
        let targetParams = extractParameters(from: tempMapper)

        // Interpolate each parameter
        mapper.reverbWet = lerp(from: sourceParams.reverb, to: targetParams.reverb, t: progress)
        mapper.filterCutoff = lerp(from: sourceParams.filter, to: targetParams.filter, t: progress)
        mapper.amplitude = lerp(from: sourceParams.amplitude, to: targetParams.amplitude, t: progress)
        mapper.baseFrequency = lerp(from: sourceParams.frequency, to: targetParams.frequency, t: progress)
        mapper.tempo = lerp(from: sourceParams.tempo, to: targetParams.tempo, t: progress)

        // Spatial position interpolation (spherical lerp would be ideal)
        let x = lerp(from: sourceParams.spatialX, to: targetParams.spatialX, t: progress)
        let y = lerp(from: sourceParams.spatialY, to: targetParams.spatialY, t: progress)
        let z = lerp(from: sourceParams.spatialZ, to: targetParams.spatialZ, t: progress)
        mapper.spatialPosition = (x, y, z)

        // Harmonic count (integer, so step interpolation)
        if progress < 0.5 {
            mapper.harmonicCount = sourceParams.harmonics
        } else {
            mapper.harmonicCount = targetParams.harmonics
        }
    }

    private struct AudioParameters {
        var reverb: Float
        var filter: Float
        var amplitude: Float
        var frequency: Float
        var tempo: Float
        var spatialX: Float
        var spatialY: Float
        var spatialZ: Float
        var harmonics: Int
    }

    private func extractParameters(from mapper: BioParameterMapper) -> AudioParameters {
        return AudioParameters(
            reverb: mapper.reverbWet,
            filter: mapper.filterCutoff,
            amplitude: mapper.amplitude,
            frequency: mapper.baseFrequency,
            tempo: mapper.tempo,
            spatialX: mapper.spatialPosition.x,
            spatialY: mapper.spatialPosition.y,
            spatialZ: mapper.spatialPosition.z,
            harmonics: mapper.harmonicCount
        )
    }


    // MARK: - Duration Calculation

    /// Calculate optimal transition duration based on context change magnitude
    /// Scientific basis: Larger parameter changes need longer transitions
    private func calculateOptimalDuration(
        from source: BioParameterMapper.BioPreset,
        to target: BioParameterMapper.BioPreset
    ) -> TimeInterval {

        // Get parameter differences
        let tempMapper = BioParameterMapper()
        tempMapper.applyPreset(source)
        let sourceParams = extractParameters(from: tempMapper)

        tempMapper.applyPreset(target)
        let targetParams = extractParameters(from: tempMapper)

        // Calculate normalized differences
        let reverbDiff = abs(targetParams.reverb - sourceParams.reverb)
        let filterDiff = abs(targetParams.filter - sourceParams.filter) / 2000.0  // Normalize to 0-1
        let ampDiff = abs(targetParams.amplitude - sourceParams.amplitude)
        let freqDiff = abs(targetParams.frequency - sourceParams.frequency) / 1000.0
        let tempoDiff = abs(targetParams.tempo - sourceParams.tempo) / 10.0

        // Weighted sum of differences
        let totalChange = (reverbDiff * 0.2) +
                         (filterDiff * 0.2) +
                         (ampDiff * 0.15) +
                         (freqDiff * 0.25) +
                         (tempoDiff * 0.2)

        // Map to duration (small change = 0.5s, large change = 10s)
        let duration = minimumTransitionDuration +
                      (totalChange * (maximumTransitionDuration - minimumTransitionDuration))

        return duration
    }


    // MARK: - Transition Curves

    /// Apply easing curve to linear progress
    private func applyTransitionCurve(_ linear: Float) -> Float {
        switch transitionCurve {
        case .linear:
            return linear

        case .easeIn:
            return linear * linear

        case .easeOut:
            return 1.0 - (1.0 - linear) * (1.0 - linear)

        case .easeInOut:
            if linear < 0.5 {
                return 2.0 * linear * linear
            } else {
                let t = linear - 1.0
                return 1.0 - 2.0 * t * t
            }

        case .smoothStep:
            return linear * linear * (3.0 - 2.0 * linear)

        case .smootherStep:
            return linear * linear * linear * (linear * (linear * 6.0 - 15.0) + 10.0)

        case .exponential:
            return (pow(2.0, 10.0 * (linear - 1.0)))
        }
    }


    // MARK: - Utility Functions

    /// Linear interpolation
    private func lerp(from: Float, to: Float, t: Float) -> Float {
        return from + (to - from) * t
    }


    // MARK: - Preset Compatibility Analysis

    /// Check if two contexts are compatible (smooth transition possible)
    func areCompatible(_ a: BioParameterMapper.BioPreset, _ b: BioParameterMapper.BioPreset) -> Bool {
        // Some transitions are inherently jarring (e.g., sleep → HIIT)
        let incompatiblePairs: [(BioParameterMapper.BioPreset, BioParameterMapper.BioPreset)] = [
            (.sleepDeep, .hiit),
            (.sleepDeep, .sprinting),
            (.meditation, .hiit),
            (.relaxation, .sprinting),
        ]

        return !incompatiblePairs.contains { ($0 == a && $1 == b) || ($0 == b && $1 == a) }
    }

    /// Get recommended transition duration for specific pair
    func recommendedDuration(from source: BioParameterMapper.BioPreset, to target: BioParameterMapper.BioPreset) -> TimeInterval {
        // Very incompatible transitions should be longer
        if !areCompatible(source, target) {
            return maximumTransitionDuration
        }

        return calculateOptimalDuration(from: source, to: target)
    }
}


// MARK: - Supporting Types

/// Transition curve/easing function
enum TransitionCurve {
    case linear         // No easing
    case easeIn         // Slow start
    case easeOut        // Slow end
    case easeInOut      // Slow start and end
    case smoothStep     // Smooth S-curve
    case smootherStep   // Smoother S-curve
    case exponential    // Very slow start, fast end
}

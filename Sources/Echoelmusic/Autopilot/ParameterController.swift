import Foundation
import Combine

// MARK: - Parameter Controller
/// Kontrolliert Parameteränderungen mit Glättung und Rampen
///
/// Verhindert abrupte Änderungen durch:
/// - Exponentielles Smoothing
/// - Rate-Limiting
/// - Sanfte Rampen

@MainActor
public class ParameterController: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var currentParameters: ParameterSnapshot = ParameterSnapshot()

    @Published public private(set) var isTransitioning: Bool = false

    @Published public private(set) var isHolding: Bool = false

    // MARK: - Configuration

    public var smoothingFactor: Double = 0.7 {
        didSet {
            smoothingFactor = max(0.1, min(0.99, smoothingFactor))
        }
    }

    /// Maximale Änderungsrate pro Sekunde
    public var maxChangeRate: Double = 0.5

    // MARK: - Internal State

    private var targetParameters: ParameterSnapshot = ParameterSnapshot()

    private var transitionStartTime: Date?
    private var transitionDuration: TimeInterval = 0

    private var smoothedValues: [String: SmoothedValue] = [:]

    private var updateTimer: AnyCancellable?

    // MARK: - Initialization

    public init() {
        startUpdateLoop()
    }

    deinit {
        updateTimer?.cancel()
    }

    // MARK: - Control

    /// Setze neue Zielparameter
    public func setTarget(_ params: ParameterSnapshot, rampTime: TimeInterval = 0.5) {
        guard !isHolding else { return }

        targetParameters = params
        transitionStartTime = Date()
        transitionDuration = rampTime
        isTransitioning = true
    }

    /// Halte aktuelle Parameter (keine weiteren Änderungen)
    public func hold() {
        isHolding = true
        isTransitioning = false
        print("[ParameterController] Parameters held")
    }

    /// Löse Hold-Zustand
    public func release() {
        isHolding = false
        print("[ParameterController] Parameters released")
    }

    /// Reduziere Intensität aller Parameter
    public func reduceIntensity(by factor: Double) {
        let reduction = max(0.1, min(0.9, factor))

        targetParameters.amplitude *= Float(1.0 - reduction)
        targetParameters.beatFrequency *= Float(1.0 - reduction * 0.5)

        print("[ParameterController] Intensity reduced by \(Int(reduction * 100))%")
    }

    /// Fade zu neutralen Werten
    public func fadeToNeutral(duration: TimeInterval = 2.0) {
        targetParameters = ParameterSnapshot.neutral
        transitionStartTime = Date()
        transitionDuration = duration
        isTransitioning = true

        print("[ParameterController] Fading to neutral over \(duration)s")
    }

    /// Bereite Übergang vor (smooth current state)
    public func prepareTransition() {
        // Speichere aktuelle Werte als Ausgangspunkt
        for (key, smoothed) in smoothedValues {
            smoothedValues[key] = SmoothedValue(
                current: smoothed.current,
                target: smoothed.current,
                velocity: 0
            )
        }
    }

    // MARK: - Update Loop

    private func startUpdateLoop() {
        // 60 Hz Update-Rate für smooth animation
        updateTimer = Timer.publish(every: 1.0/60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateParameters()
            }
    }

    private func updateParameters() {
        guard !isHolding else { return }

        // Berechne Übergangsfortschritt
        var progress: Double = 1.0

        if let startTime = transitionStartTime, transitionDuration > 0 {
            let elapsed = Date().timeIntervalSince(startTime)
            progress = min(1.0, elapsed / transitionDuration)

            // Ease-out für natürlichere Bewegung
            progress = easeOutCubic(progress)

            if progress >= 1.0 {
                isTransitioning = false
                transitionStartTime = nil
            }
        }

        // Interpoliere jeden Parameter
        currentParameters.carrierFrequency = interpolate(
            from: currentParameters.carrierFrequency,
            to: targetParameters.carrierFrequency,
            progress: Float(progress),
            key: "carrier"
        )

        currentParameters.beatFrequency = interpolate(
            from: currentParameters.beatFrequency,
            to: targetParameters.beatFrequency,
            progress: Float(progress),
            key: "beat"
        )

        currentParameters.amplitude = interpolate(
            from: currentParameters.amplitude,
            to: targetParameters.amplitude,
            progress: Float(progress),
            key: "amplitude"
        )

        currentParameters.reverbMix = interpolate(
            from: currentParameters.reverbMix,
            to: targetParameters.reverbMix,
            progress: Float(progress),
            key: "reverb"
        )

        currentParameters.spatialRotation = interpolate(
            from: currentParameters.spatialRotation,
            to: targetParameters.spatialRotation,
            progress: Float(progress),
            key: "rotation"
        )
    }

    // MARK: - Interpolation

    private func interpolate(
        from: Float,
        to: Float,
        progress: Float,
        key: String
    ) -> Float {
        // Kombiniere lineare Interpolation mit exponentiellem Smoothing

        // Lineare Interpolation basierend auf Progress
        let linearInterp = from + (to - from) * progress

        // Exponentielles Smoothing für extra Glättung
        let smoothed = getSmoothed(key: key, target: linearInterp)

        return smoothed
    }

    private func getSmoothed(key: String, target: Float) -> Float {
        if var smoothed = smoothedValues[key] {
            // Exponentielles Smoothing
            let alpha = Float(1.0 - smoothingFactor)
            smoothed.current = smoothed.current + alpha * (target - smoothed.current)
            smoothed.target = target
            smoothedValues[key] = smoothed
            return smoothed.current
        } else {
            smoothedValues[key] = SmoothedValue(current: target, target: target, velocity: 0)
            return target
        }
    }

    // MARK: - Easing Functions

    private func easeOutCubic(_ t: Double) -> Double {
        let t1 = t - 1
        return t1 * t1 * t1 + 1
    }

    private func easeInOutSine(_ t: Double) -> Double {
        return -(cos(.pi * t) - 1) / 2
    }
}

// MARK: - Parameter Snapshot

public struct ParameterSnapshot: Codable, Equatable {
    public var carrierFrequency: Float = 432.0
    public var beatFrequency: Float = 10.0
    public var amplitude: Float = 0.4
    public var reverbMix: Float = 0.3
    public var filterCutoff: Float = 5000.0
    public var spatialRotation: Float = 0.0

    public static let neutral = ParameterSnapshot(
        carrierFrequency: 432.0,
        beatFrequency: 10.0,
        amplitude: 0.3,
        reverbMix: 0.2,
        filterCutoff: 5000.0,
        spatialRotation: 0.0
    )

    public static let meditation = ParameterSnapshot(
        carrierFrequency: 432.0,
        beatFrequency: 6.0,    // Theta
        amplitude: 0.35,
        reverbMix: 0.6,
        filterCutoff: 3000.0,
        spatialRotation: 0.01
    )

    public static let focus = ParameterSnapshot(
        carrierFrequency: 432.0,
        beatFrequency: 14.0,   // Low Beta
        amplitude: 0.5,
        reverbMix: 0.2,
        filterCutoff: 8000.0,
        spatialRotation: 0.0
    )

    public static let sleep = ParameterSnapshot(
        carrierFrequency: 432.0,
        beatFrequency: 2.0,    // Delta
        amplitude: 0.25,
        reverbMix: 0.7,
        filterCutoff: 2000.0,
        spatialRotation: 0.005
    )
}

// MARK: - Smoothed Value

private struct SmoothedValue {
    var current: Float
    var target: Float
    var velocity: Float
}

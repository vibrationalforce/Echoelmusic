// PredictiveFramePrefetch.swift
// Echoelmusic - Predictive Frame Prefetching for Smooth Visuals
// Phase 10000 Ralph Wiggum Lambda Loop Mode
//
// Predicts next visual frame parameters based on bio data trends.
// Enables pre-computation for buttery-smooth 60fps visuals.
//
// Supported Platforms: ALL
// Created 2026-01-16

import Foundation

// MARK: - Prediction Input

/// Input data for frame prediction
public struct PredictionInput: Sendable {
    public let timestamp: TimeInterval
    public let coherence: Float
    public let heartRate: Float
    public let breathPhase: Float
    public let audioLevel: Float
    public let beatPhase: Float

    public init(
        timestamp: TimeInterval = CFAbsoluteTimeGetCurrent(),
        coherence: Float = 0.5,
        heartRate: Float = 72,
        breathPhase: Float = 0,
        audioLevel: Float = 0,
        beatPhase: Float = 0
    ) {
        self.timestamp = timestamp
        self.coherence = coherence
        self.heartRate = heartRate
        self.breathPhase = breathPhase
        self.audioLevel = audioLevel
        self.beatPhase = beatPhase
    }
}

// MARK: - Predicted Frame Parameters

/// Predicted parameters for next frame
public struct PredictedFrameParameters: Sendable {
    /// Predicted coherence value
    public let coherence: Float

    /// Predicted visual intensity
    public let intensity: Float

    /// Predicted hue (0-1)
    public let hue: Float

    /// Predicted particle density
    public let particleDensity: Float

    /// Predicted rotation speed
    public let rotationSpeed: Float

    /// Predicted scale factor
    public let scale: Float

    /// Confidence level (0-1)
    public let confidence: Float

    /// Timestamp this prediction is for
    public let targetTimestamp: TimeInterval

    /// How many frames ahead this prediction is
    public let framesAhead: Int
}

// MARK: - Predictive Frame Prefetcher

/// Predictive frame parameter prefetcher
///
/// Uses historical bio data to predict future visual parameters,
/// enabling pre-computation for smoother visuals.
///
/// Algorithm:
/// 1. Maintain sliding window of recent inputs
/// 2. Calculate trend using linear regression
/// 3. Apply momentum and smoothing
/// 4. Generate predictions for next N frames
///
/// Usage:
/// ```swift
/// let prefetcher = PredictiveFramePrefetcher()
///
/// // In bio data callback
/// prefetcher.addInput(PredictionInput(coherence: 0.7, ...))
///
/// // Get predictions for next 3 frames
/// let predictions = prefetcher.getPredictions(framesAhead: 3)
///
/// // Pre-render using predictions
/// for prediction in predictions {
///     renderer.prerenderFrame(with: prediction)
/// }
/// ```
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public final class PredictiveFramePrefetcher {

    // MARK: - Configuration

    public struct Configuration {
        /// Size of history window
        public var windowSize: Int = 60  // ~1 second at 60fps

        /// Maximum frames to predict ahead
        public var maxPredictionFrames: Int = 5

        /// Frame duration in seconds
        public var frameDuration: TimeInterval = 1.0 / 60.0

        /// Smoothing factor for predictions
        public var smoothingFactor: Float = 0.8

        /// Momentum factor for trend continuation
        public var momentumFactor: Float = 0.3

        /// Minimum confidence threshold
        public var minConfidence: Float = 0.3

        public static let `default` = Configuration()

        /// Low-latency configuration
        public static let lowLatency = Configuration(
            windowSize: 30,
            maxPredictionFrames: 2,
            smoothingFactor: 0.6
        )

        /// High-quality configuration
        public static let highQuality = Configuration(
            windowSize: 120,
            maxPredictionFrames: 8,
            smoothingFactor: 0.9,
            momentumFactor: 0.4
        )
    }

    public var config: Configuration

    // MARK: - History

    private var inputHistory: [PredictionInput] = []
    private var trendCoherence: Float = 0
    private var trendIntensity: Float = 0
    private var lastPredictions: [PredictedFrameParameters] = []

    // MARK: - Thread Safety

    private let lock = NSLock()

    // MARK: - Initialization

    public init(config: Configuration = .default) {
        self.config = config
    }

    // MARK: - Input

    /// Add new input data point
    public func addInput(_ input: PredictionInput) {
        lock.lock()
        defer { lock.unlock() }

        inputHistory.append(input)

        // Trim to window size
        if inputHistory.count > config.windowSize {
            inputHistory.removeFirst(inputHistory.count - config.windowSize)
        }

        // Update trends
        updateTrends()
    }

    /// Add batch of inputs
    public func addInputs(_ inputs: [PredictionInput]) {
        lock.lock()
        defer { lock.unlock() }

        inputHistory.append(contentsOf: inputs)

        // Trim to window size
        if inputHistory.count > config.windowSize {
            inputHistory.removeFirst(inputHistory.count - config.windowSize)
        }

        updateTrends()
    }

    // MARK: - Prediction

    /// Get predictions for upcoming frames
    public func getPredictions(framesAhead: Int? = nil) -> [PredictedFrameParameters] {
        lock.lock()
        defer { lock.unlock() }

        let frames = min(framesAhead ?? config.maxPredictionFrames, config.maxPredictionFrames)
        guard !inputHistory.isEmpty else {
            return generateDefaultPredictions(frames: frames)
        }

        var predictions: [PredictedFrameParameters] = []
        let currentTime = CFAbsoluteTimeGetCurrent()

        for i in 1...frames {
            let targetTime = currentTime + config.frameDuration * Double(i)
            let prediction = predictFrame(at: targetTime, framesAhead: i)
            predictions.append(prediction)
        }

        lastPredictions = predictions
        return predictions
    }

    /// Get single next frame prediction
    public func getNextFramePrediction() -> PredictedFrameParameters {
        getPredictions(framesAhead: 1).first ?? generateDefaultPrediction(framesAhead: 1)
    }

    // MARK: - Trend Analysis

    private func updateTrends() {
        guard inputHistory.count >= 2 else { return }

        // Linear regression for coherence trend
        let coherenceValues = inputHistory.map { $0.coherence }
        trendCoherence = calculateTrend(coherenceValues)

        // Calculate intensity from coherence and audio
        let intensityValues = inputHistory.map { max($0.coherence, $0.audioLevel) }
        trendIntensity = calculateTrend(intensityValues)
    }

    private func calculateTrend(_ values: [Float]) -> Float {
        guard values.count >= 2 else { return 0 }

        let n = Float(values.count)
        var sumX: Float = 0
        var sumY: Float = 0
        var sumXY: Float = 0
        var sumXX: Float = 0

        for (i, value) in values.enumerated() {
            let x = Float(i)
            sumX += x
            sumY += value
            sumXY += x * value
            sumXX += x * x
        }

        let denominator = n * sumXX - sumX * sumX
        guard denominator != 0 else { return 0 }

        return (n * sumXY - sumX * sumY) / denominator
    }

    // MARK: - Frame Prediction

    private func predictFrame(at targetTime: TimeInterval, framesAhead: Int) -> PredictedFrameParameters {
        let recent = inputHistory.suffix(10)
        guard !recent.isEmpty else {
            return generateDefaultPrediction(framesAhead: framesAhead)
        }

        // Current values (weighted average of recent)
        let currentCoherence = weightedAverage(recent.map { $0.coherence })
        let currentBreathPhase = recent.last?.breathPhase ?? 0
        let currentBeatPhase = recent.last?.beatPhase ?? 0

        // Predicted values with trend and momentum
        let dt = Float(framesAhead)
        let predictedCoherence = clamp(
            currentCoherence + trendCoherence * dt * config.momentumFactor,
            min: 0, max: 1
        )

        // Predict breath phase (cyclic, ~6 breaths/min = 0.1 Hz)
        let breathCycleSeconds: Float = 10.0  // ~6 breaths/min
        let breathDelta = Float(config.frameDuration * Double(framesAhead)) / breathCycleSeconds
        let predictedBreathPhase = fmod(currentBreathPhase + breathDelta, 1.0)

        // Predict beat phase (cyclic, based on BPM)
        let bpm = recent.last.map { 60000 / $0.heartRate } ?? 120.0
        let beatDelta = Float(config.frameDuration * Double(framesAhead)) * bpm / 60.0
        let predictedBeatPhase = fmod(currentBeatPhase + beatDelta, 1.0)

        // Calculate derived parameters
        let intensity = predictedCoherence * 0.7 + predictedBreathPhase * 0.3
        let hue = coherenceToHue(predictedCoherence)
        let particleDensity = predictedCoherence * 0.5 + 0.5
        let rotationSpeed = 0.5 + predictedCoherence * 0.5
        let scale = 0.8 + predictedCoherence * 0.4

        // Calculate confidence based on history stability
        let confidence = calculateConfidence(framesAhead: framesAhead)

        return PredictedFrameParameters(
            coherence: predictedCoherence,
            intensity: intensity,
            hue: hue,
            particleDensity: particleDensity,
            rotationSpeed: rotationSpeed,
            scale: scale,
            confidence: confidence,
            targetTimestamp: targetTime,
            framesAhead: framesAhead
        )
    }

    private func weightedAverage(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }

        var sum: Float = 0
        var weightSum: Float = 0

        for (i, value) in values.enumerated() {
            let weight = Float(i + 1)  // More recent = higher weight
            sum += value * weight
            weightSum += weight
        }

        return sum / weightSum
    }

    private func coherenceToHue(_ coherence: Float) -> Float {
        // Low coherence = red (0), high coherence = green (0.33)
        return coherence * 0.33
    }

    private func calculateConfidence(framesAhead: Int) -> Float {
        // Confidence decreases with prediction distance and increases with history
        let historyFactor = min(Float(inputHistory.count) / Float(config.windowSize), 1.0)
        let distanceFactor = 1.0 - Float(framesAhead) / Float(config.maxPredictionFrames + 1)

        // Also factor in stability (inverse of variance)
        let stabilityFactor = calculateStability()

        return max(config.minConfidence, historyFactor * distanceFactor * stabilityFactor)
    }

    private func calculateStability() -> Float {
        guard inputHistory.count >= 5 else { return 0.5 }

        let recentCoherence = inputHistory.suffix(10).map { $0.coherence }
        let mean = recentCoherence.reduce(0, +) / Float(recentCoherence.count)
        let variance = recentCoherence.reduce(0) { $0 + pow($1 - mean, 2) } / Float(recentCoherence.count)

        // Low variance = high stability
        return max(0.3, 1.0 - min(variance * 4, 0.7))
    }

    // MARK: - Default Predictions

    private func generateDefaultPredictions(frames: Int) -> [PredictedFrameParameters] {
        (1...frames).map { generateDefaultPrediction(framesAhead: $0) }
    }

    private func generateDefaultPrediction(framesAhead: Int) -> PredictedFrameParameters {
        PredictedFrameParameters(
            coherence: 0.5,
            intensity: 0.5,
            hue: 0.17,  // Yellow-ish
            particleDensity: 0.75,
            rotationSpeed: 0.75,
            scale: 1.0,
            confidence: config.minConfidence,
            targetTimestamp: CFAbsoluteTimeGetCurrent() + config.frameDuration * Double(framesAhead),
            framesAhead: framesAhead
        )
    }

    // MARK: - Utilities

    private func clamp(_ value: Float, min minVal: Float, max maxVal: Float) -> Float {
        max(minVal, min(maxVal, value))
    }

    /// Reset prediction state
    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        inputHistory.removeAll()
        trendCoherence = 0
        trendIntensity = 0
        lastPredictions.removeAll()
    }

    // MARK: - Statistics

    /// Get prediction statistics
    public var statistics: PredictionStatistics {
        lock.lock()
        defer { lock.unlock() }

        return PredictionStatistics(
            historySize: inputHistory.count,
            coherenceTrend: trendCoherence,
            intensityTrend: trendIntensity,
            averageConfidence: lastPredictions.isEmpty ? 0 :
                lastPredictions.map { $0.confidence }.reduce(0, +) / Float(lastPredictions.count)
        )
    }

    public struct PredictionStatistics: Sendable {
        public let historySize: Int
        public let coherenceTrend: Float
        public let intensityTrend: Float
        public let averageConfidence: Float

        public var trendDirection: String {
            if coherenceTrend > 0.01 { return "↑ Rising" }
            if coherenceTrend < -0.01 { return "↓ Falling" }
            return "→ Stable"
        }
    }
}

// MARK: - Pre-Render Queue

/// Queue for pre-rendered frames
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public final class PreRenderQueue {

    /// Pre-rendered frame
    public struct PreRenderedFrame {
        public let parameters: PredictedFrameParameters
        public let textureHandle: UInt64?
        public let renderedAt: Date
    }

    private var queue: [PreRenderedFrame] = []
    private let maxSize: Int
    private let lock = NSLock()

    public init(maxSize: Int = 5) {
        self.maxSize = maxSize
    }

    /// Add a pre-rendered frame
    public func enqueue(_ frame: PreRenderedFrame) {
        lock.lock()
        defer { lock.unlock() }

        queue.append(frame)
        if queue.count > maxSize {
            queue.removeFirst()
        }
    }

    /// Get frame closest to target time
    public func dequeue(forTime targetTime: TimeInterval) -> PreRenderedFrame? {
        lock.lock()
        defer { lock.unlock() }

        guard !queue.isEmpty else { return nil }

        // Find closest match
        let closest = queue.min {
            abs($0.parameters.targetTimestamp - targetTime) <
            abs($1.parameters.targetTimestamp - targetTime)
        }

        // Remove used frame
        if let frame = closest {
            queue.removeAll { $0.parameters.targetTimestamp == frame.parameters.targetTimestamp }
        }

        return closest
    }

    /// Clear all pre-rendered frames
    public func clear() {
        lock.lock()
        queue.removeAll()
        lock.unlock()
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return queue.count
    }
}

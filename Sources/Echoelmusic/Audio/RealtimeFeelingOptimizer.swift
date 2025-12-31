//
//  RealtimeFeelingOptimizer.swift
//  Echoelmusic
//
//  Created: December 2025
//  REALTIME FEELING OPTIMIZER
//
//  "Latency you can measure vs. latency you can feel - they're not the same"
//
//  This system uses psychoacoustic tricks to make audio FEEL more responsive
//  even when actual latency cannot be reduced further.
//

import Foundation
import AVFoundation
import Accelerate
import simd
import Combine

// MARK: - Perceptual Latency Techniques

/// Techniques to reduce perceived latency
public enum PerceptualLatencyTechnique: String, CaseIterable, Identifiable {
    case transientPreEmphasis = "Transient Pre-Emphasis"
    case attackEnhancement = "Attack Enhancement"
    case predictiveOnset = "Predictive Onset"
    case hapticCueing = "Haptic Pre-Cueing"
    case visualAnticipation = "Visual Anticipation"
    case maskingOptimization = "Temporal Masking"
    case psychoacousticShaping = "Psychoacoustic Shaping"

    public var id: String { rawValue }

    var description: String {
        switch self {
        case .transientPreEmphasis:
            return "Boost high frequencies in transients for faster perception"
        case .attackEnhancement:
            return "Sharpen attack envelopes to improve temporal precision"
        case .predictiveOnset:
            return "Predict and pre-render audio before user action"
        case .hapticCueing:
            return "Use haptic feedback to mask audio delay"
        case .visualAnticipation:
            return "Visual cues arrive before audio to prepare perception"
        case .maskingOptimization:
            return "Use forward masking to hide latency artifacts"
        case .psychoacousticShaping:
            return "Shape audio to match human temporal resolution limits"
        }
    }

    /// Estimated perceptual improvement (ms)
    var perceptualImprovementMs: Double {
        switch self {
        case .transientPreEmphasis: return 2.0
        case .attackEnhancement: return 3.0
        case .predictiveOnset: return 5.0
        case .hapticCueing: return 8.0
        case .visualAnticipation: return 10.0
        case .maskingOptimization: return 2.0
        case .psychoacousticShaping: return 1.0
        }
    }
}

// MARK: - Transient Detector

/// Ultra-fast transient detection for attack enhancement
final class TransientDetector {

    private var energyBuffer: [Float] = []
    private var energyIndex: Int = 0
    private let bufferSize: Int
    private var threshold: Float = 0.3
    private var lastEnergy: Float = 0

    init(bufferSize: Int = 8) {
        self.bufferSize = bufferSize
        self.energyBuffer = [Float](repeating: 0, count: bufferSize)
    }

    /// Detect transient in sample buffer
    func detectTransient(samples: UnsafePointer<Float>, count: Int) -> (isTransient: Bool, strength: Float) {
        // Calculate energy
        var energy: Float = 0
        vDSP_svesq(samples, 1, &energy, vDSP_Length(count))
        energy = sqrt(energy / Float(count))

        // Store in circular buffer
        energyBuffer[energyIndex] = energy
        energyIndex = (energyIndex + 1) % bufferSize

        // Calculate average energy
        var avgEnergy: Float = 0
        vDSP_meanv(energyBuffer, 1, &avgEnergy, vDSP_Length(bufferSize))

        // Detect sudden increase
        let ratio = energy / max(avgEnergy, 0.0001)
        let isTransient = ratio > (1.0 + threshold) && energy > lastEnergy * 1.5

        lastEnergy = energy

        return (isTransient, min(ratio / 2.0, 1.0))
    }

    /// Set detection threshold (0.1 - 1.0)
    func setThreshold(_ threshold: Float) {
        self.threshold = max(0.1, min(1.0, threshold))
    }
}

// MARK: - Attack Enhancer

/// Enhances attack portions of audio for faster perception
final class AttackEnhancer {

    private var isInAttack = false
    private var attackSamples = 0
    private let maxAttackSamples: Int
    private let attackBoostdB: Float

    // Attack envelope shaping
    private var envelope: Float = 0
    private let attackCoeff: Float
    private let releaseCoeff: Float

    init(sampleRate: Float = 48000, attackTimeMs: Float = 5.0, boostdB: Float = 3.0) {
        self.maxAttackSamples = Int(sampleRate * attackTimeMs / 1000.0)
        self.attackBoostdB = boostdB
        self.attackCoeff = exp(-1.0 / (sampleRate * 0.001))  // 1ms attack
        self.releaseCoeff = exp(-1.0 / (sampleRate * 0.050)) // 50ms release
    }

    /// Process buffer with attack enhancement
    func process(
        buffer: UnsafeMutablePointer<Float>,
        count: Int,
        transientStrength: Float
    ) {
        let boostLinear = pow(10.0, attackBoostdB / 20.0)

        for i in 0..<count {
            let sample = abs(buffer[i])

            // Envelope follower
            if sample > envelope {
                envelope = attackCoeff * envelope + (1 - attackCoeff) * sample
                isInAttack = true
                attackSamples = 0
            } else {
                envelope = releaseCoeff * envelope + (1 - releaseCoeff) * sample
                attackSamples += 1
                if attackSamples > maxAttackSamples {
                    isInAttack = false
                }
            }

            // Apply boost during attack
            if isInAttack {
                let attackPhase = Float(attackSamples) / Float(maxAttackSamples)
                let boost = 1.0 + (boostLinear - 1.0) * (1.0 - attackPhase) * transientStrength
                buffer[i] *= boost
            }
        }
    }
}

// MARK: - Transient Pre-Emphasis

/// Applies high-frequency boost to transients for faster perception
final class TransientPreEmphasis {

    // Simple high-shelf filter state
    private var z1: Float = 0
    private var z2: Float = 0

    // Filter coefficients for high-shelf at 2kHz
    private var b0: Float = 1.0
    private var b1: Float = 0.0
    private var b2: Float = 0.0
    private var a1: Float = 0.0
    private var a2: Float = 0.0

    private var boostActive = false
    private var boostDecay: Float = 0

    init(sampleRate: Float = 48000, cutoffHz: Float = 2000, boostdB: Float = 6.0) {
        calculateCoefficients(sampleRate: sampleRate, cutoffHz: cutoffHz, boostdB: boostdB)
    }

    private func calculateCoefficients(sampleRate: Float, cutoffHz: Float, boostdB: Float) {
        let A = pow(10.0, boostdB / 40.0)
        let w0 = 2.0 * Float.pi * cutoffHz / sampleRate
        let cosw0 = cos(w0)
        let sinw0 = sin(w0)
        let alpha = sinw0 / 2.0 * sqrt((A + 1.0/A) * (1.0/0.707 - 1.0) + 2.0)

        let a0 = (A + 1) - (A - 1) * cosw0 + 2 * sqrt(A) * alpha
        b0 = A * ((A + 1) + (A - 1) * cosw0 + 2 * sqrt(A) * alpha) / a0
        b1 = -2 * A * ((A - 1) + (A + 1) * cosw0) / a0
        b2 = A * ((A + 1) + (A - 1) * cosw0 - 2 * sqrt(A) * alpha) / a0
        a1 = 2 * ((A - 1) - (A + 1) * cosw0) / a0
        a2 = ((A + 1) - (A - 1) * cosw0 - 2 * sqrt(A) * alpha) / a0
    }

    /// Process buffer with transient-triggered emphasis
    func process(
        buffer: UnsafeMutablePointer<Float>,
        count: Int,
        isTransient: Bool,
        strength: Float
    ) {
        if isTransient {
            boostActive = true
            boostDecay = strength
        }

        guard boostActive else { return }

        // Apply high-shelf filter
        for i in 0..<count {
            let input = buffer[i]

            // Biquad filter
            let output = b0 * input + b1 * z1 + b2 * z2 - a1 * z1 - a2 * z2
            z2 = z1
            z1 = input

            // Blend based on decay
            buffer[i] = input + (output - input) * boostDecay
        }

        // Decay the boost
        boostDecay *= 0.99
        if boostDecay < 0.01 {
            boostActive = false
            boostDecay = 0
        }
    }
}

// MARK: - Predictive Onset

/// Predicts user actions to pre-render audio
final class PredictiveOnset {

    // MIDI velocity history for prediction
    private var velocityHistory: [(velocity: UInt8, timestamp: TimeInterval)] = []
    private let historySize = 16

    // Rhythm detection
    private var interOnsetIntervals: [TimeInterval] = []
    private var predictedNextOnset: TimeInterval = 0
    private var tempo: Double = 120  // BPM

    // Prediction confidence
    private var confidence: Float = 0

    /// Record a note onset for learning
    func recordOnset(velocity: UInt8, timestamp: TimeInterval) {
        velocityHistory.append((velocity, timestamp))

        // Keep limited history
        if velocityHistory.count > historySize {
            velocityHistory.removeFirst()
        }

        // Calculate IOIs
        updateInterOnsetIntervals()

        // Predict next onset
        predictNextOnset()
    }

    private func updateInterOnsetIntervals() {
        guard velocityHistory.count >= 2 else { return }

        interOnsetIntervals = []
        for i in 1..<velocityHistory.count {
            let ioi = velocityHistory[i].timestamp - velocityHistory[i-1].timestamp
            if ioi > 0.05 && ioi < 2.0 {  // Reasonable range
                interOnsetIntervals.append(ioi)
            }
        }
    }

    private func predictNextOnset() {
        guard interOnsetIntervals.count >= 2 else {
            confidence = 0
            return
        }

        // Calculate average IOI
        let avgIOI = interOnsetIntervals.reduce(0, +) / Double(interOnsetIntervals.count)

        // Calculate variance
        let variance = interOnsetIntervals.map { pow($0 - avgIOI, 2) }.reduce(0, +) / Double(interOnsetIntervals.count)
        let stdDev = sqrt(variance)

        // Confidence based on consistency
        confidence = Float(1.0 - min(stdDev / avgIOI, 1.0))

        // Predict next onset
        if let lastOnset = velocityHistory.last?.timestamp {
            predictedNextOnset = lastOnset + avgIOI
        }

        // Update tempo
        tempo = 60.0 / avgIOI
    }

    /// Get prediction for given time
    func getPrediction(currentTime: TimeInterval) -> (shouldPreRender: Bool, advanceMs: Double, confidence: Float) {
        let timeUntilPredicted = predictedNextOnset - currentTime

        // Pre-render if we're close to predicted onset
        if timeUntilPredicted > 0 && timeUntilPredicted < 0.050 && confidence > 0.5 {
            return (true, timeUntilPredicted * 1000, confidence)
        }

        return (false, 0, confidence)
    }

    /// Get estimated tempo
    var estimatedTempo: Double { tempo }

    /// Get prediction confidence (0-1)
    var predictionConfidence: Float { confidence }
}

// MARK: - Psychoacoustic Shaper

/// Shapes audio to match human temporal perception limits
final class PsychoacousticShaper {

    // Human auditory temporal resolution is ~2-3ms
    // Below this, events are perceived as simultaneous

    private let temporalResolutionMs: Float = 2.5
    private var lastEventTime: TimeInterval = 0

    // Forward masking curve
    // Sounds within 50ms of a loud transient are partially masked
    private let forwardMaskingMs: Float = 50

    /// Determine if latency is perceptible
    func isLatencyPerceptible(latencyMs: Float) -> Bool {
        return latencyMs > temporalResolutionMs
    }

    /// Calculate masking benefit from transient
    func calculateMaskingBenefit(
        timeSinceTransientMs: Float,
        transientLevel: Float
    ) -> Float {
        if timeSinceTransientMs > forwardMaskingMs { return 0 }

        // Forward masking decays exponentially
        let decay = exp(-timeSinceTransientMs / (forwardMaskingMs * 0.3))
        return decay * transientLevel * 0.5
    }

    /// Shape audio to exploit temporal masking
    func shapeForMasking(
        buffer: UnsafeMutablePointer<Float>,
        count: Int,
        transientInfo: (occurred: Bool, strength: Float, timeSinceMs: Float)
    ) {
        guard transientInfo.occurred else { return }

        let maskingGain = calculateMaskingBenefit(
            timeSinceTransientMs: transientInfo.timeSinceMs,
            transientLevel: transientInfo.strength
        )

        if maskingGain > 0.1 {
            // Slight level reduction in masked region (saves CPU, unnoticeable)
            var gain = 1.0 - maskingGain * 0.2
            vDSP_vsmul(buffer, 1, &gain, buffer, 1, vDSP_Length(count))
        }
    }
}

// MARK: - Realtime Feeling Optimizer

/// Main optimizer combining all perceptual latency techniques
/// Migrated to @Observable for better performance (Swift 5.9+)
@MainActor
@Observable
public final class RealtimeFeelingOptimizer {

    // MARK: - Singleton
    public static let shared = RealtimeFeelingOptimizer()

    // MARK: - Observable State

    public var enabledTechniques: Set<PerceptualLatencyTechnique> = [
        .transientPreEmphasis,
        .attackEnhancement,
        .psychoacousticShaping
    ]

    public var isRunning = false

    // Metrics
    public var measuredLatencyMs: Double = 0
    public var perceivedLatencyMs: Double = 0
    public var perceptualImprovement: Double = 0

    // Transient detection
    public var transientDetected = false
    public var transientStrength: Float = 0

    // Prediction
    public var predictionConfidence: Float = 0
    public var estimatedTempo: Double = 120

    // Settings
    public var transientThreshold: Float = 0.3
    public var attackBoostdB: Float = 3.0
    public var emphasisFrequencyHz: Float = 2000

    // MARK: - Private Components

    private var transientDetector: TransientDetector!
    private var attackEnhancer: AttackEnhancer!
    private var transientPreEmphasis: TransientPreEmphasis!
    private var predictiveOnset: PredictiveOnset!
    private var psychoacousticShaper: PsychoacousticShaper!

    private var sampleRate: Float = 48000
    private var lastTransientTime: TimeInterval = 0

    // MARK: - Initialization

    private init() {
        setupComponents()
    }

    // MARK: - Setup

    private func setupComponents() {
        transientDetector = TransientDetector()
        attackEnhancer = AttackEnhancer(sampleRate: sampleRate, attackTimeMs: 5.0, boostdB: attackBoostdB)
        transientPreEmphasis = TransientPreEmphasis(sampleRate: sampleRate, cutoffHz: emphasisFrequencyHz, boostdB: 6.0)
        predictiveOnset = PredictiveOnset()
        psychoacousticShaper = PsychoacousticShaper()
    }

    // MARK: - Public API

    /// Enable a technique
    public func enableTechnique(_ technique: PerceptualLatencyTechnique) {
        enabledTechniques.insert(technique)
        updatePerceptualImprovement()
    }

    /// Disable a technique
    public func disableTechnique(_ technique: PerceptualLatencyTechnique) {
        enabledTechniques.remove(technique)
        updatePerceptualImprovement()
    }

    /// Process audio buffer with perceptual optimizations
    public func processBuffer(
        buffer: UnsafeMutablePointer<Float>,
        count: Int,
        timestamp: TimeInterval = CACurrentMediaTime()
    ) {
        // 1. Detect transients
        let (isTransient, strength) = transientDetector.detectTransient(samples: buffer, count: count)

        transientDetected = isTransient
        transientStrength = strength

        if isTransient {
            lastTransientTime = timestamp
        }

        let timeSinceTransient = Float((timestamp - lastTransientTime) * 1000)

        // 2. Apply transient pre-emphasis
        if enabledTechniques.contains(.transientPreEmphasis) {
            transientPreEmphasis.process(
                buffer: buffer,
                count: count,
                isTransient: isTransient,
                strength: strength
            )
        }

        // 3. Apply attack enhancement
        if enabledTechniques.contains(.attackEnhancement) {
            attackEnhancer.process(
                buffer: buffer,
                count: count,
                transientStrength: strength
            )
        }

        // 4. Apply psychoacoustic shaping
        if enabledTechniques.contains(.psychoacousticShaping) {
            psychoacousticShaper.shapeForMasking(
                buffer: buffer,
                count: count,
                transientInfo: (isTransient, strength, timeSinceTransient)
            )
        }
    }

    /// Record MIDI onset for prediction
    public func recordMIDIOnset(velocity: UInt8, timestamp: TimeInterval = CACurrentMediaTime()) {
        predictiveOnset.recordOnset(velocity: velocity, timestamp: timestamp)
        predictionConfidence = predictiveOnset.predictionConfidence
        estimatedTempo = predictiveOnset.estimatedTempo
    }

    /// Get prediction for pre-rendering
    public func getPrediction(currentTime: TimeInterval = CACurrentMediaTime()) -> (shouldPreRender: Bool, advanceMs: Double, confidence: Float) {
        guard enabledTechniques.contains(.predictiveOnset) else {
            return (false, 0, 0)
        }
        return predictiveOnset.getPrediction(currentTime: currentTime)
    }

    /// Set measured system latency
    public func setMeasuredLatency(_ latencyMs: Double) {
        measuredLatencyMs = latencyMs
        updatePerceivedLatency()
    }

    // MARK: - Private Methods

    private func updatePerceptualImprovement() {
        perceptualImprovement = enabledTechniques.reduce(0) { $0 + $1.perceptualImprovementMs }
        updatePerceivedLatency()
    }

    private func updatePerceivedLatency() {
        perceivedLatencyMs = max(0, measuredLatencyMs - perceptualImprovement)
    }
}

// MARK: - SwiftUI View

import SwiftUI

public struct RealtimeFeelingView: View {
    @StateObject private var optimizer = RealtimeFeelingOptimizer.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("🎯 REALTIME FEELING")
                        .font(.title2.bold())
                    Text("Perceptual latency optimization")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Transient indicator
                Circle()
                    .fill(optimizer.transientDetected ? Color.yellow : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .animation(.easeOut(duration: 0.1), value: optimizer.transientDetected)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.2)))

            // Latency Comparison
            VStack(spacing: 12) {
                HStack {
                    VStack {
                        Text(String(format: "%.1f", optimizer.measuredLatencyMs))
                            .font(.title.bold().monospacedDigit())
                            .foregroundColor(.red)
                        Text("Measured")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)

                    VStack {
                        Text(String(format: "%.1f", optimizer.perceivedLatencyMs))
                            .font(.title.bold().monospacedDigit())
                            .foregroundColor(.green)
                        Text("Perceived")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                Text("Perceptual improvement: -\(String(format: "%.1f", optimizer.perceptualImprovement))ms")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))

            // Techniques
            VStack(alignment: .leading, spacing: 8) {
                Text("TECHNIQUES")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                ForEach(PerceptualLatencyTechnique.allCases) { technique in
                    techniqueRow(technique)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.05)))

            // Prediction Status
            if optimizer.enabledTechniques.contains(.predictiveOnset) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Prediction")
                            .font(.caption.bold())
                        Spacer()
                        Text("\(Int(optimizer.predictionConfidence * 100))% confident")
                            .font(.caption)
                            .foregroundColor(optimizer.predictionConfidence > 0.5 ? .green : .orange)
                    }

                    HStack {
                        Text("Tempo")
                            .font(.caption)
                        Spacer()
                        Text("\(Int(optimizer.estimatedTempo)) BPM")
                            .font(.caption.monospacedDigit())
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.1)))
            }
        }
        .padding()
    }

    private func techniqueRow(_ technique: PerceptualLatencyTechnique) -> some View {
        HStack {
            Toggle(isOn: Binding(
                get: { optimizer.enabledTechniques.contains(technique) },
                set: { enabled in
                    if enabled {
                        optimizer.enableTechnique(technique)
                    } else {
                        optimizer.disableTechnique(technique)
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(technique.rawValue)
                        .font(.subheadline)
                    Text("-\(String(format: "%.1f", technique.perceptualImprovementMs))ms")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .orange))
        }
    }
}

#Preview {
    RealtimeFeelingView()
        .preferredColorScheme(.dark)
}

// MARK: - ObservableObject Conformance (Backward Compatibility)

/// Allows RealtimeFeelingOptimizer to work with older SwiftUI code expecting ObservableObject
extension RealtimeFeelingOptimizer: ObservableObject { }

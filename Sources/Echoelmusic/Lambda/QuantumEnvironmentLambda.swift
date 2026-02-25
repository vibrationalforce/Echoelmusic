// QuantumEnvironmentLambda.swift
// Echoelmusic - λ% Ralph Wiggum Loop Quantum Light Science Developer Genius Mode
//
// Composable Lambda-Chain für Environment → Bio-Reactive Transformationen
// Quanteninspirierte funktionale Pipeline: |ψ_env⟩ → Û₁ → Û₂ → ... → Ûₙ → |ψ_output⟩
//
// Jeder Operator ist eine pure function: (EnvironmentStateVector) → TransformResult
// Operatoren können frei kombiniert, umgeordnet und verschachtelt werden.
//
// "I bent my wookiee" - Ralph Wiggum, Lambda Calculus Pioneer
//
// ═══════════════════════════════════════════════════════════════════════════════
// PRINCIPLE: Environment data flows through a composable chain of transformations.
// Each λ-operator maps environment state to audio/visual/haptic parameters.
// The chain is unitary — no information is lost, only transformed.
// ═══════════════════════════════════════════════════════════════════════════════
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine

// MARK: - Lambda Transform Result

/// Ergebnis einer Lambda-Transformation
public struct LambdaTransformResult: Sendable {
    public var coherenceModifier: Double       // Einfluss auf HRV-Kohärenz
    public var frequency: Double               // Empfohlene Entrainment-Frequenz
    public var carrierFrequency: Double        // Audio Carrier
    public var amplitude: Double               // Lautstärke-Modifier 0–1
    public var color: (r: Float, g: Float, b: Float)  // Visual Color
    public var reverbMix: Float                // 0–1
    public var spatialWidth: Float             // 0–1
    public var hapticIntensity: Float          // 0–1
    public var metadata: [String: Double]      // Zusätzliche Key-Value Daten

    public static let neutral = LambdaTransformResult(
        coherenceModifier: 0.0,
        frequency: 10.0,
        carrierFrequency: 440.0,
        amplitude: 0.5,
        color: (0.5, 0.5, 0.5),
        reverbMix: 0.3,
        spatialWidth: 0.5,
        hapticIntensity: 0.0,
        metadata: [:]
    )

    /// Zwei Ergebnisse blenden (Superposition)
    public func blended(with other: LambdaTransformResult, factor: Double) -> LambdaTransformResult {
        let f = Float(factor)
        let inv = 1.0 - f
        let dInv = 1.0 - factor
        return LambdaTransformResult(
            coherenceModifier: coherenceModifier * dInv + other.coherenceModifier * factor,
            frequency: frequency * dInv + other.frequency * factor,
            carrierFrequency: carrierFrequency * dInv + other.carrierFrequency * factor,
            amplitude: amplitude * dInv + other.amplitude * factor,
            color: (
                r: color.r * inv + other.color.r * f,
                g: color.g * inv + other.color.g * f,
                b: color.b * inv + other.color.b * f
            ),
            reverbMix: reverbMix * inv + other.reverbMix * f,
            spatialWidth: spatialWidth * inv + other.spatialWidth * f,
            hapticIntensity: hapticIntensity * inv + other.hapticIntensity * f,
            metadata: metadata.merging(other.metadata) { old, new in old * dInv + new * factor }
        )
    }
}

// MARK: - Lambda Operator Protocol

/// Ein einzelner λ-Operator in der Transformations-Pipeline
/// Pure function: EnvironmentStateVector → LambdaTransformResult
public struct LambdaOperator: Sendable {
    public let name: String
    public let transform: @Sendable (EnvironmentStateVector) -> LambdaTransformResult

    public init(name: String, transform: @escaping @Sendable (EnvironmentStateVector) -> LambdaTransformResult) {
        self.name = name
        self.transform = transform
    }
}

// MARK: - Built-in Lambda Operators

public enum LambdaOperators {

    // MARK: - Comfort → Coherence

    /// Komfort-Score direkt auf Kohärenz mappen
    public static let comfortToCoherence = LambdaOperator(name: "λ.comfort→coherence") { state in
        var result = LambdaTransformResult.neutral
        result.coherenceModifier = (state.comfortScore - 0.5) * 0.3
        return result
    }

    // MARK: - Temperature → Color Warmth

    /// Temperatur auf Farbwärme mappen
    public static let temperatureToColor = LambdaOperator(name: "λ.temp→color") { state in
        var result = LambdaTransformResult.neutral
        guard let temp = state.dimensions[.temperature] else { return result }

        // Kalt (-20°C) → Blau, Mild (20°C) → Grün, Heiß (45°C) → Rot
        let normalized = Float((temp.value + 20) / 65.0)  // -20...45 → 0...1
        let clamped = Swift.min(1.0, Swift.max(0.0, normalized))

        if clamped < 0.5 {
            // Blau → Grün
            let t = clamped * 2.0
            result.color = (r: 0.0, g: t, b: 1.0 - t)
        } else {
            // Grün → Rot
            let t = (clamped - 0.5) * 2.0
            result.color = (r: t, g: 1.0 - t, b: 0.0)
        }
        return result
    }

    // MARK: - Pressure → Frequency

    /// Druck auf Entrainment-Frequenz mappen
    public static let pressureToFrequency = LambdaOperator(name: "λ.pressure→freq") { state in
        var result = LambdaTransformResult.neutral
        guard let pressure = state.dimensions[.pressure] else { return result }

        // Niedrig (500 hPa, Höhe) → Theta (4Hz), Normal (1013) → Alpha (10Hz),
        // Hoch (5000 hPa, Tiefsee) → Beta (20Hz)
        let normalized = (pressure.value - 500) / 4500  // 500–5000 → 0–1
        result.frequency = 4.0 + Swift.max(0, Swift.min(1.0, normalized)) * 16.0
        return result
    }

    // MARK: - Depth → Reverb

    /// Tiefe/Altitude auf Reverb mappen (tiefer = mehr Hall)
    public static let depthToReverb = LambdaOperator(name: "λ.depth→reverb") { state in
        var result = LambdaTransformResult.neutral
        if let depth = state.dimensions[.depth] {
            result.reverbMix = Float(Swift.min(1.0, depth.value / 100.0))
            result.spatialWidth = Float(Swift.min(1.0, 0.3 + depth.value / 200.0))
        } else if let altitude = state.dimensions[.altitude] {
            // Höhe: weniger Reverb (dünnere Luft)
            result.reverbMix = Float(Swift.max(0.0, 1.0 - altitude.value / 10000.0))
        }
        return result
    }

    // MARK: - Noise → Amplitude

    /// Umgebungslärm → inverse Amplitude (laut draußen = leiser bio-reaktiv)
    public static let noiseToAmplitude = LambdaOperator(name: "λ.noise→amplitude") { state in
        var result = LambdaTransformResult.neutral
        guard let noise = state.dimensions[.noise] else { return result }

        // 20 dB (Stille) → volle Lautstärke, 80 dB (laut) → minimal
        let normalized = (noise.value - 20) / 60.0
        result.amplitude = Double(Swift.max(0.1, 1.0 - Swift.min(1.0, normalized)))
        return result
    }

    // MARK: - Wind → Spatial Movement

    /// Wind auf Spatial-Audio Bewegung mappen
    public static let windToSpatial = LambdaOperator(name: "λ.wind→spatial") { state in
        var result = LambdaTransformResult.neutral
        if let wind = state.dimensions[.windSpeed] {
            result.spatialWidth = Float(Swift.min(1.0, wind.value / 15.0))
            result.metadata["windPan"] = Swift.min(1.0, wind.value / 20.0)
        }
        if let direction = state.dimensions[.windDirection] {
            result.metadata["windAngle"] = direction.value
        }
        return result
    }

    // MARK: - Gravity → Carrier Frequency

    /// Gravitation auf Carrier-Frequenz mappen
    public static let gravityToCarrier = LambdaOperator(name: "λ.gravity→carrier") { state in
        var result = LambdaTransformResult.neutral
        guard let gravity = state.dimensions[.gravity] else { return result }

        // 0g (Schwerelosigkeit) → 396 Hz (Erdung), 1g → 440 Hz, >1g → 528 Hz
        let gNorm = gravity.value / 9.81
        if gNorm < 0.1 {
            result.carrierFrequency = 396.0
        } else if gNorm < 1.5 {
            result.carrierFrequency = 440.0
        } else {
            result.carrierFrequency = 528.0
        }
        return result
    }

    // MARK: - Radiation → Haptic Warning

    /// Strahlung auf Haptic-Warnung mappen
    public static let radiationToHaptic = LambdaOperator(name: "λ.radiation→haptic") { state in
        var result = LambdaTransformResult.neutral
        guard let radiation = state.dimensions[.radiation] else { return result }

        // >10 µSv/h → leichtes Haptic, >50 → starkes
        let normalized = Float(radiation.value / 100.0)
        result.hapticIntensity = Swift.min(1.0, normalized)
        return result
    }

    // MARK: - Water Quality → Harmonic Richness

    /// Wasserqualität → harmonischer Reichtum
    public static let waterToHarmonics = LambdaOperator(name: "λ.water→harmonics") { state in
        var result = LambdaTransformResult.neutral
        if let ph = state.dimensions[.pH] {
            // pH 7 = neutral = harmonisch, Abweichung = dissonant
            let deviation = abs(ph.value - 7.0) / 7.0
            result.metadata["harmonicRichness"] = Swift.max(0.0, 1.0 - deviation)
        }
        if let oxygen = state.dimensions[.dissolvedOxygen] {
            result.metadata["oxygenBrightness"] = Swift.min(1.0, oxygen.value / 12.0)
        }
        return result
    }

    // MARK: - Light → Visual Intensity

    /// Umgebungslicht → visuelle Intensität (Gegensteuern)
    public static let lightToVisual = LambdaOperator(name: "λ.light→visual") { state in
        var result = LambdaTransformResult.neutral
        guard let light = state.dimensions[.lightLevel] else { return result }

        // Hell draußen → gedimmte Visuals, Dunkelheit → intensive Visuals
        let normalized = Float(Swift.min(1.0, light.value / 50000.0))
        result.metadata["visualIntensity"] = Double(Swift.max(0.2, 1.0 - normalized * 0.7))
        return result
    }
}

// MARK: - Lambda Chain

/// Composable Kette von Lambda-Operatoren
/// Wie eine Quantenschaltkreis-Sequenz: |ψ⟩ → Û₁ → Û₂ → ... → |ψ'⟩
public struct LambdaChain: Sendable {
    public var operators: [LambdaOperator]

    public init(_ operators: [LambdaOperator] = []) {
        self.operators = operators
    }

    /// Operator anhängen
    public func appending(_ op: LambdaOperator) -> LambdaChain {
        var chain = self
        chain.operators.append(op)
        return chain
    }

    /// Kette ausführen und Ergebnisse blenden
    public func execute(on state: EnvironmentStateVector) -> LambdaTransformResult {
        guard !operators.isEmpty else { return .neutral }

        var accumulated = operators[0].transform(state)
        for i in 1..<operators.count {
            let next = operators[i].transform(state)
            accumulated = accumulated.blended(with: next, factor: 1.0 / Double(i + 1))
        }
        return accumulated
    }

    /// Kette mit Gewichtung ausführen
    public func executeWeighted(on state: EnvironmentStateVector, weights: [Double]) -> LambdaTransformResult {
        guard !operators.isEmpty else { return .neutral }
        let totalWeight = weights.prefix(operators.count).reduce(0, +)
        guard totalWeight > 0 else { return .neutral }

        var accumulated = LambdaTransformResult.neutral
        for (i, op) in operators.enumerated() {
            let weight = i < weights.count ? weights[i] / totalWeight : 0
            let result = op.transform(state)
            accumulated = accumulated.blended(with: result, factor: weight)
        }
        return accumulated
    }

    // MARK: - Preset Chains

    /// Universelle Standard-Kette (funktioniert überall)
    public static let universal = LambdaChain([
        LambdaOperators.comfortToCoherence,
        LambdaOperators.temperatureToColor,
        LambdaOperators.pressureToFrequency,
        LambdaOperators.noiseToAmplitude,
        LambdaOperators.lightToVisual
    ])

    /// Aquatische Kette (Tauchen, Unterwasser)
    public static let aquatic = LambdaChain([
        LambdaOperators.comfortToCoherence,
        LambdaOperators.depthToReverb,
        LambdaOperators.pressureToFrequency,
        LambdaOperators.waterToHarmonics,
        LambdaOperators.temperatureToColor
    ])

    /// Atmosphärische Kette (Fliegen, Höhe)
    public static let aerial = LambdaChain([
        LambdaOperators.comfortToCoherence,
        LambdaOperators.pressureToFrequency,
        LambdaOperators.windToSpatial,
        LambdaOperators.depthToReverb,
        LambdaOperators.temperatureToColor
    ])

    /// Extraterrestrische Kette (Orbit, Weltraum)
    public static let extraterrestrial = LambdaChain([
        LambdaOperators.comfortToCoherence,
        LambdaOperators.gravityToCarrier,
        LambdaOperators.radiationToHaptic,
        LambdaOperators.noiseToAmplitude,
        LambdaOperators.temperatureToColor
    ])

    /// Fahrzeug-Kette
    public static let vehicular = LambdaChain([
        LambdaOperators.comfortToCoherence,
        LambdaOperators.noiseToAmplitude,
        LambdaOperators.temperatureToColor,
        LambdaOperators.lightToVisual
    ])

    /// Forschungsinstitut Bahrenfeld Kette
    public static let bahrenfeldResearch = LambdaChain([
        LambdaOperators.comfortToCoherence,
        LambdaOperators.temperatureToColor,
        LambdaOperators.waterToHarmonics,
        LambdaOperators.noiseToAmplitude,
        LambdaOperators.lightToVisual,
        LambdaOperators.windToSpatial
    ])

    /// Automatische Ketten-Auswahl basierend auf Environment-Domäne
    public static func chain(for domain: EnvironmentDomain) -> LambdaChain {
        switch domain {
        case .terrestrial: return .universal
        case .aquatic: return .aquatic
        case .aerial: return .aerial
        case .extraterrestrial: return .extraterrestrial
        case .vehicular: return .vehicular
        case .subterranean: return .universal // Höhlen nutzen universelle Kette
        }
    }
}

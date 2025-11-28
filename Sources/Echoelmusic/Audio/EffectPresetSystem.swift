//
//  EffectPresetSystem.swift
//  Echoelmusic
//
//  Created: 2025-11-28
//  Professional Effect Preset & Chain Management
//
//  Features:
//  - Save/load effect presets
//  - Effect chain management
//  - Parameter automation keyframes
//  - A/B comparison
//  - Undo/Redo for effect changes
//

import Foundation
import Combine

// MARK: - Effect Parameter

/// Represents a single effect parameter
public struct EffectParameter: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let minValue: Float
    public let maxValue: Float
    public let defaultValue: Float
    public var currentValue: Float
    public let unit: String  // "dB", "Hz", "ms", "%", etc.
    public let curve: ParameterCurve

    public enum ParameterCurve: String, Codable {
        case linear
        case logarithmic
        case exponential
        case sCurve
    }

    public init(id: String, name: String, min: Float, max: Float, defaultValue: Float, unit: String = "", curve: ParameterCurve = .linear) {
        self.id = id
        self.name = name
        self.minValue = min
        self.maxValue = max
        self.defaultValue = defaultValue
        self.currentValue = defaultValue
        self.unit = unit
        self.curve = curve
    }

    /// Normalize value to 0-1 range
    public var normalizedValue: Float {
        (currentValue - minValue) / (maxValue - minValue)
    }

    /// Set from normalized 0-1 value
    public mutating func setNormalized(_ value: Float) {
        currentValue = minValue + value * (maxValue - minValue)
    }
}

// MARK: - Effect Preset

/// Complete preset for a single effect
public struct EffectPreset: Codable, Identifiable {
    public let id: UUID
    public var name: String
    public let effectType: String
    public var parameters: [String: Float]  // Parameter ID → Value
    public var isDefault: Bool
    public var category: String
    public var tags: [String]
    public let createdAt: Date
    public var modifiedAt: Date
    public var author: String

    public init(id: UUID = UUID(), name: String, effectType: String, parameters: [String: Float] = [:]) {
        self.id = id
        self.name = name
        self.effectType = effectType
        self.parameters = parameters
        self.isDefault = false
        self.category = "User"
        self.tags = []
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.author = "User"
    }
}

// MARK: - Effect Chain Preset

/// Complete preset for an effect chain (multiple effects in series)
public struct EffectChainPreset: Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var effects: [EffectSlot]
    public var category: String
    public var tags: [String]
    public let createdAt: Date
    public var modifiedAt: Date
    public var author: String
    public var description: String

    public struct EffectSlot: Codable, Identifiable {
        public let id: UUID
        public var effectType: String
        public var parameters: [String: Float]
        public var isBypassed: Bool
        public var mixAmount: Float  // 0-1 dry/wet

        public init(effectType: String, parameters: [String: Float] = [:]) {
            self.id = UUID()
            self.effectType = effectType
            self.parameters = parameters
            self.isBypassed = false
            self.mixAmount = 1.0
        }
    }

    public init(id: UUID = UUID(), name: String, effects: [EffectSlot] = []) {
        self.id = id
        self.name = name
        self.effects = effects
        self.category = "User"
        self.tags = []
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.author = "User"
        self.description = ""
    }
}

// MARK: - Parameter Automation

/// Keyframe-based parameter automation
public struct ParameterAutomation: Codable, Identifiable {
    public let id: UUID
    public let effectId: UUID
    public let parameterId: String
    public var keyframes: [Keyframe]
    public var isEnabled: Bool
    public var interpolation: InterpolationType

    public struct Keyframe: Codable, Identifiable, Comparable {
        public let id: UUID
        public var time: Double  // In seconds
        public var value: Float
        public var curve: CurveType

        public enum CurveType: String, Codable {
            case linear
            case hold  // Step/instant
            case easeIn
            case easeOut
            case easeInOut
            case bezier
        }

        public init(time: Double, value: Float, curve: CurveType = .linear) {
            self.id = UUID()
            self.time = time
            self.value = value
            self.curve = curve
        }

        public static func < (lhs: Keyframe, rhs: Keyframe) -> Bool {
            lhs.time < rhs.time
        }
    }

    public enum InterpolationType: String, Codable {
        case linear
        case smooth
        case step
    }

    public init(effectId: UUID, parameterId: String) {
        self.id = UUID()
        self.effectId = effectId
        self.parameterId = parameterId
        self.keyframes = []
        self.isEnabled = true
        self.interpolation = .linear
    }

    /// Evaluate automation at given time
    public func evaluate(at time: Double) -> Float? {
        guard isEnabled, !keyframes.isEmpty else { return nil }

        let sorted = keyframes.sorted()

        // Before first keyframe
        if time <= sorted.first!.time {
            return sorted.first!.value
        }

        // After last keyframe
        if time >= sorted.last!.time {
            return sorted.last!.value
        }

        // Find surrounding keyframes
        for i in 0..<(sorted.count - 1) {
            let k1 = sorted[i]
            let k2 = sorted[i + 1]

            if time >= k1.time && time <= k2.time {
                let t = Float((time - k1.time) / (k2.time - k1.time))
                return interpolate(from: k1.value, to: k2.value, t: t, curve: k1.curve)
            }
        }

        return nil
    }

    private func interpolate(from v1: Float, to v2: Float, t: Float, curve: Keyframe.CurveType) -> Float {
        let easedT: Float
        switch curve {
        case .linear:
            easedT = t
        case .hold:
            easedT = 0
        case .easeIn:
            easedT = t * t
        case .easeOut:
            easedT = 1 - (1 - t) * (1 - t)
        case .easeInOut:
            easedT = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
        case .bezier:
            // Cubic bezier approximation
            easedT = t * t * (3 - 2 * t)
        }
        return v1 + (v2 - v1) * easedT
    }

    /// Add keyframe
    public mutating func addKeyframe(at time: Double, value: Float, curve: Keyframe.CurveType = .linear) {
        let keyframe = Keyframe(time: time, value: value, curve: curve)
        keyframes.append(keyframe)
        keyframes.sort()
    }

    /// Remove keyframe
    public mutating func removeKeyframe(id: UUID) {
        keyframes.removeAll { $0.id == id }
    }
}

// MARK: - Effect Preset Manager

/// Manages effect presets with persistence
@MainActor
public final class EffectPresetManager: ObservableObject {
    public static let shared = EffectPresetManager()

    @Published public private(set) var presets: [EffectPreset] = []
    @Published public private(set) var chainPresets: [EffectChainPreset] = []
    @Published public private(set) var automations: [UUID: ParameterAutomation] = [:]

    private let presetsURL: URL
    private let chainsURL: URL
    private var cancellables = Set<AnyCancellable>()

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let presetsDir = documentsPath.appendingPathComponent("Presets", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: presetsDir, withIntermediateDirectories: true)

        self.presetsURL = presetsDir.appendingPathComponent("effects.json")
        self.chainsURL = presetsDir.appendingPathComponent("chains.json")

        loadPresets()
        loadFactoryPresets()
    }

    // MARK: - Preset Management

    /// Save effect preset
    public func savePreset(_ preset: EffectPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
        persistPresets()
    }

    /// Delete effect preset
    public func deletePreset(id: UUID) {
        presets.removeAll { $0.id == id }
        persistPresets()
    }

    /// Get presets for effect type
    public func presets(for effectType: String) -> [EffectPreset] {
        presets.filter { $0.effectType == effectType }
    }

    /// Save chain preset
    public func saveChainPreset(_ chain: EffectChainPreset) {
        if let index = chainPresets.firstIndex(where: { $0.id == chain.id }) {
            chainPresets[index] = chain
        } else {
            chainPresets.append(chain)
        }
        persistChains()
    }

    /// Delete chain preset
    public func deleteChainPreset(id: UUID) {
        chainPresets.removeAll { $0.id == id }
        persistChains()
    }

    // MARK: - Automation

    /// Add automation for parameter
    public func addAutomation(effectId: UUID, parameterId: String) -> ParameterAutomation {
        let automation = ParameterAutomation(effectId: effectId, parameterId: parameterId)
        automations[automation.id] = automation
        return automation
    }

    /// Update automation
    public func updateAutomation(_ automation: ParameterAutomation) {
        automations[automation.id] = automation
    }

    /// Remove automation
    public func removeAutomation(id: UUID) {
        automations.removeValue(forKey: id)
    }

    /// Evaluate all automations at time
    public func evaluateAutomations(at time: Double) -> [UUID: [String: Float]] {
        var results: [UUID: [String: Float]] = [:]

        for (_, automation) in automations where automation.isEnabled {
            if let value = automation.evaluate(at: time) {
                if results[automation.effectId] == nil {
                    results[automation.effectId] = [:]
                }
                results[automation.effectId]?[automation.parameterId] = value
            }
        }

        return results
    }

    // MARK: - Persistence

    private func loadPresets() {
        guard FileManager.default.fileExists(atPath: presetsURL.path) else { return }

        do {
            let data = try Data(contentsOf: presetsURL)
            presets = try JSONDecoder().decode([EffectPreset].self, from: data)
        } catch {
            print("Failed to load presets: \(error)")
        }
    }

    private func persistPresets() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(presets)
            try data.write(to: presetsURL)
        } catch {
            print("Failed to save presets: \(error)")
        }
    }

    private func loadChains() {
        guard FileManager.default.fileExists(atPath: chainsURL.path) else { return }

        do {
            let data = try Data(contentsOf: chainsURL)
            chainPresets = try JSONDecoder().decode([EffectChainPreset].self, from: data)
        } catch {
            print("Failed to load chains: \(error)")
        }
    }

    private func persistChains() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(chainPresets)
            try data.write(to: chainsURL)
        } catch {
            print("Failed to save chains: \(error)")
        }
    }

    // MARK: - Factory Presets

    private func loadFactoryPresets() {
        // Only add factory presets if none exist
        guard presets.isEmpty else { return }

        // Compressor presets
        presets.append(EffectPreset(
            name: "Vocal Compression",
            effectType: "compressor",
            parameters: ["threshold": -18, "ratio": 4, "attack": 10, "release": 100, "makeup": 6]
        ))
        presets.append(EffectPreset(
            name: "Drum Bus",
            effectType: "compressor",
            parameters: ["threshold": -12, "ratio": 6, "attack": 1, "release": 50, "makeup": 4]
        ))
        presets.append(EffectPreset(
            name: "Gentle Glue",
            effectType: "compressor",
            parameters: ["threshold": -24, "ratio": 2, "attack": 30, "release": 200, "makeup": 2]
        ))

        // Reverb presets
        presets.append(EffectPreset(
            name: "Large Hall",
            effectType: "reverb",
            parameters: ["size": 0.9, "decay": 3.5, "predelay": 30, "damping": 0.4, "mix": 0.3]
        ))
        presets.append(EffectPreset(
            name: "Tight Room",
            effectType: "reverb",
            parameters: ["size": 0.3, "decay": 0.8, "predelay": 5, "damping": 0.6, "mix": 0.2]
        ))
        presets.append(EffectPreset(
            name: "Plate Shimmer",
            effectType: "reverb",
            parameters: ["size": 0.7, "decay": 2.5, "predelay": 15, "damping": 0.2, "mix": 0.25]
        ))

        // Delay presets
        presets.append(EffectPreset(
            name: "Slapback",
            effectType: "delay",
            parameters: ["time": 80, "feedback": 0.1, "mix": 0.3, "sync": 0]
        ))
        presets.append(EffectPreset(
            name: "Ping Pong",
            effectType: "delay",
            parameters: ["time": 375, "feedback": 0.45, "mix": 0.25, "sync": 1, "pingpong": 1]
        ))
        presets.append(EffectPreset(
            name: "Ambient Wash",
            effectType: "delay",
            parameters: ["time": 500, "feedback": 0.65, "mix": 0.2, "damping": 0.7]
        ))

        // EQ presets
        presets.append(EffectPreset(
            name: "Vocal Presence",
            effectType: "eq",
            parameters: ["lowCut": 80, "low": -2, "lowMid": 0, "highMid": 3, "high": 2, "highCut": 16000]
        ))
        presets.append(EffectPreset(
            name: "Bass Enhancement",
            effectType: "eq",
            parameters: ["lowCut": 30, "low": 4, "lowMid": 2, "highMid": -1, "high": 0]
        ))

        // Mark as factory presets
        for i in 0..<presets.count {
            presets[i].isDefault = true
            presets[i].category = "Factory"
            presets[i].author = "Echoelmusic"
        }

        persistPresets()
    }
}

// MARK: - A/B Comparison

/// A/B comparison state for effect chains
@MainActor
public final class ABComparison: ObservableObject {
    @Published public var stateA: EffectChainPreset?
    @Published public var stateB: EffectChainPreset?
    @Published public var isShowingB: Bool = false

    public var currentState: EffectChainPreset? {
        isShowingB ? stateB : stateA
    }

    /// Capture current state as A
    public func captureA(_ chain: EffectChainPreset) {
        stateA = chain
    }

    /// Capture current state as B
    public func captureB(_ chain: EffectChainPreset) {
        stateB = chain
    }

    /// Toggle between A and B
    public func toggle() {
        isShowingB.toggle()
    }

    /// Swap A and B
    public func swap() {
        let temp = stateA
        stateA = stateB
        stateB = temp
    }

    /// Copy A to B
    public func copyAtoB() {
        stateB = stateA
    }

    /// Copy B to A
    public func copyBtoA() {
        stateA = stateB
    }
}

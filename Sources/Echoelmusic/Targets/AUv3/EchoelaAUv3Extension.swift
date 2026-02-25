// MARK: - EchoelaAUv3Extension.swift
// Echoelmusic Suite - AUv3 Plugin Extension
// Bundle ID: com.echoelmusic.app.auv3
// Copyright 2026 Echoelmusic. All rights reserved.

import Foundation
import AudioToolbox
import AVFoundation
import CoreAudioKit
import Combine

// MARK: - Echoela AUv3 Manager

/// AUv3 extension for Echoela integration in external DAWs (Logic Pro, Ableton, etc.)
/// Provides AI-assisted parameter control and bio-reactive modulation
@MainActor
public final class EchoelaAUv3Manager: ObservableObject {

    // MARK: - Singleton

    public static let shared = EchoelaAUv3Manager()

    // MARK: - Published State

    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var lockedParameters: Set<AUParameterAddress> = []
    @Published public private(set) var bioModulationEnabled: Bool = false
    @Published public private(set) var currentPreset: String?
    @Published public private(set) var latencyMs: Double = 0

    // MARK: - Types

    /// Parameter lock state
    public struct ParameterLock: Identifiable, Codable {
        public let id: UUID
        public let address: AUParameterAddress
        public let name: String
        public let lockedValue: Float
        public let lockedAt: Date
        public let lockedBy: LockSource

        public enum LockSource: String, Codable {
            case echoela = "Echoela AI"
            case user = "User"
            case bioReactive = "Bio-Reactive"
        }
    }

    /// Bio-reactive modulation mapping
    public struct BioModulation: Identifiable, Codable {
        public let id: UUID
        public let parameterAddress: AUParameterAddress
        public let parameterName: String
        public let bioSource: BioSource
        public let mappingCurve: MappingCurve
        public let intensity: Double  // 0-1
        public let inverted: Bool

        public enum BioSource: String, Codable {
            case heartRate = "Heart Rate"
            case hrv = "HRV"
            case coherence = "Coherence"
            case breathingRate = "Breathing Rate"
            case breathPhase = "Breath Phase"
        }

        public enum MappingCurve: String, Codable {
            case linear
            case exponential
            case logarithmic
            case sCurve
            case stepped
        }
    }

    /// AUv3 preset
    public struct AUv3Preset: Identifiable, Codable {
        public let id: UUID
        public let name: String
        public let parameters: [AUParameterAddress: Float]
        public let bioModulations: [BioModulation]
        public let locks: [ParameterLock]
        public let createdAt: Date
        public let echoelaGenerated: Bool
    }

    // MARK: - Properties

    private var audioUnit: AUAudioUnit?
    private var parameterTree: AUParameterTree?
    private var cancellables = Set<AnyCancellable>()
    private var bioModulations: [BioModulation] = []
    private var parameterLocks: [AUParameterAddress: ParameterLock] = [:]

    // MARK: - Configuration

    /// Target latency for real-time processing
    public static let targetLatencyMs: Double = 3.0

    /// Maximum bio modulation update rate
    public static let bioUpdateRateHz: Double = 60.0

    // MARK: - Initialization

    private init() {
        setupEchoelaContext()
    }

    private func setupEchoelaContext() {
        // Set Echoela context to AUv3 mode
        Task { @MainActor in
            EchoelaManager.shared.setContext(.auv3)
        }

        // Listen for Echoela actions
        NotificationCenter.default.publisher(for: .echoelaAction)
            .compactMap { $0.userInfo as? [String: Any] }
            .filter { ($0["category"] as? String) == "auv3" }
            .sink { [weak self] info in
                self?.handleEchoelaAction(info)
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Connect to an AUv3 audio unit
    public func connect(to audioUnit: AUAudioUnit) {
        self.audioUnit = audioUnit
        self.parameterTree = audioUnit.parameterTree
        self.isConnected = true

        // Calculate latency
        if let outputBusses = audioUnit.outputBusses.first {
            let sampleRate = outputBusses.format.sampleRate
            let frameCount = Double(audioUnit.maximumFramesToRender)
            latencyMs = (frameCount / sampleRate) * 1000
        }
    }

    /// Disconnect from audio unit
    public func disconnect() {
        audioUnit = nil
        parameterTree = nil
        isConnected = false
        lockedParameters.removeAll()
        bioModulations.removeAll()
    }

    /// Lock a parameter (prevents external modification)
    public func lockParameter(
        address: AUParameterAddress,
        name: String,
        source: ParameterLock.LockSource = .user
    ) {
        guard let param = parameterTree?.parameter(withAddress: address) else { return }

        let lock = ParameterLock(
            id: UUID(),
            address: address,
            name: name,
            lockedValue: param.value,
            lockedAt: Date(),
            lockedBy: source
        )

        parameterLocks[address] = lock
        lockedParameters.insert(address)
    }

    /// Unlock a parameter
    public func unlockParameter(address: AUParameterAddress) {
        parameterLocks.removeValue(forKey: address)
        lockedParameters.remove(address)
    }

    /// Lock all parameters (Echoela command)
    public func lockAllParameters() {
        parameterTree?.allParameters.forEach { param in
            lockParameter(address: param.address, name: param.displayName, source: .echoela)
        }
    }

    /// Unlock all parameters
    public func unlockAllParameters() {
        lockedParameters.removeAll()
        parameterLocks.removeAll()
    }

    /// Add bio-reactive modulation
    public func addBioModulation(_ modulation: BioModulation) {
        // Remove existing modulation for same parameter
        bioModulations.removeAll { $0.parameterAddress == modulation.parameterAddress }
        bioModulations.append(modulation)
        bioModulationEnabled = !bioModulations.isEmpty
    }

    /// Remove bio modulation
    public func removeBioModulation(for address: AUParameterAddress) {
        bioModulations.removeAll { $0.parameterAddress == address }
        bioModulationEnabled = !bioModulations.isEmpty
    }

    /// Update bio-reactive parameters
    public func updateBioModulations(
        heartRate: Double,
        hrv: Double,
        coherence: Double,
        breathingRate: Double,
        breathPhase: Double
    ) {
        guard bioModulationEnabled else { return }

        for modulation in bioModulations {
            guard !lockedParameters.contains(modulation.parameterAddress) else { continue }

            let rawValue: Double
            switch modulation.bioSource {
            case .heartRate:
                rawValue = normalize(heartRate, from: 40...200)
            case .hrv:
                rawValue = normalize(hrv, from: 0...150)
            case .coherence:
                rawValue = coherence
            case .breathingRate:
                rawValue = normalize(breathingRate, from: 4...30)
            case .breathPhase:
                rawValue = breathPhase
            }

            let mappedValue = applyMappingCurve(rawValue, curve: modulation.mappingCurve)
            let finalValue = modulation.inverted ? (1.0 - mappedValue) : mappedValue
            let scaledValue = finalValue * modulation.intensity

            // Apply to parameter
            if let param = parameterTree?.parameter(withAddress: modulation.parameterAddress) {
                let range = param.maxValue - param.minValue
                let newValue = param.minValue + Float(scaledValue) * range
                param.value = newValue
            }
        }
    }

    /// Save current state as preset
    public func savePreset(name: String, echoelaGenerated: Bool = false) -> AUv3Preset {
        var parameters: [AUParameterAddress: Float] = [:]

        parameterTree?.allParameters.forEach { param in
            parameters[param.address] = param.value
        }

        let preset = AUv3Preset(
            id: UUID(),
            name: name,
            parameters: parameters,
            bioModulations: bioModulations,
            locks: Array(parameterLocks.values),
            createdAt: Date(),
            echoelaGenerated: echoelaGenerated
        )

        currentPreset = name
        return preset
    }

    /// Load preset
    public func loadPreset(_ preset: AUv3Preset) {
        // Apply parameters
        for (address, value) in preset.parameters {
            parameterTree?.parameter(withAddress: address)?.value = value
        }

        // Apply locks
        parameterLocks.removeAll()
        lockedParameters.removeAll()
        for lock in preset.locks {
            parameterLocks[lock.address] = lock
            lockedParameters.insert(lock.address)
        }

        // Apply bio modulations
        bioModulations = preset.bioModulations
        bioModulationEnabled = !bioModulations.isEmpty

        currentPreset = preset.name
    }

    /// Generate deep link for parameter control
    public func generateDeepLink(action: String, parameterAddress: AUParameterAddress? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = EchoelaManager.deepLinkScheme
        components.host = "action"
        components.path = "/auv3/\(action)"

        if let address = parameterAddress {
            components.queryItems = [URLQueryItem(name: "param", value: String(address))]
        }

        return components.url
    }

    // MARK: - Private Methods

    private func handleEchoelaAction(_ info: [String: Any]) {
        guard let action = info["action"] as? String else { return }

        switch action {
        case "lock":
            if let params = info["params"] as? [String: String],
               let paramStr = params["param"],
               let address = AUParameterAddress(paramStr) {
                lockParameter(address: address, name: "Unknown", source: .echoela)
            } else {
                lockAllParameters()
            }

        case "unlock":
            if let params = info["params"] as? [String: String],
               let paramStr = params["param"],
               let address = AUParameterAddress(paramStr) {
                unlockParameter(address: address)
            } else {
                unlockAllParameters()
            }

        case "bio_enable":
            bioModulationEnabled = true

        case "bio_disable":
            bioModulationEnabled = false

        default:
            break
        }
    }

    private func normalize(_ value: Double, from range: ClosedRange<Double>) -> Double {
        return (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private func applyMappingCurve(_ value: Double, curve: BioModulation.MappingCurve) -> Double {
        let clamped = max(0, min(1, value))

        switch curve {
        case .linear:
            return clamped
        case .exponential:
            return pow(clamped, 2)
        case .logarithmic:
            return log10(1 + clamped * 9) / log10(10)
        case .sCurve:
            return clamped * clamped * (3 - 2 * clamped)
        case .stepped:
            return floor(clamped * 10) / 10
        }
    }
}

// MARK: - AUv3 View Controller Extension

#if canImport(UIKit)
import UIKit
import SwiftUI

/// SwiftUI view for AUv3 plugin interface with Echoela integration
public struct EchoelaAUv3View: View {
    @ObservedObject private var auv3Manager = EchoelaAUv3Manager.shared
    @ObservedObject private var echoela = EchoelaManager.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // Header with connection status
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(.purple)
                Text("Echoelmusic AUv3")
                    .font(.headline)
                Spacer()

                Circle()
                    .fill(auv3Manager.isConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(auv3Manager.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
            }

            // Latency indicator
            if auv3Manager.isConnected {
                HStack {
                    Text("Latency:")
                    Text(String(format: "%.1f ms", auv3Manager.latencyMs))
                        .foregroundStyle(auv3Manager.latencyMs < 5 ? .green : .orange)
                }
                .font(.caption)
            }

            Divider()

            // Parameter locks
            HStack {
                Text("Locked: \(auv3Manager.lockedParameters.count)")
                Spacer()
                Button("Lock All") {
                    auv3Manager.lockAllParameters()
                }
                .buttonStyle(.bordered)

                Button("Unlock All") {
                    auv3Manager.unlockAllParameters()
                }
                .buttonStyle(.bordered)
            }

            // Bio modulation toggle
            Toggle("Bio-Reactive Modulation", isOn: Binding(
                get: { auv3Manager.bioModulationEnabled },
                set: { _ in }  // Read-only display
            ))
            .disabled(true)

            Divider()

            // Echoela mini assistant
            if echoela.isActive {
                EchoelaAssistantView()
                    .frame(height: 200)
            } else {
                Button {
                    echoela.activate(in: .auv3)
                } label: {
                    Label("Activate Echoela", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
        }
        .padding()
    }
}
#endif

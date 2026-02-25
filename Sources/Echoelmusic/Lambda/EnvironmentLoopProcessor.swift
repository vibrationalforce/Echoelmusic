// EnvironmentLoopProcessor.swift
// Echoelmusic - λ% Ralph Wiggum Loop Quantum Light Science Developer Genius Mode
//
// 60Hz Adaptive Loop-Prozessor für universelles Environment-Processing
// Verbindet UniversalEnvironmentEngine mit LambdaChain und Bio-Daten
//
// Architektur:
//   ┌─────────────────────────────────────────────────────────────┐
//   │                    60Hz Control Loop                        │
//   │                                                             │
//   │  Sensors ──→ StateVector ──→ LambdaChain ──→ TransformResult│
//   │                                    ↑                        │
//   │  BioData ──────────────────────────┘            ↓           │
//   │                                          ┌──────────────┐   │
//   │                                          │ Audio Engine │   │
//   │                                          │ Visual Engine│   │
//   │                                          │ Haptic Engine│   │
//   │                                          │ DMX/Lighting │   │
//   │                                          └──────────────┘   │
//   └─────────────────────────────────────────────────────────────┘
//
// "My cat's breath smells like cat food" - Ralph Wiggum, Loop Theorist
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine

// MARK: - Loop State

/// Zustand des Environment-Loop-Prozessors
public enum EnvironmentLoopState: String, CaseIterable, Codable, Sendable {
    case idle = "Idle"
    case starting = "Starting"
    case running = "Running"
    case paused = "Paused"
    case transitioning = "Transitioning"
    case error = "Error"
}

// MARK: - Loop Tick Data

/// Ein einzelner Tick des 60Hz Loops
public struct EnvironmentLoopTick: Sendable {
    public let tickNumber: UInt64
    public let timestamp: Date
    public let deltaTime: TimeInterval       // Sekunden seit letztem Tick
    public let environmentState: EnvironmentStateVector
    public let lambdaResult: LambdaTransformResult
    public let transitionBlend: Double?      // nil wenn kein Übergang
    public let loopLatencyMs: Double
}

// MARK: - Loop Statistics

/// Laufzeitstatistiken des Loops
public struct EnvironmentLoopStats: Sendable {
    public var totalTicks: UInt64 = 0
    public var averageLatencyMs: Double = 0.0
    public var maxLatencyMs: Double = 0.0
    public var droppedFrames: UInt64 = 0
    public var environmentChanges: UInt64 = 0
    public var uptimeSeconds: TimeInterval = 0.0
}

// MARK: - Environment Loop Processor

/// 60Hz Adaptive Loop für universelles Environment-Processing
/// Verbindet Sensordaten mit Lambda-Kette und erzeugt bio-reaktive Outputs
@MainActor
public class EnvironmentLoopProcessor: ObservableObject {

    public static let shared = EnvironmentLoopProcessor()

    // MARK: - Dependencies

    private let environmentEngine = UniversalEnvironmentEngine.shared

    // MARK: - Published State

    @Published public var loopState: EnvironmentLoopState = .idle
    @Published public var currentTick: EnvironmentLoopTick?
    @Published public var stats: EnvironmentLoopStats = EnvironmentLoopStats()
    @Published public var currentLambdaResult: LambdaTransformResult = .neutral

    // MARK: - Configuration

    @Published public var targetHz: Double = 60.0
    @Published public var adaptiveHz: Bool = true             // Automatisch reduzieren bei hoher CPU
    @Published public var activeLambdaChain: LambdaChain = .universal
    @Published public var autoSelectChain: Bool = true        // Chain auto-wählen basierend auf Environment

    // MARK: - Output Publishers (andere Engines subscriben hierauf)

    public let coherenceOutput = PassthroughSubject<Double, Never>()
    public let frequencyOutput = PassthroughSubject<Double, Never>()
    public let colorOutput = PassthroughSubject<(r: Float, g: Float, b: Float), Never>()
    public let spatialOutput = PassthroughSubject<Float, Never>()
    public let reverbOutput = PassthroughSubject<Float, Never>()
    public let hapticOutput = PassthroughSubject<Float, Never>()

    // MARK: - Private State

    private var tickCounter: UInt64 = 0
    private var lastTickTime: Date = Date()
    private var loopStartTime: Date?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupEnvironmentSubscription()
    }

    // MARK: - Lifecycle

    /// Loop starten
    public func start() {
        guard loopState != .running else { return }
        loopState = .starting
        tickCounter = 0
        lastTickTime = Date()
        loopStartTime = Date()
        stats = EnvironmentLoopStats()

        let interval = 1.0 / targetHz
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        loopState = .running
    }

    /// Loop stoppen
    public func stop() {
        timer?.invalidate()
        timer = nil
        loopState = .idle
    }

    /// Loop pausieren
    public func pause() {
        guard loopState == .running else { return }
        timer?.invalidate()
        timer = nil
        loopState = .paused
    }

    /// Loop fortsetzen
    public func resume() {
        guard loopState == .paused else { return }
        let interval = 1.0 / targetHz
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        loopState = .running
    }

    // MARK: - Core Tick

    private func tick() {
        let now = Date()
        let delta = now.timeIntervalSince(lastTickTime)
        lastTickTime = now

        tickCounter += 1

        // Lambda Chain automatisch wählen
        if autoSelectChain {
            let domain = environmentEngine.currentEnvironment.domain
            activeLambdaChain = LambdaChain.chain(for: domain)
        }

        // Lambda Chain ausführen
        let state = environmentEngine.stateVector
        let result = activeLambdaChain.execute(on: state)

        // Transition Blending
        var finalResult = result
        var transitionBlend: Double? = nil
        if let transition = environmentEngine.activeTransition {
            transitionBlend = transition.blendFactor
            // Während Übergang: altes Environment einblenden
            let oldState = EnvironmentStateVector(environmentClass: transition.from)
            let oldResult = activeLambdaChain.execute(on: oldState)
            finalResult = oldResult.blended(with: result, factor: transition.blendFactor)
        }

        currentLambdaResult = finalResult

        // Latenz berechnen
        let latencyMs = Date().timeIntervalSince(now) * 1000.0

        // Tick-Daten erzeugen
        let tick = EnvironmentLoopTick(
            tickNumber: tickCounter,
            timestamp: now,
            deltaTime: delta,
            environmentState: state,
            lambdaResult: finalResult,
            transitionBlend: transitionBlend,
            loopLatencyMs: latencyMs
        )
        currentTick = tick

        // Statistiken updaten
        stats.totalTicks = tickCounter
        stats.averageLatencyMs = (stats.averageLatencyMs * Double(tickCounter - 1) + latencyMs) / Double(tickCounter)
        stats.maxLatencyMs = Swift.max(stats.maxLatencyMs, latencyMs)
        if let start = loopStartTime {
            stats.uptimeSeconds = now.timeIntervalSince(start)
        }

        // Check für dropped Frames
        let expectedInterval = 1.0 / targetHz
        if delta > expectedInterval * 2.0 {
            stats.droppedFrames += UInt64(delta / expectedInterval) - 1
        }

        // Outputs an subscribende Engines senden
        coherenceOutput.send(finalResult.coherenceModifier)
        frequencyOutput.send(finalResult.frequency)
        colorOutput.send(finalResult.color)
        spatialOutput.send(finalResult.spatialWidth)
        reverbOutput.send(finalResult.reverbMix)
        hapticOutput.send(finalResult.hapticIntensity)
    }

    // MARK: - Environment Auto-Detection

    private func setupEnvironmentSubscription() {
        environmentEngine.$currentEnvironment
            .removeDuplicates()
            .sink { [weak self] newEnv in
                guard let self else { return }
                self.stats.environmentChanges += 1

                if self.autoSelectChain {
                    self.activeLambdaChain = LambdaChain.chain(for: newEnv.domain)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Adaptive Hz

    /// Hz dynamisch anpassen (z.B. bei niedrigem Akku)
    public func setAdaptiveHz(_ factor: Double) {
        guard adaptiveHz else { return }
        let newHz = Swift.max(10.0, Swift.min(120.0, 60.0 * factor))
        guard abs(newHz - targetHz) > 1.0 else { return }
        targetHz = newHz

        if loopState == .running {
            timer?.invalidate()
            let interval = 1.0 / newHz
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.tick()
                }
            }
        }
    }

    // MARK: - Custom Lambda Injection

    /// Eigenen Lambda-Operator in die Kette einfügen
    public func injectOperator(_ op: LambdaOperator) {
        activeLambdaChain = activeLambdaChain.appending(op)
    }

    /// Lambda-Kette komplett ersetzen
    public func setLambdaChain(_ chain: LambdaChain) {
        autoSelectChain = false
        activeLambdaChain = chain
    }
}

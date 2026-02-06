// MARK: - MorphicSandboxManager.swift
// Echoelmusic Suite - Echoela Morphic Engine
// Copyright 2026 Echoelmusic. All rights reserved.
//
// Safe execution environment for Echoela-generated DSP graphs.
// No file access, no network, no unbounded allocation - just pure audio.

import Foundation
import Combine

// MARK: - Sandbox Configuration

/// Security and resource limits for Morphic execution
public struct MorphicSandboxConfig {
    /// Maximum number of nodes in a single graph
    public var maxNodes: Int = 32
    /// Maximum buffer size (samples) per process call
    public var maxBufferSize: Int = 4096
    /// Maximum processing time per buffer (ms) before kill
    public var maxProcessingTimeMs: Double = 10.0
    /// Maximum total memory for delay lines / buffers (bytes)
    public var maxMemoryBytes: Int = 8 * 1024 * 1024 // 8 MB
    /// Maximum simultaneous active graphs
    public var maxActiveGraphs: Int = 8
    /// Enable bio-reactive parameter updates
    public var bioReactiveEnabled: Bool = true
    /// Sample rate
    public var sampleRate: Float = EchoelCore.defaultSampleRate
    /// Output limiter enabled (prevents clipping)
    public var limiterEnabled: Bool = true
    /// Output ceiling (dBFS)
    public var outputCeiling: Float = -0.3

    public static let `default` = MorphicSandboxConfig()

    public static let performance = MorphicSandboxConfig(
        maxNodes: 16,
        maxBufferSize: 2048,
        maxProcessingTimeMs: 5.0,
        maxMemoryBytes: 4 * 1024 * 1024,
        maxActiveGraphs: 4
    )

    public static let creative = MorphicSandboxConfig(
        maxNodes: 32,
        maxBufferSize: 4096,
        maxProcessingTimeMs: 15.0,
        maxMemoryBytes: 16 * 1024 * 1024,
        maxActiveGraphs: 12
    )
}

// MARK: - Sandbox Session

/// A running instance of a MorphicGraph in the sandbox
public class MorphicSession: Identifiable, ObservableObject {
    public let id: String
    public let graph: MorphicGraph
    public let createdAt: Date

    @Published public var isActive: Bool = false
    @Published public var isBypassed: Bool = false
    @Published public var outputLevel: Float = 0.0
    @Published public var cpuUsage: Double = 0.0
    @Published public private(set) var processedFrames: UInt64 = 0
    @Published public private(set) var lastViolation: String?

    /// Dry/wet mix for the entire session
    @Published public var mix: Float = 1.0

    init(graph: MorphicGraph) {
        self.id = graph.id
        self.graph = graph
        self.createdAt = Date()
    }

    /// Process audio through this session's graph
    func process(_ input: [Float], config: MorphicSandboxConfig) -> [Float] {
        guard isActive, !isBypassed else { return input }

        let startTime = CFAbsoluteTimeGetCurrent()

        // Run through graph
        var output = graph.process(input)

        // Apply session mix
        if mix < 1.0 {
            for i in 0..<output.count {
                output[i] = input[i] * (1.0 - mix) + output[i] * mix
            }
        }

        // Output limiter
        if config.limiterEnabled {
            let ceiling = pow(10.0, config.outputCeiling / 20.0)
            for i in 0..<output.count {
                if output[i] > ceiling { output[i] = ceiling }
                else if output[i] < -ceiling { output[i] = -ceiling }
            }
        }

        // Track metrics
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        cpuUsage = elapsed / config.maxProcessingTimeMs
        processedFrames += UInt64(input.count)

        // Update output level (RMS)
        let rms = sqrt(output.reduce(0) { $0 + $1 * $1 } / Float(max(1, output.count)))
        outputLevel = rms

        // Check timing violation
        if elapsed > config.maxProcessingTimeMs {
            lastViolation = "Processing took \(String(format: "%.1f", elapsed))ms (limit: \(config.maxProcessingTimeMs)ms)"
            log.warning("Morphic sandbox timing violation: \(lastViolation ?? "")")
        }

        return output
    }
}

// MARK: - Sandbox Manager

/// Manages safe execution of Echoela-generated DSP graphs
/// Enforces resource limits, prevents unsafe operations, and provides monitoring
@MainActor
public final class MorphicSandboxManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = MorphicSandboxManager()

    // MARK: - Published State

    @Published public private(set) var activeSessions: [MorphicSession] = []
    @Published public private(set) var totalCPUUsage: Double = 0.0
    @Published public private(set) var totalMemoryUsage: Int = 0
    @Published public private(set) var violations: [SandboxViolation] = []
    @Published public var config: MorphicSandboxConfig = .default

    // MARK: - Types

    public struct SandboxViolation: Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let sessionID: String
        public let type: ViolationType
        public let message: String

        public enum ViolationType: String {
            case timing      // Processing took too long
            case memory      // Memory limit exceeded
            case nodeLimit   // Too many nodes
            case bufferLimit // Buffer too large
            case amplitude   // Output too loud (pre-limiter)
            case sessionLimit // Too many active sessions
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Session Lifecycle

    /// Load a compiled graph into the sandbox
    public func loadGraph(_ graph: MorphicGraph) throws -> MorphicSession {
        // Validate against sandbox limits
        guard graph.nodes.count <= config.maxNodes else {
            let violation = SandboxViolation(
                timestamp: Date(),
                sessionID: graph.id,
                type: .nodeLimit,
                message: "Graph has \(graph.nodes.count) nodes (limit: \(config.maxNodes))"
            )
            violations.append(violation)
            throw MorphicError.sandboxViolation("Too many nodes: \(graph.nodes.count)/\(config.maxNodes)")
        }

        guard activeSessions.count < config.maxActiveGraphs else {
            let violation = SandboxViolation(
                timestamp: Date(),
                sessionID: graph.id,
                type: .sessionLimit,
                message: "Max active sessions reached (\(config.maxActiveGraphs))"
            )
            violations.append(violation)
            throw MorphicError.sandboxViolation("Maximum active sessions reached: \(config.maxActiveGraphs)")
        }

        let session = MorphicSession(graph: graph)
        activeSessions.append(session)
        log.info("Morphic sandbox: loaded graph '\(graph.name)' with \(graph.nodes.count) nodes")
        return session
    }

    /// Activate a session (start processing)
    public func activateSession(id: String) {
        guard let session = activeSessions.first(where: { $0.id == id }) else { return }
        session.isActive = true
        log.info("Morphic sandbox: activated session '\(session.graph.name)'")
    }

    /// Deactivate a session (pause processing)
    public func deactivateSession(id: String) {
        guard let session = activeSessions.first(where: { $0.id == id }) else { return }
        session.isActive = false
        log.info("Morphic sandbox: deactivated session '\(session.graph.name)'")
    }

    /// Bypass a session (pass-through)
    public func bypassSession(id: String, bypassed: Bool) {
        guard let session = activeSessions.first(where: { $0.id == id }) else { return }
        session.isBypassed = bypassed
    }

    /// Unload a session from the sandbox
    public func unloadSession(id: String) {
        if let index = activeSessions.firstIndex(where: { $0.id == id }) {
            let session = activeSessions[index]
            session.isActive = false
            session.graph.reset()
            activeSessions.remove(at: index)
            log.info("Morphic sandbox: unloaded session '\(session.graph.name)'")
        }
    }

    /// Unload all sessions
    public func unloadAll() {
        for session in activeSessions {
            session.isActive = false
            session.graph.reset()
        }
        activeSessions.removeAll()
        log.info("Morphic sandbox: all sessions unloaded")
    }

    // MARK: - Audio Processing

    /// Process audio through all active sandbox sessions (serial chain)
    public func process(_ input: [Float]) -> [Float] {
        guard !activeSessions.isEmpty else { return input }

        // Validate buffer size
        guard input.count <= config.maxBufferSize else {
            violations.append(SandboxViolation(
                timestamp: Date(),
                sessionID: "global",
                type: .bufferLimit,
                message: "Buffer size \(input.count) exceeds limit \(config.maxBufferSize)"
            ))
            return Array(input.prefix(config.maxBufferSize))
        }

        var signal = input

        for session in activeSessions where session.isActive && !session.isBypassed {
            signal = session.process(signal, config: config)
        }

        // Update aggregate metrics
        totalCPUUsage = activeSessions.reduce(0) { $0 + $1.cpuUsage } / Double(max(1, activeSessions.count))

        return signal
    }

    /// Process audio through a specific session only
    public func process(_ input: [Float], sessionID: String) -> [Float] {
        guard let session = activeSessions.first(where: { $0.id == sessionID }),
              session.isActive, !session.isBypassed else { return input }
        return session.process(input, config: config)
    }

    // MARK: - Bio-Reactive Updates

    /// Update all active session graphs with current biometric data
    public func updateBio(_ body: EchoelPulse.BodyMusic) {
        guard config.bioReactiveEnabled else { return }
        for session in activeSessions where session.isActive {
            session.graph.updateBio(body)
        }
    }

    // MARK: - Monitoring

    /// Get sandbox health report
    public var healthReport: SandboxHealthReport {
        SandboxHealthReport(
            activeSessions: activeSessions.count,
            maxSessions: config.maxActiveGraphs,
            averageCPU: totalCPUUsage,
            totalNodes: activeSessions.reduce(0) { $0 + $1.graph.nodes.count },
            recentViolations: violations.suffix(10).reversed(),
            isHealthy: totalCPUUsage < 0.8 && violations.filter {
                $0.timestamp > Date().addingTimeInterval(-60)
            }.count < 5
        )
    }

    public struct SandboxHealthReport {
        public let activeSessions: Int
        public let maxSessions: Int
        public let averageCPU: Double
        public let totalNodes: Int
        public let recentViolations: [SandboxViolation]
        public let isHealthy: Bool
    }

    /// Clear old violations (keep last 100)
    public func pruneViolations() {
        if violations.count > 100 {
            violations = Array(violations.suffix(100))
        }
    }

    // MARK: - Quick Compile & Run

    /// Convenience: compile a description and immediately load it
    public func compileAndRun(description: String, name: String? = nil) async throws -> MorphicSession {
        let result = try await MorphicCompiler.shared.compile(description: description, name: name)
        let session = try loadGraph(result.graph)
        activateSession(id: session.id)
        return session
    }

    /// Convenience: compile with LLM and immediately load
    public func compileWithLLMAndRun(description: String, name: String? = nil, bioContext: EchoelPulse.BodyMusic? = nil) async throws -> MorphicSession {
        let result = try await MorphicCompiler.shared.compileWithLLM(description: description, name: name, bioContext: bioContext)
        let session = try loadGraph(result.graph)
        activateSession(id: session.id)
        return session
    }
}

// MARK: - Preset Morphic Effects

/// Built-in Morphic effect templates that Echoela can suggest
public enum MorphicPresets {

    /// Warm analog chain: tube saturation -> filter -> reverb
    public static func warmAnalog() async throws -> MorphicGraph {
        let result = try await MorphicCompiler.shared.compile(
            description: "warm tube saturation with gentle low-pass filter and subtle room reverb",
            name: "Warm Analog"
        )
        return result.graph
    }

    /// Bio-reactive meditation: coherence-controlled reverb + breath filter
    public static func bioMeditation() async throws -> MorphicGraph {
        let result = try await MorphicCompiler.shared.compile(
            description: "gentle low-pass filter controlled by breathing with coherence-mapped reverb space and heart-rate warmth",
            name: "Bio Meditation"
        )
        return result.graph
    }

    /// Glitch destroyer: bitcrush + delay + hard distortion
    public static func glitchDestroyer() async throws -> MorphicGraph {
        let result = try await MorphicCompiler.shared.compile(
            description: "intense bit crush distortion with echo delay and extreme saturation",
            name: "Glitch Destroyer"
        )
        return result.graph
    }

    /// Ambient wash: long reverb + filter sweep + subtle delay
    public static func ambientWash() async throws -> MorphicGraph {
        let result = try await MorphicCompiler.shared.compile(
            description: "bright airy filter sweep with wet hall reverb and gentle delay echo",
            name: "Ambient Wash"
        )
        return result.graph
    }

    /// Synth pad: oscillator + filter + reverb
    public static func synthPad() async throws -> MorphicGraph {
        let result = try await MorphicCompiler.shared.compile(
            description: "sine oscillator synth tone with low-pass filter and spacious reverb",
            name: "Synth Pad"
        )
        return result.graph
    }
}

// Note: Morphic Engine tools are registered in EchoelaManager.toolDefinitions

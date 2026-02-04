// SamplePlugins.swift
// Echoelmusic - λ Lambda Mode Ralph Wiggum Loop Quantum Light Science
//
// Sample developer plugins demonstrating the Echoelmusic SDK
// Reference implementations for plugin developers
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import Combine
import simd

// MARK: - Sacred Geometry Visualizer Plugin

/// A visualization plugin that renders sacred geometry patterns based on bio coherence
/// Demonstrates: visualization, bioProcessing, quantumVisualization capabilities
public final class SacredGeometryVisualizerPlugin: EchoelmusicPlugin {

    // MARK: - Plugin Info

    public var identifier: String { "com.echoelmusic.sacred-geometry" }
    public var name: String { "Sacred Geometry Visualizer" }
    public var version: String { "1.0.0" }
    public var author: String { "Echoelmusic Community" }
    public var pluginDescription: String { "Renders sacred geometry patterns (Flower of Life, Metatron's Cube, Sri Yantra) that respond to bio coherence and quantum state" }
    public var requiredSDKVersion: String { "2.0.0" }
    public var capabilities: Set<PluginCapability> { [.visualization, .bioProcessing, .quantumVisualization] }

    // MARK: - Configuration

    public enum GeometryPattern: String, CaseIterable, Sendable {
        case flowerOfLife = "Flower of Life"
        case metatronsCube = "Metatron's Cube"
        case sriYantra = "Sri Yantra"
        case seedOfLife = "Seed of Life"
        case treeOfLife = "Tree of Life"
        case vesicaPiscis = "Vesica Piscis"
        case torusField = "Torus Field"
        case fibonacciSpiral = "Fibonacci Spiral"
    }

    public struct Configuration: Sendable {
        public var pattern: GeometryPattern = .flowerOfLife
        public var colorScheme: ColorScheme = .spectrum
        public var rotationSpeed: Float = 0.5
        public var breathSync: Bool = true
        public var quantumOverlay: Bool = true
        public var lineWidth: Float = 2.0
        public var glowIntensity: Float = 0.7

        public enum ColorScheme: String, CaseIterable, Sendable {
            case spectrum = "Spectrum Colors"
            case golden = "Golden"
            case cosmic = "Cosmic"
            case earthTones = "Earth Tones"
            case bioReactive = "Bio-Reactive"
        }
    }

    // MARK: - State

    public var configuration = Configuration()
    private var coherence: Float = 0.5
    private var breathPhase: Float = 0.0
    private var quantumCoherence: Float = 0.5
    private var totalTime: TimeInterval = 0
    private var vertices: [SIMD2<Float>] = []

    // MARK: - Constants

    private let phi: Float = 1.618033988749895  // Golden ratio
    private let sqrt3: Float = 1.7320508075688772

    // MARK: - Initialization

    public init() {
        generateVertices()
    }

    // MARK: - Plugin Lifecycle

    public func onLoad(context: PluginContext) async throws {
        await MainActor.run {
            DeveloperConsole.shared.info("Sacred Geometry plugin loaded - Pattern: \(configuration.pattern.rawValue)", source: identifier)
        }
        generateVertices()
    }

    public func onUnload() async {
        await MainActor.run {
            DeveloperConsole.shared.info("Sacred Geometry plugin unloaded", source: identifier)
        }
    }

    public func onFrame(deltaTime: TimeInterval) {
        totalTime += deltaTime

        // Update breath phase animation
        if configuration.breathSync {
            breathPhase = Float(sin(totalTime * 0.5) * 0.5 + 0.5)
        }
    }

    public func onBioDataUpdate(_ bioData: BioData) {
        coherence = bioData.coherence
        if let breathing = bioData.breathingRate {
            // Sync rotation to breathing
            breathPhase = (breathing / 20.0).clamped(to: 0...1)
        }
    }

    public func onQuantumStateChange(_ state: QuantumPluginState) {
        quantumCoherence = state.coherenceLevel
    }

    public func renderVisual(context: RenderContext) -> VisualOutput? {
        // Calculate dynamic parameters
        let rotation = Float(totalTime) * configuration.rotationSpeed * (1.0 + coherence * 0.5)
        let scale = 0.8 + breathPhase * 0.2
        let glow = configuration.glowIntensity * (0.5 + quantumCoherence * 0.5)

        // Color based on coherence
        let hue = coherence * 0.3  // Green to cyan range for high coherence
        let saturation: Float = 0.7 + quantumCoherence * 0.3

        return VisualOutput(
            pixelData: nil,
            textureId: nil,
            shaderUniforms: [
                "pattern": Float(GeometryPattern.allCases.firstIndex(of: configuration.pattern) ?? 0),
                "rotation": rotation,
                "scale": scale,
                "coherence": coherence,
                "quantumCoherence": quantumCoherence,
                "breathPhase": breathPhase,
                "lineWidth": configuration.lineWidth,
                "glow": glow,
                "hue": hue,
                "saturation": saturation,
                "time": Float(context.totalTime),
                "phi": phi
            ],
            blendMode: .add
        )
    }

    // MARK: - Geometry Generation

    private func generateVertices() {
        vertices.removeAll()

        switch configuration.pattern {
        case .flowerOfLife:
            generateFlowerOfLife()
        case .metatronsCube:
            generateMetatronsCube()
        case .sriYantra:
            generateSriYantra()
        case .seedOfLife:
            generateSeedOfLife()
        case .treeOfLife:
            generateTreeOfLife()
        case .vesicaPiscis:
            generateVesicaPiscis()
        case .torusField:
            generateTorusField()
        case .fibonacciSpiral:
            generateFibonacciSpiral()
        }
    }

    private func generateFlowerOfLife() {
        // Central circle + 6 surrounding circles
        let radius: Float = 0.15
        vertices.append(SIMD2<Float>(0, 0))

        for i in 0..<6 {
            let angle = Float(i) * Float.pi / 3
            vertices.append(SIMD2<Float>(cos(angle) * radius, sin(angle) * radius))
        }

        // Second ring
        for i in 0..<12 {
            let angle = Float(i) * Float.pi / 6
            vertices.append(SIMD2<Float>(cos(angle) * radius * 2, sin(angle) * radius * 2))
        }
    }

    private func generateMetatronsCube() {
        // 13 circles arranged in a specific pattern
        let radius: Float = 0.08
        vertices.append(SIMD2<Float>(0, 0))

        for ring in 1...2 {
            let ringRadius = Float(ring) * radius * 2
            let count = ring * 6
            for i in 0..<count {
                let angle = Float(i) * 2 * Float.pi / Float(count)
                vertices.append(SIMD2<Float>(cos(angle) * ringRadius, sin(angle) * ringRadius))
            }
        }
    }

    private func generateSriYantra() {
        // 9 interlocking triangles
        for i in 0..<9 {
            let scale = 1.0 - Float(i) * 0.1
            let rotation = Float(i % 2) * Float.pi
            for j in 0..<3 {
                let angle = Float(j) * 2 * Float.pi / 3 + rotation
                vertices.append(SIMD2<Float>(cos(angle) * scale * 0.3, sin(angle) * scale * 0.3))
            }
        }
    }

    private func generateSeedOfLife() {
        // 7 circles: 1 center + 6 surrounding
        let radius: Float = 0.12
        vertices.append(SIMD2<Float>(0, 0))
        for i in 0..<6 {
            let angle = Float(i) * Float.pi / 3
            vertices.append(SIMD2<Float>(cos(angle) * radius, sin(angle) * radius))
        }
    }

    private func generateTreeOfLife() {
        // 10 sephiroth positions
        let positions: [SIMD2<Float>] = [
            SIMD2<Float>(0, 0.4),     // Kether
            SIMD2<Float>(-0.2, 0.25), // Binah
            SIMD2<Float>(0.2, 0.25),  // Chokmah
            SIMD2<Float>(0, 0.1),     // Da'at
            SIMD2<Float>(-0.2, 0),    // Geburah
            SIMD2<Float>(0.2, 0),     // Chesed
            SIMD2<Float>(0, -0.1),    // Tiphareth
            SIMD2<Float>(-0.2, -0.25), // Hod
            SIMD2<Float>(0.2, -0.25),  // Netzach
            SIMD2<Float>(0, -0.4)     // Malkuth
        ]
        vertices = positions
    }

    private func generateVesicaPiscis() {
        // Two overlapping circles
        vertices.append(SIMD2<Float>(-0.1, 0))
        vertices.append(SIMD2<Float>(0.1, 0))
    }

    private func generateTorusField() {
        // Torus cross-section points
        let majorRadius: Float = 0.25
        let minorRadius: Float = 0.1
        for i in 0..<32 {
            let angle = Float(i) * 2 * Float.pi / 32
            let x = (majorRadius + minorRadius * cos(angle * 8)) * cos(angle)
            let y = (majorRadius + minorRadius * cos(angle * 8)) * sin(angle)
            vertices.append(SIMD2<Float>(x, y))
        }
    }

    private func generateFibonacciSpiral() {
        // Golden spiral points
        var a: Float = 0
        var b: Float = 1
        for i in 0..<21 {
            let angle = Float(i) * phi * 2 * Float.pi / 8
            let radius = b * 0.01
            vertices.append(SIMD2<Float>(cos(angle) * radius, sin(angle) * radius))
            let temp = a + b
            a = b
            b = temp
        }
    }

    // MARK: - Public API

    public func setPattern(_ pattern: GeometryPattern) {
        configuration.pattern = pattern
        generateVertices()
        Task { @MainActor in
            DeveloperConsole.shared.debug("Pattern changed to: \(pattern.rawValue)", source: self.identifier)
        }
    }

    public func getVertices() -> [SIMD2<Float>] {
        vertices
    }
}

// MARK: - Bio Audio Generator Plugin

/// An audio generator that creates harmonic sounds from biometric data
/// Demonstrates: audioGenerator, bioProcessing, hrvAnalysis capabilities
public final class BioAudioGeneratorPlugin: EchoelmusicPlugin {

    // MARK: - Plugin Info

    public var identifier: String { "com.echoelmusic.bio-audio-generator" }
    public var name: String { "Bio Audio Generator" }
    public var version: String { "1.0.0" }
    public var author: String { "Echoelmusic Community" }
    public var pluginDescription: String { "Generates harmonic audio from biometric signals - heart rate drives rhythm, HRV modulates harmony, breathing shapes dynamics" }
    public var requiredSDKVersion: String { "2.0.0" }
    public var capabilities: Set<PluginCapability> { [.audioGenerator, .bioProcessing, .hrvAnalysis] }

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public var baseFrequency: Float = 432.0  // Hz (A4 tuned to 432)
        public var harmonicSeries: HarmonicSeries = .natural
        public var rhythmSource: RhythmSource = .heartRate
        public var dynamicsSource: DynamicsSource = .breathing
        public var scale: Scale = .pentatonic
        public var octaveRange: ClosedRange<Int> = 2...5
        public var reverbMix: Float = 0.3
        public var outputGain: Float = 0.5

        public enum HarmonicSeries: String, CaseIterable, Sendable {
            case natural = "Natural Harmonics"
            case fibonacci = "Fibonacci Harmonics"
            case golden = "Golden Ratio"
            case pythagorean = "Pythagorean"
            case justIntonation = "Just Intonation"
        }

        public enum RhythmSource: String, CaseIterable, Sendable {
            case heartRate = "Heart Rate"
            case hrv = "HRV"
            case breathing = "Breathing"
            case coherence = "Coherence"
        }

        public enum DynamicsSource: String, CaseIterable, Sendable {
            case breathing = "Breathing"
            case coherence = "Coherence"
            case hrv = "HRV"
            case skinConductance = "Skin Conductance"
        }

        public enum Scale: String, CaseIterable, Sendable {
            case pentatonic = "Pentatonic"
            case major = "Major"
            case minor = "Minor"
            case lydian = "Lydian"
            case dorian = "Dorian"
            case wholeTone = "Whole Tone"
            case chromatic = "Chromatic"
        }
    }

    // MARK: - State

    public var configuration = Configuration()
    private var heartRate: Float = 70.0
    private var hrv: Float = 50.0
    private var coherence: Float = 0.5
    private var breathingRate: Float = 12.0
    private var breathPhase: Float = 0.0
    private var skinConductance: Float = 0.5

    private var oscillatorPhases: [Float] = Array(repeating: 0, count: 8)
    private var currentNotes: [Int] = []
    private var noteTimer: Float = 0

    // MARK: - Constants

    private let phi: Float = 1.618033988749895
    private let scaleIntervals: [Configuration.Scale: [Int]] = [
        .pentatonic: [0, 2, 4, 7, 9],
        .major: [0, 2, 4, 5, 7, 9, 11],
        .minor: [0, 2, 3, 5, 7, 8, 10],
        .lydian: [0, 2, 4, 6, 7, 9, 11],
        .dorian: [0, 2, 3, 5, 7, 9, 10],
        .wholeTone: [0, 2, 4, 6, 8, 10],
        .chromatic: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    ]

    // MARK: - Initialization

    public init() {}

    // MARK: - Plugin Lifecycle

    public func onLoad(context: PluginContext) async throws {
        await MainActor.run {
            DeveloperConsole.shared.info("Bio Audio Generator loaded - Base freq: \(configuration.baseFrequency)Hz", source: identifier)
        }
    }

    public func onUnload() async {
        await MainActor.run {
            DeveloperConsole.shared.info("Bio Audio Generator unloaded", source: identifier)
        }
    }

    public func onFrame(deltaTime: TimeInterval) {
        // Update note timing based on rhythm source
        let rhythmBPM: Float
        switch configuration.rhythmSource {
        case .heartRate:
            rhythmBPM = heartRate
        case .hrv:
            rhythmBPM = 60.0 + hrv * 0.5
        case .breathing:
            rhythmBPM = breathingRate * 5
        case .coherence:
            rhythmBPM = 60.0 + coherence * 60.0
        }

        let beatInterval = 60.0 / rhythmBPM
        noteTimer += Float(deltaTime)

        if noteTimer >= beatInterval {
            noteTimer = 0
            generateNextNote()
        }
    }

    public func onBioDataUpdate(_ bioData: BioData) {
        if let hr = bioData.heartRate { heartRate = hr }
        if let hrvVal = bioData.hrvSDNN { hrv = hrvVal }
        coherence = bioData.coherence
        if let br = bioData.breathingRate { breathingRate = br }
        if let gsr = bioData.skinConductance { skinConductance = gsr }

        // Estimate breath phase from breathing rate
        breathPhase = fmod(breathPhase + breathingRate / 60.0 * 0.016, 1.0)
    }

    public func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
        let sampleRateF = Float(sampleRate)
        let samplesPerChannel = buffer.count / channels

        // Get dynamics multiplier
        let dynamics = getDynamicsMultiplier()

        for sample in 0..<samplesPerChannel {
            var outputSample: Float = 0

            // Generate each harmonic
            for (i, note) in currentNotes.enumerated() {
                guard i < oscillatorPhases.count else { break }

                let frequency = noteToFrequency(note)
                let harmonicGain = getHarmonicGain(index: i)

                // Update phase
                oscillatorPhases[i] += frequency / sampleRateF
                if oscillatorPhases[i] >= 1.0 { oscillatorPhases[i] -= 1.0 }

                // Generate sample with smooth waveform
                let phase = oscillatorPhases[i] * 2 * Float.pi
                let wave = sin(phase) * 0.6 + sin(phase * 2) * 0.25 + sin(phase * 3) * 0.15

                outputSample += wave * harmonicGain
            }

            // Apply dynamics and gain
            outputSample *= dynamics * configuration.outputGain

            // Soft clip
            outputSample = tanh(outputSample)

            // Write to all channels
            for channel in 0..<channels {
                buffer[sample * channels + channel] += outputSample
            }
        }
    }

    // MARK: - Helpers

    private func generateNextNote() {
        let scale = scaleIntervals[configuration.scale] ?? [0]
        let octave = Int.random(in: configuration.octaveRange)
        let noteInScale = scale.randomElement() ?? 0
        let midiNote = 60 + (octave - 4) * 12 + noteInScale

        // Add note with coherence-based probability
        if Float.random(in: 0...1) < coherence {
            currentNotes.append(midiNote)

            // Limit polyphony
            if currentNotes.count > 4 {
                currentNotes.removeFirst()
            }
        }
    }

    private func noteToFrequency(_ midiNote: Int) -> Float {
        configuration.baseFrequency * pow(2.0, Float(midiNote - 69) / 12.0)
    }

    private func getHarmonicGain(index: Int) -> Float {
        switch configuration.harmonicSeries {
        case .natural:
            return 1.0 / Float(index + 1)
        case .fibonacci:
            let fib = [1, 1, 2, 3, 5, 8, 13, 21]
            return 1.0 / Float(fib[min(index, fib.count - 1)])
        case .golden:
            return pow(1.0 / phi, Float(index))
        case .pythagorean:
            let ratios: [Float] = [1, 0.5, 0.33, 0.25, 0.2, 0.166, 0.142, 0.125]
            return ratios[min(index, ratios.count - 1)]
        case .justIntonation:
            let ratios: [Float] = [1, 0.8, 0.666, 0.6, 0.5, 0.4, 0.333, 0.285]
            return ratios[min(index, ratios.count - 1)]
        }
    }

    private func getDynamicsMultiplier() -> Float {
        switch configuration.dynamicsSource {
        case .breathing:
            return 0.3 + sin(breathPhase * Float.pi) * 0.7
        case .coherence:
            return 0.5 + coherence * 0.5
        case .hrv:
            return 0.5 + (hrv / 100.0).clamped(to: 0...0.5)
        case .skinConductance:
            return 0.3 + skinConductance * 0.7
        }
    }
}

// MARK: - Quantum MIDI Bridge Plugin

/// A MIDI controller that maps quantum state to MIDI CC messages
/// Demonstrates: midiOutput, quantumProcessing, oscControl capabilities
public final class QuantumMIDIBridgePlugin: EchoelmusicPlugin {

    // MARK: - Plugin Info

    public var identifier: String { "com.echoelmusic.quantum-midi-bridge" }
    public var name: String { "Quantum MIDI Bridge" }
    public var version: String { "1.0.0" }
    public var author: String { "Echoelmusic Community" }
    public var pluginDescription: String { "Maps quantum coherence, entanglement, and superposition states to MIDI CC messages for external synths and DAWs" }
    public var requiredSDKVersion: String { "2.0.0" }
    public var capabilities: Set<PluginCapability> { [.midiOutput, .quantumProcessing, .oscControl] }

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public var midiChannel: UInt8 = 1
        public var coherenceCC: UInt8 = 1    // Mod wheel
        public var entanglementCC: UInt8 = 74  // Cutoff
        public var superpositionCC: UInt8 = 71  // Resonance
        public var bioCoherenceCC: UInt8 = 11   // Expression
        public var quantumNoiseCC: UInt8 = 73   // Attack
        public var sendOSC: Bool = true
        public var oscAddress: String = "/echoelmusic/quantum"
        public var smoothing: Float = 0.1
    }

    // MARK: - MIDI Message Types

    public struct MIDIMessage: Sendable {
        public var status: UInt8
        public var data1: UInt8
        public var data2: UInt8
        public var timestamp: TimeInterval

        public static func controlChange(channel: UInt8, cc: UInt8, value: UInt8) -> MIDIMessage {
            MIDIMessage(
                status: 0xB0 | (channel - 1),
                data1: cc,
                data2: value,
                timestamp: Date().timeIntervalSince1970
            )
        }

        public static func noteOn(channel: UInt8, note: UInt8, velocity: UInt8) -> MIDIMessage {
            MIDIMessage(
                status: 0x90 | (channel - 1),
                data1: note,
                data2: velocity,
                timestamp: Date().timeIntervalSince1970
            )
        }

        public static func noteOff(channel: UInt8, note: UInt8) -> MIDIMessage {
            MIDIMessage(
                status: 0x80 | (channel - 1),
                data1: note,
                data2: 0,
                timestamp: Date().timeIntervalSince1970
            )
        }
    }

    // MARK: - State

    public var configuration = Configuration()
    private var quantumCoherence: Float = 0.5
    private var entanglementStrength: Float = 0.0
    private var superpositionCount: Int = 0
    private var bioCoherence: Float = 0.5

    private var smoothedCoherence: Float = 0.5
    private var smoothedEntanglement: Float = 0.0

    private var outputMessages: [MIDIMessage] = []
    private var lastSendTime: TimeInterval = 0

    // MARK: - Initialization

    public init() {}

    // MARK: - Plugin Lifecycle

    public func onLoad(context: PluginContext) async throws {
        await MainActor.run {
            DeveloperConsole.shared.info("Quantum MIDI Bridge loaded - Channel: \(configuration.midiChannel)", source: identifier)
        }
    }

    public func onUnload() async {
        // Send all notes off
        let allNotesOff = MIDIMessage.controlChange(channel: configuration.midiChannel, cc: 123, value: 0)
        outputMessages.append(allNotesOff)
        await MainActor.run {
            DeveloperConsole.shared.info("Quantum MIDI Bridge unloaded", source: identifier)
        }
    }

    public func onFrame(deltaTime: TimeInterval) {
        // Smooth values
        let alpha = configuration.smoothing
        smoothedCoherence = smoothedCoherence * (1 - alpha) + quantumCoherence * alpha
        smoothedEntanglement = smoothedEntanglement * (1 - alpha) + entanglementStrength * alpha

        // Rate limit MIDI output (max 60 messages/sec)
        let now = Date().timeIntervalSince1970
        if now - lastSendTime >= 1.0/60.0 {
            lastSendTime = now
            generateMIDIMessages()
        }
    }

    public func onBioDataUpdate(_ bioData: BioData) {
        bioCoherence = bioData.coherence
    }

    public func onQuantumStateChange(_ state: QuantumPluginState) {
        quantumCoherence = state.coherenceLevel
        entanglementStrength = state.entanglementStrength
        superpositionCount = state.superpositionCount
    }

    // MARK: - MIDI Generation

    private func generateMIDIMessages() {
        outputMessages.removeAll()

        // Map quantum state to MIDI CC values (0-127)
        let coherenceValue = UInt8(min(127, max(0, Int(smoothedCoherence * 127))))
        let entanglementValue = UInt8(min(127, max(0, Int(smoothedEntanglement * 127))))
        let superpositionValue = UInt8(min(127, max(0, superpositionCount * 10)))
        let bioValue = UInt8(min(127, max(0, Int(bioCoherence * 127))))

        // Add quantum noise based on superposition
        let noiseAmount = Float.random(in: 0...1) * Float(superpositionCount) / 10.0
        let noiseValue = UInt8(min(127, max(0, Int(noiseAmount * 127))))

        // Generate CC messages
        outputMessages.append(.controlChange(channel: configuration.midiChannel, cc: configuration.coherenceCC, value: coherenceValue))
        outputMessages.append(.controlChange(channel: configuration.midiChannel, cc: configuration.entanglementCC, value: entanglementValue))
        outputMessages.append(.controlChange(channel: configuration.midiChannel, cc: configuration.superpositionCC, value: superpositionValue))
        outputMessages.append(.controlChange(channel: configuration.midiChannel, cc: configuration.bioCoherenceCC, value: bioValue))
        outputMessages.append(.controlChange(channel: configuration.midiChannel, cc: configuration.quantumNoiseCC, value: noiseValue))

        // Log for debugging
        Task { @MainActor in
            DeveloperConsole.shared.debug("MIDI: Coh=\(coherenceValue) Ent=\(entanglementValue) Bio=\(bioValue)", source: self.identifier)
        }
    }

    // MARK: - Public API

    /// Get pending MIDI messages
    public func flushMessages() -> [MIDIMessage] {
        let messages = outputMessages
        outputMessages.removeAll()
        return messages
    }

    /// Send a quantum trigger note
    public func sendQuantumTrigger(velocity: UInt8 = 100) {
        // Send a C4 note for quantum events
        let noteOn = MIDIMessage.noteOn(channel: configuration.midiChannel, note: 60, velocity: velocity)
        outputMessages.append(noteOn)

        // Schedule note off (in real implementation, use proper timing)
        let noteOff = MIDIMessage.noteOff(channel: configuration.midiChannel, note: 60)
        outputMessages.append(noteOff)

        Task { @MainActor in
            DeveloperConsole.shared.info("Quantum trigger sent", source: self.identifier)
        }
    }

    /// Get OSC message bundle for external routing
    public func getOSCBundle() -> [(address: String, arguments: [Any])] {
        guard configuration.sendOSC else { return [] }

        return [
            ("\(configuration.oscAddress)/coherence", [smoothedCoherence]),
            ("\(configuration.oscAddress)/entanglement", [smoothedEntanglement]),
            ("\(configuration.oscAddress)/superposition", [superpositionCount]),
            ("\(configuration.oscAddress)/bio", [bioCoherence])
        ]
    }
}

// MARK: - DMX Light Show Plugin

/// A DMX lighting controller for live performances
/// Demonstrates: dmxOutput, bioProcessing, quantumVisualization capabilities
public final class DMXLightShowPlugin: EchoelmusicPlugin {

    // MARK: - Plugin Info

    public var identifier: String { "com.echoelmusic.dmx-light-show" }
    public var name: String { "DMX Light Show" }
    public var version: String { "1.0.0" }
    public var author: String { "Echoelmusic Community" }
    public var pluginDescription: String { "Controls DMX lighting fixtures based on bio coherence, quantum state, and audio analysis for immersive live shows" }
    public var requiredSDKVersion: String { "2.0.0" }
    public var capabilities: Set<PluginCapability> { [.dmxOutput, .bioProcessing, .quantumVisualization] }

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public var universe: UInt8 = 1
        public var baseAddress: UInt16 = 1
        public var fixtureCount: Int = 8
        public var colorMode: ColorMode = .bioReactive
        public var intensitySource: IntensitySource = .coherence
        public var strobeOnQuantumEvent: Bool = true
        public var artNetIP: String = "192.168.1.100"
        public var artNetPort: UInt16 = 6454

        public enum ColorMode: String, CaseIterable, Sendable {
            case bioReactive = "Bio-Reactive"
            case quantum = "Quantum"
            case spectrum = "Spectrum"
            case rainbow = "Rainbow"
            case breathing = "Breathing"
            case heartbeat = "Heartbeat"
        }

        public enum IntensitySource: String, CaseIterable, Sendable {
            case coherence = "Coherence"
            case heartRate = "Heart Rate"
            case breathing = "Breathing"
            case audio = "Audio"
        }
    }

    // MARK: - DMX Data

    public struct DMXFixture: Sendable {
        public var red: UInt8 = 0
        public var green: UInt8 = 0
        public var blue: UInt8 = 0
        public var white: UInt8 = 0
        public var intensity: UInt8 = 255
        public var strobe: UInt8 = 0
        public var pan: UInt8 = 127
        public var tilt: UInt8 = 127
    }

    // MARK: - State

    public var configuration = Configuration()
    private var fixtures: [DMXFixture] = []
    private var coherence: Float = 0.5
    private var heartRate: Float = 70.0
    private var breathPhase: Float = 0.0
    private var quantumCoherence: Float = 0.5
    private var audioLevel: Float = 0.0
    private var totalTime: TimeInterval = 0

    // MARK: - Initialization

    public init() {
        fixtures = Array(repeating: DMXFixture(), count: 16)
    }

    // MARK: - Plugin Lifecycle

    public func onLoad(context: PluginContext) async throws {
        fixtures = Array(repeating: DMXFixture(), count: configuration.fixtureCount)
        await MainActor.run {
            DeveloperConsole.shared.info("DMX Light Show loaded - \(configuration.fixtureCount) fixtures", source: identifier)
        }
    }

    public func onUnload() async {
        // Blackout all fixtures
        for i in 0..<fixtures.count {
            fixtures[i] = DMXFixture()
        }
        await MainActor.run {
            DeveloperConsole.shared.info("DMX Light Show unloaded - blackout", source: identifier)
        }
    }

    public func onFrame(deltaTime: TimeInterval) {
        totalTime += deltaTime

        // Update fixture colors and intensity
        updateFixtures()
    }

    public func onBioDataUpdate(_ bioData: BioData) {
        coherence = bioData.coherence
        if let hr = bioData.heartRate { heartRate = hr }
        if let br = bioData.breathingRate {
            breathPhase = fmod(breathPhase + br / 60.0 * 0.016, 1.0)
        }
    }

    public func onQuantumStateChange(_ state: QuantumPluginState) {
        quantumCoherence = state.coherenceLevel

        // Strobe on quantum entanglement events
        if configuration.strobeOnQuantumEvent && state.entanglementStrength > 0.8 {
            triggerStrobe(duration: 0.1)
        }
    }

    // MARK: - Fixture Updates

    private func updateFixtures() {
        let intensity = getIntensity()
        let colors = getColors()

        for i in 0..<fixtures.count {
            let colorIndex = i % colors.count
            let (r, g, b) = colors[colorIndex]

            fixtures[i].red = UInt8(Float(r) * intensity)
            fixtures[i].green = UInt8(Float(g) * intensity)
            fixtures[i].blue = UInt8(Float(b) * intensity)
            fixtures[i].intensity = UInt8(intensity * 255)

            // Animate pan/tilt based on coherence
            let panOffset = sin(Float(totalTime) + Float(i) * 0.5) * coherence * 50
            let tiltOffset = cos(Float(totalTime) * 0.7 + Float(i) * 0.3) * coherence * 30
            fixtures[i].pan = UInt8(127 + Int(panOffset))
            fixtures[i].tilt = UInt8(127 + Int(tiltOffset))
        }
    }

    private func getIntensity() -> Float {
        switch configuration.intensitySource {
        case .coherence:
            return 0.3 + coherence * 0.7
        case .heartRate:
            let normalized = (heartRate - 60) / 60  // 60-120 BPM range
            return 0.3 + normalized.clamped(to: 0...0.7)
        case .breathing:
            return 0.3 + sin(breathPhase * Float.pi) * 0.7
        case .audio:
            return 0.1 + audioLevel * 0.9
        }
    }

    private func getColors() -> [(UInt8, UInt8, UInt8)] {
        switch configuration.colorMode {
        case .bioReactive:
            // Green for high coherence, red for low
            let r = UInt8((1 - coherence) * 255)
            let g = UInt8(coherence * 255)
            let b: UInt8 = 50
            return [(r, g, b)]

        case .quantum:
            // Cyan/purple quantum colors
            let shift = Float(sin(totalTime * 2) * 0.5 + 0.5)
            let r = UInt8(shift * 200)
            let g = UInt8((1 - shift) * 100)
            let b: UInt8 = 255
            return [(r, g, b)]

        case .spectrum:
            // 7-band spectrum (ROYGBIV)
            return [
                (255, 0, 0),     // Red
                (255, 127, 0),   // Orange
                (255, 255, 0),   // Yellow
                (0, 255, 0),     // Green
                (0, 127, 255),   // Cyan
                (0, 0, 255),     // Blue
                (127, 0, 255)    // Violet
            ]

        case .rainbow:
            // Full spectrum
            var colors: [(UInt8, UInt8, UInt8)] = []
            for i in 0..<configuration.fixtureCount {
                let hue = Float(i) / Float(configuration.fixtureCount)
                let rgb = hsvToRGB(h: hue, s: 1.0, v: 1.0)
                colors.append(rgb)
            }
            return colors

        case .breathing:
            // Soft blue/white cycling
            let phase = sin(breathPhase * Float.pi)
            let r = UInt8(100 + phase * 100)
            let g = UInt8(150 + phase * 100)
            let b: UInt8 = 255
            return [(r, g, b)]

        case .heartbeat:
            // Red pulse with heartbeat
            let beatPhase = Float(fmod(totalTime * Double(heartRate) / 60.0, 1.0))
            let intensity: Float = beatPhase < 0.2 ? 1.0 : 0.3
            let r = UInt8(255 * intensity)
            return [(r, 30, 50)]
        }
    }

    private func hsvToRGB(h: Float, s: Float, v: Float) -> (UInt8, UInt8, UInt8) {
        let c = v * s
        let x = c * (1 - abs(fmod(h * 6, 2) - 1))
        let m = v - c

        var r: Float = 0, g: Float = 0, b: Float = 0
        let sector = Int(h * 6) % 6
        switch sector {
        case 0: r = c; g = x; b = 0
        case 1: r = x; g = c; b = 0
        case 2: r = 0; g = c; b = x
        case 3: r = 0; g = x; b = c
        case 4: r = x; g = 0; b = c
        case 5: r = c; g = 0; b = x
        default: break
        }

        return (
            UInt8((r + m) * 255),
            UInt8((g + m) * 255),
            UInt8((b + m) * 255)
        )
    }

    // MARK: - Public API

    public func triggerStrobe(duration: TimeInterval) {
        for i in 0..<fixtures.count {
            fixtures[i].strobe = 200
        }

        // Reset strobe after duration
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            for i in 0..<self.fixtures.count {
                self.fixtures[i].strobe = 0
            }
        }
    }

    public func getDMXData() -> Data {
        var dmxData = Data()

        for fixture in fixtures {
            dmxData.append(fixture.red)
            dmxData.append(fixture.green)
            dmxData.append(fixture.blue)
            dmxData.append(fixture.white)
            dmxData.append(fixture.intensity)
            dmxData.append(fixture.strobe)
            dmxData.append(fixture.pan)
            dmxData.append(fixture.tilt)
        }

        return dmxData
    }

    public func setAudioLevel(_ level: Float) {
        audioLevel = level.clamped(to: 0...1)
    }
}

// Note: clamped(to:) extension moved to NumericExtensions.swift

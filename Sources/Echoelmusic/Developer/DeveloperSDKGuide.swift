// DeveloperSDKGuide.swift
// Echoelmusic - Phase 10000 ULTIMATE RALPH WIGGUM LOOP MODE
//
// Comprehensive Developer SDK Guide for Plugin Development
// Complete documentation, API reference, examples, and best practices
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import simd

// MARK: - Developer SDK Guide

/// Comprehensive guide for developing Echoelmusic plugins
///
/// This guide provides complete documentation for:
/// - Getting started with the SDK
/// - Plugin development patterns
/// - API reference
/// - Complete runnable examples
/// - Best practices
/// - Publishing workflow
/// - Troubleshooting
public struct DeveloperSDKGuide {

    // MARK: - SDK Information

    public static let version = "2.0.0"
    public static let buildNumber = 10000
    public static let codename = "Ultimate Ralph Wiggum Loop Mode"
    public static let releaseDate = "2026-01-07"

    public static var fullVersion: String {
        "\(version) (Build \(buildNumber)) - \(codename)"
    }

    // MARK: - Documentation Sections

    public struct Documentation {

        // MARK: - Getting Started

        public struct GettingStarted {

            public static let overview = """
            # Echoelmusic Developer SDK - Getting Started

            Welcome to the Echoelmusic Developer SDK! This guide will help you create powerful plugins
            that extend Echoelmusic's bio-reactive audio-visual platform.

            ## What is the Echoelmusic SDK?

            The Echoelmusic SDK enables developers to create plugins that:
            - Process audio in real-time with zero latency
            - Generate stunning visuals synchronized to bio signals
            - Access biometric data (HRV, heart rate, breathing)
            - Control MIDI, DMX, and OSC devices
            - Integrate with quantum emulation systems
            - Collaborate globally with other plugins

            ## SDK Capabilities

            ### Audio Processing
            - Real-time audio effects and generators
            - MIDI input/output and MPE support
            - Multi-channel spatial audio
            - Sample-accurate timing

            ### Visual Generation
            - GPU-accelerated shader effects
            - 2D/3D rendering pipelines
            - Particle systems
            - Sacred geometry patterns

            ### Bio-Reactive Features
            - HRV coherence tracking
            - Heart rate monitoring
            - Breathing pattern detection
            - Skin conductance (GSR)

            ### Quantum Integration
            - Quantum state processing
            - Entanglement simulation
            - Superposition visualization
            - Bio-coherent quantum modes

            ### Control Systems
            - Gesture recognition
            - Voice commands
            - MIDI/OSC/DMX output
            - Hardware integration

            ## System Requirements

            ### Development Environment
            - macOS 12+ or Linux (Ubuntu 20.04+)
            - Xcode 14+ (for Apple platforms)
            - Swift 5.9+
            - Git

            ### Deployment Targets
            - iOS 15+
            - macOS 12+
            - watchOS 8+
            - tvOS 15+
            - visionOS 1+
            - Android 8+ (API 26+)
            - Windows 10+
            - Linux (Ubuntu 20.04+)

            ### Recommended Hardware
            - 8GB RAM minimum (16GB recommended)
            - Multi-core CPU (4+ cores recommended)
            - GPU with Metal/OpenGL/Vulkan support
            - Audio interface for low-latency testing

            ## Installation

            ### 1. Clone the Echoelmusic Repository

            ```bash
            git clone https://github.com/echoelmusic/echoelmusic.git
            cd echoelmusic
            ```

            ### 2. Build the SDK

            ```bash
            # Swift Package Manager
            swift build

            # Run tests to verify installation
            swift test
            ```

            ### 3. Open in Xcode (optional)

            ```bash
            open Package.swift
            ```

            ### 4. Verify SDK Installation

            ```swift
            import Echoelmusic

            print(SDKVersion.current)
            // Output: "2.0.0 (Build 10000) - Ultimate Ralph Wiggum Loop Mode"
            ```

            ## Quick Start - Your First Plugin

            Here's a minimal plugin that visualizes bio coherence:

            ```swift
            import Foundation

            class MyFirstPlugin: EchoelmusicPlugin {
                // Plugin metadata
                var identifier: String { "com.mycompany.first-plugin" }
                var name: String { "My First Plugin" }
                var version: String { "1.0.0" }
                var author: String { "Your Name" }
                var pluginDescription: String { "Visualizes bio coherence" }
                var requiredSDKVersion: String { "2.0.0" }
                var capabilities: Set<PluginCapability> { [.visualization, .bioProcessing] }

                // Plugin state
                private var coherence: Float = 0.5

                // Lifecycle methods
                func onLoad(context: PluginContext) async throws {
                    print("Plugin loaded!")
                }

                func onUnload() async {
                    print("Plugin unloaded!")
                }

                // Bio data updates
                func onBioDataUpdate(_ bioData: BioData) {
                    coherence = bioData.coherence
                }

                // Visual rendering
                func renderVisual(context: RenderContext) -> VisualOutput? {
                    VisualOutput(
                        pixelData: nil,
                        textureId: nil,
                        shaderUniforms: [
                            "coherence": coherence,
                            "time": Float(context.totalTime)
                        ],
                        blendMode: .add
                    )
                }
            }
            ```

            ## Loading Your Plugin

            ```swift
            let pluginManager = PluginManager()
            let myPlugin = MyFirstPlugin()

            try await pluginManager.loadPlugin(myPlugin)
            ```

            ## Next Steps

            1. Read the **Plugin Development** section for detailed patterns
            2. Explore the **API Reference** for all available features
            3. Study the **Code Examples** for complete plugin implementations
            4. Review **Best Practices** for performance optimization
            5. Join the Echoelmusic developer community on Discord

            ## Resources

            - API Documentation: https://docs.echoelmusic.com/api
            - Developer Forum: https://forum.echoelmusic.com
            - Sample Plugins: https://github.com/echoelmusic/sample-plugins
            - Discord Community: https://discord.gg/echoelmusic
            - Video Tutorials: https://youtube.com/echoelmusic-dev

            ## Getting Help

            - GitHub Issues: https://github.com/echoelmusic/echoelmusic/issues
            - Stack Overflow: Tag [echoelmusic-sdk]
            - Email: developers@echoelmusic.com
            """

        } // GettingStarted

        // MARK: - Plugin Development

        public struct PluginDevelopment {

            public static let protocolOverview = """
            # Plugin Protocol - Complete Guide

            ## EchoelmusicPlugin Protocol

            Every plugin must conform to the `EchoelmusicPlugin` protocol.

            ### Required Properties

            ```swift
            protocol EchoelmusicPlugin: AnyObject {
                // REQUIRED: Unique identifier (reverse domain notation)
                var identifier: String { get }

                // REQUIRED: Human-readable plugin name
                var name: String { get }

                // REQUIRED: Semantic version (e.g., "1.0.0")
                var version: String { get }

                // REQUIRED: Plugin author/company
                var author: String { get }

                // REQUIRED: Brief description
                var pluginDescription: String { get }

                // REQUIRED: Minimum SDK version needed
                var requiredSDKVersion: String { get }

                // REQUIRED: Plugin capabilities
                var capabilities: Set<PluginCapability> { get }
            }
            ```

            ### Required Methods

            ```swift
            // Called when plugin is loaded - perform initialization here
            func onLoad(context: PluginContext) async throws

            // Called when plugin is unloaded - cleanup resources here
            func onUnload() async
            ```

            ### Optional Methods (Default Implementations Provided)

            ```swift
            // Called every frame at 60Hz - use for animations and updates
            func onFrame(deltaTime: TimeInterval)

            // Called when biometric data updates
            func onBioDataUpdate(_ bioData: BioData)

            // Called when quantum state changes
            func onQuantumStateChange(_ state: QuantumPluginState)

            // Process audio buffer (for audio plugins)
            func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int)

            // Render visual frame (for visual plugins)
            func renderVisual(context: RenderContext) -> VisualOutput?

            // Handle user interaction
            func handleInteraction(_ interaction: UserInteraction)
            ```

            ## Plugin Capabilities

            Declare what your plugin can do using `PluginCapability`:

            ### Audio Capabilities
            - `.audioInput` - Receives audio input
            - `.audioOutput` - Produces audio output
            - `.audioEffect` - Processes audio (filters, effects)
            - `.audioGenerator` - Generates audio (synths, oscillators)
            - `.midiInput` - Receives MIDI messages
            - `.midiOutput` - Sends MIDI messages

            ### Visual Capabilities
            - `.visualization` - Renders visuals
            - `.shaderEffect` - GPU shader effects
            - `.particleSystem` - Particle effects
            - `.threeD` - 3D rendering

            ### Bio Capabilities
            - `.bioInput` - Receives raw bio data
            - `.bioProcessing` - Processes bio signals
            - `.hrvAnalysis` - HRV analysis
            - `.coherenceTracking` - Coherence calculation

            ### Quantum Capabilities
            - `.quantumProcessing` - Processes quantum states
            - `.quantumVisualization` - Visualizes quantum data
            - `.quantumEntanglement` - Entanglement simulation

            ### Control Capabilities
            - `.gestureInput` - Gesture recognition
            - `.voiceInput` - Voice commands
            - `.midiControl` - MIDI control output
            - `.oscControl` - OSC protocol
            - `.dmxOutput` - DMX lighting control

            ### Integration Capabilities
            - `.cloudSync` - Cloud synchronization
            - `.collaboration` - Multi-user sessions
            - `.streaming` - Live streaming
            - `.recording` - Audio/video recording

            ### AI Capabilities
            - `.aiGeneration` - AI content generation
            - `.machineLearning` - ML models
            - `.neuralNetwork` - Neural network processing

            ## Plugin Lifecycle

            ### 1. Loading

            ```swift
            func onLoad(context: PluginContext) async throws {
                // Initialize resources
                // Load configuration
                // Setup state
                // Validate capabilities

                DeveloperConsole.shared.info("Plugin loaded", source: identifier)
            }
            ```

            ### 2. Running

            ```swift
            // Frame updates (60Hz)
            func onFrame(deltaTime: TimeInterval) {
                // Update animations
                // Process timers
                // Update UI state
            }

            // Bio data updates (varies, typically 1-10Hz)
            func onBioDataUpdate(_ bioData: BioData) {
                // React to heart rate changes
                // Update based on coherence
                // Sync to breathing
            }

            // Audio processing (real-time, sample-accurate)
            func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
                // Process audio samples
                // Apply effects
                // Generate sound
            }
            ```

            ### 3. Unloading

            ```swift
            func onUnload() async {
                // Release resources
                // Stop timers
                // Save state if needed
                // Cleanup

                DeveloperConsole.shared.info("Plugin unloaded", source: identifier)
            }
            ```

            ## Thread Safety

            ### Main Thread Methods
            - `onLoad()`, `onUnload()`, `onFrame()`
            - `onBioDataUpdate()`, `onQuantumStateChange()`
            - `renderVisual()`, `handleInteraction()`

            ### Audio Thread Methods
            - `processAudio()` - NEVER allocate memory or lock here!

            ### Thread-Safe Communication

            ```swift
            // Use atomic operations
            import Atomics
            let atomicValue = ManagedAtomic<Float>(0.5)

            // Main thread
            func onBioDataUpdate(_ bioData: BioData) {
                atomicValue.store(bioData.coherence, ordering: .relaxed)
            }

            // Audio thread
            func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
                let coherence = atomicValue.load(ordering: .relaxed)
                // Use coherence safely
            }
            ```

            ## Error Handling

            ```swift
            func onLoad(context: PluginContext) async throws {
                // Throw descriptive errors
                guard context.deviceCapabilities.hasGPU else {
                    throw PluginError.gpuRequired
                }

                guard let configFile = loadConfig() else {
                    throw PluginError.configNotFound
                }

                try validateConfig(configFile)
            }

            enum PluginError: Error, LocalizedError {
                case gpuRequired
                case configNotFound
                case invalidConfig(String)

                var errorDescription: String? {
                    switch self {
                    case .gpuRequired: return "GPU required for this plugin"
                    case .configNotFound: return "Configuration file not found"
                    case .invalidConfig(let msg): return "Invalid config: \\(msg)"
                    }
                }
            }
            ```
            """

            public static let configuration = """
            # Plugin Configuration

            ## Configuration Structures

            Use `Sendable` structs for plugin configuration:

            ```swift
            public struct Configuration: Sendable {
                // Audio settings
                public var baseFrequency: Float = 432.0
                public var outputGain: Float = 0.5

                // Visual settings
                public var colorScheme: ColorScheme = .bioReactive
                public var rotationSpeed: Float = 1.0

                // Feature flags
                public var enableQuantum: Bool = true
                public var breathSync: Bool = true

                public enum ColorScheme: String, CaseIterable, Sendable {
                    case bioReactive = "Bio-Reactive"
                    case quantum = "Quantum"
                    case rainbow = "Rainbow"
                }
            }
            ```

            ## Saving and Loading

            ```swift
            class MyPlugin: EchoelmusicPlugin {
                var configuration = Configuration()

                func onLoad(context: PluginContext) async throws {
                    // Load from disk
                    if let savedConfig = try? loadConfiguration(from: context.dataDirectory) {
                        configuration = savedConfig
                    }
                }

                func onUnload() async {
                    // Save to disk
                    let context = // ... get context
                    try? saveConfiguration(configuration, to: context.dataDirectory)
                }

                private func loadConfiguration(from directory: URL) throws -> Configuration {
                    let fileURL = directory.appendingPathComponent("config.json")
                    let data = try Data(contentsOf: fileURL)
                    return try JSONDecoder().decode(Configuration.self, from: data)
                }

                private func saveConfiguration(_ config: Configuration, to directory: URL) throws {
                    let fileURL = directory.appendingPathComponent("config.json")
                    let data = try JSONEncoder().encode(config)
                    try data.write(to: fileURL)
                }
            }
            ```

            ## User-Accessible Settings

            ```swift
            // Public API for users to configure plugin
            public func setColorScheme(_ scheme: Configuration.ColorScheme) {
                configuration.colorScheme = scheme
                DeveloperConsole.shared.debug("Color scheme: \\(scheme)", source: identifier)
            }

            public func setFrequency(_ freq: Float) {
                configuration.baseFrequency = freq.clamped(to: 20...20000)
            }
            ```
            """

        } // PluginDevelopment

        // MARK: - API Reference

        public struct APIReference {

            public static let pluginContext = """
            # Plugin Context API

            The `PluginContext` provides information about the host environment.

            ## Structure

            ```swift
            struct PluginContext {
                // SDK and app versions
                let sdkVersion: SDKVersion
                let hostAppVersion: String

                // Platform information
                let platform: Platform  // .iOS, .macOS, .android, etc.

                // Device capabilities
                let deviceCapabilities: DeviceCapabilities

                // Storage directories
                let dataDirectory: URL      // Persistent data storage
                let cacheDirectory: URL     // Temporary cache storage

                // Shared state for inter-plugin communication
                let sharedState: SharedPluginState
            }
            ```

            ## Device Capabilities

            ```swift
            struct DeviceCapabilities {
                var hasGPU: Bool              // GPU available
                var hasNeuralEngine: Bool     // Apple Neural Engine
                var hasBiometrics: Bool       // HealthKit/sensors
                var hasHaptics: Bool          // Haptic feedback
                var hasSpatialAudio: Bool     // Spatial audio support
                var maxTextureSize: Int       // Max GPU texture size
                var cpuCores: Int             // CPU core count
                var memoryMB: Int             // Available RAM
            }
            ```

            ## Usage Example

            ```swift
            func onLoad(context: PluginContext) async throws {
                // Check platform
                if context.platform == .visionOS {
                    enableSpatialMode()
                }

                // Adapt to capabilities
                if context.deviceCapabilities.hasGPU {
                    useGPURendering = true
                } else {
                    useCPURendering = true
                }

                // Use storage
                let configURL = context.dataDirectory.appendingPathComponent("config.json")

                // Check memory
                if context.deviceCapabilities.memoryMB < 2048 {
                    reducedQualityMode = true
                }
            }
            ```
            """

            public static let bioData = """
            # Bio Data API

            Access real-time biometric data through `BioData`.

            ## Structure

            ```swift
            struct BioData: Sendable {
                var heartRate: Float?           // BPM (40-200)
                var hrvSDNN: Float?              // HRV SDNN in ms
                var hrvRMSSD: Float?             // HRV RMSSD in ms
                var coherence: Float             // 0.0-1.0 (always available)
                var breathingRate: Float?        // Breaths per minute (6-30)
                var skinConductance: Float?      // GSR (0.0-1.0)
                var temperature: Float?          // Skin temp in Celsius
                var timestamp: Date              // Sample timestamp
            }
            ```

            ## Using Bio Data

            ```swift
            func onBioDataUpdate(_ bioData: BioData) {
                // Always available
                let coherence = bioData.coherence  // 0.0 (low) to 1.0 (high)

                // Optional fields - check before using
                if let heartRate = bioData.heartRate {
                    // Map heart rate (40-200 BPM) to tempo
                    let tempo = heartRate.clamped(to: 60...180)
                    setTempo(tempo)
                }

                if let breathing = bioData.breathingRate {
                    // Sync animation to breathing (6-30 breaths/min)
                    let breathCycleHz = breathing / 60.0
                    animationSpeed = breathCycleHz
                }

                if let hrv = bioData.hrvSDNN {
                    // Higher HRV = more relaxed
                    let relaxation = (hrv / 100.0).clamped(to: 0...1)
                    setRelaxationLevel(relaxation)
                }
            }
            ```

            ## Coherence Interpretation

            ```swift
            func interpretCoherence(_ coherence: Float) -> String {
                switch coherence {
                case 0.0..<0.3:   return "Low - Stressed/Chaotic"
                case 0.3..<0.6:   return "Medium - Balanced"
                case 0.6..<0.8:   return "High - Coherent"
                case 0.8...1.0:   return "Very High - Flow State"
                default:          return "Unknown"
                }
            }
            ```

            ## Bio Data Mapping Examples

            ```swift
            // Map to audio filter cutoff
            let cutoffHz = 200 + bioData.coherence * 5000  // 200-5200 Hz

            // Map to visual color
            let hue = bioData.coherence * 0.3  // Green (0.3) = high coherence

            // Map to reverb wet/dry
            let reverbWet = 1.0 - bioData.coherence  // More reverb = less coherent

            // Map to particle count
            let particles = Int(100 + bioData.coherence * 900)  // 100-1000 particles
            ```
            """

            public static let sharedState = """
            # Shared State API

            Inter-plugin communication via `SharedPluginState`.

            ## Actor-Based Thread Safety

            ```swift
            actor SharedPluginState {
                // Key-value storage
                var parameters: [String: Double]
                var flags: [String: Bool]

                // Message passing
                var messages: [PluginMessage]

                // Thread-safe accessors
                func setParameter(_ key: String, value: Double)
                func getParameter(_ key: String) -> Double?
                func setFlag(_ key: String, value: Bool)
                func getFlag(_ key: String) -> Bool
                func sendMessage(_ message: PluginMessage)
                func getMessages(for pluginId: String?) -> [PluginMessage]
            }
            ```

            ## Publishing Values

            ```swift
            func onBioDataUpdate(_ bioData: BioData) async {
                // Publish coherence for other plugins
                await context.sharedState.setParameter("global.coherence", value: Double(bioData.coherence))

                // Set flags
                await context.sharedState.setFlag("quantum.enabled", value: isQuantumMode)
            }
            ```

            ## Reading Values

            ```swift
            func onFrame(deltaTime: TimeInterval) {
                Task {
                    // Read published values
                    if let coherence = await context.sharedState.getParameter("global.coherence") {
                        updateVisualization(coherence: Float(coherence))
                    }

                    // Check flags
                    let quantumEnabled = await context.sharedState.getFlag("quantum.enabled")
                    if quantumEnabled {
                        enableQuantumEffects()
                    }
                }
            }
            ```

            ## Message Passing

            ```swift
            // Send message to specific plugin
            let message = SharedPluginState.PluginMessage(
                fromPlugin: self.identifier,
                toPlugin: "com.other.plugin",
                type: "trigger",
                data: ["event": "quantum_pulse", "intensity": "0.8"],
                timestamp: Date()
            )
            await context.sharedState.sendMessage(message)

            // Receive messages
            let messages = await context.sharedState.getMessages(for: self.identifier)
            for msg in messages where msg.type == "trigger" {
                handleTrigger(msg.data)
            }
            ```

            ## Recommended Key Naming

            ```
            global.*          - System-wide values (coherence, tempo, etc.)
            plugin.<id>.*     - Plugin-specific values
            quantum.*         - Quantum system values
            bio.*             - Biometric values
            audio.*           - Audio engine values
            visual.*          - Visual engine values
            ```
            """

            public static let audioProcessing = """
            # Audio Processing API

            Real-time audio processing with zero-latency buffer access.

            ## Audio Buffer Format

            ```swift
            func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
                // buffer: Interleaved float samples [-1.0, 1.0]
                // sampleRate: 44100, 48000, 96000, etc.
                // channels: 1 (mono), 2 (stereo), 8 (surround), etc.

                let samplesPerChannel = buffer.count / channels

                // Process each sample
                for frame in 0..<samplesPerChannel {
                    for channel in 0..<channels {
                        let index = frame * channels + channel
                        var sample = buffer[index]

                        // Process sample here
                        sample = processSample(sample)

                        buffer[index] = sample
                    }
                }
            }
            ```

            ## Audio Thread Restrictions

            ⚠️ **CRITICAL**: Never do these in `processAudio()`:
            - Allocate memory (no `Array()`, `String()`, etc.)
            - Use locks or mutexes
            - Call async functions
            - Perform I/O operations
            - Use `print()` or logging

            ✅ **Safe**: Use pre-allocated buffers and atomic operations

            ## Simple Audio Effect

            ```swift
            class SimpleGainPlugin: EchoelmusicPlugin {
                private var gain: Float = 0.5

                func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
                    // Simple gain (volume) effect
                    for i in 0..<buffer.count {
                        buffer[i] *= gain
                    }
                }
            }
            ```

            ## Filter Example

            ```swift
            class SimpleLowPassFilter: EchoelmusicPlugin {
                private var cutoff: Float = 1000.0  // Hz
                private var previousSamples: [Float] = [0, 0]

                func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
                    let rc = 1.0 / (2.0 * Float.pi * cutoff)
                    let dt = 1.0 / Float(sampleRate)
                    let alpha = dt / (rc + dt)

                    for channel in 0..<channels {
                        var prev = previousSamples[channel]

                        for frame in 0..<(buffer.count / channels) {
                            let index = frame * channels + channel
                            let current = buffer[index]

                            // Low-pass filter
                            prev = prev + alpha * (current - prev)
                            buffer[index] = prev
                        }

                        previousSamples[channel] = prev
                    }
                }
            }
            ```

            ## Oscillator Example

            ```swift
            class SineOscillator: EchoelmusicPlugin {
                private var phase: Float = 0.0
                private var frequency: Float = 440.0  // A4
                private var amplitude: Float = 0.3

                func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
                    let phaseIncrement = frequency / Float(sampleRate)

                    for frame in 0..<(buffer.count / channels) {
                        // Generate sine wave
                        let sample = sin(phase * 2.0 * Float.pi) * amplitude

                        // Write to all channels
                        for channel in 0..<channels {
                            buffer[frame * channels + channel] += sample
                        }

                        // Increment phase
                        phase += phaseIncrement
                        if phase >= 1.0 { phase -= 1.0 }
                    }
                }
            }
            ```
            """

            public static let visualRendering = """
            # Visual Rendering API

            Create stunning visuals synchronized to bio signals and audio.

            ## Render Context

            ```swift
            struct RenderContext: Sendable {
                var width: Int                    // Frame width in pixels
                var height: Int                   // Frame height in pixels
                var pixelScale: Float             // Retina scale (1.0, 2.0, 3.0)
                var deltaTime: TimeInterval       // Time since last frame
                var totalTime: TimeInterval       // Total elapsed time
                var frameNumber: Int              // Frame counter
                var bioData: BioData              // Current bio data
                var quantumState: QuantumPluginState  // Quantum state
            }
            ```

            ## Visual Output

            ```swift
            struct VisualOutput: Sendable {
                var pixelData: Data?              // Raw pixel data (RGBA)
                var textureId: UInt32?            // GPU texture ID
                var shaderUniforms: [String: Float]  // Shader parameters
                var blendMode: BlendMode          // How to composite

                enum BlendMode {
                    case replace  // Replace existing pixels
                    case add      // Additive blending
                    case multiply // Multiply blending
                    case screen   // Screen blending
                    case overlay  // Overlay blending
                }
            }
            ```

            ## Shader-Based Rendering (Recommended)

            ```swift
            func renderVisual(context: RenderContext) -> VisualOutput? {
                // Pass parameters to GPU shader
                VisualOutput(
                    pixelData: nil,
                    textureId: nil,
                    shaderUniforms: [
                        "time": Float(context.totalTime),
                        "coherence": context.bioData.coherence,
                        "resolution": Float(context.width),
                        "aspectRatio": Float(context.width) / Float(context.height)
                    ],
                    blendMode: .add
                )
            }
            ```

            ## CPU Pixel Rendering

            ```swift
            func renderVisual(context: RenderContext) -> VisualOutput? {
                let width = context.width
                let height = context.height
                var pixels = [UInt8](repeating: 0, count: width * height * 4)

                // Draw gradient based on coherence
                for y in 0..<height {
                    for x in 0..<width {
                        let index = (y * width + x) * 4
                        let intensity = UInt8(context.bioData.coherence * 255)

                        pixels[index + 0] = intensity      // Red
                        pixels[index + 1] = 255 - intensity // Green
                        pixels[index + 2] = 128            // Blue
                        pixels[index + 3] = 255            // Alpha
                    }
                }

                return VisualOutput(
                    pixelData: Data(pixels),
                    textureId: nil,
                    shaderUniforms: [:],
                    blendMode: .replace
                )
            }
            ```

            ## Animated Visual

            ```swift
            func renderVisual(context: RenderContext) -> VisualOutput? {
                // Rotating mandala synchronized to breathing
                let breathPhase = sin(Float(context.totalTime) * 0.5)
                let rotation = Float(context.totalTime) * context.bioData.coherence
                let scale = 0.8 + breathPhase * 0.2

                VisualOutput(
                    pixelData: nil,
                    textureId: nil,
                    shaderUniforms: [
                        "rotation": rotation,
                        "scale": scale,
                        "coherence": context.bioData.coherence,
                        "hue": context.bioData.coherence * 0.3,
                        "time": Float(context.totalTime)
                    ],
                    blendMode: .add
                )
            }
            ```
            """

        } // APIReference

        // MARK: - Code Examples

        public struct CodeExamples {

            public static let simpleVisualizer = """
            # Example 1: Simple Visualizer Plugin

            A minimal plugin that creates a pulsing circle based on coherence.

            ```swift
            import Foundation

            /// Simple coherence visualizer - pulsing circle
            final class SimpleVisualizerPlugin: EchoelmusicPlugin {

                // MARK: - Plugin Info

                var identifier: String { "com.example.simple-visualizer" }
                var name: String { "Simple Visualizer" }
                var version: String { "1.0.0" }
                var author: String { "Your Name" }
                var pluginDescription: String { "Pulsing circle that grows with coherence" }
                var requiredSDKVersion: String { "2.0.0" }
                var capabilities: Set<PluginCapability> { [.visualization, .bioProcessing] }

                // MARK: - State

                private var coherence: Float = 0.5
                private var pulsePhase: Float = 0.0

                // MARK: - Lifecycle

                func onLoad(context: PluginContext) async throws {
                    DeveloperConsole.shared.info("Simple Visualizer loaded", source: identifier)
                }

                func onUnload() async {
                    DeveloperConsole.shared.info("Simple Visualizer unloaded", source: identifier)
                }

                // MARK: - Updates

                func onFrame(deltaTime: TimeInterval) {
                    // Animate pulse
                    pulsePhase += Float(deltaTime) * 2.0
                    if pulsePhase >= Float.pi * 2 { pulsePhase = 0 }
                }

                func onBioDataUpdate(_ bioData: BioData) {
                    coherence = bioData.coherence
                }

                // MARK: - Rendering

                func renderVisual(context: RenderContext) -> VisualOutput? {
                    let pulse = sin(pulsePhase) * 0.5 + 0.5
                    let radius = 0.3 + coherence * 0.4 + pulse * 0.1

                    return VisualOutput(
                        pixelData: nil,
                        textureId: nil,
                        shaderUniforms: [
                            "radius": radius,
                            "coherence": coherence,
                            "pulse": pulse,
                            "time": Float(context.totalTime)
                        ],
                        blendMode: .add
                    )
                }
            }
            ```
            """

            public static let bioReactiveEffect = """
            # Example 2: Bio-Reactive Audio Effect

            An audio plugin that applies reverb based on coherence level.

            ```swift
            import Foundation
            import simd

            /// Bio-reactive reverb - more reverb at low coherence
            final class BioReverbPlugin: EchoelmusicPlugin {

                // MARK: - Plugin Info

                var identifier: String { "com.example.bio-reverb" }
                var name: String { "Bio Reverb" }
                var version: String { "1.0.0" }
                var author: String { "Your Name" }
                var pluginDescription: String { "Reverb amount controlled by bio coherence" }
                var requiredSDKVersion: String { "2.0.0" }
                var capabilities: Set<PluginCapability> { [.audioEffect, .bioProcessing] }

                // MARK: - Configuration

                struct Configuration: Sendable {
                    var minWet: Float = 0.0     // Wet mix at high coherence
                    var maxWet: Float = 0.7     // Wet mix at low coherence
                    var roomSize: Float = 0.5   // 0.0 - 1.0
                    var damping: Float = 0.5    // 0.0 - 1.0
                }

                // MARK: - State

                var configuration = Configuration()
                private var coherence: Float = 0.5
                private var delayBuffer: [Float] = []
                private var delayIndex: Int = 0

                // MARK: - Constants

                private let maxDelayMs: Int = 100

                // MARK: - Lifecycle

                func onLoad(context: PluginContext) async throws {
                    // Allocate delay buffer (100ms at 48kHz = 4800 samples)
                    delayBuffer = Array(repeating: 0, count: 4800 * 2) // Stereo
                    DeveloperConsole.shared.info("Bio Reverb loaded", source: identifier)
                }

                func onUnload() async {
                    delayBuffer.removeAll()
                }

                // MARK: - Updates

                func onBioDataUpdate(_ bioData: BioData) {
                    coherence = bioData.coherence
                }

                // MARK: - Audio Processing

                func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
                    // Calculate wet/dry mix based on coherence
                    // Low coherence = more reverb
                    let wetMix = configuration.minWet + (1.0 - coherence) * (configuration.maxWet - configuration.minWet)
                    let dryMix = 1.0 - wetMix

                    // Simple delay-based reverb
                    let delayTime = Int(Float(maxDelayMs) * configuration.roomSize * Float(sampleRate) / 1000.0)
                    let feedback = 0.3 + configuration.roomSize * 0.4
                    let damping = configuration.damping

                    for i in 0..<buffer.count {
                        let input = buffer[i]

                        // Read from delay buffer
                        let delayedSample = delayBuffer[delayIndex]

                        // Apply damping (low-pass)
                        let wetSample = delayedSample * (1.0 - damping) + input * damping

                        // Write to delay buffer with feedback
                        delayBuffer[delayIndex] = input + wetSample * feedback

                        // Mix dry and wet
                        buffer[i] = input * dryMix + wetSample * wetMix

                        // Advance delay index
                        delayIndex = (delayIndex + 1) % delayTime
                    }
                }
            }
            ```
            """

            public static let midiProcessor = """
            # Example 3: MIDI Processor Plugin

            Generate MIDI notes from bio data.

            ```swift
            import Foundation

            /// Bio-to-MIDI converter
            final class BioMIDIPlugin: EchoelmusicPlugin {

                // MARK: - Plugin Info

                var identifier: String { "com.example.bio-midi" }
                var name: String { "Bio MIDI" }
                var version: String { "1.0.0" }
                var author: String { "Your Name" }
                var pluginDescription: String { "Generates MIDI notes from heart rate and coherence" }
                var requiredSDKVersion: String { "2.0.0" }
                var capabilities: Set<PluginCapability> { [.midiOutput, .bioProcessing, .hrvAnalysis] }

                // MARK: - MIDI Message

                struct MIDIMessage: Sendable {
                    var status: UInt8    // 0x90 = note on, 0x80 = note off
                    var note: UInt8      // 0-127
                    var velocity: UInt8  // 0-127
                    var timestamp: TimeInterval
                }

                // MARK: - State

                private var heartRate: Float = 70.0
                private var coherence: Float = 0.5
                private var currentNote: UInt8? = nil
                private var noteTimer: Float = 0.0
                private var midiMessages: [MIDIMessage] = []

                // MARK: - Scale

                private let pentatonicScale: [UInt8] = [0, 2, 4, 7, 9]  // Major pentatonic intervals
                private let baseNote: UInt8 = 60  // C4

                // MARK: - Lifecycle

                func onLoad(context: PluginContext) async throws {
                    DeveloperConsole.shared.info("Bio MIDI loaded", source: identifier)
                }

                func onUnload() async {
                    // Send note off for current note
                    if let note = currentNote {
                        stopNote(note)
                    }
                }

                // MARK: - Updates

                func onFrame(deltaTime: TimeInterval) {
                    noteTimer += Float(deltaTime)

                    // Trigger note based on heart rate
                    let beatInterval = 60.0 / heartRate

                    if noteTimer >= beatInterval {
                        noteTimer = 0
                        generateNote()
                    }
                }

                func onBioDataUpdate(_ bioData: BioData) {
                    coherence = bioData.coherence
                    if let hr = bioData.heartRate {
                        heartRate = hr
                    }
                }

                // MARK: - MIDI Generation

                private func generateNote() {
                    // Stop previous note
                    if let prevNote = currentNote {
                        stopNote(prevNote)
                    }

                    // Select note from pentatonic scale based on coherence
                    let scaleIndex = Int(coherence * Float(pentatonicScale.count - 1))
                    let octave = Int((coherence * 3.0))  // 0-2 octaves up
                    let note = baseNote + pentatonicScale[scaleIndex] + UInt8(octave * 12)

                    // Velocity based on coherence
                    let velocity = UInt8(60 + coherence * 67)  // 60-127

                    // Send note on
                    let noteOn = MIDIMessage(
                        status: 0x90,
                        note: note,
                        velocity: velocity,
                        timestamp: Date().timeIntervalSince1970
                    )
                    midiMessages.append(noteOn)
                    currentNote = note

                    DeveloperConsole.shared.debug("MIDI Note: \\(note) Vel: \\(velocity)", source: identifier)
                }

                private func stopNote(_ note: UInt8) {
                    let noteOff = MIDIMessage(
                        status: 0x80,
                        note: note,
                        velocity: 0,
                        timestamp: Date().timeIntervalSince1970
                    )
                    midiMessages.append(noteOff)
                    currentNote = nil
                }

                // MARK: - Public API

                func getMIDIMessages() -> [MIDIMessage] {
                    let messages = midiMessages
                    midiMessages.removeAll()
                    return messages
                }
            }
            ```
            """

            public static let dmxController = """
            # Example 4: DMX Lighting Controller

            Control stage lighting from bio signals.

            ```swift
            import Foundation

            /// DMX lighting controlled by bio coherence
            final class BioDMXPlugin: EchoelmusicPlugin {

                // MARK: - Plugin Info

                var identifier: String { "com.example.bio-dmx" }
                var name: String { "Bio DMX" }
                var version: String { "1.0.0" }
                var author: String { "Your Name" }
                var pluginDescription: String { "DMX lighting synchronized to bio coherence" }
                var requiredSDKVersion: String { "2.0.0" }
                var capabilities: Set<PluginCapability> { [.dmxOutput, .bioProcessing] }

                // MARK: - DMX Fixture

                struct RGBFixture: Sendable {
                    var address: UInt16
                    var red: UInt8 = 0
                    var green: UInt8 = 0
                    var blue: UInt8 = 0
                    var intensity: UInt8 = 255
                }

                // MARK: - State

                private var fixtures: [RGBFixture] = []
                private var coherence: Float = 0.5
                private var breathPhase: Float = 0.0

                // MARK: - Lifecycle

                func onLoad(context: PluginContext) async throws {
                    // Create 8 RGB fixtures starting at address 1
                    for i in 0..<8 {
                        fixtures.append(RGBFixture(address: UInt16(1 + i * 4)))
                    }
                    DeveloperConsole.shared.info("Bio DMX loaded - \\(fixtures.count) fixtures", source: identifier)
                }

                func onUnload() async {
                    // Blackout all fixtures
                    for i in 0..<fixtures.count {
                        fixtures[i].red = 0
                        fixtures[i].green = 0
                        fixtures[i].blue = 0
                    }
                }

                // MARK: - Updates

                func onFrame(deltaTime: TimeInterval) {
                    // Animate breathing
                    breathPhase += Float(deltaTime) * 0.5
                    if breathPhase >= Float.pi * 2 { breathPhase = 0 }

                    updateFixtures()
                }

                func onBioDataUpdate(_ bioData: BioData) {
                    coherence = bioData.coherence
                }

                // MARK: - DMX Update

                private func updateFixtures() {
                    // Color based on coherence
                    // Low coherence = red, high coherence = green
                    let red = UInt8((1.0 - coherence) * 255)
                    let green = UInt8(coherence * 255)
                    let blue: UInt8 = 50

                    // Intensity pulses with breathing
                    let breathIntensity = sin(breathPhase) * 0.5 + 0.5
                    let intensity = UInt8((0.3 + breathIntensity * 0.7) * 255)

                    // Update all fixtures
                    for i in 0..<fixtures.count {
                        fixtures[i].red = red
                        fixtures[i].green = green
                        fixtures[i].blue = blue
                        fixtures[i].intensity = intensity
                    }
                }

                // MARK: - Public API

                func getDMXData() -> Data {
                    // Generate DMX universe data (512 channels)
                    var dmxData = Data(count: 512)

                    for fixture in fixtures {
                        let addr = Int(fixture.address - 1)
                        guard addr + 3 < 512 else { continue }

                        dmxData[addr + 0] = fixture.red
                        dmxData[addr + 1] = fixture.green
                        dmxData[addr + 2] = fixture.blue
                        dmxData[addr + 3] = fixture.intensity
                    }

                    return dmxData
                }
            }
            ```
            """

            public static let aiGenerator = """
            # Example 5: AI Music Generator

            Generate melodies using Markov chains and bio data.

            ```swift
            import Foundation

            /// AI melody generator based on bio coherence
            final class AIMelodyPlugin: EchoelmusicPlugin {

                // MARK: - Plugin Info

                var identifier: String { "com.example.ai-melody" }
                var name: String { "AI Melody Generator" }
                var version: String { "1.0.0" }
                var author: String { "Your Name" }
                var pluginDescription: String { "Generates melodies using Markov chains influenced by bio coherence" }
                var requiredSDKVersion: String { "2.0.0" }
                var capabilities: Set<PluginCapability> { [.audioGenerator, .aiGeneration, .bioProcessing] }

                // MARK: - Markov Chain

                struct MarkovChain {
                    // Transition probabilities between intervals
                    var transitions: [[Float]] = [
                        [0.3, 0.4, 0.2, 0.1],  // From unison
                        [0.2, 0.3, 0.3, 0.2],  // From step
                        [0.1, 0.3, 0.4, 0.2],  // From skip
                        [0.2, 0.2, 0.3, 0.3]   // From leap
                    ]

                    enum Interval: Int {
                        case unison = 0  // Same note
                        case step = 1    // +/- 1-2 semitones
                        case skip = 2    // +/- 3-4 semitones
                        case leap = 3    // +/- 5+ semitones
                    }

                    func nextInterval(from current: Interval) -> Interval {
                        let probs = transitions[current.rawValue]
                        let rand = Float.random(in: 0...1)

                        var cumulative: Float = 0
                        for (i, prob) in probs.enumerated() {
                            cumulative += prob
                            if rand < cumulative {
                                return Interval(rawValue: i) ?? .step
                            }
                        }
                        return .step
                    }
                }

                // MARK: - State

                private var markov = MarkovChain()
                private var coherence: Float = 0.5
                private var currentNote: Int = 60  // C4
                private var lastInterval: MarkovChain.Interval = .unison
                private var notePhase: Float = 0.0
                private var noteDuration: Float = 0.5  // seconds

                // MARK: - Scale

                private let pentatonicScale: [Int] = [0, 2, 4, 7, 9]

                // MARK: - Lifecycle

                func onLoad(context: PluginContext) async throws {
                    DeveloperConsole.shared.info("AI Melody loaded", source: identifier)
                }

                func onUnload() async {
                    DeveloperConsole.shared.info("AI Melody unloaded", source: identifier)
                }

                // MARK: - Updates

                func onFrame(deltaTime: TimeInterval) {
                    notePhase += Float(deltaTime)

                    // Generate new note when duration elapsed
                    if notePhase >= noteDuration {
                        notePhase = 0
                        generateNextNote()
                    }
                }

                func onBioDataUpdate(_ bioData: BioData) {
                    coherence = bioData.coherence

                    // Higher coherence = slower, more flowing melodies
                    noteDuration = 0.3 + coherence * 0.7  // 0.3 - 1.0 seconds
                }

                // MARK: - Melody Generation

                private func generateNextNote() {
                    // Use Markov chain to decide interval
                    let interval = markov.nextInterval(from: lastInterval)
                    lastInterval = interval

                    // Calculate semitone change
                    let semitones: Int
                    switch interval {
                    case .unison:
                        semitones = 0
                    case .step:
                        semitones = Bool.random() ? 2 : -1
                    case .skip:
                        semitones = Bool.random() ? 4 : -3
                    case .leap:
                        semitones = Bool.random() ? 7 : -5
                    }

                    // Apply change
                    currentNote += semitones

                    // Quantize to pentatonic scale
                    currentNote = quantizeToScale(currentNote)

                    // Keep in reasonable range (C3 - C6)
                    currentNote = max(48, min(84, currentNote))

                    DeveloperConsole.shared.debug("New note: \\(currentNote)", source: identifier)
                }

                private func quantizeToScale(_ note: Int) -> Int {
                    let octave = note / 12
                    let pitchClass = note % 12

                    // Find closest scale degree
                    var closest = pentatonicScale[0]
                    var minDist = abs(pitchClass - closest)

                    for scaleDegree in pentatonicScale {
                        let dist = abs(pitchClass - scaleDegree)
                        if dist < minDist {
                            minDist = dist
                            closest = scaleDegree
                        }
                    }

                    return octave * 12 + closest
                }

                // MARK: - Audio Generation

                func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
                    let frequency = 440.0 * pow(2.0, Float(currentNote - 69) / 12.0)
                    let phaseIncrement = frequency / Float(sampleRate)

                    var localPhase = notePhase

                    for frame in 0..<(buffer.count / channels) {
                        // Simple sine wave
                        let sample = sin(localPhase * 2.0 * Float.pi) * 0.2

                        for channel in 0..<channels {
                            buffer[frame * channels + channel] += sample
                        }

                        localPhase += phaseIncrement
                        if localPhase >= 1.0 { localPhase -= 1.0 }
                    }
                }
            }
            ```
            """

        } // CodeExamples

        // MARK: - Best Practices

        public struct BestPractices {

            public static let performance = """
            # Performance Best Practices

            ## Memory Management

            ### Pre-allocate Buffers

            ```swift
            class MyPlugin: EchoelmusicPlugin {
                // ✅ GOOD: Pre-allocate in onLoad
                private var delayBuffer: [Float] = []

                func onLoad(context: PluginContext) async throws {
                    delayBuffer = Array(repeating: 0, count: 48000)
                }

                func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
                    // ✅ Use pre-allocated buffer
                    // ❌ NEVER allocate here
                }
            }
            ```

            ### Avoid Allocations in Audio Thread

            ```swift
            func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
                // ❌ BAD: Allocates memory
                let temp = Array(repeating: 0.0, count: buffer.count)

                // ✅ GOOD: Use pre-allocated or stack memory
                var temp: [Float] = delayBuffer  // Pre-allocated
            }
            ```

            ## CPU Optimization

            ### Use SIMD

            ```swift
            import simd

            func processAudioSIMD(buffer: inout [Float], gain: Float) {
                let gainVector = SIMD4<Float>(repeating: gain)

                for i in stride(from: 0, to: buffer.count, by: 4) {
                    var vec = SIMD4<Float>(
                        buffer[i],
                        buffer[i+1],
                        buffer[i+2],
                        buffer[i+3]
                    )
                    vec *= gainVector

                    buffer[i] = vec[0]
                    buffer[i+1] = vec[1]
                    buffer[i+2] = vec[2]
                    buffer[i+3] = vec[3]
                }
            }
            ```

            ### Minimize Trigonometry

            ```swift
            // ❌ BAD: Calculating sin/cos every sample
            for i in 0..<buffer.count {
                buffer[i] = sin(Float(i) * frequency)
            }

            // ✅ GOOD: Use phase accumulator
            var phase: Float = 0.0
            let phaseIncrement = frequency / Float(sampleRate)
            for i in 0..<buffer.count {
                buffer[i] = sin(phase * 2 * Float.pi)
                phase += phaseIncrement
                if phase >= 1.0 { phase -= 1.0 }
            }
            ```

            ## GPU Optimization

            ### Minimize Shader Complexity

            ```swift
            // ✅ GOOD: Pass complex calculations as uniforms
            func renderVisual(context: RenderContext) -> VisualOutput? {
                // Calculate once on CPU
                let complexValue = exp(coherence * 2.0) / (1.0 + coherence)

                VisualOutput(
                    pixelData: nil,
                    textureId: nil,
                    shaderUniforms: [
                        "precomputedValue": complexValue  // Pass to GPU
                    ],
                    blendMode: .add
                )
            }
            ```

            ## Thread Safety

            ### Atomic Operations

            ```swift
            import Atomics

            class MyPlugin: EchoelmusicPlugin {
                private let atomicCoherence = ManagedAtomic<Float>(0.5)

                // Main thread
                func onBioDataUpdate(_ bioData: BioData) {
                    atomicCoherence.store(bioData.coherence, ordering: .relaxed)
                }

                // Audio thread
                func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
                    let coherence = atomicCoherence.load(ordering: .relaxed)
                    // Use coherence safely
                }
            }
            ```

            ## Latency Minimization

            ### Buffer Size Awareness

            ```swift
            func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
                let bufferSize = buffer.count / channels
                let latencyMs = Double(bufferSize) / Double(sampleRate) * 1000.0

                // Typical buffer sizes:
                // 64 samples @ 48kHz = 1.3ms latency ✅
                // 512 samples @ 48kHz = 10.7ms latency ⚠️
            }
            ```

            ## Error Handling

            ### Graceful Degradation

            ```swift
            func onLoad(context: PluginContext) async throws {
                // Check requirements
                guard context.deviceCapabilities.hasGPU else {
                    // Fallback to CPU rendering
                    DeveloperConsole.shared.warning("No GPU, using CPU fallback", source: identifier)
                    useCPUMode = true
                    return  // Don't throw - degrade gracefully
                }

                // Critical requirement
                guard context.platform != .watchOS else {
                    throw PluginError.unsupportedPlatform("watchOS not supported")
                }
            }
            ```

            ### Input Validation

            ```swift
            func setFrequency(_ freq: Float) {
                // Clamp to valid range
                frequency = max(20, min(20000, freq))
            }

            func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
                // Protect against NaN/Inf
                for i in 0..<buffer.count {
                    if !buffer[i].isFinite {
                        buffer[i] = 0
                    }
                }
            }
            ```
            """

            public static let testing = """
            # Testing Plugins

            ## Unit Tests

            ```swift
            import XCTest
            @testable import Echoelmusic

            final class MyPluginTests: XCTestCase {

                var plugin: MyPlugin!
                var context: PluginContext!

                override func setUp() {
                    super.setUp()
                    plugin = MyPlugin()
                    context = createTestContext()
                }

                func testPluginLoads() async throws {
                    try await plugin.onLoad(context: context)
                    XCTAssertEqual(plugin.identifier, "com.example.my-plugin")
                }

                func testBioDataUpdate() {
                    let bioData = BioData(
                        heartRate: 70,
                        hrvSDNN: 50,
                        hrvRMSSD: 40,
                        coherence: 0.8,
                        breathingRate: 12,
                        skinConductance: nil,
                        temperature: nil,
                        timestamp: Date()
                    )

                    plugin.onBioDataUpdate(bioData)
                    // Verify plugin state updated
                }

                func testAudioProcessing() {
                    var buffer: [Float] = Array(repeating: 0, count: 512)
                    plugin.processAudio(buffer: &buffer, sampleRate: 48000, channels: 2)

                    // Verify output is in valid range
                    for sample in buffer {
                        XCTAssertTrue(sample >= -1.0 && sample <= 1.0)
                        XCTAssertTrue(sample.isFinite)
                    }
                }

                private func createTestContext() -> PluginContext {
                    PluginContext(
                        sdkVersion: .current,
                        hostAppVersion: "2.0.0",
                        platform: .iOS,
                        deviceCapabilities: PluginContext.DeviceCapabilities(
                            hasGPU: true,
                            hasNeuralEngine: true,
                            hasBiometrics: true,
                            hasHaptics: true,
                            hasSpatialAudio: true,
                            maxTextureSize: 16384,
                            cpuCores: 8,
                            memoryMB: 8192
                        ),
                        dataDirectory: FileManager.default.temporaryDirectory,
                        cacheDirectory: FileManager.default.temporaryDirectory,
                        sharedState: SharedPluginState()
                    )
                }
            }
            ```

            ## Performance Testing

            ```swift
            func testAudioPerformance() {
                var buffer: [Float] = Array(repeating: 0, count: 512)

                measure {
                    for _ in 0..<1000 {
                        plugin.processAudio(buffer: &buffer, sampleRate: 48000, channels: 2)
                    }
                }

                // Should complete in < 0.1 seconds for 1000 iterations
            }
            ```

            ## Integration Testing

            ```swift
            func testPluginManager() async throws {
                let manager = PluginManager()
                let plugin = MyPlugin()

                // Test loading
                try await manager.loadPlugin(plugin)
                XCTAssertTrue(manager.loadedPlugins.keys.contains(plugin.identifier))

                // Test bio broadcast
                let bioData = BioData.empty
                manager.broadcastBioData(bioData)

                // Test unloading
                try await manager.unloadPlugin(plugin.identifier)
                XCTAssertFalse(manager.loadedPlugins.keys.contains(plugin.identifier))
            }
            ```
            """

        } // BestPractices

        // MARK: - Publishing

        public struct Publishing {

            public static let packaging = """
            # Plugin Packaging & Distribution

            ## Plugin Structure

            ```
            MyPlugin/
            ├── Package.swift              # Swift package manifest
            ├── README.md                  # Plugin documentation
            ├── LICENSE                    # MIT, Apache 2.0, etc.
            ├── Sources/
            │   └── MyPlugin/
            │       ├── MyPlugin.swift     # Main plugin file
            │       └── Configuration.swift
            ├── Tests/
            │   └── MyPluginTests/
            │       └── MyPluginTests.swift
            └── Resources/               # Optional
                ├── icon.png
                └── presets/
            ```

            ## Package.swift

            ```swift
            // swift-tools-version: 5.9
            import PackageDescription

            let package = Package(
                name: "MyPlugin",
                platforms: [
                    .iOS(.v15),
                    .macOS(.v12)
                ],
                products: [
                    .library(
                        name: "MyPlugin",
                        targets: ["MyPlugin"]
                    )
                ],
                dependencies: [
                    .package(url: "https://github.com/echoelmusic/echoelmusic.git", from: "2.0.0")
                ],
                targets: [
                    .target(
                        name: "MyPlugin",
                        dependencies: ["Echoelmusic"]
                    ),
                    .testTarget(
                        name: "MyPluginTests",
                        dependencies: ["MyPlugin"]
                    )
                ]
            )
            ```

            ## README.md Template

            ```markdown
            # My Echoelmusic Plugin

            Short description of what your plugin does.

            ## Features

            - Feature 1
            - Feature 2
            - Feature 3

            ## Requirements

            - Echoelmusic SDK 2.0.0+
            - iOS 15+ / macOS 12+
            - GPU required

            ## Installation

            ### Swift Package Manager

            ```swift
            dependencies: [
                .package(url: "https://github.com/username/MyPlugin.git", from: "1.0.0")
            ]
            ```

            ## Usage

            ```swift
            let plugin = MyPlugin()
            try await pluginManager.loadPlugin(plugin)
            ```

            ## Configuration

            ```swift
            plugin.setColorScheme(.rainbow)
            plugin.setIntensity(0.8)
            ```

            ## License

            MIT License - see LICENSE file

            ## Author

            Your Name - your@email.com
            ```

            ## Versioning

            Follow Semantic Versioning (semver.org):

            - **MAJOR**: Breaking changes (2.0.0)
            - **MINOR**: New features, backward compatible (1.1.0)
            - **PATCH**: Bug fixes (1.0.1)

            ```swift
            var version: String { "1.2.3" }
            ```

            ## Distribution Channels

            ### 1. Swift Package Manager (Recommended)

            Host on GitHub, GitLab, or BitBucket:

            ```bash
            git tag 1.0.0
            git push origin 1.0.0
            ```

            ### 2. Echoelmusic Plugin Registry

            Submit to https://plugins.echoelmusic.com:

            ```bash
            echoelmusic-cli plugin publish \\
                --name "My Plugin" \\
                --version 1.0.0 \\
                --github "username/MyPlugin"
            ```

            ### 3. Direct Distribution

            Provide Swift package URL:

            ```
            https://github.com/username/MyPlugin.git
            ```

            ## Plugin Metadata

            Create `plugin.json` for registry:

            ```json
            {
                "identifier": "com.example.my-plugin",
                "name": "My Plugin",
                "version": "1.0.0",
                "author": "Your Name",
                "description": "Short description",
                "homepage": "https://github.com/username/MyPlugin",
                "license": "MIT",
                "capabilities": [
                    "visualization",
                    "bioProcessing"
                ],
                "platforms": ["iOS", "macOS"],
                "minSDKVersion": "2.0.0",
                "screenshots": [
                    "https://example.com/screenshot1.png"
                ],
                "tags": ["visuals", "bio-reactive", "meditation"]
            }
            ```

            ## Update Mechanism

            Support automatic updates:

            ```swift
            class MyPlugin: EchoelmusicPlugin {
                var updateURL: URL? {
                    URL(string: "https://api.example.com/plugin/updates")
                }

                func checkForUpdates() async throws -> String? {
                    // Return new version if available
                }
            }
            ```
            """

        } // Publishing

        // MARK: - Troubleshooting

        public struct Troubleshooting {

            public static let commonIssues = """
            # Troubleshooting Guide

            ## Common Issues

            ### Plugin Fails to Load

            **Error**: "Plugin 'xxx' is already loaded"

            **Solution**:
            ```swift
            // Unload first
            try await pluginManager.unloadPlugin(identifier)
            // Then reload
            try await pluginManager.loadPlugin(plugin)
            ```

            **Error**: "Incompatible SDK version"

            **Solution**:
            ```swift
            // Update requiredSDKVersion
            var requiredSDKVersion: String { "2.0.0" }  // Not "2.0.1"
            ```

            ### Audio Processing Issues

            **Problem**: Audio crackling or glitches

            **Solutions**:
            1. Check for allocations in audio thread
            2. Verify all samples are finite
            3. Ensure buffer size handling is correct

            ```swift
            func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
                // ✅ Verify buffer size
                guard buffer.count % channels == 0 else {
                    DeveloperConsole.shared.error("Invalid buffer size", source: identifier)
                    return
                }

                // ✅ Check for NaN/Inf
                for i in 0..<buffer.count {
                    if !buffer[i].isFinite {
                        buffer[i] = 0
                    }
                }
            }
            ```

            **Problem**: High CPU usage

            **Solutions**:
            1. Profile with Instruments
            2. Use SIMD operations
            3. Reduce complexity
            4. Pre-calculate expensive operations

            ### Visual Rendering Issues

            **Problem**: Low frame rate

            **Solutions**:
            1. Use GPU shaders instead of CPU pixel manipulation
            2. Reduce texture resolution
            3. Simplify shader code

            ```swift
            // ✅ GOOD: Pass to GPU shader
            VisualOutput(
                shaderUniforms: ["coherence": coherence],
                blendMode: .add
            )

            // ❌ SLOW: CPU pixel manipulation
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            // ... manipulate pixels
            ```

            ### Bio Data Issues

            **Problem**: Bio data is nil

            **Solutions**:
            1. Check device has bio sensors
            2. Request HealthKit permissions
            3. Use simulator fallback

            ```swift
            func onBioDataUpdate(_ bioData: BioData) {
                // ✅ Always check optional values
                if let heartRate = bioData.heartRate {
                    useHeartRate(heartRate)
                } else {
                    useFallbackValue()
                }
            }
            ```

            ### Memory Issues

            **Problem**: Memory leak

            **Solutions**:
            1. Use weak references for closures
            2. Clean up in onUnload
            3. Profile with Instruments

            ```swift
            func onLoad(context: PluginContext) async throws {
                // ✅ Use weak self in closures
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    self?.update()
                }
            }

            func onUnload() async {
                // ✅ Cleanup
                timer?.invalidate()
                timer = nil
                buffers.removeAll()
            }
            ```

            ## Debugging Tips

            ### Enable Developer Console

            ```swift
            func onLoad(context: PluginContext) async throws {
                DeveloperConsole.shared.isVisible = true
                DeveloperConsole.shared.logLevel = .debug
            }
            ```

            ### Logging Best Practices

            ```swift
            // Use appropriate log levels
            DeveloperConsole.shared.debug("Minor info", source: identifier)
            DeveloperConsole.shared.info("Important event", source: identifier)
            DeveloperConsole.shared.warning("Potential issue", source: identifier)
            DeveloperConsole.shared.error("Critical error", source: identifier)
            ```

            ### Performance Profiling

            ```swift
            func onFrame(deltaTime: TimeInterval) {
                let start = Date()

                // Your code here
                updateState()

                let elapsed = Date().timeIntervalSince(start)
                if elapsed > 0.016 {  // > 16ms (60fps)
                    DeveloperConsole.shared.warning("Frame took \\(elapsed * 1000)ms", source: identifier)
                }
            }
            ```

            ## FAQ

            **Q: Can I use Combine/async-await in audio thread?**

            A: No! Audio thread must be real-time safe. Use only in onLoad, onFrame, onBioDataUpdate.

            **Q: How do I test on simulator?**

            A: Use mock bio data:
            ```swift
            #if targetEnvironment(simulator)
            let mockBioData = BioData(
                heartRate: 70,
                hrvSDNN: 50,
                hrvRMSSD: 40,
                coherence: 0.7,
                breathingRate: 12,
                skinConductance: nil,
                temperature: nil,
                timestamp: Date()
            )
            onBioDataUpdate(mockBioData)
            #endif
            ```

            **Q: How do I share data between plugins?**

            A: Use SharedPluginState:
            ```swift
            await context.sharedState.setParameter("myValue", value: 42)
            ```

            **Q: Can I use third-party Swift packages?**

            A: Yes! Add to Package.swift dependencies.

            **Q: How do I handle different screen sizes?**

            A: Use RenderContext dimensions:
            ```swift
            func renderVisual(context: RenderContext) -> VisualOutput? {
                let aspectRatio = Float(context.width) / Float(context.height)
                // Adapt to aspect ratio
            }
            ```

            ## Getting Help

            1. Check documentation: https://docs.echoelmusic.com
            2. Search GitHub issues: https://github.com/echoelmusic/echoelmusic/issues
            3. Ask on Discord: https://discord.gg/echoelmusic
            4. Email: developers@echoelmusic.com

            ## Reporting Bugs

            Include:
            - Plugin name and version
            - SDK version
            - Platform and OS version
            - Minimal reproduction code
            - Expected vs actual behavior
            - Console logs
            """

        } // Troubleshooting

    } // Documentation

} // DeveloperSDKGuide

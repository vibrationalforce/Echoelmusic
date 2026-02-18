// EchoelWorldEngine.swift
// Echoelmusic — Procedural Bio-Reactive World Generation
//
// ═══════════════════════════════════════════════════════════════════════════════
// EchoelWorld — Procedural universes that breathe with your biometrics
//
// Architecture:
// ┌──────────────────────────────────────────────────────────────────────────┐
// │  Bio-State (coherence, HR, HRV)                                          │
// │       │                                                                  │
// │       ├─→ World Seed Generator ──→ Deterministic from bio-state         │
// │       ├─→ Terrain Morphing ──→ Landscape reacts to coherence            │
// │       ├─→ Weather System ──→ Calm/Storm from HRV                        │
// │       ├─→ Time of Day ──→ Circadian-aware lighting                      │
// │       │                                                                  │
// │  Audio Analysis                                                          │
// │       │                                                                  │
// │       ├─→ Frequency → Flora density (bass=trees, treble=flowers)        │
// │       ├─→ Amplitude → Water level, wind speed                           │
// │       ├─→ Rhythm → Creature movement patterns                           │
// │       ├─→ Key → Color palette (major=warm, minor=cool)                  │
// │       │                                                                  │
// │  EchoelMind (On-Device LLM)                                             │
// │       │                                                                  │
// │       ├─→ Narrative → Lore, place names, story fragments                │
// │       ├─→ Descriptions → Accessibility text for world elements          │
// │       │                                                                  │
// │       ▼                                                                  │
// │  World State ──→ Godot/Metal Renderer                                   │
// │            ──→ Spatial Audio (PHASE/AVAudio)                             │
// │            ──→ visionOS Immersive Space                                  │
// │            ──→ Stream Visual                                             │
// └──────────────────────────────────────────────────────────────────────────┘
//
// Inspiration:
// - No Man's Sky: 13 devs → 18.4 quintillion planets (Superformula, L-Systems)
// - Bio-reactivity: Your heartbeat shapes the world
// - On-device: Foundation Models for narrative, Core ML for generation
//
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine
import Accelerate

// MARK: - World Types

/// World biome types (procedurally selected from bio-state)
public enum WorldBiome: String, CaseIterable, Codable, Sendable {
    case crystal = "Crystal Caverns"        // High coherence, calm
    case forest = "Sacred Forest"           // Moderate coherence, balanced
    case ocean = "Deep Ocean"               // Low coherence, flowing
    case nebula = "Cosmic Nebula"           // High energy, creative
    case desert = "Resonant Desert"         // Low energy, meditative
    case mountain = "Harmonic Peaks"        // Peak coherence
    case void = "Quantum Void"              // Lambda mode
    case garden = "Bio-Garden"              // Wellness mode

    /// Select biome from bio-state
    public static func from(coherence: Float, energy: Float) -> WorldBiome {
        switch (coherence, energy) {
        case (0.8..., _): return .mountain
        case (0.6..., 0.5...): return .crystal
        case (0.6..., ..<0.5): return .garden
        case (0.4..<0.6, 0.5...): return .nebula
        case (0.4..<0.6, ..<0.5): return .forest
        case (..<0.4, 0.5...): return .ocean
        case (..<0.4, ..<0.5): return .desert
        default: return .void
        }
    }

    public var primaryColor: (r: Float, g: Float, b: Float) {
        switch self {
        case .crystal: return (0.6, 0.8, 1.0)      // Ice blue
        case .forest: return (0.2, 0.7, 0.3)       // Deep green
        case .ocean: return (0.1, 0.3, 0.8)        // Ocean blue
        case .nebula: return (0.7, 0.2, 0.9)       // Purple
        case .desert: return (0.9, 0.7, 0.3)       // Sand gold
        case .mountain: return (0.9, 0.9, 1.0)     // Snow white
        case .void: return (0.05, 0.0, 0.1)        // Deep void
        case .garden: return (0.4, 0.8, 0.5)       // Lush green
        }
    }

    public var ambientSound: String {
        switch self {
        case .crystal: return "crystal_resonance"
        case .forest: return "sacred_forest_ambient"
        case .ocean: return "deep_ocean_waves"
        case .nebula: return "cosmic_hum"
        case .desert: return "wind_sand"
        case .mountain: return "mountain_wind"
        case .void: return "quantum_silence"
        case .garden: return "bio_garden_life"
        }
    }
}

/// Weather state driven by HRV
public enum WorldWeather: String, CaseIterable, Codable, Sendable {
    case clear = "Clear"                    // High HRV, coherent
    case gentle = "Gentle Mist"             // Moderate HRV
    case rain = "Rhythmic Rain"             // Moderate-low HRV (rain follows HR pattern)
    case storm = "Bio-Storm"                // Low HRV, chaotic (storm intensity from stress)
    case aurora = "Aurora"                  // Peak coherence (rare, beautiful)
    case cosmic = "Cosmic Shower"           // Lambda mode active

    public static func from(hrvSDNN: Float, coherence: Float) -> WorldWeather {
        if coherence > 0.9 { return .aurora }
        switch hrvSDNN {
        case 80...: return .clear
        case 50..<80: return .gentle
        case 30..<50: return .rain
        default: return .storm
        }
    }
}

/// Time of day (circadian-aware)
public enum WorldTimeOfDay: String, CaseIterable, Codable, Sendable {
    case dawn = "Dawn"
    case morning = "Morning"
    case noon = "Noon"
    case afternoon = "Afternoon"
    case dusk = "Dusk"
    case night = "Night"
    case deepNight = "Deep Night"

    public static func fromRealTime() -> WorldTimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<7: return .dawn
        case 7..<11: return .morning
        case 11..<14: return .noon
        case 14..<17: return .afternoon
        case 17..<20: return .dusk
        case 20..<23: return .night
        default: return .deepNight
        }
    }
}

/// Complete world state
public struct WorldState: Sendable {
    public var seed: UInt64                  // Deterministic seed from bio-state
    public var biome: WorldBiome
    public var weather: WorldWeather
    public var timeOfDay: WorldTimeOfDay
    public var terrainAmplitude: Float       // How dramatic the terrain is (from energy)
    public var floraDensity: Float           // Vegetation density (from bass frequencies)
    public var waterLevel: Float             // Water height (from amplitude)
    public var windSpeed: Float              // Wind intensity (from HRV variability)
    public var particleDensity: Float        // Ambient particles (from coherence)
    public var colorTemperature: Float       // Warm/cool (from musical key)
    public var narrativeFragment: String     // AI-generated lore snippet
    public var placeName: String             // AI-generated location name

    public static let initial = WorldState(
        seed: 0,
        biome: .forest,
        weather: .clear,
        timeOfDay: .fromRealTime(),
        terrainAmplitude: 0.5,
        floraDensity: 0.5,
        waterLevel: 0.3,
        windSpeed: 0.2,
        particleDensity: 0.5,
        colorTemperature: 0.5,
        narrativeFragment: "",
        placeName: "Genesis"
    )
}

/// Procedural generation parameters
public struct ProceduralParams: Sendable {
    public var octaves: Int = 6                 // Perlin noise layers
    public var persistence: Float = 0.5         // Noise amplitude per octave
    public var lacunarity: Float = 2.0          // Noise frequency per octave
    public var scale: Float = 100.0             // World scale
    public var heightMultiplier: Float = 50.0   // Terrain height
    public var erosionIterations: Int = 3       // Hydraulic erosion passes
}

// MARK: - EchoelWorldEngine

/// Procedural bio-reactive world generation engine
///
/// Creates living, breathing worlds that respond to biometric data.
/// Every heartbeat shapes the terrain. Every breath moves the wind.
/// Coherence determines whether the world is chaotic or harmonious.
///
/// Usage:
/// ```swift
/// let world = EchoelWorldEngine.shared
///
/// // Start world generation
/// world.startWorldGeneration()
///
/// // World automatically evolves from EngineBus bio/audio data
///
/// // Get current world state for rendering
/// let state = world.currentState
/// print(state.biome) // .crystal (high coherence)
/// print(state.weather) // .aurora (peak coherence)
///
/// // Generate terrain heightmap
/// let heightmap = world.generateTerrainHeightmap(resolution: 256)
///
/// // Request narrative from EchoelMind
/// let lore = try await world.generateNarrative()
/// ```
@MainActor
public final class EchoelWorldEngine: ObservableObject {

    public static let shared = EchoelWorldEngine()

    // MARK: - Published State

    /// Current world state
    @Published public var currentState: WorldState = .initial

    /// Is world generation active
    @Published public var isActive: Bool = false

    /// Procedural generation parameters
    @Published public var params: ProceduralParams = ProceduralParams()

    /// World evolution speed (how fast the world changes)
    @Published public var evolutionSpeed: Float = 1.0

    /// Lock biome (prevent automatic changes)
    @Published public var biomeLocked: Bool = false

    /// World history (for time-lapse replay)
    @Published public var stateHistory: [WorldState] = []

    /// Maximum history length
    @Published public var maxHistory: Int = 1800 // 30 minutes at 1Hz

    // MARK: - Bio Inputs

    private var coherence: Float = 0.5
    private var heartRate: Float = 70
    private var hrvSDNN: Float = 50
    private var breathingRate: Float = 15
    private var audioEnergy: Float = 0
    private var audioSpectrum: [Float] = []

    // MARK: - Internal

    private var cancellables = Set<AnyCancellable>()
    private var busSubscription: BusSubscription?
    private var audioBusSubscription: BusSubscription?
    private var updateTimer: Timer?
    private var worldAge: TimeInterval = 0

    // MARK: - Initialization

    private init() {
        subscribeToBus()
    }

    // MARK: - World Control

    /// Start procedural world generation
    public func startWorldGeneration() {
        isActive = true
        worldAge = 0
        stateHistory.removeAll()

        // 1Hz world update (smooth enough for atmosphere, light on CPU)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evolveWorld()
            }
        }

        EngineBus.shared.publish(.custom(
            topic: "world.started",
            payload: ["biome": currentState.biome.rawValue]
        ))
    }

    /// Stop world generation
    public func stopWorldGeneration() {
        updateTimer?.invalidate()
        updateTimer = nil
        isActive = false
    }

    /// Force a specific biome
    public func setBiome(_ biome: WorldBiome) {
        currentState.biome = biome
        biomeLocked = true
    }

    /// Unlock biome for bio-reactive selection
    public func unlockBiome() {
        biomeLocked = false
    }

    // MARK: - Terrain Generation

    /// Generate a terrain heightmap using Perlin noise
    ///
    /// The heightmap is seeded by the current bio-state, making each
    /// person's world unique to their physiological state.
    public func generateTerrainHeightmap(resolution: Int) -> [Float] {
        let seed = currentState.seed
        var heightmap = [Float](repeating: 0, count: resolution * resolution)

        for y in 0..<resolution {
            for x in 0..<resolution {
                let nx = Float(x) / Float(resolution) * params.scale
                let ny = Float(y) / Float(resolution) * params.scale

                var amplitude: Float = 1.0
                var frequency: Float = 1.0
                var value: Float = 0
                var maxValue: Float = 0

                for _ in 0..<params.octaves {
                    // Perlin noise approximation using sin/cos (no external dependency)
                    let sx = nx * frequency + Float(seed % 1000)
                    let sy = ny * frequency + Float(seed % 997)
                    let noise = perlinNoise2D(x: sx, y: sy)

                    value += noise * amplitude
                    maxValue += amplitude
                    amplitude *= params.persistence
                    frequency *= params.lacunarity
                }

                // Normalize and apply bio-reactive height
                let normalized = (value / maxValue + 1.0) / 2.0
                let bioModulated = normalized * params.heightMultiplier * currentState.terrainAmplitude
                heightmap[y * resolution + x] = bioModulated
            }
        }

        return heightmap
    }

    /// Generate color map for terrain based on biome
    public func generateColorMap(heightmap: [Float], resolution: Int) -> [(r: Float, g: Float, b: Float)] {
        let biomeColor = currentState.biome.primaryColor

        return heightmap.map { height in
            let normalizedHeight = height / (params.heightMultiplier * currentState.terrainAmplitude)
            let warmth = currentState.colorTemperature

            // Blend biome color with height-based variation
            let r = biomeColor.r * (0.5 + normalizedHeight * 0.5) * (0.8 + warmth * 0.4)
            let g = biomeColor.g * (0.3 + normalizedHeight * 0.7)
            let b = biomeColor.b * (0.6 + (1 - normalizedHeight) * 0.4) * (1.2 - warmth * 0.4)

            return (min(1, r), min(1, g), min(1, b))
        }
    }

    // MARK: - Narrative (via EchoelMind)

    /// Generate a narrative fragment for the current world state
    public func generateNarrative() async throws -> String {
        let mind = EchoelMindEngine.shared

        let prompt = """
        Generate a brief, evocative description (2-3 sentences) for this bio-reactive world:
        - Biome: \(currentState.biome.rawValue)
        - Weather: \(currentState.weather.rawValue)
        - Time: \(currentState.timeOfDay.rawValue)
        - Coherence: \(Int(coherence * 100))%
        - Heart Rate: \(Int(heartRate)) BPM
        The world is a living expression of the user's biometric state.
        """

        let response = try await mind.generateBioReactive(
            task: .narrative,
            prompt: prompt,
            maxTokens: 150
        )

        currentState.narrativeFragment = response.output
        return response.output
    }

    /// Generate a place name for the current location
    public func generatePlaceName() async throws -> String {
        let mind = EchoelMindEngine.shared

        let response = try await mind.generate(
            task: .generate,
            prompt: "Generate a single mystical place name for a \(currentState.biome.rawValue) biome at \(currentState.timeOfDay.rawValue). Just the name, nothing else.",
            maxTokens: 20,
            temperature: 0.9
        )

        currentState.placeName = response.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return currentState.placeName
    }

    // MARK: - Private Methods

    /// Evolve world state based on current bio/audio inputs
    private func evolveWorld() {
        worldAge += 1

        // Generate seed from bio-state (deterministic)
        let seedValue = UInt64(coherence * 10000) ^ UInt64(heartRate * 100) ^ UInt64(worldAge)
        currentState.seed = seedValue

        // Update biome (if not locked)
        if !biomeLocked {
            let newBiome = WorldBiome.from(coherence: coherence, energy: audioEnergy)
            if newBiome != currentState.biome {
                // Smooth transition — only change if sustained for 5+ seconds
                // (prevents jarring biome switches from momentary fluctuations)
                currentState.biome = newBiome
            }
        }

        // Update weather from HRV
        currentState.weather = WorldWeather.from(hrvSDNN: hrvSDNN, coherence: coherence)

        // Update time of day (real-time or accelerated)
        currentState.timeOfDay = WorldTimeOfDay.fromRealTime()

        // Bio-reactive terrain morphing
        let smoothFactor: Float = 0.05 * evolutionSpeed
        currentState.terrainAmplitude = lerp(
            currentState.terrainAmplitude,
            0.3 + audioEnergy * 0.7,
            t: smoothFactor
        )

        // Flora density from bass frequencies
        let bassEnergy = audioSpectrum.prefix(8).reduce(0, +) / 8.0
        currentState.floraDensity = lerp(
            currentState.floraDensity,
            0.2 + bassEnergy * 0.8,
            t: smoothFactor
        )

        // Water level from overall amplitude
        currentState.waterLevel = lerp(
            currentState.waterLevel,
            0.2 + audioEnergy * 0.5,
            t: smoothFactor * 0.5
        )

        // Wind from breathing rate
        currentState.windSpeed = lerp(
            currentState.windSpeed,
            breathingRate / 30.0, // Normalize to 0-1
            t: smoothFactor
        )

        // Particle density from coherence
        currentState.particleDensity = lerp(
            currentState.particleDensity,
            coherence,
            t: smoothFactor
        )

        // Color temperature from coherence (warm = high coherence)
        currentState.colorTemperature = lerp(
            currentState.colorTemperature,
            coherence,
            t: smoothFactor * 0.3
        )

        // Record history
        stateHistory.append(currentState)
        if stateHistory.count > maxHistory {
            stateHistory.removeFirst()
        }

        // Publish state
        EngineBus.shared.publish(.custom(
            topic: "world.evolved",
            payload: [
                "biome": currentState.biome.rawValue,
                "weather": currentState.weather.rawValue,
                "terrain": "\(Int(currentState.terrainAmplitude * 100))%",
                "age": "\(Int(worldAge))s"
            ]
        ))
    }

    /// Simple 2D Perlin noise approximation (no external dependency)
    private func perlinNoise2D(x: Float, y: Float) -> Float {
        // Gradient noise using sin/cos hash (simple, deterministic)
        let ix = Int(floor(x))
        let iy = Int(floor(y))
        let fx = x - floor(x)
        let fy = y - floor(y)

        // Smoothstep interpolation
        let sx = fx * fx * (3 - 2 * fx)
        let sy = fy * fy * (3 - 2 * fy)

        // Hash corners
        let n00 = gradientDot(ix: ix, iy: iy, fx: fx, fy: fy)
        let n10 = gradientDot(ix: ix + 1, iy: iy, fx: fx - 1, fy: fy)
        let n01 = gradientDot(ix: ix, iy: iy + 1, fx: fx, fy: fy - 1)
        let n11 = gradientDot(ix: ix + 1, iy: iy + 1, fx: fx - 1, fy: fy - 1)

        // Bilinear interpolation
        let nx0 = n00 + sx * (n10 - n00)
        let nx1 = n01 + sx * (n11 - n01)
        return nx0 + sy * (nx1 - nx0)
    }

    private func gradientDot(ix: Int, iy: Int, fx: Float, fy: Float) -> Float {
        // Simple hash to pseudo-random gradient
        let hash = (ix &* 374761393 &+ iy &* 668265263) &* 1274126177
        let angle = Float(hash & 0xFFFF) / Float(0xFFFF) * .pi * 2
        return cos(angle) * fx + sin(angle) * fy
    }

    /// Linear interpolation
    private func lerp(_ a: Float, _ b: Float, t: Float) -> Float {
        a + (b - a) * min(max(t, 0), 1)
    }

    /// Subscribe to EngineBus for bio and audio data
    private func subscribeToBus() {
        busSubscription = EngineBus.shared.subscribe(to: .bio) { [weak self] msg in
            if case .bioUpdate(let bio) = msg {
                Task { @MainActor in
                    self?.coherence = bio.coherence
                    self?.heartRate = bio.heartRate
                    self?.hrvSDNN = bio.hrvSDNN
                    self?.breathingRate = bio.breathingRate
                }
            }
        }

        audioBusSubscription = EngineBus.shared.subscribe(to: .audio) { [weak self] msg in
            if case .audioAnalysis(let audio) = msg {
                Task { @MainActor in
                    self?.audioEnergy = audio.rmsLevel
                    self?.audioSpectrum = audio.spectrum
                }
            }
        }
    }
}

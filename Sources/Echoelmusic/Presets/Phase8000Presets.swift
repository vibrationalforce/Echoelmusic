// Phase8000Presets.swift
// Echoelmusic - 8000% MAXIMUM OVERDRIVE MODE
//
// Curated presets for all engines
// Video, Creative, Science, Wellness, Collaboration
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation

// MARK: - Preset Protocol

public protocol EnginePreset: Identifiable, Codable, Sendable {
    var id: UUID { get }
    var name: String { get }
    var description: String { get }
    var category: String { get }
    var author: String { get }
    var version: String { get }
}

// MARK: - Video Presets

public struct Phase8000VideoPreset: EnginePreset {
    public let id: UUID
    public var name: String
    public var description: String
    public var category: String
    public var author: String
    public var version: String

    public var resolution: VideoResolution
    public var frameRate: VideoFrameRate
    public var effects: [VideoEffectType]
    public var quantumSync: Bool
    public var bioReactive: Bool

    public static let cinematic4K = Phase8000VideoPreset(
        id: UUID(),
        name: "Cinematic 4K",
        description: "Professional cinema-quality video with film grain and vignette",
        category: "Professional",
        author: "Echoelmusic",
        version: "1.0",
        resolution: .uhd4k,
        frameRate: .cinema24,
        effects: [.filmGrain, .vignette, .colorGrade],
        quantumSync: false,
        bioReactive: false
    )

    public static let quantumDream = Phase8000VideoPreset(
        id: UUID(),
        name: "Quantum Dream",
        description: "Ethereal quantum effects with bio-reactive coherence field",
        category: "Quantum",
        author: "Echoelmusic",
        version: "1.0",
        resolution: .uhd4k,
        frameRate: .smooth60,
        effects: [.quantumWave, .coherenceField, .photonTrails],
        quantumSync: true,
        bioReactive: true
    )

    public static let bioReactiveFlow = Phase8000VideoPreset(
        id: UUID(),
        name: "Bio-Reactive Flow",
        description: "Heartbeat-synced visuals responding to your biometrics",
        category: "Bio-Reactive",
        author: "Echoelmusic",
        version: "1.0",
        resolution: .fullHD1080p,
        frameRate: .smooth60,
        effects: [.heartbeatPulse, .breathingWave, .hrvCoherence],
        quantumSync: true,
        bioReactive: true
    )

    public static let lightSpeed8K = Phase8000VideoPreset(
        id: UUID(),
        name: "Light Speed 8K",
        description: "Maximum resolution with quantum light trails",
        category: "Extreme",
        author: "Echoelmusic",
        version: "1.0",
        resolution: .uhd8k,
        frameRate: .proMotion120,
        effects: [.photonTrails, .lensFlare, .motionBlur],
        quantumSync: true,
        bioReactive: false
    )

    public static let socialMedia = Phase8000VideoPreset(
        id: UUID(),
        name: "Social Ready",
        description: "Optimized for social media platforms",
        category: "Social",
        author: "Echoelmusic",
        version: "1.0",
        resolution: .fullHD1080p,
        frameRate: .standard30,
        effects: [.brightness, .saturation, .sharpen],
        quantumSync: false,
        bioReactive: false
    )

    public static let all: [Phase8000VideoPreset] = [
        .cinematic4K, .quantumDream, .bioReactiveFlow, .lightSpeed8K, .socialMedia
    ]
}

// MARK: - Creative Presets

public struct CreativePreset: EnginePreset {
    public let id: UUID
    public var name: String
    public var description: String
    public var category: String
    public var author: String
    public var version: String

    public var mode: CreativeMode
    public var style: ArtStyle?
    public var genre: MusicGenre?
    public var promptTemplate: String
    public var quantumEnhanced: Bool
    public var parameters: [String: Double]

    public static let quantumArtist = CreativePreset(
        id: UUID(),
        name: "Quantum Artist",
        description: "AI art with quantum-inspired patterns and sacred geometry",
        category: "Art",
        author: "Echoelmusic",
        version: "1.0",
        mode: .quantumArt,
        style: .quantumGenerated,
        genre: nil,
        promptTemplate: "Quantum light field, sacred geometry, bioluminescent patterns, ethereal",
        quantumEnhanced: true,
        parameters: ["guidance": 9.0, "steps": 75, "coherence": 0.9]
    )

    public static let fractalExplorer = CreativePreset(
        id: UUID(),
        name: "Fractal Explorer",
        description: "Deep dive into infinite fractal dimensions",
        category: "Generative",
        author: "Echoelmusic",
        version: "1.0",
        mode: .fractals,
        style: .proceduralArt,
        genre: nil,
        promptTemplate: "",
        quantumEnhanced: true,
        parameters: ["iterations": 500, "zoom": 1.0, "perturbation": 0.05]
    )

    public static let ambientComposer = CreativePreset(
        id: UUID(),
        name: "Ambient Composer",
        description: "Generate soothing ambient soundscapes",
        category: "Music",
        author: "Echoelmusic",
        version: "1.0",
        mode: .musicComposition,
        style: nil,
        genre: .ambient,
        promptTemplate: "Peaceful ambient soundscape, flowing, ethereal, calming",
        quantumEnhanced: true,
        parameters: ["tempo": 60, "duration": 180, "layers": 5]
    )

    public static let cyberpunkVision = CreativePreset(
        id: UUID(),
        name: "Cyberpunk Vision",
        description: "Neon-soaked futuristic cityscapes",
        category: "Art",
        author: "Echoelmusic",
        version: "1.0",
        mode: .generativeArt,
        style: .cyberpunk,
        genre: nil,
        promptTemplate: "Cyberpunk cityscape, neon lights, rain-soaked streets, holographic",
        quantumEnhanced: false,
        parameters: ["guidance": 8.5, "steps": 50]
    )

    public static let meditationMusic = CreativePreset(
        id: UUID(),
        name: "Meditation Music",
        description: "Multidimensional Brainwave Entrainment and relaxation soundscapes",
        category: "Wellness",
        author: "Echoelmusic",
        version: "1.0",
        mode: .musicComposition,
        style: nil,
        genre: .meditation,
        promptTemplate: "Meditation music, Multidimensional Brainwave Entrainment, ambient soundscape, relaxation",
        quantumEnhanced: true,
        parameters: ["frequency": 432, "binaural": 10, "duration": 600]
    )

    public static let all: [CreativePreset] = [
        .quantumArtist, .fractalExplorer, .ambientComposer, .cyberpunkVision, .meditationMusic
    ]
}

// MARK: - Scientific Presets

public struct ScientificPreset: EnginePreset {
    public let id: UUID
    public var name: String
    public var description: String
    public var category: String
    public var author: String
    public var version: String

    public var visualizationType: ScientificVisualizationType
    public var simulationParameters: [String: Double]
    public var quantumEnabled: Bool
    public var dataGenerator: String?

    public static let quantumFieldExplorer = ScientificPreset(
        id: UUID(),
        name: "Quantum Field Explorer",
        description: "Visualize quantum probability fields",
        category: "Physics",
        author: "Echoelmusic",
        version: "1.0",
        visualizationType: .quantumField,
        simulationParameters: ["resolution": 256, "timestep": 0.01],
        quantumEnabled: true,
        dataGenerator: "quantum"
    )

    public static let waveFunctionCollapse = ScientificPreset(
        id: UUID(),
        name: "Wave Function Collapse",
        description: "Watch quantum states collapse in real-time",
        category: "Physics",
        author: "Echoelmusic",
        version: "1.0",
        visualizationType: .waveFunction,
        simulationParameters: ["qubits": 4, "decoherence": 0.01],
        quantumEnabled: true,
        dataGenerator: nil
    )

    public static let galaxySimulation = ScientificPreset(
        id: UUID(),
        name: "Galaxy Simulation",
        description: "N-body gravitational simulation of stellar systems",
        category: "Astronomy",
        author: "Echoelmusic",
        version: "1.0",
        visualizationType: .galaxySimulation,
        simulationParameters: ["bodies": 1000, "timestep": 0.1],
        quantumEnabled: false,
        dataGenerator: "orbits"
    )

    public static let fluidDynamics = ScientificPreset(
        id: UUID(),
        name: "Fluid Dynamics",
        description: "Navier-Stokes fluid simulation",
        category: "Physics",
        author: "Echoelmusic",
        version: "1.0",
        visualizationType: .vectorField,
        simulationParameters: ["resolution": 128, "viscosity": 0.001],
        quantumEnabled: false,
        dataGenerator: nil
    )

    public static let all: [ScientificPreset] = [
        .quantumFieldExplorer, .waveFunctionCollapse, .galaxySimulation, .fluidDynamics
    ]
}

// MARK: - Wellness Presets

/// Wellness category types for meditation and wellness sessions
public enum WellnessCategory: String, Codable, Sendable {
    case mindfulness = "Mindfulness"
    case relaxation = "Relaxation"
    case focus = "Focus"
    case sleepSupport = "Sleep Support"
    case meditation = "Meditation"
    case energy = "Energy"
}

/// Breathing pattern types for guided breathing exercises
public enum BreathingPattern: String, Codable, Sendable {
    case coherenceBreath = "Coherence Breath"
    case relaxingBreath = "Relaxing Breath"
    case boxBreathing = "Box Breathing"
    case fourSevenEight = "4-7-8 Breath"
    case energizingBreath = "Energizing Breath"

    public var name: String { rawValue }

    public var cycleDuration: Double {
        switch self {
        case .coherenceBreath: return 10
        case .relaxingBreath: return 12
        case .boxBreathing: return 16
        case .fourSevenEight: return 19
        case .energizingBreath: return 6
        }
    }
}

public struct WellnessPreset: EnginePreset {
    public let id: UUID
    public var name: String
    public var description: String
    public var category: String
    public var author: String
    public var version: String

    public var wellnessCategory: WellnessCategory
    public var durationMinutes: Int
    public var breathingPattern: BreathingPattern?
    public var backgroundSounds: [String]
    public var guidedInstructions: Bool

    public static let morningMindfulness = WellnessPreset(
        id: UUID(),
        name: "Morning Mindfulness",
        description: "Start your day with clarity and intention",
        category: "Morning",
        author: "Echoelmusic",
        version: "1.0",
        wellnessCategory: .mindfulness,
        durationMinutes: 10,
        breathingPattern: .coherenceBreath,
        backgroundSounds: ["tibetanBowls"],
        guidedInstructions: true
    )

    public static let deepRelaxation = WellnessPreset(
        id: UUID(),
        name: "Deep Relaxation",
        description: "Release tension and find calm",
        category: "Relaxation",
        author: "Echoelmusic",
        version: "1.0",
        wellnessCategory: .relaxation,
        durationMinutes: 20,
        breathingPattern: .relaxingBreath,
        backgroundSounds: ["oceanWaves", "rain"],
        guidedInstructions: true
    )

    public static let focusSession = WellnessPreset(
        id: UUID(),
        name: "Focus Session",
        description: "Enhance concentration and productivity",
        category: "Focus",
        author: "Echoelmusic",
        version: "1.0",
        wellnessCategory: .focus,
        durationMinutes: 25,
        breathingPattern: .boxBreathing,
        backgroundSounds: ["binaural40Hz"],
        guidedInstructions: false
    )

    public static let sleepPreparation = WellnessPreset(
        id: UUID(),
        name: "Sleep Preparation",
        description: "Wind down for restful sleep",
        category: "Sleep",
        author: "Echoelmusic",
        version: "1.0",
        wellnessCategory: .sleepSupport,
        durationMinutes: 30,
        breathingPattern: .relaxingBreath,
        backgroundSounds: ["pinkNoise", "rain"],
        guidedInstructions: true
    )

    public static let quantumCoherence = WellnessPreset(
        id: UUID(),
        name: "Quantum Coherence",
        description: "Sync with the quantum field for deep meditation",
        category: "Advanced",
        author: "Echoelmusic",
        version: "1.0",
        wellnessCategory: .meditation,
        durationMinutes: 45,
        breathingPattern: .coherenceBreath,
        backgroundSounds: ["quantumHarmonics", "tibetanBowls"],
        guidedInstructions: true
    )

    public static let all: [WellnessPreset] = [
        .morningMindfulness, .deepRelaxation, .focusSession, .sleepPreparation, .quantumCoherence
    ]
}

// MARK: - Collaboration Presets

public struct CollaborationPreset: EnginePreset {
    public let id: UUID
    public var name: String
    public var description: String
    public var category: String
    public var author: String
    public var version: String

    public var mode: CollaborationMode
    public var maxParticipants: Int
    public var quantumSync: Bool
    public var autoRecord: Bool
    public var suggestedDuration: Int // minutes

    public static let musicJamSession = CollaborationPreset(
        id: UUID(),
        name: "Music Jam Session",
        description: "Real-time music collaboration with zero latency",
        category: "Music",
        author: "Echoelmusic",
        version: "1.0",
        mode: .musicJam,
        maxParticipants: 8,
        quantumSync: true,
        autoRecord: true,
        suggestedDuration: 60
    )

    public static let globalMeditation = CollaborationPreset(
        id: UUID(),
        name: "Global Meditation",
        description: "Join meditators worldwide for synchronized coherence",
        category: "Wellness",
        author: "Echoelmusic",
        version: "1.0",
        mode: .groupMeditation,
        maxParticipants: 1000,
        quantumSync: true,
        autoRecord: false,
        suggestedDuration: 30
    )

    public static let artStudio = CollaborationPreset(
        id: UUID(),
        name: "Collaborative Art Studio",
        description: "Create art together in real-time",
        category: "Creative",
        author: "Echoelmusic",
        version: "1.0",
        mode: .artCollaboration,
        maxParticipants: 12,
        quantumSync: false,
        autoRecord: true,
        suggestedDuration: 120
    )

    public static let researchLab = CollaborationPreset(
        id: UUID(),
        name: "Research Lab",
        description: "Collaborative scientific research and analysis",
        category: "Science",
        author: "Echoelmusic",
        version: "1.0",
        mode: .researchSession,
        maxParticipants: 20,
        quantumSync: true,
        autoRecord: true,
        suggestedDuration: 90
    )

    public static let coherenceCircle = CollaborationPreset(
        id: UUID(),
        name: "Coherence Circle",
        description: "Achieve collective quantum coherence",
        category: "Quantum",
        author: "Echoelmusic",
        version: "1.0",
        mode: .coherenceSync,
        maxParticipants: 500,
        quantumSync: true,
        autoRecord: false,
        suggestedDuration: 15
    )

    public static let all: [CollaborationPreset] = [
        .musicJamSession, .globalMeditation, .artStudio, .researchLab, .coherenceCircle
    ]
}

// MARK: - Phase 8000 Preset Manager

@MainActor
public final class Phase8000PresetManager: ObservableObject {
    public static let shared = Phase8000PresetManager()

    @Published public var videoPresets: [Phase8000VideoPreset] = Phase8000VideoPreset.all
    @Published public var creativePresets: [CreativePreset] = CreativePreset.all
    @Published public var scientificPresets: [ScientificPreset] = ScientificPreset.all
    @Published public var wellnessPresets: [WellnessPreset] = WellnessPreset.all
    @Published public var collaborationPresets: [CollaborationPreset] = CollaborationPreset.all

    public var totalPresetCount: Int {
        videoPresets.count + creativePresets.count + scientificPresets.count +
        wellnessPresets.count + collaborationPresets.count
    }

    private init() {}

    public func loadCustomPresets() {
        // Load from UserDefaults or file system
    }

    public func saveCustomPreset<T: EnginePreset>(_ preset: T) {
        // Save to UserDefaults or file system
    }
}

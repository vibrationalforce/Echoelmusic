//
// Preset.swift
// Echoelmusic
//
// Unified preset model for saving/loading complete system state
//

import Foundation
import SwiftUI

/// Complete preset containing all user-configurable settings
struct Preset: Codable, Identifiable, Equatable {

    // MARK: - Properties

    let id: UUID
    var name: String
    var author: String
    var description: String
    var category: PresetCategory
    var tags: [String]
    var isFavorite: Bool
    var isFactory: Bool

    // Settings
    var dspSettings: DSPSettings
    var visualSettings: VisualSettings
    var bioSettings: BioSettings

    // Metadata
    var createdDate: Date
    var modifiedDate: Date
    var version: String

    // CloudKit
    var cloudKitRecordID: String?
    var isShared: Bool
    var shareURL: URL?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        author: String = "User",
        description: String = "",
        category: PresetCategory = .custom,
        tags: [String] = [],
        isFavorite: Bool = false,
        isFactory: Bool = false,
        dspSettings: DSPSettings,
        visualSettings: VisualSettings,
        bioSettings: BioSettings,
        version: String = "1.0.0"
    ) {
        self.id = id
        self.name = name
        self.author = author
        self.description = description
        self.category = category
        self.tags = tags
        self.isFavorite = isFavorite
        self.isFactory = isFactory
        self.dspSettings = dspSettings
        self.visualSettings = visualSettings
        self.bioSettings = bioSettings
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.version = version
    }

    // MARK: - Factory Presets

    static let factoryPresets: [Preset] = [
        Preset.deepRelaxation,
        Preset.energizing,
        Preset.focusMode,
        Preset.meditationJourney,
        Preset.sleepInduction,
        Preset.creativeFlow,
        Preset.anxietyRelief,
        Preset.heartCoherence,
        Preset.breathingSync,
        Preset.morningAwakening,
    ]

    // MARK: - Preset Definitions

    static let deepRelaxation = Preset(
        name: "Deep Relaxation",
        author: "Echoelmusic",
        description: "Calming soundscape that responds to your heart rate, promoting deep relaxation and stress relief",
        category: .relaxation,
        tags: ["relaxation", "stress-relief", "calm", "meditation"],
        isFactory: true,
        dspSettings: DSPSettings(
            filterFrequency: 200.0,
            filterResonance: 0.3,
            reverbMix: 0.6,
            reverbSize: 0.8,
            delayTime: 500.0,
            delayFeedback: 0.4,
            compressorThreshold: -20.0,
            compressorRatio: 2.0,
            bioReactiveIntensity: 0.7
        ),
        visualSettings: VisualSettings(
            visualizerType: .waveform,
            colorScheme: .deepBlue,
            particleCount: .medium,
            animationSpeed: 0.5
        ),
        bioSettings: BioSettings(
            heartRateModulation: 0.8,
            hrvModulation: 0.6,
            breathingModulation: 0.5,
            targetHeartRate: 60.0
        )
    )

    static let energizing = Preset(
        name: "Energizing",
        author: "Echoelmusic",
        description: "Uplifting and dynamic audio that adapts to boost your energy levels",
        category: .energy,
        tags: ["energy", "motivation", "workout", "morning"],
        isFactory: true,
        dspSettings: DSPSettings(
            filterFrequency: 2000.0,
            filterResonance: 0.7,
            reverbMix: 0.3,
            reverbSize: 0.4,
            delayTime: 250.0,
            delayFeedback: 0.3,
            compressorThreshold: -15.0,
            compressorRatio: 4.0,
            bioReactiveIntensity: 0.9
        ),
        visualSettings: VisualSettings(
            visualizerType: .particles,
            colorScheme: .vibrantOrange,
            particleCount: .high,
            animationSpeed: 1.5
        ),
        bioSettings: BioSettings(
            heartRateModulation: 0.9,
            hrvModulation: 0.4,
            breathingModulation: 0.7,
            targetHeartRate: 100.0
        )
    )

    static let focusMode = Preset(
        name: "Focus Mode",
        author: "Echoelmusic",
        description: "Minimal, consistent soundscape designed to enhance concentration and productivity",
        category: .focus,
        tags: ["focus", "productivity", "work", "study"],
        isFactory: true,
        dspSettings: DSPSettings(
            filterFrequency: 500.0,
            filterResonance: 0.4,
            reverbMix: 0.2,
            reverbSize: 0.3,
            delayTime: 375.0,
            delayFeedback: 0.2,
            compressorThreshold: -18.0,
            compressorRatio: 3.0,
            bioReactiveIntensity: 0.5
        ),
        visualSettings: VisualSettings(
            visualizerType: .spectrum,
            colorScheme: .neutralGray,
            particleCount: .low,
            animationSpeed: 0.8
        ),
        bioSettings: BioSettings(
            heartRateModulation: 0.5,
            hrvModulation: 0.7,
            breathingModulation: 0.3,
            targetHeartRate: 75.0
        )
    )

    static let meditationJourney = Preset(
        name: "Meditation Journey",
        author: "Echoelmusic",
        description: "Ethereal soundscape for deep meditation practice with breath synchronization",
        category: .meditation,
        tags: ["meditation", "mindfulness", "spiritual", "breathing"],
        isFactory: true,
        dspSettings: DSPSettings(
            filterFrequency: 150.0,
            filterResonance: 0.2,
            reverbMix: 0.8,
            reverbSize: 0.9,
            delayTime: 750.0,
            delayFeedback: 0.6,
            compressorThreshold: -22.0,
            compressorRatio: 1.5,
            bioReactiveIntensity: 0.6
        ),
        visualSettings: VisualSettings(
            visualizerType: .mandala,
            colorScheme: .purple,
            particleCount: .medium,
            animationSpeed: 0.3
        ),
        bioSettings: BioSettings(
            heartRateModulation: 0.6,
            hrvModulation: 0.8,
            breathingModulation: 0.9,
            targetHeartRate: 55.0
        )
    )

    static let sleepInduction = Preset(
        name: "Sleep Induction",
        author: "Echoelmusic",
        description: "Soothing frequencies designed to guide you into restful sleep",
        category: .sleep,
        tags: ["sleep", "insomnia", "night", "rest"],
        isFactory: true,
        dspSettings: DSPSettings(
            filterFrequency: 100.0,
            filterResonance: 0.1,
            reverbMix: 0.7,
            reverbSize: 1.0,
            delayTime: 1000.0,
            delayFeedback: 0.5,
            compressorThreshold: -25.0,
            compressorRatio: 1.2,
            bioReactiveIntensity: 0.4
        ),
        visualSettings: VisualSettings(
            visualizerType: .waveform,
            colorScheme: .deepPurple,
            particleCount: .low,
            animationSpeed: 0.2
        ),
        bioSettings: BioSettings(
            heartRateModulation: 0.4,
            hrvModulation: 0.9,
            breathingModulation: 0.8,
            targetHeartRate: 50.0
        )
    )

    static let creativeFlow = Preset(
        name: "Creative Flow",
        author: "Echoelmusic",
        description: "Inspiring soundscape that adapts to maintain creative flow state",
        category: .creativity,
        tags: ["creativity", "flow", "artistic", "inspiration"],
        isFactory: true,
        dspSettings: DSPSettings(
            filterFrequency: 800.0,
            filterResonance: 0.6,
            reverbMix: 0.5,
            reverbSize: 0.6,
            delayTime: 400.0,
            delayFeedback: 0.4,
            compressorThreshold: -16.0,
            compressorRatio: 2.5,
            bioReactiveIntensity: 0.7
        ),
        visualSettings: VisualSettings(
            visualizerType: .fractal,
            colorScheme: .rainbow,
            particleCount: .high,
            animationSpeed: 1.0
        ),
        bioSettings: BioSettings(
            heartRateModulation: 0.7,
            hrvModulation: 0.6,
            breathingModulation: 0.5,
            targetHeartRate: 80.0
        )
    )

    static let anxietyRelief = Preset(
        name: "Anxiety Relief",
        author: "Echoelmusic",
        description: "Grounding frequencies to reduce anxiety and promote emotional balance",
        category: .therapeutic,
        tags: ["anxiety", "calm", "grounding", "therapy"],
        isFactory: true,
        dspSettings: DSPSettings(
            filterFrequency: 250.0,
            filterResonance: 0.3,
            reverbMix: 0.5,
            reverbSize: 0.7,
            delayTime: 600.0,
            delayFeedback: 0.3,
            compressorThreshold: -20.0,
            compressorRatio: 2.0,
            bioReactiveIntensity: 0.8
        ),
        visualSettings: VisualSettings(
            visualizerType: .breathingCircle,
            colorScheme: .calmGreen,
            particleCount: .medium,
            animationSpeed: 0.6
        ),
        bioSettings: BioSettings(
            heartRateModulation: 0.9,
            hrvModulation: 0.8,
            breathingModulation: 0.7,
            targetHeartRate: 65.0
        )
    )

    static let heartCoherence = Preset(
        name: "Heart Coherence",
        author: "Echoelmusic",
        description: "Optimized for achieving heart-brain coherence through HRV biofeedback",
        category: .biofeedback,
        tags: ["coherence", "HRV", "biofeedback", "health"],
        isFactory: true,
        dspSettings: DSPSettings(
            filterFrequency: 300.0,
            filterResonance: 0.4,
            reverbMix: 0.4,
            reverbSize: 0.5,
            delayTime: 500.0,
            delayFeedback: 0.3,
            compressorThreshold: -18.0,
            compressorRatio: 2.5,
            bioReactiveIntensity: 1.0
        ),
        visualSettings: VisualSettings(
            visualizerType: .heartRate,
            colorScheme: .heartRed,
            particleCount: .medium,
            animationSpeed: 0.7
        ),
        bioSettings: BioSettings(
            heartRateModulation: 1.0,
            hrvModulation: 1.0,
            breathingModulation: 0.8,
            targetHeartRate: 70.0
        )
    )

    static let breathingSync = Preset(
        name: "Breathing Sync",
        author: "Echoelmusic",
        description: "Audio synchronized to optimal breathing patterns for relaxation",
        category: .breathing,
        tags: ["breathing", "pranayama", "relaxation", "technique"],
        isFactory: true,
        dspSettings: DSPSettings(
            filterFrequency: 400.0,
            filterResonance: 0.5,
            reverbMix: 0.6,
            reverbSize: 0.6,
            delayTime: 450.0,
            delayFeedback: 0.4,
            compressorThreshold: -19.0,
            compressorRatio: 2.0,
            bioReactiveIntensity: 0.7
        ),
        visualSettings: VisualSettings(
            visualizerType: .breathingCircle,
            colorScheme: .breathBlue,
            particleCount: .low,
            animationSpeed: 0.4
        ),
        bioSettings: BioSettings(
            heartRateModulation: 0.6,
            hrvModulation: 0.7,
            breathingModulation: 1.0,
            targetHeartRate: 60.0
        )
    )

    static let morningAwakening = Preset(
        name: "Morning Awakening",
        author: "Echoelmusic",
        description: "Gentle, progressive stimulation to ease into wakefulness",
        category: .energy,
        tags: ["morning", "wake-up", "gentle", "sunrise"],
        isFactory: true,
        dspSettings: DSPSettings(
            filterFrequency: 1000.0,
            filterResonance: 0.6,
            reverbMix: 0.3,
            reverbSize: 0.4,
            delayTime: 300.0,
            delayFeedback: 0.2,
            compressorThreshold: -17.0,
            compressorRatio: 3.0,
            bioReactiveIntensity: 0.6
        ),
        visualSettings: VisualSettings(
            visualizerType: .spectrum,
            colorScheme: .sunrise,
            particleCount: .medium,
            animationSpeed: 1.0
        ),
        bioSettings: BioSettings(
            heartRateModulation: 0.7,
            hrvModulation: 0.5,
            breathingModulation: 0.6,
            targetHeartRate: 85.0
        )
    )
}

// MARK: - Supporting Types

enum PresetCategory: String, Codable, CaseIterable {
    case relaxation = "Relaxation"
    case energy = "Energy"
    case focus = "Focus"
    case meditation = "Meditation"
    case sleep = "Sleep"
    case creativity = "Creativity"
    case therapeutic = "Therapeutic"
    case biofeedback = "Biofeedback"
    case breathing = "Breathing"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .relaxation: return "wind"
        case .energy: return "bolt.fill"
        case .focus: return "eye.fill"
        case .meditation: return "brain.head.profile"
        case .sleep: return "moon.stars.fill"
        case .creativity: return "paintbrush.fill"
        case .therapeutic: return "heart.text.square.fill"
        case .biofeedback: return "waveform.path.ecg"
        case .breathing: return "lungs.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
}

struct DSPSettings: Codable, Equatable {
    var filterFrequency: Double
    var filterResonance: Double
    var reverbMix: Double
    var reverbSize: Double
    var delayTime: Double
    var delayFeedback: Double
    var compressorThreshold: Double
    var compressorRatio: Double
    var bioReactiveIntensity: Double
}

struct VisualSettings: Codable, Equatable {
    var visualizerType: VisualizerType
    var colorScheme: ColorSchemeType
    var particleCount: ParticleCount
    var animationSpeed: Double
}

struct BioSettings: Codable, Equatable {
    var heartRateModulation: Double
    var hrvModulation: Double
    var breathingModulation: Double
    var targetHeartRate: Double
}

enum VisualizerType: String, Codable {
    case waveform, spectrum, particles, mandala, fractal, breathingCircle, heartRate
}

enum ColorSchemeType: String, Codable {
    case deepBlue, vibrantOrange, neutralGray, purple, deepPurple
    case rainbow, calmGreen, heartRed, breathBlue, sunrise
}

enum ParticleCount: String, Codable {
    case low, medium, high
}

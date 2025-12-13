import Foundation

/// Bio-Mapping Presets System
/// Defines preset configurations for different bio-reactive music experiences
/// Each preset maps biometric parameters to audio/visual parameters optimally

// MARK: - Preset Definitions

/// Bio-mapping preset with full parameter configuration
struct BioMappingPreset: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: PresetCategory
    let description: String
    let icon: String

    // Parameter mappings
    let hrvToReverbRange: ClosedRange<Float>
    let heartRateToFilterRange: ClosedRange<Float>
    let coherenceToAmplitudeRange: ClosedRange<Float>
    let baseFrequency: Float
    let tempoRange: ClosedRange<Float>
    let harmonicProfile: HarmonicProfile
    let spatialMode: SpatialMappingMode
    let visualMode: String

    // Binaural beat configuration
    let binauralBaseFrequency: Float
    let binauralBeatFrequency: Float
    let binauralState: BinauralState

    init(
        name: String,
        category: PresetCategory,
        description: String,
        icon: String,
        hrvToReverbRange: ClosedRange<Float> = 0.1...0.8,
        heartRateToFilterRange: ClosedRange<Float> = 200...2000,
        coherenceToAmplitudeRange: ClosedRange<Float> = 0.3...0.8,
        baseFrequency: Float = 432.0,
        tempoRange: ClosedRange<Float> = 4...8,
        harmonicProfile: HarmonicProfile = .balanced,
        spatialMode: SpatialMappingMode = .centered,
        visualMode: String = "mandala",
        binauralBaseFrequency: Float = 200,
        binauralBeatFrequency: Float = 10,
        binauralState: BinauralState = .alpha
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.description = description
        self.icon = icon
        self.hrvToReverbRange = hrvToReverbRange
        self.heartRateToFilterRange = heartRateToFilterRange
        self.coherenceToAmplitudeRange = coherenceToAmplitudeRange
        self.baseFrequency = baseFrequency
        self.tempoRange = tempoRange
        self.harmonicProfile = harmonicProfile
        self.spatialMode = spatialMode
        self.visualMode = visualMode
        self.binauralBaseFrequency = binauralBaseFrequency
        self.binauralBeatFrequency = binauralBeatFrequency
        self.binauralState = binauralState
    }
}

// MARK: - Supporting Types

enum PresetCategory: String, Codable, CaseIterable {
    case meditation = "Meditation"
    case healing = "Healing"
    case focus = "Focus"
    case creative = "Creative"
    case relaxation = "Relaxation"
    case energizing = "Energizing"
    case sleep = "Sleep"
    case custom = "Custom"
}

enum HarmonicProfile: String, Codable, CaseIterable {
    case minimal = "Minimal"      // 2-3 harmonics
    case balanced = "Balanced"    // 5 harmonics
    case rich = "Rich"            // 7+ harmonics
    case pure = "Pure"            // Sine wave only
    case overtone = "Overtone"    // Enhanced odd harmonics
}

enum SpatialMappingMode: String, Codable, CaseIterable {
    case centered = "Centered"          // Audio stays centered
    case orbital = "Orbital"            // Rotates around listener
    case breathing = "Breathing"        // Expands/contracts with breath
    case coherenceResponsive = "Coherence"  // Moves based on coherence
    case immersive = "Immersive"        // Full 3D field
}

enum BinauralState: String, Codable, CaseIterable {
    case delta = "Delta"      // 0.5-4 Hz - Deep sleep
    case theta = "Theta"      // 4-8 Hz - Meditation, creativity
    case alpha = "Alpha"      // 8-12 Hz - Relaxation, light meditation
    case beta = "Beta"        // 12-30 Hz - Focus, alertness
    case gamma = "Gamma"      // 30-100 Hz - Peak performance
}

// MARK: - Preset Library

/// Library of predefined bio-mapping presets
class BioMappingPresetLibrary {

    static let shared = BioMappingPresetLibrary()

    /// All available presets
    let presets: [BioMappingPreset]

    private init() {
        self.presets = Self.createDefaultPresets()
    }

    /// Get presets by category
    func presets(for category: PresetCategory) -> [BioMappingPreset] {
        presets.filter { $0.category == category }
    }

    /// Get preset by name
    func preset(named name: String) -> BioMappingPreset? {
        presets.first { $0.name == name }
    }

    // MARK: - Default Presets

    private static func createDefaultPresets() -> [BioMappingPreset] {
        return [
            // MEDITATION PRESETS
            BioMappingPreset(
                name: "Deep Meditation",
                category: .meditation,
                description: "Theta waves for deep meditative states with expanded reverb",
                icon: "leaf.fill",
                hrvToReverbRange: 0.5...0.9,
                heartRateToFilterRange: 150...600,
                coherenceToAmplitudeRange: 0.3...0.6,
                baseFrequency: 432.0,
                tempoRange: 3...5,
                harmonicProfile: .pure,
                spatialMode: .breathing,
                visualMode: "mandala",
                binauralBaseFrequency: 200,
                binauralBeatFrequency: 6,
                binauralState: .theta
            ),

            BioMappingPreset(
                name: "Mindfulness",
                category: .meditation,
                description: "Alpha waves for present-moment awareness",
                icon: "sparkles",
                hrvToReverbRange: 0.3...0.7,
                heartRateToFilterRange: 300...1000,
                coherenceToAmplitudeRange: 0.4...0.7,
                baseFrequency: 528.0,
                tempoRange: 4...6,
                harmonicProfile: .balanced,
                spatialMode: .centered,
                visualMode: "cymatics",
                binauralBaseFrequency: 200,
                binauralBeatFrequency: 10,
                binauralState: .alpha
            ),

            // HEALING PRESETS
            BioMappingPreset(
                name: "Heart Coherence",
                category: .healing,
                description: "Optimized for HeartMath coherence building with 528Hz love frequency",
                icon: "heart.fill",
                hrvToReverbRange: 0.4...0.8,
                heartRateToFilterRange: 200...800,
                coherenceToAmplitudeRange: 0.4...0.8,
                baseFrequency: 528.0,
                tempoRange: 5...7,
                harmonicProfile: .rich,
                spatialMode: .coherenceResponsive,
                visualMode: "heartCoherenceMandala",
                binauralBaseFrequency: 264,
                binauralBeatFrequency: 8,
                binauralState: .alpha
            ),

            BioMappingPreset(
                name: "Chakra Balancing",
                category: .healing,
                description: "396Hz root frequency for grounding and release",
                icon: "circle.hexagongrid.fill",
                hrvToReverbRange: 0.5...0.85,
                heartRateToFilterRange: 150...500,
                coherenceToAmplitudeRange: 0.3...0.7,
                baseFrequency: 396.0,
                tempoRange: 4...6,
                harmonicProfile: .overtone,
                spatialMode: .immersive,
                visualMode: "sacredGeometry",
                binauralBaseFrequency: 198,
                binauralBeatFrequency: 7,
                binauralState: .theta
            ),

            // FOCUS PRESETS
            BioMappingPreset(
                name: "Deep Focus",
                category: .focus,
                description: "Beta waves for concentration and productivity",
                icon: "brain.head.profile",
                hrvToReverbRange: 0.1...0.4,
                heartRateToFilterRange: 800...2500,
                coherenceToAmplitudeRange: 0.5...0.8,
                baseFrequency: 741.0,
                tempoRange: 6...8,
                harmonicProfile: .minimal,
                spatialMode: .centered,
                visualMode: "brainwave",
                binauralBaseFrequency: 300,
                binauralBeatFrequency: 18,
                binauralState: .beta
            ),

            BioMappingPreset(
                name: "Flow State",
                category: .focus,
                description: "Alpha-Theta border for creative flow",
                icon: "wand.and.stars",
                hrvToReverbRange: 0.3...0.6,
                heartRateToFilterRange: 500...1500,
                coherenceToAmplitudeRange: 0.5...0.8,
                baseFrequency: 639.0,
                tempoRange: 5...7,
                harmonicProfile: .balanced,
                spatialMode: .orbital,
                visualMode: "waveform",
                binauralBaseFrequency: 250,
                binauralBeatFrequency: 10,
                binauralState: .alpha
            ),

            // CREATIVE PRESETS
            BioMappingPreset(
                name: "Creative Inspiration",
                category: .creative,
                description: "Theta waves for enhanced creativity and imagination",
                icon: "paintbrush.fill",
                hrvToReverbRange: 0.4...0.8,
                heartRateToFilterRange: 400...1200,
                coherenceToAmplitudeRange: 0.4...0.8,
                baseFrequency: 639.0,
                tempoRange: 4...7,
                harmonicProfile: .rich,
                spatialMode: .orbital,
                visualMode: "particles",
                binauralBaseFrequency: 220,
                binauralBeatFrequency: 6,
                binauralState: .theta
            ),

            BioMappingPreset(
                name: "Sonic Explorer",
                category: .creative,
                description: "Full parameter range for experimental sound design",
                icon: "waveform.path.ecg",
                hrvToReverbRange: 0.1...0.95,
                heartRateToFilterRange: 100...4000,
                coherenceToAmplitudeRange: 0.2...0.9,
                baseFrequency: 432.0,
                tempoRange: 2...12,
                harmonicProfile: .rich,
                spatialMode: .immersive,
                visualMode: "spectral",
                binauralBaseFrequency: 150,
                binauralBeatFrequency: 4,
                binauralState: .theta
            ),

            // RELAXATION PRESETS
            BioMappingPreset(
                name: "Deep Relaxation",
                category: .relaxation,
                description: "Alpha waves for stress relief and calm",
                icon: "cloud.fill",
                hrvToReverbRange: 0.6...0.9,
                heartRateToFilterRange: 150...500,
                coherenceToAmplitudeRange: 0.3...0.6,
                baseFrequency: 432.0,
                tempoRange: 3...5,
                harmonicProfile: .pure,
                spatialMode: .breathing,
                visualMode: "mandala",
                binauralBaseFrequency: 200,
                binauralBeatFrequency: 10,
                binauralState: .alpha
            ),

            // ENERGIZING PRESETS
            BioMappingPreset(
                name: "Morning Energy",
                category: .energizing,
                description: "Beta-Gamma for alertness and motivation",
                icon: "sun.max.fill",
                hrvToReverbRange: 0.1...0.3,
                heartRateToFilterRange: 1000...3000,
                coherenceToAmplitudeRange: 0.6...0.9,
                baseFrequency: 852.0,
                tempoRange: 7...10,
                harmonicProfile: .overtone,
                spatialMode: .immersive,
                visualMode: "particles",
                binauralBaseFrequency: 400,
                binauralBeatFrequency: 35,
                binauralState: .gamma
            ),

            // SLEEP PRESETS
            BioMappingPreset(
                name: "Sleep Preparation",
                category: .sleep,
                description: "Delta waves for deep sleep induction",
                icon: "moon.fill",
                hrvToReverbRange: 0.7...0.95,
                heartRateToFilterRange: 100...300,
                coherenceToAmplitudeRange: 0.2...0.4,
                baseFrequency: 396.0,
                tempoRange: 2...4,
                harmonicProfile: .pure,
                spatialMode: .breathing,
                visualMode: "mandala",
                binauralBaseFrequency: 100,
                binauralBeatFrequency: 2,
                binauralState: .delta
            )
        ]
    }
}

// MARK: - Preset Application

extension BioMappingPreset {

    /// Apply this preset to a BioParameterMapper
    @MainActor
    func apply(to mapper: BioParameterMapper) {
        // Set base parameters
        mapper.reverbWet = (hrvToReverbRange.lowerBound + hrvToReverbRange.upperBound) / 2
        mapper.filterCutoff = (heartRateToFilterRange.lowerBound + heartRateToFilterRange.upperBound) / 2
        mapper.amplitude = (coherenceToAmplitudeRange.lowerBound + coherenceToAmplitudeRange.upperBound) / 2
        mapper.baseFrequency = baseFrequency
        mapper.tempo = (tempoRange.lowerBound + tempoRange.upperBound) / 2

        // Set harmonic count based on profile
        switch harmonicProfile {
        case .minimal:
            mapper.harmonicCount = 3
        case .balanced:
            mapper.harmonicCount = 5
        case .rich:
            mapper.harmonicCount = 7
        case .pure:
            mapper.harmonicCount = 1
        case .overtone:
            mapper.harmonicCount = 9
        }

        print("🎛️ Applied preset: \(name)")
    }

    /// Get mapped reverb value from HRV coherence
    func mapHRVToReverb(_ hrvCoherence: Double) -> Float {
        let normalized = Float(hrvCoherence / 100.0)
        return hrvToReverbRange.lowerBound + normalized * (hrvToReverbRange.upperBound - hrvToReverbRange.lowerBound)
    }

    /// Get mapped filter cutoff from heart rate
    func mapHeartRateToFilter(_ heartRate: Double) -> Float {
        let normalized = Float((heartRate - 40.0) / 80.0).clamped(to: 0...1)
        return heartRateToFilterRange.lowerBound + normalized * (heartRateToFilterRange.upperBound - heartRateToFilterRange.lowerBound)
    }

    /// Get mapped amplitude from coherence
    func mapCoherenceToAmplitude(_ coherence: Double) -> Float {
        let normalized = Float(coherence / 100.0)
        return coherenceToAmplitudeRange.lowerBound + normalized * (coherenceToAmplitudeRange.upperBound - coherenceToAmplitudeRange.lowerBound)
    }
}

// MARK: - Float Extension

extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

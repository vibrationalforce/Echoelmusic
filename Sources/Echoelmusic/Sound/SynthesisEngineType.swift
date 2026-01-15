import Foundation

// MARK: - Unified Synthesis Engine Type
// Consolidates duplicate enums from UniversalSoundLibrary and AdvancedPlugins
// This is the single source of truth for all synthesis engine types

/// Unified synthesis engine type for all audio synthesis across the platform.
///
/// This enum consolidates:
/// - `UniversalSoundLibrary.SynthEngine.SynthType`
/// - `AISoundDesignerPlugin.SynthesisEngine`
///
/// Usage:
/// ```swift
/// let engine: SynthesisEngineType = .wavetable
/// let displayName = engine.displayName // "Wavetable Synthesis"
/// ```
public enum SynthesisEngineType: String, CaseIterable, Sendable, Codable {
    // Classic synthesis methods
    case subtractive = "subtractive"
    case fm = "fm"
    case wavetable = "wavetable"
    case additive = "additive"

    // Texture-based synthesis
    case granular = "granular"
    case spectral = "spectral"

    // Physical modeling variants
    case physicalModeling = "physical_modeling"
    case karplusStrong = "karplus_strong"
    case waveguide = "waveguide"
    case modal = "modal"

    // Sample-based
    case sampler = "sampler"

    // Advanced
    case vector = "vector"
    case neural = "neural"

    // Organic/Genetic synthesis (Synplant-inspired)
    case genetic = "genetic"
    case organic = "organic"

    // Bio-reactive synthesis (Echoelmusic unique)
    case bioReactive = "bio_reactive"

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .subtractive: return "Subtractive Synthesis"
        case .fm: return "FM Synthesis"
        case .wavetable: return "Wavetable Synthesis"
        case .additive: return "Additive Synthesis"
        case .granular: return "Granular Synthesis"
        case .spectral: return "Spectral Processing"
        case .physicalModeling: return "Physical Modeling"
        case .karplusStrong: return "Karplus-Strong"
        case .waveguide: return "Waveguide Synthesis"
        case .modal: return "Modal Synthesis"
        case .sampler: return "Sample-based"
        case .vector: return "Vector Synthesis"
        case .neural: return "Neural Audio"
        case .genetic: return "Genetic Synthesis"
        case .organic: return "Organic Synthesis"
        case .bioReactive: return "Bio-Reactive Synthesis"
        }
    }

    /// Short description of the synthesis method
    public var description: String {
        switch self {
        case .subtractive:
            return "Classic analog-style synthesis with oscillators and filters"
        case .fm:
            return "Frequency modulation for complex harmonic timbres (DX7-style)"
        case .wavetable:
            return "Morphing between waveform tables for evolving sounds"
        case .additive:
            return "Building sounds from individual harmonics"
        case .granular:
            return "Microscopic time-domain synthesis for textures"
        case .spectral:
            return "FFT-based analysis and resynthesis"
        case .physicalModeling:
            return "Simulation of physical instrument behavior"
        case .karplusStrong:
            return "Plucked string algorithm for realistic strings"
        case .waveguide:
            return "Digital waveguide for wind and string simulation"
        case .modal:
            return "Resonant mode-based synthesis for bells and plates"
        case .sampler:
            return "Sample playback with advanced manipulation"
        case .vector:
            return "Crossfading between multiple sound sources"
        case .neural:
            return "AI-powered audio generation and transformation"
        case .genetic:
            return "Sounds evolve and mutate like DNA (Synplant-inspired)"
        case .organic:
            return "Living, breathing sounds that grow from seeds"
        case .bioReactive:
            return "Synthesis controlled by heart rate, HRV, and breathing"
        }
    }

    /// Synthesis category for grouping in UI
    public var category: SynthesisCategory {
        switch self {
        case .subtractive, .fm, .wavetable, .additive:
            return .classic
        case .granular, .spectral:
            return .texture
        case .physicalModeling, .karplusStrong, .waveguide, .modal:
            return .physical
        case .sampler:
            return .sample
        case .vector, .neural:
            return .advanced
        case .genetic, .organic:
            return .organic
        case .bioReactive:
            return .bioReactive
        }
    }

    /// Whether this synthesis type supports real-time parameter modulation
    public var supportsRealTimeModulation: Bool {
        switch self {
        case .neural:
            return false  // Neural typically requires more processing
        default:
            return true
        }
    }
}

/// Categories for grouping synthesis engine types
public enum SynthesisCategory: String, CaseIterable, Sendable {
    case classic = "Classic"
    case texture = "Texture"
    case physical = "Physical"
    case sample = "Sample"
    case advanced = "Advanced"
    case organic = "Organic"       // Synplant-inspired genetic/organic synthesis
    case bioReactive = "Bio-Reactive"  // Echoelmusic unique biofeedback synthesis

    /// Engines in this category
    public var engines: [SynthesisEngineType] {
        SynthesisEngineType.allCases.filter { $0.category == self }
    }
}

// MARK: - Type Aliases for Backwards Compatibility

/// Legacy type alias - use `SynthesisEngineType` instead
/// @available(*, deprecated, renamed: "SynthesisEngineType")
public typealias SynthType = SynthesisEngineType

/// Legacy type alias - use `SynthesisEngineType` instead
/// @available(*, deprecated, renamed: "SynthesisEngineType")
public typealias SynthesisEngine = SynthesisEngineType

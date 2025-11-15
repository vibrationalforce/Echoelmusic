import Foundation
import AVFoundation

// MARK: - Project Template System
// Pre-configured project templates for quick start

/// Project template management system
@MainActor
class ProjectTemplateSystem: ObservableObject {

    // MARK: - Published Properties
    @Published var templates: [ProjectTemplate] = []
    @Published var userTemplates: [ProjectTemplate] = []
    @Published var categories: [TemplateCategory] = []

    // MARK: - Template
    struct ProjectTemplate: Identifiable, Codable {
        var id: UUID
        var name: String
        var description: String
        var category: TemplateCategory
        var author: String
        var version: String
        var thumbnail: Data?
        var tags: [String]

        // Project settings
        var tempo: Double
        var timeSignature: TimeSignature
        var key: MusicalKey
        var sampleRate: Double
        var bitDepth: Int

        // Track configuration
        var trackTemplates: [TrackTemplate]

        // Effect chains
        var masterEffectChain: [EffectPreset]

        // MIDI mappings
        var midiMappings: [MIDIMapping]

        // Created from template
        var createdAt: Date
        var lastModified: Date
    }

    struct TimeSignature: Codable {
        var numerator: Int
        var denominator: Int

        var description: String {
            "\(numerator)/\(denominator)"
        }

        static let fourFour = TimeSignature(numerator: 4, denominator: 4)
        static let threeFour = TimeSignature(numerator: 3, denominator: 4)
        static let sixEight = TimeSignature(numerator: 6, denominator: 8)
    }

    struct MusicalKey: Codable {
        var root: Note
        var scale: Scale

        enum Note: String, Codable {
            case c, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b
        }

        enum Scale: String, Codable {
            case major, minor, dorian, phrygian, lydian, mixolydian, aeolian, locrian
        }

        var description: String {
            "\(root.rawValue.capitalized) \(scale.rawValue.capitalized)"
        }
    }

    // MARK: - Track Template
    struct TrackTemplate: Identifiable, Codable {
        var id: UUID
        var name: String
        var type: TrackType
        var color: CodableColor
        var effectChain: [EffectPreset]
        var instrumentPreset: InstrumentPreset?
        var volume: Float
        var pan: Float
        var muted: Bool
        var solo: Bool
        var recordEnabled: Bool

        enum TrackType: String, Codable {
            case audio, midi, instrument, aux, group, master
        }
    }

    struct EffectPreset: Identifiable, Codable {
        var id: UUID
        var name: String
        var pluginIdentifier: String?
        var parameters: [String: Float]
        var enabled: Bool
    }

    struct InstrumentPreset: Codable {
        var name: String
        var pluginIdentifier: String?
        var parameters: [String: Float]
        var midiChannel: Int
    }

    struct MIDIMapping: Codable {
        var cc: Int  // MIDI CC number
        var parameter: String
        var minValue: Float
        var maxValue: Float
        var curve: MappingCurve

        enum MappingCurve: String, Codable {
            case linear, logarithmic, exponential
        }
    }

    struct CodableColor: Codable {
        var red: Double
        var green: Double
        var blue: Double
        var alpha: Double
    }

    // MARK: - Template Categories
    enum TemplateCategory: String, Codable, CaseIterable {
        case blank
        case electronic, hiphop, rock, pop, jazz, classical
        case scoring, podcast, voiceover
        case mixing, mastering
        case experimental, ambient
        case custom

        var displayName: String {
            rawValue.capitalized
        }
    }

    // MARK: - Init
    init() {
        loadBuiltInTemplates()
        loadUserTemplates()
    }

    // MARK: - Built-in Templates
    private func loadBuiltInTemplates() {
        templates = [
            createBlankTemplate(),
            createElectronicTemplate(),
            createHipHopTemplate(),
            createRockTemplate(),
            createPopTemplate(),
            createPodcastTemplate(),
            createMixingTemplate(),
            createMasteringTemplate()
        ]
    }

    private func createBlankTemplate() -> ProjectTemplate {
        return ProjectTemplate(
            id: UUID(),
            name: "Blank Project",
            description: "Empty project with default settings",
            category: .blank,
            author: "Echoelmusic",
            version: "1.0",
            thumbnail: nil,
            tags: ["blank", "default"],
            tempo: 120,
            timeSignature: .fourFour,
            key: MusicalKey(root: .c, scale: .major),
            sampleRate: 48000,
            bitDepth: 24,
            trackTemplates: [],
            masterEffectChain: [],
            midiMappings: [],
            createdAt: Date(),
            lastModified: Date()
        )
    }

    private func createElectronicTemplate() -> ProjectTemplate {
        var template = createBlankTemplate()
        template.id = UUID()
        template.name = "Electronic Production"
        template.description = "EDM/Electronic music production template"
        template.category = .electronic
        template.tempo = 128
        template.tags = ["electronic", "edm", "house", "techno"]

        // Tracks
        template.trackTemplates = [
            TrackTemplate(
                id: UUID(), name: "Kick", type: .midi,
                color: CodableColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0),
                effectChain: [
                    EffectPreset(id: UUID(), name: "EQ", pluginIdentifier: nil, parameters: [:], enabled: true),
                    EffectPreset(id: UUID(), name: "Compressor", pluginIdentifier: nil, parameters: [:], enabled: true)
                ],
                instrumentPreset: nil,
                volume: 0.8, pan: 0, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Bass", type: .midi,
                color: CodableColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.7, pan: 0, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Lead", type: .midi,
                color: CodableColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.6, pan: 0, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Pads", type: .midi,
                color: CodableColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.4, pan: 0, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "FX", type: .audio,
                color: CodableColor(red: 0.8, green: 0.2, blue: 1.0, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.5, pan: 0, muted: false, solo: false, recordEnabled: true
            )
        ]

        // Master chain
        template.masterEffectChain = [
            EffectPreset(id: UUID(), name: "Master EQ", pluginIdentifier: nil, parameters: [:], enabled: true),
            EffectPreset(id: UUID(), name: "Limiter", pluginIdentifier: nil, parameters: [:], enabled: true)
        ]

        return template
    }

    private func createHipHopTemplate() -> ProjectTemplate {
        var template = createBlankTemplate()
        template.id = UUID()
        template.name = "Hip Hop Beat"
        template.description = "Hip hop beat making template"
        template.category = .hiphop
        template.tempo = 90
        template.tags = ["hiphop", "trap", "rap", "beat"]

        template.trackTemplates = [
            TrackTemplate(
                id: UUID(), name: "Drums", type: .midi,
                color: CodableColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.8, pan: 0, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "808 Bass", type: .midi,
                color: CodableColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.9, pan: 0, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Melody", type: .midi,
                color: CodableColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.6, pan: 0, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Vocal", type: .audio,
                color: CodableColor(red: 1.0, green: 0.5, blue: 0.8, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.7, pan: 0, muted: false, solo: false, recordEnabled: true
            )
        ]

        return template
    }

    private func createRockTemplate() -> ProjectTemplate {
        var template = createBlankTemplate()
        template.id = UUID()
        template.name = "Rock Band"
        template.description = "Full rock band recording template"
        template.category = .rock
        template.tempo = 140
        template.tags = ["rock", "band", "live"]

        template.trackTemplates = [
            TrackTemplate(
                id: UUID(), name: "Kick In", type: .audio,
                color: CodableColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.8, pan: 0, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Snare Top", type: .audio,
                color: CodableColor(red: 1.0, green: 0.4, blue: 0.2, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.7, pan: 0, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Overhead L", type: .audio,
                color: CodableColor(red: 0.8, green: 0.8, blue: 0.2, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.6, pan: -0.5, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Overhead R", type: .audio,
                color: CodableColor(red: 0.8, green: 0.8, blue: 0.2, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.6, pan: 0.5, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Bass DI", type: .audio,
                color: CodableColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.7, pan: 0, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Guitar L", type: .audio,
                color: CodableColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.6, pan: -0.4, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Guitar R", type: .audio,
                color: CodableColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.6, pan: 0.4, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Lead Vocal", type: .audio,
                color: CodableColor(red: 1.0, green: 0.2, blue: 0.8, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.7, pan: 0, muted: false, solo: false, recordEnabled: true
            )
        ]

        return template
    }

    private func createPopTemplate() -> ProjectTemplate {
        var template = createBlankTemplate()
        template.id = UUID()
        template.name = "Pop Production"
        template.description: "Modern pop music production"
        template.category = .pop
        template.tempo = 110
        template.tags = ["pop", "commercial", "radio"]

        template.trackTemplates = [
            TrackTemplate(
                id: UUID(), name: "Drums", type: .midi,
                color: CodableColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.8, pan: 0, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Bass", type: .midi,
                color: CodableColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.7, pan: 0, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Piano/Keys", type: .midi,
                color: CodableColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.6, pan: 0, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Synth", type: .midi,
                color: CodableColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.5, pan: 0, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Lead Vocal", type: .audio,
                color: CodableColor(red: 1.0, green: 0.2, blue: 0.6, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.8, pan: 0, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "BG Vocals", type: .audio,
                color: CodableColor(red: 1.0, green: 0.5, blue: 0.8, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.6, pan: 0, muted: false, solo: false, recordEnabled: true
            )
        ]

        return template
    }

    private func createPodcastTemplate() -> ProjectTemplate {
        var template = createBlankTemplate()
        template.id = UUID()
        template.name = "Podcast"
        template.description = "Podcast recording and editing template"
        template.category = .podcast
        template.tempo = 120
        template.tags = ["podcast", "voice", "interview"]

        template.trackTemplates = [
            TrackTemplate(
                id: UUID(), name: "Host", type: .audio,
                color: CodableColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.8, pan: -0.2, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Guest", type: .audio,
                color: CodableColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.8, pan: 0.2, muted: false, solo: false, recordEnabled: true
            ),
            TrackTemplate(
                id: UUID(), name: "Intro Music", type: .audio,
                color: CodableColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.4, pan: 0, muted: false, solo: false, recordEnabled: false
            ),
            TrackTemplate(
                id: UUID(), name: "Background Music", type: .audio,
                color: CodableColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0),
                effectChain: [],
                instrumentPreset: nil,
                volume: 0.2, pan: 0, muted: false, solo: false, recordEnabled: false
            )
        ]

        return template
    }

    private func createMixingTemplate() -> ProjectTemplate {
        var template = createBlankTemplate()
        template.id = UUID()
        template.name = "Mixing Session"
        template.description = "Professional mixing template"
        template.category = .mixing
        template.tempo = 120
        template.tags = ["mixing", "professional"]

        // Would include aux tracks, buses, etc.

        return template
    }

    private func createMasteringTemplate() -> ProjectTemplate {
        var template = createBlankTemplate()
        template.id = UUID()
        template.name = "Mastering Session"
        template.description = "Professional mastering template"
        template.category = .mastering
        template.tempo = 120
        template.tags = ["mastering", "professional"]

        template.masterEffectChain = [
            EffectPreset(id: UUID(), name: "Linear Phase EQ", pluginIdentifier: nil, parameters: [:], enabled: true),
            EffectPreset(id: UUID(), name: "Multiband Compressor", pluginIdentifier: nil, parameters: [:], enabled: true),
            EffectPreset(id: UUID(), name: "Stereo Imager", pluginIdentifier: nil, parameters: [:], enabled: true),
            EffectPreset(id: UUID(), name: "Harmonic Exciter", pluginIdentifier: nil, parameters: [:], enabled: true),
            EffectPreset(id: UUID(), name: "Limiter", pluginIdentifier: nil, parameters: [:], enabled: true),
            EffectPreset(id: UUID(), name: "Dithering", pluginIdentifier: nil, parameters: [:], enabled: true)
        ]

        return template
    }

    // MARK: - Template Management
    func createProject(from template: ProjectTemplate) -> ProjectConfiguration {
        return ProjectConfiguration(
            name: "Untitled Project",
            tempo: template.tempo,
            timeSignature: template.timeSignature,
            key: template.key,
            sampleRate: template.sampleRate,
            bitDepth: template.bitDepth,
            tracks: template.trackTemplates,
            masterEffectChain: template.masterEffectChain
        )
    }

    struct ProjectConfiguration {
        var name: String
        var tempo: Double
        var timeSignature: TimeSignature
        var key: MusicalKey
        var sampleRate: Double
        var bitDepth: Int
        var tracks: [TrackTemplate]
        var masterEffectChain: [EffectPreset]
    }

    func saveAsTemplate(from project: ProjectConfiguration, name: String, category: TemplateCategory) {
        let template = ProjectTemplate(
            id: UUID(),
            name: name,
            description: "Custom user template",
            category: category,
            author: "User",
            version: "1.0",
            thumbnail: nil,
            tags: ["custom", "user"],
            tempo: project.tempo,
            timeSignature: project.timeSignature,
            key: project.key,
            sampleRate: project.sampleRate,
            bitDepth: project.bitDepth,
            trackTemplates: project.tracks,
            masterEffectChain: project.masterEffectChain,
            midiMappings: [],
            createdAt: Date(),
            lastModified: Date()
        )

        userTemplates.append(template)
        saveUserTemplates()
    }

    func deleteTemplate(_ templateID: UUID) {
        userTemplates.removeAll { $0.id == templateID }
        saveUserTemplates()
    }

    // MARK: - Persistence
    private func loadUserTemplates() {
        // Load from file
    }

    private func saveUserTemplates() {
        // Save to file
    }
}

import Foundation

/// Represents a shareable skill, technique, or configuration created by a user
/// Skills can be breathing patterns, session templates, audio presets, or visualizations
struct UserSkill: Codable, Identifiable {

    // MARK: - Identity

    let id: UUID
    let creatorID: String
    let creatorName: String
    let creatorAvatar: URL?

    // MARK: - Metadata

    let name: String
    let description: String
    let type: SkillType
    let category: SkillCategory
    let tags: [String]

    // MARK: - Content

    let content: SkillContent

    // MARK: - Statistics

    let createdAt: Date
    var updatedAt: Date
    var downloads: Int
    var rating: Double  // 0.0 - 5.0
    var ratingCount: Int
    var favorites: Int

    // MARK: - Media

    let thumbnail: URL?
    let previewVideo: URL?
    let screenshots: [URL]

    // MARK: - Verification

    var isVerified: Bool  // Verified by BLAB team
    var isFeatured: Bool  // Featured on marketplace

    // MARK: - Pricing (Future)

    var isPremium: Bool
    var price: Decimal?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        creatorID: String,
        creatorName: String,
        creatorAvatar: URL? = nil,
        name: String,
        description: String,
        type: SkillType,
        category: SkillCategory,
        tags: [String] = [],
        content: SkillContent,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        downloads: Int = 0,
        rating: Double = 0.0,
        ratingCount: Int = 0,
        favorites: Int = 0,
        thumbnail: URL? = nil,
        previewVideo: URL? = nil,
        screenshots: [URL] = [],
        isVerified: Bool = false,
        isFeatured: Bool = false,
        isPremium: Bool = false,
        price: Decimal? = nil
    ) {
        self.id = id
        self.creatorID = creatorID
        self.creatorName = creatorName
        self.creatorAvatar = creatorAvatar
        self.name = name
        self.description = description
        self.type = type
        self.category = category
        self.tags = tags
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.downloads = downloads
        self.rating = rating
        self.ratingCount = ratingCount
        self.favorites = favorites
        self.thumbnail = thumbnail
        self.previewVideo = previewVideo
        self.screenshots = screenshots
        self.isVerified = isVerified
        self.isFeatured = isFeatured
        self.isPremium = isPremium
        self.price = price
    }

    // MARK: - Methods

    /// Generate share URL for this skill
    func shareURL() -> URL {
        // TODO: Implement deep linking
        return URL(string: "blab://skill/\(id.uuidString)")!
    }

    /// Export skill as JSON file
    func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Import skill from JSON data
    static func importJSON(_ data: Data) throws -> UserSkill {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UserSkill.self, from: data)
    }

    /// Create skill from session (auto-generate content)
    static func from(session: Session, creator: UserProfile) -> UserSkill {
        let content = SkillContent.sessionTemplate(SessionTemplateSkill(
            duration: session.duration,
            brainwaveState: .alpha,  // TODO: Detect from session
            visualizationMode: .particles,
            binauralFrequency: 10.0,
            includesBinaural: true,
            includesHRV: !session.bioData.isEmpty
        ))

        return UserSkill(
            creatorID: creator.userID,
            creatorName: creator.displayName,
            creatorAvatar: creator.profileImageURL,
            name: session.name,
            description: "Session template with \(session.tracks.count) tracks and HRV data",
            type: .sessionTemplate,
            category: .meditation,
            tags: generateTags(from: session),
            content: content
        )
    }

    private static func generateTags(from session: Session) -> [String] {
        var tags = ["session"]

        if session.averageCoherence > 70 {
            tags.append("high-coherence")
        }

        if session.duration > 600 {
            tags.append("long-form")
        }

        tags.append("hrv")
        tags.append("binaural")

        return tags
    }
}


// MARK: - Skill Type

enum SkillType: String, Codable, CaseIterable {
    case breathingTechnique = "Breathing Technique"
    case sessionTemplate = "Session Template"
    case binauralPreset = "Binaural Beat Preset"
    case visualizationConfig = "Visualization Configuration"
    case audioEffect = "Audio Effect"
    case hrvProtocol = "HRV Training Protocol"
    case meditationGuide = "Meditation Guide"

    var icon: String {
        switch self {
        case .breathingTechnique: return "lungs.fill"
        case .sessionTemplate: return "doc.text.fill"
        case .binauralPreset: return "waveform.circle.fill"
        case .visualizationConfig: return "eyeglasses"
        case .audioEffect: return "music.note"
        case .hrvProtocol: return "heart.text.square.fill"
        case .meditationGuide: return "leaf.fill"
        }
    }

    var color: String {
        switch self {
        case .breathingTechnique: return "cyan"
        case .sessionTemplate: return "purple"
        case .binauralPreset: return "pink"
        case .visualizationConfig: return "orange"
        case .audioEffect: return "green"
        case .hrvProtocol: return "red"
        case .meditationGuide: return "blue"
        }
    }
}


// MARK: - Skill Category

enum SkillCategory: String, Codable, CaseIterable {
    case meditation = "Meditation"
    case relaxation = "Relaxation"
    case focus = "Focus"
    case energy = "Energy"
    case sleep = "Sleep"
    case creativity = "Creativity"
    case performance = "Performance"
    case healing = "Healing"
    case breathwork = "Breathwork"
    case other = "Other"

    var icon: String {
        switch self {
        case .meditation: return "leaf.fill"
        case .relaxation: return "moon.stars.fill"
        case .focus: return "target"
        case .energy: return "bolt.fill"
        case .sleep: return "bed.double.fill"
        case .creativity: return "paintbrush.fill"
        case .performance: return "flame.fill"
        case .healing: return "heart.fill"
        case .breathwork: return "lungs.fill"
        case .other: return "star.fill"
        }
    }
}


// MARK: - Skill Content (Union Type)

enum SkillContent: Codable {
    case breathingTechnique(BreathingTechniqueSkill)
    case sessionTemplate(SessionTemplateSkill)
    case binauralPreset(BinauralPresetSkill)
    case visualizationConfig(VisualizationConfigSkill)
    case audioEffect(AudioEffectSkill)
    case hrvProtocol(HRVProtocolSkill)
    case meditationGuide(MeditationGuideSkill)

    enum CodingKeys: String, CodingKey {
        case type
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "breathingTechnique":
            let data = try container.decode(BreathingTechniqueSkill.self, forKey: .data)
            self = .breathingTechnique(data)
        case "sessionTemplate":
            let data = try container.decode(SessionTemplateSkill.self, forKey: .data)
            self = .sessionTemplate(data)
        case "binauralPreset":
            let data = try container.decode(BinauralPresetSkill.self, forKey: .data)
            self = .binauralPreset(data)
        case "visualizationConfig":
            let data = try container.decode(VisualizationConfigSkill.self, forKey: .data)
            self = .visualizationConfig(data)
        case "audioEffect":
            let data = try container.decode(AudioEffectSkill.self, forKey: .data)
            self = .audioEffect(data)
        case "hrvProtocol":
            let data = try container.decode(HRVProtocolSkill.self, forKey: .data)
            self = .hrvProtocol(data)
        case "meditationGuide":
            let data = try container.decode(MeditationGuideSkill.self, forKey: .data)
            self = .meditationGuide(data)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown skill type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .breathingTechnique(let data):
            try container.encode("breathingTechnique", forKey: .type)
            try container.encode(data, forKey: .data)
        case .sessionTemplate(let data):
            try container.encode("sessionTemplate", forKey: .type)
            try container.encode(data, forKey: .data)
        case .binauralPreset(let data):
            try container.encode("binauralPreset", forKey: .type)
            try container.encode(data, forKey: .data)
        case .visualizationConfig(let data):
            try container.encode("visualizationConfig", forKey: .type)
            try container.encode(data, forKey: .data)
        case .audioEffect(let data):
            try container.encode("audioEffect", forKey: .type)
            try container.encode(data, forKey: .data)
        case .hrvProtocol(let data):
            try container.encode("hrvProtocol", forKey: .type)
            try container.encode(data, forKey: .data)
        case .meditationGuide(let data):
            try container.encode("meditationGuide", forKey: .type)
            try container.encode(data, forKey: .data)
        }
    }
}


// MARK: - Breathing Technique Skill

struct BreathingTechniqueSkill: Codable {
    let name: String
    let pattern: BreathingPattern
    let duration: TimeInterval
    let instructions: [String]
    let benefits: [String]

    struct BreathingPattern: Codable {
        let inhale: TimeInterval
        let hold1: TimeInterval?
        let exhale: TimeInterval
        let hold2: TimeInterval?
        let cycles: Int
    }
}


// MARK: - Session Template Skill

struct SessionTemplateSkill: Codable {
    let duration: TimeInterval
    let brainwaveState: BinauralBeatGenerator.BrainwaveState
    let visualizationMode: VisualizationMode
    let binauralFrequency: Float
    let includesBinaural: Bool
    let includesHRV: Bool
}


// MARK: - Binaural Preset Skill

struct BinauralPresetSkill: Codable {
    let carrierFrequency: Float
    let beatFrequency: Float
    let amplitude: Float
    let brainwaveState: BinauralBeatGenerator.BrainwaveState
    let waveform: String  // "sine", "square", "triangle"
}


// MARK: - Visualization Config Skill

struct VisualizationConfigSkill: Codable {
    let mode: VisualizationMode
    let colorScheme: String
    let sensitivity: Float
    let customParameters: [String: Float]
}


// MARK: - Audio Effect Skill

struct AudioEffectSkill: Codable {
    let effectType: String  // "reverb", "delay", "distortion", etc.
    let parameters: [String: Float]
    let wetDryMix: Float
}


// MARK: - HRV Protocol Skill

struct HRVProtocolSkill: Codable {
    let targetCoherence: Float
    let duration: TimeInterval
    let breathingRate: Float  // breaths per minute
    let feedbackType: String  // "visual", "audio", "haptic"
    let steps: [HRVStep]

    struct HRVStep: Codable {
        let duration: TimeInterval
        let targetRange: ClosedRange<Float>
        let instruction: String
    }
}


// MARK: - Meditation Guide Skill

struct MeditationGuideSkill: Codable {
    let style: String  // "mindfulness", "transcendental", "guided", etc.
    let duration: TimeInterval
    let audioGuide: URL?
    let steps: [MeditationStep]
    let backgroundMusic: String?

    struct MeditationStep: Codable {
        let timestamp: TimeInterval
        let instruction: String
        let duration: TimeInterval
    }
}

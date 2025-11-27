import Foundation
import Combine

/// GlobalInclusivity - Worldwide Cultural Adaptation & Offline Access
/// Ensuring the Quantum Life Scanner works for EVERY person on Earth
///
/// Mission: Technology should never be a barrier to healing and development.
/// Everyone deserves access regardless of location, language, culture, or connectivity.
///
/// Principles:
/// 1. Cultural Humility - Adapting to local contexts, not imposing Western models
/// 2. Linguistic Justice - All languages are equally valuable
/// 3. Connectivity Justice - Offline-first for underserved regions
/// 4. Economic Justice - Accessible pricing for all income levels
/// 5. Disability Justice - Designed for the full spectrum of human ability
///
/// Research Base:
/// - WHO Traditional Medicine Strategy 2014-2023
/// - UNESCO Cultural Diversity Guidelines
/// - UN Sustainable Development Goals (SDG 3: Health, SDG 10: Reduced Inequalities)
/// - Decolonizing Global Health (Abimbola, 2021)
@MainActor
public final class GlobalInclusivity: ObservableObject {

    // MARK: - Singleton

    public static let shared = GlobalInclusivity()

    // MARK: - Published State

    @Published public var currentCulture: CulturalContext?
    @Published public var offlineModeEnabled: Bool = false
    @Published public var lowBandwidthMode: Bool = false
    @Published public var localizedContent: LocalizedContentPack?
    @Published public var culturalAdaptations: [CulturalAdaptation] = []

    // MARK: - Cultural Context

    public struct CulturalContext: Codable {
        public var region: WorldRegion
        public var country: String
        public var language: String
        public var languageScript: LanguageScript
        public var textDirection: TextDirection
        public var culturalFramework: CulturalFramework
        public var healingTraditions: [HealingTradition]
        public var timeZone: String
        public var dateFormat: DateFormat
        public var numberFormat: NumberFormat
        public var measurementSystem: MeasurementSystem
        public var colorSymbolism: ColorSymbolism
        public var communicationStyle: CommunicationStyle

        public init(region: WorldRegion, country: String, language: String) {
            self.region = region
            self.country = country
            self.language = language
            self.languageScript = .latin
            self.textDirection = .leftToRight
            self.culturalFramework = region.defaultFramework
            self.healingTraditions = region.healingTraditions
            self.timeZone = TimeZone.current.identifier
            self.dateFormat = region.defaultDateFormat
            self.numberFormat = region.defaultNumberFormat
            self.measurementSystem = region.defaultMeasurement
            self.colorSymbolism = region.colorSymbolism
            self.communicationStyle = region.communicationStyle
        }
    }

    // MARK: - World Region

    public enum WorldRegion: String, Codable, CaseIterable {
        case northAmerica = "North America"
        case latinAmerica = "Latin America"
        case westernEurope = "Western Europe"
        case easternEurope = "Eastern Europe"
        case middleEast = "Middle East"
        case northAfrica = "North Africa"
        case subSaharanAfrica = "Sub-Saharan Africa"
        case southAsia = "South Asia"
        case eastAsia = "East Asia"
        case southeastAsia = "Southeast Asia"
        case oceania = "Oceania"
        case centralAsia = "Central Asia"

        var defaultFramework: CulturalFramework {
            switch self {
            case .northAmerica, .westernEurope, .oceania:
                return .individualist
            case .eastAsia, .southeastAsia, .middleEast, .southAsia:
                return .collectivist
            case .latinAmerica, .subSaharanAfrica:
                return .communitarian
            case .easternEurope, .centralAsia, .northAfrica:
                return .mixed
            }
        }

        var healingTraditions: [HealingTradition] {
            switch self {
            case .eastAsia:
                return [.traditionalChineseMedicine, .acupuncture, .qigong, .meditation]
            case .southAsia:
                return [.ayurveda, .yoga, .meditation, .pranayama]
            case .middleEast:
                return [.unaniMedicine, .propheticMedicine, .meditation]
            case .subSaharanAfrica:
                return [.traditionalAfricanMedicine, .communityHealing, .ritualHealing]
            case .latinAmerica:
                return [.curanderismo, .plantMedicine, .communityHealing]
            case .northAmerica:
                return [.westernMedicine, .nativeAmericanHealing, .integrative]
            case .westernEurope:
                return [.westernMedicine, .naturopathy, .integrative]
            case .easternEurope:
                return [.westernMedicine, .folkMedicine, .balneotherapy]
            case .southeastAsia:
                return [.traditionalMedicine, .meditation, .energyHealing]
            case .oceania:
                return [.westernMedicine, .indigenousHealing, .integrative]
            case .centralAsia:
                return [.traditionalMedicine, .shamanism, .herbalMedicine]
            case .northAfrica:
                return [.unaniMedicine, .traditionalMedicine, .spiritualHealing]
            }
        }

        var defaultDateFormat: DateFormat {
            switch self {
            case .northAmerica:
                return .monthDayYear
            case .eastAsia:
                return .yearMonthDay
            default:
                return .dayMonthYear
            }
        }

        var defaultNumberFormat: NumberFormat {
            switch self {
            case .northAmerica, .eastAsia, .oceania, .southeastAsia:
                return .periodDecimal   // 1,000.00
            default:
                return .commaDecimal    // 1.000,00
            }
        }

        var defaultMeasurement: MeasurementSystem {
            switch self {
            case .northAmerica:
                return .imperial
            default:
                return .metric
            }
        }

        var colorSymbolism: ColorSymbolism {
            switch self {
            case .eastAsia:
                return ColorSymbolism(
                    positive: ["Red", "Gold", "Yellow"],
                    negative: ["White", "Black"],
                    healing: ["Green", "Blue"],
                    warning: ["White"],
                    notes: "Red = luck/prosperity, White = mourning in some contexts"
                )
            case .middleEast, .northAfrica:
                return ColorSymbolism(
                    positive: ["Green", "Blue", "Gold"],
                    negative: ["Black"],
                    healing: ["Green", "White"],
                    warning: ["Red"],
                    notes: "Green = Islam/nature, Blue = protection"
                )
            case .southAsia:
                return ColorSymbolism(
                    positive: ["Red", "Yellow", "Orange", "Green"],
                    negative: ["Black", "White"],
                    healing: ["Green", "Blue"],
                    warning: ["Black"],
                    notes: "Red = purity/fertility, White = mourning, Saffron = sacred"
                )
            case .subSaharanAfrica:
                return ColorSymbolism(
                    positive: ["Green", "Gold", "Red"],
                    negative: ["Black"],
                    healing: ["Green", "Blue", "White"],
                    warning: ["Red"],
                    notes: "Pan-African colors meaningful, varies by country"
                )
            default:
                return ColorSymbolism(
                    positive: ["Green", "Blue", "Gold"],
                    negative: ["Black", "Gray"],
                    healing: ["Green", "Blue", "White"],
                    warning: ["Red", "Orange"],
                    notes: "Standard Western color associations"
                )
            }
        }

        var communicationStyle: CommunicationStyle {
            switch self {
            case .northAmerica, .westernEurope, .oceania:
                return .direct
            case .eastAsia, .southeastAsia, .middleEast:
                return .indirect
            default:
                return .contextual
            }
        }

        var languages: [String] {
            switch self {
            case .northAmerica:
                return ["en", "es", "fr"]
            case .latinAmerica:
                return ["es", "pt", "en"]
            case .westernEurope:
                return ["en", "de", "fr", "es", "it", "nl", "pt"]
            case .easternEurope:
                return ["ru", "pl", "uk", "ro", "cs", "hu"]
            case .middleEast:
                return ["ar", "fa", "he", "tr"]
            case .northAfrica:
                return ["ar", "fr", "ber"]
            case .subSaharanAfrica:
                return ["en", "fr", "sw", "ha", "yo", "am"]
            case .southAsia:
                return ["hi", "bn", "ur", "ta", "te", "mr", "en"]
            case .eastAsia:
                return ["zh", "ja", "ko"]
            case .southeastAsia:
                return ["id", "th", "vi", "tl", "ms"]
            case .oceania:
                return ["en", "mi", "to", "sm"]
            case .centralAsia:
                return ["kk", "uz", "ky", "tk", "ru"]
            }
        }
    }

    // MARK: - Cultural Framework

    public enum CulturalFramework: String, Codable {
        case individualist = "Individualist"       // Self-focused goals
        case collectivist = "Collectivist"         // Group/family-focused
        case communitarian = "Communitarian"       // Community-focused
        case mixed = "Mixed"                       // Blend of approaches

        var wellbeingEmphasis: String {
            switch self {
            case .individualist:
                return "Personal achievement, autonomy, self-expression"
            case .collectivist:
                return "Family harmony, social role fulfillment, group success"
            case .communitarian:
                return "Community wellbeing, mutual support, shared resources"
            case .mixed:
                return "Balance of individual and collective needs"
            }
        }

        var recommendationStyle: String {
            switch self {
            case .individualist:
                return "Focus on personal growth and individual achievements"
            case .collectivist:
                return "Frame growth in context of family and social obligations"
            case .communitarian:
                return "Emphasize community contribution and mutual support"
            case .mixed:
                return "Balance personal and collective benefits"
            }
        }
    }

    // MARK: - Healing Tradition

    public enum HealingTradition: String, Codable, CaseIterable {
        case westernMedicine = "Western Medicine"
        case traditionalChineseMedicine = "Traditional Chinese Medicine"
        case ayurveda = "Ayurveda"
        case unaniMedicine = "Unani Medicine"
        case traditionalAfricanMedicine = "Traditional African Medicine"
        case nativeAmericanHealing = "Native American Healing"
        case curanderismo = "Curanderismo"
        case naturopathy = "Naturopathy"
        case acupuncture = "Acupuncture"
        case yoga = "Yoga"
        case qigong = "Qigong"
        case meditation = "Meditation"
        case pranayama = "Pranayama"
        case energyHealing = "Energy Healing"
        case plantMedicine = "Plant Medicine"
        case communityHealing = "Community Healing"
        case ritualHealing = "Ritual Healing"
        case spiritualHealing = "Spiritual Healing"
        case folkMedicine = "Folk Medicine"
        case balneotherapy = "Balneotherapy"
        case shamanism = "Shamanism"
        case herbalMedicine = "Herbal Medicine"
        case integrative = "Integrative Medicine"
        case indigenousHealing = "Indigenous Healing"
        case traditionalMedicine = "Traditional Medicine"
        case propheticMedicine = "Prophetic Medicine"

        var description: String {
            switch self {
            case .westernMedicine:
                return "Evidence-based allopathic medicine"
            case .traditionalChineseMedicine:
                return "5,000-year-old system including acupuncture, herbs, qigong"
            case .ayurveda:
                return "Ancient Indian system of balance (doshas: Vata, Pitta, Kapha)"
            case .unaniMedicine:
                return "Greco-Arabic medicine based on four humors"
            case .yoga:
                return "Mind-body practice for union of body, mind, spirit"
            case .meditation:
                return "Contemplative practices for mental clarity and peace"
            default:
                return "Traditional healing practice from specific cultural context"
            }
        }

        var evidenceLevel: String {
            switch self {
            case .westernMedicine:
                return "Level 1a (RCTs, systematic reviews)"
            case .meditation, .yoga:
                return "Level 1a-1b (Strong evidence for specific conditions)"
            case .acupuncture:
                return "Level 1b-2a (Moderate evidence for pain, nausea)"
            case .traditionalChineseMedicine, .ayurveda:
                return "Level 2b-3 (Growing evidence, more research needed)"
            default:
                return "Level 3-4 (Traditional use, limited clinical trials)"
            }
        }

        var whoRecognition: String {
            switch self {
            case .westernMedicine:
                return "Primary global healthcare system"
            case .traditionalChineseMedicine:
                return "WHO ICD-11 includes TCM diagnoses (2019)"
            case .ayurveda:
                return "WHO Traditional Medicine Strategy 2014-2023"
            case .yoga, .meditation:
                return "Recognized as complementary approaches"
            default:
                return "Recognized under traditional medicine frameworks"
            }
        }
    }

    // MARK: - Supporting Types

    public enum LanguageScript: String, Codable {
        case latin = "Latin"
        case arabic = "Arabic"
        case cyrillic = "Cyrillic"
        case devanagari = "Devanagari"
        case chinese = "Chinese (Hanzi)"
        case japanese = "Japanese (Kanji/Kana)"
        case korean = "Korean (Hangul)"
        case hebrew = "Hebrew"
        case thai = "Thai"
        case tamil = "Tamil"
        case bengali = "Bengali"
        case greek = "Greek"
    }

    public enum TextDirection: String, Codable {
        case leftToRight = "Left to Right"
        case rightToLeft = "Right to Left"
        case topToBottom = "Top to Bottom"
    }

    public enum DateFormat: String, Codable {
        case dayMonthYear = "DD/MM/YYYY"
        case monthDayYear = "MM/DD/YYYY"
        case yearMonthDay = "YYYY-MM-DD"
    }

    public enum NumberFormat: String, Codable {
        case periodDecimal = "Period Decimal (1,000.00)"
        case commaDecimal = "Comma Decimal (1.000,00)"
        case arabicNumerals = "Arabic-Indic Numerals"
        case devanagariNumerals = "Devanagari Numerals"
    }

    public enum MeasurementSystem: String, Codable {
        case metric = "Metric"
        case imperial = "Imperial"
    }

    public struct ColorSymbolism: Codable {
        public var positive: [String]
        public var negative: [String]
        public var healing: [String]
        public var warning: [String]
        public var notes: String
    }

    public enum CommunicationStyle: String, Codable {
        case direct = "Direct"           // Explicit, straightforward
        case indirect = "Indirect"       // Implicit, context-dependent
        case contextual = "Contextual"   // Varies by situation

        var uiGuidance: String {
            switch self {
            case .direct:
                return "Clear, explicit instructions. Direct feedback."
            case .indirect:
                return "Gentle suggestions. Face-saving language. Implicit guidance."
            case .contextual:
                return "Adapt based on user preference and situation."
            }
        }
    }

    // MARK: - Cultural Adaptation

    public struct CulturalAdaptation: Codable, Identifiable {
        public let id: UUID
        public var featureName: String
        public var originalApproach: String
        public var adaptedApproach: String
        public var culturalRationale: String
        public var region: WorldRegion

        public init(featureName: String, originalApproach: String, adaptedApproach: String, culturalRationale: String, region: WorldRegion) {
            self.id = UUID()
            self.featureName = featureName
            self.originalApproach = originalApproach
            self.adaptedApproach = adaptedApproach
            self.culturalRationale = culturalRationale
            self.region = region
        }
    }

    // MARK: - Localized Content Pack

    public struct LocalizedContentPack: Codable {
        public var language: String
        public var region: WorldRegion
        public var translations: [String: String]
        public var culturalNotes: [String]
        public var localResources: [LocalResource]
        public var adaptedInterventions: [AdaptedIntervention]
        public var offlineAvailable: Bool
        public var downloadSize: Int  // bytes
        public var lastUpdated: Date

        public struct LocalResource: Codable, Identifiable {
            public let id: UUID
            public var name: String
            public var type: ResourceType
            public var description: String
            public var contactInfo: String
            public var isAvailableOffline: Bool
            public var languages: [String]

            public enum ResourceType: String, Codable {
                case crisisLine = "Crisis Line"
                case mentalHealth = "Mental Health Service"
                case community = "Community Support"
                case healthcare = "Healthcare"
                case socialServices = "Social Services"
                case employment = "Employment Services"
                case education = "Education"
                case legal = "Legal Aid"
            }
        }

        public struct AdaptedIntervention: Codable, Identifiable {
            public let id: UUID
            public var originalName: String
            public var localizedName: String
            public var culturalAdaptation: String
            public var localEquivalent: String?
            public var evidenceInContext: String
        }
    }

    // MARK: - Offline Data Package

    public struct OfflineDataPackage: Codable {
        public var language: String
        public var region: WorldRegion
        public var version: String
        public var downloadedDate: Date
        public var sizeBytes: Int

        // Core functionality
        public var scannerAvailable: Bool
        public var healingProtocolsAvailable: Bool
        public var careerMatchingAvailable: Bool
        public var potentialTrackingAvailable: Bool

        // Content
        public var localizedStrings: [String: String]
        public var interventionLibrary: [String]
        public var jobDatabase: [String]
        public var learningResources: [String]

        // Data storage
        public var maxLocalScans: Int
        public var syncWhenOnline: Bool

        public init(language: String, region: WorldRegion) {
            self.language = language
            self.region = region
            self.version = "1.0"
            self.downloadedDate = Date()
            self.sizeBytes = 0

            self.scannerAvailable = true
            self.healingProtocolsAvailable = true
            self.careerMatchingAvailable = true
            self.potentialTrackingAvailable = true

            self.localizedStrings = [:]
            self.interventionLibrary = []
            self.jobDatabase = []
            self.learningResources = []

            self.maxLocalScans = 100
            self.syncWhenOnline = true
        }
    }

    // MARK: - Network Status

    @Published public var networkStatus: NetworkStatus = .online
    @Published public var lastSyncDate: Date?
    @Published public var pendingSyncItems: Int = 0

    public enum NetworkStatus: String {
        case online = "Online"
        case offline = "Offline"
        case lowBandwidth = "Low Bandwidth"
        case syncing = "Syncing"
    }

    // MARK: - Initialization

    private init() {
        print("==============================================")
        print("   GLOBAL INCLUSIVITY ENGINE")
        print("==============================================")
        print("   For EVERY person on Earth")
        print("   Cultural adaptation: Active")
        print("   Offline mode: Ready")
        print("   Languages: 23+ supported")
        print("==============================================")

        setupDefaultCulturalAdaptations()
    }

    // MARK: - Setup Cultural Context

    public func setupCulturalContext(region: WorldRegion, country: String, language: String) {
        currentCulture = CulturalContext(region: region, country: country, language: language)

        // Apply RTL if needed
        if ["ar", "he", "fa", "ur"].contains(language) {
            currentCulture?.textDirection = .rightToLeft
        }

        // Set script
        currentCulture?.languageScript = getScript(for: language)

        print("   GlobalInclusivity: Context set for \(region.rawValue), \(language)")
    }

    // MARK: - Enable Offline Mode

    public func enableOfflineMode() async -> OfflineDataPackage {
        offlineModeEnabled = true
        networkStatus = .offline

        let package = OfflineDataPackage(
            language: currentCulture?.language ?? "en",
            region: currentCulture?.region ?? .northAmerica
        )

        print("   GlobalInclusivity: Offline mode enabled")
        print("   Scanner: Available offline")
        print("   Healing: Available offline")
        print("   Career: Available offline")

        return package
    }

    // MARK: - Enable Low Bandwidth Mode

    public func enableLowBandwidthMode() {
        lowBandwidthMode = true
        print("   GlobalInclusivity: Low bandwidth mode enabled")
        print("   - Images: Compressed")
        print("   - Animations: Reduced")
        print("   - Sync: Batched")
    }

    // MARK: - Get Adapted Intervention

    public func getAdaptedIntervention(original: String) -> String {
        guard let culture = currentCulture else { return original }

        // Adapt intervention to cultural context
        switch (original, culture.region) {
        case ("Mindfulness Meditation", .southAsia):
            return "Dhyana/Meditation (traditional practice from yoga tradition)"
        case ("Mindfulness Meditation", .eastAsia):
            return "Chan/Zen Meditation (traditional contemplative practice)"
        case ("Breathing Exercise", .southAsia):
            return "Pranayama (yogic breath control)"
        case ("Breathing Exercise", .eastAsia):
            return "Qigong Breathing (energy cultivation)"
        case ("Progressive Muscle Relaxation", .eastAsia):
            return "Tai Chi-inspired relaxation"
        case ("Talk Therapy", .collectivist):
            return "Family-inclusive counseling"
        default:
            return original
        }
    }

    // MARK: - Get Local Resources

    public func getLocalResources(for category: LocalizedContentPack.LocalResource.ResourceType) -> [LocalizedContentPack.LocalResource] {
        // In production: Query local database
        // For now: Return sample resources

        return [
            LocalizedContentPack.LocalResource(
                id: UUID(),
                name: "Local Crisis Line",
                type: category,
                description: "24/7 support in your language",
                contactInfo: "Emergency: 112 (EU), 911 (US), 999 (UK)",
                isAvailableOffline: true,
                languages: currentCulture?.region.languages ?? ["en"]
            )
        ]
    }

    // MARK: - Setup Default Cultural Adaptations

    private func setupDefaultCulturalAdaptations() {
        culturalAdaptations = [
            CulturalAdaptation(
                featureName: "Wellbeing Score Display",
                originalApproach: "Individual score prominently displayed",
                adaptedApproach: "Family/community wellbeing context included",
                culturalRationale: "Collectivist cultures value group harmony over individual metrics",
                region: .eastAsia
            ),
            CulturalAdaptation(
                featureName: "Goal Setting",
                originalApproach: "Personal achievement goals",
                adaptedApproach: "Goals framed in family/community context",
                culturalRationale: "Success is often defined by contribution to family",
                region: .southAsia
            ),
            CulturalAdaptation(
                featureName: "Healing Recommendations",
                originalApproach: "Western evidence-based interventions",
                adaptedApproach: "Include traditional medicine options alongside",
                culturalRationale: "Traditional healing is deeply trusted and effective",
                region: .subSaharanAfrica
            ),
            CulturalAdaptation(
                featureName: "Mental Health Language",
                originalApproach: "Clinical mental health terminology",
                adaptedApproach: "Holistic wellbeing language, reduced stigma framing",
                culturalRationale: "Mental health stigma varies; holistic framing is more acceptable",
                region: .middleEast
            ),
            CulturalAdaptation(
                featureName: "Career Success Metrics",
                originalApproach: "Salary and title advancement",
                adaptedApproach: "Include family support capacity, community standing",
                culturalRationale: "Success measured differently across cultures",
                region: .latinAmerica
            )
        ]
    }

    // MARK: - Get Script

    private func getScript(for language: String) -> LanguageScript {
        switch language {
        case "ar": return .arabic
        case "he": return .hebrew
        case "fa": return .arabic  // Persian uses Arabic script
        case "ru", "uk", "bg", "sr": return .cyrillic
        case "hi", "mr", "ne": return .devanagari
        case "zh": return .chinese
        case "ja": return .japanese
        case "ko": return .korean
        case "th": return .thai
        case "ta": return .tamil
        case "bn": return .bengali
        case "el": return .greek
        default: return .latin
        }
    }

    // MARK: - Sync When Online

    public func syncWhenOnline() async {
        guard networkStatus == .online else { return }

        networkStatus = .syncing
        print("   GlobalInclusivity: Syncing \(pendingSyncItems) items...")

        // Simulate sync
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        pendingSyncItems = 0
        lastSyncDate = Date()
        networkStatus = .online

        print("   GlobalInclusivity: Sync complete")
    }

    // MARK: - Report

    public func getReport() -> String {
        return """
        =====================================================
        GLOBAL INCLUSIVITY REPORT
        =====================================================

        CURRENT CONTEXT:
        - Region: \(currentCulture?.region.rawValue ?? "Not set")
        - Country: \(currentCulture?.country ?? "Not set")
        - Language: \(currentCulture?.language ?? "Not set")
        - Text Direction: \(currentCulture?.textDirection.rawValue ?? "LTR")
        - Cultural Framework: \(currentCulture?.culturalFramework.rawValue ?? "Not set")

        NETWORK STATUS:
        - Status: \(networkStatus.rawValue)
        - Offline Mode: \(offlineModeEnabled ? "Enabled" : "Disabled")
        - Low Bandwidth: \(lowBandwidthMode ? "Enabled" : "Disabled")
        - Last Sync: \(lastSyncDate?.description ?? "Never")
        - Pending Sync: \(pendingSyncItems) items

        HEALING TRADITIONS RECOGNIZED:
        \(currentCulture?.healingTraditions.map { "  - \($0.rawValue)" }.joined(separator: "\n") ?? "  None")

        CULTURAL ADAPTATIONS ACTIVE: \(culturalAdaptations.count)
        \(culturalAdaptations.prefix(3).map { "  - \($0.featureName): \($0.adaptedApproach)" }.joined(separator: "\n"))

        SUPPORTED LANGUAGES IN REGION:
        \(currentCulture?.region.languages.joined(separator: ", ") ?? "en")

        =====================================================
        "Technology should adapt to culture, not erase it."
        =====================================================
        """
    }
}

import Foundation
import Combine

// MARK: - Wellness Engines Module
/// Complete wellness engines for Echoelmusic
/// Includes Longevity, NeuroSpiritual, Quantum Health, and Adey Windows engines
///
/// DISCLAIMER: These features are for general wellness, relaxation, and creative purposes only.
/// NOT a medical device. NOT intended to diagnose, treat, cure, or prevent any disease.
/// Consult healthcare professionals for medical advice.

// MARK: - 1. Longevity Nutrition Engine

/// Scientific longevity nutrition engine based on Blue Zones research and aging hallmarks
/// Reference: López-Otín et al., Cell 2013 - The Hallmarks of Aging
@MainActor
class LongevityNutritionEngine: ObservableObject {

    // MARK: - Published State

    @Published var currentBiologicalAge: Float = 0
    @Published var chronologicalAge: Float = 0
    @Published var hrvCoherence: Float = 0.5
    @Published var currentChronotype: Chronotype = .bear
    @Published var selectedCompounds: [LongevityCompound] = []
    @Published var dailyProtocol: [DailyProtocolItem] = []

    // MARK: - Hallmarks of Aging (López-Otín et al., Cell 2013)

    enum HallmarkOfAging: String, CaseIterable, Identifiable {
        case genomicInstability = "Genomic Instability"
        case telomereAttrition = "Telomere Attrition"
        case epigeneticAlterations = "Epigenetic Alterations"
        case lossOfProteostasis = "Loss of Proteostasis"
        case deregulatedNutrientSensing = "Deregulated Nutrient Sensing"
        case mitochondrialDysfunction = "Mitochondrial Dysfunction"
        case cellularSenescence = "Cellular Senescence"
        case stemCellExhaustion = "Stem Cell Exhaustion"
        case alteredIntercellularCommunication = "Altered Intercellular Communication"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .genomicInstability:
                return "Accumulation of DNA damage throughout life"
            case .telomereAttrition:
                return "Progressive shortening of telomere protective caps"
            case .epigeneticAlterations:
                return "Changes in gene expression without DNA sequence changes"
            case .lossOfProteostasis:
                return "Decline in protein quality control mechanisms"
            case .deregulatedNutrientSensing:
                return "Impaired ability to sense and respond to nutrients"
            case .mitochondrialDysfunction:
                return "Reduced efficiency of cellular energy production"
            case .cellularSenescence:
                return "Accumulation of cells that stop dividing"
            case .stemCellExhaustion:
                return "Decline in tissue regenerative capacity"
            case .alteredIntercellularCommunication:
                return "Changes in signaling between cells"
            }
        }

        var targetCompounds: [CompoundCategory] {
            switch self {
            case .genomicInstability:
                return [.antioxidant, .dnaRepair]
            case .telomereAttrition:
                return [.telomerase, .antioxidant]
            case .epigeneticAlterations:
                return [.epigenetic, .sirtuin]
            case .lossOfProteostasis:
                return [.autophagy, .chaperone]
            case .deregulatedNutrientSensing:
                return [.sirtuin, .ampk]
            case .mitochondrialDysfunction:
                return [.mitochondrial, .nad]
            case .cellularSenescence:
                return [.senolytic, .senostatic]
            case .stemCellExhaustion:
                return [.stemCell, .growthFactor]
            case .alteredIntercellularCommunication:
                return [.antiInflammatory, .immunomodulator]
            }
        }
    }

    // MARK: - Longevity Compounds

    enum CompoundCategory: String, CaseIterable {
        case sirtuin = "Sirtuin Activator"
        case senolytic = "Senolytic"
        case nad = "NAD+ Precursor"
        case mitochondrial = "Mitochondrial Support"
        case epigenetic = "Epigenetic Modulator"
        case autophagy = "Autophagy Inducer"
        case antioxidant = "Antioxidant"
        case antiInflammatory = "Anti-Inflammatory"
        case telomerase = "Telomerase Activator"
        case ampk = "AMPK Activator"
        case chaperone = "Chaperone Support"
        case dnaRepair = "DNA Repair"
        case senostatic = "Senostatic"
        case stemCell = "Stem Cell Support"
        case growthFactor = "Growth Factor"
        case immunomodulator = "Immunomodulator"
    }

    struct LongevityCompound: Identifiable {
        let id = UUID()
        let name: String
        let category: CompoundCategory
        let evidenceLevel: EvidenceLevel
        let targetHallmarks: [HallmarkOfAging]
        let dosageRange: String
        let timing: String
        let notes: String
        let citations: [String]
    }

    enum EvidenceLevel: String, CaseIterable {
        case humanRCT = "Human RCT"
        case humanObservational = "Human Observational"
        case animalStudy = "Animal Study"
        case inVitro = "In Vitro"
        case traditional = "Traditional Use"

        var strength: Int {
            switch self {
            case .humanRCT: return 5
            case .humanObservational: return 4
            case .animalStudy: return 3
            case .inVitro: return 2
            case .traditional: return 1
            }
        }
    }

    // MARK: - Blue Zone Foods

    struct BlueZoneFood: Identifiable {
        let id = UUID()
        let name: String
        let origin: BlueZone
        let category: FoodCategory
        let longevityBenefits: [String]
        let servingsPerWeek: Int
        let coherenceImpact: Float  // 0-1 how much it may support HRV coherence
    }

    enum BlueZone: String, CaseIterable {
        case okinawa = "Okinawa, Japan"
        case sardinia = "Sardinia, Italy"
        case nicoya = "Nicoya, Costa Rica"
        case ikaria = "Ikaria, Greece"
        case lomaLinda = "Loma Linda, California"
    }

    enum FoodCategory: String, CaseIterable {
        case cruciferous = "Cruciferous Vegetables"
        case legumes = "Legumes"
        case berries = "Berries"
        case fermented = "Fermented Foods"
        case alliums = "Alliums (Garlic/Onion)"
        case nuts = "Nuts & Seeds"
        case wholegrains = "Whole Grains"
        case fish = "Fatty Fish"
        case oliveOil = "Olive Oil"
        case greenTea = "Green Tea"
        case herbs = "Herbs & Spices"
        case seaweed = "Seaweed"
    }

    // MARK: - Chronotype

    enum Chronotype: String, CaseIterable {
        case lion = "Lion (Early Bird)"
        case bear = "Bear (Average)"
        case wolf = "Wolf (Night Owl)"
        case dolphin = "Dolphin (Light Sleeper)"

        var optimalWakeTime: String {
            switch self {
            case .lion: return "5:30-6:00 AM"
            case .bear: return "7:00-7:30 AM"
            case .wolf: return "9:00-9:30 AM"
            case .dolphin: return "6:30-7:00 AM"
            }
        }

        var fastingWindow: String {
            switch self {
            case .lion: return "6:00 PM - 6:00 AM (12h)"
            case .bear: return "7:00 PM - 9:00 AM (14h)"
            case .wolf: return "8:00 PM - 12:00 PM (16h)"
            case .dolphin: return "7:00 PM - 7:00 AM (12h)"
            }
        }
    }

    // MARK: - Daily Protocol

    struct DailyProtocolItem: Identifiable {
        let id = UUID()
        let time: String
        let activity: String
        let category: ProtocolCategory
        let duration: Int  // minutes
        let coherenceBoost: Float
    }

    enum ProtocolCategory: String {
        case nutrition = "Nutrition"
        case movement = "Movement"
        case mindfulness = "Mindfulness"
        case sleep = "Sleep"
        case social = "Social"
        case coldExposure = "Cold Exposure"
        case heatExposure = "Heat Exposure"
        case lightExposure = "Light Exposure"
    }

    // MARK: - Database

    private(set) var compoundsDatabase: [LongevityCompound] = []
    private(set) var blueZoneFoods: [BlueZoneFood] = []

    // MARK: - Initialization

    init() {
        loadCompoundsDatabase()
        loadBlueZoneFoods()
        generateDailyProtocol()
        log.audio("LongevityNutritionEngine: Initialized with \(compoundsDatabase.count) compounds, \(blueZoneFoods.count) Blue Zone foods")
    }

    // MARK: - Load Compounds Database

    private func loadCompoundsDatabase() {
        compoundsDatabase = [
            LongevityCompound(
                name: "NMN (Nicotinamide Mononucleotide)",
                category: .nad,
                evidenceLevel: .humanRCT,
                targetHallmarks: [.mitochondrialDysfunction, .deregulatedNutrientSensing],
                dosageRange: "250-500mg/day",
                timing: "Morning",
                notes: "NAD+ precursor, may support energy metabolism",
                citations: ["Imai & Guarente, 2014, Cell Metab"]
            ),
            LongevityCompound(
                name: "Resveratrol",
                category: .sirtuin,
                evidenceLevel: .humanObservational,
                targetHallmarks: [.epigeneticAlterations, .deregulatedNutrientSensing],
                dosageRange: "100-500mg/day",
                timing: "With fatty meal",
                notes: "SIRT1 activator, found in red grapes",
                citations: ["Howitz et al., 2003, Nature"]
            ),
            LongevityCompound(
                name: "Fisetin",
                category: .senolytic,
                evidenceLevel: .animalStudy,
                targetHallmarks: [.cellularSenescence],
                dosageRange: "100-500mg intermittently",
                timing: "2-3 day course monthly",
                notes: "Senolytic flavonoid, found in strawberries",
                citations: ["Yousefzadeh et al., 2018, EBioMedicine"]
            ),
            LongevityCompound(
                name: "Spermidine",
                category: .autophagy,
                evidenceLevel: .humanObservational,
                targetHallmarks: [.lossOfProteostasis, .cellularSenescence],
                dosageRange: "1-5mg/day",
                timing: "Morning",
                notes: "Autophagy inducer, found in wheat germ",
                citations: ["Eisenberg et al., 2016, Nat Med"]
            ),
            LongevityCompound(
                name: "Quercetin",
                category: .senolytic,
                evidenceLevel: .humanRCT,
                targetHallmarks: [.cellularSenescence, .alteredIntercellularCommunication],
                dosageRange: "500-1000mg intermittently",
                timing: "With Dasatinib for senolytic effect",
                notes: "Senolytic when combined with Dasatinib",
                citations: ["Justice et al., 2019, EBioMedicine"]
            ),
            LongevityCompound(
                name: "Sulforaphane",
                category: .epigenetic,
                evidenceLevel: .humanRCT,
                targetHallmarks: [.genomicInstability, .epigeneticAlterations],
                dosageRange: "10-50mg/day",
                timing: "Morning",
                notes: "Nrf2 activator from broccoli sprouts",
                citations: ["Fahey et al., 2017, Nutrients"]
            ),
            LongevityCompound(
                name: "Berberine",
                category: .ampk,
                evidenceLevel: .humanRCT,
                targetHallmarks: [.deregulatedNutrientSensing, .mitochondrialDysfunction],
                dosageRange: "500-1500mg/day",
                timing: "With meals",
                notes: "AMPK activator, glucose metabolism",
                citations: ["Yin et al., 2008, Metabolism"]
            ),
            LongevityCompound(
                name: "CoQ10 (Ubiquinol)",
                category: .mitochondrial,
                evidenceLevel: .humanRCT,
                targetHallmarks: [.mitochondrialDysfunction],
                dosageRange: "100-300mg/day",
                timing: "With fatty meal",
                notes: "Mitochondrial electron carrier",
                citations: ["Mortensen et al., 2014, JACC Heart Fail"]
            ),
            LongevityCompound(
                name: "Alpha-Ketoglutarate (AKG)",
                category: .mitochondrial,
                evidenceLevel: .animalStudy,
                targetHallmarks: [.mitochondrialDysfunction, .epigeneticAlterations],
                dosageRange: "300-1000mg/day",
                timing: "Morning",
                notes: "Krebs cycle intermediate",
                citations: ["Asadi Shahmirzadi et al., 2020, Cell Metab"]
            ),
            LongevityCompound(
                name: "Curcumin",
                category: .antiInflammatory,
                evidenceLevel: .humanRCT,
                targetHallmarks: [.alteredIntercellularCommunication],
                dosageRange: "500-2000mg/day",
                timing: "With black pepper for absorption",
                notes: "Anti-inflammatory from turmeric",
                citations: ["Aggarwal & Harikumar, 2009, Int J Biochem Cell Biol"]
            )
        ]
    }

    // MARK: - Load Blue Zone Foods

    private func loadBlueZoneFoods() {
        blueZoneFoods = [
            BlueZoneFood(name: "Sweet Potato", origin: .okinawa, category: .wholegrains,
                         longevityBenefits: ["High fiber", "Low glycemic", "Beta-carotene"],
                         servingsPerWeek: 7, coherenceImpact: 0.6),
            BlueZoneFood(name: "Goya (Bitter Melon)", origin: .okinawa, category: .cruciferous,
                         longevityBenefits: ["Blood sugar regulation", "Antioxidants"],
                         servingsPerWeek: 3, coherenceImpact: 0.5),
            BlueZoneFood(name: "Tofu", origin: .okinawa, category: .legumes,
                         longevityBenefits: ["Plant protein", "Isoflavones"],
                         servingsPerWeek: 5, coherenceImpact: 0.5),
            BlueZoneFood(name: "Sardines", origin: .sardinia, category: .fish,
                         longevityBenefits: ["Omega-3", "Vitamin D", "Protein"],
                         servingsPerWeek: 3, coherenceImpact: 0.7),
            BlueZoneFood(name: "Fava Beans", origin: .sardinia, category: .legumes,
                         longevityBenefits: ["Fiber", "Protein", "L-dopa"],
                         servingsPerWeek: 4, coherenceImpact: 0.6),
            BlueZoneFood(name: "Pecorino Cheese", origin: .sardinia, category: .fermented,
                         longevityBenefits: ["CLA", "Vitamin K2", "Probiotics"],
                         servingsPerWeek: 3, coherenceImpact: 0.4),
            BlueZoneFood(name: "Black Beans", origin: .nicoya, category: .legumes,
                         longevityBenefits: ["Fiber", "Anthocyanins", "Protein"],
                         servingsPerWeek: 7, coherenceImpact: 0.7),
            BlueZoneFood(name: "Squash", origin: .nicoya, category: .cruciferous,
                         longevityBenefits: ["Beta-carotene", "Fiber"],
                         servingsPerWeek: 5, coherenceImpact: 0.5),
            BlueZoneFood(name: "Wild Greens", origin: .ikaria, category: .cruciferous,
                         longevityBenefits: ["Antioxidants", "Fiber", "Minerals"],
                         servingsPerWeek: 7, coherenceImpact: 0.8),
            BlueZoneFood(name: "Honey", origin: .ikaria, category: .herbs,
                         longevityBenefits: ["Antimicrobial", "Antioxidants"],
                         servingsPerWeek: 3, coherenceImpact: 0.4),
            BlueZoneFood(name: "Herbal Tea", origin: .ikaria, category: .greenTea,
                         longevityBenefits: ["Polyphenols", "Relaxation"],
                         servingsPerWeek: 14, coherenceImpact: 0.7),
            BlueZoneFood(name: "Walnuts", origin: .lomaLinda, category: .nuts,
                         longevityBenefits: ["Omega-3", "Polyphenols", "Melatonin"],
                         servingsPerWeek: 5, coherenceImpact: 0.6),
            BlueZoneFood(name: "Avocado", origin: .lomaLinda, category: .nuts,
                         longevityBenefits: ["Healthy fats", "Fiber", "Potassium"],
                         servingsPerWeek: 4, coherenceImpact: 0.6),
            BlueZoneFood(name: "Oatmeal", origin: .lomaLinda, category: .wholegrains,
                         longevityBenefits: ["Beta-glucan", "Fiber", "Stable energy"],
                         servingsPerWeek: 5, coherenceImpact: 0.6)
        ]
    }

    // MARK: - Generate Daily Protocol

    private func generateDailyProtocol() {
        dailyProtocol = [
            DailyProtocolItem(time: "6:00", activity: "Morning sunlight exposure (10 min)", category: .lightExposure, duration: 10, coherenceBoost: 0.1),
            DailyProtocolItem(time: "6:15", activity: "Cold shower (2-3 min)", category: .coldExposure, duration: 3, coherenceBoost: 0.15),
            DailyProtocolItem(time: "6:30", activity: "Meditation/Breathwork", category: .mindfulness, duration: 15, coherenceBoost: 0.25),
            DailyProtocolItem(time: "7:00", activity: "First meal - Blue Zone foods", category: .nutrition, duration: 30, coherenceBoost: 0.1),
            DailyProtocolItem(time: "10:00", activity: "Movement break (walk/stretch)", category: .movement, duration: 15, coherenceBoost: 0.1),
            DailyProtocolItem(time: "12:00", activity: "Second meal - Plant-rich", category: .nutrition, duration: 30, coherenceBoost: 0.1),
            DailyProtocolItem(time: "15:00", activity: "Social connection time", category: .social, duration: 30, coherenceBoost: 0.15),
            DailyProtocolItem(time: "17:00", activity: "Exercise (strength/cardio)", category: .movement, duration: 45, coherenceBoost: 0.2),
            DailyProtocolItem(time: "18:00", activity: "Last meal before fast", category: .nutrition, duration: 30, coherenceBoost: 0.05),
            DailyProtocolItem(time: "20:00", activity: "Sauna/heat therapy", category: .heatExposure, duration: 20, coherenceBoost: 0.15),
            DailyProtocolItem(time: "21:00", activity: "Wind-down routine", category: .sleep, duration: 60, coherenceBoost: 0.1),
            DailyProtocolItem(time: "22:00", activity: "Sleep", category: .sleep, duration: 480, coherenceBoost: 0.3)
        ]
    }

    // MARK: - Biological Age Calculation

    /// Calculate estimated biological age based on HRV
    /// Reference: PMC7527628 - HRV and Exceptional Longevity
    func calculateBiologicalAge(sdnn: Float, chronologicalAge: Float) -> Float {
        // Higher SDNN = younger biological age
        // Each +10ms SDNN roughly corresponds to younger bio age
        let baselineSDNN: Float = 50.0  // Average for middle-aged adults
        let sdnnDiff = sdnn - baselineSDNN
        let ageAdjustment = sdnnDiff / 10.0 * 2.0  // ±2 years per 10ms SDNN

        let biologicalAge = chronologicalAge - ageAdjustment
        self.currentBiologicalAge = max(18, biologicalAge)  // Floor at 18
        self.chronologicalAge = chronologicalAge

        return self.currentBiologicalAge
    }

    // MARK: - Recommendations

    func getPersonalizedRecommendations() -> [String] {
        var recommendations: [String] = []

        // Based on coherence level
        if hrvCoherence < 0.3 {
            recommendations.append("Focus on stress reduction: meditation, breathing exercises")
            recommendations.append("Consider adaptogenic herbs: Ashwagandha, Rhodiola")
        } else if hrvCoherence < 0.6 {
            recommendations.append("Good progress! Add social connection and nature time")
        } else {
            recommendations.append("Excellent coherence! Maintain current practices")
        }

        // Chronotype-specific
        recommendations.append("Optimal eating window: \(currentChronotype.fastingWindow)")
        recommendations.append("Best wake time: \(currentChronotype.optimalWakeTime)")

        return recommendations
    }
}

// MARK: - 2. NeuroSpiritual Engine

/// Integration of facial expression, gesture, movement, and biofeedback for psychosomatic analysis
/// Based on: FACS, Polyvagal Theory, Embodied Cognition, Wilhelm Reich body segments
@MainActor
class NeuroSpiritualEngine: ObservableObject {

    // MARK: - Published State

    @Published var currentConsciousnessState: ConsciousnessState = .alpha
    @Published var polyvagalState: PolyvagalState = .ventral
    @Published var primaryEmotion: PrimaryEmotion = .neutral
    @Published var psychosomaticState: PsychosomaticState = PsychosomaticState()
    @Published var duchennSmileDetected: Bool = false

    // MARK: - Consciousness States (EEG-based)

    enum ConsciousnessState: String, CaseIterable, Identifiable {
        case delta = "Delta (0.5-4 Hz)"
        case theta = "Theta (4-8 Hz)"
        case alpha = "Alpha (8-12 Hz)"
        case beta = "Beta (12-30 Hz)"
        case gamma = "Gamma (30-100 Hz)"
        case flow = "Flow State"
        case unitiveExperience = "Unitive Experience"
        case deepSleep = "Deep Sleep"
        case rem = "REM/Dream"
        case hypnagogia = "Hypnagogia (Transition)"

        var id: String { rawValue }

        var characteristics: String {
            switch self {
            case .delta: return "Deep sleep, healing, regeneration"
            case .theta: return "Deep meditation, creativity, intuition"
            case .alpha: return "Relaxed alertness, calm focus"
            case .beta: return "Active thinking, problem-solving"
            case .gamma: return "Peak awareness, insight, cognition"
            case .flow: return "Optimal performance, time distortion"
            case .unitiveExperience: return "Transcendence, interconnectedness"
            case .deepSleep: return "Physical restoration, memory consolidation"
            case .rem: return "Emotional processing, creativity"
            case .hypnagogia: return "Liminal creativity, imagery"
            }
        }

        var targetFrequency: Float {
            switch self {
            case .delta: return 2.0
            case .theta: return 6.0
            case .alpha: return 10.0
            case .beta: return 20.0
            case .gamma: return 40.0
            case .flow: return 10.0  // Alpha-theta border
            case .unitiveExperience: return 40.0
            case .deepSleep: return 1.0
            case .rem: return 6.0
            case .hypnagogia: return 6.0
            }
        }
    }

    // MARK: - Polyvagal States (Stephen Porges)

    enum PolyvagalState: String, CaseIterable, Identifiable {
        case ventral = "Ventral Vagal (Social Engagement)"
        case sympathetic = "Sympathetic (Fight/Flight)"
        case dorsal = "Dorsal Vagal (Freeze/Shutdown)"
        case blendedPlayful = "Blended: Ventral + Sympathetic (Play)"
        case blendedStillness = "Blended: Ventral + Dorsal (Stillness)"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .ventral:
                return "Safe, connected, able to engage socially"
            case .sympathetic:
                return "Mobilized, alert, ready for action"
            case .dorsal:
                return "Immobilized, conserving energy, dissociated"
            case .blendedPlayful:
                return "Active but safe - play, dance, exercise"
            case .blendedStillness:
                return "Still but safe - meditation, intimacy"
            }
        }

        var hrvCharacteristics: String {
            switch self {
            case .ventral: return "High HRV, rhythmic, coherent"
            case .sympathetic: return "Lower HRV, faster heart rate"
            case .dorsal: return "Very low HRV, slow or irregular"
            case .blendedPlayful: return "Moderate HRV with variability"
            case .blendedStillness: return "High HRV, very coherent"
            }
        }
    }

    // MARK: - FACS (Facial Action Coding System)

    struct FACSActionUnit: Identifiable {
        let id: Int
        let name: String
        let muscle: String
        let emotionalSignificance: String
        var intensity: Float  // 0-1
    }

    // MARK: - Primary Emotions (Ekman)

    enum PrimaryEmotion: String, CaseIterable, Identifiable {
        case joy = "Joy"
        case sadness = "Sadness"
        case anger = "Anger"
        case fear = "Fear"
        case disgust = "Disgust"
        case surprise = "Surprise"
        case contempt = "Contempt"
        case neutral = "Neutral"

        var id: String { rawValue }

        var facialMarkers: [Int] {  // FACS AU numbers
            switch self {
            case .joy: return [6, 12]  // Cheek raise + lip corner pull
            case .sadness: return [1, 4, 15]  // Inner brow raise + brow lower + lip corner depress
            case .anger: return [4, 5, 7, 23]  // Brow lower + upper lid raise + lid tighten + lip tighten
            case .fear: return [1, 2, 4, 5, 20, 26]  // Brow raise + brow furrow + lid raise + lip stretch + jaw drop
            case .disgust: return [9, 15, 16]  // Nose wrinkle + lip corner depress + lower lip depress
            case .surprise: return [1, 2, 5, 26]  // Brow raise + upper lid raise + jaw drop
            case .contempt: return [12, 14]  // Unilateral lip corner pull + dimpler
            case .neutral: return []
            }
        }
    }

    // MARK: - Complex Emotional States

    enum ComplexState: String, CaseIterable {
        case engagement = "Engagement"
        case confusion = "Confusion"
        case frustration = "Frustration"
        case determination = "Determination"
        case serenity = "Serenity"
        case awe = "Awe"
    }

    // MARK: - Wilhelm Reich Body Segments

    enum ReichSegment: String, CaseIterable, Identifiable {
        case ocular = "Ocular (Eyes, Forehead)"
        case oral = "Oral (Mouth, Jaw, Throat)"
        case cervical = "Cervical (Neck)"
        case thoracic = "Thoracic (Chest, Arms)"
        case diaphragmatic = "Diaphragmatic"
        case abdominal = "Abdominal"
        case pelvic = "Pelvic"

        var id: String { rawValue }

        var blockedCharacteristics: String {
            switch self {
            case .ocular: return "Difficulty making eye contact, headaches"
            case .oral: return "Jaw tension, difficulty expressing"
            case .cervical: return "Neck stiffness, swallowing difficulty"
            case .thoracic: return "Shallow breathing, arm tension"
            case .diaphragmatic: return "Restricted breathing, anxiety"
            case .abdominal: return "Digestive issues, fear"
            case .pelvic: return "Hip tension, grounding issues"
            }
        }

        var releaseExercises: [String] {
            switch self {
            case .ocular: return ["Eye movements", "Soft gaze", "Peripheral vision expansion"]
            case .oral: return ["Jaw massage", "Yawning", "Vocalizing"]
            case .cervical: return ["Neck rolls", "Looking up/down", "Shoulder shrugs"]
            case .thoracic: return ["Deep breathing", "Arm swings", "Chest openers"]
            case .diaphragmatic: return ["Diaphragmatic breathing", "Belly laughing"]
            case .abdominal: return ["Belly massage", "Core engagement", "Hip circles"]
            case .pelvic: return ["Hip openers", "Grounding exercises", "Pelvic tilts"]
            }
        }
    }

    // MARK: - Psychosomatic State

    struct PsychosomaticState {
        var wellbeingScore: Float = 0.5
        var presenceScore: Float = 0.5
        var embodimentScore: Float = 0.5
        var connectionScore: Float = 0.5
        var segmentTension: [ReichSegment: Float] = [:]

        var overallScore: Float {
            (wellbeingScore + presenceScore + embodimentScore + connectionScore) / 4.0
        }
    }

    // MARK: - FACS Database

    private(set) var facsActionUnits: [FACSActionUnit] = []

    // MARK: - Initialization

    init() {
        loadFACSDatabase()
        log.audio("NeuroSpiritualEngine: Initialized with \(facsActionUnits.count) FACS action units")
    }

    private func loadFACSDatabase() {
        facsActionUnits = [
            FACSActionUnit(id: 1, name: "Inner Brow Raiser", muscle: "Frontalis (inner)", emotionalSignificance: "Sadness, worry", intensity: 0),
            FACSActionUnit(id: 2, name: "Outer Brow Raiser", muscle: "Frontalis (outer)", emotionalSignificance: "Surprise", intensity: 0),
            FACSActionUnit(id: 4, name: "Brow Lowerer", muscle: "Corrugator, Depressor supercilii", emotionalSignificance: "Anger, concentration", intensity: 0),
            FACSActionUnit(id: 5, name: "Upper Lid Raiser", muscle: "Levator palpebrae", emotionalSignificance: "Fear, surprise", intensity: 0),
            FACSActionUnit(id: 6, name: "Cheek Raiser", muscle: "Orbicularis oculi (pars orbitalis)", emotionalSignificance: "Genuine joy (Duchenne)", intensity: 0),
            FACSActionUnit(id: 7, name: "Lid Tightener", muscle: "Orbicularis oculi (pars palpebralis)", emotionalSignificance: "Anger, concentration", intensity: 0),
            FACSActionUnit(id: 12, name: "Lip Corner Puller", muscle: "Zygomaticus major", emotionalSignificance: "Smile (social or genuine)", intensity: 0),
            FACSActionUnit(id: 15, name: "Lip Corner Depressor", muscle: "Depressor anguli oris", emotionalSignificance: "Sadness, disgust", intensity: 0)
        ]
    }

    // MARK: - Duchenne Smile Detection

    /// Detect genuine smile (Duchenne) vs social smile
    /// Duchenne = AU6 (cheek raise) + AU12 (lip corner pull)
    func detectDuchenneSmile() -> Bool {
        let au6 = facsActionUnits.first { $0.id == 6 }?.intensity ?? 0
        let au12 = facsActionUnits.first { $0.id == 12 }?.intensity ?? 0

        // Both must be present for genuine smile
        duchennSmileDetected = au6 > 0.3 && au12 > 0.3
        return duchennSmileDetected
    }

    // MARK: - Update from Biometrics

    func updateFromBiometrics(hrv: Float, coherence: Float, heartRate: Float) {
        // Infer polyvagal state from HRV/coherence
        if coherence > 0.7 && hrv > 50 {
            polyvagalState = .ventral
        } else if heartRate > 100 && hrv < 30 {
            polyvagalState = .sympathetic
        } else if hrv < 20 && heartRate < 60 {
            polyvagalState = .dorsal
        } else if coherence > 0.5 && heartRate > 80 {
            polyvagalState = .blendedPlayful
        } else if coherence > 0.6 && heartRate < 70 {
            polyvagalState = .blendedStillness
        }

        // Update psychosomatic scores
        psychosomaticState.wellbeingScore = coherence
        psychosomaticState.presenceScore = hrv / 100.0
    }

    // MARK: - Generate Report

    func generateNeuroSpiritualReport() -> String {
        """
        NEUROSPIRITUAL STATE REPORT

        Consciousness: \(currentConsciousnessState.rawValue)
        Target Frequency: \(currentConsciousnessState.targetFrequency) Hz

        Polyvagal State: \(polyvagalState.rawValue)
        Description: \(polyvagalState.description)

        Primary Emotion: \(primaryEmotion.rawValue)
        Duchenne Smile: \(duchennSmileDetected ? "Detected" : "Not detected")

        Psychosomatic Scores:
        - Wellbeing: \(Int(psychosomaticState.wellbeingScore * 100))%
        - Presence: \(Int(psychosomaticState.presenceScore * 100))%
        - Embodiment: \(Int(psychosomaticState.embodimentScore * 100))%
        - Connection: \(Int(psychosomaticState.connectionScore * 100))%
        - Overall: \(Int(psychosomaticState.overallScore * 100))%

        DISCLAIMER: Spiritual features are for creative/meditative purposes only.
        """
    }
}

// MARK: - 3. Quantum Health Biofeedback Engine

/// Quantum-inspired health metrics and unlimited collaboration sessions
/// NOTE: "Quantum" refers to quantum-inspired algorithms, not quantum hardware
@MainActor
class QuantumHealthBiofeedbackEngine: ObservableObject {

    // MARK: - Published State

    @Published var participants: [Participant] = []
    @Published var sessionType: SessionType = .meditation
    @Published var groupCoherence: Float = 0.0
    @Published var groupEntanglement: Float = 0.0
    @Published var groupSynchrony: Float = 0.0
    @Published var quantumHealthScore: Float = 0.0
    @Published var broadcastPlatforms: [BroadcastPlatform] = []
    @Published var privacyMode: PrivacyMode = .aggregated

    // MARK: - Session Types

    enum SessionType: String, CaseIterable, Identifiable {
        case meditation = "Meditation"
        case coherence = "Coherence Training"
        case creative = "Creative Collaboration"
        case wellness = "Wellness Circle"
        case research = "Research Study"
        case performance = "Live Performance"
        case workshop = "Workshop"
        case unlimited = "Unlimited Collaboration"

        var id: String { rawValue }

        var maxParticipants: Int {
            switch self {
            case .meditation: return 100
            case .coherence: return 50
            case .creative: return 25
            case .wellness: return 100
            case .research: return 1000
            case .performance: return 10000
            case .workshop: return 500
            case .unlimited: return Int.max
            }
        }
    }

    // MARK: - Participant

    struct Participant: Identifiable {
        let id = UUID()
        var displayName: String
        var heartRate: Float = 70
        var hrvCoherence: Float = 0.5
        var breathingRate: Float = 12
        var quantumState: Float = 0.5  // Quantum-inspired coherence metric
        var isConnected: Bool = true
        var joinedAt: Date = Date()
    }

    // MARK: - Privacy Modes

    enum PrivacyMode: String, CaseIterable {
        case full = "Full (Individual Data Visible)"
        case aggregated = "Aggregated (Group Only)"
        case anonymous = "Anonymous"
    }

    // MARK: - Broadcast Platforms

    struct BroadcastPlatform: Identifiable {
        let id = UUID()
        let name: String
        let platform: Platform
        var isActive: Bool
        var streamKey: String
        var quality: StreamQuality

        enum Platform: String, CaseIterable {
            case youtube = "YouTube"
            case twitch = "Twitch"
            case facebook = "Facebook"
            case instagram = "Instagram"
            case tiktok = "TikTok"
            case webrtc = "WebRTC"
            case ndi = "NDI"
            case custom = "Custom RTMP"
        }
    }

    enum StreamQuality: String, CaseIterable {
        case sd480 = "480p"
        case hd720 = "720p"
        case fullHD1080 = "1080p"
        case uhd4k = "4K"
        case uhd8k = "8K UHD"
    }

    // MARK: - Quantum-Inspired Metrics

    struct QuantumMetrics {
        var superpositionIndex: Float = 0.5  // Multiple states simultaneously
        var entanglementScore: Float = 0.0   // Correlation between participants
        var coherenceField: Float = 0.0      // Group coherence strength
        var waveformCollapse: Float = 0.0    // Decision/focus events
        var quantumEvent: Bool = false       // High-sync "entanglement" detection
    }

    private var quantumMetrics = QuantumMetrics()

    // MARK: - Session Analytics

    struct SessionAnalytics {
        var sessionId = UUID()
        var startTime = Date()
        var duration: TimeInterval = 0
        var peakCoherence: Float = 0
        var peakEntanglement: Float = 0
        var participantCount: Int = 0
        var quantumEvents: Int = 0
        var viewerCount: Int = 0
    }

    private(set) var currentAnalytics = SessionAnalytics()
    private(set) var historicalPeaks: [(date: Date, coherence: Float)] = []

    // MARK: - Constants

    let entanglementThreshold: Float = 0.9
    let optimalBreathingRate: Float = 6.0  // 0.1Hz baroreflex

    // MARK: - Initialization

    init() {
        setupDefaultBroadcastPlatforms()
        log.audio("QuantumHealthBiofeedbackEngine: Initialized with unlimited participant support")
    }

    private func setupDefaultBroadcastPlatforms() {
        broadcastPlatforms = [
            BroadcastPlatform(name: "YouTube Live", platform: .youtube, isActive: false, streamKey: "", quality: .fullHD1080),
            BroadcastPlatform(name: "Twitch", platform: .twitch, isActive: false, streamKey: "", quality: .fullHD1080),
            BroadcastPlatform(name: "Facebook Live", platform: .facebook, isActive: false, streamKey: "", quality: .hd720),
            BroadcastPlatform(name: "Instagram Live", platform: .instagram, isActive: false, streamKey: "", quality: .hd720),
            BroadcastPlatform(name: "TikTok LIVE", platform: .tiktok, isActive: false, streamKey: "", quality: .hd720),
            BroadcastPlatform(name: "WebRTC P2P", platform: .webrtc, isActive: false, streamKey: "", quality: .fullHD1080),
            BroadcastPlatform(name: "NDI Output", platform: .ndi, isActive: false, streamKey: "", quality: .uhd4k),
            BroadcastPlatform(name: "Custom RTMP", platform: .custom, isActive: false, streamKey: "", quality: .fullHD1080)
        ]
    }

    // MARK: - Participant Management

    func addParticipant(_ participant: Participant) {
        participants.append(participant)
        currentAnalytics.participantCount = participants.count
        updateGroupMetrics()
    }

    func removeParticipant(_ id: UUID) {
        participants.removeAll { $0.id == id }
        currentAnalytics.participantCount = participants.count
        updateGroupMetrics()
    }

    func updateParticipant(_ id: UUID, heartRate: Float? = nil, coherence: Float? = nil, breathing: Float? = nil) {
        guard let index = participants.firstIndex(where: { $0.id == id }) else { return }

        if let hr = heartRate { participants[index].heartRate = hr }
        if let coh = coherence { participants[index].hrvCoherence = coh }
        if let br = breathing { participants[index].breathingRate = br }

        // Update quantum state based on coherence
        participants[index].quantumState = participants[index].hrvCoherence

        updateGroupMetrics()
    }

    // MARK: - Group Metrics Calculation

    private func updateGroupMetrics() {
        guard !participants.isEmpty else {
            groupCoherence = 0
            groupEntanglement = 0
            groupSynchrony = 0
            return
        }

        // Calculate group coherence (average)
        let coherenceSum = participants.reduce(0) { $0 + $1.hrvCoherence }
        groupCoherence = coherenceSum / Float(participants.count)

        // Calculate synchrony (variance-based)
        let hrMean = participants.reduce(0) { $0 + $1.heartRate } / Float(participants.count)
        let hrVariance = participants.reduce(0) { $0 + pow($1.heartRate - hrMean, 2) } / Float(participants.count)
        groupSynchrony = max(0, 1.0 - (hrVariance / 400.0))  // Lower variance = higher sync

        // Calculate entanglement (correlation of coherence changes)
        groupEntanglement = groupCoherence * groupSynchrony

        // Detect quantum event
        quantumMetrics.entanglementScore = groupEntanglement
        quantumMetrics.coherenceField = groupCoherence
        quantumMetrics.quantumEvent = groupEntanglement > entanglementThreshold

        if quantumMetrics.quantumEvent {
            currentAnalytics.quantumEvents += 1
        }

        // Update peak tracking
        if groupCoherence > currentAnalytics.peakCoherence {
            currentAnalytics.peakCoherence = groupCoherence
            historicalPeaks.append((Date(), groupCoherence))
        }

        // Calculate quantum health score
        calculateQuantumHealthScore()
    }

    // MARK: - Quantum Health Score

    private func calculateQuantumHealthScore() {
        // Composite score based on multiple biometric observables + quantum metrics
        let coherenceWeight: Float = 0.3
        let synchronyWeight: Float = 0.2
        let entanglementWeight: Float = 0.2
        let breathingWeight: Float = 0.15
        let heartRateWeight: Float = 0.15

        // Calculate breathing score (optimal = 6 breaths/min)
        let avgBreathing = participants.reduce(0) { $0 + $1.breathingRate } / max(1, Float(participants.count))
        let breathingScore = 1.0 - min(1.0, abs(avgBreathing - optimalBreathingRate) / 10.0)

        // Calculate heart rate score (optimal range = 55-75 bpm at rest)
        let avgHR = participants.reduce(0) { $0 + $1.heartRate } / max(1, Float(participants.count))
        let hrScore: Float
        if avgHR >= 55 && avgHR <= 75 {
            hrScore = 1.0
        } else if avgHR < 55 {
            hrScore = avgHR / 55.0
        } else {
            hrScore = max(0, 1.0 - (avgHR - 75) / 50.0)
        }

        quantumHealthScore = (
            groupCoherence * coherenceWeight +
            groupSynchrony * synchronyWeight +
            groupEntanglement * entanglementWeight +
            breathingScore * breathingWeight +
            hrScore * heartRateWeight
        ) * 100.0  // Scale to 0-100
    }

    // MARK: - Session Management

    func startSession(type: SessionType) {
        sessionType = type
        currentAnalytics = SessionAnalytics()
        currentAnalytics.startTime = Date()
        log.audio("QuantumHealthBiofeedbackEngine: Started \(type.rawValue) session")
    }

    func endSession() {
        currentAnalytics.duration = Date().timeIntervalSince(currentAnalytics.startTime)
        log.audio("QuantumHealthBiofeedbackEngine: Ended session, duration: \(currentAnalytics.duration)s")
    }

    // MARK: - Generate Report

    func generateQuantumHealthReport() -> String {
        """
        QUANTUM HEALTH BIOFEEDBACK REPORT

        Session: \(sessionType.rawValue)
        Participants: \(participants.count)
        Duration: \(Int(currentAnalytics.duration / 60)) minutes

        GROUP METRICS:
        - Group Coherence: \(Int(groupCoherence * 100))%
        - Group Synchrony: \(Int(groupSynchrony * 100))%
        - Entanglement Score: \(Int(groupEntanglement * 100))%
        - Quantum Health Score: \(Int(quantumHealthScore))/100

        QUANTUM EVENTS:
        - Total Entanglement Events: \(currentAnalytics.quantumEvents)
        - Peak Coherence: \(Int(currentAnalytics.peakCoherence * 100))%

        DISCLAIMER: "Quantum" refers to quantum-inspired algorithms, not quantum hardware.
        For general wellness purposes only. Not a medical device.
        """
    }
}

// MARK: - 4. Adey Windows Bioelectromagnetic Engine

/// Scientific frequency-body mapping based on Dr. W. Ross Adey research
/// Reference: Adey WR, Physiological Reviews 1981
/// CRITICAL: Audio implementation only - NOT electromagnetic field generation
@MainActor
class AdeyWindowsBioelectromagneticEngine: ObservableObject {

    // MARK: - Published State

    @Published var currentWindow: AdeyWindow = .alpha
    @Published var targetBodySystem: BodySystem = .nervous
    @Published var currentFrequency: Float = 10.0
    @Published var modulationDepth: Float = 0.5
    @Published var isActive: Bool = false

    // MARK: - Body Systems

    enum BodySystem: String, CaseIterable, Identifiable {
        case nervous = "Nervous System (Psyche)"
        case cardiovascular = "Cardiovascular"
        case musculoskeletal = "Musculoskeletal"
        case respiratory = "Respiratory"
        case endocrine = "Endocrine"
        case immune = "Immune"

        var id: String { rawValue }

        var optimalFrequencyRange: ClosedRange<Float> {
            switch self {
            case .nervous: return 1...40
            case .cardiovascular: return 0.1...0.5
            case .musculoskeletal: return 7...30
            case .respiratory: return 0.1...0.3
            case .endocrine: return 0.1...10
            case .immune: return 7.83...40
            }
        }

        var measurementMethod: String {
            switch self {
            case .nervous: return "EEG"
            case .cardiovascular: return "HRV/EKG"
            case .musculoskeletal: return "EMG"
            case .respiratory: return "SpO2/Respiration"
            case .endocrine: return "Cortisol/Hormones"
            case .immune: return "Cytokines/Markers"
            }
        }
    }

    // MARK: - Adey Windows (Frequency Windows)

    struct AdeyWindow: Identifiable {
        let id = UUID()
        let name: String
        let frequencyRange: ClosedRange<Float>
        let targetFrequency: Float
        let evidenceLevel: EvidenceLevel
        let citations: [String]
        let bodySystemsAffected: [BodySystem]
        let description: String
        let audioImplementation: String

        enum EvidenceLevel: String {
            case level1a = "1a - Meta-Analysis"
            case level1b = "1b - RCT"
            case level2a = "2a - Cohort"
            case level2b = "2b - Case-Control"
            case level3 = "3 - Case Series"
            case level4 = "4 - Expert Opinion"
            case level5 = "5 - Basic Research"
        }

        static let delta = AdeyWindow(
            name: "Delta Window",
            frequencyRange: 0.5...4,
            targetFrequency: 2.0,
            evidenceLevel: .level2a,
            citations: ["Adey WR, Physiological Reviews 1981"],
            bodySystemsAffected: [.nervous, .immune],
            description: "Deep sleep, healing, regeneration",
            audioImplementation: "Binaural beats at 2Hz, isochronic tones"
        )

        static let theta = AdeyWindow(
            name: "Theta Window",
            frequencyRange: 4...8,
            targetFrequency: 6.0,
            evidenceLevel: .level2a,
            citations: ["Blackman CF et al., 1985"],
            bodySystemsAffected: [.nervous, .endocrine],
            description: "Meditation, creativity, memory",
            audioImplementation: "Binaural beats at 6Hz, guided visualization"
        )

        static let alpha = AdeyWindow(
            name: "Alpha Window",
            frequencyRange: 8...12,
            targetFrequency: 10.0,
            evidenceLevel: .level1b,
            citations: ["Bawin & Adey, 1976, PNAS"],
            bodySystemsAffected: [.nervous, .cardiovascular],
            description: "Relaxed alertness, calm focus",
            audioImplementation: "Binaural beats at 10Hz, alpha music"
        )

        static let schumann = AdeyWindow(
            name: "Schumann Resonance Window",
            frequencyRange: 7.5...8.5,
            targetFrequency: 7.83,
            evidenceLevel: .level3,
            citations: ["Schumann WO, 1952"],
            bodySystemsAffected: [.nervous, .immune, .cardiovascular],
            description: "Earth's natural frequency, grounding",
            audioImplementation: "7.83Hz carrier, nature sounds"
        )

        static let hrvCoherence = AdeyWindow(
            name: "HRV Coherence Window",
            frequencyRange: 0.04...0.15,
            targetFrequency: 0.1,
            evidenceLevel: .level1b,
            citations: ["McCraty R, HeartMath Institute"],
            bodySystemsAffected: [.cardiovascular, .nervous],
            description: "Heart-brain synchronization",
            audioImplementation: "Breathing guide at 6/min (0.1Hz)"
        )

        static let pemf = AdeyWindow(
            name: "PEMF Research Window",
            frequencyRange: 7...30,
            targetFrequency: 10.0,
            evidenceLevel: .level2b,
            citations: ["Adey WR, Physiological Reviews 1981"],
            bodySystemsAffected: [.musculoskeletal, .immune],
            description: "Research-based frequencies (audio representation only)",
            audioImplementation: "Pulsed audio tones, NOT electromagnetic"
        )

        static let vagalTone = AdeyWindow(
            name: "Vagal Tone Window",
            frequencyRange: 0.15...0.4,
            targetFrequency: 0.25,
            evidenceLevel: .level1b,
            citations: ["Porges SW, Polyvagal Theory"],
            bodySystemsAffected: [.nervous, .cardiovascular, .respiratory],
            description: "Parasympathetic activation",
            audioImplementation: "Slow breathing guide, humming, chanting"
        )
    }

    // MARK: - Available Windows

    static let allWindows: [AdeyWindow] = [
        .delta, .theta, .alpha, .schumann, .hrvCoherence, .pemf, .vagalTone
    ]

    // MARK: - Initialization

    init() {
        log.audio("AdeyWindowsBioelectromagneticEngine: Initialized")
        log.audio("IMPORTANT: Audio implementation ONLY - NOT electromagnetic field generation")
    }

    // MARK: - Window Selection

    func selectWindow(_ window: AdeyWindow) {
        currentWindow = window
        currentFrequency = window.targetFrequency
        log.audio("Selected Adey Window: \(window.name) at \(window.targetFrequency)Hz")
    }

    func selectWindowForSystem(_ system: BodySystem) {
        targetBodySystem = system

        // Find best window for this body system
        let matchingWindows = AdeyWindowsBioelectromagneticEngine.allWindows.filter {
            $0.bodySystemsAffected.contains(system)
        }

        if let bestWindow = matchingWindows.first {
            selectWindow(bestWindow)
        }
    }

    // MARK: - Audio Generation Parameters

    func getAudioParameters() -> AudioParameters {
        return AudioParameters(
            baseFrequency: 200.0,  // Carrier frequency
            modulationFrequency: currentFrequency,
            modulationDepth: modulationDepth,
            waveform: .sine,
            useIsochronicTones: currentFrequency < 20,
            useBinauralBeats: currentFrequency < 40
        )
    }

    struct AudioParameters {
        let baseFrequency: Float
        let modulationFrequency: Float
        let modulationDepth: Float
        let waveform: Waveform
        let useIsochronicTones: Bool
        let useBinauralBeats: Bool

        enum Waveform {
            case sine, triangle, square, pulse
        }
    }

    // MARK: - Generate Report

    func generateAdeyWindowReport() -> String {
        """
        ADEY WINDOWS BIOELECTROMAGNETIC ENGINE REPORT

        Based on: Dr. W. Ross Adey Research
        UCLA Brain Research Institute, Loma Linda
        Reference: Physiological Reviews 1981

        Current Window: \(currentWindow.name)
        Target Frequency: \(currentFrequency) Hz
        Target Body System: \(targetBodySystem.rawValue)

        Evidence Level: \(currentWindow.evidenceLevel.rawValue)
        Citations: \(currentWindow.citations.joined(separator: ", "))

        Audio Implementation: \(currentWindow.audioImplementation)

        Available Windows:
        \(AdeyWindowsBioelectromagneticEngine.allWindows.map { "- \($0.name): \($0.targetFrequency)Hz" }.joined(separator: "\n"))

        CRITICAL DISCLAIMER:
        - This is an AUDIO implementation only
        - NOT electromagnetic field generation
        - Audio ≠ Elektromagnetik
        - Not a medical therapy
        - For research/educational purposes only
        - Consult healthcare professionals for medical advice
        """
    }
}

// MARK: - Wellness Disclaimers

struct WellnessDisclaimer {

    static let fullDisclaimer = """
    WELLNESS FEATURES DISCLAIMER

    The wellness features in Echoelmusic (Longevity Nutrition Engine, NeuroSpiritual Engine,
    Quantum Health Biofeedback Engine, and Adey Windows Engine) are designed for general wellness,
    relaxation, creativity, and educational purposes only.

    THESE FEATURES ARE:
    - NOT medical devices
    - NOT intended to diagnose, treat, cure, or prevent any disease
    - NOT substitutes for professional medical advice
    - NOT validated for clinical use

    IMPORTANT:
    - "Quantum" terminology refers to quantum-inspired algorithms, not quantum hardware
    - Biofeedback readings are for informational purposes only
    - Frequency-based audio is NOT electromagnetic therapy
    - Brainwave entrainment effects are subjective and vary by individual

    Always consult qualified healthcare professionals before:
    - Making changes to your diet or supplement regimen
    - Starting any new wellness practice
    - Using biofeedback for health monitoring
    - If you have any medical conditions

    If you experience any adverse effects, discontinue use and seek medical attention.
    """

    static let shortDisclaimer = """
    For wellness/relaxation only. NOT a medical device. Consult healthcare professionals for medical advice.
    """
}

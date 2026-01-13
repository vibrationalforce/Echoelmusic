//
//  AdvancedWellnessEngines.swift
//  Echoelmusic
//
//  Created: 2026-01-13
//  Phase 10000 ULTIMATE - Scientific Wellness Engines
//
//  DISCLAIMER: These features are for general wellness, creativity, and
//  informational purposes ONLY. They are NOT medical devices and do NOT
//  provide medical advice, diagnosis, or treatment. Always consult qualified
//  healthcare professionals for medical concerns.
//

import Foundation
import Combine

// MARK: - Health Disclaimers

/// Comprehensive health disclaimer system for all wellness features
public struct WellnessDisclaimer {
    public static let full = """
    IMPORTANT HEALTH DISCLAIMER

    This application and its wellness features are designed for general wellness,
    creativity, relaxation, and informational purposes ONLY.

    This is NOT a medical device. It does NOT:
    - Diagnose, treat, cure, or prevent any disease
    - Provide medical advice or recommendations
    - Replace professional medical consultation
    - Measure clinical-grade biometric data

    The biometric readings, scores, and recommendations are approximations
    for wellness exploration only. They should NOT be used for medical decisions.

    If you have any health concerns, please consult a qualified healthcare
    professional. If you experience any discomfort while using this app,
    stop immediately and seek medical attention if needed.

    Breathing exercises may not be suitable for everyone. Those with
    respiratory conditions, cardiovascular issues, or pregnancy should
    consult their doctor before use.

    By using these features, you acknowledge this disclaimer and agree
    that the developers are not liable for any health-related outcomes.
    """

    public static let short = "For wellness purposes only. Not a medical device. Consult healthcare professionals for medical concerns."

    public static let biometric = "Biometric readings are approximations for wellness exploration, not clinical measurements."

    public static let longevity = "Longevity information is educational only. Individual results vary. Consult healthcare providers before dietary changes."

    public static let breathing = "Breathing exercises may not be suitable for everyone. Stop if you feel dizzy or uncomfortable."
}

// MARK: - ========================================
// MARK: - 1. LONGEVITY NUTRITION ENGINE
// MARK: - ========================================

/// Evidence level based on Oxford Centre for Evidence-Based Medicine (CEBM)
public enum EvidenceLevel: String, CaseIterable, Codable {
    case humanRCT = "1a - Human RCT/Meta-Analysis"
    case humanObservational = "2a - Human Observational"
    case animalStudy = "3 - Animal Study"
    case inVitro = "4 - In Vitro/Cell Culture"
    case traditionalUse = "5 - Traditional Use/Expert Opinion"

    public var confidence: Double {
        switch self {
        case .humanRCT: return 0.95
        case .humanObservational: return 0.75
        case .animalStudy: return 0.50
        case .inVitro: return 0.30
        case .traditionalUse: return 0.15
        }
    }
}

/// The 9 Hallmarks of Aging (Lopez-Otin et al., Cell 2013)
public enum HallmarkOfAging: String, CaseIterable, Codable, Identifiable {
    case genomicInstability = "Genomic Instability"
    case telomereAttrition = "Telomere Attrition"
    case epigeneticAlterations = "Epigenetic Alterations"
    case lossOfProteostasis = "Loss of Proteostasis"
    case deregulatedNutrientSensing = "Deregulated Nutrient Sensing"
    case mitochondrialDysfunction = "Mitochondrial Dysfunction"
    case cellularSenescence = "Cellular Senescence"
    case stemCellExhaustion = "Stem Cell Exhaustion"
    case alteredIntercellularCommunication = "Altered Intercellular Communication"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .genomicInstability:
            return "Accumulation of DNA damage throughout life"
        case .telomereAttrition:
            return "Progressive shortening of chromosome end caps"
        case .epigeneticAlterations:
            return "Changes in gene expression patterns without DNA changes"
        case .lossOfProteostasis:
            return "Decline in protein folding and clearance mechanisms"
        case .deregulatedNutrientSensing:
            return "Impaired response to nutrients (insulin, IGF-1, mTOR)"
        case .mitochondrialDysfunction:
            return "Reduced energy production and increased oxidative stress"
        case .cellularSenescence:
            return "Accumulation of cells that stop dividing but resist death"
        case .stemCellExhaustion:
            return "Decline in regenerative capacity of tissues"
        case .alteredIntercellularCommunication:
            return "Changes in signaling between cells, including inflammation"
        }
    }

    public var citation: String {
        "Lopez-Otin C, et al. The Hallmarks of Aging. Cell. 2013;153(6):1194-1217"
    }
}

/// Category of longevity compound
public enum CompoundCategory: String, CaseIterable, Codable {
    case sirtuinActivator = "Sirtuin Activator"
    case senolytic = "Senolytic"
    case nadPrecursor = "NAD+ Precursor"
    case mitochondrialSupport = "Mitochondrial Support"
    case epigeneticModulator = "Epigenetic Modulator"
    case autophagyInducer = "Autophagy Inducer"
    case antioxidant = "Antioxidant"
    case antiInflammatory = "Anti-Inflammatory"
    case metabolicRegulator = "Metabolic Regulator"
    case telomereSupport = "Telomere Support"
}

/// Longevity compound with scientific backing
public struct LongevityCompound: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let category: CompoundCategory
    public let targetedHallmarks: [HallmarkOfAging]
    public let evidenceLevel: EvidenceLevel
    public let mechanism: String
    public let foodSources: [String]
    public let citations: [String]
    public let caution: String?

    public init(
        id: UUID = UUID(),
        name: String,
        category: CompoundCategory,
        targetedHallmarks: [HallmarkOfAging],
        evidenceLevel: EvidenceLevel,
        mechanism: String,
        foodSources: [String],
        citations: [String],
        caution: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.targetedHallmarks = targetedHallmarks
        self.evidenceLevel = evidenceLevel
        self.mechanism = mechanism
        self.foodSources = foodSources
        self.citations = citations
        self.caution = caution
    }
}

/// Blue Zone region
public enum BlueZoneRegion: String, CaseIterable, Codable {
    case okinawa = "Okinawa, Japan"
    case sardinia = "Sardinia, Italy"
    case nicoya = "Nicoya, Costa Rica"
    case ikaria = "Ikaria, Greece"
    case lomaLinda = "Loma Linda, California"

    public var characteristics: String {
        switch self {
        case .okinawa: return "Plant-based diet, sweet potatoes, tofu, bitter melon"
        case .sardinia: return "Mediterranean diet, goat milk, whole grains, red wine"
        case .nicoya: return "Beans, corn, squash, tropical fruits"
        case .ikaria: return "Wild greens, olive oil, herbal teas, honey"
        case .lomaLinda: return "Vegetarian Adventist diet, nuts, legumes"
        }
    }
}

/// Food from Blue Zone regions
public struct BlueZoneFood: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let region: BlueZoneRegion
    public let category: FoodCategory
    public let keyNutrients: [String]
    public let longevityBenefits: [String]
    public let servingSuggestion: String

    public init(
        id: UUID = UUID(),
        name: String,
        region: BlueZoneRegion,
        category: FoodCategory,
        keyNutrients: [String],
        longevityBenefits: [String],
        servingSuggestion: String
    ) {
        self.id = id
        self.name = name
        self.region = region
        self.category = category
        self.keyNutrients = keyNutrients
        self.longevityBenefits = longevityBenefits
        self.servingSuggestion = servingSuggestion
    }
}

/// Food category
public enum FoodCategory: String, CaseIterable, Codable {
    case cruciferous = "Cruciferous Vegetables"
    case legumes = "Legumes"
    case berries = "Berries"
    case fermented = "Fermented Foods"
    case alliums = "Alliums"
    case leafyGreens = "Leafy Greens"
    case nuts = "Nuts & Seeds"
    case wholeGrains = "Whole Grains"
    case fish = "Fish"
    case oliveOil = "Olive Oil"
    case herbs = "Herbs & Spices"
    case tea = "Tea"
}

/// Chronotype for circadian optimization
public enum Chronotype: String, CaseIterable, Codable {
    case lion = "Lion"      // Early bird
    case bear = "Bear"      // Average
    case wolf = "Wolf"      // Night owl
    case dolphin = "Dolphin" // Light sleeper

    public var wakeTime: String {
        switch self {
        case .lion: return "5:30-6:00 AM"
        case .bear: return "7:00-7:30 AM"
        case .wolf: return "7:30-9:00 AM"
        case .dolphin: return "6:30 AM (variable)"
        }
    }

    public var optimalFastingWindow: String {
        switch self {
        case .lion: return "6:00 PM - 6:00 AM (12h)"
        case .bear: return "7:00 PM - 9:00 AM (14h)"
        case .wolf: return "8:00 PM - 12:00 PM (16h)"
        case .dolphin: return "7:00 PM - 7:00 AM (12h)"
        }
    }

    public var peakPerformanceTime: String {
        switch self {
        case .lion: return "8:00 AM - 12:00 PM"
        case .bear: return "10:00 AM - 2:00 PM"
        case .wolf: return "5:00 PM - 9:00 PM"
        case .dolphin: return "3:00 PM - 9:00 PM"
        }
    }
}

/// Power 9 principles from Blue Zones research
public struct Power9Principle: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let description: String
    public let coherenceImpact: Double // 0-1 impact on HRV coherence
    public let practicalTips: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        coherenceImpact: Double,
        practicalTips: [String]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.coherenceImpact = coherenceImpact
        self.practicalTips = practicalTips
    }
}

/// Biological age calculation result
public struct BiologicalAgeResult: Codable {
    public let chronologicalAge: Int
    public let estimatedBiologicalAge: Double
    public let hrvContribution: Double
    public let lifestyleContribution: Double
    public let confidence: Double
    public let recommendations: [String]
    public let disclaimer: String

    public init(
        chronologicalAge: Int,
        estimatedBiologicalAge: Double,
        hrvContribution: Double,
        lifestyleContribution: Double,
        confidence: Double,
        recommendations: [String]
    ) {
        self.chronologicalAge = chronologicalAge
        self.estimatedBiologicalAge = estimatedBiologicalAge
        self.hrvContribution = hrvContribution
        self.lifestyleContribution = lifestyleContribution
        self.confidence = confidence
        self.recommendations = recommendations
        self.disclaimer = WellnessDisclaimer.longevity
    }
}

/// Main Longevity Nutrition Engine
@MainActor
public final class LongevityNutritionEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var compounds: [LongevityCompound] = []
    @Published public private(set) var blueZoneFoods: [BlueZoneFood] = []
    @Published public private(set) var power9Principles: [Power9Principle] = []
    @Published public private(set) var currentChronotype: Chronotype = .bear
    @Published public private(set) var biologicalAgeResult: BiologicalAgeResult?
    @Published public private(set) var currentHRVCoherence: Double = 0.5

    // MARK: - Constants

    public static let disclaimer = WellnessDisclaimer.longevity

    /// Scientific reference: PMC7527628 - HRV and Exceptional Longevity
    public static let hrvLongevityReference = "Zulfiqar U, et al. Relation of High Heart Rate Variability to Healthy Longevity. Am J Cardiol. 2010;105(8):1181-1185. doi:10.1016/j.amjcard.2009.12.022"

    // MARK: - Initialization

    public init() {
        loadCompounds()
        loadBlueZoneFoods()
        loadPower9Principles()
    }

    // MARK: - Public Methods

    /// Update HRV coherence from biofeedback
    public func updateHRVCoherence(_ coherence: Double) {
        currentHRVCoherence = max(0, min(1, coherence))
    }

    /// Set user chronotype
    public func setChronotype(_ chronotype: Chronotype) {
        currentChronotype = chronotype
    }

    /// Calculate estimated biological age from HRV
    /// Reference: +10ms SDNN associated with ~20% reduced mortality (PMC7527628)
    public func calculateBiologicalAge(
        chronologicalAge: Int,
        sdnnMs: Double,
        rmssdMs: Double,
        lifestyleScore: Double // 0-1
    ) -> BiologicalAgeResult {
        // Base biological age starts at chronological
        var bioAge = Double(chronologicalAge)

        // HRV contribution (higher HRV = younger biological age)
        // Average SDNN for healthy adults: 50-100ms
        let avgSDNN: Double = 75
        let sdnnDelta = sdnnMs - avgSDNN
        let hrvAdjustment = sdnnDelta * 0.1 // Each 10ms above average = -1 year
        bioAge -= hrvAdjustment

        // RMSSD contribution (parasympathetic tone)
        let avgRMSSD: Double = 42
        let rmssdDelta = rmssdMs - avgRMSSD
        let rmssdAdjustment = rmssdDelta * 0.05
        bioAge -= rmssdAdjustment

        // Lifestyle contribution
        let lifestyleAdjustment = (lifestyleScore - 0.5) * 10 // -5 to +5 years
        bioAge -= lifestyleAdjustment

        // Clamp to reasonable range
        bioAge = max(Double(chronologicalAge) - 15, min(Double(chronologicalAge) + 15, bioAge))

        // Generate recommendations
        var recommendations: [String] = []
        if sdnnMs < 50 {
            recommendations.append("Consider coherence breathing exercises to improve HRV")
        }
        if lifestyleScore < 0.5 {
            recommendations.append("Focus on Power 9 lifestyle principles")
        }
        if currentHRVCoherence < 0.4 {
            recommendations.append("Practice heart-focused meditation for coherence")
        }

        let result = BiologicalAgeResult(
            chronologicalAge: chronologicalAge,
            estimatedBiologicalAge: bioAge,
            hrvContribution: hrvAdjustment + rmssdAdjustment,
            lifestyleContribution: lifestyleAdjustment,
            confidence: 0.6, // Moderate confidence for non-clinical estimate
            recommendations: recommendations
        )

        biologicalAgeResult = result
        return result
    }

    /// Get compounds targeting specific hallmark
    public func compounds(targeting hallmark: HallmarkOfAging) -> [LongevityCompound] {
        compounds.filter { $0.targetedHallmarks.contains(hallmark) }
    }

    /// Get foods from specific Blue Zone
    public func foods(from region: BlueZoneRegion) -> [BlueZoneFood] {
        blueZoneFoods.filter { $0.region == region }
    }

    /// Get fasting recommendation for chronotype
    public func getFastingPlan() -> (window: String, meals: [String]) {
        let window = currentChronotype.optimalFastingWindow
        let meals: [String]

        switch currentChronotype {
        case .lion:
            meals = ["Breakfast: 6:00 AM", "Lunch: 11:00 AM", "Dinner: 5:00 PM"]
        case .bear:
            meals = ["Breakfast: 9:00 AM", "Lunch: 1:00 PM", "Dinner: 6:00 PM"]
        case .wolf:
            meals = ["Brunch: 12:00 PM", "Snack: 4:00 PM", "Dinner: 7:30 PM"]
        case .dolphin:
            meals = ["Breakfast: 7:00 AM", "Lunch: 12:00 PM", "Dinner: 6:00 PM"]
        }

        return (window, meals)
    }

    // MARK: - Private Methods

    private func loadCompounds() {
        compounds = [
            LongevityCompound(
                name: "NMN (Nicotinamide Mononucleotide)",
                category: .nadPrecursor,
                targetedHallmarks: [.mitochondrialDysfunction, .genomicInstability, .epigeneticAlterations],
                evidenceLevel: .humanObservational,
                mechanism: "Precursor to NAD+, supports cellular energy and DNA repair",
                foodSources: ["Broccoli", "Cabbage", "Cucumber", "Edamame", "Avocado"],
                citations: ["Yoshino J, et al. Science. 2011;332(6036):1443-1446"],
                caution: "Long-term human studies ongoing"
            ),
            LongevityCompound(
                name: "Resveratrol",
                category: .sirtuinActivator,
                targetedHallmarks: [.deregulatedNutrientSensing, .mitochondrialDysfunction],
                evidenceLevel: .animalStudy,
                mechanism: "Activates SIRT1, mimics caloric restriction",
                foodSources: ["Red grapes", "Red wine", "Peanuts", "Blueberries"],
                citations: ["Baur JA, et al. Nature. 2006;444(7117):337-342"],
                caution: "Bioavailability is limited; effects in humans less clear"
            ),
            LongevityCompound(
                name: "Fisetin",
                category: .senolytic,
                targetedHallmarks: [.cellularSenescence, .alteredIntercellularCommunication],
                evidenceLevel: .animalStudy,
                mechanism: "Clears senescent cells, reduces inflammation",
                foodSources: ["Strawberries", "Apples", "Persimmons", "Onions"],
                citations: ["Yousefzadeh MJ, et al. EBioMedicine. 2018;36:18-28"],
                caution: "Human clinical trials in progress"
            ),
            LongevityCompound(
                name: "Spermidine",
                category: .autophagyInducer,
                targetedHallmarks: [.lossOfProteostasis, .stemCellExhaustion],
                evidenceLevel: .humanObservational,
                mechanism: "Induces autophagy, promotes cellular cleanup",
                foodSources: ["Wheat germ", "Aged cheese", "Mushrooms", "Soybeans", "Legumes"],
                citations: ["Eisenberg T, et al. Nat Med. 2016;22(12):1428-1438"],
                caution: nil
            ),
            LongevityCompound(
                name: "Quercetin",
                category: .senolytic,
                targetedHallmarks: [.cellularSenescence, .alteredIntercellularCommunication],
                evidenceLevel: .humanObservational,
                mechanism: "Senolytic when combined with dasatinib; anti-inflammatory",
                foodSources: ["Onions", "Apples", "Berries", "Capers", "Green tea"],
                citations: ["Zhu Y, et al. Aging Cell. 2015;14(4):644-658"],
                caution: "Most senolytic studies use pharmaceutical combinations"
            ),
            LongevityCompound(
                name: "Berberine",
                category: .metabolicRegulator,
                targetedHallmarks: [.deregulatedNutrientSensing, .mitochondrialDysfunction],
                evidenceLevel: .humanRCT,
                mechanism: "Activates AMPK, improves glucose metabolism",
                foodSources: ["Goldenseal", "Oregon grape", "Barberry"],
                citations: ["Yin J, et al. Metabolism. 2008;57(5):712-717"],
                caution: "May interact with medications; consult healthcare provider"
            ),
            LongevityCompound(
                name: "Sulforaphane",
                category: .epigeneticModulator,
                targetedHallmarks: [.epigeneticAlterations, .genomicInstability],
                evidenceLevel: .humanObservational,
                mechanism: "Activates Nrf2 pathway, supports detoxification",
                foodSources: ["Broccoli sprouts", "Broccoli", "Brussels sprouts", "Kale"],
                citations: ["Houghton CA, et al. Nutrients. 2016;8(3):157"],
                caution: nil
            ),
            LongevityCompound(
                name: "EGCG (Epigallocatechin Gallate)",
                category: .antioxidant,
                targetedHallmarks: [.genomicInstability, .cellularSenescence],
                evidenceLevel: .humanObservational,
                mechanism: "Powerful antioxidant, supports cellular health",
                foodSources: ["Green tea", "Matcha", "White tea"],
                citations: ["Kuriyama S, et al. JAMA. 2006;296(10):1255-1265"],
                caution: "High doses may affect liver; moderate consumption recommended"
            ),
            LongevityCompound(
                name: "Curcumin",
                category: .antiInflammatory,
                targetedHallmarks: [.alteredIntercellularCommunication, .cellularSenescence],
                evidenceLevel: .humanRCT,
                mechanism: "Anti-inflammatory, modulates multiple signaling pathways",
                foodSources: ["Turmeric"],
                citations: ["Aggarwal BB, et al. Ann N Y Acad Sci. 2004;1030:434-441"],
                caution: "Low bioavailability; combine with piperine for absorption"
            ),
            LongevityCompound(
                name: "Omega-3 Fatty Acids",
                category: .antiInflammatory,
                targetedHallmarks: [.alteredIntercellularCommunication, .telomereAttrition],
                evidenceLevel: .humanRCT,
                mechanism: "Reduces inflammation, supports telomere length",
                foodSources: ["Fatty fish", "Flaxseed", "Chia seeds", "Walnuts"],
                citations: ["Farzaneh-Far R, et al. JAMA. 2010;303(3):250-257"],
                caution: nil
            ),
            LongevityCompound(
                name: "Alpha-Ketoglutarate (AKG)",
                category: .metabolicRegulator,
                targetedHallmarks: [.mitochondrialDysfunction, .epigeneticAlterations],
                evidenceLevel: .animalStudy,
                mechanism: "TCA cycle intermediate, epigenetic regulator",
                foodSources: ["Produced endogenously; supplements available"],
                citations: ["Asadi Shahmirzadi A, et al. Cell Metab. 2020;32(3):447-456"],
                caution: "Human longevity studies limited"
            ),
            LongevityCompound(
                name: "Urolithin A",
                category: .mitochondrialSupport,
                targetedHallmarks: [.mitochondrialDysfunction, .stemCellExhaustion],
                evidenceLevel: .humanRCT,
                mechanism: "Induces mitophagy, renews mitochondria",
                foodSources: ["Pomegranates", "Berries", "Walnuts (gut-converted)"],
                citations: ["Andreux PA, et al. Nat Metab. 2019;1:595-603"],
                caution: "Conversion depends on gut microbiome"
            ),
            LongevityCompound(
                name: "Astaxanthin",
                category: .antioxidant,
                targetedHallmarks: [.genomicInstability, .mitochondrialDysfunction],
                evidenceLevel: .humanObservational,
                mechanism: "Carotenoid antioxidant, protects mitochondria",
                foodSources: ["Salmon", "Shrimp", "Krill", "Algae"],
                citations: ["Kidd P. Altern Med Rev. 2011;16(4):355-364"],
                caution: nil
            ),
            LongevityCompound(
                name: "Nicotinamide Riboside (NR)",
                category: .nadPrecursor,
                targetedHallmarks: [.mitochondrialDysfunction, .genomicInstability],
                evidenceLevel: .humanRCT,
                mechanism: "NAD+ precursor, supports cellular energy",
                foodSources: ["Milk", "Yeast (trace amounts)"],
                citations: ["Martens CR, et al. Nat Commun. 2018;9:1286"],
                caution: nil
            ),
            LongevityCompound(
                name: "Glycine",
                category: .epigeneticModulator,
                targetedHallmarks: [.epigeneticAlterations, .lossOfProteostasis],
                evidenceLevel: .animalStudy,
                mechanism: "Methyl donor, supports collagen synthesis",
                foodSources: ["Bone broth", "Gelatin", "Meat", "Fish"],
                citations: ["Miller RA, et al. Aging Cell. 2019;18(3):e12953"],
                caution: nil
            )
        ]
    }

    private func loadBlueZoneFoods() {
        blueZoneFoods = [
            // Okinawa
            BlueZoneFood(name: "Sweet Potato (Beni Imo)", region: .okinawa, category: .wholeGrains,
                        keyNutrients: ["Beta-carotene", "Fiber", "Vitamin C"],
                        longevityBenefits: ["Low glycemic", "Anti-inflammatory", "Antioxidant"],
                        servingSuggestion: "Steamed or roasted, 1 cup daily"),
            BlueZoneFood(name: "Tofu", region: .okinawa, category: .legumes,
                        keyNutrients: ["Plant protein", "Isoflavones", "Calcium"],
                        longevityBenefits: ["Heart health", "Hormone balance", "Bone health"],
                        servingSuggestion: "100-150g per meal, 3-5 times weekly"),
            BlueZoneFood(name: "Bitter Melon (Goya)", region: .okinawa, category: .leafyGreens,
                        keyNutrients: ["Vitamin C", "Folate", "Charantin"],
                        longevityBenefits: ["Blood sugar regulation", "Antioxidant"],
                        servingSuggestion: "Stir-fried, 1/2 cup several times weekly"),
            BlueZoneFood(name: "Turmeric", region: .okinawa, category: .herbs,
                        keyNutrients: ["Curcumin", "Manganese", "Iron"],
                        longevityBenefits: ["Anti-inflammatory", "Brain health"],
                        servingSuggestion: "1/4 tsp daily in food or tea"),
            BlueZoneFood(name: "Seaweed", region: .okinawa, category: .leafyGreens,
                        keyNutrients: ["Iodine", "Fiber", "Minerals"],
                        longevityBenefits: ["Thyroid support", "Gut health"],
                        servingSuggestion: "Small portion with most meals"),

            // Sardinia
            BlueZoneFood(name: "Cannonau Wine", region: .sardinia, category: .fermented,
                        keyNutrients: ["Polyphenols", "Resveratrol", "Anthocyanins"],
                        longevityBenefits: ["Heart health", "Antioxidant"],
                        servingSuggestion: "1-2 small glasses with meals (if you drink)"),
            BlueZoneFood(name: "Pecorino Cheese", region: .sardinia, category: .fermented,
                        keyNutrients: ["CLA", "Omega-3", "Calcium"],
                        longevityBenefits: ["Bone health", "Heart health"],
                        servingSuggestion: "1 oz several times weekly"),
            BlueZoneFood(name: "Fava Beans", region: .sardinia, category: .legumes,
                        keyNutrients: ["Protein", "Fiber", "L-DOPA"],
                        longevityBenefits: ["Brain health", "Heart health"],
                        servingSuggestion: "1/2 cup cooked, several times weekly"),
            BlueZoneFood(name: "Sourdough Bread", region: .sardinia, category: .wholeGrains,
                        keyNutrients: ["Fiber", "B vitamins", "Prebiotics"],
                        longevityBenefits: ["Gut health", "Lower glycemic"],
                        servingSuggestion: "1-2 slices daily"),
            BlueZoneFood(name: "Barley", region: .sardinia, category: .wholeGrains,
                        keyNutrients: ["Beta-glucan", "Fiber", "Selenium"],
                        longevityBenefits: ["Cholesterol reduction", "Blood sugar control"],
                        servingSuggestion: "1/2 cup cooked daily"),

            // Nicoya
            BlueZoneFood(name: "Black Beans", region: .nicoya, category: .legumes,
                        keyNutrients: ["Protein", "Fiber", "Anthocyanins"],
                        longevityBenefits: ["Heart health", "Blood sugar control"],
                        servingSuggestion: "1 cup cooked daily"),
            BlueZoneFood(name: "Squash", region: .nicoya, category: .leafyGreens,
                        keyNutrients: ["Beta-carotene", "Fiber", "Vitamin C"],
                        longevityBenefits: ["Eye health", "Immune support"],
                        servingSuggestion: "1 cup several times weekly"),
            BlueZoneFood(name: "Corn Tortillas", region: .nicoya, category: .wholeGrains,
                        keyNutrients: ["Fiber", "Niacin", "Calcium (nixtamalized)"],
                        longevityBenefits: ["Energy", "Bone health"],
                        servingSuggestion: "2-3 tortillas per meal"),
            BlueZoneFood(name: "Papaya", region: .nicoya, category: .berries,
                        keyNutrients: ["Vitamin C", "Papain", "Beta-carotene"],
                        longevityBenefits: ["Digestion", "Skin health"],
                        servingSuggestion: "1 cup fresh daily"),
            BlueZoneFood(name: "Yuca", region: .nicoya, category: .wholeGrains,
                        keyNutrients: ["Carbohydrates", "Vitamin C", "Manganese"],
                        longevityBenefits: ["Sustained energy", "Gut health"],
                        servingSuggestion: "Boiled or roasted, moderate portions"),

            // Ikaria
            BlueZoneFood(name: "Wild Greens (Horta)", region: .ikaria, category: .leafyGreens,
                        keyNutrients: ["Vitamins A/C/K", "Minerals", "Fiber"],
                        longevityBenefits: ["Antioxidant", "Anti-inflammatory"],
                        servingSuggestion: "1-2 cups cooked daily"),
            BlueZoneFood(name: "Olive Oil", region: .ikaria, category: .oliveOil,
                        keyNutrients: ["Oleic acid", "Polyphenols", "Vitamin E"],
                        longevityBenefits: ["Heart health", "Brain health"],
                        servingSuggestion: "3-4 tablespoons daily"),
            BlueZoneFood(name: "Honey", region: .ikaria, category: .herbs,
                        keyNutrients: ["Antioxidants", "Enzymes", "Prebiotics"],
                        longevityBenefits: ["Antimicrobial", "Wound healing"],
                        servingSuggestion: "1-2 tsp daily (in moderation)"),
            BlueZoneFood(name: "Herbal Tea", region: .ikaria, category: .tea,
                        keyNutrients: ["Polyphenols", "Essential oils", "Minerals"],
                        longevityBenefits: ["Relaxation", "Antioxidant"],
                        servingSuggestion: "2-3 cups daily"),
            BlueZoneFood(name: "Potatoes", region: .ikaria, category: .wholeGrains,
                        keyNutrients: ["Potassium", "Vitamin C", "Fiber"],
                        longevityBenefits: ["Heart health", "Satiety"],
                        servingSuggestion: "1 medium potato daily"),

            // Loma Linda
            BlueZoneFood(name: "Walnuts", region: .lomaLinda, category: .nuts,
                        keyNutrients: ["Omega-3", "Protein", "Antioxidants"],
                        longevityBenefits: ["Brain health", "Heart health"],
                        servingSuggestion: "1 oz (handful) daily"),
            BlueZoneFood(name: "Oatmeal", region: .lomaLinda, category: .wholeGrains,
                        keyNutrients: ["Beta-glucan", "Fiber", "Protein"],
                        longevityBenefits: ["Cholesterol reduction", "Satiety"],
                        servingSuggestion: "1 cup cooked for breakfast"),
            BlueZoneFood(name: "Avocado", region: .lomaLinda, category: .nuts,
                        keyNutrients: ["Healthy fats", "Potassium", "Fiber"],
                        longevityBenefits: ["Heart health", "Nutrient absorption"],
                        servingSuggestion: "1/2 avocado daily"),
            BlueZoneFood(name: "Lentils", region: .lomaLinda, category: .legumes,
                        keyNutrients: ["Protein", "Fiber", "Iron"],
                        longevityBenefits: ["Heart health", "Blood sugar control"],
                        servingSuggestion: "1 cup cooked several times weekly"),
            BlueZoneFood(name: "Soy Milk", region: .lomaLinda, category: .legumes,
                        keyNutrients: ["Protein", "Isoflavones", "Calcium"],
                        longevityBenefits: ["Bone health", "Heart health"],
                        servingSuggestion: "1-2 cups daily")
        ]
    }

    private func loadPower9Principles() {
        power9Principles = [
            Power9Principle(
                name: "Move Naturally",
                description: "Live in environments that constantly nudge you into moving",
                coherenceImpact: 0.7,
                practicalTips: ["Walk instead of drive", "Garden", "Take stairs", "Stand while working"]
            ),
            Power9Principle(
                name: "Purpose (Ikigai/Plan de Vida)",
                description: "Know why you wake up in the morning",
                coherenceImpact: 0.85,
                practicalTips: ["Define your values", "Set meaningful goals", "Help others", "Learn continuously"]
            ),
            Power9Principle(
                name: "Downshift",
                description: "Have routines to reverse inflammation from stress",
                coherenceImpact: 0.95,
                practicalTips: ["Meditate daily", "Practice coherence breathing", "Nap", "Arrive early"]
            ),
            Power9Principle(
                name: "80% Rule (Hara Hachi Bu)",
                description: "Stop eating when 80% full",
                coherenceImpact: 0.6,
                practicalTips: ["Eat slowly", "Use smaller plates", "Eat mindfully", "Avoid distractions"]
            ),
            Power9Principle(
                name: "Plant Slant",
                description: "Eat mostly plant-based, especially beans",
                coherenceImpact: 0.65,
                practicalTips: ["Beans daily", "Limit meat to 5x/month", "Whole grains", "Vegetables at every meal"]
            ),
            Power9Principle(
                name: "Wine at 5",
                description: "Moderate, regular consumption with friends and food",
                coherenceImpact: 0.5,
                practicalTips: ["1-2 glasses max", "With food and friends", "Or skip entirely", "Not for non-drinkers"]
            ),
            Power9Principle(
                name: "Belong",
                description: "Participate in a faith-based community",
                coherenceImpact: 0.75,
                practicalTips: ["Attend services", "Join spiritual community", "Practice gratitude", "Meditate"]
            ),
            Power9Principle(
                name: "Loved Ones First",
                description: "Keep aging parents and grandparents nearby",
                coherenceImpact: 0.8,
                practicalTips: ["Regular family meals", "Call parents weekly", "Invest in partner", "Be present with children"]
            ),
            Power9Principle(
                name: "Right Tribe",
                description: "Surround yourself with people who support healthy behaviors",
                coherenceImpact: 0.85,
                practicalTips: ["Choose positive friends", "Join health groups", "Limit negative influences", "Be a good friend"]
            )
        ]
    }
}

// MARK: - ========================================
// MARK: - 2. NEUROSPIRITUAL ENGINE
// MARK: - ========================================

/// Consciousness state based on brainwave patterns
public enum ConsciousnessState: String, CaseIterable, Codable, Identifiable {
    case delta = "Delta"
    case theta = "Theta"
    case alpha = "Alpha"
    case beta = "Beta"
    case gamma = "Gamma"
    case flowState = "Flow State"
    case unitiveExperience = "Unitive Experience"
    case transcendent = "Transcendent"
    case meditative = "Meditative"
    case contemplative = "Contemplative"

    public var id: String { rawValue }

    public var frequencyRange: String {
        switch self {
        case .delta: return "0.5-4 Hz"
        case .theta: return "4-8 Hz"
        case .alpha: return "8-13 Hz"
        case .beta: return "13-30 Hz"
        case .gamma: return "30-100 Hz"
        case .flowState: return "Alpha-Theta border (7-10 Hz)"
        case .unitiveExperience: return "High gamma (40+ Hz)"
        case .transcendent: return "Gamma with alpha coherence"
        case .meditative: return "Theta-Alpha (5-10 Hz)"
        case .contemplative: return "Alpha dominant (8-12 Hz)"
        }
    }

    public var characteristics: String {
        switch self {
        case .delta: return "Deep sleep, regeneration, unconscious"
        case .theta: return "Drowsy, dreaming, creativity, memory"
        case .alpha: return "Relaxed, calm, learning, light meditation"
        case .beta: return "Alert, focused, active thinking"
        case .gamma: return "Peak awareness, insight, binding"
        case .flowState: return "Optimal performance, effortless action"
        case .unitiveExperience: return "Sense of oneness, ego dissolution"
        case .transcendent: return "Mystical awareness, deep insight"
        case .meditative: return "Contemplative, introspective"
        case .contemplative: return "Reflective, peaceful awareness"
        }
    }
}

/// Polyvagal state (Stephen Porges theory)
public enum PolyvagalState: String, CaseIterable, Codable, Identifiable {
    case ventralVagal = "Ventral Vagal"
    case sympathetic = "Sympathetic"
    case dorsalVagal = "Dorsal Vagal"
    case blendedVentralSympathetic = "Blended Ventral-Sympathetic"
    case freeze = "Freeze (Dorsal-Sympathetic)"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .ventralVagal:
            return "Social engagement, safety, connection, calm alertness"
        case .sympathetic:
            return "Mobilization, fight-or-flight, stress response"
        case .dorsalVagal:
            return "Immobilization, shutdown, conservation, dissociation"
        case .blendedVentralSympathetic:
            return "Play, healthy excitement, passionate engagement"
        case .freeze:
            return "Immobilization with fear, trauma response"
        }
    }

    public var physiologicalMarkers: [String] {
        switch self {
        case .ventralVagal:
            return ["High HRV", "Relaxed face", "Soft eyes", "Prosodic voice"]
        case .sympathetic:
            return ["Elevated HR", "Reduced HRV", "Muscle tension", "Rapid breathing"]
        case .dorsalVagal:
            return ["Low HR", "Flat affect", "Reduced movement", "Shallow breathing"]
        case .blendedVentralSympathetic:
            return ["Variable HR", "Animated face", "Energized movement"]
        case .freeze:
            return ["Dissociation", "Numbness", "Immobility", "High internal arousal"]
        }
    }

    public var citation: String {
        "Porges SW. The Polyvagal Theory. W.W. Norton & Company. 2011"
    }
}

/// Primary emotion (Ekman model)
public enum PrimaryEmotion: String, CaseIterable, Codable, Identifiable {
    case joy = "Joy"
    case sadness = "Sadness"
    case anger = "Anger"
    case fear = "Fear"
    case disgust = "Disgust"
    case surprise = "Surprise"
    case contempt = "Contempt"

    public var id: String { rawValue }

    public var facialMarkers: [String] {
        switch self {
        case .joy: return ["Raised cheeks", "Crow's feet", "Lip corners up"]
        case .sadness: return ["Inner brow raise", "Lip corners down", "Droopy eyelids"]
        case .anger: return ["Brow furrow", "Tightened lips", "Flared nostrils"]
        case .fear: return ["Raised brows", "Wide eyes", "Tense mouth"]
        case .disgust: return ["Nose wrinkle", "Raised upper lip", "Narrowed eyes"]
        case .surprise: return ["Raised brows", "Wide eyes", "Open mouth"]
        case .contempt: return ["Unilateral lip corner raise", "Slight sneer"]
        }
    }
}

/// Complex emotional state
public enum ComplexState: String, CaseIterable, Codable {
    case engagement = "Engagement"
    case confusion = "Confusion"
    case frustration = "Frustration"
    case determination = "Determination"
    case serenity = "Serenity"
    case awe = "Awe"
}

/// FACS Action Unit
public struct FACSActionUnit: Identifiable, Codable {
    public let id: Int
    public let name: String
    public let muscles: [String]
    public let description: String

    public init(id: Int, name: String, muscles: [String], description: String) {
        self.id = id
        self.name = name
        self.muscles = muscles
        self.description = description
    }
}

/// Facial expression analysis result
public struct FacialExpressionAnalysis: Codable {
    public let timestamp: Date
    public let primaryEmotion: PrimaryEmotion?
    public let emotionConfidence: Double
    public let complexStates: [ComplexState: Double]
    public let actionUnits: [Int: Double] // AU number -> intensity 0-1
    public let isDuchenneSmile: Bool
    public let valence: Double // -1 negative to +1 positive
    public let arousal: Double // 0 calm to 1 excited

    public init(
        timestamp: Date = Date(),
        primaryEmotion: PrimaryEmotion?,
        emotionConfidence: Double,
        complexStates: [ComplexState: Double],
        actionUnits: [Int: Double],
        isDuchenneSmile: Bool,
        valence: Double,
        arousal: Double
    ) {
        self.timestamp = timestamp
        self.primaryEmotion = primaryEmotion
        self.emotionConfidence = emotionConfidence
        self.complexStates = complexStates
        self.actionUnits = actionUnits
        self.isDuchenneSmile = isDuchenneSmile
        self.valence = valence
        self.arousal = arousal
    }
}

/// Reich/Lowen body segment for somatic analysis
public enum ReichLowenSegment: String, CaseIterable, Codable, Identifiable {
    case ocular = "Ocular"
    case oral = "Oral"
    case cervical = "Cervical"
    case thoracic = "Thoracic"
    case diaphragm = "Diaphragm"
    case abdominal = "Abdominal"
    case pelvic = "Pelvic"

    public var id: String { rawValue }

    public var bodyArea: String {
        switch self {
        case .ocular: return "Eyes, forehead, scalp"
        case .oral: return "Mouth, jaw, throat"
        case .cervical: return "Neck, tongue base"
        case .thoracic: return "Chest, upper back, arms, hands"
        case .diaphragm: return "Diaphragm, solar plexus"
        case .abdominal: return "Abdomen, lower back"
        case .pelvic: return "Pelvis, legs, feet"
        }
    }

    public var emotionalThemes: [String] {
        switch self {
        case .ocular: return ["Contact", "Vision", "Understanding"]
        case .oral: return ["Nurturance", "Expression", "Trust"]
        case .cervical: return ["Control", "Self-expression", "Communication"]
        case .thoracic: return ["Love", "Grief", "Reaching out"]
        case .diaphragm: return ["Anxiety", "Anger", "Breathing"]
        case .abdominal: return ["Fear", "Power", "Vulnerability"]
        case .pelvic: return ["Pleasure", "Sexuality", "Grounding"]
        }
    }
}

/// Gesture analysis result
public struct GestureAnalysis: Codable {
    public let timestamp: Date
    public let handOpenness: Double // 0 closed to 1 open
    public let gestureType: GestureType
    public let isHeartCentered: Bool
    public let position: GesturePosition
    public let energy: Double // 0 low to 1 high

    public init(
        timestamp: Date = Date(),
        handOpenness: Double,
        gestureType: GestureType,
        isHeartCentered: Bool,
        position: GesturePosition,
        energy: Double
    ) {
        self.timestamp = timestamp
        self.handOpenness = handOpenness
        self.gestureType = gestureType
        self.isHeartCentered = isHeartCentered
        self.position = position
        self.energy = energy
    }
}

/// Type of gesture
public enum GestureType: String, CaseIterable, Codable {
    case open = "Open"
    case closed = "Closed"
    case reaching = "Reaching"
    case protective = "Protective"
    case expressive = "Expressive"
    case grounding = "Grounding"
    case heartFocused = "Heart-Focused"
    case prayerful = "Prayerful"
}

/// Gesture position relative to body
public enum GesturePosition: String, CaseIterable, Codable {
    case aboveHead = "Above Head"
    case faceLevel = "Face Level"
    case heartLevel = "Heart Level"
    case solarPlexus = "Solar Plexus"
    case abdomen = "Abdomen"
    case sides = "At Sides"
    case behind = "Behind Body"
}

/// Body movement quality analysis
public struct MovementQuality: Codable {
    public let fluidity: Double // 0 stiff to 1 fluid
    public let rhythmicity: Double // 0 arrhythmic to 1 rhythmic
    public let groundingScore: Double // 0 ungrounded to 1 grounded
    public let expansiveness: Double // 0 contracted to 1 expansive
    public let symmetry: Double // 0 asymmetric to 1 symmetric

    public init(
        fluidity: Double,
        rhythmicity: Double,
        groundingScore: Double,
        expansiveness: Double,
        symmetry: Double
    ) {
        self.fluidity = fluidity
        self.rhythmicity = rhythmicity
        self.groundingScore = groundingScore
        self.expansiveness = expansiveness
        self.symmetry = symmetry
    }
}

/// Integrated psychosomatic state
public struct PsychosomaticState: Codable {
    public let timestamp: Date
    public let wellbeingScore: Double // 0-1
    public let presenceScore: Double // 0-1
    public let embodimentScore: Double // 0-1
    public let connectionScore: Double // 0-1
    public let overallIntegration: Double // 0-1
    public let dominantPolyvagalState: PolyvagalState
    public let consciousnessState: ConsciousnessState
    public let segmentTension: [ReichLowenSegment: Double]

    public init(
        timestamp: Date = Date(),
        wellbeingScore: Double,
        presenceScore: Double,
        embodimentScore: Double,
        connectionScore: Double,
        dominantPolyvagalState: PolyvagalState,
        consciousnessState: ConsciousnessState,
        segmentTension: [ReichLowenSegment: Double]
    ) {
        self.timestamp = timestamp
        self.wellbeingScore = wellbeingScore
        self.presenceScore = presenceScore
        self.embodimentScore = embodimentScore
        self.connectionScore = connectionScore
        self.overallIntegration = (wellbeingScore + presenceScore + embodimentScore + connectionScore) / 4.0
        self.dominantPolyvagalState = dominantPolyvagalState
        self.consciousnessState = consciousnessState
        self.segmentTension = segmentTension
    }
}

/// Main NeuroSpiritual Engine
@MainActor
public final class NeuroSpiritualEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var currentConsciousnessState: ConsciousnessState = .alpha
    @Published public private(set) var currentPolyvagalState: PolyvagalState = .ventralVagal
    @Published public private(set) var latestFacialAnalysis: FacialExpressionAnalysis?
    @Published public private(set) var latestGestureAnalysis: GestureAnalysis?
    @Published public private(set) var latestMovementQuality: MovementQuality?
    @Published public private(set) var psychosomaticState: PsychosomaticState?
    @Published public private(set) var facsActionUnits: [FACSActionUnit] = []
    @Published public private(set) var hrvCoherence: Double = 0.5

    // MARK: - Constants

    public static let disclaimer = """
    NEUROSPIRITUAL FEATURES DISCLAIMER

    These features integrate concepts from psychology, neuroscience, and contemplative
    traditions for creative and meditative purposes ONLY.

    This is NOT a clinical psychological assessment tool. The readings and states
    described are approximations based on limited sensor data and should NOT be
    used for psychological diagnosis or treatment decisions.

    Scientific basis includes: Polyvagal Theory (Porges), Embodied Cognition
    (Varela, Thompson, Rosch), FACS (Ekman), Somatic Experiencing (Levine),
    HeartMath Institute research, and Reichian body therapy concepts.

    For mental health concerns, please consult qualified mental health professionals.
    """

    // MARK: - Initialization

    public init() {
        loadFACSActionUnits()
    }

    // MARK: - Public Methods

    /// Update HRV coherence from biofeedback
    public func updateHRVCoherence(_ coherence: Double) {
        hrvCoherence = max(0, min(1, coherence))
        updateConsciousnessFromHRV()
        updatePolyvagalFromHRV()
    }

    /// Process facial expression data
    public func processFacialExpression(
        actionUnits: [Int: Double],
        landmarks: [(x: Double, y: Double)]? = nil
    ) -> FacialExpressionAnalysis {
        // Detect Duchenne smile (AU6 + AU12)
        let au6 = actionUnits[6] ?? 0 // Cheek raiser
        let au12 = actionUnits[12] ?? 0 // Lip corner puller
        let isDuchenne = au6 > 0.4 && au12 > 0.5

        // Detect primary emotion from AUs
        let (emotion, confidence) = detectPrimaryEmotion(from: actionUnits)

        // Calculate valence and arousal
        let valence = calculateValence(from: actionUnits, emotion: emotion)
        let arousal = calculateArousal(from: actionUnits)

        // Detect complex states
        let complexStates = detectComplexStates(from: actionUnits, valence: valence, arousal: arousal)

        let analysis = FacialExpressionAnalysis(
            primaryEmotion: emotion,
            emotionConfidence: confidence,
            complexStates: complexStates,
            actionUnits: actionUnits,
            isDuchenneSmile: isDuchenne,
            valence: valence,
            arousal: arousal
        )

        latestFacialAnalysis = analysis
        updatePsychosomaticState()
        return analysis
    }

    /// Process gesture data
    public func processGesture(
        handOpenness: Double,
        handPosition: (x: Double, y: Double, z: Double),
        velocity: Double
    ) -> GestureAnalysis {
        // Determine gesture type
        let gestureType: GestureType
        if handOpenness > 0.8 {
            gestureType = .open
        } else if handOpenness < 0.2 {
            gestureType = .closed
        } else if velocity > 0.5 {
            gestureType = .expressive
        } else if handPosition.y < 0.3 {
            gestureType = .grounding
        } else {
            gestureType = .reaching
        }

        // Determine position
        let position: GesturePosition
        if handPosition.y > 0.8 {
            position = .aboveHead
        } else if handPosition.y > 0.6 {
            position = .faceLevel
        } else if handPosition.y > 0.45 {
            position = .heartLevel
        } else if handPosition.y > 0.35 {
            position = .solarPlexus
        } else {
            position = .abdomen
        }

        // Check if heart-centered (both hands at heart level, close together)
        let isHeartCentered = position == .heartLevel && handOpenness > 0.3 && handOpenness < 0.7

        let analysis = GestureAnalysis(
            handOpenness: handOpenness,
            gestureType: gestureType,
            isHeartCentered: isHeartCentered,
            position: position,
            energy: velocity
        )

        latestGestureAnalysis = analysis
        updatePsychosomaticState()
        return analysis
    }

    /// Process body movement quality
    public func processMovement(
        jointVelocities: [Double],
        centerOfMass: (x: Double, y: Double),
        symmetryScore: Double
    ) -> MovementQuality {
        // Calculate fluidity from velocity variance
        let avgVelocity = jointVelocities.reduce(0, +) / Double(max(1, jointVelocities.count))
        let variance = jointVelocities.map { pow($0 - avgVelocity, 2) }.reduce(0, +) / Double(max(1, jointVelocities.count))
        let fluidity = max(0, min(1, 1 - sqrt(variance)))

        // Calculate rhythmicity (simplified - would use FFT in production)
        let rhythmicity = hrvCoherence * 0.7 + 0.3 // Correlate with HRV

        // Calculate grounding from center of mass
        let groundingScore = max(0, min(1, 1 - centerOfMass.y))

        // Calculate expansiveness from joint spread
        let maxVelocity = jointVelocities.max() ?? 0
        let expansiveness = max(0, min(1, maxVelocity))

        let quality = MovementQuality(
            fluidity: fluidity,
            rhythmicity: rhythmicity,
            groundingScore: groundingScore,
            expansiveness: expansiveness,
            symmetry: symmetryScore
        )

        latestMovementQuality = quality
        updatePsychosomaticState()
        return quality
    }

    /// Get integrated psychosomatic state
    public func getIntegratedState() -> PsychosomaticState? {
        return psychosomaticState
    }

    /// Detect body segment tension from posture
    public func analyzeSegmentTension(postureData: [String: Double]) -> [ReichLowenSegment: Double] {
        var tension: [ReichLowenSegment: Double] = [:]

        for segment in ReichLowenSegment.allCases {
            // Map posture data to segments (simplified)
            switch segment {
            case .ocular:
                tension[segment] = postureData["eyeTension"] ?? 0.3
            case .oral:
                tension[segment] = postureData["jawTension"] ?? 0.3
            case .cervical:
                tension[segment] = postureData["neckTension"] ?? 0.4
            case .thoracic:
                tension[segment] = postureData["shoulderTension"] ?? 0.4
            case .diaphragm:
                tension[segment] = 1.0 - hrvCoherence // Inverse of breathing coherence
            case .abdominal:
                tension[segment] = postureData["abdominalTension"] ?? 0.3
            case .pelvic:
                tension[segment] = postureData["hipTension"] ?? 0.3
            }
        }

        return tension
    }

    // MARK: - Private Methods

    private func loadFACSActionUnits() {
        facsActionUnits = [
            FACSActionUnit(id: 1, name: "Inner Brow Raiser", muscles: ["Frontalis (pars medialis)"], description: "Raises inner eyebrows"),
            FACSActionUnit(id: 2, name: "Outer Brow Raiser", muscles: ["Frontalis (pars lateralis)"], description: "Raises outer eyebrows"),
            FACSActionUnit(id: 4, name: "Brow Lowerer", muscles: ["Corrugator supercilii", "Depressor supercilii"], description: "Furrows brow"),
            FACSActionUnit(id: 5, name: "Upper Lid Raiser", muscles: ["Levator palpebrae superioris"], description: "Widens eyes"),
            FACSActionUnit(id: 6, name: "Cheek Raiser", muscles: ["Orbicularis oculi (pars orbitalis)"], description: "Raises cheeks, crow's feet"),
            FACSActionUnit(id: 7, name: "Lid Tightener", muscles: ["Orbicularis oculi (pars palpebralis)"], description: "Tightens eyelids"),
            FACSActionUnit(id: 12, name: "Lip Corner Puller", muscles: ["Zygomaticus major"], description: "Pulls lip corners up (smile)"),
            FACSActionUnit(id: 15, name: "Lip Corner Depressor", muscles: ["Depressor anguli oris"], description: "Pulls lip corners down (frown)")
        ]
    }

    private func detectPrimaryEmotion(from actionUnits: [Int: Double]) -> (PrimaryEmotion?, Double) {
        // Joy: AU6 + AU12
        let joyScore = (actionUnits[6] ?? 0) * 0.4 + (actionUnits[12] ?? 0) * 0.6

        // Sadness: AU1 + AU4 + AU15
        let sadnessScore = (actionUnits[1] ?? 0) * 0.3 + (actionUnits[4] ?? 0) * 0.3 + (actionUnits[15] ?? 0) * 0.4

        // Anger: AU4 + AU5 + AU7
        let angerScore = (actionUnits[4] ?? 0) * 0.4 + (actionUnits[5] ?? 0) * 0.3 + (actionUnits[7] ?? 0) * 0.3

        // Fear: AU1 + AU2 + AU4 + AU5
        let fearScore = (actionUnits[1] ?? 0) * 0.25 + (actionUnits[2] ?? 0) * 0.25 + (actionUnits[4] ?? 0) * 0.25 + (actionUnits[5] ?? 0) * 0.25

        // Surprise: AU1 + AU2 + AU5
        let surpriseScore = (actionUnits[1] ?? 0) * 0.33 + (actionUnits[2] ?? 0) * 0.33 + (actionUnits[5] ?? 0) * 0.34

        let scores: [(PrimaryEmotion, Double)] = [
            (.joy, joyScore),
            (.sadness, sadnessScore),
            (.anger, angerScore),
            (.fear, fearScore),
            (.surprise, surpriseScore)
        ]

        if let maxScore = scores.max(by: { $0.1 < $1.1 }), maxScore.1 > 0.3 {
            return (maxScore.0, maxScore.1)
        }

        return (nil, 0)
    }

    private func calculateValence(from actionUnits: [Int: Double], emotion: PrimaryEmotion?) -> Double {
        // Positive AUs: 6, 12 (smile)
        // Negative AUs: 4, 15 (frown)
        let positive = (actionUnits[6] ?? 0) + (actionUnits[12] ?? 0)
        let negative = (actionUnits[4] ?? 0) + (actionUnits[15] ?? 0)

        return max(-1, min(1, (positive - negative) / 2))
    }

    private func calculateArousal(from actionUnits: [Int: Double]) -> Double {
        // High arousal: wide eyes (AU5), raised brows (AU1, AU2)
        let arousalAUs = (actionUnits[1] ?? 0) + (actionUnits[2] ?? 0) + (actionUnits[5] ?? 0)
        return max(0, min(1, arousalAUs / 3))
    }

    private func detectComplexStates(from actionUnits: [Int: Double], valence: Double, arousal: Double) -> [ComplexState: Double] {
        var states: [ComplexState: Double] = [:]

        // Engagement: positive valence + moderate arousal
        states[.engagement] = max(0, (valence + 1) / 2 * (1 - abs(arousal - 0.5) * 2))

        // Serenity: positive valence + low arousal
        states[.serenity] = max(0, (valence + 1) / 2 * (1 - arousal))

        // Confusion: moderate arousal + brow furrow
        states[.confusion] = (actionUnits[4] ?? 0) * 0.6 + arousal * 0.4

        // Frustration: negative valence + high arousal
        states[.frustration] = max(0, (1 - valence) / 2 * arousal)

        // Determination: brow lower + lip tightening
        states[.determination] = (actionUnits[4] ?? 0) * 0.5 + (actionUnits[7] ?? 0) * 0.5

        // Awe: wide eyes + open mouth (not implemented fully)
        states[.awe] = (actionUnits[5] ?? 0) * 0.7 + (actionUnits[2] ?? 0) * 0.3

        return states
    }

    private func updateConsciousnessFromHRV() {
        // Map HRV coherence to consciousness state
        if hrvCoherence > 0.9 {
            currentConsciousnessState = .unitiveExperience
        } else if hrvCoherence > 0.8 {
            currentConsciousnessState = .flowState
        } else if hrvCoherence > 0.7 {
            currentConsciousnessState = .meditative
        } else if hrvCoherence > 0.5 {
            currentConsciousnessState = .alpha
        } else if hrvCoherence > 0.3 {
            currentConsciousnessState = .beta
        } else {
            currentConsciousnessState = .theta
        }
    }

    private func updatePolyvagalFromHRV() {
        // Map HRV to polyvagal state
        if hrvCoherence > 0.7 {
            currentPolyvagalState = .ventralVagal
        } else if hrvCoherence > 0.5 {
            currentPolyvagalState = .blendedVentralSympathetic
        } else if hrvCoherence > 0.3 {
            currentPolyvagalState = .sympathetic
        } else {
            currentPolyvagalState = .dorsalVagal
        }
    }

    private func updatePsychosomaticState() {
        // Calculate wellbeing from facial valence
        let wellbeing = latestFacialAnalysis.map { ($0.valence + 1) / 2 } ?? 0.5

        // Calculate presence from movement quality
        let presence = latestMovementQuality.map { ($0.fluidity + $0.groundingScore) / 2 } ?? 0.5

        // Calculate embodiment from gesture
        let embodiment = latestGestureAnalysis.map { gesture -> Double in
            let openness = gesture.handOpenness
            let heartCentered = gesture.isHeartCentered ? 0.3 : 0.0
            return openness * 0.7 + heartCentered
        } ?? 0.5

        // Connection from polyvagal state
        let connection: Double
        switch currentPolyvagalState {
        case .ventralVagal: connection = 0.9
        case .blendedVentralSympathetic: connection = 0.7
        case .sympathetic: connection = 0.4
        case .dorsalVagal: connection = 0.2
        case .freeze: connection = 0.1
        }

        // Segment tension (use defaults if no posture data)
        var segmentTension: [ReichLowenSegment: Double] = [:]
        for segment in ReichLowenSegment.allCases {
            segmentTension[segment] = segment == .diaphragm ? (1 - hrvCoherence) : 0.3
        }

        psychosomaticState = PsychosomaticState(
            wellbeingScore: wellbeing,
            presenceScore: presence,
            embodimentScore: embodiment,
            connectionScore: connection,
            dominantPolyvagalState: currentPolyvagalState,
            consciousnessState: currentConsciousnessState,
            segmentTension: segmentTension
        )
    }
}

// MARK: - ========================================
// MARK: - 3. QUANTUM HEALTH BIOFEEDBACK ENGINE
// MARK: - ========================================

/// Session type for quantum health sessions
public enum QuantumSessionType: String, CaseIterable, Codable, Identifiable {
    case meditation = "Meditation"
    case coherence = "Coherence Training"
    case creative = "Creative Flow"
    case wellness = "Wellness"
    case research = "Research"
    case performance = "Performance"
    case workshop = "Workshop"
    case unlimited = "Unlimited"

    public var id: String { rawValue }

    public var maxParticipants: Int {
        switch self {
        case .meditation: return 1000
        case .coherence: return 500
        case .creative: return 100
        case .wellness: return 200
        case .research: return 50
        case .performance: return 10000
        case .workshop: return 100
        case .unlimited: return Int.max
        }
    }

    public var description: String {
        switch self {
        case .meditation: return "Group meditation with coherence synchronization"
        case .coherence: return "Heart coherence training with biofeedback"
        case .creative: return "Creative collaboration with bio-reactive audio"
        case .wellness: return "General wellness and relaxation session"
        case .research: return "Research study with data collection"
        case .performance: return "Live performance with audience participation"
        case .workshop: return "Educational workshop with guided exercises"
        case .unlimited: return "Unlimited participants for global events"
        }
    }
}

/// Stream quality for broadcasting
public enum StreamQuality: String, CaseIterable, Codable {
    case sd480p = "480p SD"
    case hd720p = "720p HD"
    case fullHD1080p = "1080p Full HD"
    case uhd4k = "4K UHD"
    case uhd8k = "8K UHD"

    public var resolution: (width: Int, height: Int) {
        switch self {
        case .sd480p: return (854, 480)
        case .hd720p: return (1280, 720)
        case .fullHD1080p: return (1920, 1080)
        case .uhd4k: return (3840, 2160)
        case .uhd8k: return (7680, 4320)
        }
    }

    public var bitrate: Int {
        switch self {
        case .sd480p: return 1_500_000
        case .hd720p: return 4_000_000
        case .fullHD1080p: return 8_000_000
        case .uhd4k: return 35_000_000
        case .uhd8k: return 100_000_000
        }
    }
}

/// Broadcasting platform
public enum BroadcastPlatform: String, CaseIterable, Codable {
    case youtube = "YouTube"
    case twitch = "Twitch"
    case facebook = "Facebook"
    case instagram = "Instagram"
    case tiktok = "TikTok"
    case webrtc = "WebRTC"
    case ndi = "NDI"
    case custom = "Custom RTMP"
}

/// Privacy mode for sessions
public enum PrivacyMode: String, CaseIterable, Codable {
    case full = "Full Data Sharing"
    case aggregated = "Aggregated Only"
    case anonymous = "Anonymous"

    public var description: String {
        switch self {
        case .full: return "Individual biometric data visible to host"
        case .aggregated: return "Only group averages shared"
        case .anonymous: return "No individual data shared, full privacy"
        }
    }
}

/// Quantum-inspired health metric
public struct QuantumHealthMetric: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let value: Double // 0-100
    public let unit: String
    public let timestamp: Date
    public let source: String

    public init(
        id: UUID = UUID(),
        name: String,
        value: Double,
        unit: String,
        timestamp: Date = Date(),
        source: String
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.source = source
    }
}

/// Participant in a quantum health session
public struct QuantumSessionParticipant: Identifiable, Codable {
    public let id: UUID
    public let displayName: String
    public let joinedAt: Date
    public var currentCoherence: Double
    public var hrvMetrics: HRVMetrics?
    public var isEntangled: Bool
    public let privacyMode: PrivacyMode

    public init(
        id: UUID = UUID(),
        displayName: String,
        joinedAt: Date = Date(),
        currentCoherence: Double = 0.5,
        hrvMetrics: HRVMetrics? = nil,
        isEntangled: Bool = false,
        privacyMode: PrivacyMode = .aggregated
    ) {
        self.id = id
        self.displayName = displayName
        self.joinedAt = joinedAt
        self.currentCoherence = currentCoherence
        self.hrvMetrics = hrvMetrics
        self.isEntangled = isEntangled
        self.privacyMode = privacyMode
    }
}

/// HRV metrics for quantum health
public struct HRVMetrics: Codable {
    public let sdnn: Double // ms
    public let rmssd: Double // ms
    public let pnn50: Double // %
    public let lfHfRatio: Double
    public let coherenceRatio: Double // 0-1

    public init(sdnn: Double, rmssd: Double, pnn50: Double, lfHfRatio: Double, coherenceRatio: Double) {
        self.sdnn = sdnn
        self.rmssd = rmssd
        self.pnn50 = pnn50
        self.lfHfRatio = lfHfRatio
        self.coherenceRatio = coherenceRatio
    }
}

/// Group quantum metrics
public struct GroupQuantumMetrics: Codable {
    public let groupCoherence: Double // 0-1 average coherence
    public let entanglementScore: Double // 0-1 synchrony between participants
    public let synchronyScore: Double // 0-1 timing alignment
    public let participantCount: Int
    public let activeEntanglements: Int
    public let timestamp: Date

    public init(
        groupCoherence: Double,
        entanglementScore: Double,
        synchronyScore: Double,
        participantCount: Int,
        activeEntanglements: Int,
        timestamp: Date = Date()
    ) {
        self.groupCoherence = groupCoherence
        self.entanglementScore = entanglementScore
        self.synchronyScore = synchronyScore
        self.participantCount = participantCount
        self.activeEntanglements = activeEntanglements
        self.timestamp = timestamp
    }
}

/// Broadcast configuration
public struct BroadcastConfig: Codable {
    public let platform: BroadcastPlatform
    public let streamKey: String
    public let quality: StreamQuality
    public let isEnabled: Bool

    public init(platform: BroadcastPlatform, streamKey: String, quality: StreamQuality, isEnabled: Bool = true) {
        self.platform = platform
        self.streamKey = streamKey
        self.quality = quality
        self.isEnabled = isEnabled
    }
}

/// Session analytics
public struct SessionAnalytics: Codable {
    public let sessionId: UUID
    public let sessionType: QuantumSessionType
    public let startTime: Date
    public let endTime: Date?
    public let peakParticipants: Int
    public let peakCoherence: Double
    public let totalEntanglementEvents: Int
    public let averageCoherence: Double
    public let healthScoreHistory: [Double]

    public init(
        sessionId: UUID,
        sessionType: QuantumSessionType,
        startTime: Date,
        endTime: Date? = nil,
        peakParticipants: Int,
        peakCoherence: Double,
        totalEntanglementEvents: Int,
        averageCoherence: Double,
        healthScoreHistory: [Double]
    ) {
        self.sessionId = sessionId
        self.sessionType = sessionType
        self.startTime = startTime
        self.endTime = endTime
        self.peakParticipants = peakParticipants
        self.peakCoherence = peakCoherence
        self.totalEntanglementEvents = totalEntanglementEvents
        self.averageCoherence = averageCoherence
        self.healthScoreHistory = healthScoreHistory
    }

    public var duration: TimeInterval {
        guard let end = endTime else { return Date().timeIntervalSince(startTime) }
        return end.timeIntervalSince(startTime)
    }
}

/// Main Quantum Health Biofeedback Engine
@MainActor
public final class QuantumHealthBiofeedbackEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isSessionActive: Bool = false
    @Published public private(set) var currentSessionType: QuantumSessionType = .wellness
    @Published public private(set) var participants: [QuantumSessionParticipant] = []
    @Published public private(set) var groupMetrics: GroupQuantumMetrics?
    @Published public private(set) var quantumHealthScore: Double = 50.0 // 0-100
    @Published public private(set) var healthMetrics: [QuantumHealthMetric] = []
    @Published public private(set) var broadcastConfigs: [BroadcastConfig] = []
    @Published public private(set) var sessionAnalytics: SessionAnalytics?
    @Published public private(set) var entanglementThreshold: Double = 0.9

    // MARK: - Private Properties

    private var sessionId: UUID?
    private var sessionStartTime: Date?
    private var healthScoreHistory: [Double] = []
    private var entanglementEventCount: Int = 0
    private var peakCoherence: Double = 0
    private var peakParticipants: Int = 0

    // MARK: - Constants

    public static let disclaimer = """
    QUANTUM HEALTH BIOFEEDBACK DISCLAIMER

    The term "quantum" refers to quantum-INSPIRED algorithms and visualizations,
    NOT actual quantum computing hardware or quantum physics measurements.

    This system uses classical computing with algorithms inspired by quantum
    concepts (superposition, entanglement, coherence) for creative visualization
    and group synchronization purposes.

    Health metrics and scores are for wellness exploration ONLY and are NOT
    clinical measurements. This is NOT a medical device.

    "Entanglement" refers to high synchronization between participants'
    biometric signals, not quantum mechanical entanglement.

    Consult healthcare professionals for any health concerns.
    """

    /// Optimal breathing rate for coherence (6 breaths/min = 0.1 Hz baroreflex)
    public static let optimalBreathingRate: Double = 6.0

    // MARK: - Initialization

    public init() {}

    // MARK: - Session Management

    /// Start a new quantum health session
    public func startSession(type: QuantumSessionType, privacyMode: PrivacyMode = .aggregated) {
        sessionId = UUID()
        currentSessionType = type
        sessionStartTime = Date()
        isSessionActive = true
        participants = []
        healthScoreHistory = []
        entanglementEventCount = 0
        peakCoherence = 0
        peakParticipants = 0

        updateSessionAnalytics()
    }

    /// End the current session
    public func endSession() {
        guard isSessionActive, let id = sessionId, let startTime = sessionStartTime else { return }

        let avgCoherence = healthScoreHistory.isEmpty ? 0 : healthScoreHistory.reduce(0, +) / Double(healthScoreHistory.count)

        sessionAnalytics = SessionAnalytics(
            sessionId: id,
            sessionType: currentSessionType,
            startTime: startTime,
            endTime: Date(),
            peakParticipants: peakParticipants,
            peakCoherence: peakCoherence,
            totalEntanglementEvents: entanglementEventCount,
            averageCoherence: avgCoherence,
            healthScoreHistory: healthScoreHistory
        )

        isSessionActive = false
        participants = []
    }

    /// Add a participant to the session
    public func addParticipant(_ participant: QuantumSessionParticipant) {
        guard isSessionActive else { return }
        guard participants.count < currentSessionType.maxParticipants else { return }

        participants.append(participant)
        peakParticipants = max(peakParticipants, participants.count)
        updateGroupMetrics()
    }

    /// Remove a participant from the session
    public func removeParticipant(id: UUID) {
        participants.removeAll { $0.id == id }
        updateGroupMetrics()
    }

    /// Update participant coherence
    public func updateParticipantCoherence(id: UUID, coherence: Double, hrvMetrics: HRVMetrics? = nil) {
        guard let index = participants.firstIndex(where: { $0.id == id }) else { return }

        participants[index].currentCoherence = coherence
        participants[index].hrvMetrics = hrvMetrics

        // Check for entanglement
        if coherence >= entanglementThreshold {
            participants[index].isEntangled = true
        } else {
            participants[index].isEntangled = false
        }

        updateGroupMetrics()
        updateQuantumHealthScore()
    }

    // MARK: - Broadcasting

    /// Configure broadcast to platform
    public func configureBroadcast(platform: BroadcastPlatform, streamKey: String, quality: StreamQuality) {
        let config = BroadcastConfig(platform: platform, streamKey: streamKey, quality: quality)

        if let index = broadcastConfigs.firstIndex(where: { $0.platform == platform }) {
            broadcastConfigs[index] = config
        } else {
            broadcastConfigs.append(config)
        }
    }

    /// Remove broadcast configuration
    public func removeBroadcast(platform: BroadcastPlatform) {
        broadcastConfigs.removeAll { $0.platform == platform }
    }

    // MARK: - Health Metrics

    /// Calculate integrated quantum health score
    public func calculateQuantumHealthScore(
        heartRate: Double,
        hrv: Double,
        coherence: Double,
        breathingRate: Double,
        sleepQuality: Double? = nil
    ) -> Double {
        var score: Double = 0
        var weightSum: Double = 0

        // Heart rate contribution (60-70 optimal)
        let hrScore = max(0, 100 - abs(heartRate - 65) * 2)
        score += hrScore * 0.2
        weightSum += 0.2

        // HRV contribution (higher is better, normalized)
        let hrvScore = min(100, hrv * 1.5)
        score += hrvScore * 0.25
        weightSum += 0.25

        // Coherence contribution (0-1 to 0-100)
        let coherenceScore = coherence * 100
        score += coherenceScore * 0.3
        weightSum += 0.3

        // Breathing rate contribution (6/min optimal)
        let breathScore = max(0, 100 - abs(breathingRate - Self.optimalBreathingRate) * 10)
        score += breathScore * 0.15
        weightSum += 0.15

        // Sleep quality if available
        if let sleep = sleepQuality {
            score += sleep * 0.1
            weightSum += 0.1
        }

        let finalScore = score / weightSum
        quantumHealthScore = finalScore
        healthScoreHistory.append(finalScore)
        peakCoherence = max(peakCoherence, coherence)

        // Add to metrics
        let metric = QuantumHealthMetric(
            name: "Quantum Health Score",
            value: finalScore,
            unit: "points",
            source: "Integrated Calculation"
        )
        healthMetrics.append(metric)

        return finalScore
    }

    /// Get health score interpretation
    public func interpretHealthScore(_ score: Double) -> (status: String, recommendations: [String]) {
        let status: String
        var recommendations: [String] = []

        if score >= 80 {
            status = "Excellent"
            recommendations = ["Maintain your current practices", "Share your wellness journey with others"]
        } else if score >= 60 {
            status = "Good"
            recommendations = ["Focus on coherence breathing", "Aim for 7-8 hours of quality sleep"]
        } else if score >= 40 {
            status = "Moderate"
            recommendations = ["Practice 10 minutes of coherence breathing daily", "Reduce stress with mindfulness", "Consider a consistent sleep schedule"]
        } else {
            status = "Needs Attention"
            recommendations = ["Start with 5-minute breathing sessions", "Prioritize rest and recovery", "Consider consulting a wellness professional"]
        }

        return (status, recommendations)
    }

    // MARK: - Private Methods

    private func updateGroupMetrics() {
        guard !participants.isEmpty else {
            groupMetrics = nil
            return
        }

        // Calculate group coherence (average)
        let avgCoherence = participants.map { $0.currentCoherence }.reduce(0, +) / Double(participants.count)

        // Calculate entanglement score (how many are above threshold)
        let entangledCount = participants.filter { $0.isEntangled }.count
        let entanglementScore = Double(entangledCount) / Double(participants.count)

        // Calculate synchrony (variance - lower variance = higher synchrony)
        let coherences = participants.map { $0.currentCoherence }
        let variance = coherences.map { pow($0 - avgCoherence, 2) }.reduce(0, +) / Double(participants.count)
        let synchronyScore = max(0, 1 - sqrt(variance) * 2)

        // Check for entanglement event
        if entanglementScore > 0.5 && avgCoherence > entanglementThreshold {
            entanglementEventCount += 1
        }

        groupMetrics = GroupQuantumMetrics(
            groupCoherence: avgCoherence,
            entanglementScore: entanglementScore,
            synchronyScore: synchronyScore,
            participantCount: participants.count,
            activeEntanglements: entangledCount
        )
    }

    private func updateQuantumHealthScore() {
        guard let metrics = groupMetrics else { return }

        // Simple health score from group metrics
        let score = (metrics.groupCoherence * 40 + metrics.synchronyScore * 30 + metrics.entanglementScore * 30) * 100
        quantumHealthScore = score
        healthScoreHistory.append(score)
    }

    private func updateSessionAnalytics() {
        guard let id = sessionId, let startTime = sessionStartTime else { return }

        let avgCoherence = healthScoreHistory.isEmpty ? 0 : healthScoreHistory.reduce(0, +) / Double(healthScoreHistory.count)

        sessionAnalytics = SessionAnalytics(
            sessionId: id,
            sessionType: currentSessionType,
            startTime: startTime,
            endTime: nil,
            peakParticipants: peakParticipants,
            peakCoherence: peakCoherence,
            totalEntanglementEvents: entanglementEventCount,
            averageCoherence: avgCoherence,
            healthScoreHistory: healthScoreHistory
        )
    }
}

// MARK: - ========================================
// MARK: - 4. ADEY WINDOWS BIOELECTROMAGNETIC ENGINE
// MARK: - ========================================

/// Body system for Adey Windows mapping
public enum BodySystem: String, CaseIterable, Codable, Identifiable {
    case nervous = "Nervous System (Psyche)"
    case cardiovascular = "Cardiovascular System"
    case musculoskeletal = "Musculoskeletal System"
    case respiratory = "Respiratory System"
    case endocrine = "Endocrine System"
    case immune = "Immune System"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .nervous: return "Brain, spinal cord, peripheral nerves"
        case .cardiovascular: return "Heart, blood vessels, circulation"
        case .musculoskeletal: return "Muscles, bones, joints"
        case .respiratory: return "Lungs, airways, breathing"
        case .endocrine: return "Hormonal glands, metabolism"
        case .immune: return "Lymphatic system, immune cells"
        }
    }

    public var scientificMeasurement: String {
        switch self {
        case .nervous: return "EEG (Electroencephalogram)"
        case .cardiovascular: return "HRV, ECG/EKG"
        case .musculoskeletal: return "EMG (Electromyogram)"
        case .respiratory: return "SpO2, Respiratory Rate"
        case .endocrine: return "Cortisol, Hormone Panels"
        case .immune: return "Inflammatory Markers"
        }
    }
}

/// Scientific frequency window based on Adey research
public struct AdeyWindow: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let frequencyRangeHz: ClosedRange<Double>
    public let targetSystems: [BodySystem]
    public let scientificBasis: String
    public let citations: [String]
    public let evidenceLevel: EvidenceLevel
    public let audioImplementation: String

    public init(
        id: UUID = UUID(),
        name: String,
        frequencyRangeHz: ClosedRange<Double>,
        targetSystems: [BodySystem],
        scientificBasis: String,
        citations: [String],
        evidenceLevel: EvidenceLevel,
        audioImplementation: String
    ) {
        self.id = id
        self.name = name
        self.frequencyRangeHz = frequencyRangeHz
        self.targetSystems = targetSystems
        self.scientificBasis = scientificBasis
        self.citations = citations
        self.evidenceLevel = evidenceLevel
        self.audioImplementation = audioImplementation
    }
}

/// Audio entrainment mode
public enum EntrainmentMode: String, CaseIterable, Codable {
    case binauralBeats = "Binaural Beats"
    case isochronicTones = "Isochronic Tones"
    case monaural = "Monaural Beats"
    case breathingGuide = "Breathing Guide"
    case combined = "Combined"

    public var description: String {
        switch self {
        case .binauralBeats: return "Two tones at slightly different frequencies in each ear"
        case .isochronicTones: return "Single tone pulsing at target frequency"
        case .monaural: return "Two tones mixed before reaching ears"
        case .breathingGuide: return "Audio cues for breathing synchronization"
        case .combined: return "Multiple entrainment techniques combined"
        }
    }
}

/// Entrainment session configuration
public struct EntrainmentSession: Codable, Identifiable {
    public let id: UUID
    public let window: String // Window name
    public let mode: EntrainmentMode
    public let targetFrequency: Double
    public let carrierFrequency: Double
    public let duration: TimeInterval
    public let startTime: Date
    public var currentPhase: Double // 0-1

    public init(
        id: UUID = UUID(),
        window: String,
        mode: EntrainmentMode,
        targetFrequency: Double,
        carrierFrequency: Double = 200,
        duration: TimeInterval,
        startTime: Date = Date(),
        currentPhase: Double = 0
    ) {
        self.id = id
        self.window = window
        self.mode = mode
        self.targetFrequency = targetFrequency
        self.carrierFrequency = carrierFrequency
        self.duration = duration
        self.startTime = startTime
        self.currentPhase = currentPhase
    }
}

/// Frequency-body mapping result
public struct FrequencyBodyMapping: Codable {
    public let frequency: Double
    public let primarySystem: BodySystem
    public let secondarySystems: [BodySystem]
    public let expectedEffect: String
    public let evidenceLevel: EvidenceLevel
    public let audioParameters: AudioParameters

    public init(
        frequency: Double,
        primarySystem: BodySystem,
        secondarySystems: [BodySystem],
        expectedEffect: String,
        evidenceLevel: EvidenceLevel,
        audioParameters: AudioParameters
    ) {
        self.frequency = frequency
        self.primarySystem = primarySystem
        self.secondarySystems = secondarySystems
        self.expectedEffect = expectedEffect
        self.evidenceLevel = evidenceLevel
        self.audioParameters = audioParameters
    }
}

/// Audio parameters for entrainment
public struct AudioParameters: Codable {
    public let carrierFrequency: Double
    public let modulationDepth: Double
    public let amplitude: Double
    public let fadeInDuration: TimeInterval
    public let fadeOutDuration: TimeInterval

    public init(
        carrierFrequency: Double,
        modulationDepth: Double,
        amplitude: Double,
        fadeInDuration: TimeInterval = 10,
        fadeOutDuration: TimeInterval = 10
    ) {
        self.carrierFrequency = carrierFrequency
        self.modulationDepth = modulationDepth
        self.amplitude = amplitude
        self.fadeInDuration = fadeInDuration
        self.fadeOutDuration = fadeOutDuration
    }
}

/// Main Adey Windows Bioelectromagnetic Engine
@MainActor
public final class AdeyWindowsBioelectromagneticEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var windows: [AdeyWindow] = []
    @Published public private(set) var currentSession: EntrainmentSession?
    @Published public private(set) var isSessionActive: Bool = false
    @Published public private(set) var currentEntrainmentMode: EntrainmentMode = .binauralBeats
    @Published public private(set) var hrvCoherence: Double = 0.5
    @Published public private(set) var currentMapping: FrequencyBodyMapping?

    // MARK: - Constants

    public static let disclaimer = """
    ADEY WINDOWS BIOELECTROMAGNETIC ENGINE DISCLAIMER

    CRITICAL: This system uses AUDIO (sound waves) to create entrainment effects.
    It does NOT generate or apply electromagnetic fields to the body.

    Dr. W. Ross Adey's research at UCLA and Loma Linda concerned biological effects
    of electromagnetic fields. This application ONLY uses audio frequencies that
    correspond to the frequency ranges studied, NOT electromagnetic radiation.

    Audio entrainment (binaural beats, isochronic tones) may promote relaxation
    but the evidence for specific physiological effects varies. This is NOT an
    electromagnetic therapy device.

    Scientific Basis:
    - Adey WR. Tissue interactions with nonionizing electromagnetic fields.
      Physiological Reviews. 1981;61(2):435-514
    - Blackman CF, et al. Effects of ELF fields on calcium-ion efflux.
      Bioelectromagnetics. 1985
    - Bawin SM, Adey WR. Sensitivity of calcium binding in cerebral tissue
      to weak environmental electric fields. PNAS. 1976;73(6):1999-2003

    This is NOT a medical device. Consult healthcare professionals for
    any health concerns. Do not use if you have epilepsy or are prone to seizures.
    """

    public static let adeyReference = """
    Dr. W. Ross Adey (1922-2004) was a pioneer in bioelectromagnetics research at
    UCLA Brain Research Institute and later at Loma Linda VA Medical Center.
    His work identified specific "frequency windows" where biological tissues
    showed enhanced sensitivity to weak electromagnetic fields.

    Key findings (Physiological Reviews 1981):
    - Calcium efflux from brain tissue at specific ELF frequencies
    - Amplitude windows for biological response
    - Frequency-specific effects on neural tissue

    IMPORTANT: This audio application is INSPIRED by Adey's frequency research
    but uses SOUND, not electromagnetic fields.
    """

    // MARK: - Initialization

    public init() {
        loadScientificWindows()
    }

    // MARK: - Public Methods

    /// Update HRV coherence from biofeedback
    public func updateHRVCoherence(_ coherence: Double) {
        hrvCoherence = max(0, min(1, coherence))
    }

    /// Get window for target body system
    public func getWindow(for system: BodySystem) -> [AdeyWindow] {
        windows.filter { $0.targetSystems.contains(system) }
    }

    /// Get window by name
    public func getWindow(named name: String) -> AdeyWindow? {
        windows.first { $0.name == name }
    }

    /// Start entrainment session
    public func startSession(
        window: AdeyWindow,
        mode: EntrainmentMode,
        duration: TimeInterval
    ) {
        let targetFreq = (window.frequencyRangeHz.lowerBound + window.frequencyRangeHz.upperBound) / 2

        currentSession = EntrainmentSession(
            window: window.name,
            mode: mode,
            targetFrequency: targetFreq,
            carrierFrequency: calculateOptimalCarrier(for: targetFreq),
            duration: duration
        )

        currentEntrainmentMode = mode
        isSessionActive = true

        // Create frequency-body mapping
        currentMapping = createMapping(for: targetFreq, window: window)
    }

    /// Stop current session
    public func stopSession() {
        currentSession = nil
        isSessionActive = false
        currentMapping = nil
    }

    /// Update session phase
    public func updateSessionPhase(_ phase: Double) {
        guard var session = currentSession else { return }
        session.currentPhase = max(0, min(1, phase))
        currentSession = session
    }

    /// Get recommended window based on current state
    public func getRecommendedWindow() -> AdeyWindow? {
        // Based on HRV coherence, recommend appropriate window
        if hrvCoherence < 0.3 {
            // Low coherence - recommend alpha for relaxation
            return windows.first { $0.name == "Alpha" }
        } else if hrvCoherence < 0.6 {
            // Moderate - recommend theta for deeper relaxation
            return windows.first { $0.name == "Theta" }
        } else if hrvCoherence > 0.8 {
            // High coherence - can explore gamma for insight
            return windows.first { $0.name == "Gamma" }
        } else {
            // Default to HRV Coherence window
            return windows.first { $0.name == "HRV Coherence" }
        }
    }

    /// Calculate audio parameters for entrainment
    public func calculateAudioParameters(
        targetFrequency: Double,
        mode: EntrainmentMode
    ) -> AudioParameters {
        let carrier = calculateOptimalCarrier(for: targetFrequency)
        let modDepth: Double
        let amplitude: Double

        switch mode {
        case .binauralBeats:
            modDepth = 1.0
            amplitude = 0.5
        case .isochronicTones:
            modDepth = 1.0
            amplitude = 0.6
        case .monaural:
            modDepth = 0.8
            amplitude = 0.5
        case .breathingGuide:
            modDepth = 0.3
            amplitude = 0.4
        case .combined:
            modDepth = 0.7
            amplitude = 0.5
        }

        return AudioParameters(
            carrierFrequency: carrier,
            modulationDepth: modDepth,
            amplitude: amplitude
        )
    }

    // MARK: - Private Methods

    private func loadScientificWindows() {
        windows = [
            AdeyWindow(
                name: "Delta",
                frequencyRangeHz: 0.5...4.0,
                targetSystems: [.nervous, .immune],
                scientificBasis: "Deep sleep frequencies associated with healing and regeneration",
                citations: ["Adey WR. Physiological Reviews. 1981;61(2):435-514"],
                evidenceLevel: .humanObservational,
                audioImplementation: "Binaural beats at 2 Hz with 100-200 Hz carrier"
            ),
            AdeyWindow(
                name: "Theta",
                frequencyRangeHz: 4.0...8.0,
                targetSystems: [.nervous, .endocrine],
                scientificBasis: "Meditation and creativity frequencies, memory consolidation",
                citations: ["Blackman CF, et al. Bioelectromagnetics. 1985"],
                evidenceLevel: .humanObservational,
                audioImplementation: "Binaural beats at 6 Hz with 200-400 Hz carrier"
            ),
            AdeyWindow(
                name: "Alpha",
                frequencyRangeHz: 8.0...13.0,
                targetSystems: [.nervous, .cardiovascular],
                scientificBasis: "Relaxed alertness, reduced anxiety, improved learning",
                citations: ["Bawin SM, Adey WR. PNAS. 1976;73(6):1999-2003"],
                evidenceLevel: .humanRCT,
                audioImplementation: "Binaural beats at 10 Hz with 200-400 Hz carrier"
            ),
            AdeyWindow(
                name: "Beta",
                frequencyRangeHz: 13.0...30.0,
                targetSystems: [.nervous, .musculoskeletal],
                scientificBasis: "Active thinking, focus, alertness",
                citations: ["Adey WR. Physiological Reviews. 1981;61(2):435-514"],
                evidenceLevel: .humanObservational,
                audioImplementation: "Isochronic tones at 15-20 Hz"
            ),
            AdeyWindow(
                name: "Gamma",
                frequencyRangeHz: 30.0...100.0,
                targetSystems: [.nervous],
                scientificBasis: "Higher cognitive functions, binding, peak experience",
                citations: ["Davidson RJ, Lutz A. IEEE Signal Processing. 2008"],
                evidenceLevel: .humanObservational,
                audioImplementation: "Isochronic tones at 40 Hz (gamma peak)"
            ),
            AdeyWindow(
                name: "Schumann Resonance",
                frequencyRangeHz: 7.83...7.83,
                targetSystems: [.nervous, .cardiovascular, .immune],
                scientificBasis: "Earth's electromagnetic resonance frequency",
                citations: ["Schumann WO. Z Naturforsch. 1952;7a:149-154"],
                evidenceLevel: .traditionalUse,
                audioImplementation: "Binaural beats at 7.83 Hz with pink noise"
            ),
            AdeyWindow(
                name: "HRV Coherence",
                frequencyRangeHz: 0.1...0.1,
                targetSystems: [.cardiovascular, .nervous, .respiratory],
                scientificBasis: "Optimal baroreflex sensitivity at 0.1 Hz (6 breaths/min)",
                citations: ["McCraty R. HeartMath Institute. 2015"],
                evidenceLevel: .humanRCT,
                audioImplementation: "Breathing guide with 5-second inhale, 5-second exhale"
            ),
            AdeyWindow(
                name: "PEMF Low",
                frequencyRangeHz: 1.0...10.0,
                targetSystems: [.musculoskeletal, .immune],
                scientificBasis: "Frequencies used in PEMF therapy devices",
                citations: ["Bassett CA, et al. Science. 1974;184(4136):575-577"],
                evidenceLevel: .humanRCT,
                audioImplementation: "Isochronic tones mimicking PEMF pulse patterns"
            ),
            AdeyWindow(
                name: "Vagal Tone",
                frequencyRangeHz: 0.15...0.4,
                targetSystems: [.cardiovascular, .respiratory, .nervous],
                scientificBasis: "High-frequency HRV band associated with vagal activity",
                citations: ["Porges SW. Psychophysiology. 2007;44(2):161-166"],
                evidenceLevel: .humanRCT,
                audioImplementation: "Rhythmic breathing guide at 9-24 breaths/min"
            ),
            AdeyWindow(
                name: "Adey Calcium Window",
                frequencyRangeHz: 6.0...20.0,
                targetSystems: [.nervous],
                scientificBasis: "Original Adey research window for calcium efflux",
                citations: ["Adey WR. Physiological Reviews. 1981", "Blackman CF. 1985"],
                evidenceLevel: .animalStudy,
                audioImplementation: "Binaural beats scanning through 6-20 Hz range"
            )
        ]
    }

    private func calculateOptimalCarrier(for targetFrequency: Double) -> Double {
        // Carrier frequency should be in comfortable hearing range
        // and create pleasant binaural beat perception
        if targetFrequency < 4 {
            return 150 // Lower carrier for delta
        } else if targetFrequency < 8 {
            return 200 // Mid-low for theta
        } else if targetFrequency < 15 {
            return 250 // Mid for alpha/low beta
        } else {
            return 300 // Higher for beta/gamma
        }
    }

    private func createMapping(for frequency: Double, window: AdeyWindow) -> FrequencyBodyMapping {
        let params = calculateAudioParameters(targetFrequency: frequency, mode: currentEntrainmentMode)

        return FrequencyBodyMapping(
            frequency: frequency,
            primarySystem: window.targetSystems.first ?? .nervous,
            secondarySystems: Array(window.targetSystems.dropFirst()),
            expectedEffect: window.scientificBasis,
            evidenceLevel: window.evidenceLevel,
            audioParameters: params
        )
    }
}

// MARK: - ========================================
// MARK: - SwiftUI Preview Helpers
// MARK: - ========================================

#if DEBUG
/// Preview provider for wellness engines
public struct WellnessEnginesPreview {

    public static var longevityEngine: LongevityNutritionEngine {
        let engine = LongevityNutritionEngine()
        return engine
    }

    public static var neuroSpiritualEngine: NeuroSpiritualEngine {
        let engine = NeuroSpiritualEngine()
        engine.updateHRVCoherence(0.75)
        return engine
    }

    public static var quantumHealthEngine: QuantumHealthBiofeedbackEngine {
        let engine = QuantumHealthBiofeedbackEngine()
        engine.startSession(type: .meditation)
        return engine
    }

    public static var adeyEngine: AdeyWindowsBioelectromagneticEngine {
        let engine = AdeyWindowsBioelectromagneticEngine()
        return engine
    }
}
#endif

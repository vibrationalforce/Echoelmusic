// LongevityNutritionEngine.swift
// Echoelmusic - Holistic Bio-Coherence Platform
//
// Wissenschaftlich fundierte Langlebigkeits-Ernährung
// Basiert auf: Blue Zones, David Sinclair, HRV-Longevity Studien (PMC7527628)
//
// HINWEIS: Keine medizinische Beratung. Konsultieren Sie einen Arzt.

import Foundation

// MARK: - Longevity Pathways

/// Die 9 Hallmarks of Aging (López-Otín et al., Cell 2013)
public enum HallmarkOfAging: String, CaseIterable, Codable {
    case genomicInstability = "genomic_instability"
    case telomereAttrition = "telomere_attrition"
    case epigeneticAlterations = "epigenetic_alterations"
    case lossOfProteostasis = "loss_of_proteostasis"
    case deregulatedNutrientSensing = "deregulated_nutrient_sensing"
    case mitochondrialDysfunction = "mitochondrial_dysfunction"
    case cellularSenescence = "cellular_senescence"
    case stemCellExhaustion = "stem_cell_exhaustion"
    case alteredIntercellularCommunication = "altered_intercellular_communication"

    public var description: String {
        switch self {
        case .genomicInstability:
            return "DNA-Schäden und Mutationen akkumulieren"
        case .telomereAttrition:
            return "Telomere verkürzen sich bei jeder Zellteilung"
        case .epigeneticAlterations:
            return "Epigenetische Muster verändern sich"
        case .lossOfProteostasis:
            return "Proteine falten sich fehlerhaft"
        case .deregulatedNutrientSensing:
            return "mTOR, AMPK, Sirtuine dysreguliert"
        case .mitochondrialDysfunction:
            return "Energieproduktion sinkt, ROS steigen"
        case .cellularSenescence:
            return "Seneszente Zellen akkumulieren (SASP)"
        case .stemCellExhaustion:
            return "Regenerationsfähigkeit sinkt"
        case .alteredIntercellularCommunication:
            return "Chronische Entzündung (Inflammaging)"
        }
    }

    /// Nährstoffe die diesen Hallmark adressieren
    public var targetingNutrients: [String] {
        switch self {
        case .genomicInstability:
            return ["Sulforaphan", "Curcumin", "EGCG", "Resveratrol", "NAD+"]
        case .telomereAttrition:
            return ["Omega-3", "Vitamin D", "Folat", "Astragalus", "Meditation"]
        case .epigeneticAlterations:
            return ["Sulforaphan", "Resveratrol", "Curcumin", "Butyrat", "SAMe"]
        case .lossOfProteostasis:
            return ["Spermidine", "Curcumin", "Fasting", "Heat Shock (Sauna)"]
        case .deregulatedNutrientSensing:
            return ["Fasting", "Metformin", "Berberine", "AKG", "Rapamycin"]
        case .mitochondrialDysfunction:
            return ["CoQ10", "PQQ", "NAD+/NMN", "Urolithin A", "Creatine"]
        case .cellularSenescence:
            return ["Fisetin", "Quercetin", "Dasatinib", "Piperlongumine", "Spermidine"]
        case .stemCellExhaustion:
            return ["NAD+", "Rapamycin", "Fasting", "GH Secretagogues"]
        case .alteredIntercellularCommunication:
            return ["Omega-3", "Curcumin", "Resveratrol", "Fasting", "Exercise"]
        }
    }
}

// MARK: - Longevity Compounds

/// Wissenschaftlich erforschte Langlebigkeits-Substanzen
public struct LongevityCompound: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let category: CompoundCategory
    public let mechanism: String
    public let dosage: String
    public let timing: String
    public let foodSources: [String]
    public let targetedHallmarks: [HallmarkOfAging]
    public let evidenceLevel: EvidenceLevel
    public let hrvImpact: Double  // -1 bis +1
    public let caution: String

    public init(
        id: UUID = UUID(),
        name: String,
        category: CompoundCategory,
        mechanism: String,
        dosage: String,
        timing: String,
        foodSources: [String],
        targetedHallmarks: [HallmarkOfAging],
        evidenceLevel: EvidenceLevel,
        hrvImpact: Double,
        caution: String
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.mechanism = mechanism
        self.dosage = dosage
        self.timing = timing
        self.foodSources = foodSources
        self.targetedHallmarks = targetedHallmarks
        self.evidenceLevel = evidenceLevel
        self.hrvImpact = hrvImpact
        self.caution = caution
    }
}

public enum CompoundCategory: String, CaseIterable, Codable {
    case sirtuin = "sirtuin_activator"
    case senolytic = "senolytic"
    case nad = "nad_precursor"
    case mitochondrial = "mitochondrial"
    case epigenetic = "epigenetic"
    case antiInflammatory = "anti_inflammatory"
    case autophagy = "autophagy_inducer"
    case telomere = "telomere_support"
    case antioxidant = "antioxidant"
    case adaptogen = "adaptogen"
}

public enum EvidenceLevel: String, CaseIterable, Codable {
    case humanRCT = "human_rct"           // Randomisierte kontrollierte Studie
    case humanObservational = "human_obs"  // Beobachtungsstudie
    case animalStudy = "animal"            // Tiermodell
    case inVitro = "in_vitro"             // Zellkultur
    case traditional = "traditional"       // Traditionelle Verwendung

    public var reliability: Double {
        switch self {
        case .humanRCT: return 1.0
        case .humanObservational: return 0.8
        case .animalStudy: return 0.5
        case .inVitro: return 0.3
        case .traditional: return 0.4
        }
    }
}

// MARK: - Blue Zones Principles

/// Die 9 Blue Zones Power 9 Prinzipien
public enum BlueZonePrinciple: String, CaseIterable, Codable {
    case moveNaturally = "move_naturally"
    case purpose = "purpose"
    case downshift = "downshift"
    case eightyPercentRule = "80_percent_rule"
    case plantSlant = "plant_slant"
    case wineAtFive = "wine_at_five"
    case belong = "belong"
    case lovedOnesFirst = "loved_ones_first"
    case rightTribe = "right_tribe"

    public var description: String {
        switch self {
        case .moveNaturally: return "Natürliche Bewegung im Alltag integriert"
        case .purpose: return "Ikigai/Plan de Vida - Lebensinn kennen"
        case .downshift: return "Tägliche Stress-Reduktion (Gebet, Siesta, Happy Hour)"
        case .eightyPercentRule: return "Hara Hachi Bu - Nur 80% satt essen"
        case .plantSlant: return "95% pflanzliche Ernährung, Bohnen als Basis"
        case .wineAtFive: return "1-2 Gläser Wein täglich mit Freunden"
        case .belong: return "Spirituelle Gemeinschaft/Glaubensgruppe"
        case .lovedOnesFirst: return "Familie priorisieren"
        case .rightTribe: return "Soziales Netzwerk das Gesundheit unterstützt"
        }
    }

    public var coherenceImpact: Double {
        switch self {
        case .moveNaturally: return 0.6
        case .purpose: return 0.9
        case .downshift: return 0.95
        case .eightyPercentRule: return 0.5
        case .plantSlant: return 0.6
        case .wineAtFive: return 0.3
        case .belong: return 0.85
        case .lovedOnesFirst: return 0.8
        case .rightTribe: return 0.75
        }
    }
}

// MARK: - Chronotype-Specific Longevity Plans

/// Langlebigkeits-Ernährungsplan pro Chronotyp
public struct ChronotypeLongevityPlan: Identifiable, Codable {
    public let id: UUID
    public let chronotype: Chronotype
    public let fastingWindow: String
    public let eatingWindow: String
    public let firstMealTime: String
    public let lastMealTime: String
    public let keyFoods: [LongevityFood]
    public let supplements: [LongevityCompound]
    public let exerciseProtocol: String
    public let sleepProtocol: String
    public let stressProtocol: String
    public let estimatedLifespanBenefit: String

    public init(
        id: UUID = UUID(),
        chronotype: Chronotype,
        fastingWindow: String,
        eatingWindow: String,
        firstMealTime: String,
        lastMealTime: String,
        keyFoods: [LongevityFood],
        supplements: [LongevityCompound],
        exerciseProtocol: String,
        sleepProtocol: String,
        stressProtocol: String,
        estimatedLifespanBenefit: String
    ) {
        self.id = id
        self.chronotype = chronotype
        self.fastingWindow = fastingWindow
        self.eatingWindow = eatingWindow
        self.firstMealTime = firstMealTime
        self.lastMealTime = lastMealTime
        self.keyFoods = keyFoods
        self.supplements = supplements
        self.exerciseProtocol = exerciseProtocol
        self.sleepProtocol = sleepProtocol
        self.stressProtocol = stressProtocol
        self.estimatedLifespanBenefit = estimatedLifespanBenefit
    }
}

public struct LongevityFood: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let category: FoodCategory
    public let activeCompounds: [String]
    public let targetedHallmarks: [HallmarkOfAging]
    public let servingSize: String
    public let frequency: String
    public let hrvBenefit: Double
    public let blueZoneOrigin: String?

    public init(
        id: UUID = UUID(),
        name: String,
        category: FoodCategory,
        activeCompounds: [String],
        targetedHallmarks: [HallmarkOfAging],
        servingSize: String,
        frequency: String,
        hrvBenefit: Double,
        blueZoneOrigin: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.activeCompounds = activeCompounds
        self.targetedHallmarks = targetedHallmarks
        self.servingSize = servingSize
        self.frequency = frequency
        self.hrvBenefit = hrvBenefit
        self.blueZoneOrigin = blueZoneOrigin
    }
}

public enum FoodCategory: String, CaseIterable, Codable {
    case cruciferous = "cruciferous"
    case legumes = "legumes"
    case berries = "berries"
    case nuts = "nuts"
    case fermented = "fermented"
    case seafood = "seafood"
    case leafyGreens = "leafy_greens"
    case alliums = "alliums"
    case spices = "spices"
    case beverages = "beverages"
    case wholegrains = "whole_grains"
    case mushrooms = "mushrooms"
}

// MARK: - Longevity Nutrition Engine

@MainActor
public final class LongevityNutritionEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var currentPlan: ChronotypeLongevityPlan?
    @Published public private(set) var biologicalAge: Double = 0
    @Published public private(set) var longevityScore: Double = 0.5
    @Published public private(set) var hallmarkScores: [HallmarkOfAging: Double] = [:]

    // MARK: - Static Data

    /// Wissenschaftlich fundierte Langlebigkeits-Lebensmittel
    public static let longevityFoods: [LongevityFood] = [
        // CRUCIFEROUS - Sulforaphan (DNA Repair, Epigenetics)
        LongevityFood(
            name: "Brokkoli Sprossen",
            category: .cruciferous,
            activeCompounds: ["Sulforaphan", "Glucoraphanin", "DIM"],
            targetedHallmarks: [.genomicInstability, .epigeneticAlterations, .cellularSenescence],
            servingSize: "50g",
            frequency: "Täglich",
            hrvBenefit: 0.6,
            blueZoneOrigin: nil
        ),
        LongevityFood(
            name: "Brokkoli",
            category: .cruciferous,
            activeCompounds: ["Sulforaphan", "Vitamin C", "Folat"],
            targetedHallmarks: [.genomicInstability, .alteredIntercellularCommunication],
            servingSize: "150g",
            frequency: "4-5x/Woche",
            hrvBenefit: 0.5,
            blueZoneOrigin: nil
        ),

        // LEGUMES - Blue Zone Cornerstone
        LongevityFood(
            name: "Schwarze Bohnen",
            category: .legumes,
            activeCompounds: ["Anthocyane", "Ballaststoffe", "Protein", "Folat"],
            targetedHallmarks: [.deregulatedNutrientSensing, .alteredIntercellularCommunication],
            servingSize: "150g gekocht",
            frequency: "Täglich",
            hrvBenefit: 0.5,
            blueZoneOrigin: "Nicoya, Costa Rica"
        ),
        LongevityFood(
            name: "Linsen",
            category: .legumes,
            activeCompounds: ["Protein", "Eisen", "Folat", "Ballaststoffe"],
            targetedHallmarks: [.deregulatedNutrientSensing],
            servingSize: "150g gekocht",
            frequency: "4-5x/Woche",
            hrvBenefit: 0.45,
            blueZoneOrigin: "Sardinia, Italien"
        ),
        LongevityFood(
            name: "Sojabohnen/Tofu",
            category: .legumes,
            activeCompounds: ["Isoflavone", "Spermidine", "Protein"],
            targetedHallmarks: [.lossOfProteostasis, .cellularSenescence],
            servingSize: "100g",
            frequency: "3-4x/Woche",
            hrvBenefit: 0.5,
            blueZoneOrigin: "Okinawa, Japan"
        ),

        // BERRIES - Polyphenole, Senolytics
        LongevityFood(
            name: "Blaubeeren",
            category: .berries,
            activeCompounds: ["Anthocyane", "Pterostilbene", "Quercetin"],
            targetedHallmarks: [.genomicInstability, .alteredIntercellularCommunication],
            servingSize: "100g",
            frequency: "Täglich",
            hrvBenefit: 0.55,
            blueZoneOrigin: nil
        ),
        LongevityFood(
            name: "Erdbeeren (Fisetin-reich)",
            category: .berries,
            activeCompounds: ["Fisetin", "Vitamin C", "Ellagitannine"],
            targetedHallmarks: [.cellularSenescence],
            servingSize: "150g",
            frequency: "3-4x/Woche",
            hrvBenefit: 0.5,
            blueZoneOrigin: nil
        ),

        // NUTS - Brain, Heart, Longevity
        LongevityFood(
            name: "Walnüsse",
            category: .nuts,
            activeCompounds: ["ALA Omega-3", "Polyphenole", "Melatonin"],
            targetedHallmarks: [.alteredIntercellularCommunication, .mitochondrialDysfunction],
            servingSize: "30g (7 Walnüsse)",
            frequency: "Täglich",
            hrvBenefit: 0.6,
            blueZoneOrigin: "Sardinia, Italien"
        ),
        LongevityFood(
            name: "Mandeln",
            category: .nuts,
            activeCompounds: ["Vitamin E", "Magnesium", "Ballaststoffe"],
            targetedHallmarks: [.deregulatedNutrientSensing],
            servingSize: "30g",
            frequency: "Täglich",
            hrvBenefit: 0.5,
            blueZoneOrigin: "Loma Linda, USA"
        ),

        // FERMENTED - Gut-Brain-Heart Axis
        LongevityFood(
            name: "Natto",
            category: .fermented,
            activeCompounds: ["Spermidine", "Nattokinase", "Vitamin K2"],
            targetedHallmarks: [.lossOfProteostasis, .cellularSenescence, .alteredIntercellularCommunication],
            servingSize: "50g",
            frequency: "3-4x/Woche",
            hrvBenefit: 0.7,
            blueZoneOrigin: "Okinawa, Japan"
        ),
        LongevityFood(
            name: "Kimchi/Sauerkraut",
            category: .fermented,
            activeCompounds: ["Probiotika", "Vitamin C", "Sulforaphan"],
            targetedHallmarks: [.alteredIntercellularCommunication],
            servingSize: "50g",
            frequency: "Täglich",
            hrvBenefit: 0.55,
            blueZoneOrigin: nil
        ),

        // SEAFOOD - Omega-3, Selenium
        LongevityFood(
            name: "Wildlachs",
            category: .seafood,
            activeCompounds: ["EPA", "DHA", "Astaxanthin", "Selen"],
            targetedHallmarks: [.alteredIntercellularCommunication, .mitochondrialDysfunction, .telomereAttrition],
            servingSize: "150g",
            frequency: "2-3x/Woche",
            hrvBenefit: 0.8,
            blueZoneOrigin: nil
        ),
        LongevityFood(
            name: "Sardinen",
            category: .seafood,
            activeCompounds: ["Omega-3", "Calcium", "CoQ10"],
            targetedHallmarks: [.alteredIntercellularCommunication, .mitochondrialDysfunction],
            servingSize: "100g",
            frequency: "2x/Woche",
            hrvBenefit: 0.7,
            blueZoneOrigin: "Sardinia, Italien"
        ),

        // LEAFY GREENS
        LongevityFood(
            name: "Grünkohl",
            category: .leafyGreens,
            activeCompounds: ["Sulforaphan", "Lutein", "Vitamin K", "Quercetin"],
            targetedHallmarks: [.genomicInstability, .epigeneticAlterations],
            servingSize: "100g",
            frequency: "4-5x/Woche",
            hrvBenefit: 0.55,
            blueZoneOrigin: nil
        ),
        LongevityFood(
            name: "Spinat",
            category: .leafyGreens,
            activeCompounds: ["Nitrate", "Magnesium", "Folat", "Lutein"],
            targetedHallmarks: [.mitochondrialDysfunction],
            servingSize: "100g",
            frequency: "Täglich",
            hrvBenefit: 0.5,
            blueZoneOrigin: nil
        ),

        // ALLIUMS - Sulfur Compounds
        LongevityFood(
            name: "Knoblauch",
            category: .alliums,
            activeCompounds: ["Allicin", "S-Allyl-Cystein", "Selen"],
            targetedHallmarks: [.alteredIntercellularCommunication, .genomicInstability],
            servingSize: "2-3 Zehen",
            frequency: "Täglich",
            hrvBenefit: 0.45,
            blueZoneOrigin: "Ikaria, Griechenland"
        ),
        LongevityFood(
            name: "Zwiebeln",
            category: .alliums,
            activeCompounds: ["Quercetin", "Schwefelverbindungen"],
            targetedHallmarks: [.cellularSenescence, .alteredIntercellularCommunication],
            servingSize: "50g",
            frequency: "Täglich",
            hrvBenefit: 0.4,
            blueZoneOrigin: nil
        ),

        // SPICES
        LongevityFood(
            name: "Kurkuma + schwarzer Pfeffer",
            category: .spices,
            activeCompounds: ["Curcumin", "Piperin (2000% Absorption)"],
            targetedHallmarks: [.alteredIntercellularCommunication, .lossOfProteostasis, .epigeneticAlterations],
            servingSize: "1 TL Kurkuma + Prise Pfeffer",
            frequency: "Täglich",
            hrvBenefit: 0.6,
            blueZoneOrigin: "Okinawa (als Gelbwurz)"
        ),
        LongevityFood(
            name: "Ingwer",
            category: .spices,
            activeCompounds: ["Gingerole", "Shogaole"],
            targetedHallmarks: [.alteredIntercellularCommunication],
            servingSize: "10g frisch",
            frequency: "Täglich",
            hrvBenefit: 0.45,
            blueZoneOrigin: "Okinawa, Japan"
        ),

        // BEVERAGES
        LongevityFood(
            name: "Grüner Tee (Matcha)",
            category: .beverages,
            activeCompounds: ["EGCG", "L-Theanin", "Catechine"],
            targetedHallmarks: [.genomicInstability, .epigeneticAlterations, .cellularSenescence],
            servingSize: "2-3 Tassen",
            frequency: "Täglich",
            hrvBenefit: 0.65,
            blueZoneOrigin: "Okinawa, Japan"
        ),
        LongevityFood(
            name: "Rotwein (Cannonau)",
            category: .beverages,
            activeCompounds: ["Resveratrol", "Quercetin", "Procyanidine"],
            targetedHallmarks: [.deregulatedNutrientSensing, .alteredIntercellularCommunication],
            servingSize: "1-2 Gläser (150ml)",
            frequency: "Täglich mit Mahlzeit",
            hrvBenefit: 0.3,
            blueZoneOrigin: "Sardinia, Italien"
        ),
        LongevityFood(
            name: "Kaffee",
            category: .beverages,
            activeCompounds: ["Chlorogensäure", "Kahweol", "Trigonellin"],
            targetedHallmarks: [.deregulatedNutrientSensing, .alteredIntercellularCommunication],
            servingSize: "2-4 Tassen",
            frequency: "Morgens (vor 14:00)",
            hrvBenefit: 0.35,
            blueZoneOrigin: "Ikaria, Sardinia"
        ),

        // MUSHROOMS
        LongevityFood(
            name: "Shiitake",
            category: .mushrooms,
            activeCompounds: ["Beta-Glucane", "Ergothionein", "Lentinan"],
            targetedHallmarks: [.alteredIntercellularCommunication, .stemCellExhaustion],
            servingSize: "100g",
            frequency: "3x/Woche",
            hrvBenefit: 0.5,
            blueZoneOrigin: "Okinawa, Japan"
        ),
        LongevityFood(
            name: "Lion's Mane",
            category: .mushrooms,
            activeCompounds: ["Hericenone", "Erinacine", "NGF-Stimulation"],
            targetedHallmarks: [.stemCellExhaustion, .alteredIntercellularCommunication],
            servingSize: "500mg-2g Extrakt",
            frequency: "Täglich",
            hrvBenefit: 0.55,
            blueZoneOrigin: nil
        ),

        // WHOLE GRAINS
        LongevityFood(
            name: "Haferflocken",
            category: .wholegrains,
            activeCompounds: ["Beta-Glucan", "Avenanthramide", "Ballaststoffe"],
            targetedHallmarks: [.deregulatedNutrientSensing, .alteredIntercellularCommunication],
            servingSize: "50g",
            frequency: "Täglich",
            hrvBenefit: 0.45,
            blueZoneOrigin: nil
        ),
        LongevityFood(
            name: "Süßkartoffel (Lila)",
            category: .wholegrains,
            activeCompounds: ["Anthocyane", "Beta-Carotin", "Ballaststoffe"],
            targetedHallmarks: [.genomicInstability, .deregulatedNutrientSensing],
            servingSize: "150g",
            frequency: "3-4x/Woche",
            hrvBenefit: 0.5,
            blueZoneOrigin: "Okinawa, Japan"
        )
    ]

    /// Wissenschaftlich erforschte Supplements (mit Vorsicht!)
    public static let longevityCompounds: [LongevityCompound] = [
        // NAD+ Precursors
        LongevityCompound(
            name: "NMN (Nicotinamid-Mononukleotid)",
            category: .nad,
            mechanism: "NAD+ Vorläufer, aktiviert Sirtuine, DNA-Reparatur",
            dosage: "250-1000mg",
            timing: "Morgens",
            foodSources: ["Edamame", "Brokkoli", "Avocado"],
            targetedHallmarks: [.mitochondrialDysfunction, .genomicInstability, .epigeneticAlterations],
            evidenceLevel: .humanObservational,
            hrvImpact: 0.4,
            caution: "Langzeitstudien fehlen. Mit Arzt besprechen."
        ),
        LongevityCompound(
            name: "NR (Nicotinamid-Ribosid)",
            category: .nad,
            mechanism: "NAD+ Vorläufer, alternative zu NMN",
            dosage: "300-1000mg",
            timing: "Morgens",
            foodSources: ["Milch", "Hefe"],
            targetedHallmarks: [.mitochondrialDysfunction, .genomicInstability],
            evidenceLevel: .humanRCT,
            hrvImpact: 0.35,
            caution: "FDA GRAS Status. Besser erforscht als NMN."
        ),

        // Sirtuin Activators
        LongevityCompound(
            name: "Resveratrol",
            category: .sirtuin,
            mechanism: "SIRT1 Aktivator, mimics Kalorienrestriktion",
            dosage: "500-1000mg",
            timing: "Morgens mit Fett (Joghurt)",
            foodSources: ["Rotwein", "Traubenschalen", "Erdnüsse"],
            targetedHallmarks: [.deregulatedNutrientSensing, .mitochondrialDysfunction],
            evidenceLevel: .humanObservational,
            hrvImpact: 0.4,
            caution: "Bioverfügbarkeit niedrig ohne Fett. Wechselwirkung mit Blutverdünnern."
        ),
        LongevityCompound(
            name: "Pterostilbene",
            category: .sirtuin,
            mechanism: "4x bioverfügbarer als Resveratrol",
            dosage: "50-250mg",
            timing: "Morgens",
            foodSources: ["Blaubeeren", "Weintrauben"],
            targetedHallmarks: [.deregulatedNutrientSensing, .genomicInstability],
            evidenceLevel: .humanObservational,
            hrvImpact: 0.45,
            caution: "Weniger erforscht als Resveratrol."
        ),

        // Senolytics
        LongevityCompound(
            name: "Fisetin",
            category: .senolytic,
            mechanism: "Eliminiert seneszente Zellen, stärkstes natürliches Senolytikum",
            dosage: "100-500mg (zyklisch: 2 Tage/Monat)",
            timing: "Mit Mahlzeit",
            foodSources: ["Erdbeeren", "Äpfel", "Zwiebeln", "Gurken"],
            targetedHallmarks: [.cellularSenescence],
            evidenceLevel: .humanObservational,
            hrvImpact: 0.5,
            caution: "Intermittierend dosieren. Nicht während Krankheit."
        ),
        LongevityCompound(
            name: "Quercetin",
            category: .senolytic,
            mechanism: "Senolytikum (mit Dasatinib), anti-inflammatorisch",
            dosage: "500-1000mg",
            timing: "Mit Mahlzeit",
            foodSources: ["Zwiebeln", "Äpfel", "Kapern", "Brokkoli"],
            targetedHallmarks: [.cellularSenescence, .alteredIntercellularCommunication],
            evidenceLevel: .humanRCT,
            hrvImpact: 0.45,
            caution: "Kann mit Medikamenten interagieren."
        ),

        // Autophagy
        LongevityCompound(
            name: "Spermidine",
            category: .autophagy,
            mechanism: "Induziert Autophagie, Zellreinigung",
            dosage: "1-5mg",
            timing: "Morgens",
            foodSources: ["Natto", "Weizenkeime", "Pilze", "Erbsen", "Käse (aged)"],
            targetedHallmarks: [.lossOfProteostasis, .cellularSenescence, .mitochondrialDysfunction],
            evidenceLevel: .humanObservational,
            hrvImpact: 0.55,
            caution: "Aus Nahrung bevorzugen (Natto, Weizenkeime)."
        ),

        // Mitochondrial Support
        LongevityCompound(
            name: "CoQ10 (Ubiquinol)",
            category: .mitochondrial,
            mechanism: "Elektronentransportkette, Antioxidans",
            dosage: "100-300mg Ubiquinol",
            timing: "Mit fetthaltiger Mahlzeit",
            foodSources: ["Organfleisch", "Sardinen", "Erdnüsse"],
            targetedHallmarks: [.mitochondrialDysfunction],
            evidenceLevel: .humanRCT,
            hrvImpact: 0.5,
            caution: "Ubiquinol besser als Ubiquinon für >40 Jahre."
        ),
        LongevityCompound(
            name: "PQQ (Pyrrolochinolinchinon)",
            category: .mitochondrial,
            mechanism: "Mitochondrien-Biogenese, Neuroprotektion",
            dosage: "10-20mg",
            timing: "Morgens",
            foodSources: ["Kiwi", "Papaya", "Natto", "grüner Tee"],
            targetedHallmarks: [.mitochondrialDysfunction, .stemCellExhaustion],
            evidenceLevel: .humanObservational,
            hrvImpact: 0.4,
            caution: "Am besten mit CoQ10 kombinieren."
        ),
        LongevityCompound(
            name: "Urolithin A",
            category: .mitochondrial,
            mechanism: "Mitophagie (defekte Mitochondrien entfernen)",
            dosage: "500-1000mg",
            timing: "Morgens",
            foodSources: ["Granatapfel", "Walnüsse", "Beeren (via Darmbakterien)"],
            targetedHallmarks: [.mitochondrialDysfunction],
            evidenceLevel: .humanRCT,
            hrvImpact: 0.45,
            caution: "Körpereigene Produktion variiert je nach Mikrobiom."
        ),

        // Anti-Inflammatory
        LongevityCompound(
            name: "Omega-3 (EPA/DHA)",
            category: .antiInflammatory,
            mechanism: "Resolins, anti-inflammatorisch, Membranfluidität",
            dosage: "2-4g EPA+DHA",
            timing: "Mit Mahlzeit",
            foodSources: ["Lachs", "Sardinen", "Makrele", "Algenöl"],
            targetedHallmarks: [.alteredIntercellularCommunication, .telomereAttrition],
            evidenceLevel: .humanRCT,
            hrvImpact: 0.8,
            caution: "Höhere Dosen mit Arzt besprechen. Blutverdünnende Wirkung."
        ),
        LongevityCompound(
            name: "Curcumin + Piperin",
            category: .antiInflammatory,
            mechanism: "NF-κB Hemmung, Epigenetik, Autophagie",
            dosage: "500-2000mg + 20mg Piperin",
            timing: "Mit fetthaltiger Mahlzeit",
            foodSources: ["Kurkuma", "schwarzer Pfeffer"],
            targetedHallmarks: [.alteredIntercellularCommunication, .epigeneticAlterations, .lossOfProteostasis],
            evidenceLevel: .humanRCT,
            hrvImpact: 0.55,
            caution: "Piperin erhöht Absorption um 2000%. Kann mit Medikamenten interagieren."
        ),

        // Epigenetic
        LongevityCompound(
            name: "Sulforaphan",
            category: .epigenetic,
            mechanism: "Nrf2 Aktivator, HDAC Inhibitor, Phase 2 Enzyme",
            dosage: "10-50mg (oder Brokkoli Sprossen)",
            timing: "Morgens",
            foodSources: ["Brokkoli Sprossen", "Brokkoli", "Rosenkohl"],
            targetedHallmarks: [.genomicInstability, .epigeneticAlterations, .alteredIntercellularCommunication],
            evidenceLevel: .humanRCT,
            hrvImpact: 0.5,
            caution: "Sprossen am besten (100x mehr als reifer Brokkoli)."
        ),

        // Telomere
        LongevityCompound(
            name: "Astragalus (TA-65/Cycloastragenol)",
            category: .telomere,
            mechanism: "Telomerase Aktivierung",
            dosage: "25-50mg Cycloastragenol",
            timing: "Morgens",
            foodSources: ["Astragalus Wurzel (TCM)"],
            targetedHallmarks: [.telomereAttrition],
            evidenceLevel: .humanObservational,
            hrvImpact: 0.3,
            caution: "Kontrovers - Telomerase auch in Krebszellen aktiv. Mit Arzt besprechen."
        ),

        // Adaptogens for HRV
        LongevityCompound(
            name: "Ashwagandha (KSM-66)",
            category: .adaptogen,
            mechanism: "Cortisol -30%, GABA-erg, Telomere",
            dosage: "300-600mg",
            timing: "Abends",
            foodSources: [],
            targetedHallmarks: [.alteredIntercellularCommunication, .telomereAttrition],
            evidenceLevel: .humanRCT,
            hrvImpact: 0.7,
            caution: "Schilddrüsenfunktion beachten. Nicht bei Autoimmun."
        ),
        LongevityCompound(
            name: "Rhodiola Rosea",
            category: .adaptogen,
            mechanism: "Anti-Fatigue, AMPK Aktivierung",
            dosage: "200-600mg (3% Rosavine)",
            timing: "Morgens",
            foodSources: [],
            targetedHallmarks: [.mitochondrialDysfunction, .alteredIntercellularCommunication],
            evidenceLevel: .humanRCT,
            hrvImpact: 0.5,
            caution: "Stimulierend - nicht abends."
        )
    ]

    // MARK: - Chronotype Plans

    /// Safe helper to find compounds by name substring
    private static func findCompound(containing name: String) -> LongevityCompound? {
        longevityCompounds.first { $0.name.contains(name) }
    }

    /// Safe helper to get multiple compounds
    private static func findCompounds(_ names: [String]) -> [LongevityCompound] {
        names.compactMap { findCompound(containing: $0) }
    }

    public static func createLionPlan() -> ChronotypeLongevityPlan {
        ChronotypeLongevityPlan(
            chronotype: .lion,
            fastingWindow: "18:00 - 06:00 (12h)",
            eatingWindow: "06:00 - 18:00 (12h)",
            firstMealTime: "06:00-07:00",
            lastMealTime: "17:00-18:00",
            keyFoods: longevityFoods.filter { food in
                food.hrvBenefit >= 0.5
            },
            supplements: findCompounds(["Omega-3", "NMN", "Ashwagandha"]),
            exerciseProtocol: "06:00 Cardio/Yoga, 17:00 Kraft",
            sleepProtocol: "21:00 Schlaf, 05:00-05:30 Aufwachen",
            stressProtocol: "Morgenmeditation 06:00, Nachmittags-NSDR 14:00",
            estimatedLifespanBenefit: "+8-12 Jahre (basierend auf Blue Zone Daten)"
        )
    }

    public static func createBearPlan() -> ChronotypeLongevityPlan {
        ChronotypeLongevityPlan(
            chronotype: .bear,
            fastingWindow: "20:00 - 08:00 (12h)",
            eatingWindow: "08:00 - 20:00 (12h)",
            firstMealTime: "08:00-09:00",
            lastMealTime: "19:00-20:00",
            keyFoods: longevityFoods.filter { food in
                food.hrvBenefit >= 0.45
            },
            supplements: findCompounds(["Omega-3", "CoQ10", "Curcumin"]),
            exerciseProtocol: "07:30 Bewegung, 17:00-19:00 Haupttraining",
            sleepProtocol: "23:00 Schlaf, 07:00 Aufwachen",
            stressProtocol: "Morgenlicht 30min, Abendmeditation 21:00",
            estimatedLifespanBenefit: "+6-10 Jahre (basierend auf Blue Zone Daten)"
        )
    }

    public static func createWolfPlan() -> ChronotypeLongevityPlan {
        ChronotypeLongevityPlan(
            chronotype: .wolf,
            fastingWindow: "22:00 - 10:00 (12h) oder 16:8",
            eatingWindow: "10:00 - 22:00 (12h)",
            firstMealTime: "10:00-11:00",
            lastMealTime: "21:00-22:00",
            keyFoods: longevityFoods.filter { food in
                food.hrvBenefit >= 0.45
            },
            supplements: findCompounds(["Omega-3", "Ashwagandha", "Rhodiola"]),
            exerciseProtocol: "18:00-20:00 Haupttraining",
            sleepProtocol: "00:00-01:00 Schlaf, 07:30-08:00 Aufwachen",
            stressProtocol: "Intensive Morgenlicht-Therapie, späte Meditation 23:00",
            estimatedLifespanBenefit: "+5-8 Jahre (zirkadiane Anpassung kritisch)"
        )
    }

    public static func createDolphinPlan() -> ChronotypeLongevityPlan {
        ChronotypeLongevityPlan(
            chronotype: .dolphin,
            fastingWindow: "21:00 - 09:00 (12h)",
            eatingWindow: "09:00 - 21:00 (12h)",
            firstMealTime: "09:00-10:00",
            lastMealTime: "20:00-21:00",
            keyFoods: longevityFoods.filter { food in
                food.hrvBenefit >= 0.5  // Höhere HRV Anforderung für Dolphins
            },
            supplements: findCompounds(["Omega-3", "Ashwagandha", "Spermidine"]),
            exerciseProtocol: "16:00-18:00 moderates Training, Yoga bevorzugt",
            sleepProtocol: "23:30 Schlaf (strikt), 06:30 Aufwachen, NSDR Naps",
            stressProtocol: "Kohärenz-Atmung 4x/Tag, Abend-Routine kritisch",
            estimatedLifespanBenefit: "+4-7 Jahre (Schlafqualität ist Schlüssel)"
        )
    }

    // MARK: - Singleton

    public static let shared = LongevityNutritionEngine()

    // MARK: - Initialization

    public init() {
        initializeHallmarkScores()
    }

    // MARK: - Public Methods

    /// Wählt Plan basierend auf Chronotyp
    public func selectPlan(for chronotype: Chronotype) {
        switch chronotype {
        case .lion:
            currentPlan = Self.createLionPlan()
        case .bear:
            currentPlan = Self.createBearPlan()
        case .wolf:
            currentPlan = Self.createWolfPlan()
        case .dolphin:
            currentPlan = Self.createDolphinPlan()
        }
    }

    /// Berechnet biologisches Alter basierend auf HRV und Lebensstil
    public func calculateBiologicalAge(
        chronologicalAge: Int,
        avgHRV: Double,           // ms
        avgCoherence: Double,     // 0-1
        exerciseMinutes: Int,     // pro Woche
        sleepHours: Double,       // pro Nacht
        plantBasedPercent: Double // 0-1
    ) -> Double {
        var ageDelta: Double = 0

        // HRV Impact (PMC7527628: +10ms HRV = -20% mortality)
        let expectedHRV = 60.0 - (Double(chronologicalAge) * 0.5)  // Alterserwartung
        let hrvDelta = (avgHRV - expectedHRV) / 10.0
        ageDelta -= hrvDelta * 2  // Jede 10ms über Erwartung = 2 Jahre jünger

        // Coherence Impact
        if avgCoherence > 0.7 {
            ageDelta -= 3  // Hohe Kohärenz = 3 Jahre jünger
        } else if avgCoherence > 0.5 {
            ageDelta -= 1.5
        }

        // Exercise (WHO: 150 min/week)
        if exerciseMinutes >= 300 {
            ageDelta -= 5  // Doppelte Empfehlung
        } else if exerciseMinutes >= 150 {
            ageDelta -= 3
        } else if exerciseMinutes < 75 {
            ageDelta += 3  // Sedentär
        }

        // Sleep (7-9 optimal)
        if sleepHours >= 7 && sleepHours <= 9 {
            ageDelta -= 2
        } else if sleepHours < 6 || sleepHours > 10 {
            ageDelta += 3
        }

        // Plant-based (Blue Zones: 95%)
        if plantBasedPercent >= 0.9 {
            ageDelta -= 4
        } else if plantBasedPercent >= 0.7 {
            ageDelta -= 2
        } else if plantBasedPercent < 0.3 {
            ageDelta += 2
        }

        biologicalAge = Double(chronologicalAge) + ageDelta
        updateLongevityScore()

        return biologicalAge
    }

    /// Berechnet Longevity Score (0-100)
    public func updateLongevityScore() {
        // Basierend auf Hallmark-Scores
        let avgHallmarkScore = hallmarkScores.values.reduce(0, +) / Double(hallmarkScores.count)
        longevityScore = avgHallmarkScore
    }

    /// Aktualisiert Hallmark-Score basierend auf Ernährung
    public func updateHallmarkScore(_ hallmark: HallmarkOfAging, targetingIntake: Double) {
        // 0-1 basierend auf wie viel der empfohlenen Nährstoffe konsumiert werden
        hallmarkScores[hallmark] = min(1.0, targetingIntake)
    }

    // MARK: - Private Methods

    private func initializeHallmarkScores() {
        for hallmark in HallmarkOfAging.allCases {
            hallmarkScores[hallmark] = 0.5  // Baseline
        }
    }
}

// MARK: - Scientific Disclaimer

public struct LongevityDisclaimer {
    public static let full = """
    WISSENSCHAFTLICHER HINWEIS ZUR LANGLEBIGKEIT
    =============================================

    Die in dieser App präsentierten Informationen basieren auf aktueller
    wissenschaftlicher Forschung zur Langlebigkeit, einschließlich:

    - Blue Zones Studien (Buettner et al.)
    - Hallmarks of Aging (López-Otín et al., Cell 2013)
    - HRV-Longevity Korrelationen (PMC7527628, Frontiers 2020)
    - David Sinclair's Forschung (Harvard Medical School)
    - Kalorienrestriktion und Fasten-Studien

    WICHTIGE EINSCHRÄNKUNGEN:

    1. Viele Substanzen sind primär in Tiermodellen oder Zellkulturen erforscht.
    2. Langzeit-Humanstudien fehlen für die meisten Longevity-Supplements.
    3. Individuelle Reaktionen variieren stark (Genetik, Mikrobiom).
    4. Wechselwirkungen mit Medikamenten sind möglich.

    EMPFEHLUNGEN:

    ✓ Fokussieren Sie sich auf bewährte Lifestyle-Faktoren:
      - Pflanzenbetonte Ernährung
      - Regelmäßige Bewegung
      - Ausreichend Schlaf
      - Stressmanagement
      - Soziale Verbindungen

    ✓ Supplements nur nach Rücksprache mit einem Arzt
    ✓ Regelmäßige Gesundheitschecks

    Diese App ist KEIN Ersatz für medizinische Beratung.
    Konsultieren Sie immer einen qualifizierten Arzt.

    Quellen:
    - PMC7527628: HRV and Exceptional Longevity
    - Cell 2013: The Hallmarks of Aging
    - JAMA: Blue Zones Dietary Patterns
    - Nature: NAD+ and Aging
    """
}

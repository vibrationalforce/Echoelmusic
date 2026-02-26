// CircadianRhythmEngine.swift
// Echoelmusic - Holistic Bio-Coherence Platform
//
// Zirkadiane Rhythmus-Engine für optimale Gesundheit & Kohärenz
// Basiert auf Chronobiologie, Lichttherapie und circadianer Wissenschaft
//
// WICHTIGER HINWEIS: Diese App ist KEIN medizinisches Gerät.
// Alle Empfehlungen dienen nur der allgemeinen Wellness und ersetzen
// keine professionelle medizinische Beratung.

import Foundation
import Combine
#if canImport(HealthKit)
import HealthKit
#endif

// MARK: - Circadian Phase (24h Zyklus)

/// Die 8 Hauptphasen des zirkadianen Rhythmus
public enum CircadianPhase: String, CaseIterable, Codable {
    case deepSleep = "deep_sleep"           // 00:00-04:00 - Tiefschlaf, Zellregeneration
    case remSleep = "rem_sleep"             // 04:00-06:00 - REM, Traumphase, Gedächtnis
    case cortisol = "cortisol_awakening"    // 06:00-08:00 - Cortisol-Anstieg, Aufwachen
    case peakAlertness = "peak_alertness"   // 08:00-12:00 - Höchste Wachheit, Fokus
    case postLunch = "post_lunch"           // 12:00-14:00 - Verdauung, leichte Müdigkeit
    case secondWind = "second_wind"         // 14:00-18:00 - Zweiter Energieschub
    case windDown = "wind_down"             // 18:00-21:00 - Abendentspannung
    case melatonin = "melatonin_onset"      // 21:00-00:00 - Melatonin-Ausschüttung

    /// Optimale Aktivitäten für jede Phase
    public var optimalActivities: [String] {
        switch self {
        case .deepSleep:
            return ["Schlafen", "Zellregeneration", "HGH-Ausschüttung", "Immunsystem-Stärkung"]
        case .remSleep:
            return ["Träumen", "Gedächtniskonsolidierung", "Emotionale Verarbeitung"]
        case .cortisol:
            return ["Sanftes Aufwachen", "Morgenlicht", "Leichte Bewegung", "Hydration"]
        case .peakAlertness:
            return ["Komplexe Aufgaben", "Kreative Arbeit", "Wichtige Meetings", "Lernen"]
        case .postLunch:
            return ["Leichte Aktivität", "Spaziergang", "Meditation", "Routineaufgaben"]
        case .secondWind:
            return ["Sport", "Krafttraining", "Cardio", "Teamarbeit", "Brainstorming"]
        case .windDown:
            return ["Abendessen", "Soziale Aktivitäten", "Leichtes Yoga", "Lesen"]
        case .melatonin:
            return ["Blaulichtfilter", "Entspannung", "Meditation", "Schlafvorbereitung"]
        }
    }

    /// Empfohlene Lichtfarbe (zirkadian-optimiert)
    public var recommendedLightColor: (r: Float, g: Float, b: Float) {
        switch self {
        case .deepSleep:
            return (0.0, 0.0, 0.0)           // Dunkelheit
        case .remSleep:
            return (0.0, 0.0, 0.0)           // Dunkelheit
        case .cortisol:
            return (1.0, 0.6, 0.3)           // Warmes Sonnenaufgang-Orange
        case .peakAlertness:
            return (0.0, 0.8, 0.95)          // Energetisches Blau (5000-6500K)
        case .postLunch:
            return (0.0, 0.79, 0.34)         // Beruhigendes Gruen (~530nm)
        case .secondWind:
            return (0.0, 0.75, 0.85)         // Helles Cyan
        case .windDown:
            return (1.0, 0.5, 0.2)           // Warmes Orange (2700K)
        case .melatonin:
            return (0.8, 0.3, 0.1)           // Tiefes Rot/Amber (kein Blau)
        }
    }

    /// Empfohlene Musik-Frequenz (Hz)
    public var recommendedFrequency: Double {
        switch self {
        case .deepSleep:    return 2.0      // Delta (0.5-4 Hz)
        case .remSleep:     return 6.0      // Theta (4-8 Hz)
        case .cortisol:     return 10.0     // Alpha (8-12 Hz)
        case .peakAlertness: return 20.0    // Beta (12-30 Hz)
        case .postLunch:    return 10.0     // Alpha
        case .secondWind:   return 18.0     // Beta
        case .windDown:     return 8.0      // Alpha/Theta
        case .melatonin:    return 4.0      // Theta/Delta
        }
    }

    /// Carrier-Frequenz fuer Multidimensional Brainwave Entrainment (Standard 440Hz)
    /// HINWEIS: Alle Carrier-Frequenzen sind akustisch aequivalent fuer Entrainment.
    /// Es gibt keine wissenschaftliche Evidenz fuer "spezielle" Frequenzen wie 432Hz oder 528Hz.
    public var carrierFrequency: Double {
        switch self {
        case .deepSleep, .remSleep, .melatonin:
            return 440.0    // Standard A4 Stimmung
        case .postLunch, .windDown:
            return 440.0    // Standard A4 Stimmung
        default:
            return 440.0    // Standard A4 Stimmung
        }
    }
}

// MARK: - Chronotype (Schlaftyp)

/// Die 4 Hauptchronotypen nach Dr. Michael Breus
public enum Chronotype: String, CaseIterable, Codable {
    case lion = "lion"          // Früher Vogel (15% der Bevölkerung)
    case bear = "bear"          // Normal (55% der Bevölkerung)
    case wolf = "wolf"          // Nachteule (15% der Bevölkerung)
    case dolphin = "dolphin"    // Leichter Schläfer (10% der Bevölkerung)

    /// Optimale Aufwachzeit
    public var optimalWakeTime: String {
        switch self {
        case .lion:     return "05:30"
        case .bear:     return "07:00"
        case .wolf:     return "07:30"
        case .dolphin:  return "06:30"
        }
    }

    /// Optimale Schlafenszeit
    public var optimalBedTime: String {
        switch self {
        case .lion:     return "21:00"
        case .bear:     return "23:00"
        case .wolf:     return "00:00"
        case .dolphin:  return "23:30"
        }
    }

    /// Peak Produktivitätszeit
    public var peakProductivityWindow: String {
        switch self {
        case .lion:     return "08:00-12:00"
        case .bear:     return "10:00-14:00"
        case .wolf:     return "17:00-21:00"
        case .dolphin:  return "15:00-21:00"
        }
    }

    /// Optimale Trainingszeit
    public var optimalExerciseTime: String {
        switch self {
        case .lion:     return "06:00-07:00 oder 17:00"
        case .bear:     return "07:30-12:00 oder 17:00-19:00"
        case .wolf:     return "18:00-20:00"
        case .dolphin:  return "07:30 oder 16:00-18:00"
        }
    }
}

// MARK: - Lifestyle Tip Category

public enum LifestyleTipCategory: String, CaseIterable, Codable {
    case sleep = "sleep"
    case nutrition = "nutrition"
    case fitness = "fitness"
    case stress = "stress"
    case social = "social"
    case nature = "nature"
    case mindfulness = "mindfulness"
    case lightExposure = "light_exposure"
    case hydration = "hydration"
    case breathing = "breathing"
}

// MARK: - Lifestyle Tip

public struct LifestyleTip: Identifiable, Codable {
    public let id: UUID
    public let category: LifestyleTipCategory
    public let title: String
    public let description: String
    public let circadianPhases: [CircadianPhase]
    public let scientificBasis: String
    public let coherenceImpact: Double  // -1.0 bis +1.0

    public init(
        id: UUID = UUID(),
        category: LifestyleTipCategory,
        title: String,
        description: String,
        circadianPhases: [CircadianPhase],
        scientificBasis: String,
        coherenceImpact: Double
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.description = description
        self.circadianPhases = circadianPhases
        self.scientificBasis = scientificBasis
        self.coherenceImpact = coherenceImpact
    }
}

// MARK: - Fitness Activity

public enum FitnessActivityType: String, CaseIterable, Codable {
    // Cardio
    case walking = "walking"
    case running = "running"
    case cycling = "cycling"
    case swimming = "swimming"
    case hiit = "hiit"
    case dancing = "dancing"

    // Kraft
    case weightTraining = "weight_training"
    case bodyweight = "bodyweight"
    case resistance = "resistance"

    // Flexibilität & Balance
    case yoga = "yoga"
    case pilates = "pilates"
    case stretching = "stretching"
    case taichi = "taichi"
    case qigong = "qigong"

    // Entspannung
    case meditation = "meditation"
    case breathwork = "breathwork"
    case coldExposure = "cold_exposure"
    case sauna = "sauna"

    /// Empfohlene Dauer in Minuten
    public var recommendedDuration: Int {
        switch self {
        case .walking: return 30
        case .running: return 20
        case .cycling: return 45
        case .swimming: return 30
        case .hiit: return 20
        case .dancing: return 30
        case .weightTraining: return 45
        case .bodyweight: return 30
        case .resistance: return 30
        case .yoga: return 45
        case .pilates: return 45
        case .stretching: return 15
        case .taichi: return 30
        case .qigong: return 20
        case .meditation: return 20
        case .breathwork: return 10
        case .coldExposure: return 3
        case .sauna: return 15
        }
    }

    /// Optimale Tageszeit
    public var optimalTimeOfDay: [CircadianPhase] {
        switch self {
        case .walking, .stretching:
            return [.cortisol, .postLunch, .windDown]
        case .running, .cycling, .swimming, .hiit:
            return [.secondWind]  // 14:00-18:00 beste Zeit für Cardio
        case .weightTraining, .bodyweight, .resistance:
            return [.secondWind]  // Muskelkraft peak
        case .yoga, .pilates, .taichi, .qigong:
            return [.cortisol, .windDown]
        case .meditation, .breathwork:
            return CircadianPhase.allCases
        case .coldExposure:
            return [.cortisol]  // Morgens für Dopamin
        case .sauna:
            return [.windDown]  // Abends für Schlafqualität
        case .dancing:
            return [.secondWind, .windDown]
        }
    }

    /// HRV/Kohärenz-Effekt
    public var coherenceEffect: Double {
        switch self {
        case .meditation: return 0.9
        case .breathwork: return 0.85
        case .yoga: return 0.8
        case .taichi, .qigong: return 0.75
        case .walking: return 0.6
        case .swimming: return 0.55
        case .pilates: return 0.5
        case .stretching: return 0.5
        case .cycling: return 0.4
        case .dancing: return 0.4
        case .running: return 0.3
        case .bodyweight: return 0.3
        case .weightTraining: return 0.25
        case .resistance: return 0.25
        case .hiit: return 0.2
        case .coldExposure: return 0.7  // Stark nach Anpassung
        case .sauna: return 0.6
        }
    }
}

// MARK: - Nutrition Plan

public enum MealType: String, CaseIterable, Codable {
    case breakfast = "breakfast"
    case morningSnack = "morning_snack"
    case lunch = "lunch"
    case afternoonSnack = "afternoon_snack"
    case dinner = "dinner"
    case eveningSnack = "evening_snack"

    /// Optimale Uhrzeit
    public var optimalTime: String {
        switch self {
        case .breakfast: return "07:00-08:00"
        case .morningSnack: return "10:00-10:30"
        case .lunch: return "12:00-13:00"
        case .afternoonSnack: return "15:00-15:30"
        case .dinner: return "18:00-19:00"
        case .eveningSnack: return "20:00-20:30"
        }
    }

    /// Empfohlener Makronährstoff-Fokus
    public var macroFocus: String {
        switch self {
        case .breakfast: return "Protein + Fett (Cortisol-Unterstützung)"
        case .morningSnack: return "Protein + Ballaststoffe"
        case .lunch: return "Ausgewogen (40/30/30)"
        case .afternoonSnack: return "Komplexe Kohlenhydrate + Protein"
        case .dinner: return "Protein + Gemüse (leicht verdaulich)"
        case .eveningSnack: return "Casein/Tryptophan (Schlafunterstützung)"
        }
    }
}

public struct NutritionItem: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let category: String  // Protein, Carb, Fat, Vegetable, Fruit
    public let circadianBenefit: String
    public let coherenceImpact: Double
    public let optimalMealTypes: [MealType]

    public init(
        id: UUID = UUID(),
        name: String,
        category: String,
        circadianBenefit: String,
        coherenceImpact: Double,
        optimalMealTypes: [MealType]
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.circadianBenefit = circadianBenefit
        self.coherenceImpact = coherenceImpact
        self.optimalMealTypes = optimalMealTypes
    }
}

// MARK: - Circadian Rhythm Engine

/// Hauptklasse für zirkadiane Rhythmus-Optimierung
@MainActor
public final class CircadianRhythmEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var currentPhase: CircadianPhase = .peakAlertness
    @Published public private(set) var chronotype: Chronotype = .bear
    @Published public private(set) var circadianScore: Double = 0.5  // 0-1
    @Published public private(set) var sleepDebt: Double = 0.0  // Stunden
    @Published public private(set) var lightExposureToday: Double = 0.0  // Lux-Stunden
    @Published public private(set) var currentRecommendations: [LifestyleTip] = []
    @Published public private(set) var todaysFitnessplan: [FitnessActivityType] = []
    @Published public private(set) var todaysNutritionPlan: [MealType: [NutritionItem]] = [:]

    // MARK: - Private Properties

    private var updateTimer: Timer?
    private let calendar = Calendar.current

    // MARK: - Static Data

    public static let lifestyleTips: [LifestyleTip] = [
        // Schlaf
        LifestyleTip(
            category: .sleep,
            title: "Konsistente Schlafenszeit",
            description: "Gehe jeden Tag zur gleichen Zeit ins Bett, auch am Wochenende. Dies stabilisiert deinen zirkadianen Rhythmus.",
            circadianPhases: [.melatonin],
            scientificBasis: "Regelmäßige Schlafzeiten synchronisieren den Suprachiasmatischen Nucleus (SCN)",
            coherenceImpact: 0.8
        ),
        LifestyleTip(
            category: .sleep,
            title: "Schlafzimmer 18°C",
            description: "Halte dein Schlafzimmer kühl (16-19°C). Die Körpertemperatur muss für tiefen Schlaf sinken.",
            circadianPhases: [.melatonin, .deepSleep],
            scientificBasis: "Thermoregulation ist eng mit dem Schlaf-Wach-Zyklus verbunden",
            coherenceImpact: 0.6
        ),

        // Lichtexposition
        LifestyleTip(
            category: .lightExposure,
            title: "Morgenlicht 10.000 Lux",
            description: "Setze dich innerhalb von 30 Minuten nach dem Aufwachen für 10-30 Minuten natürlichem Licht aus.",
            circadianPhases: [.cortisol],
            scientificBasis: "Morgenlicht unterdrückt Melatonin und triggert Cortisol-Awakening-Response",
            coherenceImpact: 0.9
        ),
        LifestyleTip(
            category: .lightExposure,
            title: "Blaulichtfilter ab 20:00",
            description: "Aktiviere Blaulichtfilter auf allen Bildschirmen 2-3 Stunden vor dem Schlafengehen.",
            circadianPhases: [.windDown, .melatonin],
            scientificBasis: "Blaues Licht (460-480nm) unterdrückt Melatoninproduktion um bis zu 50%",
            coherenceImpact: 0.7
        ),
        LifestyleTip(
            category: .lightExposure,
            title: "Grünes Licht Entspannung",
            description: "Grünes Licht (520-560nm) wird subjektiv als beruhigend empfunden. Kulturelle Tradition, keine medizinischen Belege.",
            circadianPhases: [.postLunch, .windDown],
            scientificBasis: "HINWEIS: 528Hz/nm 'DNA-Reparatur' ist NICHT wissenschaftlich belegt. Subjektive Entspannung möglich.",
            coherenceImpact: 0.4  // Reduziert - keine wissenschaftliche Basis
        ),

        // Ernährung
        LifestyleTip(
            category: .nutrition,
            title: "Proteinreiches Frühstück",
            description: "Starte mit 30g Protein innerhalb der ersten Stunde. Dies stabilisiert Blutzucker und Cortisol.",
            circadianPhases: [.cortisol],
            scientificBasis: "Protein zum Frühstück erhöht Dopamin-Vorläufer (Tyrosin) für den Tag",
            coherenceImpact: 0.6
        ),
        LifestyleTip(
            category: .nutrition,
            title: "Keine Kohlenhydrate morgens",
            description: "Vermeide einfache Kohlenhydrate am Morgen - sie führen zu Blutzuckerspitzen und Energieeinbrüchen.",
            circadianPhases: [.cortisol, .peakAlertness],
            scientificBasis: "Insulinsensitivität ist morgens höher - komplexe Kohlenhydrate besser mittags",
            coherenceImpact: 0.5
        ),
        LifestyleTip(
            category: .nutrition,
            title: "Letzte Mahlzeit 3h vor Schlaf",
            description: "Iss deine letzte Mahlzeit mindestens 3 Stunden vor dem Schlafengehen.",
            circadianPhases: [.windDown],
            scientificBasis: "Spätes Essen verzögert den zirkadianen Rhythmus und reduziert Schlafqualität",
            coherenceImpact: 0.7
        ),

        // Fitness
        LifestyleTip(
            category: .fitness,
            title: "Krafttraining 14-18 Uhr",
            description: "Trainiere Kraft am Nachmittag - Körpertemperatur und Muskelkraft sind hier maximal.",
            circadianPhases: [.secondWind],
            scientificBasis: "Testosteron:Cortisol Verhältnis ist nachmittags optimal für Hypertrophie",
            coherenceImpact: 0.5
        ),
        LifestyleTip(
            category: .fitness,
            title: "Morgen-Stretching",
            description: "10 Minuten sanftes Stretching nach dem Aufwachen aktiviert das parasympathische System.",
            circadianPhases: [.cortisol],
            scientificBasis: "Sanfte Bewegung nach dem Aufwachen erhöht HRV und reduziert Stress",
            coherenceImpact: 0.7
        ),

        // Stress
        LifestyleTip(
            category: .stress,
            title: "Physiologisches Seufzen",
            description: "2x Einatmen durch Nase, langes Ausatmen durch Mund - aktiviert sofort den Parasympathikus.",
            circadianPhases: CircadianPhase.allCases,
            scientificBasis: "Physiologisches Seufzen ist der schnellste Weg zur Stressreduktion (Stanford/Huberman)",
            coherenceImpact: 0.9
        ),
        LifestyleTip(
            category: .stress,
            title: "NSDR Protokoll",
            description: "Non-Sleep Deep Rest (Yoga Nidra) für 10-30 Minuten ersetzt 2-3 Stunden Schlaf.",
            circadianPhases: [.postLunch],
            scientificBasis: "NSDR erhöht Dopamin um 65% und beschleunigt Lernen",
            coherenceImpact: 0.85
        ),

        // Hydration
        LifestyleTip(
            category: .hydration,
            title: "500ml Wasser nach dem Aufwachen",
            description: "Trinke 500ml Wasser mit einer Prise Salz innerhalb der ersten 30 Minuten.",
            circadianPhases: [.cortisol],
            scientificBasis: "Nach 8h Schlaf bist du dehydriert - Wasser aktiviert den Stoffwechsel",
            coherenceImpact: 0.6
        ),

        // Natur
        LifestyleTip(
            category: .nature,
            title: "Earthing/Grounding",
            description: "10-20 Minuten barfuß auf Gras oder Erde stehen - reduziert Entzündungen und verbessert Schlaf.",
            circadianPhases: [.cortisol, .windDown],
            scientificBasis: "Erdung normalisiert das elektrische Potential des Körpers",
            coherenceImpact: 0.7
        ),

        // Breathing
        LifestyleTip(
            category: .breathing,
            title: "Box Breathing",
            description: "4 Sekunden ein - 4 halten - 4 aus - 4 halten. Balanciert das autonome Nervensystem.",
            circadianPhases: CircadianPhase.allCases,
            scientificBasis: "Navy SEALs verwenden Box Breathing für Stressresistenz",
            coherenceImpact: 0.8
        ),
        LifestyleTip(
            category: .breathing,
            title: "Kohärenz-Atmung 6/Min",
            description: "5 Sekunden ein, 5 Sekunden aus (6 Atemzüge/Minute) maximiert HRV-Kohärenz.",
            circadianPhases: CircadianPhase.allCases,
            scientificBasis: "6 Atemzüge/Minute synchronisiert mit der Baroreflex-Frequenz (~0.1Hz)",
            coherenceImpact: 0.95
        )
    ]

    public static let coherenceNutrition: [NutritionItem] = [
        // Omega-3 für HRV
        NutritionItem(
            name: "Wildlachs",
            category: "Protein/Omega-3",
            circadianBenefit: "EPA/DHA verbessern HRV und Gehirnfunktion",
            coherenceImpact: 0.8,
            optimalMealTypes: [.lunch, .dinner]
        ),
        NutritionItem(
            name: "Walnüsse",
            category: "Fett/Omega-3",
            circadianBenefit: "ALA und Melatonin-Vorläufer für besseren Schlaf",
            coherenceImpact: 0.6,
            optimalMealTypes: [.afternoonSnack, .eveningSnack]
        ),

        // Tryptophan für Melatonin
        NutritionItem(
            name: "Truthahn",
            category: "Protein",
            circadianBenefit: "Reich an Tryptophan - Melatonin-Vorläufer",
            coherenceImpact: 0.5,
            optimalMealTypes: [.dinner]
        ),
        NutritionItem(
            name: "Sauerkirschsaft",
            category: "Getränk",
            circadianBenefit: "Natürliche Melatoninquelle - verbessert Schlaf um 84 Minuten",
            coherenceImpact: 0.7,
            optimalMealTypes: [.eveningSnack]
        ),

        // Magnesium für Entspannung
        NutritionItem(
            name: "Dunkle Schokolade 85%",
            category: "Magnesium",
            circadianBenefit: "Magnesium aktiviert Parasympathikus, Theobromin für sanfte Energie",
            coherenceImpact: 0.5,
            optimalMealTypes: [.afternoonSnack]
        ),
        NutritionItem(
            name: "Kürbiskerne",
            category: "Magnesium/Zink",
            circadianBenefit: "Magnesium + Zink für HRV und Testosteron",
            coherenceImpact: 0.6,
            optimalMealTypes: [.morningSnack, .afternoonSnack]
        ),

        // Adaptogene
        NutritionItem(
            name: "Ashwagandha",
            category: "Adaptogen",
            circadianBenefit: "Senkt Cortisol um 30%, verbessert Schlaf und HRV",
            coherenceImpact: 0.75,
            optimalMealTypes: [.eveningSnack]
        ),
        NutritionItem(
            name: "Reishi Pilz",
            category: "Adaptogen",
            circadianBenefit: "GABA-agonistisch, fördert tiefen Schlaf",
            coherenceImpact: 0.65,
            optimalMealTypes: [.eveningSnack]
        ),

        // Morgen-Energie
        NutritionItem(
            name: "Eier (mit Eigelb)",
            category: "Protein/Cholin",
            circadianBenefit: "Cholin für Acetylcholin - Fokus und Gedächtnis",
            coherenceImpact: 0.5,
            optimalMealTypes: [.breakfast]
        ),
        NutritionItem(
            name: "Avocado",
            category: "Fett",
            circadianBenefit: "Gesunde Fette stabilisieren Energie ohne Insulinspitzen",
            coherenceImpact: 0.5,
            optimalMealTypes: [.breakfast, .lunch]
        ),

        // Polyphenole
        NutritionItem(
            name: "Blaubeeren",
            category: "Frucht/Antioxidans",
            circadianBenefit: "Anthocyane verbessern kognitive Funktion",
            coherenceImpact: 0.55,
            optimalMealTypes: [.breakfast, .morningSnack]
        ),
        NutritionItem(
            name: "Grüner Tee",
            category: "Getränk",
            circadianBenefit: "L-Theanin + Koffein = Alpha-Wellen + Fokus",
            coherenceImpact: 0.6,
            optimalMealTypes: [.breakfast, .morningSnack]
        ),

        // Fermentiertes
        NutritionItem(
            name: "Kefir",
            category: "Fermentiert",
            circadianBenefit: "Probiotika beeinflussen Vagusnerv und HRV positiv",
            coherenceImpact: 0.6,
            optimalMealTypes: [.breakfast, .afternoonSnack]
        ),
        NutritionItem(
            name: "Sauerkraut",
            category: "Fermentiert",
            circadianBenefit: "Darm-Hirn-Achse: Gute Bakterien = bessere Stimmung",
            coherenceImpact: 0.55,
            optimalMealTypes: [.lunch, .dinner]
        )
    ]

    // MARK: - Singleton

    public static let shared = CircadianRhythmEngine()

    // MARK: - Initialization

    public init() {
        updateCurrentPhase()
        generateDailyPlan()
        startContinuousUpdates()
    }

    deinit {
        updateTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Aktualisiert die aktuelle zirkadiane Phase basierend auf Uhrzeit
    public func updateCurrentPhase() {
        let hour = calendar.component(.hour, from: Date())

        switch hour {
        case 0..<4:
            currentPhase = .deepSleep
        case 4..<6:
            currentPhase = .remSleep
        case 6..<8:
            currentPhase = .cortisol
        case 8..<12:
            currentPhase = .peakAlertness
        case 12..<14:
            currentPhase = .postLunch
        case 14..<18:
            currentPhase = .secondWind
        case 18..<21:
            currentPhase = .windDown
        default:
            currentPhase = .melatonin
        }

        updateRecommendations()
    }

    /// Bestimmt den Chronotyp basierend auf Schlafpräferenzen
    public func determineChronotype(
        preferredWakeTime: Date,
        preferredBedTime: Date,
        morningProductivity: Double,  // 0-1
        eveningEnergy: Double         // 0-1
    ) {
        let wakeHour = calendar.component(.hour, from: preferredWakeTime)
        let bedHour = calendar.component(.hour, from: preferredBedTime)

        if wakeHour <= 6 && bedHour <= 22 && morningProductivity > 0.7 {
            chronotype = .lion
        } else if wakeHour >= 8 && bedHour >= 24 && eveningEnergy > 0.7 {
            chronotype = .wolf
        } else if morningProductivity < 0.4 && eveningEnergy < 0.4 {
            chronotype = .dolphin
        } else {
            chronotype = .bear
        }
    }

    /// Generiert täglichen Fitness- und Ernährungsplan
    public func generateDailyPlan() {
        // Fitness basierend auf Chronotyp und Phase
        var fitness: [FitnessActivityType] = []

        // Morgenroutine
        fitness.append(.stretching)
        fitness.append(.breathwork)

        // Haupttraining basierend auf Chronotyp
        switch chronotype {
        case .lion:
            fitness.append(.running)
            fitness.append(.yoga)
        case .bear:
            fitness.append(.weightTraining)
            fitness.append(.walking)
        case .wolf:
            fitness.append(.hiit)
            fitness.append(.dancing)
        case .dolphin:
            fitness.append(.swimming)
            fitness.append(.pilates)
        }

        // Abendentspannung
        fitness.append(.meditation)

        todaysFitnessplan = fitness

        // Ernährungsplan
        var nutrition: [MealType: [NutritionItem]] = [:]

        for mealType in MealType.allCases {
            let items = Self.coherenceNutrition.filter { item in
                item.optimalMealTypes.contains(mealType)
            }
            nutrition[mealType] = Array(items.prefix(3))
        }

        todaysNutritionPlan = nutrition
    }

    /// Berechnet Circadian Score basierend auf Aktivitäten
    public func updateCircadianScore(
        sleepQuality: Double,
        lightExposure: Double,
        mealTiming: Double,
        exerciseTiming: Double,
        screenTimeEvening: Double
    ) {
        // Gewichtete Berechnung
        circadianScore = (
            sleepQuality * 0.3 +
            lightExposure * 0.25 +
            mealTiming * 0.2 +
            exerciseTiming * 0.15 +
            (1.0 - screenTimeEvening) * 0.1
        )
    }

    /// Gibt optimale Lichteinstellungen für aktuelle Phase zurück
    public func getCurrentLightSettings() -> (color: (r: Float, g: Float, b: Float), intensity: Float) {
        let color = currentPhase.recommendedLightColor

        let intensity: Float
        switch currentPhase {
        case .deepSleep, .remSleep:
            intensity = 0.0
        case .cortisol:
            intensity = 0.5
        case .peakAlertness:
            intensity = 1.0
        case .postLunch:
            intensity = 0.7
        case .secondWind:
            intensity = 0.9
        case .windDown:
            intensity = 0.4
        case .melatonin:
            intensity = 0.2
        }

        return (color, intensity)
    }

    /// Gibt optimale Audio-Frequenz für aktuelle Phase zurück
    public func getCurrentAudioSettings() -> (entrainmentHz: Double, carrierHz: Double) {
        return (currentPhase.recommendedFrequency, currentPhase.carrierFrequency)
    }

    // MARK: - Private Methods

    private func startContinuousUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCurrentPhase()
            }
        }
    }

    private func updateRecommendations() {
        currentRecommendations = Self.lifestyleTips.filter { tip in
            tip.circadianPhases.contains(currentPhase)
        }.sorted { $0.coherenceImpact > $1.coherenceImpact }
    }
}

// MARK: - Health Disclaimer

/// WICHTIGER HINWEIS zur Gesundheit
public struct CircadianHealthDisclaimer {

    public static let fullDisclaimer = """
    WICHTIGER MEDIZINISCHER HINWEIS
    ================================

    Echoelmusic ist KEIN medizinisches Gerät und ersetzt keine professionelle
    medizinische Beratung, Diagnose oder Behandlung.

    Die in dieser App enthaltenen Informationen zu zirkadianen Rhythmen,
    Schlaf, Ernährung und Fitness dienen ausschließlich zu Informations-
    und allgemeinen Wellness-Zwecken.

    BEVOR Sie Änderungen an Ihrer Ernährung, Ihrem Schlafrhythmus oder
    Ihrem Trainingsprogramm vornehmen, konsultieren Sie bitte einen
    qualifizierten Arzt oder Gesundheitsdienstleister.

    Die biometrischen Daten (HRV, Herzfrequenz, Kohärenz) sind Schätzungen
    und können von medizinisch genauen Messungen abweichen.

    Bei gesundheitlichen Bedenken oder Symptomen wenden Sie sich bitte
    sofort an einen Arzt.

    © 2026 Echoelmusic - Nur für Wellness und kreative Zwecke
    """

    public static let shortDisclaimer = """
    Keine medizinische Beratung. Konsultieren Sie einen Arzt vor
    Änderungen an Ernährung, Schlaf oder Training.
    """
}

// LifestyleCoachEngine.swift
// Echoelmusic - Holistic Bio-Coherence Platform
//
// Lifestyle Coach für ganzheitliche Gesundheitsoptimierung
// Fitness, Ernährung, Schlaf, Stress-Management
//
// WICHTIG: Keine medizinische Beratung - nur allgemeine Wellness

import Foundation

// MARK: - Fitness Plan

/// Wöchentlicher Trainingsplan basierend auf Kohärenz-Optimierung
public struct FitnessWeekPlan: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let description: String
    public let level: FitnessLevel
    public let coherenceFocus: Double  // 0-1 wie stark Kohärenz-optimiert
    public let weeklySchedule: [DayOfWeek: DailyFitnessPlan]

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        level: FitnessLevel,
        coherenceFocus: Double,
        weeklySchedule: [DayOfWeek: DailyFitnessPlan]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.level = level
        self.coherenceFocus = coherenceFocus
        self.weeklySchedule = weeklySchedule
    }
}

public enum FitnessLevel: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case athlete = "athlete"

    public var weeklyTrainingDays: Int {
        switch self {
        case .beginner: return 3
        case .intermediate: return 4
        case .advanced: return 5
        case .athlete: return 6
        }
    }
}

public enum DayOfWeek: String, CaseIterable, Codable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
}

public struct DailyFitnessPlan: Codable {
    public let isRestDay: Bool
    public let morning: [FitnessBlock]
    public let afternoon: [FitnessBlock]
    public let evening: [FitnessBlock]

    public init(isRestDay: Bool = false, morning: [FitnessBlock] = [], afternoon: [FitnessBlock] = [], evening: [FitnessBlock] = []) {
        self.isRestDay = isRestDay
        self.morning = morning
        self.afternoon = afternoon
        self.evening = evening
    }
}

public struct FitnessBlock: Codable, Identifiable {
    public let id: UUID
    public let activity: FitnessActivityType
    public let duration: Int  // Minuten
    public let intensity: Double  // 0-1
    public let hrvImpact: Double  // Erwartete HRV-Änderung
    public let notes: String

    public init(
        id: UUID = UUID(),
        activity: FitnessActivityType,
        duration: Int,
        intensity: Double,
        hrvImpact: Double,
        notes: String
    ) {
        self.id = id
        self.activity = activity
        self.duration = duration
        self.intensity = intensity
        self.hrvImpact = hrvImpact
        self.notes = notes
    }
}

// MARK: - Nutrition Plan

/// Täglicher Ernährungsplan
public struct DailyNutritionPlan: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let targetCalories: Int
    public let targetProtein: Int   // Gramm
    public let targetCarbs: Int     // Gramm
    public let targetFat: Int       // Gramm
    public let targetFiber: Int     // Gramm
    public let targetWater: Double  // Liter
    public let meals: [MealPlan]
    public let supplements: [Supplement]

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        targetCalories: Int,
        targetProtein: Int,
        targetCarbs: Int,
        targetFat: Int,
        targetFiber: Int,
        targetWater: Double,
        meals: [MealPlan],
        supplements: [Supplement]
    ) {
        self.id = id
        self.date = date
        self.targetCalories = targetCalories
        self.targetProtein = targetProtein
        self.targetCarbs = targetCarbs
        self.targetFat = targetFat
        self.targetFiber = targetFiber
        self.targetWater = targetWater
        self.meals = meals
        self.supplements = supplements
    }
}

public struct MealPlan: Codable, Identifiable {
    public let id: UUID
    public let mealType: MealType
    public let time: String
    public let foods: [FoodItem]
    public let circadianOptimal: Bool
    public let coherenceBenefit: String

    public init(
        id: UUID = UUID(),
        mealType: MealType,
        time: String,
        foods: [FoodItem],
        circadianOptimal: Bool,
        coherenceBenefit: String
    ) {
        self.id = id
        self.mealType = mealType
        self.time = time
        self.foods = foods
        self.circadianOptimal = circadianOptimal
        self.coherenceBenefit = coherenceBenefit
    }
}

public struct FoodItem: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let portion: String
    public let calories: Int
    public let protein: Double
    public let carbs: Double
    public let fat: Double
    public let fiber: Double
    public let coherenceNutrients: [String]  // z.B. ["Omega-3", "Magnesium", "Tryptophan"]

    public init(
        id: UUID = UUID(),
        name: String,
        portion: String,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double,
        coherenceNutrients: [String]
    ) {
        self.id = id
        self.name = name
        self.portion = portion
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.coherenceNutrients = coherenceNutrients
    }
}

public struct Supplement: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let dosage: String
    public let timing: String
    public let hrvBenefit: String
    public let scientificEvidence: String

    public init(
        id: UUID = UUID(),
        name: String,
        dosage: String,
        timing: String,
        hrvBenefit: String,
        scientificEvidence: String
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.timing = timing
        self.hrvBenefit = hrvBenefit
        self.scientificEvidence = scientificEvidence
    }
}

// MARK: - Lifestyle Coach Engine

@MainActor
public final class LifestyleCoachEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var currentFitnessPlan: FitnessWeekPlan?
    @Published public private(set) var currentNutritionPlan: DailyNutritionPlan?
    @Published public private(set) var dailyProgress: DailyProgress = DailyProgress()
    @Published public private(set) var weeklyStats: WeeklyStats = WeeklyStats()
    @Published public private(set) var personalGoals: [WellnessGoal] = []

    // MARK: - User Profile

    public struct UserProfile: Codable {
        public var age: Int
        public var weight: Double  // kg
        public var height: Double  // cm
        public var biologicalSex: BiologicalSex
        public var activityLevel: ActivityLevel
        public var fitnessGoal: FitnessGoal
        public var dietaryRestrictions: [DietaryRestriction]
        public var chronotype: Chronotype

        public init(
            age: Int = 30,
            weight: Double = 70,
            height: Double = 175,
            biologicalSex: BiologicalSex = .notSpecified,
            activityLevel: ActivityLevel = .moderate,
            fitnessGoal: FitnessGoal = .generalHealth,
            dietaryRestrictions: [DietaryRestriction] = [],
            chronotype: Chronotype = .bear
        ) {
            self.age = age
            self.weight = weight
            self.height = height
            self.biologicalSex = biologicalSex
            self.activityLevel = activityLevel
            self.fitnessGoal = fitnessGoal
            self.dietaryRestrictions = dietaryRestrictions
            self.chronotype = chronotype
        }
    }

    public enum BiologicalSex: String, Codable, CaseIterable {
        case male, female, notSpecified
    }

    public enum ActivityLevel: String, Codable, CaseIterable {
        case sedentary = "sedentary"           // Wenig Bewegung
        case lightlyActive = "lightly_active"  // 1-3 Tage/Woche
        case moderate = "moderate"              // 3-5 Tage/Woche
        case veryActive = "very_active"        // 6-7 Tage/Woche
        case athlete = "athlete"               // 2x täglich

        public var tdeeMultiplier: Double {
            switch self {
            case .sedentary: return 1.2
            case .lightlyActive: return 1.375
            case .moderate: return 1.55
            case .veryActive: return 1.725
            case .athlete: return 1.9
            }
        }
    }

    public enum FitnessGoal: String, Codable, CaseIterable {
        case weightLoss = "weight_loss"
        case muscleGain = "muscle_gain"
        case maintenance = "maintenance"
        case generalHealth = "general_health"
        case endurance = "endurance"
        case flexibility = "flexibility"
        case stressReduction = "stress_reduction"
        case hrvOptimization = "hrv_optimization"
    }

    public enum DietaryRestriction: String, Codable, CaseIterable {
        case vegetarian, vegan, pescatarian
        case glutenFree, dairyFree, nutFree
        case lowCarb, keto, paleo
        case halal, kosher
        case lowFODMAP
    }

    // MARK: - Progress Tracking

    public struct DailyProgress: Codable {
        public var date: Date = Date()
        public var waterIntake: Double = 0  // Liter
        public var caloriesConsumed: Int = 0
        public var proteinConsumed: Double = 0
        public var exerciseMinutes: Int = 0
        public var meditationMinutes: Int = 0
        public var sleepHours: Double = 0
        public var avgHRV: Double = 0
        public var avgCoherence: Double = 0
        public var stepsCount: Int = 0
        public var sunlightMinutes: Int = 0
    }

    public struct WeeklyStats: Codable {
        public var avgHRV: Double = 0
        public var avgCoherence: Double = 0
        public var totalExerciseMinutes: Int = 0
        public var avgSleepHours: Double = 0
        public var avgCalories: Int = 0
        public var weightChange: Double = 0  // kg
        public var coherenceTrend: Double = 0  // -1 bis +1
    }

    public struct WellnessGoal: Codable, Identifiable {
        public let id: UUID
        public var title: String
        public var category: WellnessCategory
        public var targetValue: Double
        public var currentValue: Double
        public var unit: String
        public var deadline: Date?
        public var isCompleted: Bool

        public init(
            id: UUID = UUID(),
            title: String,
            category: WellnessCategory,
            targetValue: Double,
            currentValue: Double = 0,
            unit: String,
            deadline: Date? = nil,
            isCompleted: Bool = false
        ) {
            self.id = id
            self.title = title
            self.category = category
            self.targetValue = targetValue
            self.currentValue = currentValue
            self.unit = unit
            self.deadline = deadline
            self.isCompleted = isCompleted
        }
    }

    public enum WellnessCategory: String, Codable, CaseIterable {
        case hrv = "hrv"
        case coherence = "coherence"
        case sleep = "sleep"
        case fitness = "fitness"
        case nutrition = "nutrition"
        case hydration = "hydration"
        case mindfulness = "mindfulness"
        case weight = "weight"
    }

    // MARK: - Properties

    @Published public var userProfile: UserProfile = UserProfile()

    // MARK: - Singleton

    public static let shared = LifestyleCoachEngine()

    // MARK: - Initialization

    public init() {
        generateDefaultPlans()
    }

    // MARK: - Public Methods

    /// Berechnet täglichen Kalorienbedarf (TDEE)
    public func calculateTDEE() -> Int {
        let bmr: Double

        // Mifflin-St Jeor Formel
        switch userProfile.biologicalSex {
        case .male:
            bmr = (10 * userProfile.weight) + (6.25 * userProfile.height) - (5 * Double(userProfile.age)) + 5
        case .female:
            bmr = (10 * userProfile.weight) + (6.25 * userProfile.height) - (5 * Double(userProfile.age)) - 161
        case .notSpecified:
            bmr = (10 * userProfile.weight) + (6.25 * userProfile.height) - (5 * Double(userProfile.age)) - 78
        }

        return Int(bmr * userProfile.activityLevel.tdeeMultiplier)
    }

    /// Berechnet optimale Makronährstoffe
    public func calculateMacros() -> (protein: Int, carbs: Int, fat: Int) {
        let tdee = calculateTDEE()
        let adjustedCalories: Int

        switch userProfile.fitnessGoal {
        case .weightLoss:
            adjustedCalories = Int(Double(tdee) * 0.8)  // 20% Defizit
        case .muscleGain:
            adjustedCalories = Int(Double(tdee) * 1.1)  // 10% Überschuss
        default:
            adjustedCalories = tdee
        }

        let protein: Int
        let carbs: Int
        let fat: Int

        switch userProfile.fitnessGoal {
        case .muscleGain:
            // Hoher Protein für Muskelaufbau
            protein = Int(userProfile.weight * 2.2)  // 2.2g/kg
            fat = Int(Double(adjustedCalories) * 0.25 / 9)
            carbs = (adjustedCalories - (protein * 4) - (fat * 9)) / 4
        case .weightLoss:
            // Moderat Protein, weniger Carbs
            protein = Int(userProfile.weight * 2.0)
            fat = Int(Double(adjustedCalories) * 0.35 / 9)
            carbs = (adjustedCalories - (protein * 4) - (fat * 9)) / 4
        case .hrvOptimization:
            // Omega-3 reich, moderate Carbs
            protein = Int(userProfile.weight * 1.6)
            fat = Int(Double(adjustedCalories) * 0.35 / 9)  // Mehr Fett für Omega-3
            carbs = (adjustedCalories - (protein * 4) - (fat * 9)) / 4
        default:
            // Ausgewogen
            protein = Int(userProfile.weight * 1.8)
            fat = Int(Double(adjustedCalories) * 0.3 / 9)
            carbs = (adjustedCalories - (protein * 4) - (fat * 9)) / 4
        }

        return (protein, max(carbs, 50), fat)
    }

    /// Generiert personalisierten Fitnessplan
    public func generateFitnessPlan() -> FitnessWeekPlan {
        let fitnessLevel: FitnessLevel
        switch userProfile.activityLevel {
        case .sedentary, .lightlyActive:
            fitnessLevel = .beginner
        case .moderate:
            fitnessLevel = .intermediate
        case .veryActive:
            fitnessLevel = .advanced
        case .athlete:
            fitnessLevel = .athlete
        }

        var schedule: [DayOfWeek: DailyFitnessPlan] = [:]

        let coherenceMorning = FitnessBlock(
            activity: .breathwork,
            duration: 10,
            intensity: 0.3,
            hrvImpact: 0.15,
            notes: "Kohärenz-Atmung (6/min) direkt nach dem Aufwachen"
        )

        let eveningMeditation = FitnessBlock(
            activity: .meditation,
            duration: 15,
            intensity: 0.2,
            hrvImpact: 0.2,
            notes: "Geführte Meditation vor dem Schlafengehen"
        )

        for day in DayOfWeek.allCases {
            let isRestDay = (day == .sunday) ||
                (fitnessLevel == .beginner && (day == .wednesday || day == .saturday))

            if isRestDay {
                schedule[day] = DailyFitnessPlan(
                    isRestDay: true,
                    morning: [coherenceMorning],
                    afternoon: [
                        FitnessBlock(activity: .walking, duration: 30, intensity: 0.3, hrvImpact: 0.1, notes: "Erholungsspaziergang in der Natur")
                    ],
                    evening: [eveningMeditation]
                )
            } else {
                var afternoonWorkout: [FitnessBlock] = []

                switch userProfile.fitnessGoal {
                case .muscleGain:
                    afternoonWorkout = [
                        FitnessBlock(activity: .weightTraining, duration: 45, intensity: 0.8, hrvImpact: -0.1, notes: "Progressive Overload Training"),
                        FitnessBlock(activity: .stretching, duration: 10, intensity: 0.3, hrvImpact: 0.1, notes: "Post-Workout Dehnung")
                    ]
                case .weightLoss:
                    afternoonWorkout = [
                        FitnessBlock(activity: .hiit, duration: 25, intensity: 0.85, hrvImpact: -0.15, notes: "HIIT für maximale Fettverbrennung"),
                        FitnessBlock(activity: .walking, duration: 20, intensity: 0.4, hrvImpact: 0.05, notes: "LISS Cool-Down")
                    ]
                case .hrvOptimization, .stressReduction:
                    afternoonWorkout = [
                        FitnessBlock(activity: .yoga, duration: 45, intensity: 0.5, hrvImpact: 0.2, notes: "Vinyasa Flow für HRV"),
                        FitnessBlock(activity: .breathwork, duration: 10, intensity: 0.3, hrvImpact: 0.15, notes: "4-7-8 Atmung")
                    ]
                case .endurance:
                    afternoonWorkout = [
                        FitnessBlock(activity: .running, duration: 40, intensity: 0.7, hrvImpact: -0.05, notes: "Zone 2 Ausdauer"),
                        FitnessBlock(activity: .stretching, duration: 10, intensity: 0.3, hrvImpact: 0.05, notes: "Runner's Stretch")
                    ]
                case .flexibility:
                    afternoonWorkout = [
                        FitnessBlock(activity: .pilates, duration: 45, intensity: 0.5, hrvImpact: 0.1, notes: "Core & Flexibility"),
                        FitnessBlock(activity: .stretching, duration: 15, intensity: 0.3, hrvImpact: 0.1, notes: "Deep Stretch")
                    ]
                default:
                    afternoonWorkout = [
                        FitnessBlock(activity: .bodyweight, duration: 30, intensity: 0.6, hrvImpact: 0.0, notes: "Functional Training"),
                        FitnessBlock(activity: .walking, duration: 20, intensity: 0.4, hrvImpact: 0.05, notes: "Aktive Erholung")
                    ]
                }

                schedule[day] = DailyFitnessPlan(
                    isRestDay: false,
                    morning: [
                        coherenceMorning,
                        FitnessBlock(activity: .stretching, duration: 10, intensity: 0.3, hrvImpact: 0.1, notes: "Morgen-Mobilität")
                    ],
                    afternoon: afternoonWorkout,
                    evening: [eveningMeditation]
                )
            }
        }

        let plan = FitnessWeekPlan(
            name: "\(userProfile.fitnessGoal.rawValue.capitalized) Plan",
            description: "Personalisierter Plan für \(userProfile.fitnessGoal.rawValue)",
            level: fitnessLevel,
            coherenceFocus: userProfile.fitnessGoal == .hrvOptimization ? 0.9 : 0.5,
            weeklySchedule: schedule
        )

        currentFitnessPlan = plan
        return plan
    }

    /// Generiert personalisierten Ernährungsplan
    public func generateNutritionPlan() -> DailyNutritionPlan {
        let tdee = calculateTDEE()
        let (protein, carbs, fat) = calculateMacros()

        // HRV-optimierende Supplements
        let supplements = [
            Supplement(
                name: "Omega-3 Fischöl",
                dosage: "2-3g EPA+DHA",
                timing: "Mit Mahlzeiten",
                hrvBenefit: "Verbessert HRV um 10-15%",
                scientificEvidence: "Meta-Analyse: Signifikante HRV-Verbesserung"
            ),
            Supplement(
                name: "Magnesium Glycinat",
                dosage: "300-400mg",
                timing: "Abends vor dem Schlaf",
                hrvBenefit: "Parasympathikus-Aktivierung, besserer Schlaf",
                scientificEvidence: "Studien zeigen 15% bessere Schlafqualität"
            ),
            Supplement(
                name: "Vitamin D3 + K2",
                dosage: "4000 IU D3 + 100mcg K2",
                timing: "Morgens mit Fett",
                hrvBenefit: "Zirkadiane Rhythmus-Unterstützung",
                scientificEvidence: "Vitamin D-Mangel korreliert mit niedriger HRV"
            ),
            Supplement(
                name: "Ashwagandha KSM-66",
                dosage: "600mg",
                timing: "Abends",
                hrvBenefit: "Cortisol -30%, HRV-Verbesserung",
                scientificEvidence: "RCT: Signifikante Stressreduktion"
            )
        ]

        // Mahlzeiten basierend auf Chronotyp und Zielen
        var meals: [MealPlan] = []

        // Frühstück - Proteinreich
        let breakfastFoods: [FoodItem]
        if userProfile.dietaryRestrictions.contains(.vegan) {
            breakfastFoods = [
                FoodItem(name: "Tofu Scramble", portion: "200g", calories: 220, protein: 20, carbs: 5, fat: 14, fiber: 2, coherenceNutrients: ["Protein", "Eisen"]),
                FoodItem(name: "Avocado", portion: "1/2", calories: 160, protein: 2, carbs: 9, fat: 15, fiber: 7, coherenceNutrients: ["Omega-3", "Kalium"]),
                FoodItem(name: "Vollkornbrot", portion: "1 Scheibe", calories: 80, protein: 4, carbs: 15, fat: 1, fiber: 3, coherenceNutrients: ["B-Vitamine"])
            ]
        } else {
            breakfastFoods = [
                FoodItem(name: "Bio-Eier", portion: "3 Stück", calories: 234, protein: 18, carbs: 2, fat: 16, fiber: 0, coherenceNutrients: ["Cholin", "B12", "Omega-3"]),
                FoodItem(name: "Avocado", portion: "1/2", calories: 160, protein: 2, carbs: 9, fat: 15, fiber: 7, coherenceNutrients: ["Omega-3", "Kalium"]),
                FoodItem(name: "Spinat", portion: "50g", calories: 12, protein: 1, carbs: 2, fat: 0, fiber: 1, coherenceNutrients: ["Magnesium", "Folat"])
            ]
        }

        meals.append(MealPlan(
            mealType: .breakfast,
            time: userProfile.chronotype == .lion ? "06:00" : "07:30",
            foods: breakfastFoods,
            circadianOptimal: true,
            coherenceBenefit: "Proteinreich morgens stabilisiert Blutzucker und Cortisol"
        ))

        // Mittagessen - Ausgewogen
        let lunchFoods: [FoodItem]
        if userProfile.dietaryRestrictions.contains(.vegan) {
            lunchFoods = [
                FoodItem(name: "Quinoa Bowl", portion: "150g", calories: 220, protein: 8, carbs: 39, fat: 4, fiber: 5, coherenceNutrients: ["Protein", "Magnesium"]),
                FoodItem(name: "Linsen", portion: "100g", calories: 116, protein: 9, carbs: 20, fat: 0, fiber: 8, coherenceNutrients: ["Protein", "Eisen"]),
                FoodItem(name: "Buntes Gemüse", portion: "200g", calories: 80, protein: 4, carbs: 16, fat: 0, fiber: 6, coherenceNutrients: ["Antioxidantien"])
            ]
        } else {
            lunchFoods = [
                FoodItem(name: "Wildlachs", portion: "150g", calories: 280, protein: 35, carbs: 0, fat: 15, fiber: 0, coherenceNutrients: ["Omega-3 EPA/DHA", "B12", "Selen"]),
                FoodItem(name: "Süßkartoffel", portion: "150g", calories: 130, protein: 2, carbs: 30, fat: 0, fiber: 4, coherenceNutrients: ["Beta-Carotin", "Kalium"]),
                FoodItem(name: "Brokkoli", portion: "150g", calories: 50, protein: 4, carbs: 10, fat: 0, fiber: 4, coherenceNutrients: ["Sulforaphan", "Vitamin C"])
            ]
        }

        meals.append(MealPlan(
            mealType: .lunch,
            time: "12:30",
            foods: lunchFoods,
            circadianOptimal: true,
            coherenceBenefit: "Omega-3 reiche Mahlzeit für optimale HRV"
        ))

        // Nachmittags-Snack
        meals.append(MealPlan(
            mealType: .afternoonSnack,
            time: "15:30",
            foods: [
                FoodItem(name: "Walnüsse", portion: "30g", calories: 185, protein: 4, carbs: 4, fat: 18, fiber: 2, coherenceNutrients: ["Omega-3 ALA", "Melatonin-Vorläufer"]),
                FoodItem(name: "Dunkle Schokolade 85%", portion: "20g", calories: 120, protein: 2, carbs: 8, fat: 10, fiber: 2, coherenceNutrients: ["Magnesium", "Theobromin"])
            ],
            circadianOptimal: true,
            coherenceBenefit: "Magnesium und gesunde Fette für Nachmittags-Kohärenz"
        ))

        // Abendessen - Leicht verdaulich
        let dinnerFoods: [FoodItem]
        if userProfile.dietaryRestrictions.contains(.vegan) {
            dinnerFoods = [
                FoodItem(name: "Tempeh", portion: "150g", calories: 285, protein: 30, carbs: 15, fat: 15, fiber: 0, coherenceNutrients: ["Protein", "Probiotika"]),
                FoodItem(name: "Gemüsepfanne", portion: "200g", calories: 100, protein: 4, carbs: 20, fat: 2, fiber: 6, coherenceNutrients: ["Ballaststoffe", "Antioxidantien"])
            ]
        } else {
            dinnerFoods = [
                FoodItem(name: "Bio-Hühnerbrust", portion: "150g", calories: 165, protein: 31, carbs: 0, fat: 4, fiber: 0, coherenceNutrients: ["Protein", "Tryptophan"]),
                FoodItem(name: "Gedämpftes Gemüse", portion: "200g", calories: 80, protein: 4, carbs: 16, fat: 0, fiber: 6, coherenceNutrients: ["Ballaststoffe", "Magnesium"])
            ]
        }

        meals.append(MealPlan(
            mealType: .dinner,
            time: userProfile.chronotype == .lion ? "18:00" : "19:00",
            foods: dinnerFoods,
            circadianOptimal: true,
            coherenceBenefit: "Tryptophan-reich für Melatonin-Synthese"
        ))

        // Abend-Snack (optional für besseren Schlaf)
        meals.append(MealPlan(
            mealType: .eveningSnack,
            time: "20:30",
            foods: [
                FoodItem(name: "Sauerkirschsaft", portion: "200ml", calories: 140, protein: 1, carbs: 34, fat: 0, fiber: 0, coherenceNutrients: ["Melatonin"]),
                FoodItem(name: "Mandeln", portion: "15g", calories: 87, protein: 3, carbs: 3, fat: 8, fiber: 2, coherenceNutrients: ["Magnesium", "Tryptophan"])
            ],
            circadianOptimal: true,
            coherenceBenefit: "Natürliches Melatonin für optimalen Schlaf"
        ))

        let plan = DailyNutritionPlan(
            targetCalories: tdee,
            targetProtein: protein,
            targetCarbs: carbs,
            targetFat: fat,
            targetFiber: 35,
            targetWater: userProfile.weight * 0.035,  // 35ml/kg
            meals: meals,
            supplements: supplements
        )

        currentNutritionPlan = plan
        return plan
    }

    /// Aktualisiert täglichen Fortschritt
    public func updateProgress(
        waterIntake: Double? = nil,
        calories: Int? = nil,
        protein: Double? = nil,
        exerciseMinutes: Int? = nil,
        meditationMinutes: Int? = nil,
        sleepHours: Double? = nil,
        hrv: Double? = nil,
        coherence: Double? = nil,
        steps: Int? = nil,
        sunlight: Int? = nil
    ) {
        if let water = waterIntake { dailyProgress.waterIntake = water }
        if let cal = calories { dailyProgress.caloriesConsumed = cal }
        if let prot = protein { dailyProgress.proteinConsumed = prot }
        if let exercise = exerciseMinutes { dailyProgress.exerciseMinutes = exercise }
        if let meditation = meditationMinutes { dailyProgress.meditationMinutes = meditation }
        if let sleep = sleepHours { dailyProgress.sleepHours = sleep }
        if let h = hrv { dailyProgress.avgHRV = h }
        if let c = coherence { dailyProgress.avgCoherence = c }
        if let s = steps { dailyProgress.stepsCount = s }
        if let sun = sunlight { dailyProgress.sunlightMinutes = sun }
    }

    /// Erstellt Standard-Wellness-Ziele
    public func createDefaultGoals() {
        personalGoals = [
            WellnessGoal(
                title: "HRV über 50ms",
                category: .hrv,
                targetValue: 50,
                unit: "ms"
            ),
            WellnessGoal(
                title: "Kohärenz 80%",
                category: .coherence,
                targetValue: 80,
                unit: "%"
            ),
            WellnessGoal(
                title: "7+ Stunden Schlaf",
                category: .sleep,
                targetValue: 7,
                unit: "Stunden"
            ),
            WellnessGoal(
                title: "150 Min Sport/Woche",
                category: .fitness,
                targetValue: 150,
                unit: "Minuten"
            ),
            WellnessGoal(
                title: "2.5L Wasser/Tag",
                category: .hydration,
                targetValue: 2.5,
                unit: "Liter"
            ),
            WellnessGoal(
                title: "20 Min Meditation/Tag",
                category: .mindfulness,
                targetValue: 20,
                unit: "Minuten"
            )
        ]
    }

    // MARK: - Private Methods

    private func generateDefaultPlans() {
        _ = generateFitnessPlan()
        _ = generateNutritionPlan()
        createDefaultGoals()
    }
}

// MARK: - Health Disclaimer

public struct LifestyleHealthDisclaimer {
    public static let fitnessDisclaimer = """
    WICHTIG: Konsultieren Sie vor Beginn eines neuen Trainingsprogramms
    einen Arzt, insbesondere wenn Sie gesundheitliche Einschränkungen haben.
    Die Trainingsempfehlungen sind allgemeiner Natur und nicht individuell angepasst.
    """

    public static let nutritionDisclaimer = """
    WICHTIG: Die Ernährungsempfehlungen ersetzen keine professionelle
    Ernährungsberatung. Bei Allergien, Unverträglichkeiten oder
    Erkrankungen konsultieren Sie einen Ernährungsberater oder Arzt.
    Supplements sollten vor der Einnahme mit einem Arzt besprochen werden.
    """
}

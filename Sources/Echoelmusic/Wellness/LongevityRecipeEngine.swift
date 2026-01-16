import Foundation
#if canImport(Combine)
import Combine
#endif

// ╔═══════════════════════════════════════════════════════════════════════════════════════════════════════╗
// ║                                                                                                       ║
// ║   ██████╗ ███████╗███████╗██╗██████╗ ███████╗    ███████╗███╗   ██╗ ██████╗ ██╗███╗   ██╗███████╗     ║
// ║   ██╔══██╗██╔════╝╚══███╔╝██║██╔══██╗██╔════╝    ██╔════╝████╗  ██║██╔════╝ ██║████╗  ██║██╔════╝     ║
// ║   ██████╔╝█████╗    ███╔╝ ██║██████╔╝█████╗      █████╗  ██╔██╗ ██║██║  ███╗██║██╔██╗ ██║█████╗       ║
// ║   ██╔══██╗██╔══╝   ███╔╝  ██║██╔═══╝ ██╔══╝      ██╔══╝  ██║╚██╗██║██║   ██║██║██║╚██╗██║██╔══╝       ║
// ║   ██║  ██║███████╗███████╗██║██║     ███████╗    ███████╗██║ ╚████║╚██████╔╝██║██║ ╚████║███████╗     ║
// ║   ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝╚═╝     ╚══════╝    ╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝╚═╝  ╚═══╝╚══════╝     ║
// ║                                                                                                       ║
// ║   🍽️ LONGEVITY RECIPE ENGINE - Wissenschaftlich Fundierte Rezeptgenerierung 🍽️                       ║
// ║                                                                                                       ║
// ║   Blue Zone Recipes • Meal Planning • Shopping Lists • Macros • HRV-Optimized                        ║
// ║                                                                                                       ║
// ║   DISCLAIMER: Keine medizinische Beratung. Konsultieren Sie einen Arzt.                              ║
// ║                                                                                                       ║
// ╚═══════════════════════════════════════════════════════════════════════════════════════════════════════╝

// MARK: - Recipe Difficulty

public enum RecipeDifficulty: String, CaseIterable, Codable {
    case beginner = "Anfänger"
    case intermediate = "Fortgeschritten"
    case advanced = "Profi"
    case masterChef = "Meisterkoch"

    public var icon: String {
        switch self {
        case .beginner: return "👶"
        case .intermediate: return "👨‍🍳"
        case .advanced: return "🧑‍🍳"
        case .masterChef: return "👨‍🍳⭐"
        }
    }

    public var estimatedTimeMultiplier: Double {
        switch self {
        case .beginner: return 1.0
        case .intermediate: return 1.2
        case .advanced: return 1.5
        case .masterChef: return 2.0
        }
    }
}

// MARK: - Meal Type

public enum MealType: String, CaseIterable, Codable {
    case breakfast = "Frühstück"
    case lunch = "Mittagessen"
    case dinner = "Abendessen"
    case snack = "Snack"
    case dessert = "Dessert"
    case drink = "Getränk"
    case soup = "Suppe"
    case salad = "Salat"
    case mainCourse = "Hauptgericht"
    case sideDish = "Beilage"

    public var icon: String {
        switch self {
        case .breakfast: return "🌅"
        case .lunch: return "☀️"
        case .dinner: return "🌙"
        case .snack: return "🍎"
        case .dessert: return "🍰"
        case .drink: return "🥤"
        case .soup: return "🍲"
        case .salad: return "🥗"
        case .mainCourse: return "🍽️"
        case .sideDish: return "🥬"
        }
    }
}

// MARK: - Diet Type

public enum DietType: String, CaseIterable, Codable {
    case standard = "Standard"
    case vegetarian = "Vegetarisch"
    case vegan = "Vegan"
    case pescatarian = "Pescetarisch"
    case keto = "Keto"
    case paleo = "Paleo"
    case mediterranean = "Mediterran"
    case okinawan = "Okinawa"
    case blueZone = "Blue Zone"
    case antiInflammatory = "Anti-Inflammatorisch"
    case glutenFree = "Glutenfrei"
    case dairyFree = "Laktosefrei"
    case lowFodmap = "Low FODMAP"
    case whole30 = "Whole30"
    case intermittentFasting = "Intervallfasten"

    public var icon: String {
        switch self {
        case .standard: return "🍽️"
        case .vegetarian: return "🥬"
        case .vegan: return "🌱"
        case .pescatarian: return "🐟"
        case .keto: return "🥑"
        case .paleo: return "🦴"
        case .mediterranean: return "🫒"
        case .okinawan: return "🇯🇵"
        case .blueZone: return "💙"
        case .antiInflammatory: return "🔥"
        case .glutenFree: return "🌾❌"
        case .dairyFree: return "🥛❌"
        case .lowFodmap: return "🧬"
        case .whole30: return "3️⃣0️⃣"
        case .intermittentFasting: return "⏰"
        }
    }
}

// MARK: - Ingredient

public struct Ingredient: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var nameDe: String
    public var amount: Double
    public var unit: String
    public var category: IngredientCategory
    public var longevityCompounds: [String]
    public var calories: Double
    public var protein: Double
    public var carbs: Double
    public var fat: Double
    public var fiber: Double
    public var isOptional: Bool
    public var substitutes: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        nameDe: String = "",
        amount: Double,
        unit: String,
        category: IngredientCategory = .vegetable,
        longevityCompounds: [String] = [],
        calories: Double = 0,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        fiber: Double = 0,
        isOptional: Bool = false,
        substitutes: [String] = []
    ) {
        self.id = id
        self.name = name
        self.nameDe = nameDe.isEmpty ? name : nameDe
        self.amount = amount
        self.unit = unit
        self.category = category
        self.longevityCompounds = longevityCompounds
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.isOptional = isOptional
        self.substitutes = substitutes
    }
}

public enum IngredientCategory: String, CaseIterable, Codable {
    case vegetable = "Gemüse"
    case fruit = "Obst"
    case grain = "Getreide"
    case protein = "Protein"
    case dairy = "Milchprodukte"
    case fat = "Fette & Öle"
    case spice = "Gewürze"
    case herb = "Kräuter"
    case legume = "Hülsenfrüchte"
    case nut = "Nüsse & Samen"
    case seafood = "Meeresfrüchte"
    case fermented = "Fermentiert"
    case sweetener = "Süßungsmittel"
    case liquid = "Flüssigkeit"
    case other = "Sonstiges"

    public var icon: String {
        switch self {
        case .vegetable: return "🥬"
        case .fruit: return "🍎"
        case .grain: return "🌾"
        case .protein: return "🥩"
        case .dairy: return "🧀"
        case .fat: return "🫒"
        case .spice: return "🌶️"
        case .herb: return "🌿"
        case .legume: return "🫘"
        case .nut: return "🥜"
        case .seafood: return "🦐"
        case .fermented: return "🥒"
        case .sweetener: return "🍯"
        case .liquid: return "💧"
        case .other: return "📦"
        }
    }
}

// MARK: - Recipe Step

public struct RecipeStep: Identifiable, Codable {
    public var id: UUID
    public var stepNumber: Int
    public var instruction: String
    public var instructionDe: String
    public var durationMinutes: Int
    public var technique: CookingTechnique
    public var temperature: Int?
    public var temperatureUnit: String
    public var tips: [String]
    public var warningNotes: [String]

    public init(
        id: UUID = UUID(),
        stepNumber: Int,
        instruction: String,
        instructionDe: String = "",
        durationMinutes: Int = 5,
        technique: CookingTechnique = .prep,
        temperature: Int? = nil,
        temperatureUnit: String = "°C",
        tips: [String] = [],
        warningNotes: [String] = []
    ) {
        self.id = id
        self.stepNumber = stepNumber
        self.instruction = instruction
        self.instructionDe = instructionDe.isEmpty ? instruction : instructionDe
        self.durationMinutes = durationMinutes
        self.technique = technique
        self.temperature = temperature
        self.temperatureUnit = temperatureUnit
        self.tips = tips
        self.warningNotes = warningNotes
    }
}

public enum CookingTechnique: String, CaseIterable, Codable {
    case prep = "Vorbereitung"
    case chop = "Schneiden"
    case mix = "Mischen"
    case blend = "Pürieren"
    case saute = "Anbraten"
    case fry = "Braten"
    case bake = "Backen"
    case roast = "Rösten"
    case grill = "Grillen"
    case steam = "Dämpfen"
    case boil = "Kochen"
    case simmer = "Köcheln"
    case marinate = "Marinieren"
    case ferment = "Fermentieren"
    case rest = "Ruhen lassen"
    case serve = "Anrichten"

    public var icon: String {
        switch self {
        case .prep: return "📋"
        case .chop: return "🔪"
        case .mix: return "🥄"
        case .blend: return "🫙"
        case .saute: return "🍳"
        case .fry: return "🔥"
        case .bake: return "🥧"
        case .roast: return "🍗"
        case .grill: return "🥩"
        case .steam: return "♨️"
        case .boil: return "🫕"
        case .simmer: return "🍲"
        case .marinate: return "🧂"
        case .ferment: return "🧫"
        case .rest: return "⏳"
        case .serve: return "🍽️"
        }
    }
}

// MARK: - Nutrition Info

public struct NutritionInfo: Codable, Equatable {
    public var calories: Double
    public var protein: Double
    public var carbohydrates: Double
    public var fat: Double
    public var fiber: Double
    public var sugar: Double
    public var sodium: Double
    public var cholesterol: Double
    public var saturatedFat: Double
    public var unsaturatedFat: Double
    public var omega3: Double
    public var omega6: Double
    public var vitaminA: Double
    public var vitaminC: Double
    public var vitaminD: Double
    public var vitaminE: Double
    public var vitaminK: Double
    public var vitaminB12: Double
    public var folate: Double
    public var calcium: Double
    public var iron: Double
    public var magnesium: Double
    public var potassium: Double
    public var zinc: Double
    public var selenium: Double

    public init(
        calories: Double = 0,
        protein: Double = 0,
        carbohydrates: Double = 0,
        fat: Double = 0,
        fiber: Double = 0,
        sugar: Double = 0,
        sodium: Double = 0,
        cholesterol: Double = 0,
        saturatedFat: Double = 0,
        unsaturatedFat: Double = 0,
        omega3: Double = 0,
        omega6: Double = 0,
        vitaminA: Double = 0,
        vitaminC: Double = 0,
        vitaminD: Double = 0,
        vitaminE: Double = 0,
        vitaminK: Double = 0,
        vitaminB12: Double = 0,
        folate: Double = 0,
        calcium: Double = 0,
        iron: Double = 0,
        magnesium: Double = 0,
        potassium: Double = 0,
        zinc: Double = 0,
        selenium: Double = 0
    ) {
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
        self.cholesterol = cholesterol
        self.saturatedFat = saturatedFat
        self.unsaturatedFat = unsaturatedFat
        self.omega3 = omega3
        self.omega6 = omega6
        self.vitaminA = vitaminA
        self.vitaminC = vitaminC
        self.vitaminD = vitaminD
        self.vitaminE = vitaminE
        self.vitaminK = vitaminK
        self.vitaminB12 = vitaminB12
        self.folate = folate
        self.calcium = calcium
        self.iron = iron
        self.magnesium = magnesium
        self.potassium = potassium
        self.zinc = zinc
        self.selenium = selenium
    }

    /// Longevity score based on anti-inflammatory, antioxidant content
    public var longevityScore: Double {
        var score = 0.0
        score += min(fiber / 10.0, 1.0) * 20           // High fiber = good
        score += min(omega3 / 2.0, 1.0) * 15           // Omega-3
        score += min(vitaminC / 100.0, 1.0) * 10      // Antioxidant
        score += min(vitaminE / 15.0, 1.0) * 10       // Antioxidant
        score += min(selenium / 55.0, 1.0) * 10       // Antioxidant
        score += min(magnesium / 400.0, 1.0) * 10     // Essential mineral
        score += (1.0 - min(sugar / 50.0, 1.0)) * 15  // Low sugar = good
        score += (1.0 - min(sodium / 2300.0, 1.0)) * 10 // Low sodium = good
        return min(score, 100.0)
    }
}

// MARK: - Recipe

public struct Recipe: Identifiable, Codable {
    public var id: UUID
    public var name: String
    public var nameDe: String
    public var description: String
    public var descriptionDe: String
    public var mealType: MealType
    public var dietTypes: [DietType]
    public var difficulty: RecipeDifficulty
    public var servings: Int
    public var prepTimeMinutes: Int
    public var cookTimeMinutes: Int
    public var totalTimeMinutes: Int
    public var ingredients: [Ingredient]
    public var steps: [RecipeStep]
    public var nutrition: NutritionInfo
    public var longevityCompounds: [String]
    public var hallmarksOfAgingTargeted: [String]
    public var blueZoneOrigin: String?
    public var hrvBenefit: Double
    public var tags: [String]
    public var imageURL: String?
    public var videoURL: String?
    public var source: String
    public var createdAt: Date
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        nameDe: String = "",
        description: String = "",
        descriptionDe: String = "",
        mealType: MealType = .mainCourse,
        dietTypes: [DietType] = [.standard],
        difficulty: RecipeDifficulty = .intermediate,
        servings: Int = 4,
        prepTimeMinutes: Int = 15,
        cookTimeMinutes: Int = 30,
        ingredients: [Ingredient] = [],
        steps: [RecipeStep] = [],
        nutrition: NutritionInfo = NutritionInfo(),
        longevityCompounds: [String] = [],
        hallmarksOfAgingTargeted: [String] = [],
        blueZoneOrigin: String? = nil,
        hrvBenefit: Double = 0.5,
        tags: [String] = [],
        imageURL: String? = nil,
        videoURL: String? = nil,
        source: String = "Echoelmusic",
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.nameDe = nameDe.isEmpty ? name : nameDe
        self.description = description
        self.descriptionDe = descriptionDe.isEmpty ? description : descriptionDe
        self.mealType = mealType
        self.dietTypes = dietTypes
        self.difficulty = difficulty
        self.servings = servings
        self.prepTimeMinutes = prepTimeMinutes
        self.cookTimeMinutes = cookTimeMinutes
        self.totalTimeMinutes = prepTimeMinutes + cookTimeMinutes
        self.ingredients = ingredients
        self.steps = steps
        self.nutrition = nutrition
        self.longevityCompounds = longevityCompounds
        self.hallmarksOfAgingTargeted = hallmarksOfAgingTargeted
        self.blueZoneOrigin = blueZoneOrigin
        self.hrvBenefit = hrvBenefit
        self.tags = tags
        self.imageURL = imageURL
        self.videoURL = videoURL
        self.source = source
        self.createdAt = Date()
        self.isFavorite = isFavorite
    }
}

// MARK: - Meal Plan

public struct MealPlan: Identifiable, Codable {
    public var id: UUID
    public var name: String
    public var startDate: Date
    public var endDate: Date
    public var days: [MealPlanDay]
    public var dietType: DietType
    public var targetCalories: Double
    public var shoppingList: ShoppingList

    public init(
        id: UUID = UUID(),
        name: String = "Wochenplan",
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(7 * 24 * 60 * 60),
        days: [MealPlanDay] = [],
        dietType: DietType = .blueZone,
        targetCalories: Double = 2000,
        shoppingList: ShoppingList = ShoppingList()
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.days = days
        self.dietType = dietType
        self.targetCalories = targetCalories
        self.shoppingList = shoppingList
    }
}

public struct MealPlanDay: Identifiable, Codable {
    public var id: UUID
    public var date: Date
    public var breakfast: Recipe?
    public var lunch: Recipe?
    public var dinner: Recipe?
    public var snacks: [Recipe]
    public var totalNutrition: NutritionInfo

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        breakfast: Recipe? = nil,
        lunch: Recipe? = nil,
        dinner: Recipe? = nil,
        snacks: [Recipe] = []
    ) {
        self.id = id
        self.date = date
        self.breakfast = breakfast
        self.lunch = lunch
        self.dinner = dinner
        self.snacks = snacks
        self.totalNutrition = NutritionInfo()
    }
}

// MARK: - Shopping List

public struct ShoppingList: Identifiable, Codable {
    public var id: UUID
    public var name: String
    public var items: [ShoppingItem]
    public var createdAt: Date
    public var isCompleted: Bool

    public init(
        id: UUID = UUID(),
        name: String = "Einkaufsliste",
        items: [ShoppingItem] = [],
        isCompleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.items = items
        self.createdAt = Date()
        self.isCompleted = isCompleted
    }

    public var itemsByCategory: [IngredientCategory: [ShoppingItem]] {
        Dictionary(grouping: items) { $0.category }
    }

    public var checkedCount: Int {
        items.filter { $0.isChecked }.count
    }

    public var totalCount: Int {
        items.count
    }
}

public struct ShoppingItem: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var amount: Double
    public var unit: String
    public var category: IngredientCategory
    public var isChecked: Bool
    public var estimatedPrice: Double?
    public var store: String?

    public init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        unit: String,
        category: IngredientCategory,
        isChecked: Bool = false,
        estimatedPrice: Double? = nil,
        store: String? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
        self.category = category
        self.isChecked = isChecked
        self.estimatedPrice = estimatedPrice
        self.store = store
    }
}

// MARK: - Main Recipe Engine

@MainActor
public class LongevityRecipeEngine: ObservableObject {

    // MARK: - Published State

    @Published public var recipes: [Recipe] = []
    @Published public var currentMealPlan: MealPlan?
    @Published public var currentShoppingList: ShoppingList?
    @Published public var favoriteRecipes: [Recipe] = []
    @Published public var recentlyViewed: [Recipe] = []
    @Published public var isLoading: Bool = false

    // MARK: - Settings

    @Published public var preferredDietType: DietType = .blueZone
    @Published public var targetCaloriesPerDay: Double = 2000
    @Published public var allergies: [String] = []
    @Published public var dislikedIngredients: [String] = []

    // MARK: - Disclaimer

    public static let healthDisclaimer = """
    ⚠️ WICHTIGER HINWEIS / IMPORTANT DISCLAIMER:

    Diese Rezepte und Ernährungspläne dienen nur zu Informationszwecken.
    Sie ersetzen KEINE medizinische Beratung oder professionelle Ernährungsberatung.

    - Konsultieren Sie vor Ernährungsumstellungen einen Arzt
    - Bei Allergien oder Unverträglichkeiten: Zutaten sorgfältig prüfen
    - Nährwertangaben sind Schätzungen und können variieren
    - "Longevity"-Claims basieren auf Forschung, garantieren aber keine Ergebnisse

    This is NOT medical advice. Consult a healthcare professional.
    """

    // MARK: - Initialization

    public init() {
        loadDefaultRecipes()
    }

    // MARK: - Recipe Database

    private func loadDefaultRecipes() {
        recipes = [
            createOkinawanMisoSoup(),
            createMediterraneanSalad(),
            createSardinianMinestrone(),
            createBlueZoneBowl(),
            createTurmericGoldenMilk(),
            createIkarianHerbTea(),
            createNicoyaBlackBeanSoup(),
            createLomaLindaNutLoaf(),
            createAntiInflammatoryBowl(),
            createLongevityBreakfastBowl()
        ]
    }

    // MARK: - Sample Recipes

    private func createOkinawanMisoSoup() -> Recipe {
        Recipe(
            name: "Okinawan Longevity Miso Soup",
            nameDe: "Okinawa Langlebigkeits-Misosuppe",
            description: "Traditional Okinawan miso soup with tofu, seaweed, and longevity vegetables",
            descriptionDe: "Traditionelle okinawanische Misosuppe mit Tofu, Seetang und Langlebigkeitsgemüse",
            mealType: .soup,
            dietTypes: [.vegan, .okinawan, .blueZone, .antiInflammatory],
            difficulty: .beginner,
            servings: 4,
            prepTimeMinutes: 10,
            cookTimeMinutes: 15,
            ingredients: [
                Ingredient(name: "White Miso Paste", nameDe: "Weiße Misopaste", amount: 4, unit: "tbsp",
                          category: .fermented, longevityCompounds: ["Isoflavones", "Probiotics"]),
                Ingredient(name: "Firm Tofu", nameDe: "Fester Tofu", amount: 200, unit: "g",
                          category: .protein, longevityCompounds: ["Isoflavones", "Genistein"]),
                Ingredient(name: "Wakame Seaweed", nameDe: "Wakame Seetang", amount: 10, unit: "g",
                          category: .vegetable, longevityCompounds: ["Fucoidans", "Iodine"]),
                Ingredient(name: "Green Onions", nameDe: "Frühlingszwiebeln", amount: 4, unit: "stalks",
                          category: .vegetable, longevityCompounds: ["Quercetin", "Allicin"]),
                Ingredient(name: "Dashi Stock", nameDe: "Dashi-Brühe", amount: 1, unit: "L",
                          category: .liquid),
                Ingredient(name: "Goya (Bitter Melon)", nameDe: "Bittergurke", amount: 100, unit: "g",
                          category: .vegetable, longevityCompounds: ["Momordicin", "Charantin"], isOptional: true)
            ],
            steps: [
                RecipeStep(stepNumber: 1, instruction: "Soak wakame in water for 5 minutes",
                          instructionDe: "Wakame 5 Minuten in Wasser einweichen", durationMinutes: 5, technique: .prep),
                RecipeStep(stepNumber: 2, instruction: "Heat dashi stock to a gentle simmer",
                          instructionDe: "Dashi-Brühe sanft erhitzen", durationMinutes: 5, technique: .simmer),
                RecipeStep(stepNumber: 3, instruction: "Add tofu cubes and wakame",
                          instructionDe: "Tofuwürfel und Wakame hinzufügen", durationMinutes: 3, technique: .simmer),
                RecipeStep(stepNumber: 4, instruction: "Remove from heat, stir in miso paste (never boil miso!)",
                          instructionDe: "Vom Herd nehmen, Misopaste einrühren (niemals kochen!)", durationMinutes: 2, technique: .mix,
                          tips: ["Boiling miso destroys probiotics", "Miso kochen zerstört Probiotika"]),
                RecipeStep(stepNumber: 5, instruction: "Garnish with green onions and serve",
                          instructionDe: "Mit Frühlingszwiebeln garnieren und servieren", durationMinutes: 1, technique: .serve)
            ],
            nutrition: NutritionInfo(calories: 120, protein: 10, carbohydrates: 8, fat: 5, fiber: 2,
                                    sodium: 800, vitaminK: 15, calcium: 150, iron: 2, magnesium: 40),
            longevityCompounds: ["Isoflavones", "Genistein", "Probiotics", "Fucoidans", "Quercetin"],
            hallmarksOfAgingTargeted: ["Cellular Senescence", "Mitochondrial Dysfunction", "Gut Microbiome"],
            blueZoneOrigin: "Okinawa, Japan",
            hrvBenefit: 0.7,
            tags: ["soup", "vegan", "probiotic", "okinawa", "quick"]
        )
    }

    private func createMediterraneanSalad() -> Recipe {
        Recipe(
            name: "Mediterranean Longevity Salad",
            nameDe: "Mediterraner Langlebigkeits-Salat",
            description: "Colorful salad with olive oil, feta, and anti-inflammatory ingredients",
            descriptionDe: "Bunter Salat mit Olivenöl, Feta und entzündungshemmenden Zutaten",
            mealType: .salad,
            dietTypes: [.vegetarian, .mediterranean, .blueZone, .antiInflammatory],
            difficulty: .beginner,
            servings: 2,
            prepTimeMinutes: 15,
            cookTimeMinutes: 0,
            ingredients: [
                Ingredient(name: "Mixed Greens", nameDe: "Gemischte Blattsalate", amount: 200, unit: "g",
                          category: .vegetable, longevityCompounds: ["Chlorophyll", "Folate"]),
                Ingredient(name: "Cherry Tomatoes", nameDe: "Kirschtomaten", amount: 150, unit: "g",
                          category: .vegetable, longevityCompounds: ["Lycopene"]),
                Ingredient(name: "Cucumber", nameDe: "Gurke", amount: 1, unit: "medium",
                          category: .vegetable),
                Ingredient(name: "Red Onion", nameDe: "Rote Zwiebel", amount: 0.5, unit: "medium",
                          category: .vegetable, longevityCompounds: ["Quercetin"]),
                Ingredient(name: "Kalamata Olives", nameDe: "Kalamata-Oliven", amount: 50, unit: "g",
                          category: .vegetable, longevityCompounds: ["Oleocanthal", "Hydroxytyrosol"]),
                Ingredient(name: "Extra Virgin Olive Oil", nameDe: "Natives Olivenöl Extra", amount: 3, unit: "tbsp",
                          category: .fat, longevityCompounds: ["Oleocanthal", "Polyphenols"]),
                Ingredient(name: "Feta Cheese", nameDe: "Feta-Käse", amount: 100, unit: "g",
                          category: .dairy),
                Ingredient(name: "Walnuts", nameDe: "Walnüsse", amount: 30, unit: "g",
                          category: .nut, longevityCompounds: ["Omega-3", "Ellagitannins"])
            ],
            steps: [
                RecipeStep(stepNumber: 1, instruction: "Wash and dry all vegetables",
                          instructionDe: "Alle Gemüse waschen und trocknen", durationMinutes: 5, technique: .prep),
                RecipeStep(stepNumber: 2, instruction: "Chop vegetables into bite-sized pieces",
                          instructionDe: "Gemüse in mundgerechte Stücke schneiden", durationMinutes: 7, technique: .chop),
                RecipeStep(stepNumber: 3, instruction: "Combine in a large bowl",
                          instructionDe: "In einer großen Schüssel vermischen", durationMinutes: 2, technique: .mix),
                RecipeStep(stepNumber: 4, instruction: "Drizzle with olive oil, crumble feta, add walnuts",
                          instructionDe: "Mit Olivenöl beträufeln, Feta zerbröseln, Walnüsse hinzufügen", durationMinutes: 1, technique: .serve)
            ],
            nutrition: NutritionInfo(calories: 450, protein: 12, carbohydrates: 15, fat: 38, fiber: 5,
                                    vitaminC: 30, vitaminE: 8, calcium: 200, omega3: 1.5),
            longevityCompounds: ["Oleocanthal", "Lycopene", "Quercetin", "Omega-3", "Polyphenols"],
            hallmarksOfAgingTargeted: ["Chronic Inflammation", "Oxidative Stress", "Cardiovascular Health"],
            blueZoneOrigin: "Ikaria, Greece / Sardinia, Italy",
            hrvBenefit: 0.65,
            tags: ["salad", "raw", "quick", "mediterranean", "heart-healthy"]
        )
    }

    private func createSardinianMinestrone() -> Recipe {
        Recipe(
            name: "Sardinian Blue Zone Minestrone",
            nameDe: "Sardischer Blue Zone Minestrone",
            description: "Hearty bean and vegetable soup from the world's longest-lived men",
            mealType: .soup,
            dietTypes: [.vegan, .mediterranean, .blueZone],
            difficulty: .intermediate,
            servings: 6,
            prepTimeMinutes: 20,
            cookTimeMinutes: 45,
            ingredients: [
                Ingredient(name: "Cannellini Beans", nameDe: "Weiße Bohnen", amount: 400, unit: "g",
                          category: .legume, longevityCompounds: ["Resistant Starch", "Fiber"]),
                Ingredient(name: "Fava Beans", nameDe: "Saubohnen", amount: 200, unit: "g",
                          category: .legume, longevityCompounds: ["L-DOPA", "Fiber"]),
                Ingredient(name: "Barley", nameDe: "Gerste", amount: 100, unit: "g",
                          category: .grain, longevityCompounds: ["Beta-glucan"]),
                Ingredient(name: "Fennel", nameDe: "Fenchel", amount: 1, unit: "bulb",
                          category: .vegetable, longevityCompounds: ["Anethole"]),
                Ingredient(name: "Swiss Chard", nameDe: "Mangold", amount: 200, unit: "g",
                          category: .vegetable, longevityCompounds: ["Betalains"]),
                Ingredient(name: "Tomatoes", nameDe: "Tomaten", amount: 400, unit: "g",
                          category: .vegetable, longevityCompounds: ["Lycopene"]),
                Ingredient(name: "Garlic", nameDe: "Knoblauch", amount: 4, unit: "cloves",
                          category: .vegetable, longevityCompounds: ["Allicin", "S-allyl cysteine"]),
                Ingredient(name: "Rosemary", nameDe: "Rosmarin", amount: 2, unit: "sprigs",
                          category: .herb, longevityCompounds: ["Carnosic acid", "Rosmarinic acid"]),
                Ingredient(name: "Extra Virgin Olive Oil", nameDe: "Natives Olivenöl Extra", amount: 4, unit: "tbsp",
                          category: .fat, longevityCompounds: ["Oleocanthal"])
            ],
            nutrition: NutritionInfo(calories: 320, protein: 15, carbohydrates: 45, fat: 10, fiber: 12),
            longevityCompounds: ["Resistant Starch", "Beta-glucan", "Allicin", "Lycopene", "Carnosic acid"],
            hallmarksOfAgingTargeted: ["Gut Microbiome", "Chronic Inflammation", "Metabolic Health"],
            blueZoneOrigin: "Sardinia, Italy",
            hrvBenefit: 0.75,
            tags: ["soup", "beans", "hearty", "sardinia", "fiber-rich"]
        )
    }

    private func createBlueZoneBowl() -> Recipe {
        Recipe(
            name: "Ultimate Blue Zone Power Bowl",
            nameDe: "Ultimative Blue Zone Power Bowl",
            description: "Combines longevity foods from all 5 Blue Zones",
            mealType: .mainCourse,
            dietTypes: [.vegan, .blueZone, .antiInflammatory],
            difficulty: .intermediate,
            servings: 2,
            prepTimeMinutes: 20,
            cookTimeMinutes: 25,
            ingredients: [
                Ingredient(name: "Purple Sweet Potato", nameDe: "Lila Süßkartoffel", amount: 200, unit: "g",
                          category: .vegetable, longevityCompounds: ["Anthocyanins"], blueZoneOrigin: "Okinawa"),
                Ingredient(name: "Black Beans", nameDe: "Schwarze Bohnen", amount: 150, unit: "g",
                          category: .legume, longevityCompounds: ["Anthocyanins", "Resistant Starch"], blueZoneOrigin: "Nicoya"),
                Ingredient(name: "Bitter Greens", nameDe: "Bittere Blätter", amount: 100, unit: "g",
                          category: .vegetable, longevityCompounds: ["Sulforaphane"], blueZoneOrigin: "Ikaria"),
                Ingredient(name: "Walnuts", nameDe: "Walnüsse", amount: 30, unit: "g",
                          category: .nut, longevityCompounds: ["Omega-3"], blueZoneOrigin: "Loma Linda"),
                Ingredient(name: "Pecorino Cheese", nameDe: "Pecorino-Käse", amount: 20, unit: "g",
                          category: .dairy, isOptional: true, blueZoneOrigin: "Sardinia"),
                Ingredient(name: "Turmeric", nameDe: "Kurkuma", amount: 1, unit: "tsp",
                          category: .spice, longevityCompounds: ["Curcumin"]),
                Ingredient(name: "Extra Virgin Olive Oil", nameDe: "Natives Olivenöl Extra", amount: 2, unit: "tbsp",
                          category: .fat, longevityCompounds: ["Oleocanthal"])
            ],
            nutrition: NutritionInfo(calories: 520, protein: 18, carbohydrates: 55, fat: 25, fiber: 15),
            longevityCompounds: ["Anthocyanins", "Resistant Starch", "Curcumin", "Omega-3", "Oleocanthal"],
            hallmarksOfAgingTargeted: ["All 9 Hallmarks"],
            blueZoneOrigin: "All 5 Blue Zones",
            hrvBenefit: 0.85,
            tags: ["bowl", "complete", "all-blue-zones", "nutrient-dense"]
        )
    }

    private func createTurmericGoldenMilk() -> Recipe {
        Recipe(
            name: "Anti-Inflammatory Golden Milk",
            nameDe: "Entzündungshemmende Goldene Milch",
            description: "Warming turmeric drink for inflammation and sleep",
            mealType: .drink,
            dietTypes: [.vegan, .antiInflammatory, .keto],
            difficulty: .beginner,
            servings: 2,
            prepTimeMinutes: 5,
            cookTimeMinutes: 10,
            ingredients: [
                Ingredient(name: "Coconut Milk", nameDe: "Kokosmilch", amount: 400, unit: "ml", category: .liquid),
                Ingredient(name: "Turmeric Powder", nameDe: "Kurkumapulver", amount: 1, unit: "tbsp",
                          category: .spice, longevityCompounds: ["Curcumin"]),
                Ingredient(name: "Black Pepper", nameDe: "Schwarzer Pfeffer", amount: 0.25, unit: "tsp",
                          category: .spice, longevityCompounds: ["Piperine"],
                          tips: ["Increases curcumin absorption by 2000%"]),
                Ingredient(name: "Ginger", nameDe: "Ingwer", amount: 1, unit: "tsp",
                          category: .spice, longevityCompounds: ["Gingerols"]),
                Ingredient(name: "Cinnamon", nameDe: "Zimt", amount: 0.5, unit: "tsp",
                          category: .spice, longevityCompounds: ["Cinnamaldehyde"]),
                Ingredient(name: "Raw Honey", nameDe: "Roher Honig", amount: 1, unit: "tbsp",
                          category: .sweetener, isOptional: true)
            ],
            nutrition: NutritionInfo(calories: 180, protein: 2, carbohydrates: 8, fat: 16, fiber: 1),
            longevityCompounds: ["Curcumin", "Piperine", "Gingerols", "Cinnamaldehyde"],
            hallmarksOfAgingTargeted: ["Chronic Inflammation", "Oxidative Stress"],
            hrvBenefit: 0.7,
            tags: ["drink", "warming", "sleep", "anti-inflammatory"]
        )
    }

    private func createIkarianHerbTea() -> Recipe {
        Recipe(
            name: "Ikarian Mountain Herb Tea",
            nameDe: "Ikarischer Bergkräutertee",
            description: "Traditional longevity tea from the island where people forget to die",
            mealType: .drink,
            dietTypes: [.vegan, .blueZone, .intermittentFasting],
            difficulty: .beginner,
            servings: 4,
            prepTimeMinutes: 5,
            cookTimeMinutes: 10,
            ingredients: [
                Ingredient(name: "Wild Sage", nameDe: "Wilder Salbei", amount: 2, unit: "tbsp",
                          category: .herb, longevityCompounds: ["Carnosic acid", "Rosmarinic acid"]),
                Ingredient(name: "Wild Rosemary", nameDe: "Wilder Rosmarin", amount: 1, unit: "tbsp",
                          category: .herb, longevityCompounds: ["Carnosol"]),
                Ingredient(name: "Wild Oregano", nameDe: "Wilder Oregano", amount: 1, unit: "tbsp",
                          category: .herb, longevityCompounds: ["Carvacrol", "Thymol"]),
                Ingredient(name: "Raw Honey", nameDe: "Roher Honig", amount: 1, unit: "tsp",
                          category: .sweetener, isOptional: true),
                Ingredient(name: "Water", nameDe: "Wasser", amount: 1, unit: "L", category: .liquid)
            ],
            nutrition: NutritionInfo(calories: 5, protein: 0, carbohydrates: 1, fat: 0, fiber: 0),
            longevityCompounds: ["Carnosic acid", "Rosmarinic acid", "Carvacrol"],
            hallmarksOfAgingTargeted: ["Cognitive Decline", "Chronic Inflammation"],
            blueZoneOrigin: "Ikaria, Greece",
            hrvBenefit: 0.6,
            tags: ["tea", "herbs", "calming", "ikaria", "zero-calorie"]
        )
    }

    private func createNicoyaBlackBeanSoup() -> Recipe {
        Recipe(
            name: "Nicoyan Black Bean Soup",
            nameDe: "Nicoya Schwarzbohnensuppe",
            description: "Traditional Costa Rican soup from the Nicoya Peninsula Blue Zone",
            mealType: .soup,
            dietTypes: [.vegan, .blueZone],
            difficulty: .beginner,
            servings: 6,
            prepTimeMinutes: 15,
            cookTimeMinutes: 60,
            ingredients: [
                Ingredient(name: "Black Beans", nameDe: "Schwarze Bohnen", amount: 500, unit: "g",
                          category: .legume, longevityCompounds: ["Anthocyanins", "Resistant Starch"]),
                Ingredient(name: "Cilantro", nameDe: "Koriander", amount: 1, unit: "bunch",
                          category: .herb, longevityCompounds: ["Linalool"]),
                Ingredient(name: "Culantro/Recao", nameDe: "Langer Koriander", amount: 2, unit: "leaves",
                          category: .herb, isOptional: true),
                Ingredient(name: "Onion", nameDe: "Zwiebel", amount: 1, unit: "large",
                          category: .vegetable, longevityCompounds: ["Quercetin"]),
                Ingredient(name: "Bell Pepper", nameDe: "Paprika", amount: 1, unit: "medium",
                          category: .vegetable, longevityCompounds: ["Vitamin C"]),
                Ingredient(name: "Lime", nameDe: "Limette", amount: 2, unit: "whole",
                          category: .fruit, longevityCompounds: ["Limonene"])
            ],
            nutrition: NutritionInfo(calories: 280, protein: 16, carbohydrates: 48, fat: 2, fiber: 14),
            longevityCompounds: ["Anthocyanins", "Resistant Starch", "Quercetin"],
            hallmarksOfAgingTargeted: ["Gut Microbiome", "Blood Sugar Regulation"],
            blueZoneOrigin: "Nicoya, Costa Rica",
            hrvBenefit: 0.7,
            tags: ["soup", "beans", "nicoya", "fiber-rich", "budget-friendly"]
        )
    }

    private func createLomaLindaNutLoaf() -> Recipe {
        Recipe(
            name: "Loma Linda Nut Loaf",
            nameDe: "Loma Linda Nussbraten",
            description: "Plant-based protein-rich loaf from Seventh-day Adventist tradition",
            mealType: .mainCourse,
            dietTypes: [.vegan, .blueZone],
            difficulty: .intermediate,
            servings: 8,
            prepTimeMinutes: 20,
            cookTimeMinutes: 60,
            ingredients: [
                Ingredient(name: "Walnuts", nameDe: "Walnüsse", amount: 200, unit: "g",
                          category: .nut, longevityCompounds: ["Omega-3", "Ellagitannins"]),
                Ingredient(name: "Almonds", nameDe: "Mandeln", amount: 100, unit: "g",
                          category: .nut, longevityCompounds: ["Vitamin E"]),
                Ingredient(name: "Lentils", nameDe: "Linsen", amount: 200, unit: "g",
                          category: .legume, longevityCompounds: ["Resistant Starch"]),
                Ingredient(name: "Rolled Oats", nameDe: "Haferflocken", amount: 100, unit: "g",
                          category: .grain, longevityCompounds: ["Beta-glucan"]),
                Ingredient(name: "Onion", nameDe: "Zwiebel", amount: 1, unit: "large",
                          category: .vegetable, longevityCompounds: ["Quercetin"]),
                Ingredient(name: "Sage", nameDe: "Salbei", amount: 1, unit: "tbsp",
                          category: .herb, longevityCompounds: ["Carnosic acid"]),
                Ingredient(name: "Thyme", nameDe: "Thymian", amount: 1, unit: "tsp",
                          category: .herb, longevityCompounds: ["Thymol"])
            ],
            nutrition: NutritionInfo(calories: 380, protein: 15, carbohydrates: 25, fat: 26, fiber: 8,
                                    omega3: 2.5, vitaminE: 8),
            longevityCompounds: ["Omega-3", "Ellagitannins", "Beta-glucan", "Vitamin E"],
            hallmarksOfAgingTargeted: ["Cardiovascular Health", "Brain Health"],
            blueZoneOrigin: "Loma Linda, California",
            hrvBenefit: 0.75,
            tags: ["main", "protein", "nuts", "loma-linda", "meal-prep"]
        )
    }

    private func createAntiInflammatoryBowl() -> Recipe {
        Recipe(
            name: "Anti-Inflammatory Power Bowl",
            nameDe: "Entzündungshemmende Power Bowl",
            description: "Maximum anti-inflammatory compounds in one delicious bowl",
            mealType: .mainCourse,
            dietTypes: [.vegan, .antiInflammatory, .glutenFree],
            difficulty: .intermediate,
            servings: 2,
            prepTimeMinutes: 15,
            cookTimeMinutes: 20,
            ingredients: [
                Ingredient(name: "Salmon", nameDe: "Lachs", amount: 200, unit: "g",
                          category: .seafood, longevityCompounds: ["Omega-3", "Astaxanthin"],
                          substitutes: ["Tofu", "Tempeh"]),
                Ingredient(name: "Broccoli", nameDe: "Brokkoli", amount: 200, unit: "g",
                          category: .vegetable, longevityCompounds: ["Sulforaphane"]),
                Ingredient(name: "Turmeric", nameDe: "Kurkuma", amount: 1, unit: "tbsp",
                          category: .spice, longevityCompounds: ["Curcumin"]),
                Ingredient(name: "Ginger", nameDe: "Ingwer", amount: 2, unit: "cm",
                          category: .spice, longevityCompounds: ["Gingerols"]),
                Ingredient(name: "Blueberries", nameDe: "Blaubeeren", amount: 100, unit: "g",
                          category: .fruit, longevityCompounds: ["Anthocyanins", "Pterostilbene"]),
                Ingredient(name: "Extra Virgin Olive Oil", nameDe: "Natives Olivenöl Extra", amount: 2, unit: "tbsp",
                          category: .fat, longevityCompounds: ["Oleocanthal"]),
                Ingredient(name: "Black Pepper", nameDe: "Schwarzer Pfeffer", amount: 0.5, unit: "tsp",
                          category: .spice, longevityCompounds: ["Piperine"])
            ],
            nutrition: NutritionInfo(calories: 480, protein: 28, carbohydrates: 25, fat: 30, fiber: 8,
                                    omega3: 3.0, vitaminC: 80),
            longevityCompounds: ["Omega-3", "Sulforaphane", "Curcumin", "Anthocyanins", "Oleocanthal"],
            hallmarksOfAgingTargeted: ["Chronic Inflammation", "Oxidative Stress", "All 9 Hallmarks"],
            hrvBenefit: 0.9,
            tags: ["bowl", "anti-inflammatory", "omega-3", "superfood"]
        )
    }

    private func createLongevityBreakfastBowl() -> Recipe {
        Recipe(
            name: "Longevity Breakfast Bowl",
            nameDe: "Langlebigkeits-Frühstücksbowl",
            description: "Start your day with maximum longevity compounds",
            mealType: .breakfast,
            dietTypes: [.vegetarian, .blueZone, .antiInflammatory],
            difficulty: .beginner,
            servings: 1,
            prepTimeMinutes: 10,
            cookTimeMinutes: 5,
            ingredients: [
                Ingredient(name: "Steel-Cut Oats", nameDe: "Stahlgeschnittene Haferflocken", amount: 50, unit: "g",
                          category: .grain, longevityCompounds: ["Beta-glucan"]),
                Ingredient(name: "Wild Blueberries", nameDe: "Wilde Blaubeeren", amount: 80, unit: "g",
                          category: .fruit, longevityCompounds: ["Anthocyanins", "Pterostilbene"]),
                Ingredient(name: "Walnuts", nameDe: "Walnüsse", amount: 15, unit: "g",
                          category: .nut, longevityCompounds: ["Omega-3"]),
                Ingredient(name: "Ground Flaxseed", nameDe: "Gemahlene Leinsamen", amount: 1, unit: "tbsp",
                          category: .nut, longevityCompounds: ["Omega-3", "Lignans"]),
                Ingredient(name: "Cinnamon", nameDe: "Zimt", amount: 0.5, unit: "tsp",
                          category: .spice, longevityCompounds: ["Cinnamaldehyde"]),
                Ingredient(name: "Greek Yogurt", nameDe: "Griechischer Joghurt", amount: 100, unit: "g",
                          category: .dairy, longevityCompounds: ["Probiotics"], isOptional: true)
            ],
            nutrition: NutritionInfo(calories: 380, protein: 12, carbohydrates: 45, fat: 18, fiber: 10,
                                    omega3: 2.0),
            longevityCompounds: ["Beta-glucan", "Anthocyanins", "Omega-3", "Lignans"],
            hallmarksOfAgingTargeted: ["Gut Microbiome", "Brain Health", "Cardiovascular"],
            hrvBenefit: 0.75,
            tags: ["breakfast", "oats", "berries", "quick", "fiber-rich"]
        )
    }

    // MARK: - Recipe Generation

    /// Generate recipe recommendations based on HRV and health goals
    public func generateRecommendations(
        hrvCoherence: Double,
        targetHallmarks: [String] = [],
        mealType: MealType? = nil,
        maxPrepTime: Int? = nil
    ) -> [Recipe] {
        var filtered = recipes

        // Filter by diet type
        filtered = filtered.filter { recipe in
            recipe.dietTypes.contains(preferredDietType) || preferredDietType == .standard
        }

        // Filter by meal type
        if let mealType = mealType {
            filtered = filtered.filter { $0.mealType == mealType }
        }

        // Filter by prep time
        if let maxTime = maxPrepTime {
            filtered = filtered.filter { $0.totalTimeMinutes <= maxTime }
        }

        // Filter by allergies
        filtered = filtered.filter { recipe in
            !recipe.ingredients.contains { allergies.contains($0.name) }
        }

        // Sort by HRV benefit and longevity score
        filtered.sort { a, b in
            let scoreA = a.hrvBenefit * 0.5 + a.nutrition.longevityScore / 100 * 0.5
            let scoreB = b.hrvBenefit * 0.5 + b.nutrition.longevityScore / 100 * 0.5
            return scoreA > scoreB
        }

        // Boost recipes targeting specific hallmarks
        if !targetHallmarks.isEmpty {
            filtered.sort { a, b in
                let matchA = Set(a.hallmarksOfAgingTargeted).intersection(Set(targetHallmarks)).count
                let matchB = Set(b.hallmarksOfAgingTargeted).intersection(Set(targetHallmarks)).count
                return matchA > matchB
            }
        }

        return Array(filtered.prefix(5))
    }

    // MARK: - Meal Planning

    /// Generate a weekly meal plan
    public func generateWeeklyMealPlan(
        startDate: Date = Date(),
        dietType: DietType = .blueZone,
        targetCalories: Double = 2000
    ) -> MealPlan {
        var days: [MealPlanDay] = []

        for dayOffset in 0..<7 {
            guard let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }

            let breakfast = recipes.filter { $0.mealType == .breakfast }.randomElement()
            let lunch = recipes.filter { $0.mealType == .lunch || $0.mealType == .salad || $0.mealType == .soup }.randomElement()
            let dinner = recipes.filter { $0.mealType == .dinner || $0.mealType == .mainCourse }.randomElement()
            let snack = recipes.filter { $0.mealType == .snack || $0.mealType == .drink }.randomElement()

            let day = MealPlanDay(
                date: date,
                breakfast: breakfast,
                lunch: lunch,
                dinner: dinner,
                snacks: snack.map { [$0] } ?? []
            )
            days.append(day)
        }

        let plan = MealPlan(
            name: "Blue Zone Wochenplan",
            startDate: startDate,
            endDate: Calendar.current.date(byAdding: .day, value: 6, to: startDate) ?? startDate,
            days: days,
            dietType: dietType,
            targetCalories: targetCalories
        )

        currentMealPlan = plan
        generateShoppingList(from: plan)

        return plan
    }

    // MARK: - Shopping List Generation

    /// Generate shopping list from meal plan
    public func generateShoppingList(from mealPlan: MealPlan) {
        var ingredientMap: [String: ShoppingItem] = [:]

        for day in mealPlan.days {
            let allRecipes = [day.breakfast, day.lunch, day.dinner].compactMap { $0 } + day.snacks

            for recipe in allRecipes {
                for ingredient in recipe.ingredients where !ingredient.isOptional {
                    let key = ingredient.name.lowercased()

                    if var existing = ingredientMap[key] {
                        existing.amount += ingredient.amount
                        ingredientMap[key] = existing
                    } else {
                        ingredientMap[key] = ShoppingItem(
                            name: ingredient.nameDe,
                            amount: ingredient.amount,
                            unit: ingredient.unit,
                            category: ingredient.category
                        )
                    }
                }
            }
        }

        currentShoppingList = ShoppingList(
            name: "Einkaufsliste für \(mealPlan.name)",
            items: Array(ingredientMap.values).sorted { $0.category.rawValue < $1.category.rawValue }
        )
    }

    /// Generate shopping list from single recipe
    public func generateShoppingList(from recipe: Recipe, servings: Int? = nil) -> ShoppingList {
        let multiplier = Double(servings ?? recipe.servings) / Double(recipe.servings)

        let items = recipe.ingredients.filter { !$0.isOptional }.map { ingredient in
            ShoppingItem(
                name: ingredient.nameDe,
                amount: ingredient.amount * multiplier,
                unit: ingredient.unit,
                category: ingredient.category
            )
        }

        return ShoppingList(
            name: "Einkaufsliste für \(recipe.nameDe)",
            items: items
        )
    }

    // MARK: - Recipe Search

    /// Search recipes by query
    public func searchRecipes(query: String) -> [Recipe] {
        let lowercased = query.lowercased()
        return recipes.filter { recipe in
            recipe.name.lowercased().contains(lowercased) ||
            recipe.nameDe.lowercased().contains(lowercased) ||
            recipe.tags.contains { $0.lowercased().contains(lowercased) } ||
            recipe.longevityCompounds.contains { $0.lowercased().contains(lowercased) } ||
            recipe.ingredients.contains { $0.name.lowercased().contains(lowercased) }
        }
    }

    /// Filter recipes by compound
    public func recipesWithCompound(_ compound: String) -> [Recipe] {
        recipes.filter { $0.longevityCompounds.contains(compound) }
    }

    /// Filter recipes by Blue Zone origin
    public func recipesFromBlueZone(_ zone: String) -> [Recipe] {
        recipes.filter { $0.blueZoneOrigin?.contains(zone) == true }
    }
}

// MARK: - Ingredient Extension

private extension Ingredient {
    init(name: String, nameDe: String, amount: Double, unit: String,
         category: IngredientCategory, longevityCompounds: [String] = [],
         tips: [String] = [], substitutes: [String] = [],
         isOptional: Bool = false, blueZoneOrigin: String? = nil) {
        self.init(
            name: name,
            nameDe: nameDe,
            amount: amount,
            unit: unit,
            category: category,
            longevityCompounds: longevityCompounds,
            isOptional: isOptional,
            substitutes: substitutes
        )
    }
}

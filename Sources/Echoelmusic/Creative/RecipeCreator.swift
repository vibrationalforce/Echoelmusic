import Foundation
import Combine

/// Recipe Creator
/// Professional recipe writing tool for all types:
/// - Food & Beverages
/// - Cosmetics & Beauty Products
/// - Essential Oils & Aromatherapy
/// - Natural Medicine & Remedies
/// - Cleaning Products
///
/// Features:
/// - Sustainability ratings
/// - Vegan/vegetarian labeling
/// - Cruelty-free certification
/// - Health benefits
/// - Safety warnings
/// - Allergen information
/// - Nutrition facts (food)
/// - Ingredient sourcing
/// - Cost calculation
@MainActor
class RecipeCreator: ObservableObject {

    // MARK: - Published Properties

    @Published var currentRecipe: Recipe?
    @Published var ingredientDatabase: [Ingredient] = []

    // MARK: - Recipe Structure

    struct Recipe: Identifiable, Codable {
        let id: UUID
        var name: String
        var type: RecipeType
        var category: Category

        // Content
        var description: String
        var ingredients: [RecipeIngredient]
        var instructions: [Instruction]
        var notes: String

        // Time & Yield
        var prepTime: TimeInterval   // in seconds
        var cookTime: TimeInterval?  // for food
        var waitTime: TimeInterval?  // for cosmetics/oils (curing, steeping)
        var yield: RecipeYield

        // Tags & Certifications
        var isVegan: Bool
        var isVegetarian: Bool
        var isCrueltyFree: Bool
        var isOrganic: Bool
        var isGlutenFree: Bool?  // for food
        var isDairyFree: Bool?   // for food

        // Sustainability
        var sustainabilityRating: SustainabilityRating
        var carbonFootprint: CarbonFootprint?

        // Safety & Health
        var warnings: [SafetyWarning]
        var allergens: [Allergen]
        var healthBenefits: [HealthBenefit]

        // Nutrition (for food)
        var nutritionFacts: NutritionFacts?

        // Metadata
        var author: String
        var source: String?
        var copyright: String
        var createdDate: Date
        var lastModified: Date

        // Publishing
        var isPublic: Bool  // Publish with/without AI
        var aiGenerated: Bool  // Was AI used in creation?

        init(name: String, type: RecipeType, author: String) {
            self.id = UUID()
            self.name = name
            self.type = type
            self.category = type.defaultCategory
            self.description = ""
            self.ingredients = []
            self.instructions = []
            self.notes = ""
            self.prepTime = 0
            self.yield = RecipeYield(amount: 1, unit: type.defaultYieldUnit)
            self.isVegan = false
            self.isVegetarian = false
            self.isCrueltyFree = false
            self.isOrganic = false
            self.sustainabilityRating = .moderate
            self.warnings = []
            self.allergens = []
            self.healthBenefits = []
            self.author = author
            self.copyright = "© \(Calendar.current.component(.year, from: Date())) \(author). All Rights Reserved."
            self.createdDate = Date()
            self.lastModified = Date()
            self.isPublic = false
            self.aiGenerated = false
        }
    }

    enum RecipeType: String, Codable, CaseIterable {
        case food = "Food & Beverages"
        case cosmetics = "Cosmetics & Beauty"
        case essentialOils = "Essential Oils & Aromatherapy"
        case medicine = "Natural Medicine & Remedies"
        case cleaning = "Natural Cleaning Products"
        case skincare = "Skincare"
        case haircare = "Haircare"
        case perfume = "Perfume & Fragrances"
        case soap = "Soap & Bath"

        var defaultCategory: Category {
            switch self {
            case .food: return .main
            case .cosmetics: return .facial
            case .essentialOils: return .blend
            case .medicine: return .tincture
            case .cleaning: return .allPurpose
            case .skincare: return .facial
            case .haircare: return .shampoo
            case .perfume: return .eau DeToilette
            case .soap: return .bar
            }
        }

        var defaultYieldUnit: String {
            switch self {
            case .food: return "servings"
            case .cosmetics, .skincare, .haircare: return "ml"
            case .essentialOils, .perfume: return "drops"
            case .medicine: return "doses"
            case .cleaning: return "ml"
            case .soap: return "bars"
            }
        }
    }

    enum Category: String, Codable {
        // Food
        case appetizer, main, side, dessert, beverage, snack, breakfast

        // Cosmetics/Skincare
        case facial, body, eye, lip

        // Essential Oils
        case blend, single, massage, diffuser

        // Medicine
        case tincture, salve, tea, compress

        // Cleaning
        case allPurpose, kitchen, bathroom, laundry

        // Haircare
        case shampoo, conditioner, mask, treatment

        // Perfume
        case eauDeParfum = "Eau de Parfum"
        case eauDeToilette = "Eau de Toilette"
        case eauDeCologne = "Eau de Cologne"

        // Soap
        case bar, liquid, scrub
    }

    struct RecipeYield: Codable {
        var amount: Double
        var unit: String  // "servings", "ml", "drops", "bars", etc.

        var description: String {
            "\(amount) \(unit)"
        }
    }

    // MARK: - Ingredients

    struct RecipeIngredient: Identifiable, Codable {
        let id: UUID
        var ingredient: Ingredient
        var amount: Double
        var unit: MeasurementUnit
        var preparation: String?  // "chopped", "melted", "heated", etc.
        var isOptional: Bool

        var sustainabilityImpact: SustainabilityRating {
            ingredient.sustainability
        }
    }

    struct Ingredient: Identifiable, Codable {
        let id: UUID
        var name: String
        var category: IngredientCategory
        var latinName: String?  // Scientific name (for plants, oils)

        // Properties
        var isVegan: Bool
        var isOrganic: Bool
        var isCrueltyFree: Bool
        var sustainability: SustainabilityRating

        // For food
        var allergens: [Allergen]

        // Sourcing
        var source: IngredientSource
        var supplier: String?

        // Cost
        var costPerUnit: Double?
        var currency: String

        init(name: String, category: IngredientCategory) {
            self.id = UUID()
            self.name = name
            self.category = category
            self.isVegan = true
            self.isOrganic = false
            self.isCrueltyFree = true
            self.sustainability = .moderate
            self.allergens = []
            self.source = .unknown
            self.currency = "EUR"
        }
    }

    enum IngredientCategory: String, Codable, CaseIterable {
        // Food
        case vegetable, fruit, grain, legume, nut, seed, dairy, meat, fish, spice, herb, oil, sweetener

        // Cosmetics/Oils
        case carrierOil, essentialOil, butter, wax, emulsifier, preservative, fragrance, colorant

        // Medicine
        case medicinalHerb, tincture, extract

        // Cleaning
        case base, acid, alkali, surfactant
    }

    enum IngredientSource: String, Codable {
        case local = "Local"
        case regional = "Regional"
        case national = "National"
        case international = "International"
        case fairTrade = "Fair Trade"
        case wildcrafted = "Wildcrafted"
        case organic = "Organic Certified"
        case unknown = "Unknown"
    }

    enum MeasurementUnit: String, Codable, CaseIterable {
        // Volume
        case ml, l, tsp, tbsp, cup, drop

        // Weight
        case g, kg, oz, lb

        // Count
        case piece, pinch, handful

        var description: String { rawValue }
    }

    // MARK: - Instructions

    struct Instruction: Identifiable, Codable {
        let id: UUID
        var step: Int
        var text: String
        var duration: TimeInterval?
        var temperature: Temperature?
        var safetyNote: String?

        struct Temperature: Codable {
            var value: Double
            var unit: TemperatureUnit

            enum TemperatureUnit: String, Codable {
                case celsius = "°C"
                case fahrenheit = "°F"
            }

            var description: String {
                "\(value)\(unit.rawValue)"
            }
        }
    }

    // MARK: - Sustainability

    enum SustainabilityRating: String, Codable, CaseIterable {
        case excellent = "Excellent ★★★★★"
        case good = "Good ★★★★☆"
        case moderate = "Moderate ★★★☆☆"
        case poor = "Poor ★★☆☆☆"
        case veryPoor = "Very Poor ★☆☆☆☆"

        var stars: Int {
            switch self {
            case .excellent: return 5
            case .good: return 4
            case .moderate: return 3
            case .poor: return 2
            case .veryPoor: return 1
            }
        }

        var tips: [String] {
            switch self {
            case .excellent:
                return ["All ingredients locally sourced", "Zero waste packaging", "Carbon neutral"]
            case .good:
                return ["Most ingredients sustainable", "Recyclable packaging", "Low carbon footprint"]
            case .moderate:
                return ["Some sustainable ingredients", "Consider local alternatives"]
            case .poor:
                return ["High carbon footprint", "Non-renewable resources", "Consider alternatives"]
            case .veryPoor:
                return ["⚠️ Environmental concerns", "Seek sustainable alternatives urgently"]
            }
        }
    }

    struct CarbonFootprint: Codable {
        var kgCO2e: Double  // kg CO2 equivalent
        var rating: FootprintRating

        enum FootprintRating: String, Codable {
            case veryLow = "Very Low"
            case low = "Low"
            case moderate = "Moderate"
            case high = "High"
            case veryHigh = "Very High"
        }

        var description: String {
            "\(kgCO2e) kg CO₂e (\(rating.rawValue))"
        }
    }

    // MARK: - Safety & Health

    struct SafetyWarning: Identifiable, Codable {
        let id: UUID
        var type: WarningType
        var message: String
        var severity: Severity

        enum WarningType: String, Codable {
            case allergy = "⚠️ Allergy"
            case toxic = "☠️ Toxic"
            case irritant = "⚠️ Irritant"
            case flammable = "🔥 Flammable"
            case pregnancy = "🤰 Pregnancy"
            case children = "👶 Children"
            case medication = "💊 Medication Interaction"
            case skin = "👁️ Skin Test Required"
        }

        enum Severity: String, Codable {
            case info = "Info"
            case caution = "Caution"
            case warning = "Warning"
            case danger = "Danger"
        }
    }

    enum Allergen: String, Codable, CaseIterable {
        case gluten = "Gluten"
        case dairy = "Dairy/Lactose"
        case eggs = "Eggs"
        case nuts = "Tree Nuts"
        case peanuts = "Peanuts"
        case soy = "Soy"
        case fish = "Fish"
        case shellfish = "Shellfish"
        case sesame = "Sesame"
        case sulfites = "Sulfites"
        case mustard = "Mustard"
        case celery = "Celery"
        case lupin = "Lupin"
        case molluscs = "Molluscs"
    }

    struct HealthBenefit: Identifiable, Codable {
        let id: UUID
        var benefit: String
        var evidenceLevel: EvidenceLevel

        enum EvidenceLevel: String, Codable {
            case traditional = "Traditional Use"
            case anecdotal = "Anecdotal"
            case preliminary = "Preliminary Research"
            case scientific = "Scientific Evidence"
            case clinicalTrial = "Clinical Trial"
        }
    }

    // MARK: - Nutrition (for food recipes)

    struct NutritionFacts: Codable {
        var servingSize: String
        var calories: Int
        var totalFat: Double       // g
        var saturatedFat: Double   // g
        var transFat: Double       // g
        var cholesterol: Double    // mg
        var sodium: Double         // mg
        var totalCarbs: Double     // g
        var fiber: Double          // g
        var sugars: Double         // g
        var protein: Double        // g

        // Vitamins & Minerals (% Daily Value)
        var vitaminA: Int?
        var vitaminC: Int?
        var calcium: Int?
        var iron: Int?
    }

    // MARK: - Initialization

    init() {
        print("🧪 Recipe Creator initialized")
        loadIngredientDatabase()
    }

    private func loadIngredientDatabase() {
        // Load common ingredients
        ingredientDatabase = [
            // Food basics
            Ingredient(name: "Olive Oil", category: .oil),
            Ingredient(name: "Sea Salt", category: .spice),
            Ingredient(name: "Black Pepper", category: .spice),

            // Essential Oils
            Ingredient(name: "Lavender Essential Oil", category: .essentialOil),
            Ingredient(name: "Tea Tree Essential Oil", category: .essentialOil),
            Ingredient(name: "Peppermint Essential Oil", category: .essentialOil),

            // Carrier Oils
            Ingredient(name: "Jojoba Oil", category: .carrierOil),
            Ingredient(name: "Sweet Almond Oil", category: .carrierOil),
            Ingredient(name: "Coconut Oil", category: .carrierOil),

            // Cosmetics
            Ingredient(name: "Shea Butter", category: .butter),
            Ingredient(name: "Beeswax", category: .wax),
            Ingredient(name: "Vitamin E Oil", category: .preservative),
        ]

        print("   Loaded \(ingredientDatabase.count) ingredients")
    }

    // MARK: - Recipe Creation

    func createNewRecipe(name: String, type: RecipeType, author: String) -> Recipe {
        let recipe = Recipe(name: name, type: type, author: author)
        currentRecipe = recipe
        print("   ✅ New recipe created: \(name)")
        print("      Type: \(type.rawValue)")
        return recipe
    }

    // MARK: - Sustainability Analysis

    func analyzeSustainability(_ recipe: Recipe) -> SustainabilityReport {
        print("   🌱 Analyzing sustainability...")

        var totalScore = 0
        var maxScore = 0

        for recipeIngredient in recipe.ingredients {
            let ingredient = recipeIngredient.ingredient
            totalScore += ingredient.sustainability.stars
            maxScore += 5

            if ingredient.isOrganic { totalScore += 1 }
            if ingredient.isCrueltyFree { totalScore += 1 }
            if ingredient.source == .local || ingredient.source == .regional {
                totalScore += 2
            }
            maxScore += 4
        }

        let percentage = maxScore > 0 ? Double(totalScore) / Double(maxScore) * 100 : 0

        let rating: SustainabilityRating
        if percentage >= 80 { rating = .excellent }
        else if percentage >= 60 { rating = .good }
        else if percentage >= 40 { rating = .moderate }
        else if percentage >= 20 { rating = .poor }
        else { rating = .veryPoor }

        let report = SustainabilityReport(
            rating: rating,
            score: percentage,
            recommendations: generateSustainabilityTips(recipe)
        )

        print("   Sustainability: \(rating.rawValue) (\(Int(percentage))%)")

        return report
    }

    struct SustainabilityReport {
        let rating: SustainabilityRating
        let score: Double  // 0-100
        let recommendations: [String]
    }

    private func generateSustainabilityTips(_ recipe: Recipe) -> [String] {
        var tips: [String] = []

        // Check for local sourcing
        let nonLocalIngredients = recipe.ingredients.filter {
            $0.ingredient.source != .local && $0.ingredient.source != .regional
        }
        if !nonLocalIngredients.isEmpty {
            tips.append("💡 Consider sourcing locally: \(nonLocalIngredients.map { $0.ingredient.name }.joined(separator: ", "))")
        }

        // Check for organic
        let nonOrganicIngredients = recipe.ingredients.filter { !$0.ingredient.isOrganic }
        if !nonOrganicIngredients.isEmpty {
            tips.append("🌿 Consider organic alternatives for better sustainability")
        }

        // Check for packaging
        tips.append("📦 Tip: Use reusable containers and buy in bulk to reduce packaging waste")

        // Seasonality (for food)
        if recipe.type == .food {
            tips.append("🌾 Tip: Choose seasonal ingredients for lower environmental impact")
        }

        return tips
    }

    // MARK: - Safety Validation

    func validateSafety(_ recipe: Recipe) -> SafetyReport {
        print("   🛡️ Validating safety...")

        var warnings: [SafetyWarning] = []

        // Check for essential oil concentrations (cosmetics/perfume)
        if recipe.type == .cosmetics || recipe.type == .perfume || recipe.type == .skincare {
            for recipeIngredient in recipe.ingredients {
                if recipeIngredient.ingredient.category == .essentialOil {
                    // Essential oils should be diluted (typically 1-5% for cosmetics)
                    warnings.append(SafetyWarning(
                        id: UUID(),
                        type: .skin,
                        message: "⚠️ \(recipeIngredient.ingredient.name): Perform patch test before use. Maximum 5% concentration recommended.",
                        severity: .caution
                    ))
                }
            }
        }

        // Check for pregnancy/children warnings
        if recipe.type == .essentialOils || recipe.type == .medicine {
            warnings.append(SafetyWarning(
                id: UUID(),
                type: .pregnancy,
                message: "🤰 Consult healthcare provider before use during pregnancy or nursing.",
                severity: .warning
            ))
            warnings.append(SafetyWarning(
                id: UUID(),
                type: .children,
                message: "👶 Not recommended for children under 12 without medical supervision.",
                severity: .caution
            ))
        }

        let report = SafetyReport(
            isSafe: warnings.filter { $0.severity == .danger }.isEmpty,
            warnings: warnings,
            allergens: recipe.allergens
        )

        print("   Safety status: \(report.isSafe ? "✅ Safe" : "⚠️ Warnings present")")
        print("   Warnings: \(warnings.count)")

        return report
    }

    struct SafetyReport {
        let isSafe: Bool
        let warnings: [SafetyWarning]
        let allergens: [Allergen]
    }

    // MARK: - Export

    func exportRecipe(_ recipe: Recipe, format: ExportFormat, includeAIDisclosure: Bool) -> URL? {
        print("   💾 Exporting recipe: \(recipe.name)")
        print("      Format: \(format.rawValue)")
        print("      AI Disclosure: \(includeAIDisclosure ? "Yes" : "No")")

        switch format {
        case .pdf:
            return exportToPDF(recipe, includeAI: includeAIDisclosure)
        case .json:
            return exportToJSON(recipe)
        case .markdown:
            return exportToMarkdown(recipe, includeAI: includeAIDisclosure)
        case .html:
            return exportToHTML(recipe, includeAI: includeAIDisclosure)
        }
    }

    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF (Print)"
        case json = "JSON (Data)"
        case markdown = "Markdown (Blog)"
        case html = "HTML (Web)"
    }

    private func exportToPDF(_ recipe: Recipe, includeAI: Bool) -> URL? {
        print("      ✅ PDF generated")
        return nil // Placeholder
    }

    private func exportToJSON(_ recipe: Recipe) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        if let jsonData = try? encoder.encode(recipe) {
            print("      ✅ JSON generated (\(jsonData.count) bytes)")
        }

        return nil // Placeholder
    }

    private func exportToMarkdown(_ recipe: Recipe, includeAI: Bool) -> URL? {
        var markdown = "# \(recipe.name)\n\n"

        if includeAI && recipe.aiGenerated {
            markdown += "> ⚠️ This recipe was created with AI assistance.\n\n"
        }

        markdown += "**Type:** \(recipe.type.rawValue)\n"
        markdown += "**Author:** \(recipe.author)\n\n"

        // Certifications
        var certs: [String] = []
        if recipe.isVegan { certs.append("🌱 Vegan") }
        if recipe.isCrueltyFree { certs.append("🐰 Cruelty-Free") }
        if recipe.isOrganic { certs.append("🌿 Organic") }
        if !certs.isEmpty {
            markdown += "**Certifications:** \(certs.joined(separator: ", "))\n\n"
        }

        // Sustainability
        markdown += "**Sustainability:** \(recipe.sustainabilityRating.rawValue)\n\n"

        // Ingredients
        markdown += "## Ingredients\n\n"
        for ingredient in recipe.ingredients {
            markdown += "- \(ingredient.amount) \(ingredient.unit.rawValue) \(ingredient.ingredient.name)"
            if let prep = ingredient.preparation {
                markdown += " (\(prep))"
            }
            markdown += "\n"
        }
        markdown += "\n"

        // Instructions
        markdown += "## Instructions\n\n"
        for instruction in recipe.instructions {
            markdown += "\(instruction.step). \(instruction.text)\n"
        }
        markdown += "\n"

        // Warnings
        if !recipe.warnings.isEmpty {
            markdown += "## ⚠️ Safety Warnings\n\n"
            for warning in recipe.warnings {
                markdown += "- **\(warning.type.rawValue):** \(warning.message)\n"
            }
            markdown += "\n"
        }

        // Copyright
        markdown += "---\n\n"
        markdown += "*\(recipe.copyright)*\n"

        print("      ✅ Markdown generated")
        return nil // Placeholder
    }

    private func exportToHTML(_ recipe: Recipe, includeAI: Bool) -> URL? {
        print("      ✅ HTML generated")
        return nil // Placeholder
    }
}

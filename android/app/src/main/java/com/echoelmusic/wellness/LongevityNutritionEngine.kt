/**
 * LongevityNutritionEngine.kt
 *
 * Scientific longevity nutrition system based on:
 * - 9 Hallmarks of Aging (López-Otín et al., Cell 2013)
 * - Blue Zones Research (Dan Buettner)
 * - David Sinclair's Longevity Protocols
 * - HeartMath Institute HRV Research
 *
 * Phase 10000 ULTIMATE RALPH WIGGUM LAMBDA MODE - 100% Feature Parity
 *
 * DISCLAIMER: This is NOT medical advice. Consult healthcare professionals
 * before making any changes to your diet or supplement regimen.
 */
package com.echoelmusic.wellness

import kotlinx.coroutines.flow.*
import kotlin.math.*

// ============================================================================
// HALLMARKS OF AGING (López-Otín et al., Cell 2013)
// ============================================================================

enum class HallmarkOfAging(
    val displayName: String,
    val description: String,
    val primaryInterventions: List<String>
) {
    GENOMIC_INSTABILITY(
        "Genomic Instability",
        "DNA damage accumulation over time",
        listOf("NMN", "Resveratrol", "DNA repair support")
    ),
    TELOMERE_ATTRITION(
        "Telomere Attrition",
        "Shortening of protective chromosome caps",
        listOf("TA-65", "Astragalus", "Omega-3")
    ),
    EPIGENETIC_ALTERATIONS(
        "Epigenetic Alterations",
        "Changes in gene expression patterns",
        listOf("Alpha-ketoglutarate", "Spermidine", "NAD+ precursors")
    ),
    LOSS_OF_PROTEOSTASIS(
        "Loss of Proteostasis",
        "Protein folding dysfunction",
        listOf("Fasting", "Spermidine", "Heat shock proteins")
    ),
    DEREGULATED_NUTRIENT_SENSING(
        "Deregulated Nutrient Sensing",
        "Impaired metabolic pathways (mTOR, AMPK, Sirtuins)",
        listOf("Metformin (Rx)", "Berberine", "Fasting", "Exercise")
    ),
    MITOCHONDRIAL_DYSFUNCTION(
        "Mitochondrial Dysfunction",
        "Reduced cellular energy production",
        listOf("CoQ10", "PQQ", "NMN", "Urolithin A")
    ),
    CELLULAR_SENESCENCE(
        "Cellular Senescence",
        "Accumulation of damaged, non-dividing cells",
        listOf("Fisetin", "Quercetin", "Dasatinib (Rx)")
    ),
    STEM_CELL_EXHAUSTION(
        "Stem Cell Exhaustion",
        "Reduced regenerative capacity",
        listOf("Fasting", "Exercise", "NAD+ precursors")
    ),
    ALTERED_INTERCELLULAR_COMMUNICATION(
        "Altered Intercellular Communication",
        "Chronic inflammation and signaling dysfunction",
        listOf("Omega-3", "Curcumin", "Sulforaphane", "Anti-inflammatory diet")
    )
}

// ============================================================================
// LONGEVITY COMPOUNDS
// ============================================================================

enum class EvidenceLevel(val displayName: String, val weight: Float) {
    HUMAN_RCT("Human RCT", 1.0f),           // Randomized controlled trials in humans
    HUMAN_OBSERVATIONAL("Human Observational", 0.7f),
    ANIMAL_STUDY("Animal Study", 0.4f),
    IN_VITRO("In Vitro", 0.2f),
    TRADITIONAL("Traditional Use", 0.1f)
}

enum class CompoundCategory {
    SIRTUIN_ACTIVATOR,
    SENOLYTIC,
    NAD_PRECURSOR,
    MITOCHONDRIAL,
    EPIGENETIC,
    ANTI_INFLAMMATORY,
    AUTOPHAGY_INDUCER,
    TELOMERE_SUPPORT,
    METABOLIC,
    ANTIOXIDANT
}

data class LongevityCompound(
    val name: String,
    val category: CompoundCategory,
    val hallmarksTargeted: List<HallmarkOfAging>,
    val evidenceLevel: EvidenceLevel,
    val typicalDose: String,
    val timing: String,
    val notes: String,
    val contraindications: List<String> = emptyList(),
    val synergies: List<String> = emptyList()
)

object LongevityCompounds {
    val all = listOf(
        LongevityCompound(
            name = "NMN (Nicotinamide Mononucleotide)",
            category = CompoundCategory.NAD_PRECURSOR,
            hallmarksTargeted = listOf(
                HallmarkOfAging.GENOMIC_INSTABILITY,
                HallmarkOfAging.MITOCHONDRIAL_DYSFUNCTION,
                HallmarkOfAging.STEM_CELL_EXHAUSTION
            ),
            evidenceLevel = EvidenceLevel.HUMAN_RCT,
            typicalDose = "250-1000mg",
            timing = "Morning, sublingual or oral",
            notes = "NAD+ precursor. David Sinclair's primary supplement.",
            synergies = listOf("Resveratrol", "TMG")
        ),
        LongevityCompound(
            name = "Resveratrol",
            category = CompoundCategory.SIRTUIN_ACTIVATOR,
            hallmarksTargeted = listOf(
                HallmarkOfAging.GENOMIC_INSTABILITY,
                HallmarkOfAging.EPIGENETIC_ALTERATIONS
            ),
            evidenceLevel = EvidenceLevel.HUMAN_OBSERVATIONAL,
            typicalDose = "500-1000mg",
            timing = "Morning with fat (yogurt, olive oil)",
            notes = "SIRT1 activator. Better absorbed with fat.",
            synergies = listOf("NMN", "Quercetin")
        ),
        LongevityCompound(
            name = "Fisetin",
            category = CompoundCategory.SENOLYTIC,
            hallmarksTargeted = listOf(HallmarkOfAging.CELLULAR_SENESCENCE),
            evidenceLevel = EvidenceLevel.ANIMAL_STUDY,
            typicalDose = "100-500mg",
            timing = "Intermittent dosing (2-3 days monthly)",
            notes = "Most potent natural senolytic. Found in strawberries.",
            contraindications = listOf("Blood thinners")
        ),
        LongevityCompound(
            name = "Quercetin",
            category = CompoundCategory.SENOLYTIC,
            hallmarksTargeted = listOf(
                HallmarkOfAging.CELLULAR_SENESCENCE,
                HallmarkOfAging.ALTERED_INTERCELLULAR_COMMUNICATION
            ),
            evidenceLevel = EvidenceLevel.HUMAN_OBSERVATIONAL,
            typicalDose = "500-1000mg",
            timing = "Intermittent dosing with Fisetin",
            notes = "Senolytic when combined. Found in onions, apples.",
            synergies = listOf("Fisetin", "Vitamin C")
        ),
        LongevityCompound(
            name = "Spermidine",
            category = CompoundCategory.AUTOPHAGY_INDUCER,
            hallmarksTargeted = listOf(
                HallmarkOfAging.LOSS_OF_PROTEOSTASIS,
                HallmarkOfAging.EPIGENETIC_ALTERATIONS
            ),
            evidenceLevel = EvidenceLevel.HUMAN_OBSERVATIONAL,
            typicalDose = "1-5mg",
            timing = "Morning",
            notes = "Autophagy inducer. Found in wheat germ, aged cheese.",
            synergies = listOf("Fasting")
        ),
        LongevityCompound(
            name = "Sulforaphane",
            category = CompoundCategory.EPIGENETIC,
            hallmarksTargeted = listOf(
                HallmarkOfAging.EPIGENETIC_ALTERATIONS,
                HallmarkOfAging.ALTERED_INTERCELLULAR_COMMUNICATION
            ),
            evidenceLevel = EvidenceLevel.HUMAN_RCT,
            typicalDose = "10-50mg (or broccoli sprouts)",
            timing = "Morning",
            notes = "NRF2 activator. Best from broccoli sprouts.",
            synergies = listOf("Myrosinase (from mustard seed)")
        ),
        LongevityCompound(
            name = "CoQ10 (Ubiquinol)",
            category = CompoundCategory.MITOCHONDRIAL,
            hallmarksTargeted = listOf(HallmarkOfAging.MITOCHONDRIAL_DYSFUNCTION),
            evidenceLevel = EvidenceLevel.HUMAN_RCT,
            typicalDose = "100-300mg ubiquinol",
            timing = "With fat-containing meal",
            notes = "Mitochondrial electron carrier. Use ubiquinol form.",
            contraindications = listOf("Blood thinners at high doses")
        ),
        LongevityCompound(
            name = "Urolithin A",
            category = CompoundCategory.MITOCHONDRIAL,
            hallmarksTargeted = listOf(HallmarkOfAging.MITOCHONDRIAL_DYSFUNCTION),
            evidenceLevel = EvidenceLevel.HUMAN_RCT,
            typicalDose = "500-1000mg",
            timing = "Morning",
            notes = "Mitophagy inducer. From pomegranate metabolism."
        ),
        LongevityCompound(
            name = "Alpha-Ketoglutarate (AKG)",
            category = CompoundCategory.EPIGENETIC,
            hallmarksTargeted = listOf(HallmarkOfAging.EPIGENETIC_ALTERATIONS),
            evidenceLevel = EvidenceLevel.ANIMAL_STUDY,
            typicalDose = "300-1000mg",
            timing = "Morning on empty stomach",
            notes = "TET enzyme cofactor. May extend healthspan."
        ),
        LongevityCompound(
            name = "Berberine",
            category = CompoundCategory.METABOLIC,
            hallmarksTargeted = listOf(HallmarkOfAging.DEREGULATED_NUTRIENT_SENSING),
            evidenceLevel = EvidenceLevel.HUMAN_RCT,
            typicalDose = "500mg 2-3x daily",
            timing = "Before meals",
            notes = "AMPK activator. Natural metformin alternative.",
            contraindications = listOf("Diabetes medications", "Pregnancy")
        ),
        LongevityCompound(
            name = "Omega-3 (EPA/DHA)",
            category = CompoundCategory.ANTI_INFLAMMATORY,
            hallmarksTargeted = listOf(
                HallmarkOfAging.ALTERED_INTERCELLULAR_COMMUNICATION,
                HallmarkOfAging.TELOMERE_ATTRITION
            ),
            evidenceLevel = EvidenceLevel.HUMAN_RCT,
            typicalDose = "2-4g EPA+DHA",
            timing = "With meals",
            notes = "Anti-inflammatory. Associated with longer telomeres."
        ),
        LongevityCompound(
            name = "Curcumin",
            category = CompoundCategory.ANTI_INFLAMMATORY,
            hallmarksTargeted = listOf(HallmarkOfAging.ALTERED_INTERCELLULAR_COMMUNICATION),
            evidenceLevel = EvidenceLevel.HUMAN_RCT,
            typicalDose = "500-1000mg (liposomal or with piperine)",
            timing = "With meals",
            notes = "Potent anti-inflammatory. Needs enhanced absorption."
        ),
        LongevityCompound(
            name = "PQQ (Pyrroloquinoline Quinone)",
            category = CompoundCategory.MITOCHONDRIAL,
            hallmarksTargeted = listOf(HallmarkOfAging.MITOCHONDRIAL_DYSFUNCTION),
            evidenceLevel = EvidenceLevel.HUMAN_OBSERVATIONAL,
            typicalDose = "10-20mg",
            timing = "Morning",
            notes = "Promotes mitochondrial biogenesis.",
            synergies = listOf("CoQ10")
        ),
        LongevityCompound(
            name = "Vitamin D3",
            category = CompoundCategory.METABOLIC,
            hallmarksTargeted = listOf(HallmarkOfAging.ALTERED_INTERCELLULAR_COMMUNICATION),
            evidenceLevel = EvidenceLevel.HUMAN_RCT,
            typicalDose = "2000-5000 IU (test levels)",
            timing = "Morning with fat",
            notes = "Test and optimize levels (50-80 ng/mL target).",
            synergies = listOf("Vitamin K2")
        ),
        LongevityCompound(
            name = "Magnesium (Threonate or Glycinate)",
            category = CompoundCategory.METABOLIC,
            hallmarksTargeted = listOf(HallmarkOfAging.ALTERED_INTERCELLULAR_COMMUNICATION),
            evidenceLevel = EvidenceLevel.HUMAN_RCT,
            typicalDose = "200-400mg elemental",
            timing = "Evening (glycinate) or split dose",
            notes = "Cofactor for 300+ enzymes. Most people deficient."
        )
    )
}

// ============================================================================
// BLUE ZONES RESEARCH
// ============================================================================

enum class BlueZone(
    val displayName: String,
    val region: String,
    val averageLifeExpectancy: Int,
    val keyFoods: List<String>,
    val lifestylePrinciples: List<String>
) {
    OKINAWA(
        "Okinawa",
        "Japan",
        84,
        listOf("Sweet potatoes", "Tofu", "Bitter melon", "Turmeric", "Green tea", "Seaweed"),
        listOf("Hara hachi bu (80% full)", "Ikigai (purpose)", "Moai (social circles)")
    ),
    SARDINIA(
        "Sardinia",
        "Italy",
        83,
        listOf("Whole grain bread", "Beans", "Goat's milk", "Red wine", "Olive oil", "Fennel"),
        listOf("Daily walking", "Family first", "Social connection", "Moderate wine")
    ),
    NICOYA(
        "Nicoya Peninsula",
        "Costa Rica",
        85,
        listOf("Black beans", "Squash", "Corn tortillas", "Papaya", "Eggs", "Plantains"),
        listOf("Plan de vida (life plan)", "Faith community", "Family focus", "Light dinner")
    ),
    IKARIA(
        "Ikaria",
        "Greece",
        81,
        listOf("Wild greens", "Potatoes", "Goat's milk", "Honey", "Legumes", "Herbal teas"),
        listOf("Afternoon naps", "Mediterranean diet", "Social eating", "Herbal medicine")
    ),
    LOMA_LINDA(
        "Loma Linda",
        "California, USA",
        86,
        listOf("Nuts", "Beans", "Oatmeal", "Whole wheat bread", "Avocados", "Water"),
        listOf("Seventh-day Adventist lifestyle", "Vegetarian diet", "Sabbath rest", "Community")
    )
}

// Power 9 Principles (Dan Buettner)
enum class Power9Principle(
    val displayName: String,
    val description: String,
    val coherenceImpact: Float // How it affects HRV coherence
) {
    MOVE_NATURALLY(
        "Move Naturally",
        "Natural movement throughout the day, not gym workouts",
        0.15f
    ),
    PURPOSE(
        "Purpose (Ikigai/Plan de Vida)",
        "Knowing why you wake up in the morning",
        0.20f
    ),
    DOWNSHIFT(
        "Downshift",
        "Daily routines to reverse stress-induced inflammation",
        0.25f // Highest coherence impact
    ),
    EIGHTY_PERCENT_RULE(
        "80% Rule",
        "Stop eating when 80% full (Hara Hachi Bu)",
        0.10f
    ),
    PLANT_SLANT(
        "Plant Slant",
        "Diet mostly plant-based, beans cornerstone",
        0.12f
    ),
    WINE_AT_5(
        "Wine at 5",
        "Moderate alcohol (1-2 glasses) with friends/food",
        0.08f
    ),
    BELONG(
        "Belong",
        "Belonging to a faith-based community",
        0.18f
    ),
    LOVED_ONES_FIRST(
        "Loved Ones First",
        "Investing in family and keeping aging parents nearby",
        0.20f
    ),
    RIGHT_TRIBE(
        "Right Tribe",
        "Social circles that support healthy behaviors",
        0.22f
    )
}

// ============================================================================
// BLUE ZONE FOODS DATABASE
// ============================================================================

enum class FoodCategory {
    CRUCIFEROUS,
    LEGUMES,
    BERRIES,
    FERMENTED,
    ALLIUMS,
    NUTS_SEEDS,
    WHOLE_GRAINS,
    LEAFY_GREENS,
    FATTY_FISH,
    OLIVE_OIL,
    SPICES,
    TEA
}

data class BlueZoneFood(
    val name: String,
    val category: FoodCategory,
    val origins: List<BlueZone>,
    val keyCompounds: List<String>,
    val healthBenefits: List<String>,
    val servingSuggestion: String
)

object BlueZoneFoods {
    val all = listOf(
        BlueZoneFood(
            "Black Beans",
            FoodCategory.LEGUMES,
            listOf(BlueZone.NICOYA, BlueZone.LOMA_LINDA),
            listOf("Fiber", "Protein", "Anthocyanins", "Resistant starch"),
            listOf("Gut health", "Blood sugar control", "Heart health"),
            "1 cup daily"
        ),
        BlueZoneFood(
            "Sweet Potatoes (Purple)",
            FoodCategory.WHOLE_GRAINS,
            listOf(BlueZone.OKINAWA),
            listOf("Anthocyanins", "Beta-carotene", "Fiber", "Vitamin C"),
            listOf("Antioxidant", "Anti-inflammatory", "Gut health"),
            "1/2-1 cup daily"
        ),
        BlueZoneFood(
            "Walnuts",
            FoodCategory.NUTS_SEEDS,
            listOf(BlueZone.LOMA_LINDA),
            listOf("Omega-3 ALA", "Polyphenols", "Melatonin"),
            listOf("Brain health", "Heart health", "Longevity"),
            "Handful daily (1 oz)"
        ),
        BlueZoneFood(
            "Olive Oil (Extra Virgin)",
            FoodCategory.OLIVE_OIL,
            listOf(BlueZone.IKARIA, BlueZone.SARDINIA),
            listOf("Oleic acid", "Polyphenols", "Oleocanthal"),
            listOf("Anti-inflammatory", "Heart health", "Brain protection"),
            "2-4 tablespoons daily"
        ),
        BlueZoneFood(
            "Wild Greens",
            FoodCategory.LEAFY_GREENS,
            listOf(BlueZone.IKARIA),
            listOf("Chlorophyll", "Fiber", "Magnesium", "Folate"),
            listOf("Detoxification", "Gut health", "Micronutrients"),
            "2+ cups daily"
        ),
        BlueZoneFood(
            "Tofu",
            FoodCategory.LEGUMES,
            listOf(BlueZone.OKINAWA),
            listOf("Isoflavones", "Protein", "Calcium"),
            listOf("Hormone balance", "Heart health", "Bone health"),
            "3-4 oz daily"
        ),
        BlueZoneFood(
            "Sourdough Bread",
            FoodCategory.WHOLE_GRAINS,
            listOf(BlueZone.SARDINIA),
            listOf("Fiber", "B vitamins", "Prebiotics", "Lower glycemic"),
            listOf("Gut health", "Blood sugar", "Mineral absorption"),
            "1-2 slices daily"
        ),
        BlueZoneFood(
            "Goat's Milk/Cheese",
            FoodCategory.FERMENTED,
            listOf(BlueZone.SARDINIA, BlueZone.IKARIA),
            listOf("A2 protein", "Probiotics", "Calcium", "Medium chain fats"),
            listOf("Digestibility", "Gut health", "Anti-inflammatory"),
            "Small amount daily"
        ),
        BlueZoneFood(
            "Bitter Melon (Goya)",
            FoodCategory.CRUCIFEROUS,
            listOf(BlueZone.OKINAWA),
            listOf("Charantin", "Polypeptide-p", "Vicine"),
            listOf("Blood sugar control", "Antioxidant", "Liver health"),
            "1/2 cup several times weekly"
        ),
        BlueZoneFood(
            "Turmeric",
            FoodCategory.SPICES,
            listOf(BlueZone.OKINAWA),
            listOf("Curcumin", "Essential oils"),
            listOf("Anti-inflammatory", "Brain health", "Joint health"),
            "1/2-1 tsp daily with black pepper"
        ),
        BlueZoneFood(
            "Green Tea",
            FoodCategory.TEA,
            listOf(BlueZone.OKINAWA),
            listOf("EGCG", "L-theanine", "Catechins"),
            listOf("Antioxidant", "Metabolic", "Cognitive"),
            "2-5 cups daily"
        ),
        BlueZoneFood(
            "Seaweed",
            FoodCategory.LEAFY_GREENS,
            listOf(BlueZone.OKINAWA),
            listOf("Iodine", "Fucoidan", "Alginate"),
            listOf("Thyroid", "Gut health", "Detox"),
            "Small amount daily"
        ),
        BlueZoneFood(
            "Red Wine (Cannonau)",
            FoodCategory.FERMENTED,
            listOf(BlueZone.SARDINIA),
            listOf("Resveratrol", "Polyphenols", "Anthocyanins"),
            listOf("Heart health", "Social connection"),
            "1-2 glasses with dinner (optional)"
        ),
        BlueZoneFood(
            "Honey (Raw)",
            FoodCategory.SPICES,
            listOf(BlueZone.IKARIA),
            listOf("Antioxidants", "Enzymes", "Prebiotics"),
            listOf("Antimicrobial", "Wound healing", "Energy"),
            "1-2 tsp daily"
        ),
        BlueZoneFood(
            "Fava Beans",
            FoodCategory.LEGUMES,
            listOf(BlueZone.SARDINIA, BlueZone.IKARIA),
            listOf("Protein", "Fiber", "Folate", "L-dopa"),
            listOf("Heart health", "Brain health", "Blood sugar"),
            "1/2-1 cup several times weekly"
        )
    )
}

// ============================================================================
// CHRONOTYPE-BASED NUTRITION
// ============================================================================

enum class Chronotype(
    val displayName: String,
    val description: String,
    val optimalEatingWindow: Pair<Int, Int>, // Hours (24h format)
    val fastingRecommendation: String
) {
    LION(
        "Lion (Early Bird)",
        "Early riser, most productive in morning",
        6 to 14,
        "16:8 fasting, dinner before 3pm"
    ),
    BEAR(
        "Bear (Standard)",
        "Follows solar cycle, most common type",
        8 to 18,
        "12:12 or 14:10 fasting"
    ),
    WOLF(
        "Wolf (Night Owl)",
        "Most productive in evening",
        12 to 20,
        "Later eating window, 16:8 possible"
    ),
    DOLPHIN(
        "Dolphin (Light Sleeper)",
        "Sensitive, irregular sleep",
        9 to 17,
        "Gentle 12:12, avoid late eating"
    )
}

// ============================================================================
// BIOLOGICAL AGE CALCULATION
// ============================================================================

/**
 * HRV-based biological age estimation
 * Based on PMC7527628: +10ms SDNN = -20% mortality risk
 */
class BiologicalAgeCalculator {

    data class BiologicalAgeResult(
        val chronologicalAge: Int,
        val estimatedBiologicalAge: Float,
        val ageDelta: Float, // Negative = younger than chronological
        val hrvContribution: Float,
        val lifestyleContribution: Float,
        val confidenceLevel: Float,
        val recommendations: List<String>
    )

    fun calculateBiologicalAge(
        chronologicalAge: Int,
        sdnn: Float,              // SDNN in milliseconds
        rmssd: Float,             // RMSSD in milliseconds
        restingHeartRate: Int,
        exerciseFrequency: Int,   // Days per week
        sleepQuality: Float,      // 0-1
        dietQuality: Float,       // 0-1
        stressLevel: Float        // 0-1 (1 = high stress)
    ): BiologicalAgeResult {

        // Reference SDNN by age (approximate)
        val referenceSDNN = getReferenceSdnnForAge(chronologicalAge)

        // HRV contribution: Each 10ms above reference = ~2 years younger
        val sdnnDelta = sdnn - referenceSDNN
        val hrvYearsDelta = (sdnnDelta / 10f) * -2f

        // Lifestyle factors
        val exerciseBonus = (exerciseFrequency / 7f) * -3f // Up to -3 years
        val sleepBonus = (sleepQuality - 0.5f) * -4f // ±2 years
        val dietBonus = (dietQuality - 0.5f) * -4f // ±2 years
        val stressPenalty = (stressLevel - 0.5f) * 4f // ±2 years

        val lifestyleContribution = exerciseBonus + sleepBonus + dietBonus + stressPenalty

        // Total biological age
        val estimatedBioAge = chronologicalAge + hrvYearsDelta + lifestyleContribution
        val ageDelta = estimatedBioAge - chronologicalAge

        // Generate recommendations
        val recommendations = mutableListOf<String>()

        if (sdnn < referenceSDNN * 0.8f) {
            recommendations.add("Consider HRV training: coherent breathing 6/min")
        }
        if (restingHeartRate > 70) {
            recommendations.add("Cardio exercise could lower resting heart rate")
        }
        if (exerciseFrequency < 3) {
            recommendations.add("Aim for 3+ exercise sessions per week")
        }
        if (sleepQuality < 0.6f) {
            recommendations.add("Prioritize sleep hygiene for better recovery")
        }
        if (stressLevel > 0.6f) {
            recommendations.add("Daily stress management (meditation, nature)")
        }

        return BiologicalAgeResult(
            chronologicalAge = chronologicalAge,
            estimatedBiologicalAge = estimatedBioAge.coerceAtLeast(18f),
            ageDelta = ageDelta,
            hrvContribution = hrvYearsDelta,
            lifestyleContribution = lifestyleContribution,
            confidenceLevel = 0.7f, // Moderate confidence
            recommendations = recommendations
        )
    }

    private fun getReferenceSdnnForAge(age: Int): Float {
        // Approximate SDNN reference values by age
        return when {
            age < 30 -> 145f
            age < 40 -> 130f
            age < 50 -> 115f
            age < 60 -> 100f
            age < 70 -> 85f
            else -> 70f
        }
    }
}

// ============================================================================
// MAIN LONGEVITY ENGINE
// ============================================================================

class LongevityNutritionEngine {

    private val biologicalAgeCalculator = BiologicalAgeCalculator()

    private val _currentHallmarks = MutableStateFlow<List<HallmarkOfAging>>(emptyList())
    val currentHallmarks: StateFlow<List<HallmarkOfAging>> = _currentHallmarks

    private val _recommendedCompounds = MutableStateFlow<List<LongevityCompound>>(emptyList())
    val recommendedCompounds: StateFlow<List<LongevityCompound>> = _recommendedCompounds

    private val _biologicalAge = MutableStateFlow<BiologicalAgeCalculator.BiologicalAgeResult?>(null)
    val biologicalAge: StateFlow<BiologicalAgeCalculator.BiologicalAgeResult?> = _biologicalAge

    // User profile
    private var userChronotype: Chronotype = Chronotype.BEAR
    private var userAge: Int = 35

    /**
     * Update user profile
     */
    fun updateProfile(age: Int, chronotype: Chronotype) {
        userAge = age
        userChronotype = chronotype
        updateRecommendations()
    }

    /**
     * Calculate biological age from HRV data
     */
    fun calculateBiologicalAge(
        sdnn: Float,
        rmssd: Float,
        restingHeartRate: Int,
        exerciseFrequency: Int = 3,
        sleepQuality: Float = 0.7f,
        dietQuality: Float = 0.7f,
        stressLevel: Float = 0.4f
    ) {
        val result = biologicalAgeCalculator.calculateBiologicalAge(
            chronologicalAge = userAge,
            sdnn = sdnn,
            rmssd = rmssd,
            restingHeartRate = restingHeartRate,
            exerciseFrequency = exerciseFrequency,
            sleepQuality = sleepQuality,
            dietQuality = dietQuality,
            stressLevel = stressLevel
        )
        _biologicalAge.value = result
    }

    /**
     * Get compounds for specific hallmarks
     */
    fun getCompoundsForHallmark(hallmark: HallmarkOfAging): List<LongevityCompound> {
        return LongevityCompounds.all.filter { hallmark in it.hallmarksTargeted }
    }

    /**
     * Get foods by Blue Zone
     */
    fun getFoodsForBlueZone(zone: BlueZone): List<BlueZoneFood> {
        return BlueZoneFoods.all.filter { zone in it.origins }
    }

    /**
     * Get eating window for chronotype
     */
    fun getEatingWindow(): Pair<Int, Int> {
        return userChronotype.optimalEatingWindow
    }

    /**
     * Get Power 9 principles with coherence impact
     */
    fun getPower9Principles(): List<Power9Principle> {
        return Power9Principle.values().toList()
    }

    /**
     * Get coherence boost from Power 9 practice
     */
    fun getCoherenceBoostFromPower9(principle: Power9Principle): Float {
        return principle.coherenceImpact
    }

    private fun updateRecommendations() {
        // Age-specific hallmark priorities
        val priorityHallmarks = when {
            userAge < 40 -> listOf(
                HallmarkOfAging.GENOMIC_INSTABILITY,
                HallmarkOfAging.EPIGENETIC_ALTERATIONS
            )
            userAge < 55 -> listOf(
                HallmarkOfAging.MITOCHONDRIAL_DYSFUNCTION,
                HallmarkOfAging.CELLULAR_SENESCENCE,
                HallmarkOfAging.DEREGULATED_NUTRIENT_SENSING
            )
            else -> listOf(
                HallmarkOfAging.CELLULAR_SENESCENCE,
                HallmarkOfAging.STEM_CELL_EXHAUSTION,
                HallmarkOfAging.ALTERED_INTERCELLULAR_COMMUNICATION
            )
        }

        _currentHallmarks.value = priorityHallmarks

        // Get recommended compounds
        _recommendedCompounds.value = LongevityCompounds.all
            .filter { compound ->
                compound.hallmarksTargeted.any { it in priorityHallmarks }
            }
            .sortedByDescending { it.evidenceLevel.weight }
            .take(10)
    }

    companion object {
        const val DISCLAIMER = """
            IMPORTANT HEALTH DISCLAIMER

            This information is for educational purposes only and is NOT medical advice.

            • Consult a healthcare professional before taking any supplements
            • Discuss longevity protocols with your doctor
            • Some compounds may interact with medications
            • Individual responses vary significantly
            • The research is evolving and not all claims are proven

            Echoelmusic is NOT a medical device and does not diagnose, treat,
            cure, or prevent any disease.
        """
    }
}

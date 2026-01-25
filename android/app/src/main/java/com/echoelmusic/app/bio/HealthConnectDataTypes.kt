package com.echoelmusic.app.bio

import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import kotlin.reflect.KClass

/**
 * Echoelmusic Health Connect Data Types
 *
 * Comprehensive categorization of ALL Health Connect data types
 * with helper methods for permissions, display names, and units.
 *
 * Categories:
 * - ACTIVITY: Steps, distance, calories, exercise
 * - BODY: Weight, height, body composition
 * - VITALS: Heart rate, HRV, blood pressure, temperature
 * - SLEEP: Sleep sessions and stages
 * - NUTRITION: Food, water, nutrients
 * - CYCLE: Menstrual cycle tracking
 *
 * @author Echoelmusic Team
 * @version 2.0.0 - Phase 10000
 */

// ══════════════════════════════════════════════════════════════════════════════
// DATA TYPE CATEGORIES
// ══════════════════════════════════════════════════════════════════════════════

/**
 * All Health Connect data type categories
 */
enum class HealthDataCategory(
    val displayName: String,
    val description: String,
    val icon: String  // Material icon name
) {
    ACTIVITY(
        displayName = "Activity & Fitness",
        description = "Steps, distance, calories, exercise sessions",
        icon = "directions_run"
    ),
    BODY(
        displayName = "Body Measurements",
        description = "Weight, height, body composition",
        icon = "monitor_weight"
    ),
    VITALS(
        displayName = "Vitals",
        description = "Heart rate, HRV, blood pressure, temperature",
        icon = "favorite"
    ),
    SLEEP(
        displayName = "Sleep",
        description = "Sleep sessions, stages, and quality",
        icon = "bedtime"
    ),
    NUTRITION(
        displayName = "Nutrition",
        description = "Food intake, hydration, nutrients",
        icon = "restaurant"
    ),
    CYCLE(
        displayName = "Cycle Tracking",
        description = "Menstrual cycle and reproductive health",
        icon = "calendar_month"
    )
}

// ══════════════════════════════════════════════════════════════════════════════
// HEALTH DATA TYPES ENUM
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Comprehensive enum of all Health Connect data types
 */
enum class HealthConnectDataType(
    val recordClass: KClass<out Record>,
    val category: HealthDataCategory,
    val displayName: String,
    val unit: String,
    val description: String,
    val bioReactive: Boolean = false  // True if used for bio-reactive audio
) {
    // ─────────────────────────────────────────────────────────────────────────
    // ACTIVITY & FITNESS
    // ─────────────────────────────────────────────────────────────────────────

    STEPS(
        recordClass = StepsRecord::class,
        category = HealthDataCategory.ACTIVITY,
        displayName = "Steps",
        unit = "steps",
        description = "Number of steps taken"
    ),

    STEPS_CADENCE(
        recordClass = StepsCadenceRecord::class,
        category = HealthDataCategory.ACTIVITY,
        displayName = "Steps Cadence",
        unit = "steps/min",
        description = "Walking or running cadence"
    ),

    DISTANCE(
        recordClass = DistanceRecord::class,
        category = HealthDataCategory.ACTIVITY,
        displayName = "Distance",
        unit = "m",
        description = "Distance traveled"
    ),

    ACTIVE_CALORIES(
        recordClass = ActiveCaloriesBurnedRecord::class,
        category = HealthDataCategory.ACTIVITY,
        displayName = "Active Calories",
        unit = "kcal",
        description = "Calories burned through activity"
    ),

    TOTAL_CALORIES(
        recordClass = TotalCaloriesBurnedRecord::class,
        category = HealthDataCategory.ACTIVITY,
        displayName = "Total Calories",
        unit = "kcal",
        description = "Total calories burned (including BMR)"
    ),

    EXERCISE_SESSION(
        recordClass = ExerciseSessionRecord::class,
        category = HealthDataCategory.ACTIVITY,
        displayName = "Exercise",
        unit = "session",
        description = "Workout session with details"
    ),

    ELEVATION_GAINED(
        recordClass = ElevationGainedRecord::class,
        category = HealthDataCategory.ACTIVITY,
        displayName = "Elevation Gained",
        unit = "m",
        description = "Total elevation climbed"
    ),

    FLOORS_CLIMBED(
        recordClass = FloorsClimbedRecord::class,
        category = HealthDataCategory.ACTIVITY,
        displayName = "Floors Climbed",
        unit = "floors",
        description = "Number of floors climbed"
    ),

    SPEED(
        recordClass = SpeedRecord::class,
        category = HealthDataCategory.ACTIVITY,
        displayName = "Speed",
        unit = "m/s",
        description = "Movement speed"
    ),

    POWER(
        recordClass = PowerRecord::class,
        category = HealthDataCategory.ACTIVITY,
        displayName = "Power",
        unit = "W",
        description = "Power output (cycling, rowing)"
    ),

    CYCLING_CADENCE(
        recordClass = CyclingPedalingCadenceRecord::class,
        category = HealthDataCategory.ACTIVITY,
        displayName = "Cycling Cadence",
        unit = "rpm",
        description = "Pedaling revolutions per minute"
    ),

    WHEELCHAIR_PUSHES(
        recordClass = WheelchairPushesRecord::class,
        category = HealthDataCategory.ACTIVITY,
        displayName = "Wheelchair Pushes",
        unit = "pushes",
        description = "Number of wheelchair pushes"
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // BODY MEASUREMENTS
    // ─────────────────────────────────────────────────────────────────────────

    WEIGHT(
        recordClass = WeightRecord::class,
        category = HealthDataCategory.BODY,
        displayName = "Weight",
        unit = "kg",
        description = "Body weight"
    ),

    HEIGHT(
        recordClass = HeightRecord::class,
        category = HealthDataCategory.BODY,
        displayName = "Height",
        unit = "m",
        description = "Body height"
    ),

    BODY_FAT(
        recordClass = BodyFatRecord::class,
        category = HealthDataCategory.BODY,
        displayName = "Body Fat",
        unit = "%",
        description = "Body fat percentage"
    ),

    BODY_WATER_MASS(
        recordClass = BodyWaterMassRecord::class,
        category = HealthDataCategory.BODY,
        displayName = "Body Water Mass",
        unit = "kg",
        description = "Total body water mass"
    ),

    BONE_MASS(
        recordClass = BoneMassRecord::class,
        category = HealthDataCategory.BODY,
        displayName = "Bone Mass",
        unit = "kg",
        description = "Estimated bone mass"
    ),

    LEAN_BODY_MASS(
        recordClass = LeanBodyMassRecord::class,
        category = HealthDataCategory.BODY,
        displayName = "Lean Body Mass",
        unit = "kg",
        description = "Lean body mass (non-fat)"
    ),

    BASAL_METABOLIC_RATE(
        recordClass = BasalMetabolicRateRecord::class,
        category = HealthDataCategory.BODY,
        displayName = "BMR",
        unit = "kcal/day",
        description = "Basal metabolic rate"
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // VITALS (Core for Bio-Reactive)
    // ─────────────────────────────────────────────────────────────────────────

    HEART_RATE(
        recordClass = HeartRateRecord::class,
        category = HealthDataCategory.VITALS,
        displayName = "Heart Rate",
        unit = "BPM",
        description = "Heart beats per minute",
        bioReactive = true
    ),

    HEART_RATE_VARIABILITY(
        recordClass = HeartRateVariabilityRmssdRecord::class,
        category = HealthDataCategory.VITALS,
        displayName = "HRV (RMSSD)",
        unit = "ms",
        description = "Heart rate variability - key for coherence",
        bioReactive = true
    ),

    RESTING_HEART_RATE(
        recordClass = RestingHeartRateRecord::class,
        category = HealthDataCategory.VITALS,
        displayName = "Resting Heart Rate",
        unit = "BPM",
        description = "Heart rate at rest",
        bioReactive = true
    ),

    RESPIRATORY_RATE(
        recordClass = RespiratoryRateRecord::class,
        category = HealthDataCategory.VITALS,
        displayName = "Respiratory Rate",
        unit = "breaths/min",
        description = "Breathing rate",
        bioReactive = true
    ),

    OXYGEN_SATURATION(
        recordClass = OxygenSaturationRecord::class,
        category = HealthDataCategory.VITALS,
        displayName = "SpO2",
        unit = "%",
        description = "Blood oxygen saturation",
        bioReactive = true
    ),

    BLOOD_PRESSURE(
        recordClass = BloodPressureRecord::class,
        category = HealthDataCategory.VITALS,
        displayName = "Blood Pressure",
        unit = "mmHg",
        description = "Systolic/Diastolic blood pressure"
    ),

    BLOOD_GLUCOSE(
        recordClass = BloodGlucoseRecord::class,
        category = HealthDataCategory.VITALS,
        displayName = "Blood Glucose",
        unit = "mg/dL",
        description = "Blood sugar level"
    ),

    BODY_TEMPERATURE(
        recordClass = BodyTemperatureRecord::class,
        category = HealthDataCategory.VITALS,
        displayName = "Body Temperature",
        unit = "°C",
        description = "Core body temperature"
    ),

    BASAL_BODY_TEMPERATURE(
        recordClass = BasalBodyTemperatureRecord::class,
        category = HealthDataCategory.VITALS,
        displayName = "Basal Body Temp",
        unit = "°C",
        description = "Basal body temperature (morning)"
    ),

    VO2_MAX(
        recordClass = Vo2MaxRecord::class,
        category = HealthDataCategory.VITALS,
        displayName = "VO2 Max",
        unit = "mL/kg/min",
        description = "Maximum oxygen uptake",
        bioReactive = true
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // SLEEP
    // ─────────────────────────────────────────────────────────────────────────

    SLEEP_SESSION(
        recordClass = SleepSessionRecord::class,
        category = HealthDataCategory.SLEEP,
        displayName = "Sleep",
        unit = "hours",
        description = "Sleep session with stages",
        bioReactive = true
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // NUTRITION
    // ─────────────────────────────────────────────────────────────────────────

    NUTRITION(
        recordClass = NutritionRecord::class,
        category = HealthDataCategory.NUTRITION,
        displayName = "Nutrition",
        unit = "meal",
        description = "Food and nutrient intake"
    ),

    HYDRATION(
        recordClass = HydrationRecord::class,
        category = HealthDataCategory.NUTRITION,
        displayName = "Hydration",
        unit = "L",
        description = "Water intake"
    ),

    // ─────────────────────────────────────────────────────────────────────────
    // CYCLE TRACKING
    // ─────────────────────────────────────────────────────────────────────────

    MENSTRUATION_FLOW(
        recordClass = MenstruationFlowRecord::class,
        category = HealthDataCategory.CYCLE,
        displayName = "Menstruation Flow",
        unit = "flow",
        description = "Menstrual flow level"
    ),

    MENSTRUATION_PERIOD(
        recordClass = MenstruationPeriodRecord::class,
        category = HealthDataCategory.CYCLE,
        displayName = "Menstruation Period",
        unit = "period",
        description = "Menstrual period tracking"
    ),

    INTERMENSTRUAL_BLEEDING(
        recordClass = IntermenstrualBleedingRecord::class,
        category = HealthDataCategory.CYCLE,
        displayName = "Intermenstrual Bleeding",
        unit = "event",
        description = "Spotting between periods"
    ),

    CERVICAL_MUCUS(
        recordClass = CervicalMucusRecord::class,
        category = HealthDataCategory.CYCLE,
        displayName = "Cervical Mucus",
        unit = "type",
        description = "Cervical mucus consistency"
    ),

    OVULATION_TEST(
        recordClass = OvulationTestRecord::class,
        category = HealthDataCategory.CYCLE,
        displayName = "Ovulation Test",
        unit = "result",
        description = "Ovulation test result"
    ),

    SEXUAL_ACTIVITY(
        recordClass = SexualActivityRecord::class,
        category = HealthDataCategory.CYCLE,
        displayName = "Sexual Activity",
        unit = "event",
        description = "Sexual activity tracking"
    );

    // ══════════════════════════════════════════════════════════════════════════
    // HELPER METHODS
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Get read permission for this data type
     */
    fun getReadPermission(): String = HealthPermission.getReadPermission(recordClass)

    /**
     * Get write permission for this data type
     */
    fun getWritePermission(): String = HealthPermission.getWritePermission(recordClass)

    /**
     * Get both read and write permissions
     */
    fun getAllPermissions(): Set<String> = setOf(getReadPermission(), getWritePermission())

    companion object {
        /**
         * Get all data types for a category
         */
        fun getByCategory(category: HealthDataCategory): List<HealthConnectDataType> {
            return entries.filter { it.category == category }
        }

        /**
         * Get all bio-reactive data types
         */
        fun getBioReactiveTypes(): List<HealthConnectDataType> {
            return entries.filter { it.bioReactive }
        }

        /**
         * Get all read permissions
         */
        fun getAllReadPermissions(): Set<String> {
            return entries.map { it.getReadPermission() }.toSet()
        }

        /**
         * Get all write permissions
         */
        fun getAllWritePermissions(): Set<String> {
            return entries.map { it.getWritePermission() }.toSet()
        }

        /**
         * Get all permissions (read + write)
         */
        fun getAllPermissions(): Set<String> {
            return getAllReadPermissions() + getAllWritePermissions()
        }

        /**
         * Get bio-reactive read permissions
         */
        fun getBioReactiveReadPermissions(): Set<String> {
            return getBioReactiveTypes().map { it.getReadPermission() }.toSet()
        }

        /**
         * Get bio-reactive write permissions
         */
        fun getBioReactiveWritePermissions(): Set<String> {
            return getBioReactiveTypes().map { it.getWritePermission() }.toSet()
        }

        /**
         * Find data type by record class
         */
        fun fromRecordClass(recordClass: KClass<out Record>): HealthConnectDataType? {
            return entries.find { it.recordClass == recordClass }
        }

        /**
         * Get all record classes
         */
        fun getAllRecordClasses(): Set<KClass<out Record>> {
            return entries.map { it.recordClass }.toSet()
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// EXERCISE TYPES
// ══════════════════════════════════════════════════════════════════════════════

/**
 * All available exercise types in Health Connect
 */
enum class EchoelExerciseType(
    val healthConnectType: Int,
    val displayName: String,
    val bioReactive: Boolean = false,  // If good for bio-reactive sessions
    val description: String
) {
    // Cardio
    WALKING(ExerciseSessionRecord.EXERCISE_TYPE_WALKING, "Walking", false, "Regular walking"),
    RUNNING(ExerciseSessionRecord.EXERCISE_TYPE_RUNNING, "Running", false, "Running/Jogging"),
    CYCLING(ExerciseSessionRecord.EXERCISE_TYPE_BIKING, "Cycling", false, "Bicycle riding"),
    SWIMMING(ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL, "Swimming", false, "Pool swimming"),
    HIKING(ExerciseSessionRecord.EXERCISE_TYPE_HIKING, "Hiking", false, "Trail hiking"),

    // Gym/Strength
    STRENGTH_TRAINING(ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING, "Strength Training", false, "Weight lifting"),
    HIIT(ExerciseSessionRecord.EXERCISE_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING, "HIIT", false, "High-intensity intervals"),
    CALISTHENICS(ExerciseSessionRecord.EXERCISE_TYPE_CALISTHENICS, "Calisthenics", false, "Bodyweight exercises"),

    // Mind-Body (Bio-Reactive Friendly)
    YOGA(ExerciseSessionRecord.EXERCISE_TYPE_YOGA, "Yoga", true, "Yoga practice"),
    PILATES(ExerciseSessionRecord.EXERCISE_TYPE_PILATES, "Pilates", true, "Pilates workout"),
    STRETCHING(ExerciseSessionRecord.EXERCISE_TYPE_STRETCHING, "Stretching", true, "Flexibility exercises"),

    // Dance & Movement
    DANCING(ExerciseSessionRecord.EXERCISE_TYPE_DANCING, "Dancing", true, "Dance workout"),
    TAI_CHI(ExerciseSessionRecord.EXERCISE_TYPE_EXERCISE_CLASS, "Tai Chi", true, "Tai Chi practice"),

    // Echoelmusic-Specific Bio-Reactive Sessions
    MEDITATION(ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT, "Meditation", true, "Guided meditation"),
    BREATHING_EXERCISE(ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT, "Breathing Exercise", true, "Breath work"),
    SOUND_BATH(ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT, "Sound Bath", true, "Immersive sound healing"),
    BIO_REACTIVE_SESSION(ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT, "Bio-Reactive", true, "Bio-reactive audio session"),
    COHERENCE_TRAINING(ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT, "Coherence Training", true, "HRV coherence practice"),

    // Other
    OTHER(ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT, "Other", false, "Other workout type");

    companion object {
        fun getBioReactiveTypes(): List<EchoelExerciseType> {
            return entries.filter { it.bioReactive }
        }

        fun fromHealthConnectType(type: Int): EchoelExerciseType? {
            return entries.find { it.healthConnectType == type }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// SLEEP STAGES
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Sleep stage types
 */
enum class EchoelSleepStage(
    val healthConnectType: Int,
    val displayName: String,
    val description: String
) {
    UNKNOWN(SleepSessionRecord.STAGE_TYPE_UNKNOWN, "Unknown", "Unidentified sleep stage"),
    AWAKE(SleepSessionRecord.STAGE_TYPE_AWAKE, "Awake", "Awake in bed"),
    SLEEPING(SleepSessionRecord.STAGE_TYPE_SLEEPING, "Sleeping", "Generic sleeping"),
    OUT_OF_BED(SleepSessionRecord.STAGE_TYPE_OUT_OF_BED, "Out of Bed", "Out of bed"),
    LIGHT(SleepSessionRecord.STAGE_TYPE_LIGHT, "Light Sleep", "Light/N1+N2 sleep"),
    DEEP(SleepSessionRecord.STAGE_TYPE_DEEP, "Deep Sleep", "Deep/N3 sleep"),
    REM(SleepSessionRecord.STAGE_TYPE_REM, "REM", "Rapid eye movement sleep");

    companion object {
        fun fromHealthConnectType(type: Int): EchoelSleepStage? {
            return entries.find { it.healthConnectType == type }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// BLOOD PRESSURE POSITIONS & LOCATIONS
// ══════════════════════════════════════════════════════════════════════════════

enum class BloodPressureBodyPosition(
    val healthConnectType: Int,
    val displayName: String
) {
    UNKNOWN(BloodPressureRecord.BODY_POSITION_UNKNOWN, "Unknown"),
    STANDING(BloodPressureRecord.BODY_POSITION_STANDING_UP, "Standing"),
    SITTING(BloodPressureRecord.BODY_POSITION_SITTING_DOWN, "Sitting"),
    LYING_DOWN(BloodPressureRecord.BODY_POSITION_LYING_DOWN, "Lying Down"),
    RECLINING(BloodPressureRecord.BODY_POSITION_RECLINING, "Reclining");

    companion object {
        fun fromHealthConnectType(type: Int): BloodPressureBodyPosition? {
            return entries.find { it.healthConnectType == type }
        }
    }
}

enum class BloodPressureMeasurementLocation(
    val healthConnectType: Int,
    val displayName: String
) {
    UNKNOWN(BloodPressureRecord.MEASUREMENT_LOCATION_UNKNOWN, "Unknown"),
    LEFT_WRIST(BloodPressureRecord.MEASUREMENT_LOCATION_LEFT_WRIST, "Left Wrist"),
    RIGHT_WRIST(BloodPressureRecord.MEASUREMENT_LOCATION_RIGHT_WRIST, "Right Wrist"),
    LEFT_UPPER_ARM(BloodPressureRecord.MEASUREMENT_LOCATION_LEFT_UPPER_ARM, "Left Upper Arm"),
    RIGHT_UPPER_ARM(BloodPressureRecord.MEASUREMENT_LOCATION_RIGHT_UPPER_ARM, "Right Upper Arm");

    companion object {
        fun fromHealthConnectType(type: Int): BloodPressureMeasurementLocation? {
            return entries.find { it.healthConnectType == type }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// BODY TEMPERATURE MEASUREMENT LOCATIONS
// ══════════════════════════════════════════════════════════════════════════════

enum class BodyTemperatureMeasurementLocation(
    val healthConnectType: Int,
    val displayName: String
) {
    UNKNOWN(BodyTemperatureRecord.MEASUREMENT_LOCATION_UNKNOWN, "Unknown"),
    ARMPIT(BodyTemperatureRecord.MEASUREMENT_LOCATION_ARMPIT, "Armpit"),
    FINGER(BodyTemperatureRecord.MEASUREMENT_LOCATION_FINGER, "Finger"),
    FOREHEAD(BodyTemperatureRecord.MEASUREMENT_LOCATION_FOREHEAD, "Forehead"),
    MOUTH(BodyTemperatureRecord.MEASUREMENT_LOCATION_MOUTH, "Mouth"),
    RECTUM(BodyTemperatureRecord.MEASUREMENT_LOCATION_RECTUM, "Rectum"),
    TEMPORAL_ARTERY(BodyTemperatureRecord.MEASUREMENT_LOCATION_TEMPORAL_ARTERY, "Temporal Artery"),
    TOE(BodyTemperatureRecord.MEASUREMENT_LOCATION_TOE, "Toe"),
    EAR(BodyTemperatureRecord.MEASUREMENT_LOCATION_EAR, "Ear"),
    WRIST(BodyTemperatureRecord.MEASUREMENT_LOCATION_WRIST, "Wrist"),
    VAGINA(BodyTemperatureRecord.MEASUREMENT_LOCATION_VAGINA, "Vagina");

    companion object {
        fun fromHealthConnectType(type: Int): BodyTemperatureMeasurementLocation? {
            return entries.find { it.healthConnectType == type }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// VO2 MAX MEASUREMENT METHODS
// ══════════════════════════════════════════════════════════════════════════════

enum class Vo2MaxMeasurementMethod(
    val healthConnectType: Int,
    val displayName: String,
    val description: String
) {
    OTHER(Vo2MaxRecord.MEASUREMENT_METHOD_OTHER, "Other", "Other measurement method"),
    METABOLIC_CART(Vo2MaxRecord.MEASUREMENT_METHOD_METABOLIC_CART, "Metabolic Cart", "Lab metabolic cart"),
    HEART_RATE_RATIO(Vo2MaxRecord.MEASUREMENT_METHOD_HEART_RATE_RATIO, "Heart Rate Ratio", "HR-based estimation"),
    COOPER_TEST(Vo2MaxRecord.MEASUREMENT_METHOD_COOPER_TEST, "Cooper Test", "12-minute run test"),
    MULTISTAGE_FITNESS_TEST(Vo2MaxRecord.MEASUREMENT_METHOD_MULTISTAGE_FITNESS_TEST, "Beep Test", "Multistage fitness test"),
    ROCKPORT_FITNESS_TEST(Vo2MaxRecord.MEASUREMENT_METHOD_ROCKPORT_FITNESS_TEST, "Rockport Test", "1-mile walk test");

    companion object {
        fun fromHealthConnectType(type: Int): Vo2MaxMeasurementMethod? {
            return entries.find { it.healthConnectType == type }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MENSTRUATION FLOW TYPES
// ══════════════════════════════════════════════════════════════════════════════

enum class MenstruationFlowType(
    val healthConnectType: Int,
    val displayName: String
) {
    UNKNOWN(MenstruationFlowRecord.FLOW_UNKNOWN, "Unknown"),
    LIGHT(MenstruationFlowRecord.FLOW_LIGHT, "Light"),
    MEDIUM(MenstruationFlowRecord.FLOW_MEDIUM, "Medium"),
    HEAVY(MenstruationFlowRecord.FLOW_HEAVY, "Heavy");

    companion object {
        fun fromHealthConnectType(type: Int): MenstruationFlowType? {
            return entries.find { it.healthConnectType == type }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// OVULATION TEST RESULTS
// ══════════════════════════════════════════════════════════════════════════════

enum class OvulationTestResult(
    val healthConnectType: Int,
    val displayName: String
) {
    UNKNOWN(OvulationTestRecord.RESULT_UNKNOWN, "Unknown"),
    POSITIVE(OvulationTestRecord.RESULT_POSITIVE, "Positive"),
    NEGATIVE(OvulationTestRecord.RESULT_NEGATIVE, "Negative"),
    HIGH(OvulationTestRecord.RESULT_HIGH, "High"),
    INCONCLUSIVE(OvulationTestRecord.RESULT_INCONCLUSIVE, "Inconclusive");

    companion object {
        fun fromHealthConnectType(type: Int): OvulationTestResult? {
            return entries.find { it.healthConnectType == type }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// CERVICAL MUCUS TYPES
// ══════════════════════════════════════════════════════════════════════════════

enum class CervicalMucusAppearance(
    val healthConnectType: Int,
    val displayName: String,
    val description: String
) {
    UNKNOWN(CervicalMucusRecord.APPEARANCE_UNKNOWN, "Unknown", "Unknown appearance"),
    DRY(CervicalMucusRecord.APPEARANCE_DRY, "Dry", "Dry/no mucus"),
    STICKY(CervicalMucusRecord.APPEARANCE_STICKY, "Sticky", "Sticky texture"),
    CREAMY(CervicalMucusRecord.APPEARANCE_CREAMY, "Creamy", "Creamy/lotion-like"),
    WATERY(CervicalMucusRecord.APPEARANCE_WATERY, "Watery", "Thin and watery"),
    EGG_WHITE(CervicalMucusRecord.APPEARANCE_EGG_WHITE, "Egg White", "Stretchy, clear"),
    UNUSUAL(CervicalMucusRecord.APPEARANCE_UNUSUAL, "Unusual", "Unusual appearance");

    companion object {
        fun fromHealthConnectType(type: Int): CervicalMucusAppearance? {
            return entries.find { it.healthConnectType == type }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// BIO-REACTIVE COHERENCE LEVELS
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Coherence levels calculated from HRV data
 * Used for bio-reactive audio synthesis
 */
enum class CoherenceLevel(
    val minScore: Float,
    val maxScore: Float,
    val displayName: String,
    val description: String,
    val audioEffect: String  // How it affects audio
) {
    VERY_LOW(0.0f, 0.2f, "Very Low", "Chaotic/stressed state", "Dissonant, erratic parameters"),
    LOW(0.2f, 0.4f, "Low", "Below baseline coherence", "Filtered, muted tones"),
    MEDIUM(0.4f, 0.6f, "Medium", "Baseline coherence", "Balanced, neutral sound"),
    HIGH(0.6f, 0.8f, "High", "Good coherence", "Warm, harmonious textures"),
    VERY_HIGH(0.8f, 1.0f, "Very High", "Optimal coherence", "Full, immersive sound field");

    companion object {
        fun fromScore(score: Float): CoherenceLevel {
            return entries.find { score >= it.minScore && score < it.maxScore }
                ?: if (score >= 1.0f) VERY_HIGH else VERY_LOW
        }
    }
}

import Foundation
import HealthKit
import AVFoundation

/// Health Regeneration System
/// Comprehensive health, movement, nutrition, and lifestyle optimization
///
/// Features:
/// - Sense Regeneration (Vision, Hearing, Touch, Smell, Taste)
/// - Movement Apparatus (Muscles, Joints, Posture, Flexibility)
/// - Nervous System (Stress Reduction, Vagal Tone, Sleep)
/// - Organ Health (Heart, Lungs, Digestion, Immune System)
/// - Nutrition Guidance (Personalized recommendations)
/// - Lifestyle Optimization (Circadian Rhythm, Bio-reactive routines)
///
/// Based on:
/// - HeartMath Institute Research
/// - Polyvagal Theory (Dr. Stephen Porges)
/// - Wim Hof Method
/// - Traditional Chinese Medicine (TCM)
/// - Ayurveda
/// - Modern Sports Science
/// - Nutritional Science
@MainActor
class HealthRegenerationSystem: ObservableObject {

    // MARK: - Published State

    @Published var currentProgram: RegenerationProgram?
    @Published var activeExercises: [Exercise] = []
    @Published var nutritionPlan: NutritionPlan?
    @Published var lifestyleScore: Int = 0  // 0-100

    // Health metrics
    @Published var overallHealth: HealthScore?
    @Published var stressLevel: Double = 0  // 0-100
    @Published var energyLevel: Double = 0  // 0-100
    @Published var recoveryStatus: RecoveryStatus = .unknown

    // MARK: - Regeneration Programs

    struct RegenerationProgram: Identifiable {
        let id: UUID = UUID()
        var name: String
        var duration: TimeInterval
        var focus: [RegenerationFocus]
        var exercises: [Exercise]
        var frequency: Frequency

        enum RegenerationFocus {
            case senses           // Vision, hearing, touch, smell, taste
            case movement         // Muscles, joints, posture
            case nervous_system   // Stress, vagal tone, sleep
            case organs           // Heart, lungs, digestion
            case energy           // Fatigue recovery, mitochondrial health
            case immune           // Immune system strengthening
            case mental           // Cognitive health, memory
            case emotional        // Emotional regulation, mood
        }

        enum Frequency {
            case daily
            case three_times_week
            case weekly
            case as_needed
        }
    }

    // MARK: - Exercises

    struct Exercise: Identifiable {
        let id: UUID = UUID()
        var name: String
        var type: ExerciseType
        var duration: TimeInterval
        var instructions: String
        var benefits: [String]
        var bioReactive: Bool = false

        enum ExerciseType {
            // Vision Exercises
            case eye_palming
            case eye_rotation
            case near_far_focus
            case eye_massage
            case sunning  // Bates Method

            // Hearing Exercises
            case ear_massage
            case sound_therapy
            case silence_meditation
            case binaural_beats

            // Touch/Tactile Exercises
            case skin_brushing
            case cold_exposure  // Wim Hof
            case massage
            case acupressure

            // Smell/Taste Exercises
            case aromatherapy
            case taste_meditation
            case nasal_breathing

            // Movement Exercises
            case stretching
            case yoga
            case tai_chi
            case qigong
            case strength_training
            case cardio
            case balance_training
            case mobility_work

            // Nervous System
            case breathing_4_7_8  // Dr. Andrew Weil
            case box_breathing
            case wim_hof_breathing
            case vagal_nerve_stimulation
            case cold_shower
            case meditation
            case yoga_nidra  // Deep relaxation

            // Organ Health
            case heart_coherence_breathing  // HeartMath
            case lung_expansion
            case diaphragmatic_breathing
            case digestive_massage
            case liver_cleanse_yoga

            // Energy & Recovery
            case power_nap
            case nsdr  // Non-Sleep Deep Rest (Huberman)
            case grounding  // Earthing
            case sun_exposure

            // Mental & Emotional
            case gratitude_practice
            case journaling
            case visualization
            case affirmations
        }
    }

    // MARK: - Sense Regeneration

    struct SenseRegenerationProtocol {
        var sense: Sense
        var exercises: [Exercise]
        var duration: TimeInterval

        enum Sense {
            case vision
            case hearing
            case touch
            case smell
            case taste
            case vestibular  // Balance
            case proprioception  // Body awareness
        }

        static var visionProtocol: SenseRegenerationProtocol {
            SenseRegenerationProtocol(
                sense: .vision,
                exercises: [
                    Exercise(
                        name: "Eye Palming",
                        type: .eye_palming,
                        duration: 300,  // 5 minutes
                        instructions: "Rub hands together, place warm palms over closed eyes. Breathe deeply.",
                        benefits: ["Reduces eye strain", "Relaxes eye muscles", "Improves blood flow"]
                    ),
                    Exercise(
                        name: "Near-Far Focus",
                        type: .near_far_focus,
                        duration: 180,
                        instructions: "Focus on finger 6 inches away for 15 seconds, then distant object. Repeat 10x.",
                        benefits: ["Strengthens eye muscles", "Improves focus flexibility", "Prevents myopia progression"]
                    ),
                    Exercise(
                        name: "Eye Rotation",
                        type: .eye_rotation,
                        duration: 120,
                        instructions: "Slowly rotate eyes clockwise 10x, then counterclockwise 10x.",
                        benefits: ["Strengthens extraocular muscles", "Improves peripheral vision"]
                    )
                ],
                duration: 600
            )
        }

        static var hearingProtocol: SenseRegenerationProtocol {
            SenseRegenerationProtocol(
                sense: .hearing,
                exercises: [
                    Exercise(
                        name: "Ear Massage",
                        type: .ear_massage,
                        duration: 180,
                        instructions: "Gently massage earlobes, outer ear, and area behind ears.",
                        benefits: ["Improves blood circulation", "Reduces tinnitus", "Relaxes jaw"]
                    ),
                    Exercise(
                        name: "Silence Meditation",
                        type: .silence_meditation,
                        duration: 600,
                        instructions: "Sit in complete silence. Notice subtle sounds. Train auditory attention.",
                        benefits: ["Improves auditory discrimination", "Reduces auditory fatigue"]
                    )
                ],
                duration: 780
            )
        }
    }

    // MARK: - Movement Apparatus Regeneration

    struct MovementProtocol {
        var focus: MovementFocus
        var exercises: [Exercise]
        var bioReactive: Bool

        enum MovementFocus {
            case posture_correction
            case joint_mobility
            case muscle_recovery
            case flexibility
            case strength
            case balance
            case coordination
        }

        static var postureProtocol: MovementProtocol {
            MovementProtocol(
                focus: .posture_correction,
                exercises: [
                    Exercise(
                        name: "Wall Angels",
                        type: .stretching,
                        duration: 180,
                        instructions: "Stand against wall, raise arms like snow angel. Hold shoulders and lower back against wall.",
                        benefits: ["Corrects rounded shoulders", "Opens chest", "Strengthens upper back"]
                    ),
                    Exercise(
                        name: "Cat-Cow Stretch",
                        type: .yoga,
                        duration: 300,
                        instructions: "On hands and knees, alternate arching and rounding spine with breath.",
                        benefits: ["Improves spine flexibility", "Releases back tension", "Massages organs"]
                    )
                ],
                bioReactive: false
            )
        }

        static var bioReactiveMovement: MovementProtocol {
            MovementProtocol(
                focus: .flexibility,
                exercises: [
                    Exercise(
                        name: "HRV-Adaptive Yoga",
                        type: .yoga,
                        duration: 1800,  // 30 minutes
                        instructions: "Yoga flow that adapts to your HRV. High HRV = deeper stretches, Low HRV = gentle restorative.",
                        benefits: ["Personalized to your state", "Optimizes recovery", "Prevents overtraining"],
                        bioReactive: true
                    )
                ],
                bioReactive: true
            )
        }
    }

    // MARK: - Nervous System Regeneration

    struct NervousSystemProtocol {
        var target: Target
        var exercises: [Exercise]

        enum Target {
            case stress_reduction
            case vagal_tone_improvement  // Parasympathetic activation
            case sleep_optimization
            case anxiety_relief
            case focus_enhancement
        }

        static var vagalToneProtocol: NervousSystemProtocol {
            NervousSystemProtocol(
                target: .vagal_tone_improvement,
                exercises: [
                    Exercise(
                        name: "4-7-8 Breathing",
                        type: .breathing_4_7_8,
                        duration: 240,
                        instructions: "Inhale 4 seconds, hold 7 seconds, exhale 8 seconds. Repeat 4 cycles.",
                        benefits: ["Activates parasympathetic nervous system", "Reduces anxiety", "Improves sleep"]
                    ),
                    Exercise(
                        name: "Cold Exposure",
                        type: .cold_shower,
                        duration: 180,
                        instructions: "End shower with 30-60 seconds of cold water. Breathe calmly.",
                        benefits: ["Increases vagal tone", "Boosts norepinephrine", "Improves mood", "Strengthens immune system"]
                    ),
                    Exercise(
                        name: "Humming/Chanting",
                        type: .vagal_nerve_stimulation,
                        duration: 300,
                        instructions: "Hum 'Om' or sing. Vibration stimulates vagus nerve.",
                        benefits: ["Direct vagal stimulation", "Reduces heart rate", "Increases HRV"]
                    )
                ]
            )
        }

        static var sleepProtocol: NervousSystemProtocol {
            NervousSystemProtocol(
                target: .sleep_optimization,
                exercises: [
                    Exercise(
                        name: "Yoga Nidra",
                        type: .yoga_nidra,
                        duration: 1200,  // 20 minutes
                        instructions: "Guided body scan meditation. Lie down, follow voice instructions.",
                        benefits: ["Equivalent to 2-3 hours of sleep", "Deep nervous system reset", "Reduces stress hormones"]
                    ),
                    Exercise(
                        name: "NSDR (Non-Sleep Deep Rest)",
                        type: .nsdr,
                        duration: 600,  // 10 minutes
                        instructions: "Huberman protocol: Lie still, systematic relaxation, maintain awareness.",
                        benefits: ["Restores dopamine", "Improves focus", "Enhances learning consolidation"]
                    )
                ]
            )
        }
    }

    // MARK: - Organ Health Regeneration

    struct OrganHealthProtocol {
        var organ: Organ
        var exercises: [Exercise]
        var nutrition: [NutritionRecommendation]

        enum Organ {
            case heart
            case lungs
            case liver
            case kidneys
            case digestive_system
            case immune_system
            case endocrine_system  // Hormones
        }

        static var heartProtocol: OrganHealthProtocol {
            OrganHealthProtocol(
                organ: .heart,
                exercises: [
                    Exercise(
                        name: "HeartMath Coherence Breathing",
                        type: .heart_coherence_breathing,
                        duration: 300,
                        instructions: "Breathe 5-6 breaths/minute. Focus on heart area. Feel appreciation.",
                        benefits: ["Increases HRV", "Synchronizes heart-brain", "Reduces blood pressure"]
                    ),
                    Exercise(
                        name: "Zone 2 Cardio",
                        type: .cardio,
                        duration: 2700,  // 45 minutes
                        instructions: "Maintain 60-70% max heart rate. Should be able to talk.",
                        benefits: ["Improves mitochondrial function", "Enhances fat burning", "Strengthens heart"]
                    )
                ],
                nutrition: [
                    NutritionRecommendation(
                        category: .heart_health,
                        foods: ["Omega-3 (fish, flax)", "Berries", "Dark chocolate", "Nuts", "Olive oil"],
                        benefits: "Reduces inflammation, improves cholesterol"
                    )
                ]
            )
        }

        static var lungsProtocol: OrganHealthProtocol {
            OrganHealthProtocol(
                organ: .lungs,
                exercises: [
                    Exercise(
                        name: "Wim Hof Breathing",
                        type: .wim_hof_breathing,
                        duration: 600,
                        instructions: "30 deep breaths, exhale, hold breath as long as possible. Repeat 3 rounds.",
                        benefits: ["Increases oxygen delivery", "Alkalizes blood", "Boosts immune system", "Increases lung capacity"]
                    ),
                    Exercise(
                        name: "Diaphragmatic Breathing",
                        type: .diaphragmatic_breathing,
                        duration: 300,
                        instructions: "Breathe deep into belly, not chest. Hand on belly should rise.",
                        benefits: ["Strengthens diaphragm", "Improves oxygen exchange", "Activates vagus nerve"]
                    )
                ],
                nutrition: [
                    NutritionRecommendation(
                        category: .respiratory_health,
                        foods: ["Ginger", "Turmeric", "Garlic", "Green tea", "Apples"],
                        benefits: "Anti-inflammatory, improves lung function"
                    )
                ]
            )
        }

        static var digestiveProtocol: OrganHealthProtocol {
            OrganHealthProtocol(
                organ: .digestive_system,
                exercises: [
                    Exercise(
                        name: "Abdominal Massage",
                        type: .digestive_massage,
                        duration: 600,
                        instructions: "Massage abdomen clockwise (direction of colon). Gentle pressure.",
                        benefits: ["Improves digestion", "Relieves bloating", "Stimulates peristalsis"]
                    ),
                    Exercise(
                        name: "Pavanamuktasana (Wind-Relieving Pose)",
                        type: .yoga,
                        duration: 300,
                        instructions: "Lie on back, hug knees to chest, rock gently side to side.",
                        benefits: ["Releases gas", "Massages digestive organs", "Relieves constipation"]
                    )
                ],
                nutrition: [
                    NutritionRecommendation(
                        category: .gut_health,
                        foods: ["Fermented foods (sauerkraut, kimchi)", "Prebiotic fiber", "Bone broth", "Ginger"],
                        benefits: "Supports microbiome, reduces inflammation"
                    )
                ]
            )
        }
    }

    // MARK: - Nutrition Plan

    struct NutritionPlan: Identifiable {
        let id: UUID = UUID()
        var name: String
        var goal: NutritionGoal
        var macros: Macros
        var recommendations: [NutritionRecommendation]
        var mealTiming: MealTiming
        var bioReactive: Bool

        enum NutritionGoal {
            case weight_loss
            case muscle_gain
            case performance
            case longevity
            case gut_health
            case brain_health
            case anti_inflammatory
        }

        struct Macros {
            var protein: Int  // grams per day
            var carbs: Int
            var fat: Int
            var calories: Int

            static var balanced: Macros {
                Macros(protein: 150, carbs: 200, fat: 70, calories: 2000)
            }

            static var lowCarb: Macros {
                Macros(protein: 150, carbs: 50, fat: 130, calories: 2000)
            }

            static var highProtein: Macros {
                Macros(protein: 200, carbs: 150, fat: 60, calories: 2000)
            }
        }

        struct MealTiming {
            var pattern: Pattern
            var eatingWindow: TimeInterval  // For intermittent fasting

            enum Pattern {
                case three_meals
                case five_small_meals
                case intermittent_fasting_16_8
                case intermittent_fasting_18_6
                case omad  // One Meal A Day
                case circadian_aligned  // Eat during daylight hours
            }
        }

        static var bioReactivePlan: NutritionPlan {
            NutritionPlan(
                name: "HRV-Optimized Nutrition",
                goal: .performance,
                macros: .balanced,
                recommendations: [
                    NutritionRecommendation(
                        category: .hrv_optimization,
                        foods: ["Omega-3", "Magnesium", "Potassium", "B-vitamins", "Antioxidants"],
                        benefits: "Increases HRV, reduces inflammation"
                    )
                ],
                mealTiming: MealTiming(pattern: .circadian_aligned, eatingWindow: 28800),  // 8 hours
                bioReactive: true
            )
        }
    }

    struct NutritionRecommendation {
        var category: Category
        var foods: [String]
        var benefits: String

        enum Category {
            case heart_health
            case brain_health
            case gut_health
            case respiratory_health
            case immune_support
            case energy_optimization
            case hrv_optimization
            case anti_inflammatory
            case longevity
        }
    }

    // MARK: - Lifestyle Optimization

    struct LifestyleProtocol {
        var circadianAlignment: CircadianAlignment
        var sleepHygiene: SleepHygiene
        var stressManagement: StressManagement
        var socialConnection: SocialConnection

        struct CircadianAlignment {
            var wakeTime: Date
            var sleepTime: Date
            var morningLight: Bool  // View bright light within 30 min of waking
            var eveningLight: Bool  // Dim lights 2 hours before bed
            var mealTiming: Bool    // Eat during daylight hours

            var score: Int {
                var points = 0
                if morningLight { points += 25 }
                if eveningLight { points += 25 }
                if mealTiming { points += 25 }
                // Sleep timing
                let idealSleep = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date())!
                let sleepHour = Calendar.current.component(.hour, from: sleepTime)
                if sleepHour >= 21 && sleepHour <= 23 {
                    points += 25
                }
                return points
            }
        }

        struct SleepHygiene {
            var darkRoom: Bool
            var coolTemperature: Bool  // 60-67°F (15-19°C)
            var noScreens: Bool        // 1 hour before bed
            var consistentSchedule: Bool
            var magnesiumSupplement: Bool

            var score: Int {
                var points = 0
                if darkRoom { points += 20 }
                if coolTemperature { points += 20 }
                if noScreens { points += 20 }
                if consistentSchedule { points += 20 }
                if magnesiumSupplement { points += 20 }
                return points
            }
        }

        struct StressManagement {
            var dailyMeditation: Bool
            var exerciseRoutine: Bool
            var natureExposure: Bool
            var breathwork: Bool
            var socialSupport: Bool

            var score: Int {
                var points = 0
                if dailyMeditation { points += 20 }
                if exerciseRoutine { points += 20 }
                if natureExposure { points += 20 }
                if breathwork { points += 20 }
                if socialSupport { points += 20 }
                return points
            }
        }

        struct SocialConnection {
            var dailyHumanContact: Bool
            var weeklyGroupActivity: Bool
            var strongRelationships: Int  // Number of close friends
            var communityInvolvement: Bool

            var score: Int {
                var points = 0
                if dailyHumanContact { points += 25 }
                if weeklyGroupActivity { points += 25 }
                points += min(25, strongRelationships * 5)
                if communityInvolvement { points += 25 }
                return min(100, points)
            }
        }
    }

    // MARK: - Health Score

    struct HealthScore {
        var physical: Int      // 0-100
        var mental: Int        // 0-100
        var emotional: Int     // 0-100
        var social: Int        // 0-100
        var spiritual: Int     // 0-100

        var overall: Int {
            (physical + mental + emotional + social + spiritual) / 5
        }

        var grade: Grade {
            let score = overall
            if score >= 90 {
                return .excellent
            } else if score >= 75 {
                return .good
            } else if score >= 60 {
                return .fair
            } else {
                return .poor
            }
        }

        enum Grade {
            case excellent  // 90-100
            case good       // 75-89
            case fair       // 60-74
            case poor       // < 60
        }
    }

    // MARK: - Recovery Status

    enum RecoveryStatus {
        case unknown
        case fully_recovered
        case recovered
        case recovering
        case fatigued
        case overtrained

        static func from(hrv: Double, restingHR: Double, sleepQuality: Int) -> RecoveryStatus {
            // HRV high + Resting HR low + Sleep good = Fully recovered
            if hrv > 80 && restingHR < 55 && sleepQuality > 85 {
                return .fully_recovered
            } else if hrv > 60 && restingHR < 65 && sleepQuality > 70 {
                return .recovered
            } else if hrv > 40 {
                return .recovering
            } else if hrv > 20 {
                return .fatigued
            } else {
                return .overtrained
            }
        }
    }

    // MARK: - Bio-Reactive Health Recommendations

    func getPersonalizedRecommendations(hrv: Double, heartRate: Double, sleepScore: Int, stressLevel: Double) -> [Recommendation] {
        var recommendations: [Recommendation] = []

        // HRV-based recommendations
        if hrv < 30 {
            recommendations.append(Recommendation(
                priority: .high,
                category: .recovery,
                title: "Low HRV Detected - Prioritize Recovery",
                description: "Your HRV is low (\(Int(hrv)) ms), indicating stress or insufficient recovery.",
                actions: [
                    "Take today as a rest day or very light activity",
                    "Practice 10 minutes of slow breathing (4-7-8 method)",
                    "Ensure 8+ hours of sleep tonight",
                    "Avoid intense exercise",
                    "Consider meditation or yoga nidra"
                ]
            ))
        }

        // Sleep-based recommendations
        if sleepScore < 60 {
            recommendations.append(Recommendation(
                priority: .high,
                category: .sleep,
                title: "Poor Sleep Quality - Optimize Sleep Hygiene",
                description: "Your sleep score is low (\(sleepScore)/100).",
                actions: [
                    "Go to bed 30 minutes earlier tonight",
                    "Keep room dark and cool (65°F / 18°C)",
                    "No screens 1 hour before bed",
                    "Take 400mg magnesium glycinate before bed",
                    "Try NSDR or Yoga Nidra protocol"
                ]
            ))
        }

        // Stress-based recommendations
        if stressLevel > 70 {
            recommendations.append(Recommendation(
                priority: .high,
                category: .stress,
                title: "High Stress - Activate Parasympathetic",
                description: "Stress level is elevated (\(Int(stressLevel))%).",
                actions: [
                    "5 minutes of box breathing NOW",
                    "Cold shower for 60 seconds",
                    "20-minute walk in nature",
                    "Humming/chanting for vagal stimulation",
                    "Gratitude practice (write 3 things)"
                ]
            ))
        }

        // Heart rate-based recommendations
        if heartRate > 75 {
            recommendations.append(Recommendation(
                priority: .medium,
                category: .recovery,
                title: "Elevated Resting Heart Rate",
                description: "Resting HR is higher than optimal (\(Int(heartRate)) BPM).",
                actions: [
                    "Check hydration - drink water",
                    "Practice coherence breathing",
                    "Reduce caffeine intake",
                    "Ensure adequate electrolytes"
                ]
            ))
        }

        return recommendations
    }

    struct Recommendation {
        var priority: Priority
        var category: Category
        var title: String
        var description: String
        var actions: [String]

        enum Priority {
            case critical
            case high
            case medium
            case low
        }

        enum Category {
            case recovery
            case sleep
            case stress
            case nutrition
            case movement
            case social
        }
    }

    // MARK: - Preset Programs

    static var morningRoutine: RegenerationProgram {
        RegenerationProgram(
            name: "Morning Energizing Routine",
            duration: 1200,  // 20 minutes
            focus: [.nervous_system, .movement, .senses],
            exercises: [
                Exercise(
                    name: "Sunlight Exposure",
                    type: .sun_exposure,
                    duration: 300,
                    instructions: "View bright outdoor light within 30 min of waking. No sunglasses.",
                    benefits: ["Sets circadian rhythm", "Boosts cortisol awakening", "Improves mood"]
                ),
                Exercise(
                    name: "Wim Hof Breathing",
                    type: .wim_hof_breathing,
                    duration: 600,
                    instructions: "30 deep breaths, hold, recovery breath. 3 rounds.",
                    benefits: ["Increases energy", "Alkalizes blood", "Boosts immune system"]
                ),
                Exercise(
                    name: "Cold Shower",
                    type: .cold_shower,
                    duration: 120,
                    instructions: "1-2 minutes of cold water. Breathe calmly.",
                    benefits: ["Increases alertness", "Boosts dopamine 250%", "Improves mood"]
                )
            ],
            frequency: .daily
        )
    }

    static var eveningRoutine: RegenerationProgram {
        RegenerationProgram(
            name: "Evening Wind-Down Routine",
            duration: 1800,  // 30 minutes
            focus: [.nervous_system, .senses, .organs],
            exercises: [
                Exercise(
                    name: "Yoga Nidra",
                    type: .yoga_nidra,
                    duration: 1200,
                    instructions: "Guided body scan meditation. Lie down, follow instructions.",
                    benefits: ["Deep nervous system reset", "Equivalent to 2-3 hours sleep"]
                ),
                Exercise(
                    name: "4-7-8 Breathing",
                    type: .breathing_4_7_8,
                    duration: 300,
                    instructions: "Inhale 4, hold 7, exhale 8. Repeat 8 cycles.",
                    benefits: ["Activates parasympathetic", "Reduces anxiety", "Prepares for sleep"]
                )
            ],
            frequency: .daily
        )
    }

    // MARK: - Bio-Reactive Program Selection

    func recommendProgram(hrv: Double, stressLevel: Double, energyLevel: Double) -> RegenerationProgram {
        // High stress → Nervous system focus
        if stressLevel > 70 {
            return RegenerationProgram(
                name: "Stress Relief Protocol",
                duration: 1200,
                focus: [.nervous_system],
                exercises: [
                    Exercise(
                        name: "Vagal Nerve Stimulation",
                        type: .vagal_nerve_stimulation,
                        duration: 600,
                        instructions: "Humming, gargling, singing to activate vagus nerve.",
                        benefits: ["Reduces stress instantly", "Increases HRV", "Calms nervous system"]
                    )
                ],
                frequency: .as_needed
            )
        }

        // Low energy → Energy restoration
        if energyLevel < 30 {
            return RegenerationProgram(
                name: "Energy Restoration",
                duration: 900,
                focus: [.energy, .organs],
                exercises: [
                    Exercise(
                        name: "NSDR (Non-Sleep Deep Rest)",
                        type: .nsdr,
                        duration: 600,
                        instructions: "Huberman protocol for dopamine restoration.",
                        benefits: ["Restores dopamine", "Improves focus", "Boosts energy"]
                    )
                ],
                frequency: .as_needed
            )
        }

        // Default: Balanced program
        return Self.morningRoutine
    }

    // MARK: - Debug Info

    var debugInfo: String {
        var info = """
        HealthRegenerationSystem:
        - Overall Health: \(overallHealth?.overall ?? 0)/100
        - Stress Level: \(Int(stressLevel))%
        - Energy Level: \(Int(energyLevel))%
        - Recovery Status: \(recoveryStatus)
        """

        if let program = currentProgram {
            info += """
            \n
            Active Program: \(program.name)
            - Duration: \(Int(program.duration / 60)) minutes
            - Exercises: \(program.exercises.count)
            """
        }

        return info
    }
}

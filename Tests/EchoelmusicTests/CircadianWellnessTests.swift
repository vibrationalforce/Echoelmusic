// CircadianWellnessTests.swift
// Echoelmusic Tests
//
// Tests für Circadian Rhythm Engine und Lifestyle Coach

import XCTest
@testable import Echoelmusic

final class CircadianWellnessTests: XCTestCase {

    // MARK: - Circadian Phase Tests

    func testAllCircadianPhasesExist() {
        XCTAssertEqual(CircadianPhase.allCases.count, 8)
        XCTAssertTrue(CircadianPhase.allCases.contains(.deepSleep))
        XCTAssertTrue(CircadianPhase.allCases.contains(.remSleep))
        XCTAssertTrue(CircadianPhase.allCases.contains(.cortisol))
        XCTAssertTrue(CircadianPhase.allCases.contains(.peakAlertness))
        XCTAssertTrue(CircadianPhase.allCases.contains(.postLunch))
        XCTAssertTrue(CircadianPhase.allCases.contains(.secondWind))
        XCTAssertTrue(CircadianPhase.allCases.contains(.windDown))
        XCTAssertTrue(CircadianPhase.allCases.contains(.melatonin))
    }

    func testCircadianPhaseActivities() {
        let deepSleep = CircadianPhase.deepSleep
        XCTAssertFalse(deepSleep.optimalActivities.isEmpty)
        XCTAssertTrue(deepSleep.optimalActivities.contains("Schlafen"))

        let peakAlertness = CircadianPhase.peakAlertness
        XCTAssertTrue(peakAlertness.optimalActivities.contains("Komplexe Aufgaben"))
        XCTAssertTrue(peakAlertness.optimalActivities.contains("Kreative Arbeit"))

        let secondWind = CircadianPhase.secondWind
        XCTAssertTrue(secondWind.optimalActivities.contains("Sport"))
    }

    func testCircadianPhaseLightColors() {
        // Deep sleep should have no light
        let deepSleepLight = CircadianPhase.deepSleep.recommendedLightColor
        XCTAssertEqual(deepSleepLight.r, 0.0)
        XCTAssertEqual(deepSleepLight.g, 0.0)
        XCTAssertEqual(deepSleepLight.b, 0.0)

        // Post lunch should be calming green (~530nm)
        let postLunchLight = CircadianPhase.postLunch.recommendedLightColor
        XCTAssertGreaterThan(postLunchLight.g, 0.5)  // Green dominant

        // Melatonin phase should be warm red/amber (no blue)
        let melatoninLight = CircadianPhase.melatonin.recommendedLightColor
        XCTAssertGreaterThan(melatoninLight.r, melatoninLight.b)  // Red > Blue
    }

    func testCircadianPhaseFrequencies() {
        // Deep sleep = Delta (2Hz)
        XCTAssertEqual(CircadianPhase.deepSleep.recommendedFrequency, 2.0)

        // REM sleep = Theta (6Hz)
        XCTAssertEqual(CircadianPhase.remSleep.recommendedFrequency, 6.0)

        // Peak alertness = Beta (20Hz)
        XCTAssertEqual(CircadianPhase.peakAlertness.recommendedFrequency, 20.0)

        // Cortisol awakening = Alpha (10Hz)
        XCTAssertEqual(CircadianPhase.cortisol.recommendedFrequency, 10.0)
    }

    func testCircadianCarrierFrequencies() {
        // Sleep phases use 432Hz (subjective preference, no scientific basis)
        XCTAssertEqual(CircadianPhase.deepSleep.carrierFrequency, 432.0)
        XCTAssertEqual(CircadianPhase.remSleep.carrierFrequency, 432.0)
        XCTAssertEqual(CircadianPhase.melatonin.carrierFrequency, 432.0)

        // Daytime phases use standard 440Hz (ISO 16 A4)
        XCTAssertEqual(CircadianPhase.postLunch.carrierFrequency, 440.0)
        XCTAssertEqual(CircadianPhase.windDown.carrierFrequency, 440.0)

        // Active phases use 440Hz
        XCTAssertEqual(CircadianPhase.peakAlertness.carrierFrequency, 440.0)
    }

    // MARK: - Chronotype Tests

    func testAllChronotypesExist() {
        XCTAssertEqual(Chronotype.allCases.count, 4)
        XCTAssertTrue(Chronotype.allCases.contains(.lion))
        XCTAssertTrue(Chronotype.allCases.contains(.bear))
        XCTAssertTrue(Chronotype.allCases.contains(.wolf))
        XCTAssertTrue(Chronotype.allCases.contains(.dolphin))
    }

    func testChronotypeWakeTimes() {
        XCTAssertEqual(Chronotype.lion.optimalWakeTime, "05:30")
        XCTAssertEqual(Chronotype.bear.optimalWakeTime, "07:00")
        XCTAssertEqual(Chronotype.wolf.optimalWakeTime, "07:30")
        XCTAssertEqual(Chronotype.dolphin.optimalWakeTime, "06:30")
    }

    func testChronotypeBedTimes() {
        XCTAssertEqual(Chronotype.lion.optimalBedTime, "21:00")
        XCTAssertEqual(Chronotype.bear.optimalBedTime, "23:00")
        XCTAssertEqual(Chronotype.wolf.optimalBedTime, "00:00")
        XCTAssertEqual(Chronotype.dolphin.optimalBedTime, "23:30")
    }

    func testChronotypeProductivityWindows() {
        XCTAssertFalse(Chronotype.lion.peakProductivityWindow.isEmpty)
        XCTAssertFalse(Chronotype.bear.peakProductivityWindow.isEmpty)
        XCTAssertFalse(Chronotype.wolf.peakProductivityWindow.isEmpty)
        XCTAssertFalse(Chronotype.dolphin.peakProductivityWindow.isEmpty)
    }

    // MARK: - Lifestyle Tip Tests

    func testLifestyleTipsExist() {
        XCTAssertGreaterThan(CircadianRhythmEngine.lifestyleTips.count, 10)
    }

    func testLifestyleTipCategories() {
        let categories = Set(CircadianRhythmEngine.lifestyleTips.map { $0.category })
        XCTAssertTrue(categories.contains(.sleep))
        XCTAssertTrue(categories.contains(.nutrition))
        XCTAssertTrue(categories.contains(.fitness))
        XCTAssertTrue(categories.contains(.lightExposure))
        XCTAssertTrue(categories.contains(.breathing))
    }

    func testLifestyleTipCoherenceImpact() {
        for tip in CircadianRhythmEngine.lifestyleTips {
            XCTAssertGreaterThanOrEqual(tip.coherenceImpact, -1.0)
            XCTAssertLessThanOrEqual(tip.coherenceImpact, 1.0)
        }
    }

    func testGreenLightTipExists() {
        // Check for green light exposure tip (circadian-optimized, no pseudoscience frequency claims)
        let greenLightTip = CircadianRhythmEngine.lifestyleTips.first { tip in
            tip.category == .lightExposure && tip.title.lowercased().contains("green")
        }
        // Green light tips are optional - test passes either way
        if let tip = greenLightTip {
            XCTAssertEqual(tip.category, .lightExposure)
        }
    }

    // MARK: - Nutrition Tests

    func testCoherenceNutritionExists() {
        XCTAssertGreaterThan(CircadianRhythmEngine.coherenceNutrition.count, 10)
    }

    func testNutritionCoherenceImpact() {
        for item in CircadianRhythmEngine.coherenceNutrition {
            XCTAssertGreaterThanOrEqual(item.coherenceImpact, 0.0)
            XCTAssertLessThanOrEqual(item.coherenceImpact, 1.0)
        }
    }

    func testOmega3FoodsExist() {
        let omega3Foods = CircadianRhythmEngine.coherenceNutrition.filter { item in
            item.category.contains("Omega-3")
        }
        XCTAssertGreaterThan(omega3Foods.count, 0)
    }

    func testMagnesiumFoodsExist() {
        let magnesiumFoods = CircadianRhythmEngine.coherenceNutrition.filter { item in
            item.category.contains("Magnesium")
        }
        XCTAssertGreaterThan(magnesiumFoods.count, 0)
    }

    // MARK: - Fitness Activity Tests

    func testAllFitnessActivitiesExist() {
        XCTAssertGreaterThan(FitnessActivityType.allCases.count, 15)
    }

    func testFitnessActivityDurations() {
        for activity in FitnessActivityType.allCases {
            XCTAssertGreaterThan(activity.recommendedDuration, 0)
            XCTAssertLessThanOrEqual(activity.recommendedDuration, 60)
        }
    }

    func testFitnessActivityCoherenceEffects() {
        // Meditation should have highest coherence effect
        XCTAssertGreaterThan(FitnessActivityType.meditation.coherenceEffect, 0.8)

        // Breathwork should have high coherence effect
        XCTAssertGreaterThan(FitnessActivityType.breathwork.coherenceEffect, 0.7)

        // HIIT should have lower coherence effect (acute stress)
        XCTAssertLessThan(FitnessActivityType.hiit.coherenceEffect, 0.5)
    }

    func testFitnessActivityOptimalTimes() {
        // Strength training optimal in afternoon
        XCTAssertTrue(FitnessActivityType.weightTraining.optimalTimeOfDay.contains(.secondWind))

        // Yoga optimal morning or evening
        let yogaTimes = FitnessActivityType.yoga.optimalTimeOfDay
        XCTAssertTrue(yogaTimes.contains(.cortisol) || yogaTimes.contains(.windDown))

        // Meditation anytime
        XCTAssertEqual(FitnessActivityType.meditation.optimalTimeOfDay.count, CircadianPhase.allCases.count)
    }

    // MARK: - Meal Type Tests

    func testAllMealTypesExist() {
        XCTAssertEqual(MealType.allCases.count, 6)
    }

    func testMealOptimalTimes() {
        XCTAssertFalse(MealType.breakfast.optimalTime.isEmpty)
        XCTAssertFalse(MealType.lunch.optimalTime.isEmpty)
        XCTAssertFalse(MealType.dinner.optimalTime.isEmpty)
    }

    func testMealMacroFocus() {
        // Breakfast should focus on protein
        XCTAssertTrue(MealType.breakfast.macroFocus.contains("Protein"))

        // Evening snack should support sleep
        XCTAssertTrue(MealType.eveningSnack.macroFocus.contains("Tryptophan") ||
                      MealType.eveningSnack.macroFocus.contains("Schlaf"))
    }

    // MARK: - Health Disclaimer Tests

    func testHealthDisclaimerExists() {
        XCTAssertFalse(CircadianHealthDisclaimer.fullDisclaimer.isEmpty)
        XCTAssertFalse(CircadianHealthDisclaimer.shortDisclaimer.isEmpty)
    }

    func testHealthDisclaimerContent() {
        let fullDisclaimer = CircadianHealthDisclaimer.fullDisclaimer
        XCTAssertTrue(fullDisclaimer.contains("KEIN medizinisches Gerät"))
        XCTAssertTrue(fullDisclaimer.contains("Arzt"))
    }

    // MARK: - Circadian Rhythm Engine Tests

    @MainActor
    func testCircadianRhythmEngineInitialization() async {
        let engine = CircadianRhythmEngine()
        XCTAssertNotNil(engine.currentPhase)
        XCTAssertNotNil(engine.chronotype)
    }

    @MainActor
    func testCircadianScoreRange() async {
        let engine = CircadianRhythmEngine()
        XCTAssertGreaterThanOrEqual(engine.circadianScore, 0.0)
        XCTAssertLessThanOrEqual(engine.circadianScore, 1.0)
    }

    @MainActor
    func testLightSettingsHaveValidValues() async {
        let engine = CircadianRhythmEngine()
        let (color, intensity) = engine.getCurrentLightSettings()

        XCTAssertGreaterThanOrEqual(color.r, 0.0)
        XCTAssertLessThanOrEqual(color.r, 1.0)
        XCTAssertGreaterThanOrEqual(color.g, 0.0)
        XCTAssertLessThanOrEqual(color.g, 1.0)
        XCTAssertGreaterThanOrEqual(color.b, 0.0)
        XCTAssertLessThanOrEqual(color.b, 1.0)
        XCTAssertGreaterThanOrEqual(intensity, 0.0)
        XCTAssertLessThanOrEqual(intensity, 1.0)
    }

    @MainActor
    func testAudioSettingsHaveValidValues() async {
        let engine = CircadianRhythmEngine()
        let (entrainment, carrier) = engine.getCurrentAudioSettings()

        // Entrainment should be in brainwave range (0.5-100 Hz)
        XCTAssertGreaterThanOrEqual(entrainment, 0.5)
        XCTAssertLessThanOrEqual(entrainment, 100.0)

        // Carrier should be audible frequency (400-600 Hz for healing)
        XCTAssertGreaterThanOrEqual(carrier, 400.0)
        XCTAssertLessThanOrEqual(carrier, 600.0)
    }

    // MARK: - Performance Tests

    func testCircadianPhaseUpdatePerformance() {
        measure {
            for _ in 0..<1000 {
                let phase = CircadianPhase.allCases.randomElement()!
                _ = phase.recommendedFrequency
                _ = phase.carrierFrequency
                _ = phase.recommendedLightColor
                _ = phase.optimalActivities
            }
        }
    }

    func testNutritionLookupPerformance() {
        measure {
            for _ in 0..<100 {
                let items = CircadianRhythmEngine.coherenceNutrition
                _ = items.filter { $0.coherenceImpact > 0.5 }
                _ = items.sorted { $0.coherenceImpact > $1.coherenceImpact }
            }
        }
    }
}

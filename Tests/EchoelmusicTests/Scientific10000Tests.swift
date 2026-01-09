// Scientific10000Tests.swift
// Echoelmusic Tests
//
// Comprehensive 10000% Scientific ULTRA MODE Tests
// Tests for: LongevityNutritionEngine, NeuroSpiritualEngine, QuantumHealthBiofeedbackEngine
//
// Scientific Basis:
// - López-Otín et al., Cell 2013 (9 Hallmarks of Aging)
// - PMC7527628 (HRV and Exceptional Longevity)
// - Stephen Porges (Polyvagal Theory)
// - FACS (Facial Action Coding System)
// - Blue Zones Research (Dan Buettner)

import XCTest
@testable import Echoelmusic

final class Scientific10000Tests: XCTestCase {

    // MARK: - Hallmarks of Aging Tests

    func testAllNineHallmarksOfAgingExist() {
        // López-Otín et al., Cell 2013
        XCTAssertEqual(HallmarkOfAging.allCases.count, 9)
        XCTAssertTrue(HallmarkOfAging.allCases.contains(.genomicInstability))
        XCTAssertTrue(HallmarkOfAging.allCases.contains(.telomereAttrition))
        XCTAssertTrue(HallmarkOfAging.allCases.contains(.epigeneticAlterations))
        XCTAssertTrue(HallmarkOfAging.allCases.contains(.lossOfProteostasis))
        XCTAssertTrue(HallmarkOfAging.allCases.contains(.deregulatedNutrientSensing))
        XCTAssertTrue(HallmarkOfAging.allCases.contains(.mitochondrialDysfunction))
        XCTAssertTrue(HallmarkOfAging.allCases.contains(.cellularSenescence))
        XCTAssertTrue(HallmarkOfAging.allCases.contains(.stemCellExhaustion))
        XCTAssertTrue(HallmarkOfAging.allCases.contains(.alteredIntercellularCommunication))
    }

    func testHallmarkDescriptions() {
        XCTAssertFalse(HallmarkOfAging.genomicInstability.description.isEmpty)
        XCTAssertTrue(HallmarkOfAging.genomicInstability.description.contains("DNA"))
        XCTAssertTrue(HallmarkOfAging.telomereAttrition.description.contains("Telomere"))
        XCTAssertTrue(HallmarkOfAging.cellularSenescence.description.contains("SASP"))
    }

    func testHallmarkTargetingNutrients() {
        // Each hallmark should have targeting nutrients
        for hallmark in HallmarkOfAging.allCases {
            XCTAssertFalse(hallmark.targetingNutrients.isEmpty, "\(hallmark) should have targeting nutrients")
        }

        // Specific nutrients for specific hallmarks
        XCTAssertTrue(HallmarkOfAging.cellularSenescence.targetingNutrients.contains("Fisetin"))
        XCTAssertTrue(HallmarkOfAging.cellularSenescence.targetingNutrients.contains("Quercetin"))
        XCTAssertTrue(HallmarkOfAging.mitochondrialDysfunction.targetingNutrients.contains("CoQ10"))
        XCTAssertTrue(HallmarkOfAging.mitochondrialDysfunction.targetingNutrients.contains("NAD+/NMN"))
    }

    // MARK: - Longevity Compounds Tests

    func testAllCompoundCategoriesExist() {
        XCTAssertEqual(CompoundCategory.allCases.count, 10)
        XCTAssertTrue(CompoundCategory.allCases.contains(.sirtuin))
        XCTAssertTrue(CompoundCategory.allCases.contains(.senolytic))
        XCTAssertTrue(CompoundCategory.allCases.contains(.nad))
        XCTAssertTrue(CompoundCategory.allCases.contains(.mitochondrial))
        XCTAssertTrue(CompoundCategory.allCases.contains(.epigenetic))
        XCTAssertTrue(CompoundCategory.allCases.contains(.antiInflammatory))
        XCTAssertTrue(CompoundCategory.allCases.contains(.autophagy))
        XCTAssertTrue(CompoundCategory.allCases.contains(.telomere))
        XCTAssertTrue(CompoundCategory.allCases.contains(.antioxidant))
        XCTAssertTrue(CompoundCategory.allCases.contains(.adaptogen))
    }

    func testEvidenceLevelReliability() {
        XCTAssertEqual(EvidenceLevel.humanRCT.reliability, 1.0)
        XCTAssertEqual(EvidenceLevel.humanObservational.reliability, 0.8)
        XCTAssertEqual(EvidenceLevel.animalStudy.reliability, 0.5)
        XCTAssertEqual(EvidenceLevel.inVitro.reliability, 0.3)
        XCTAssertEqual(EvidenceLevel.traditional.reliability, 0.4)
    }

    func testLongevityCompoundCreation() {
        let compound = LongevityCompound(
            name: "NMN",
            category: .nad,
            mechanism: "NAD+ precursor",
            dosage: "250-500mg",
            timing: "Morning",
            foodSources: ["Broccoli", "Avocado"],
            targetedHallmarks: [.mitochondrialDysfunction, .stemCellExhaustion],
            evidenceLevel: .humanRCT,
            hrvImpact: 0.7,
            caution: "Consult physician"
        )

        XCTAssertEqual(compound.name, "NMN")
        XCTAssertEqual(compound.category, .nad)
        XCTAssertEqual(compound.targetedHallmarks.count, 2)
        XCTAssertEqual(compound.evidenceLevel.reliability, 1.0)
    }

    // MARK: - Blue Zones Tests

    func testAllBlueZonePrinciplesExist() {
        // Power 9 Principles
        XCTAssertEqual(BlueZonePrinciple.allCases.count, 9)
        XCTAssertTrue(BlueZonePrinciple.allCases.contains(.moveNaturally))
        XCTAssertTrue(BlueZonePrinciple.allCases.contains(.purpose))
        XCTAssertTrue(BlueZonePrinciple.allCases.contains(.downshift))
        XCTAssertTrue(BlueZonePrinciple.allCases.contains(.eightyPercentRule))
        XCTAssertTrue(BlueZonePrinciple.allCases.contains(.plantSlant))
        XCTAssertTrue(BlueZonePrinciple.allCases.contains(.wineAtFive))
        XCTAssertTrue(BlueZonePrinciple.allCases.contains(.belong))
        XCTAssertTrue(BlueZonePrinciple.allCases.contains(.lovedOnesFirst))
        XCTAssertTrue(BlueZonePrinciple.allCases.contains(.rightTribe))
    }

    func testBlueZonePrincipleCoherenceImpact() {
        // Downshift should have highest coherence impact (stress reduction)
        XCTAssertEqual(BlueZonePrinciple.downshift.coherenceImpact, 0.95)
        // Purpose (Ikigai) should be high
        XCTAssertEqual(BlueZonePrinciple.purpose.coherenceImpact, 0.9)
        // All impacts should be 0-1
        for principle in BlueZonePrinciple.allCases {
            XCTAssertGreaterThanOrEqual(principle.coherenceImpact, 0)
            XCTAssertLessThanOrEqual(principle.coherenceImpact, 1.0)
        }
    }

    func testBlueZonePrincipleDescriptions() {
        XCTAssertTrue(BlueZonePrinciple.eightyPercentRule.description.contains("Hara Hachi Bu"))
        XCTAssertTrue(BlueZonePrinciple.purpose.description.contains("Ikigai"))
    }

    // MARK: - Food Category Tests

    func testAllFoodCategoriesExist() {
        XCTAssertEqual(FoodCategory.allCases.count, 12)
        XCTAssertTrue(FoodCategory.allCases.contains(.cruciferous))
        XCTAssertTrue(FoodCategory.allCases.contains(.legumes))
        XCTAssertTrue(FoodCategory.allCases.contains(.berries))
        XCTAssertTrue(FoodCategory.allCases.contains(.fermented))
        XCTAssertTrue(FoodCategory.allCases.contains(.mushrooms))
    }

    func testLongevityFoodCreation() {
        let food = LongevityFood(
            name: "Black Beans",
            category: .legumes,
            activeCompounds: ["Fiber", "Anthocyanins", "Folate"],
            targetedHallmarks: [.deregulatedNutrientSensing, .alteredIntercellularCommunication],
            servingSize: "1/2 cup",
            frequency: "Daily",
            hrvBenefit: 0.6,
            blueZoneOrigin: "Nicoya, Costa Rica"
        )

        XCTAssertEqual(food.name, "Black Beans")
        XCTAssertEqual(food.category, .legumes)
        XCTAssertEqual(food.blueZoneOrigin, "Nicoya, Costa Rica")
        XCTAssertEqual(food.activeCompounds.count, 3)
    }

    // MARK: - Chronotype Longevity Plan Tests

    func testChronotypeLongevityPlanCreation() {
        let food = LongevityFood(
            name: "Matcha",
            category: .beverages,
            activeCompounds: ["EGCG", "L-Theanine"],
            targetedHallmarks: [.genomicInstability],
            servingSize: "1 tsp",
            frequency: "Morning",
            hrvBenefit: 0.5
        )

        let compound = LongevityCompound(
            name: "NMN",
            category: .nad,
            mechanism: "NAD+ precursor",
            dosage: "250mg",
            timing: "Morning",
            foodSources: [],
            targetedHallmarks: [.mitochondrialDysfunction],
            evidenceLevel: .humanRCT,
            hrvImpact: 0.6,
            caution: ""
        )

        let plan = ChronotypeLongevityPlan(
            chronotype: .lion,
            fastingWindow: "16:8",
            eatingWindow: "6AM-2PM",
            firstMealTime: "6:00 AM",
            lastMealTime: "2:00 PM",
            keyFoods: [food],
            supplements: [compound],
            exerciseProtocol: "HIIT Morning",
            sleepProtocol: "9PM-5AM",
            stressProtocol: "Morning meditation",
            estimatedLifespanBenefit: "+5-10 years"
        )

        XCTAssertEqual(plan.chronotype, .lion)
        XCTAssertEqual(plan.fastingWindow, "16:8")
        XCTAssertEqual(plan.keyFoods.count, 1)
        XCTAssertEqual(plan.supplements.count, 1)
    }

    // MARK: - Consciousness State Tests (NeuroSpiritual)

    func testAllConsciousnessStatesExist() {
        XCTAssertEqual(ConsciousnessState.allCases.count, 10)
        XCTAssertTrue(ConsciousnessState.allCases.contains(.deepSleep))
        XCTAssertTrue(ConsciousnessState.allCases.contains(.dreamState))
        XCTAssertTrue(ConsciousnessState.allCases.contains(.relaxedAwareness))
        XCTAssertTrue(ConsciousnessState.allCases.contains(.focusedAttention))
        XCTAssertTrue(ConsciousnessState.allCases.contains(.highPerformance))
        XCTAssertTrue(ConsciousnessState.allCases.contains(.transcendent))
        XCTAssertTrue(ConsciousnessState.allCases.contains(.flowState))
        XCTAssertTrue(ConsciousnessState.allCases.contains(.meditativeAbsorption))
        XCTAssertTrue(ConsciousnessState.allCases.contains(.lucidDreaming))
        XCTAssertTrue(ConsciousnessState.allCases.contains(.unitiveExperience))
    }

    func testConsciousnessStateBrainwaves() {
        XCTAssertTrue(ConsciousnessState.deepSleep.dominantBrainwave.contains("Delta"))
        XCTAssertTrue(ConsciousnessState.dreamState.dominantBrainwave.contains("Theta"))
        XCTAssertTrue(ConsciousnessState.relaxedAwareness.dominantBrainwave.contains("Alpha"))
        XCTAssertTrue(ConsciousnessState.transcendent.dominantBrainwave.contains("Gamma"))
        XCTAssertTrue(ConsciousnessState.lucidDreaming.dominantBrainwave.contains("Theta"))
    }

    func testConsciousnessStateHRVSignatures() {
        // Unitive experience should have highest coherence
        let unitive = ConsciousnessState.unitiveExperience.hrvSignature
        XCTAssertEqual(unitive.coherence, 0.98)

        // Meditative absorption should have very high coherence
        let meditation = ConsciousnessState.meditativeAbsorption.hrvSignature
        XCTAssertEqual(meditation.coherence, 0.95)

        // All coherence values should be 0-1
        for state in ConsciousnessState.allCases {
            let signature = state.hrvSignature
            XCTAssertGreaterThanOrEqual(signature.coherence, 0)
            XCTAssertLessThanOrEqual(signature.coherence, 1.0)
        }
    }

    func testConsciousnessStateAudioFrequencies() {
        // Deep sleep = Delta = ~2Hz
        XCTAssertEqual(ConsciousnessState.deepSleep.audioFrequency, 2.0)
        // Lucid dreaming = Schumann resonance = 7.83Hz
        XCTAssertEqual(ConsciousnessState.lucidDreaming.audioFrequency, 7.83)
        // Transcendent = Gamma = 40Hz
        XCTAssertEqual(ConsciousnessState.transcendent.audioFrequency, 40.0)
    }

    // MARK: - Polyvagal State Tests (Stephen Porges)

    func testAllPolyvagalStatesExist() {
        XCTAssertEqual(PolyvagalState.allCases.count, 5)
        XCTAssertTrue(PolyvagalState.allCases.contains(.ventralVagal))
        XCTAssertTrue(PolyvagalState.allCases.contains(.sympathetic))
        XCTAssertTrue(PolyvagalState.allCases.contains(.dorsalVagal))
        XCTAssertTrue(PolyvagalState.allCases.contains(.blendedVentralSympathetic))
        XCTAssertTrue(PolyvagalState.allCases.contains(.blendedVentralDorsal))
    }

    func testPolyvagalStateDescriptions() {
        XCTAssertTrue(PolyvagalState.ventralVagal.description.contains("Sicher"))
        XCTAssertTrue(PolyvagalState.sympathetic.description.contains("Kampf"))
        XCTAssertTrue(PolyvagalState.dorsalVagal.description.contains("Erstarrung"))
        XCTAssertTrue(PolyvagalState.blendedVentralSympathetic.description.contains("Spiel"))
    }

    func testPolyvagalStateFacialIndicators() {
        // Ventral vagal = safe = Duchenne smile
        XCTAssertTrue(PolyvagalState.ventralVagal.facialIndicators.contains("Echtes Lächeln (Duchenne)"))
        // Sympathetic = stressed = tense
        XCTAssertTrue(PolyvagalState.sympathetic.facialIndicators.contains("Angespannte Kiefer"))
        // Dorsal = shutdown = blank
        XCTAssertTrue(PolyvagalState.dorsalVagal.facialIndicators.contains("Leerer Blick"))
    }

    func testPolyvagalStateBodyIndicators() {
        XCTAssertFalse(PolyvagalState.ventralVagal.bodyIndicators.isEmpty)
        XCTAssertTrue(PolyvagalState.ventralVagal.bodyIndicators.contains("Aufrechte Haltung"))
        XCTAssertTrue(PolyvagalState.dorsalVagal.bodyIndicators.contains("Zusammengesunken"))
    }

    func testPolyvagalStateCoherenceCorrelation() {
        // Blended ventral-dorsal (stillness) has highest coherence
        XCTAssertEqual(PolyvagalState.blendedVentralDorsal.coherenceCorrelation, 0.9)
        // Ventral vagal (safe engagement) is high
        XCTAssertEqual(PolyvagalState.ventralVagal.coherenceCorrelation, 0.85)
        // Dorsal vagal (shutdown) has low coherence
        XCTAssertEqual(PolyvagalState.dorsalVagal.coherenceCorrelation, 0.25)
    }

    // MARK: - Facial Expression (FACS) Tests

    func testFacialExpressionDataCreation() {
        var expression = FacialExpressionData()

        // Test default values
        XCTAssertEqual(expression.joy, 0)
        XCTAssertEqual(expression.sadness, 0)

        // Test Duchenne smile detection
        expression.cheekRaise = 0.6
        expression.lipCornerPull = 0.6
        XCTAssertTrue(expression.isDuchenneSmile)

        expression.cheekRaise = 0.3
        XCTAssertFalse(expression.isDuchenneSmile)
    }

    func testFacialExpressionPolyvagalInference() {
        var expression = FacialExpressionData()

        // Happy engaged = ventral vagal
        expression.cheekRaise = 0.7
        expression.lipCornerPull = 0.7
        expression.engagement = 0.8
        XCTAssertEqual(expression.inferredPolyvagalState, .ventralVagal)

        // Fear = sympathetic
        expression = FacialExpressionData()
        expression.fear = 0.7
        XCTAssertEqual(expression.inferredPolyvagalState, .sympathetic)

        // Sad and disengaged = dorsal vagal
        expression = FacialExpressionData()
        expression.sadness = 0.7
        expression.engagement = 0.1
        XCTAssertEqual(expression.inferredPolyvagalState, .dorsalVagal)

        // Serene = blended ventral-dorsal
        expression = FacialExpressionData()
        expression.serenity = 0.8
        XCTAssertEqual(expression.inferredPolyvagalState, .blendedVentralDorsal)
    }

    // MARK: - Gesture Analysis Tests

    func testGestureDataCreation() {
        var gesture = GestureData()

        // Test default values
        XCTAssertEqual(gesture.leftHandOpenness, 0.5)
        XCTAssertEqual(gesture.rightHandOpenness, 0.5)

        // Test openness score
        gesture.leftHandOpenness = 1.0
        gesture.rightHandOpenness = 1.0
        gesture.isOpenPalm = true
        XCTAssertGreaterThan(gesture.opennesScore, 1.0) // 1.0 * 1.2 = 1.2

        // Test pushing away reduces openness
        gesture.isPushingAway = true
        XCTAssertLessThan(gesture.opennesScore, 1.0)
    }

    func testGestureExpressivityScore() {
        var gesture = GestureData()

        // Low movement = low expressivity
        gesture.gestureAmplitude = 0.1
        gesture.gestureSpeed = 0.1
        XCTAssertEqual(gesture.expressivityScore, 0.01)

        // High movement = high expressivity (capped at 1.0)
        gesture.gestureAmplitude = 2.0
        gesture.gestureSpeed = 2.0
        XCTAssertEqual(gesture.expressivityScore, 1.0)
    }

    // MARK: - Body Movement (Reich/Lowen) Tests

    func testBodyMovementDataCreation() {
        var movement = BodyMovementData()

        // Test default tension values
        XCTAssertEqual(movement.ocularTension, 0)
        XCTAssertEqual(movement.pelvicTension, 0)

        // Test overall tension calculation
        movement.ocularTension = 0.5
        movement.oralTension = 0.5
        movement.cervicalTension = 0.5
        movement.thoracicTension = 0.5
        movement.diaphragmaticTension = 0.5
        movement.abdominalTension = 0.5
        movement.pelvicTension = 0.5
        XCTAssertEqual(movement.overallTension, 0.5)
    }

    func testBodyMovementSevenSegments() {
        // Reich's 7 muscular armor segments
        let movement = BodyMovementData()

        // All 7 segments should be accessible
        _ = movement.ocularTension
        _ = movement.oralTension
        _ = movement.cervicalTension
        _ = movement.thoracicTension
        _ = movement.diaphragmaticTension
        _ = movement.abdominalTension
        _ = movement.pelvicTension

        XCTAssertTrue(true) // Segments accessible
    }

    // MARK: - Quantum Health State Tests

    func testQuantumHealthStateCreation() {
        let state = QuantumHealthState()

        // Test default biometric values
        XCTAssertEqual(state.heartRate, 70)
        XCTAssertEqual(state.hrvSDNN, 50)
        XCTAssertEqual(state.hrvRMSSD, 40)
        XCTAssertEqual(state.bloodOxygenation, 98)

        // Test quantum-inspired metrics
        XCTAssertEqual(state.coherenceAmplitude, 0.5)
        XCTAssertEqual(state.phaseAlignment, 0.5)
        XCTAssertEqual(state.entropyLevel, 0.5)
    }

    func testQuantumHealthScore() {
        var state = QuantumHealthState()

        // Default state should have moderate score
        let defaultScore = state.quantumHealthScore
        XCTAssertGreaterThan(defaultScore, 0)
        XCTAssertLessThanOrEqual(defaultScore, 100)

        // Optimal state should have higher score
        state.hrvSDNN = 80
        state.coherenceRatio = 0.9
        state.breathingRate = 6.0 // Optimal
        state.bloodOxygenation = 99
        state.coherenceAmplitude = 0.9
        state.phaseAlignment = 0.9
        state.entropyLevel = 0.1 // Low entropy = high order

        let optimalScore = state.quantumHealthScore
        XCTAssertGreaterThan(optimalScore, defaultScore)
    }

    // MARK: - Quantum Session Tests

    func testQuantumSessionCreation() {
        let session = QuantumEntanglementSession(
            name: "Global Meditation",
            sessionType: .meditation,
            maxParticipants: .max
        )

        XCTAssertEqual(session.name, "Global Meditation")
        XCTAssertEqual(session.sessionType, .meditation)
        XCTAssertEqual(session.maxParticipants, Int.max)
        XCTAssertTrue(session.isActive)
        XCTAssertTrue(session.participants.isEmpty)
    }

    func testAllSessionTypesExist() {
        XCTAssertEqual(QuantumEntanglementSession.SessionType.allCases.count, 8)
        XCTAssertTrue(QuantumEntanglementSession.SessionType.allCases.contains(.meditation))
        XCTAssertTrue(QuantumEntanglementSession.SessionType.allCases.contains(.coherenceTraining))
        XCTAssertTrue(QuantumEntanglementSession.SessionType.allCases.contains(.creativeSynthesis))
        XCTAssertTrue(QuantumEntanglementSession.SessionType.allCases.contains(.wellnessCircle))
        XCTAssertTrue(QuantumEntanglementSession.SessionType.allCases.contains(.researchStudy))
        XCTAssertTrue(QuantumEntanglementSession.SessionType.allCases.contains(.performance))
        XCTAssertTrue(QuantumEntanglementSession.SessionType.allCases.contains(.workshop))
        XCTAssertTrue(QuantumEntanglementSession.SessionType.allCases.contains(.unlimited))
    }

    // MARK: - Entangled Participant Tests

    func testEntangledParticipantCreation() {
        let participant = EntangledParticipant(
            displayName: "Alice"
        )

        XCTAssertEqual(participant.displayName, "Alice")
        XCTAssertEqual(participant.connectionQuality, 1.0)
        XCTAssertFalse(participant.isLeader)
        XCTAssertTrue(participant.entanglementPartners.isEmpty)
    }

    // MARK: - Broadcast Configuration Tests

    func testBroadcastConfigurationCreation() {
        var config = BroadcastConfiguration()

        XCTAssertFalse(config.enabled)
        XCTAssertTrue(config.platforms.isEmpty)
        XCTAssertEqual(config.quality, .hd1080)
        XCTAssertTrue(config.biometricOverlay)
        XCTAssertEqual(config.privacyMode, .aggregated)
    }

    func testAllBroadcastPlatformsExist() {
        XCTAssertEqual(BroadcastConfiguration.BroadcastPlatform.allCases.count, 8)
        XCTAssertTrue(BroadcastConfiguration.BroadcastPlatform.allCases.contains(.youtube))
        XCTAssertTrue(BroadcastConfiguration.BroadcastPlatform.allCases.contains(.twitch))
        XCTAssertTrue(BroadcastConfiguration.BroadcastPlatform.allCases.contains(.facebook))
        XCTAssertTrue(BroadcastConfiguration.BroadcastPlatform.allCases.contains(.instagram))
        XCTAssertTrue(BroadcastConfiguration.BroadcastPlatform.allCases.contains(.tiktok))
        XCTAssertTrue(BroadcastConfiguration.BroadcastPlatform.allCases.contains(.custom))
        XCTAssertTrue(BroadcastConfiguration.BroadcastPlatform.allCases.contains(.webrtc))
        XCTAssertTrue(BroadcastConfiguration.BroadcastPlatform.allCases.contains(.ndi))
    }

    func testAllStreamQualitiesExist() {
        XCTAssertEqual(BroadcastConfiguration.StreamQuality.allCases.count, 5)
        XCTAssertTrue(BroadcastConfiguration.StreamQuality.allCases.contains(.mobile480))
        XCTAssertTrue(BroadcastConfiguration.StreamQuality.allCases.contains(.hd720))
        XCTAssertTrue(BroadcastConfiguration.StreamQuality.allCases.contains(.hd1080))
        XCTAssertTrue(BroadcastConfiguration.StreamQuality.allCases.contains(.uhd4k))
        XCTAssertTrue(BroadcastConfiguration.StreamQuality.allCases.contains(.uhd8k))
    }

    func testAllPrivacyModesExist() {
        XCTAssertEqual(BroadcastConfiguration.PrivacyMode.allCases.count, 3)
        XCTAssertTrue(BroadcastConfiguration.PrivacyMode.allCases.contains(.full))
        XCTAssertTrue(BroadcastConfiguration.PrivacyMode.allCases.contains(.aggregated))
        XCTAssertTrue(BroadcastConfiguration.PrivacyMode.allCases.contains(.anonymous))
    }

    // MARK: - Engine Constants Tests

    func testQuantumEngineConstants() {
        // Unlimited participants
        XCTAssertEqual(QuantumHealthBiofeedbackEngine.unlimitedParticipants, Int.max)
        // Entanglement threshold
        XCTAssertEqual(QuantumHealthBiofeedbackEngine.entanglementThreshold, 0.9)
        // Optimal breathing rate (6/min = 0.1Hz baroreflex)
        XCTAssertEqual(QuantumHealthBiofeedbackEngine.optimalBreathingRate, 6.0)
    }

    // MARK: - Integration Tests

    @MainActor
    func testQuantumHealthBiofeedbackEngineSessionLifecycle() async {
        let engine = QuantumHealthBiofeedbackEngine()

        // Create session
        let session = engine.createSession(
            name: "Test Session",
            type: .coherenceTraining
        )

        XCTAssertEqual(session.name, "Test Session")
        XCTAssertNotNil(engine.activeSession)

        // Join session
        let participant = engine.joinSession(
            sessionId: session.id,
            displayName: "Tester"
        )

        XCTAssertNotNil(participant)
        XCTAssertEqual(engine.totalParticipants, 1)

        // Leave session
        if let p = participant {
            engine.leaveSession(participantId: p.id)
        }

        XCTAssertNil(engine.activeSession) // Session should close when empty
    }

    // MARK: - Performance Tests

    func testQuantumHealthStateCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = QuantumHealthState()
            }
        }
    }

    func testFacialExpressionPolyvagalInferencePerformance() {
        var expression = FacialExpressionData()
        expression.joy = 0.8
        expression.cheekRaise = 0.7
        expression.lipCornerPull = 0.7
        expression.engagement = 0.9

        measure {
            for _ in 0..<10000 {
                _ = expression.inferredPolyvagalState
            }
        }
    }

    // MARK: - Edge Case Tests

    func testBodyMovementZeroTension() {
        let movement = BodyMovementData()
        XCTAssertEqual(movement.overallTension, 0)
    }

    func testBodyMovementMaxTension() {
        var movement = BodyMovementData()
        movement.ocularTension = 1.0
        movement.oralTension = 1.0
        movement.cervicalTension = 1.0
        movement.thoracicTension = 1.0
        movement.diaphragmaticTension = 1.0
        movement.abdominalTension = 1.0
        movement.pelvicTension = 1.0
        XCTAssertEqual(movement.overallTension, 1.0)
    }

    func testQuantumHealthScoreEdgeCases() {
        var state = QuantumHealthState()

        // Minimum values
        state.hrvSDNN = 0
        state.coherenceRatio = 0
        state.breathingRate = 0
        state.bloodOxygenation = 0
        state.coherenceAmplitude = 0
        state.phaseAlignment = 0
        state.entropyLevel = 1.0

        let minScore = state.quantumHealthScore
        XCTAssertGreaterThanOrEqual(minScore, 0)

        // Maximum values
        state.hrvSDNN = 200
        state.coherenceRatio = 1.0
        state.breathingRate = 6.0
        state.bloodOxygenation = 100
        state.coherenceAmplitude = 1.0
        state.phaseAlignment = 1.0
        state.entropyLevel = 0

        let maxScore = state.quantumHealthScore
        XCTAssertLessThanOrEqual(maxScore, 100)
    }

    // MARK: - Scientific Disclaimer Tests

    func testLongevityCompoundRequiresCaution() {
        let compound = LongevityCompound(
            name: "Rapamycin",
            category: .autophagy,
            mechanism: "mTOR inhibition",
            dosage: "Prescription only",
            timing: "Weekly",
            foodSources: [],
            targetedHallmarks: [.deregulatedNutrientSensing],
            evidenceLevel: .humanRCT,
            hrvImpact: 0.3,
            caution: "Prescription only. Immunosuppressant."
        )

        XCTAssertFalse(compound.caution.isEmpty)
        XCTAssertTrue(compound.caution.contains("Prescription"))
    }
}

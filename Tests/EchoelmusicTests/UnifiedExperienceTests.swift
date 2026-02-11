import XCTest
@testable import Echoelmusic

// MARK: - Unified Experience Tests
// Comprehensive tests for the Inclusive Design System, Feature Interconnection,
// Universal Accessibility, and Adaptive Navigation.

@MainActor
final class UnifiedExperienceTests: XCTestCase {

    // MARK: - Ability Profile Tests

    func testDefaultProfile() {
        let profile = AbilityProfile.standard
        XCTAssertEqual(profile.visionLevel, .full)
        XCTAssertEqual(profile.motorPrecision, .full)
        XCTAssertEqual(profile.hearingLevel, .full)
        XCTAssertEqual(profile.cognitiveLoad, .standard)
        XCTAssertEqual(profile.colorPerception, .full)
        XCTAssertEqual(profile.lightSensitivity, .normal)
        XCTAssertEqual(profile.tremorLevel, .none)
        XCTAssertEqual(profile.motionTolerance, .full)
        XCTAssertEqual(profile.contrastSensitivity, 1.0)
        XCTAssertFalse(profile.memorySupport)
    }

    func testLowVisionProfile() {
        let profile = AbilityProfile.lowVision
        XCTAssertEqual(profile.visionLevel, .low)
        XCTAssertEqual(profile.contrastSensitivity, 0.4)
        XCTAssertEqual(profile.motorPrecision, .full) // vision doesn't affect motor
    }

    func testBlindProfile() {
        let profile = AbilityProfile.blind
        XCTAssertEqual(profile.visionLevel, .none)
    }

    func testMotorLimitedProfile() {
        let profile = AbilityProfile.motorLimited
        XCTAssertEqual(profile.motorPrecision, .low)
        XCTAssertEqual(profile.reactionSpeed, .low)
        XCTAssertEqual(profile.tremorLevel, .moderate)
    }

    func testDeafProfile() {
        let profile = AbilityProfile.deaf
        XCTAssertEqual(profile.hearingLevel, .none)
    }

    func testCognitiveProfile() {
        let profile = AbilityProfile.cognitive
        XCTAssertEqual(profile.cognitiveLoad, .simplified)
        XCTAssertEqual(profile.attentionSpan, .moderate)
        XCTAssertTrue(profile.memorySupport)
    }

    func testPhotosensitiveProfile() {
        let profile = AbilityProfile.photosensitive
        XCTAssertEqual(profile.lightSensitivity, .epilepticRisk)
        XCTAssertEqual(profile.motionTolerance, .low)
    }

    func testElderlyProfile() {
        let profile = AbilityProfile.elderly
        XCTAssertEqual(profile.visionLevel, .moderate)
        XCTAssertEqual(profile.motorPrecision, .moderate)
        XCTAssertEqual(profile.hearingLevel, .moderate)
        XCTAssertEqual(profile.cognitiveLoad, .simplified)
        XCTAssertEqual(profile.frequencyRange, .reducedHigh)
    }

    func testAbilityLevelComparable() {
        XCTAssertTrue(AbilityProfile.AbilityLevel.none < .low)
        XCTAssertTrue(AbilityProfile.AbilityLevel.low < .moderate)
        XCTAssertTrue(AbilityProfile.AbilityLevel.moderate < .high)
        XCTAssertTrue(AbilityProfile.AbilityLevel.high < .full)
    }

    func testProfileEquatable() {
        let a = AbilityProfile.standard
        let b = AbilityProfile.standard
        XCTAssertEqual(a, b)

        var c = AbilityProfile.standard
        c.visionLevel = .low
        XCTAssertNotEqual(a, c)
    }

    func testProfileCodable() throws {
        let profile = AbilityProfile.elderly
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(AbilityProfile.self, from: data)
        XCTAssertEqual(profile, decoded)
    }

    // MARK: - Adaptive Design Tokens Tests

    func testDefaultTokens() {
        let tokens = AdaptiveDesignTokens.shared
        tokens.profile = .standard

        XCTAssertEqual(tokens.spacingXS, 4)
        XCTAssertEqual(tokens.spacingSM, 8)
        XCTAssertEqual(tokens.spacingMD, 16)
        XCTAssertEqual(tokens.spacingLG, 24)
        XCTAssertEqual(tokens.minTouchTarget, 44)
        XCTAssertTrue(tokens.animationEnabled)
        XCTAssertTrue(tokens.flashesAllowed)
        XCTAssertEqual(tokens.typeScaleFactor, 1.0)
        XCTAssertFalse(tokens.useHighContrast)
    }

    func testLowVisionTokens() {
        let tokens = AdaptiveDesignTokens.shared
        tokens.profile = .lowVision

        XCTAssertGreaterThan(tokens.typeScaleFactor, 1.0)
        XCTAssertTrue(tokens.useHighContrast)
        XCTAssertTrue(tokens.showLabelsAlways)
        XCTAssertGreaterThan(tokens.iconSize, 24)
    }

    func testMotorLimitedTokens() {
        let tokens = AdaptiveDesignTokens.shared
        tokens.profile = .motorLimited

        XCTAssertGreaterThanOrEqual(tokens.minTouchTarget, 64)
        XCTAssertGreaterThanOrEqual(tokens.preferredTouchTarget, 72)
        XCTAssertLessThan(tokens.dragSensitivity, 1.0)
        XCTAssertGreaterThan(tokens.longPressThreshold, 0.5)
    }

    func testPhotosensitiveTokens() {
        let tokens = AdaptiveDesignTokens.shared
        tokens.profile = .photosensitive

        XCTAssertFalse(tokens.flashesAllowed)
        XCTAssertFalse(tokens.animationEnabled)
        XCTAssertEqual(tokens.maxFlashFrequency, 0)
    }

    func testCognitiveTokens() {
        let tokens = AdaptiveDesignTokens.shared
        tokens.profile = .cognitive

        XCTAssertEqual(tokens.preferredColumns, 1)
        XCTAssertTrue(tokens.showLabelsAlways)
    }

    func testSpacingScalesWithMotor() {
        let tokens = AdaptiveDesignTokens.shared
        tokens.profile = .standard
        let normalSpacing = tokens.spacingMD

        tokens.profile = .motorLimited
        XCTAssertGreaterThan(tokens.spacingMD, normalSpacing)
    }

    func testBorderWidthScalesWithVision() {
        let tokens = AdaptiveDesignTokens.shared
        tokens.profile = .standard
        let normalBorder = tokens.borderWidth

        tokens.profile = .lowVision
        XCTAssertGreaterThanOrEqual(tokens.borderWidth, normalBorder)
    }

    // MARK: - Adaptive Color Tests

    func testPrimaryColorAdaptsToColorPerception() {
        let fullColor = AdaptiveColor.primary(for: .standard)
        let protanColor = AdaptiveColor.primary(for: AbilityProfile.lowVision)

        // Different profiles should potentially yield different colors
        XCTAssertNotNil(fullColor)
        XCTAssertNotNil(protanColor)
    }

    func testCoherenceColorRange() {
        let low = AdaptiveColor.coherence(0.1, for: .standard)
        let mid = AdaptiveColor.coherence(0.5, for: .standard)
        let high = AdaptiveColor.coherence(0.9, for: .standard)

        XCTAssertNotNil(low)
        XCTAssertNotNil(mid)
        XCTAssertNotNil(high)
    }

    func testStatusColorsForAllPerceptions() {
        for perception in AbilityProfile.ColorPerception.allCases {
            var profile = AbilityProfile.standard
            profile.colorPerception = perception

            XCTAssertNotNil(AdaptiveColor.success(for: profile))
            XCTAssertNotNil(AdaptiveColor.warning(for: profile))
            XCTAssertNotNil(AdaptiveColor.error(for: profile))
            XCTAssertNotNil(AdaptiveColor.primary(for: profile))
            XCTAssertNotNil(AdaptiveColor.secondary(for: profile))
        }
    }

    // MARK: - Semantic Icon Tests

    func testStatusIconsHaveDistinctShapes() {
        let excellent = SemanticIcon.status(.excellent)
        let good = SemanticIcon.status(.good)
        let moderate = SemanticIcon.status(.moderate)
        let low = SemanticIcon.status(.low)
        let critical = SemanticIcon.status(.critical)

        // Each status level should have a different icon shape
        let icons = [excellent.name, good.name, moderate.name, low.name, critical.name]
        let uniqueIcons = Set(icons)
        XCTAssertEqual(uniqueIcons.count, 5, "Each status level should have a unique icon")
    }

    // MARK: - Feature Interconnection Engine Tests

    func testDefaultConnections() {
        let engine = FeatureInterconnectionEngine.shared
        XCTAssertFalse(engine.connections.isEmpty, "Should have default connections")
    }

    func testAllDomainsActive() {
        let engine = FeatureInterconnectionEngine.shared
        for domain in FeatureDomain.allCases {
            XCTAssertTrue(engine.activeDomains.contains(domain))
        }
    }

    func testEventEmission() {
        let engine = FeatureInterconnectionEngine.shared
        engine.emit(.bpmChanged(140))
        XCTAssertEqual(engine.currentBPM, 140)
    }

    func testHeartRateEvent() {
        let engine = FeatureInterconnectionEngine.shared
        engine.emit(.heartRateUpdated(85))
        XCTAssertEqual(engine.currentHeartRate, 85)
    }

    func testCoherenceEvent() {
        let engine = FeatureInterconnectionEngine.shared
        engine.emit(.coherenceUpdated(0.85))
        XCTAssertEqual(engine.currentCoherence, 0.85)
    }

    func testBioStateEvent() {
        let engine = FeatureInterconnectionEngine.shared
        engine.emit(.bioStateChanged(.flow))
        XCTAssertEqual(engine.currentBioState, .flow)
    }

    func testSessionStateEvent() {
        let engine = FeatureInterconnectionEngine.shared
        engine.emit(.sessionStateChanged(.active))
        XCTAssertEqual(engine.currentSessionState, .active)
    }

    func testToggleConnection() {
        let engine = FeatureInterconnectionEngine.shared
        guard let first = engine.connections.first else { return }

        let source = first.source
        let target = first.target
        let wasActive = first.isActive

        engine.toggleConnection(source: source, target: target)
        let updated = engine.connections.first { $0.source == source && $0.target == target }
        XCTAssertNotEqual(updated?.isActive, wasActive)

        // Toggle back
        engine.toggleConnection(source: source, target: target)
    }

    func testConnectionStrength() {
        let engine = FeatureInterconnectionEngine.shared
        guard let first = engine.connections.first else { return }

        engine.setConnectionStrength(source: first.source, target: first.target, strength: 0.5)
        let updated = engine.connections.first { $0.source == first.source && $0.target == first.target }
        XCTAssertEqual(updated?.strength, 0.5)

        // Reset
        engine.setConnectionStrength(source: first.source, target: first.target, strength: 1.0)
    }

    func testConnectionStrengthClamping() {
        let engine = FeatureInterconnectionEngine.shared
        guard let first = engine.connections.first else { return }

        engine.setConnectionStrength(source: first.source, target: first.target, strength: -0.5)
        let updated = engine.connections.first { $0.source == first.source && $0.target == first.target }
        XCTAssertEqual(updated?.strength, 0.0)

        engine.setConnectionStrength(source: first.source, target: first.target, strength: 1.5)
        let updated2 = engine.connections.first { $0.source == first.source && $0.target == first.target }
        XCTAssertEqual(updated2?.strength, 1.0)
    }

    func testDomainActivation() {
        let engine = FeatureInterconnectionEngine.shared
        engine.setDomainActive(.quantum, active: false)
        XCTAssertFalse(engine.activeDomains.contains(.quantum))

        engine.setDomainActive(.quantum, active: true)
        XCTAssertTrue(engine.activeDomains.contains(.quantum))
    }

    func testConnectionsForDomain() {
        let engine = FeatureInterconnectionEngine.shared
        let bioConnections = engine.connectionsFor(.biofeedback)
        XCTAssertFalse(bioConnections.isEmpty, "Biofeedback should have connections")
    }

    func testInterconnectionHealth() {
        let engine = FeatureInterconnectionEngine.shared
        engine.applyPreset(.full)
        XCTAssertEqual(engine.interconnectionHealth, 1.0)
    }

    func testPresetMinimal() {
        let engine = FeatureInterconnectionEngine.shared
        engine.applyPreset(.minimal)
        XCTAssertLessThan(engine.interconnectionHealth, 1.0)

        // Reset
        engine.applyPreset(.full)
    }

    func testPresetMeditation() {
        let engine = FeatureInterconnectionEngine.shared
        engine.applyPreset(.meditation)

        // Bio→audio should be active in meditation
        let bioToAudio = engine.connections.first { $0.source == .biofeedback && $0.target == .audio }
        XCTAssertTrue(bioToAudio?.isActive ?? false)

        // Reset
        engine.applyPreset(.full)
    }

    func testEventLogGrowth() {
        let engine = FeatureInterconnectionEngine.shared
        let initialCount = engine.eventLog.count

        engine.emit(.beatDetected(beatPhase: 0.5))
        XCTAssertGreaterThan(engine.eventLog.count, initialCount)
    }

    func testEventLogTrimming() {
        let engine = FeatureInterconnectionEngine.shared

        // Emit many events to trigger trimming
        for i in 0..<250 {
            engine.emit(.bpmChanged(Double(60 + i)))
        }

        XCTAssertLessThanOrEqual(engine.eventLog.count, 200)
    }

    func testFeatureDomainIcons() {
        for domain in FeatureDomain.allCases {
            XCTAssertFalse(domain.icon.isEmpty, "\(domain) should have an icon")
        }
    }

    func testFeatureDomainDefaultTargets() {
        // Biofeedback should connect to many things
        XCTAssertFalse(FeatureDomain.biofeedback.defaultTargets.isEmpty)
        XCTAssertTrue(FeatureDomain.biofeedback.defaultTargets.contains(.audio))

        // Audio should connect to video and visualization
        XCTAssertTrue(FeatureDomain.audio.defaultTargets.contains(.video))
        XCTAssertTrue(FeatureDomain.audio.defaultTargets.contains(.visualization))
    }

    // MARK: - Universal Accessibility Engine Tests

    func testDefaultAccessibilityState() {
        let engine = UniversalAccessibilityEngine.shared
        XCTAssertEqual(engine.primaryInteractionMode, .touch)
        XCTAssertTrue(engine.availableInteractionModes.contains(.touch))
        XCTAssertNil(engine.guidedStep)
    }

    func testComplexityLevelOrdering() {
        XCTAssertTrue(UniversalAccessibilityEngine.ComplexityLevel.minimal < .simple)
        XCTAssertTrue(UniversalAccessibilityEngine.ComplexityLevel.simple < .standard)
        XCTAssertTrue(UniversalAccessibilityEngine.ComplexityLevel.standard < .full)
        XCTAssertTrue(UniversalAccessibilityEngine.ComplexityLevel.full < .expert)
    }

    func testFeatureVisibility() {
        let engine = UniversalAccessibilityEngine.shared

        engine.complexityLevel = .minimal
        XCTAssertTrue(engine.shouldShowFeature(.playPause))
        XCTAssertTrue(engine.shouldShowFeature(.wellness))
        XCTAssertFalse(engine.shouldShowFeature(.nodeEditor))
        XCTAssertFalse(engine.shouldShowFeature(.developer))

        engine.complexityLevel = .full
        XCTAssertTrue(engine.shouldShowFeature(.playPause))
        XCTAssertTrue(engine.shouldShowFeature(.nodeEditor))
        XCTAssertTrue(engine.shouldShowFeature(.mixing))

        engine.complexityLevel = .expert
        XCTAssertTrue(engine.shouldShowFeature(.developer))
    }

    func testPresetProfileApplication() {
        let engine = UniversalAccessibilityEngine.shared

        engine.applyPresetProfile(.lowVision)
        XCTAssertEqual(engine.profile.visionLevel, .low)

        engine.applyPresetProfile(.motorLimited)
        XCTAssertEqual(engine.profile.motorPrecision, .low)

        engine.applyPresetProfile(.deaf)
        XCTAssertEqual(engine.profile.hearingLevel, .none)

        engine.applyPresetProfile(.standard)
        XCTAssertEqual(engine.profile.visionLevel, .full)
    }

    func testAnnouncementSetting() {
        let engine = UniversalAccessibilityEngine.shared
        engine.announce("Test announcement")
        XCTAssertEqual(engine.pendingAnnouncement, "Test announcement")
    }

    func testBeatIndicator() {
        let engine = UniversalAccessibilityEngine.shared

        // Only shows for hearing impaired
        engine.applyPresetProfile(.deaf)
        engine.indicateBeat()
        XCTAssertTrue(engine.visualBeatIndicator)

        // Should auto-hide (async)
        let expectation = XCTestExpectation(description: "Beat indicator hides")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertFalse(engine.visualBeatIndicator)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        engine.applyPresetProfile(.standard)
    }

    func testInteractionModeIcons() {
        for mode in InteractionMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty)
            XCTAssertFalse(mode.description.isEmpty)
        }
    }

    func testProfilePresetIcons() {
        for preset in UniversalAccessibilityEngine.ProfilePreset.allCases {
            XCTAssertFalse(preset.icon.isEmpty)
        }
    }

    // MARK: - Adaptive Navigation Tests

    func testDefaultNavigation() {
        let nav = AdaptiveNavigationManager.shared
        XCTAssertEqual(nav.currentWorkspace, .home)
        XCTAssertEqual(nav.navigationContext, .exploring)
        XCTAssertFalse(nav.navigationHistory.isEmpty)
    }

    func testNavigateTo() {
        let nav = AdaptiveNavigationManager.shared
        nav.navigateTo(.audio)
        XCTAssertEqual(nav.currentWorkspace, .audio)
        XCTAssertTrue(nav.navigationHistory.contains(.audio))
    }

    func testGoBack() {
        let nav = AdaptiveNavigationManager.shared
        nav.navigateTo(.home)
        nav.navigateTo(.audio)
        nav.navigateTo(.video)
        nav.goBack()
        XCTAssertEqual(nav.currentWorkspace, .audio)
    }

    func testContextSwitching() {
        let nav = AdaptiveNavigationManager.shared
        nav.switchContext(.meditating)
        XCTAssertEqual(nav.navigationContext, .meditating)

        // Meditating context should include wellness
        XCTAssertTrue(nav.visibleWorkspaces.contains(.wellness))

        nav.switchContext(.exploring)
    }

    func testVisibleWorkspacesFilteredByComplexity() {
        let nav = AdaptiveNavigationManager.shared
        let accessibility = UniversalAccessibilityEngine.shared

        accessibility.complexityLevel = .minimal
        let minimalWorkspaces = nav.visibleWorkspaces
        XCTAssertTrue(minimalWorkspaces.contains(.home))
        XCTAssertTrue(minimalWorkspaces.contains(.wellness))

        accessibility.complexityLevel = .full
        let fullWorkspaces = nav.visibleWorkspaces
        XCTAssertGreaterThanOrEqual(fullWorkspaces.count, minimalWorkspaces.count)
    }

    func testVoiceCommandNavigation() {
        let nav = AdaptiveNavigationManager.shared
        nav.handleVoiceCommand("go to audio")
        XCTAssertEqual(nav.currentWorkspace, .audio)

        nav.handleVoiceCommand("back")
    }

    func testBreadcrumbs() {
        let nav = AdaptiveNavigationManager.shared
        nav.navigateTo(.home)
        XCTAssertEqual(nav.breadcrumbs, ["Home"])

        nav.navigateTo(.audio)
        XCTAssertEqual(nav.breadcrumbs, ["Home", "Audio"])
    }

    func testNavigationHistoryLimit() {
        let nav = AdaptiveNavigationManager.shared
        // Navigate many times to test history trimming
        for _ in 0..<25 {
            nav.navigateTo(.audio)
            nav.navigateTo(.video)
        }
        XCTAssertLessThanOrEqual(nav.navigationHistory.count, 20)
    }

    // MARK: - Workspace Tests

    func testAllWorkspacesHaveIcons() {
        for workspace in AdaptiveWorkspace.allCases {
            XCTAssertFalse(workspace.icon.isEmpty, "\(workspace) should have an icon")
        }
    }

    func testAllWorkspacesHaveColors() {
        for workspace in AdaptiveWorkspace.allCases {
            XCTAssertNotNil(workspace.color)
        }
    }

    func testAllWorkspacesHaveVoiceCommands() {
        for workspace in AdaptiveWorkspace.allCases {
            XCTAssertFalse(workspace.voiceCommand.isEmpty, "\(workspace) should have a voice command")
        }
    }

    func testContextAvailableWorkspaces() {
        for context in NavigationContext.allCases {
            XCTAssertFalse(context.availableWorkspaces.isEmpty, "\(context) should have workspaces")
            XCTAssertTrue(context.availableWorkspaces.contains(.home), "\(context) should always include home")
        }
    }

    // MARK: - Onboarding Assessment Tests

    func testAssessmentQuestions() {
        let questions = AbilityAssessment.questions
        XCTAssertGreaterThanOrEqual(questions.count, 4, "Should have at least 4 assessment questions")

        for question in questions {
            XCTAssertFalse(question.title.isEmpty)
            XCTAssertFalse(question.description.isEmpty)
            XCTAssertFalse(question.icon.isEmpty)
            XCTAssertGreaterThanOrEqual(question.options.count, 2, "Each question needs at least 2 options")
        }
    }

    func testAssessmentOptionAppliesProfile() {
        var profile = AbilityProfile.standard
        let questions = AbilityAssessment.questions

        // Apply the "larger & clearer" option from vision question
        if let visionQuestion = questions.first(where: { $0.domain == .vision }),
           let largerOption = visionQuestion.options.first(where: { $0.label == "Larger & clearer" }) {
            largerOption.profileAdjustment(&profile)
            XCTAssertEqual(profile.visionLevel, .moderate)
        }
    }

    // MARK: - Integration Tests

    func testProfileChangePropagates() {
        let accessibility = UniversalAccessibilityEngine.shared
        let tokens = AdaptiveDesignTokens.shared

        accessibility.profile = .motorLimited
        XCTAssertGreaterThanOrEqual(tokens.minTouchTarget, 64)

        accessibility.profile = .standard
        XCTAssertEqual(tokens.minTouchTarget, 44)
    }

    func testEventBusToStateCache() {
        let engine = FeatureInterconnectionEngine.shared

        // Emit multiple events
        engine.emit(.bpmChanged(128))
        engine.emit(.heartRateUpdated(80))
        engine.emit(.coherenceUpdated(0.9))
        engine.emit(.breathingPhaseChanged(0.5))
        engine.emit(.audioLevelChanged(0.7))

        // State cache should be updated
        XCTAssertEqual(engine.currentBPM, 128)
        XCTAssertEqual(engine.currentHeartRate, 80)
        XCTAssertEqual(engine.currentCoherence, 0.9)
        XCTAssertEqual(engine.currentBreathingPhase, 0.5)
        XCTAssertEqual(engine.currentAudioLevel, 0.7)
    }

    func testFullSystemIntegration() {
        // Test that all systems initialize and work together
        let tokens = AdaptiveDesignTokens.shared
        let interconnection = FeatureInterconnectionEngine.shared
        let accessibility = UniversalAccessibilityEngine.shared
        let navigation = AdaptiveNavigationManager.shared

        // Set profile
        accessibility.profile = .standard
        XCTAssertTrue(tokens.animationEnabled)

        // Navigate
        navigation.navigateTo(.wellness)
        XCTAssertEqual(navigation.currentWorkspace, .wellness)

        // Emit bio event
        interconnection.emit(.coherenceUpdated(0.85))
        XCTAssertEqual(interconnection.currentCoherence, 0.85)

        // Switch context
        navigation.switchContext(.meditating)
        XCTAssertTrue(navigation.visibleWorkspaces.contains(.wellness))

        // Apply meditation preset
        interconnection.applyPreset(.meditation)
        let bioToAudio = interconnection.connections.first { $0.source == .biofeedback && $0.target == .audio }
        XCTAssertTrue(bioToAudio?.isActive ?? false)

        // Clean up
        navigation.navigateTo(.home)
        navigation.switchContext(.exploring)
        interconnection.applyPreset(.full)
    }

    // MARK: - Event Log Entry Tests

    func testEventLogEntryDescriptions() {
        let bpmEntry = EventLogEntry(event: .bpmChanged(120), timestamp: Date())
        XCTAssertTrue(bpmEntry.description.contains("120"))

        let hrEntry = EventLogEntry(event: .heartRateUpdated(72), timestamp: Date())
        XCTAssertTrue(hrEntry.description.contains("72"))

        let coherenceEntry = EventLogEntry(event: .coherenceUpdated(0.85), timestamp: Date())
        XCTAssertTrue(coherenceEntry.description.contains("85"))
    }

    // MARK: - Feature Complexity Tests

    func testFeatureComplexityLevels() {
        // Minimal features should have lowest complexity
        XCTAssertEqual(UniversalAccessibilityEngine.FeatureComplexity.playPause.minimumLevel, .minimal)
        XCTAssertEqual(UniversalAccessibilityEngine.FeatureComplexity.wellness.minimumLevel, .minimal)

        // Simple features
        XCTAssertEqual(UniversalAccessibilityEngine.FeatureComplexity.bioMetrics.minimumLevel, .simple)

        // Standard features
        XCTAssertEqual(UniversalAccessibilityEngine.FeatureComplexity.effects.minimumLevel, .standard)

        // Full features
        XCTAssertEqual(UniversalAccessibilityEngine.FeatureComplexity.nodeEditor.minimumLevel, .full)

        // Expert features
        XCTAssertEqual(UniversalAccessibilityEngine.FeatureComplexity.developer.minimumLevel, .expert)
    }

    // MARK: - Connection Mapping Tests

    func testConnectionMappingTypes() {
        let mappings: [FeatureConnection.ConnectionMapping] = [
            .direct, .scaled, .inverted, .gated, .smoothed, .quantized
        ]
        XCTAssertEqual(mappings.count, 6)
    }

    // MARK: - Interconnection Preset Tests

    func testAllPresetsApply() {
        let engine = FeatureInterconnectionEngine.shared

        for preset in FeatureInterconnectionEngine.InterconnectionPreset.allCases {
            engine.applyPreset(preset)
            // Should not crash and should have valid state
            XCTAssertGreaterThanOrEqual(engine.interconnectionHealth, 0)
            XCTAssertLessThanOrEqual(engine.interconnectionHealth, 1.0)
        }

        engine.applyPreset(.full)
    }

    func testPerformancePresetBoostsAudio() {
        let engine = FeatureInterconnectionEngine.shared
        engine.applyPreset(.performance)

        let audioConnections = engine.connections.filter { $0.target == .audio }
        for conn in audioConnections where conn.isActive {
            XCTAssertEqual(conn.strength, 1.0)
        }

        engine.applyPreset(.full)
    }

    func testStudioPresetFocusesAudio() {
        let engine = FeatureInterconnectionEngine.shared
        engine.applyPreset(.studio)

        let audioConnections = engine.connections.filter { $0.source == .audio || $0.target == .audio }
        for conn in audioConnections where conn.isActive {
            XCTAssertEqual(conn.strength, 1.0)
        }

        engine.applyPreset(.full)
    }
}

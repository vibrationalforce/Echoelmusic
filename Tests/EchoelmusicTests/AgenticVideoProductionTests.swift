import XCTest
@testable import Echoelmusic

/// Comprehensive tests for the Agentic Video Production Pipeline
/// Tests Model Orchestrator, Character Drift Detection, Agentic Director, and Timeline Assembler
final class AgenticVideoProductionTests: XCTestCase {

    // MARK: - Model Orchestrator Tests

    func testModelCapabilitiesSora2() {
        let capabilities = VideoGenerationModel.sora2.capabilities
        XCTAssertEqual(capabilities.physicsRealism, 0.98, accuracy: 0.01)
        XCTAssertEqual(capabilities.temporalConsistency, 0.92, accuracy: 0.01)
        XCTAssertEqual(capabilities.maxDuration, 60.0, accuracy: 0.1)
        XCTAssertTrue(capabilities.specialFeatures.contains("physics-accurate"))
        XCTAssertTrue(capabilities.specialFeatures.contains("world-simulation"))
    }

    func testModelCapabilitiesKling2() {
        let capabilities = VideoGenerationModel.kling2.capabilities
        XCTAssertEqual(capabilities.temporalConsistency, 0.96, accuracy: 0.01)
        XCTAssertEqual(capabilities.maxDuration, 120.0, accuracy: 0.1)
        XCTAssertTrue(capabilities.specialFeatures.contains("temporal-coherence"))
        XCTAssertTrue(capabilities.specialFeatures.contains("lip-sync"))
    }

    func testModelCapabilitiesRunwayGen4() {
        let capabilities = VideoGenerationModel.runwayGen4.capabilities
        XCTAssertEqual(capabilities.stylisticControl, 0.95, accuracy: 0.01)
        XCTAssertTrue(capabilities.specialFeatures.contains("style-reference"))
        XCTAssertTrue(capabilities.specialFeatures.contains("camera-presets"))
    }

    func testModelCapabilitiesHybrid() {
        let capabilities = VideoGenerationModel.hybrid.capabilities
        XCTAssertGreaterThan(capabilities.physicsRealism, 0.9)
        XCTAssertGreaterThan(capabilities.temporalConsistency, 0.9)
        XCTAssertGreaterThan(capabilities.stylisticControl, 0.9)
        XCTAssertEqual(capabilities.maxDuration, 300.0, accuracy: 0.1)
    }

    func testAllModelsHaveEndpoints() {
        for model in VideoGenerationModel.allCases {
            XCTAssertFalse(model.apiEndpoint.isEmpty, "\(model.rawValue) should have an API endpoint")
        }
    }

    // MARK: - Suitability Score Tests

    func testSuitabilityScoreForPhysicsRequest() {
        var request = VideoGenerationRequest(prompt: "Physics simulation", duration: 10.0)
        request.requiresPhysicsRealism = true

        let sora2Score = VideoGenerationModel.sora2.capabilities.suitabilityScore(for: request)
        let localScore = VideoGenerationModel.localDiffusion.capabilities.suitabilityScore(for: request)

        XCTAssertGreaterThan(sora2Score, localScore, "Sora 2 should score higher for physics requests")
    }

    func testSuitabilityScoreForStyleRequest() {
        var request = VideoGenerationRequest(prompt: "Artistic video", duration: 5.0)
        request.styleReference = URL(string: "https://example.com/style.jpg")

        let runwayScore = VideoGenerationModel.runwayGen4.capabilities.suitabilityScore(for: request)
        XCTAssertGreaterThan(runwayScore, 0.5, "Runway should score well for style requests")
    }

    func testSuitabilityScoreForLongDuration() {
        let request = VideoGenerationRequest(prompt: "Long video", duration: 90.0)

        let kling2Caps = VideoGenerationModel.kling2.capabilities
        let runwayCaps = VideoGenerationModel.runwayGen4.capabilities

        let klingScore = kling2Caps.suitabilityScore(for: request)
        let runwayScore = runwayCaps.suitabilityScore(for: request)

        // Kling supports 120s, Runway only 16s
        XCTAssertGreaterThan(klingScore, runwayScore, "Kling should score higher for long duration")
    }

    func testSuitabilityScoreWithBudgetConstraint() {
        var request = VideoGenerationRequest(prompt: "Budget video", duration: 10.0)
        request.budgetLimit = 0.5  // Very low budget

        let localScore = VideoGenerationModel.localDiffusion.capabilities.suitabilityScore(for: request)
        let sora2Score = VideoGenerationModel.sora2.capabilities.suitabilityScore(for: request)

        XCTAssertGreaterThan(localScore, sora2Score * 0.5, "Local model should not be penalized heavily for free")
    }

    func testSuitabilityScoreWithRequiredFeatures() {
        var request = VideoGenerationRequest(prompt: "Lip sync video", duration: 5.0)
        request.requiredFeatures = ["lip-sync", "face-swap"]

        let klingScore = VideoGenerationModel.kling2.capabilities.suitabilityScore(for: request)
        XCTAssertGreaterThan(klingScore, 0.6, "Kling should score well with matching features")
    }

    // MARK: - Video Generation Request Tests

    func testVideoGenerationRequestDefaults() {
        let request = VideoGenerationRequest(prompt: "Test", duration: 5.0)

        XCTAssertEqual(request.prompt, "Test")
        XCTAssertEqual(request.duration, 5.0)
        XCTAssertEqual(request.resolution, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(request.fps, 30.0)
        XCTAssertFalse(request.requiresPhysicsRealism)
        XCTAssertTrue(request.characterReferences.isEmpty)
        XCTAssertEqual(request.priority, .normal)
    }

    func testVideoGenerationRequestAspectRatio() {
        let request = VideoGenerationRequest(
            prompt: "Test",
            duration: 5.0,
            resolution: CGSize(width: 1920, height: 1080)
        )
        XCTAssertEqual(request.aspectRatio, 16.0/9.0, accuracy: 0.01)
    }

    // MARK: - Character Reference Tests

    func testCharacterReferenceCreation() {
        let character = CharacterReference(name: "Hero")

        XCTAssertEqual(character.name, "Hero")
        XCTAssertTrue(character.referenceImages.isEmpty)
        XCTAssertNil(character.faceEmbedding)
        XCTAssertNil(character.bodyProportions)
    }

    func testBodyProportionsAllTypes() {
        for bodyType in BodyProportions.BodyType.allCases {
            let proportions = BodyProportions(
                height: 0.5,
                shoulderWidth: 0.3,
                armLength: 0.4,
                legLength: 0.5,
                headSize: 0.15,
                bodyType: bodyType
            )
            XCTAssertEqual(proportions.bodyType, bodyType)
        }
    }

    // MARK: - Scene Context Tests

    func testSceneContextTimeOfDay() {
        for timeOfDay in SceneContext.TimeOfDay.allCases {
            XCTAssertFalse(timeOfDay.rawValue.isEmpty)
        }
        XCTAssertEqual(SceneContext.TimeOfDay.allCases.count, 8)
    }

    func testSceneContextWeather() {
        for weather in SceneContext.Weather.allCases {
            XCTAssertFalse(weather.rawValue.isEmpty)
        }
        XCTAssertEqual(SceneContext.Weather.allCases.count, 8)
    }

    func testSceneContextMood() {
        for mood in SceneContext.SceneMood.allCases {
            XCTAssertFalse(mood.rawValue.isEmpty)
        }
        XCTAssertEqual(SceneContext.SceneMood.allCases.count, 8)
    }

    func testCameraMovementTypes() {
        for movementType in SceneContext.CameraMovement.MovementType.allCases {
            XCTAssertFalse(movementType.rawValue.isEmpty)
        }
        XCTAssertEqual(SceneContext.CameraMovement.MovementType.allCases.count, 9)
    }

    // MARK: - Story Metadata Tests

    func testStoryMetadataGenres() {
        XCTAssertEqual(StoryMetadata.Genre.allCases.count, 14)
        XCTAssertTrue(StoryMetadata.Genre.allCases.contains(.drama))
        XCTAssertTrue(StoryMetadata.Genre.allCases.contains(.meditation))
    }

    func testNarrativeStructures() {
        XCTAssertEqual(StoryMetadata.NarrativeStructure.allCases.count, 7)
        XCTAssertTrue(StoryMetadata.NarrativeStructure.allCases.contains(.threeAct))
        XCTAssertTrue(StoryMetadata.NarrativeStructure.allCases.contains(.herosJourney))
    }

    func testStoryBeatTypes() {
        XCTAssertEqual(StoryMetadata.StoryBeat.BeatType.allCases.count, 11)
        XCTAssertTrue(StoryMetadata.StoryBeat.BeatType.allCases.contains(.climax))
        XCTAssertTrue(StoryMetadata.StoryBeat.BeatType.allCases.contains(.plotTwist))
    }

    func testCharacterArcTypes() {
        XCTAssertEqual(StoryMetadata.CharacterArc.ArcType.allCases.count, 7)
        XCTAssertTrue(StoryMetadata.CharacterArc.ArcType.allCases.contains(.transformation))
        XCTAssertTrue(StoryMetadata.CharacterArc.ArcType.allCases.contains(.redemption))
    }

    func testPaceTypes() {
        XCTAssertEqual(StoryMetadata.PaceProfile.Pace.allCases.count, 5)
        for pace in StoryMetadata.PaceProfile.Pace.allCases {
            XCTAssertFalse(pace.rawValue.isEmpty)
        }
    }

    func testCinematicLooks() {
        XCTAssertEqual(StoryMetadata.VisualStyle.CinematicLook.allCases.count, 7)
        XCTAssertTrue(StoryMetadata.VisualStyle.CinematicLook.allCases.contains(.noir))
        XCTAssertTrue(StoryMetadata.VisualStyle.CinematicLook.allCases.contains(.futuristic))
    }

    // MARK: - Character Drift Detector Tests

    @MainActor
    func testDriftDetectorSingleton() {
        let detector1 = CharacterDriftDetector.shared
        let detector2 = CharacterDriftDetector.shared
        XCTAssertTrue(detector1 === detector2, "Should be same instance")
    }

    @MainActor
    func testDriftAnalysisWithNoReferences() async {
        let detector = CharacterDriftDetector.shared
        let score = await detector.analyzeConsistency(videoURL: nil, references: [])
        XCTAssertEqual(score, 1.0, "Empty references should return perfect score")
    }

    @MainActor
    func testDriftAnalysisIssueTypes() {
        for issueType in CharacterDriftDetector.DriftAnalysis.DriftIssue.IssueType.allCases {
            XCTAssertFalse(issueType.rawValue.isEmpty)
        }
        XCTAssertEqual(CharacterDriftDetector.DriftAnalysis.DriftIssue.IssueType.allCases.count, 7)
    }

    // MARK: - Volumetric Content Pipeline Tests

    @MainActor
    func testVolumetricPipelineSingleton() {
        let pipeline1 = VolumetricContentPipeline.shared
        let pipeline2 = VolumetricContentPipeline.shared
        XCTAssertTrue(pipeline1 === pipeline2, "Should be same instance")
    }

    func testVolumetricAssetTypes() {
        XCTAssertEqual(VolumetricContentPipeline.VolumetricAsset.AssetType.allCases.count, 7)
        for assetType in VolumetricContentPipeline.VolumetricAsset.AssetType.allCases {
            XCTAssertFalse(assetType.rawValue.isEmpty)
        }
    }

    func testPointCloudFormats() {
        XCTAssertEqual(VolumetricContentPipeline.PointCloudFormat.allCases.count, 4)
        XCTAssertTrue(VolumetricContentPipeline.PointCloudFormat.allCases.contains(.ply))
        XCTAssertTrue(VolumetricContentPipeline.PointCloudFormat.allCases.contains(.e57))
    }

    func testBoundingBoxCalculations() {
        let bbox = VolumetricContentPipeline.VolumetricAsset.BoundingBox(
            min: SIMD3<Float>(-1, -2, -3),
            max: SIMD3<Float>(1, 2, 3)
        )

        XCTAssertEqual(bbox.center.x, 0, accuracy: 0.001)
        XCTAssertEqual(bbox.center.y, 0, accuracy: 0.001)
        XCTAssertEqual(bbox.center.z, 0, accuracy: 0.001)

        XCTAssertEqual(bbox.size.x, 2, accuracy: 0.001)
        XCTAssertEqual(bbox.size.y, 4, accuracy: 0.001)
        XCTAssertEqual(bbox.size.z, 6, accuracy: 0.001)
    }

    func testCompositionLayerBlendModes() {
        XCTAssertEqual(VolumetricContentPipeline.VolumetricComposition.CompositionLayer.BlendMode3D.allCases.count, 5)
    }

    func testLightSourceTypes() {
        XCTAssertEqual(VolumetricContentPipeline.VolumetricComposition.LightSource.LightType.allCases.count, 5)
    }

    func testRenderQualities() {
        XCTAssertEqual(VolumetricContentPipeline.VolumetricComposition.OutputSettings.RenderQuality.allCases.count, 3)
    }

    @MainActor
    func testCreateComposition() {
        let pipeline = VolumetricContentPipeline.shared
        let composition = pipeline.createComposition(name: "Test Composition")

        XCTAssertEqual(composition.name, "Test Composition")
        XCTAssertTrue(composition.layers.isEmpty)
        XCTAssertEqual(composition.lighting.count, 1)
        XCTAssertEqual(composition.camera.fov, 60)
    }

    // MARK: - Agentic Director Tests

    @MainActor
    func testAgenticDirectorSingleton() {
        let director1 = AgenticDirector.shared
        let director2 = AgenticDirector.shared
        XCTAssertTrue(director1 === director2, "Should be same instance")
    }

    func testDirectorDecisionTypes() {
        XCTAssertEqual(AgenticDirector.DirectorDecision.DecisionType.allCases.count, 10)
        for decisionType in AgenticDirector.DirectorDecision.DecisionType.allCases {
            XCTAssertFalse(decisionType.rawValue.isEmpty)
        }
    }

    @MainActor
    func testDirectorInitialState() {
        let director = AgenticDirector.shared
        XCTAssertFalse(director.isDirecting)
        XCTAssertEqual(director.confidenceThreshold, 0.75)
    }

    @MainActor
    func testStoryStateDefaults() {
        let state = AgenticDirector.StoryState()
        XCTAssertEqual(state.currentBeatIndex, 0)
        XCTAssertEqual(state.emotionalIntensity, 0.5)
        XCTAssertEqual(state.tensionLevel, 0.3)
        XCTAssertEqual(state.audienceEngagement, 0.7)
        XCTAssertEqual(state.pacingMultiplier, 1.0)
    }

    // MARK: - Timeline Assembler Tests

    @MainActor
    func testTimelineAssemblerSingleton() {
        let assembler1 = TimelineAssembler.shared
        let assembler2 = TimelineAssembler.shared
        XCTAssertTrue(assembler1 === assembler2, "Should be same instance")
    }

    func testTransitionTypes() {
        XCTAssertEqual(TimelineAssembler.AssembledTimeline.SegmentTransition.TransitionType.allCases.count, 8)
        XCTAssertTrue(TimelineAssembler.AssembledTimeline.SegmentTransition.TransitionType.allCases.contains(.dissolve))
        XCTAssertTrue(TimelineAssembler.AssembledTimeline.SegmentTransition.TransitionType.allCases.contains(.match_cut))
    }

    func testEasingTypes() {
        XCTAssertEqual(TimelineAssembler.AssembledTimeline.SegmentTransition.EasingType.allCases.count, 5)
    }

    func testFlowIssueTypes() {
        for issueType in [TimelineAssembler.AssembledTimeline.NarrativeFlowAnalysis.FlowIssue.IssueType.pacingJump,
                          .emotionalDisconnect, .visualJarring, .narrativeGap] {
            XCTAssertFalse(issueType.rawValue.isEmpty)
        }
    }

    // MARK: - Integration Tests

    @MainActor
    func testModelOrchestratorSelection() async {
        let orchestrator = ModelOrchestrator.shared

        // Physics-heavy request should prefer Sora 2
        var physicsRequest = VideoGenerationRequest(prompt: "Physics simulation", duration: 10.0)
        physicsRequest.requiresPhysicsRealism = true

        let selectedModel = orchestrator.selectOptimalModel(for: physicsRequest)
        // Should select based on physics capability
        XCTAssertTrue([.sora2, .hybrid].contains(selectedModel))
    }

    @MainActor
    func testModelOrchestratorRespectsPreferedModel() async {
        let orchestrator = ModelOrchestrator.shared

        var request = VideoGenerationRequest(prompt: "Test", duration: 5.0)
        request.preferredModel = .runwayGen4

        let selectedModel = orchestrator.selectOptimalModel(for: request)
        XCTAssertEqual(selectedModel, .runwayGen4)
    }

    // MARK: - Performance Tests

    func testSuitabilityScorePerformance() {
        let request = VideoGenerationRequest(prompt: "Performance test", duration: 10.0)

        measure {
            for _ in 0..<1000 {
                for model in VideoGenerationModel.allCases {
                    _ = model.capabilities.suitabilityScore(for: request)
                }
            }
        }
    }

    // MARK: - Notification Tests

    func testNotificationNames() {
        XCTAssertEqual(Notification.Name.agenticDirectorCameraSwitch.rawValue, "agenticDirectorCameraSwitch")
        XCTAssertEqual(Notification.Name.agenticDirectorCut.rawValue, "agenticDirectorCut")
        XCTAssertEqual(Notification.Name.agenticDirectorLightingChange.rawValue, "agenticDirectorLightingChange")
    }

    // MARK: - API Client Tests

    func testVideoAPIClientCreation() {
        for model in VideoGenerationModel.allCases {
            let client = VideoAPIClient(model: model)
            XCTAssertEqual(client.model, model)
        }
    }

    // MARK: - Edge Cases

    func testEmptyPrompt() {
        let request = VideoGenerationRequest(prompt: "", duration: 5.0)
        XCTAssertTrue(request.prompt.isEmpty)
    }

    func testZeroDuration() {
        let request = VideoGenerationRequest(prompt: "Test", duration: 0.0)
        XCTAssertEqual(request.duration, 0.0)
    }

    func testNegativeDuration() {
        let request = VideoGenerationRequest(prompt: "Test", duration: -5.0)
        XCTAssertLessThan(request.duration, 0)
        // Suitability should handle gracefully
        let score = VideoGenerationModel.sora2.capabilities.suitabilityScore(for: request)
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 1)
    }

    func testVeryLargeDuration() {
        let request = VideoGenerationRequest(prompt: "Test", duration: 3600.0)  // 1 hour

        for model in VideoGenerationModel.allCases {
            let score = model.capabilities.suitabilityScore(for: request)
            // Should penalize models that can't handle long duration
            if model.capabilities.maxDuration < 3600 {
                XCTAssertLessThan(score, 0.7)
            }
        }
    }

    func testVeryHighResolution() {
        let request = VideoGenerationRequest(
            prompt: "8K Test",
            duration: 5.0,
            resolution: CGSize(width: 7680, height: 4320)
        )

        // Only hybrid should handle 8K well
        let hybridScore = VideoGenerationModel.hybrid.capabilities.suitabilityScore(for: request)
        let localScore = VideoGenerationModel.localDiffusion.capabilities.suitabilityScore(for: request)

        XCTAssertGreaterThan(hybridScore, localScore)
    }
}

// MARK: - Helper Extension for Tests

extension CharacterDriftDetector.DriftAnalysis.DriftIssue.IssueType: CaseIterable {
    public static var allCases: [CharacterDriftDetector.DriftAnalysis.DriftIssue.IssueType] {
        [.faceChange, .clothingChange, .proportionShift, .poseArtifact,
         .voiceMismatch, .lightingInconsistency, .temporalGlitch]
    }
}

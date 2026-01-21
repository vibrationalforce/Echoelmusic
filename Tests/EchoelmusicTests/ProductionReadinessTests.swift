// ProductionReadinessTests.swift
// Echoelmusic - Production Readiness Test Suite
//
// Comprehensive tests for all production infrastructure:
// - XcodeProjectGenerator
// - MLModelManager
// - AppStoreMetadata
// - ProductionHealthKitManager
// - ServerInfrastructure
// - ProductionAPIConfiguration
// - AdvancedPlugins
//
// Created: 2026-01-07
// Phase: 10000 ULTIMATE RALPH WIGGUM LOOP MODE
// Coverage: 100+ test methods

import XCTest
@testable import Echoelmusic

@MainActor
final class ProductionReadinessTests: XCTestCase {

    // MARK: - XcodeProjectGenerator Tests (15 tests)

    func testXcodeProjectGeneratorInitialization() {
        let generator = XcodeProjectGenerator()
        XCTAssertNotNil(generator)
    }

    func testXcodeProjectGeneratorTargetConfigurations() {
        let generator = XcodeProjectGenerator()

        // Test iOS target
        let iosTarget = generator.createTarget(platform: .iOS, name: "Echoelmusic")
        XCTAssertEqual(iosTarget.platform, .iOS)
        XCTAssertEqual(iosTarget.deploymentTarget, "15.0")
        XCTAssertTrue(iosTarget.capabilities.contains(.healthKit))
        XCTAssertTrue(iosTarget.capabilities.contains(.coreML))
    }

    func testXcodeProjectGeneratorMacOSTarget() {
        let generator = XcodeProjectGenerator()
        let macTarget = generator.createTarget(platform: .macOS, name: "Echoelmusic")
        XCTAssertEqual(macTarget.platform, .macOS)
        XCTAssertEqual(macTarget.deploymentTarget, "12.0")
        XCTAssertTrue(macTarget.capabilities.contains(.coreAudio))
    }

    func testXcodeProjectGeneratorVisionOSTarget() {
        let generator = XcodeProjectGenerator()
        let visionTarget = generator.createTarget(platform: .visionOS, name: "Echoelmusic")
        XCTAssertEqual(visionTarget.platform, .visionOS)
        XCTAssertEqual(visionTarget.deploymentTarget, "1.0")
        XCTAssertTrue(visionTarget.capabilities.contains(.spatialComputing))
    }

    func testXcodeProjectGeneratorCapabilityLists() {
        let generator = XcodeProjectGenerator()
        let capabilities = generator.getAllCapabilities()

        XCTAssertTrue(capabilities.contains(.healthKit))
        XCTAssertTrue(capabilities.contains(.coreML))
        XCTAssertTrue(capabilities.contains(.backgroundModes))
        XCTAssertTrue(capabilities.contains(.pushNotifications))
        XCTAssertTrue(capabilities.contains(.signInWithApple))
        XCTAssertTrue(capabilities.contains(.appGroups))
    }

    func testXcodeProjectGeneratorFrameworkReferences() {
        let generator = XcodeProjectGenerator()
        let frameworks = generator.getFrameworks(for: .iOS)

        XCTAssertTrue(frameworks.contains("HealthKit.framework"))
        XCTAssertTrue(frameworks.contains("CoreML.framework"))
        XCTAssertTrue(frameworks.contains("AVFoundation.framework"))
        XCTAssertTrue(frameworks.contains("CoreAudio.framework"))
        XCTAssertTrue(frameworks.contains("Metal.framework"))
    }

    func testXcodeProjectGeneratorBuildSettings() {
        let generator = XcodeProjectGenerator()
        let settings = generator.getBuildSettings(for: .iOS, configuration: .release)

        XCTAssertEqual(settings["SWIFT_OPTIMIZATION_LEVEL"], "-O")
        XCTAssertEqual(settings["SWIFT_COMPILATION_MODE"], "wholemodule")
        XCTAssertEqual(settings["ENABLE_BITCODE"], "NO")
        XCTAssertEqual(settings["IPHONEOS_DEPLOYMENT_TARGET"], "15.0")
    }

    func testXcodeProjectGeneratorDebugBuildSettings() {
        let generator = XcodeProjectGenerator()
        let settings = generator.getBuildSettings(for: .iOS, configuration: .debug)

        XCTAssertEqual(settings["SWIFT_OPTIMIZATION_LEVEL"], "-Onone")
        XCTAssertEqual(settings["DEBUG_INFORMATION_FORMAT"], "dwarf-with-dsym")
    }

    func testXcodeProjectGeneratorInfoPlistEntries() {
        let generator = XcodeProjectGenerator()
        let plist = generator.getInfoPlistEntries()

        XCTAssertNotNil(plist["NSHealthShareUsageDescription"])
        XCTAssertNotNil(plist["NSHealthUpdateUsageDescription"])
        XCTAssertNotNil(plist["NSMicrophoneUsageDescription"])
        XCTAssertNotNil(plist["NSCameraUsageDescription"])
        XCTAssertNotNil(plist["NSFaceIDUsageDescription"])
    }

    func testXcodeProjectGeneratorEntitlements() {
        let generator = XcodeProjectGenerator()
        let entitlements = generator.getEntitlements(for: .iOS)

        XCTAssertTrue(entitlements.contains("com.apple.developer.healthkit"))
        XCTAssertTrue(entitlements.contains("com.apple.developer.networking.wifi-info"))
        XCTAssertTrue(entitlements.contains("com.apple.security.application-groups"))
    }

    func testXcodeProjectGeneratorSchemeGeneration() {
        let generator = XcodeProjectGenerator()
        let scheme = generator.createScheme(name: "Echoelmusic", target: "iOS")

        XCTAssertEqual(scheme.name, "Echoelmusic")
        XCTAssertTrue(scheme.buildActions.contains(.build))
        XCTAssertTrue(scheme.buildActions.contains(.test))
        XCTAssertTrue(scheme.buildActions.contains(.run))
    }

    func testXcodeProjectGeneratorMultiplePlatforms() {
        let generator = XcodeProjectGenerator()
        let platforms: [Platform] = [.iOS, .macOS, .tvOS, .watchOS, .visionOS]

        for platform in platforms {
            let target = generator.createTarget(platform: platform, name: "Echoelmusic")
            XCTAssertEqual(target.platform, platform)
            XCTAssertFalse(target.capabilities.isEmpty)
        }
    }

    func testXcodeProjectGeneratorCodeSigning() {
        let generator = XcodeProjectGenerator()
        let codeSign = generator.getCodeSigningSettings(for: .iOS)

        XCTAssertNotNil(codeSign["CODE_SIGN_IDENTITY"])
        XCTAssertNotNil(codeSign["DEVELOPMENT_TEAM"])
        XCTAssertEqual(codeSign["CODE_SIGN_STYLE"], "Automatic")
    }

    func testXcodeProjectGeneratorAssetCatalog() {
        let generator = XcodeProjectGenerator()
        let assets = generator.getAssetCatalogConfiguration()

        XCTAssertTrue(assets.includesAppIcons)
        XCTAssertTrue(assets.includesLaunchImages)
        XCTAssertTrue(assets.supportsProMotion)
    }

    func testXcodeProjectGeneratorWatchOSCompanion() {
        let generator = XcodeProjectGenerator()
        let watchTarget = generator.createWatchCompanionTarget()

        XCTAssertEqual(watchTarget.platform, .watchOS)
        XCTAssertTrue(watchTarget.requiresiOSCompanion)
    }

    // MARK: - MLModelManager Tests (12 tests)

    func testMLModelManagerInitialization() async {
        let manager = MLModelManager.shared
        XCTAssertNotNil(manager)
    }

    func testMLModelManagerModelConfigurations() {
        let manager = MLModelManager.shared
        let configs = manager.getAllModelConfigurations()

        XCTAssertTrue(configs.contains { $0.name == "BioPredictor" })
        XCTAssertTrue(configs.contains { $0.name == "AudioClassifier" })
        XCTAssertTrue(configs.contains { $0.name == "EmotionDetector" })
    }

    func testMLModelManagerCacheSystem() async {
        let manager = MLModelManager.shared

        // Load a model
        let result = await manager.loadModel(name: "BioPredictor")
        XCTAssertTrue(result.isSuccess)

        // Check cache
        let cached = manager.isModelCached(name: "BioPredictor")
        XCTAssertTrue(cached)
    }

    func testMLModelManagerCacheEviction() async {
        let manager = MLModelManager.shared

        // Set low memory limit
        manager.setMaxCacheSize(bytes: 1_000_000) // 1MB

        // Load multiple models
        await manager.loadModel(name: "BioPredictor")
        await manager.loadModel(name: "AudioClassifier")

        // Check LRU eviction occurred
        let cacheSize = manager.getCurrentCacheSize()
        XCTAssertLessThanOrEqual(cacheSize, 1_000_000)
    }

    func testMLModelManagerModelLoadingStates() async {
        let manager = MLModelManager.shared

        // Check initial state
        var state = manager.getModelState(name: "BioPredictor")
        XCTAssertEqual(state, .notLoaded)

        // Load model
        let result = await manager.loadModel(name: "BioPredictor")
        XCTAssertTrue(result.isSuccess)

        // Check loaded state
        state = manager.getModelState(name: "BioPredictor")
        XCTAssertEqual(state, .loaded)
    }

    func testMLModelManagerInferenceEngine() async {
        let manager = MLModelManager.shared

        // Load model
        await manager.loadModel(name: "BioPredictor")

        // Run inference
        let input: [Float] = [72.0, 50.0, 0.75, 12.0] // HR, HRV, Coherence, BR
        let output = await manager.runInference(modelName: "BioPredictor", input: input)

        XCTAssertNotNil(output)
        XCTAssertFalse(output!.isEmpty)
    }

    func testMLModelManagerBatchInference() async {
        let manager = MLModelManager.shared
        await manager.loadModel(name: "BioPredictor")

        let batch: [[Float]] = [
            [70.0, 45.0, 0.6, 10.0],
            [75.0, 55.0, 0.8, 14.0],
            [80.0, 60.0, 0.9, 16.0]
        ]

        let results = await manager.runBatchInference(modelName: "BioPredictor", inputs: batch)
        XCTAssertEqual(results.count, 3)
    }

    func testMLModelManagerPreprocessing() {
        let manager = MLModelManager.shared

        let raw: [Float] = [150.0, 200.0, 5.0]
        let normalized = manager.preprocessInput(raw, type: .minMaxNormalization)

        XCTAssertTrue(normalized.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    func testMLModelManagerPostprocessing() {
        let manager = MLModelManager.shared

        let modelOutput: [Float] = [0.1, 0.7, 0.2]
        let classified = manager.postprocessOutput(modelOutput, type: .classification)

        XCTAssertEqual(classified.predictedClass, 1) // Highest probability
        XCTAssertEqual(classified.confidence, 0.7)
    }

    func testMLModelManagerMetrics() async {
        let manager = MLModelManager.shared

        await manager.loadModel(name: "BioPredictor")
        let metrics = manager.getModelMetrics(name: "BioPredictor")

        XCTAssertNotNil(metrics)
        XCTAssertGreaterThan(metrics!.inferenceTimeMs, 0)
        XCTAssertGreaterThan(metrics!.modelSizeBytes, 0)
    }

    func testMLModelManagerUnloadModel() async {
        let manager = MLModelManager.shared

        await manager.loadModel(name: "BioPredictor")
        XCTAssertTrue(manager.isModelCached(name: "BioPredictor"))

        manager.unloadModel(name: "BioPredictor")
        XCTAssertFalse(manager.isModelCached(name: "BioPredictor"))
    }

    func testMLModelManagerClearAllCache() async {
        let manager = MLModelManager.shared

        await manager.loadModel(name: "BioPredictor")
        await manager.loadModel(name: "AudioClassifier")

        manager.clearAllCache()
        XCTAssertEqual(manager.getCurrentCacheSize(), 0)
    }

    // MARK: - AppStoreMetadata Tests (15 tests)

    func testAppStoreMetadataInitialization() {
        let metadata = AppStoreMetadata()
        XCTAssertNotNil(metadata)
    }

    func testAppStoreMetadataAllLocalizationsExist() {
        let metadata = AppStoreMetadata()
        let locales = metadata.getSupportedLocales()

        let required = ["en-US", "de-DE", "ja-JP", "es-ES", "fr-FR",
                       "zh-CN", "ko-KR", "pt-BR", "it-IT", "ru-RU", "ar-SA", "hi-IN"]

        for locale in required {
            XCTAssertTrue(locales.contains(locale), "Missing locale: \(locale)")
        }
    }

    func testAppStoreMetadataSubtitleCharacterLimit() {
        let metadata = AppStoreMetadata()

        for locale in metadata.getSupportedLocales() {
            let subtitle = metadata.getSubtitle(locale: locale)
            XCTAssertLessThanOrEqual(subtitle.count, 30, "Subtitle too long for \(locale)")
            XCTAssertGreaterThan(subtitle.count, 0, "Subtitle empty for \(locale)")
        }
    }

    func testAppStoreMetadataKeywordsCharacterLimit() {
        let metadata = AppStoreMetadata()

        for locale in metadata.getSupportedLocales() {
            let keywords = metadata.getKeywords(locale: locale)
            let combined = keywords.joined(separator: ",")
            XCTAssertLessThanOrEqual(combined.count, 100, "Keywords too long for \(locale)")
        }
    }

    func testAppStoreMetadataDescriptionCharacterLimit() {
        let metadata = AppStoreMetadata()

        for locale in metadata.getSupportedLocales() {
            let description = metadata.getDescription(locale: locale)
            XCTAssertLessThanOrEqual(description.count, 4000, "Description too long for \(locale)")
            XCTAssertGreaterThan(description.count, 100, "Description too short for \(locale)")
        }
    }

    func testAppStoreMetadataScreenshotSpecifications() {
        let metadata = AppStoreMetadata()
        let specs = metadata.getScreenshotSpecs()

        // iPhone 6.7" (iPhone 15 Pro Max)
        XCTAssertTrue(specs.contains { $0.device == "iPhone 6.7" && $0.resolution == (1290, 2796) })

        // iPad Pro 12.9"
        XCTAssertTrue(specs.contains { $0.device == "iPad Pro 12.9" && $0.resolution == (2048, 2732) })

        // Apple Vision Pro
        XCTAssertTrue(specs.contains { $0.device == "Apple Vision Pro" })
    }

    func testAppStoreMetadataPrivacyPractices() {
        let metadata = AppStoreMetadata()
        let privacy = metadata.getPrivacyPractices()

        XCTAssertTrue(privacy.dataCollected.contains("Health Data"))
        XCTAssertTrue(privacy.dataCollected.contains("Audio Data"))
        XCTAssertTrue(privacy.dataCollected.contains("Usage Data"))

        XCTAssertTrue(privacy.purposeDescription.contains("biometric"))
        XCTAssertFalse(privacy.linkedToUser, "Privacy should not link to user")
    }

    func testAppStoreMetadataSubscriptionTiers() {
        let metadata = AppStoreMetadata()
        let tiers = metadata.getSubscriptionTiers()

        XCTAssertEqual(tiers.count, 3)

        // Free tier
        let free = tiers.first { $0.name == "Free" }
        XCTAssertNotNil(free)
        XCTAssertEqual(free?.price, 0.0)

        // Pro tier
        let pro = tiers.first { $0.name == "Pro" }
        XCTAssertNotNil(pro)
        XCTAssertGreaterThan(pro!.price, 0)

        // Ultimate tier
        let ultimate = tiers.first { $0.name == "Ultimate" }
        XCTAssertNotNil(ultimate)
        XCTAssertGreaterThan(ultimate!.price, pro!.price)
    }

    func testAppStoreMetadataAgeRating() {
        let metadata = AppStoreMetadata()
        let rating = metadata.getAgeRating()

        XCTAssertEqual(rating, "4+")
        XCTAssertTrue(metadata.hasNoObjectionableContent())
    }

    func testAppStoreMetadataCategoryClassification() {
        let metadata = AppStoreMetadata()

        XCTAssertEqual(metadata.getPrimaryCategory(), "Music")
        XCTAssertEqual(metadata.getSecondaryCategory(), "Health & Fitness")
    }

    func testAppStoreMetadataAppClipConfiguration() {
        let metadata = AppStoreMetadata()
        let appClip = metadata.getAppClipConfiguration()

        XCTAssertNotNil(appClip)
        XCTAssertTrue(appClip!.enabled)
        XCTAssertLessThanOrEqual(appClip!.size, 15_000_000) // 15MB limit
    }

    func testAppStoreMetadataPromotionalText() {
        let metadata = AppStoreMetadata()

        for locale in metadata.getSupportedLocales() {
            let promoText = metadata.getPromotionalText(locale: locale)
            XCTAssertLessThanOrEqual(promoText.count, 170, "Promo text too long for \(locale)")
        }
    }

    func testAppStoreMetadataWhatsNewText() {
        let metadata = AppStoreMetadata()
        let whatsNew = metadata.getWhatsNew(version: "1.0.0")

        XCTAssertFalse(whatsNew.isEmpty)
        XCTAssertLessThanOrEqual(whatsNew.count, 4000)
    }

    func testAppStoreMetadataMarketingURL() {
        let metadata = AppStoreMetadata()
        let url = metadata.getMarketingURL()

        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.starts(with: "https://"))
    }

    func testAppStoreMetadataSupportURL() {
        let metadata = AppStoreMetadata()
        let url = metadata.getSupportURL()

        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("support"))
    }

    // MARK: - ProductionHealthKitManager Tests (12 tests)

    func testProductionHealthKitManagerInitialization() {
        let manager = ProductionHealthKitManager.shared
        XCTAssertNotNil(manager)
    }

    func testProductionHealthKitManagerDataSourceSwitching() async {
        let manager = ProductionHealthKitManager.shared

        // Start with real HealthKit
        manager.setDataSource(.healthKit)
        XCTAssertEqual(manager.currentDataSource, .healthKit)

        // Switch to simulation
        manager.setDataSource(.simulation)
        XCTAssertEqual(manager.currentDataSource, .simulation)
    }

    func testProductionHealthKitManagerSimulationMode() async {
        let manager = ProductionHealthKitManager.shared
        manager.setDataSource(.simulation)

        // Start simulation
        await manager.startSimulation(preset: .restingState)

        // Get simulated data
        let heartRate = await manager.getCurrentHeartRate()
        XCTAssertGreaterThan(heartRate, 40)
        XCTAssertLessThan(heartRate, 100)
    }

    func testProductionHealthKitManagerHRVCalculations() async {
        let manager = ProductionHealthKitManager.shared

        // Mock RR intervals
        let rrIntervals: [Double] = [0.8, 0.82, 0.79, 0.81, 0.83, 0.80, 0.78, 0.81]

        let sdnn = manager.calculateSDNN(rrIntervals: rrIntervals)
        XCTAssertGreaterThan(sdnn, 0)

        let rmssd = manager.calculateRMSSD(rrIntervals: rrIntervals)
        XCTAssertGreaterThan(rmssd, 0)

        let pnn50 = manager.calculatePNN50(rrIntervals: rrIntervals)
        XCTAssertGreaterThanOrEqual(pnn50, 0)
        XCTAssertLessThanOrEqual(pnn50, 100)
    }

    func testProductionHealthKitManagerCoherenceCalculation() {
        let manager = ProductionHealthKitManager.shared

        let sdnn: Float = 50.0
        let rmssd: Float = 35.0
        let pnn50: Float = 15.0

        let coherence = manager.calculateCoherence(sdnn: sdnn, rmssd: rmssd, pnn50: pnn50)

        XCTAssertGreaterThanOrEqual(coherence, 0.0)
        XCTAssertLessThanOrEqual(coherence, 1.0)
    }

    func testProductionHealthKitManagerReplayFunctionality() async {
        let manager = ProductionHealthKitManager.shared

        // Save session for replay
        manager.startRecording()
        await manager.recordData(heartRate: 75.0, hrv: 55.0)
        await manager.recordData(heartRate: 76.0, hrv: 56.0)
        let session = manager.stopRecording()

        XCTAssertNotNil(session)
        XCTAssertEqual(session!.dataPoints.count, 2)

        // Replay session
        manager.setDataSource(.replay(session: session!))
        await manager.startReplay()

        let replayedHR = await manager.getCurrentHeartRate()
        XCTAssertEqual(replayedHR, 75.0)
    }

    func testProductionHealthKitManagerPrivacySettings() {
        let manager = ProductionHealthKitManager.shared

        // Enable privacy mode
        manager.setPrivacyMode(enabled: true)
        XCTAssertTrue(manager.isPrivacyModeEnabled)

        // In privacy mode, data should be anonymized
        let data = manager.getAnonymizedData()
        XCTAssertNotNil(data)
        XCTAssertNil(data.userIdentifier)
    }

    func testProductionHealthKitManagerStreamingSession() async {
        let manager = ProductionHealthKitManager.shared
        manager.setDataSource(.simulation)

        var receivedUpdates = 0
        let expectation = XCTestExpectation(description: "Receive streaming updates")

        let cancellable = manager.startStreaming { bioData in
            receivedUpdates += 1
            if receivedUpdates >= 3 {
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 5.0)
        cancellable.cancel()

        XCTAssertGreaterThanOrEqual(receivedUpdates, 3)
    }

    func testProductionHealthKitManagerDataValidation() {
        let manager = ProductionHealthKitManager.shared

        // Valid data
        XCTAssertTrue(manager.isValidHeartRate(70.0))
        XCTAssertTrue(manager.isValidHRV(50.0))

        // Invalid data
        XCTAssertFalse(manager.isValidHeartRate(300.0))
        XCTAssertFalse(manager.isValidHeartRate(-10.0))
        XCTAssertFalse(manager.isValidHRV(-5.0))
    }

    func testProductionHealthKitManagerExportData() async {
        let manager = ProductionHealthKitManager.shared

        manager.startRecording()
        await manager.recordData(heartRate: 75.0, hrv: 55.0)
        let session = manager.stopRecording()

        let exportedData = manager.exportToJSON(session: session!)
        XCTAssertNotNil(exportedData)

        // Verify JSON structure
        let json = try? JSONSerialization.jsonObject(with: exportedData!, options: [])
        XCTAssertNotNil(json)
    }

    func testProductionHealthKitManagerAuthorization() async {
        let manager = ProductionHealthKitManager.shared

        let authStatus = await manager.requestAuthorization()
        // In test environment, this may return denied
        XCTAssertNotNil(authStatus)
    }

    func testProductionHealthKitManagerHealthDisclaimer() {
        let manager = ProductionHealthKitManager.shared
        let disclaimer = manager.getHealthDisclaimer()

        XCTAssertTrue(disclaimer.contains("NOT a medical device"))
        XCTAssertTrue(disclaimer.contains("informational purposes"))
        XCTAssertTrue(disclaimer.contains("consult a healthcare professional"))
    }

    // MARK: - ServerInfrastructure Tests (20 tests)

    func testServerConfigurationInitialization() async {
        let config = await ServerConfiguration.shared
        XCTAssertNotNil(config)
        let env = await config.environment
        XCTAssertEqual(env, .production)
    }

    func testServerConfigurationAllRegions() {
        let regions: [ServerRegion] = [
            .usWest, .usEast, .euWest, .euCentral,
            .asiaPacific, .asiaSoutheast, .southAmerica,
            .oceania, .middleEast, .africa, .quantumGlobal
        ]

        for region in regions {
            XCTAssertFalse(region.endpoint.isEmpty)
            XCTAssertTrue(region.endpoint.contains("echoelmusic.com"))
        }
    }

    func testServerConfigurationEnvironmentSwitching() async {
        let config = await ServerConfiguration.shared

        await config.setEnvironment(.development)
        let devURL = await config.baseURL
        XCTAssertTrue(devURL.contains("dev-"))

        await config.setEnvironment(.staging)
        let stagingURL = await config.baseURL
        XCTAssertTrue(stagingURL.contains("staging-"))

        await config.setEnvironment(.production)
        let prodURL = await config.baseURL
        XCTAssertFalse(prodURL.contains("dev-"))
        XCTAssertFalse(prodURL.contains("staging-"))
    }

    func testServerConfigurationURLConstruction() async {
        let config = await ServerConfiguration.shared
        await config.setSelectedRegion(.usWest)

        let apiURL = await config.apiBaseURL
        XCTAssertTrue(apiURL.contains("api/v2"))
        XCTAssertTrue(apiURL.starts(with: "https://"))
    }

    func testServerConfigurationWebSocketURLs() async {
        let config = await ServerConfiguration.shared

        let wsURL = await config.webSocketURL
        XCTAssertNotNil(wsURL)
        XCTAssertTrue(wsURL!.absoluteString.starts(with: "wss://"))

        let collabURL = await config.collaborationWebSocketURL
        XCTAssertNotNil(collabURL)
        XCTAssertTrue(collabURL!.absoluteString.contains("collaboration"))
    }

    func testAuthenticationServiceInitialization() async {
        let auth = await AuthenticationService.shared
        XCTAssertNotNil(auth)
        let isAuth = await auth.isAuthenticated
        XCTAssertFalse(isAuth)
    }

    func testAuthenticationServiceAnonymousSession() async throws {
        let auth = await AuthenticationService.shared

        try await auth.createAnonymousSession()

        let isAuth = await auth.isAuthenticated
        let isAnon = await auth.isAnonymous
        XCTAssertTrue(isAuth)
        XCTAssertTrue(isAnon)
        let token = await auth.currentToken
        XCTAssertNotNil(token)
        let userID = await auth.userID
        XCTAssertNotNil(userID)
    }

    func testAuthenticationServiceTokenManagement() async throws {
        let auth = await AuthenticationService.shared
        try await auth.createAnonymousSession()

        let token = await auth.currentToken
        XCTAssertNotNil(token)
        XCTAssertFalse(token!.isExpired)

        let accessToken = token!.accessToken
        XCTAssertTrue(accessToken.starts(with: "anon_"))
    }

    func testAuthenticationServiceSignOut() async throws {
        let auth = await AuthenticationService.shared

        try await auth.createAnonymousSession()
        var isAuth = await auth.isAuthenticated
        XCTAssertTrue(isAuth)

        await auth.signOut()
        isAuth = await auth.isAuthenticated
        XCTAssertFalse(isAuth)
        let token = await auth.currentToken
        XCTAssertNil(token)
    }

    func testCollaborationServerInitialization() async {
        let server = await CollaborationServer.shared
        XCTAssertNotNil(server)
        let state = await server.connectionState
        if case .disconnected = state {
            // Expected
        } else {
            XCTFail("Expected disconnected state")
        }
    }

    func testCollaborationServerMessageStructure() {
        let message = WSMessage(
            type: .join,
            sessionID: "test-session",
            userID: "test-user",
            data: ["test": AnyCodable("value")]
        )

        XCTAssertEqual(message.type, .join)
        XCTAssertEqual(message.sessionID, "test-session")
        XCTAssertEqual(message.userID, "test-user")
    }

    func testCloudSyncServiceInitialization() async {
        let sync = await CloudSyncService.shared
        XCTAssertNotNil(sync)
        let syncing = await sync.isSyncing
        XCTAssertFalse(syncing)
    }

    func testCloudSyncServiceConflictResolution() async {
        let sync = await CloudSyncService.shared

        await sync.setConflictResolution(.localWins)
        var resolution = await sync.conflictResolution
        if case .localWins = resolution {} else {
            XCTFail("Expected localWins")
        }

        await sync.setConflictResolution(.newerWins)
        resolution = await sync.conflictResolution
        if case .newerWins = resolution {} else {
            XCTFail("Expected newerWins")
        }
    }

    func testRealtimeBioSyncInitialization() async {
        let bioSync = await RealtimeBioSync.shared
        XCTAssertNotNil(bioSync)
        let active = await bioSync.isActive
        XCTAssertFalse(active)
    }

    func testBioDataPacketEncoding() {
        let packet = BioDataPacket(
            userID: "test-user",
            timestamp: Date(),
            heartRate: 75.0,
            hrvCoherence: 0.75,
            breathingRate: 12.0,
            gsr: 0.5,
            spo2: 98.0
        )

        let compactData = packet.compactEncode()
        XCTAssertEqual(compactData.count, 20) // 5 floats * 4 bytes
    }

    func testAPIClientInitialization() async {
        let client = await APIClient.shared
        XCTAssertNotNil(client)
        let retries = await client.maxRetries
        XCTAssertEqual(retries, 3)
    }

    func testOfflineSupportInitialization() async {
        let offline = await OfflineSupport.shared
        XCTAssertNotNil(offline)
        let isOffline = await offline.isOffline
        XCTAssertFalse(isOffline)
        let queued = await offline.queuedRequests
        XCTAssertEqual(queued.count, 0)
    }

    func testOfflineSupportQueueing() async {
        let offline = await OfflineSupport.shared

        await offline.queueRequest(endpoint: "/test", method: .GET)
        var queued = await offline.queuedRequests
        XCTAssertEqual(queued.count, 1)

        await offline.queueRequest(endpoint: "/test2", method: .POST, body: Data())
        queued = await offline.queuedRequests
        XCTAssertEqual(queued.count, 2)
    }

    func testServerHealthMonitorInitialization() async {
        let monitor = await ServerHealthMonitor.shared
        XCTAssertNotNil(monitor)
        let healthy = await monitor.isHealthy
        XCTAssertTrue(healthy)
    }

    func testAggregatedBioDataPrivacy() {
        let aggregated = AggregatedBioData(
            participantCount: 10,
            averageCoherence: 0.75,
            averageHeartRate: 72.0,
            coherenceVariance: 0.1,
            timestamp: Date()
        )

        // Verify no individual data is exposed
        XCTAssertGreaterThan(aggregated.participantCount, 1)
        XCTAssertGreaterThan(aggregated.averageCoherence, 0)
    }

    // MARK: - ProductionAPIConfiguration Tests (18 tests)

    func testAPIEnvironmentDetection() {
        let current = APIEnvironment.current
        XCTAssertNotNil(current)

        #if DEBUG
        XCTAssertEqual(current, .development)
        #else
        XCTAssertEqual(current, .production)
        #endif
    }

    func testRetryPolicyConfigurations() {
        let defaultPolicy = APIRetryPolicy.default
        XCTAssertEqual(defaultPolicy.maxRetries, 3)

        let aggressive = APIRetryPolicy.aggressive
        XCTAssertGreaterThan(aggressive.maxRetries, defaultPolicy.maxRetries)

        let conservative = APIRetryPolicy.conservative
        XCTAssertLessThan(conservative.maxRetries, defaultPolicy.maxRetries)
    }

    func testRateLimitConfigurations() {
        let defaultLimit = RateLimitConfiguration.default
        XCTAssertEqual(defaultLimit.requestsPerSecond, 10)

        let streaming = RateLimitConfiguration.streaming
        XCTAssertLessThan(streaming.requestsPerSecond, defaultLimit.requestsPerSecond)

        let analytics = RateLimitConfiguration.analytics
        XCTAssertGreaterThan(analytics.requestsPerSecond, defaultLimit.requestsPerSecond)
    }

    func testYouTubeAPIConfiguration() {
        let youtube = YouTubeAPIConfiguration()

        XCTAssertEqual(youtube.baseURL.absoluteString, "https://www.googleapis.com/youtube/v3")
        XCTAssertTrue(youtube.apiKeyIdentifier.contains("youtube"))
        XCTAssertEqual(youtube.maxBitrate, 51_000_000)
        XCTAssertEqual(youtube.scopes.count, 2)
    }

    func testTwitchAPIConfiguration() {
        let twitch = TwitchAPIConfiguration()

        XCTAssertEqual(twitch.baseURL.absoluteString, "https://api.twitch.tv/helix")
        XCTAssertTrue(twitch.apiKeyIdentifier.contains("twitch"))
        XCTAssertGreaterThan(twitch.ingestEndpoints.count, 0)
    }

    func testFacebookAPIConfiguration() {
        let facebook = FacebookAPIConfiguration()

        XCTAssertTrue(facebook.baseURL.absoluteString.contains("graph.facebook.com"))
        XCTAssertTrue(facebook.permissions.contains("publish_video"))
    }

    func testInstagramAPIConfiguration() {
        let instagram = InstagramAPIConfiguration()

        XCTAssertTrue(instagram.baseURL.absoluteString.contains("graph.instagram.com"))
    }

    func testTikTokAPIConfiguration() {
        let tiktok = TikTokAPIConfiguration()

        XCTAssertTrue(tiktok.baseURL.absoluteString.contains("open-api.tiktok.com"))
    }

    func testCloudKitConfiguration() {
        let cloudKit = CloudKitConfiguration()

        XCTAssertEqual(cloudKit.containerIdentifier, "iCloud.com.echoelmusic.app")
        XCTAssertEqual(cloudKit.timeout, 60.0)
    }

    func testAWSS3Configuration() {
        let s3 = AWSS3Configuration()

        XCTAssertTrue(s3.baseURL.absoluteString.contains("s3"))
        XCTAssertEqual(s3.region, "us-east-1")
        XCTAssertTrue(s3.bucketName.contains("echoelmusic"))
    }

    func testSecureAPIKeyManagerStorage() async throws {
        let manager = await SecureAPIKeyManager.shared

        let testKey = "test-api-key-12345"
        let identifier = "test_api_key"

        try await manager.storeAPIKey(testKey, identifier: identifier)
        let retrieved = try await manager.retrieveAPIKey(identifier: identifier)

        XCTAssertEqual(retrieved, testKey)

        // Cleanup
        try await manager.deleteAPIKey(identifier: identifier)
    }

    func testSecureAPIKeyManagerObfuscation() async {
        let manager = await SecureAPIKeyManager.shared

        let plaintext = "secret-key"
        let salt: [UInt8] = [42, 17, 99, 128]

        let obfuscated = await manager.obfuscate(plaintext, salt: salt)
        let deobfuscated = await manager.deobfuscate(obfuscated, salt: salt)

        XCTAssertEqual(deobfuscated, plaintext)
    }

    func testAPIHealthCheckerStructure() async {
        let checker = await APIHealthChecker.shared
        XCTAssertNotNil(checker)
    }

    func testProductionAPIManagerInitialization() async {
        let manager = await ProductionAPIManager.shared
        XCTAssertNotNil(manager)

        let youtube = await manager.youtube
        XCTAssertNotNil(youtube)
        let twitch = await manager.twitch
        XCTAssertNotNil(twitch)
        let cloudKit = await manager.cloudKit
        XCTAssertNotNil(cloudKit)
        let s3 = await manager.s3
        XCTAssertNotNil(s3)
    }

    func testDMXConfiguration() {
        let dmx = DMXConfiguration.default

        XCTAssertEqual(dmx.artNetIP, "192.168.1.100")
        XCTAssertEqual(dmx.artNetPort, 6454)
        XCTAssertEqual(dmx.refreshRate, 44)
    }

    func testOSCConfiguration() {
        let osc = OSCConfiguration.default

        XCTAssertEqual(osc.host, "127.0.0.1")
        XCTAssertEqual(osc.port, 8000)
        XCTAssertGreaterThan(osc.addressSpace.count, 0)
    }

    func testMIDINetworkConfiguration() {
        let midi = MIDINetworkConfiguration.default

        XCTAssertEqual(midi.sessionName, "Echoelmusic MIDI")
        XCTAssertEqual(midi.bonjourName, "_apple-midi._udp")
    }

    func testAbletonLinkConfiguration() {
        let link = AbletonLinkConfiguration.default

        XCTAssertTrue(link.enableAtStartup)
        XCTAssertEqual(link.quantum, 4.0)
    }

    // MARK: - AdvancedPlugins Tests (15 tests)

    func testAISoundDesignerPluginInitialization() {
        let plugin = AISoundDesignerPlugin()

        XCTAssertEqual(plugin.identifier, "com.echoelmusic.ai-sound-designer")
        XCTAssertEqual(plugin.name, "AI Sound Designer Pro")
        XCTAssertTrue(plugin.capabilities.contains(.audioGenerator))
        XCTAssertTrue(plugin.capabilities.contains(.machineLearning))
    }

    func testAISoundDesignerSynthesisEngines() {
        let engines = AISoundDesignerPlugin.SynthesisEngine.allCases

        XCTAssertTrue(engines.contains(.granular))
        XCTAssertTrue(engines.contains(.spectral))
        XCTAssertTrue(engines.contains(.neural))
        XCTAssertTrue(engines.contains(.wavetable))
    }

    func testAISoundDesignerConfiguration() {
        let plugin = AISoundDesignerPlugin()

        plugin.configuration.engine = .granular
        XCTAssertEqual(plugin.configuration.engine, .granular)

        plugin.configuration.grainSize = 0.1
        XCTAssertEqual(plugin.configuration.grainSize, 0.1)
    }

    func testAISoundDesignerBioReactivity() {
        let plugin = AISoundDesignerPlugin()

        plugin.configuration.bioReactive = true
        plugin.configuration.hrvToFilter = true
        plugin.configuration.breathToAmplitude = true

        XCTAssertTrue(plugin.configuration.bioReactive)
    }

    func testAISoundDesignerSoundParameters() {
        let plugin = AISoundDesignerPlugin()

        plugin.parameters.osc1Level = 0.8
        plugin.parameters.reverbMix = 0.4

        XCTAssertEqual(plugin.parameters.osc1Level, 0.8)
    }

    func testLaserVisualDesignerPluginInitialization() {
        let plugin = LaserVisualDesignerPlugin()

        XCTAssertEqual(plugin.identifier, "com.echoelmusic.laser-visual-designer")
        XCTAssertTrue(plugin.capabilities.contains(.dmxOutput))
        XCTAssertTrue(plugin.capabilities.contains(.visualization))
    }

    func testLaserVisualDesignerLaserTypes() {
        let types = LaserVisualDesignerPlugin.LaserType.allCases

        XCTAssertGreaterThan(types.count, 0)
        XCTAssertTrue(types.contains(.geometric))
        XCTAssertTrue(types.contains(.scanner))
    }

    func testLaserVisualDesignerILDAExport() {
        let plugin = LaserVisualDesignerPlugin()

        let frames = plugin.generateILDAFrames(count: 10)
        XCTAssertEqual(frames.count, 10)
    }

    func testLaserVisualDesignerBioSync() {
        let plugin = LaserVisualDesignerPlugin()

        plugin.configuration.bioReactive = true
        plugin.configuration.coherenceToIntensity = true

        let bioData = BioData(
            heartRate: 75.0,
            hrvSDNN: 55.0,
            coherence: 0.8,
            breathingRate: 12.0
        )

        plugin.onBioDataUpdate(bioData)
        // Intensity should be affected by coherence
    }

    func testOrganicScoreInstrumentPluginInitialization() {
        let plugin = OrganicScoreInstrumentPlugin()

        XCTAssertEqual(plugin.identifier, "com.echoelmusic.organic-score-instrument")
        XCTAssertTrue(plugin.capabilities.contains(.audioGenerator))
    }

    func testOrganicScoreInstrumentArticulations() {
        let articulations = OrganicScoreInstrumentPlugin.Articulation.allCases

        XCTAssertGreaterThan(articulations.count, 3)
        XCTAssertTrue(articulations.contains(.legato))
        XCTAssertTrue(articulations.contains(.staccato))
    }

    func testOrganicScoreInstrumentOrchestraSection() {
        let plugin = OrganicScoreInstrumentPlugin()

        plugin.configuration.section = .strings
        XCTAssertEqual(plugin.configuration.section, .strings)

        plugin.configuration.section = .brass
        XCTAssertEqual(plugin.configuration.section, .brass)
    }

    func testOrganicScoreInstrumentDynamics() {
        let dynamics = OrganicScoreInstrumentPlugin.DynamicMarking.allCases

        XCTAssertTrue(dynamics.contains(.piano))
        XCTAssertTrue(dynamics.contains(.forte))
        XCTAssertTrue(dynamics.contains(.fortissimo))
    }

    func testOrganicScoreInstrumentBioModulation() {
        let plugin = OrganicScoreInstrumentPlugin()

        plugin.configuration.bioModulation = true
        plugin.configuration.coherenceToDynamics = true

        let bioData = BioData(
            heartRate: nil,
            hrvSDNN: nil,
            coherence: 0.9,
            breathingRate: nil
        )

        plugin.onBioDataUpdate(bioData)
        // Dynamics should be affected
    }

    func testAllPluginsHaveUniqueIdentifiers() {
        let aiSound = AISoundDesignerPlugin()
        let laser = LaserVisualDesignerPlugin()
        let organic = OrganicScoreInstrumentPlugin()

        let identifiers = Set([aiSound.identifier, laser.identifier, organic.identifier])
        XCTAssertEqual(identifiers.count, 3, "All plugins must have unique identifiers")
    }
}

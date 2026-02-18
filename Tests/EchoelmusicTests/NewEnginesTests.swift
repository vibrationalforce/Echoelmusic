import XCTest
@testable import Echoelmusic

/// Comprehensive tests for the 12 new Echoelmusic engines (2026 expansion).
///
/// Covers:
/// - EchoelTranslateEngine (Translation/)
/// - EchoelSpeechEngine (Translation/)
/// - EchoelLyricsEngine (Lyrics/)
/// - EchoelSubtitleRenderer (Subtitle/)
/// - EchoelMindEngine (Mind/)
/// - EchoelMintEngine (Mint/)
/// - EchoelAvatarEngine (Avatar/)
/// - EchoelWorldEngine (World/)
/// - EchoelGodotBridge (Godot/)
/// - EchoelOSCEngine (Integration/)
/// - EchoelShowControl (Integration/)
/// - EchoelIntegrationHub (Integration/)
///
@MainActor
final class NewEnginesTests: XCTestCase {

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - 1. EchoelTranslateEngine Tests
    // ═══════════════════════════════════════════════════════════════════════

    func testEchoelLanguageEnumProperties() {
        // Case count: 19 Tier 1 + 4 Tier 2 = 23
        XCTAssertEqual(EchoelLanguage.allCases.count, 23,
                       "EchoelLanguage should have 23 language cases")

        // Raw values
        XCTAssertEqual(EchoelLanguage.english.rawValue, "en")
        XCTAssertEqual(EchoelLanguage.japanese.rawValue, "ja")
        XCTAssertEqual(EchoelLanguage.chineseSimplified.rawValue, "zh-Hans")
        XCTAssertEqual(EchoelLanguage.norwegian.rawValue, "no")

        // Display names
        XCTAssertEqual(EchoelLanguage.english.displayName, "English")
        XCTAssertEqual(EchoelLanguage.german.displayName, "Deutsch")
        XCTAssertEqual(EchoelLanguage.japanese.displayName, "日本語")

        // RTL
        XCTAssertTrue(EchoelLanguage.arabic.isRTL)
        XCTAssertFalse(EchoelLanguage.english.isRTL)

        // Identifiable
        XCTAssertEqual(EchoelLanguage.french.id, "fr")
    }

    func testTranslationResultInitialization() {
        let result = TranslationResult(
            sourceText: "Hello",
            sourceLanguage: .english,
            targetLanguage: .spanish,
            translatedText: "Hola",
            confidence: 0.95,
            latencyMs: 12.5,
            isOnDevice: true
        )

        XCTAssertEqual(result.sourceText, "Hello")
        XCTAssertEqual(result.translatedText, "Hola")
        XCTAssertEqual(result.sourceLanguage, .english)
        XCTAssertEqual(result.targetLanguage, .spanish)
        XCTAssertEqual(result.confidence, 0.95, accuracy: 0.001)
        XCTAssertEqual(result.latencyMs, 12.5, accuracy: 0.001)
        XCTAssertTrue(result.isOnDevice)
        XCTAssertNotNil(result.id)
        XCTAssertNotNil(result.timestamp)
    }

    func testTranslationSupportingEnums() {
        XCTAssertEqual(TranslationMode.allCases.count, 4)
        XCTAssertEqual(TranslationMode.realtime.rawValue, "Realtime")
        XCTAssertEqual(TranslationMode.lyrics.rawValue, "Lyrics")
        XCTAssertEqual(TranslationProvider.allCases.count, 3)
    }

    func testTranslateEngineSharedInstance() {
        let engine = EchoelTranslateEngine.shared
        XCTAssertNotNil(engine)
        XCTAssertEqual(engine.sourceLanguage, .english)
        XCTAssertTrue(engine.autoDetectSource)
        XCTAssertEqual(engine.mode, .realtime)

        engine.sourceLanguage = .english
        let pairs = engine.availablePairs()
        XCTAssertEqual(pairs.count, 22,
                       "Available pairs should exclude source language (23 - 1 = 22)")
        XCTAssertFalse(pairs.contains(.english))
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - 2. EchoelSpeechEngine Tests
    // ═══════════════════════════════════════════════════════════════════════

    func testSpeechTypesAndEnums() {
        XCTAssertEqual(SpeechBackend.allCases.count, 3)
        XCTAssertEqual(SpeechBackend.auto.rawValue, "Auto")
        XCTAssertEqual(SpeechEngineState.idle.rawValue, "Idle")
        XCTAssertEqual(SpeechEngineState.listening.rawValue, "Listening")
        XCTAssertEqual(SpeechEngineState.error.rawValue, "Error")
    }

    func testRecognizedWordAndSegment() {
        let word = RecognizedWord(
            text: "hello",
            startTime: 1.0,
            endTime: 1.5,
            confidence: 0.98,
            isFinal: true
        )
        XCTAssertEqual(word.text, "hello")
        XCTAssertEqual(word.duration, 0.5, accuracy: 0.001)
        XCTAssertEqual(word.confidence, 0.98, accuracy: 0.001)
        XCTAssertTrue(word.isFinal)
        XCTAssertNotNil(word.id)

        let segment = TranscriptionSegment(
            text: "Hello world",
            startTime: 0.0,
            endTime: 2.0,
            isFinal: false
        )
        XCTAssertEqual(segment.text, "Hello world")
        XCTAssertEqual(segment.duration, 2.0, accuracy: 0.001)
        XCTAssertFalse(segment.isFinal)
    }

    func testSpeechEngineSharedInstance() {
        let engine = EchoelSpeechEngine.shared
        XCTAssertNotNil(engine)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.activeBackend, .auto)
        XCTAssertFalse(engine.autoTranslate)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - 3. EchoelLyricsEngine Tests
    // ═══════════════════════════════════════════════════════════════════════

    func testLyricsWordAndLineTypes() {
        let word = LyricsWord(text: "dream", startTime: 5.0, endTime: 5.8, confidence: 0.92)
        XCTAssertEqual(word.text, "dream")
        XCTAssertEqual(word.startTime, 5.0, accuracy: 0.001)
        XCTAssertEqual(word.confidence, 0.92, accuracy: 0.001)

        let line = LyricsLine(
            text: "Somewhere over the rainbow",
            startTime: 10.0,
            endTime: 14.5,
            translations: ["es": "En algun lugar sobre el arcoiris"]
        )
        XCTAssertEqual(line.text, "Somewhere over the rainbow")
        XCTAssertEqual(line.duration, 4.5, accuracy: 0.001)
        XCTAssertEqual(line.translations["es"], "En algun lugar sobre el arcoiris")
    }

    func testLyricsDocumentInitialization() {
        let doc = LyricsDocument(
            title: "Test Song",
            artist: "Test Artist",
            language: "en",
            lines: [],
            duration: 180.0
        )
        XCTAssertEqual(doc.title, "Test Song")
        XCTAssertEqual(doc.artist, "Test Artist")
        XCTAssertEqual(doc.language, "en")
        XCTAssertEqual(doc.duration, 180.0, accuracy: 0.001)
        XCTAssertEqual(doc.wordCount, 0)
        XCTAssertEqual(doc.fullText, "")
        XCTAssertFalse(doc.isEdited)
    }

    func testLyricsEnumsAndEngine() {
        XCTAssertEqual(LyricsExtractionMode.allCases.count, 3)
        XCTAssertEqual(LyricsDisplayMode.allCases.count, 5)
        XCTAssertEqual(LyricsDisplayMode.karaoke.rawValue, "Karaoke")
        XCTAssertEqual(LyricsExportFormat.allCases.count, 5)
        XCTAssertEqual(LyricsExportFormat.vtt.rawValue, "WebVTT")

        let engine = EchoelLyricsEngine.shared
        XCTAssertNotNil(engine)
        XCTAssertNil(engine.document)
        XCTAssertFalse(engine.isExtracting)
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(engine.displayMode, .subtitle)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - 4. EchoelSubtitleRenderer Tests
    // ═══════════════════════════════════════════════════════════════════════

    func testSubtitleTypesAndEnums() {
        XCTAssertEqual(SubtitlePosition.allCases.count, 4)
        XCTAssertEqual(SubtitlePosition.bottom.rawValue, "Bottom")
        XCTAssertEqual(SubtitleAnimation.allCases.count, 7)
        XCTAssertEqual(SubtitleAnimation.highlight.rawValue, "Highlight")
        XCTAssertEqual(EchoelSubtitleRenderer.SubtitlePreset.allCases.count, 4)
        XCTAssertEqual(EchoelSubtitleRenderer.SubtitlePreset.concert.rawValue, "Concert")
    }

    func testSubtitleEntryInitialization() {
        let entry = SubtitleEntry(
            text: "Hello World",
            language: .english,
            duration: 5.0,
            highlightedWordIndex: nil,
            progress: 0.0
        )
        XCTAssertEqual(entry.text, "Hello World")
        XCTAssertEqual(entry.language, .english)
        XCTAssertEqual(entry.duration, 5.0, accuracy: 0.001)
        XCTAssertNil(entry.highlightedWordIndex)
        XCTAssertNotNil(entry.id)
    }

    func testSubtitleRendererSharedInstance() {
        let renderer = EchoelSubtitleRenderer.shared
        XCTAssertNotNil(renderer)
        XCTAssertTrue(renderer.isVisible)
        XCTAssertEqual(renderer.maxLanguages, 3)
        XCTAssertTrue(renderer.autoHide)
        XCTAssertFalse(renderer.generateWebVTT)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - 5. EchoelMindEngine Tests
    // ═══════════════════════════════════════════════════════════════════════

    func testMindTaskEnum() {
        XCTAssertEqual(MindTask.allCases.count, 9,
                       "MindTask should have 9 cases")
        XCTAssertEqual(MindTask.summarize.rawValue, "Summarize")
        XCTAssertEqual(MindTask.narrative.rawValue, "Narrative")
        XCTAssertEqual(MindTask.correct.rawValue, "Correct")
    }

    func testMindMoodBioReactiveMapping() {
        XCTAssertEqual(MindMood.from(coherence: 0.1), .stressed)
        XCTAssertEqual(MindMood.from(coherence: 0.3), .calm)
        XCTAssertEqual(MindMood.from(coherence: 0.5), .focused)
        XCTAssertEqual(MindMood.from(coherence: 0.7), .creative)
        XCTAssertEqual(MindMood.from(coherence: 0.9), .energetic)

        XCTAssertEqual(MindMood.calm.rawValue, "calm, serene, contemplative")
        XCTAssertEqual(MindMood.focused.rawValue, "focused, precise, analytical")
        XCTAssertEqual(MindMood.stressed.rawValue, "grounding, reassuring, simple")
    }

    func testMindResponseInitialization() {
        let response = MindResponse(
            task: .summarize,
            input: "Test input",
            output: "Test output",
            mood: .focused,
            tokenCount: 50,
            latencyMs: 120.0,
            isOnDevice: true
        )
        XCTAssertEqual(response.task, .summarize)
        XCTAssertEqual(response.input, "Test input")
        XCTAssertEqual(response.output, "Test output")
        XCTAssertEqual(response.mood, .focused)
        XCTAssertEqual(response.tokenCount, 50)
        XCTAssertEqual(response.latencyMs, 120.0, accuracy: 0.001)
        XCTAssertTrue(response.isOnDevice)
        XCTAssertNotNil(response.id)
        XCTAssertNotNil(response.timestamp)
    }

    func testMindSchemasAndEngine() {
        XCTAssertEqual(MindSchema.moodClassification.name, "MoodClassification")
        XCTAssertEqual(MindSchema.moodClassification.fields.count, 3)
        XCTAssertEqual(MindSchema.sessionSummary.name, "SessionSummary")
        XCTAssertEqual(MindSchema.sessionSummary.fields.count, 5)
        XCTAssertEqual(MindSchema.creativeSuggestion.fields.count, 3)
        XCTAssertEqual(MindSchema.lyricsCorrection.fields.count, 3)

        let engine = EchoelMindEngine.shared
        XCTAssertNotNil(engine)
        XCTAssertFalse(engine.isGenerating)
        XCTAssertEqual(engine.currentMood, .focused)
        XCTAssertEqual(engine.totalTokens, 0)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - 6. EchoelMintEngine Tests
    // ═══════════════════════════════════════════════════════════════════════

    func testMintTypeAndRarityEnums() {
        XCTAssertEqual(MintType.allCases.count, 4)
        XCTAssertEqual(MintType.moment.rawValue, "Moment")
        XCTAssertEqual(MintType.live.rawValue, "Live")

        XCTAssertEqual(MintRarity.allCases.count, 5)
        XCTAssertEqual(MintRarity.common.rawValue, "Common")
        XCTAssertEqual(MintRarity.mythic.rawValue, "Mythic")
        XCTAssertEqual(MintRarity.common.colorHex, "#9CA3AF")
        XCTAssertEqual(MintRarity.mythic.colorHex, "#EC4899")
    }

    func testMintRarityBioReactiveMapping() {
        XCTAssertEqual(MintRarity.from(coherence: 0.3), .common)
        XCTAssertEqual(MintRarity.from(coherence: 0.65), .uncommon)
        XCTAssertEqual(MintRarity.from(coherence: 0.85), .rare)
        XCTAssertEqual(MintRarity.from(coherence: 0.96), .legendary)
        XCTAssertEqual(
            MintRarity.from(coherence: 0.96, isLive: true, sustainedSeconds: 31),
            .mythic,
            ">95% coherence + live + sustained should be Mythic"
        )
    }

    func testBioReactiveAttributesEmpty() {
        let empty = BioReactiveAttributes.empty
        XCTAssertEqual(empty.coherence, 0)
        XCTAssertEqual(empty.heartRate, 0)
        XCTAssertEqual(empty.fieldGeometry, "grid")
        XCTAssertEqual(empty.spatialDimension, "stereo")
    }

    func testMintDocumentInitAndMetadata() {
        let doc = MintDocument(
            name: "Test Moment",
            description: "A test NFT",
            artistName: "Echoel",
            mintType: .moment,
            bioAttributes: .empty
        )
        XCTAssertEqual(doc.name, "Test Moment")
        XCTAssertEqual(doc.artistName, "Echoel")
        XCTAssertEqual(doc.mintType, .moment)
        XCTAssertEqual(doc.rarity, .common)
        XCTAssertEqual(doc.royaltyPercentage, 10.0, accuracy: 0.001)
        XCTAssertEqual(doc.editionSize, 1)
        XCTAssertFalse(doc.isMinted)
        XCTAssertNil(doc.mintHash)

        let metadata = doc.toMetadata()
        XCTAssertEqual(metadata["name"] as? String, "Test Moment")
        XCTAssertNotNil(metadata["attributes"])
        XCTAssertNotNil(metadata["external_url"])
    }

    func testMintEngineSharedInstance() {
        let engine = EchoelMintEngine.shared
        XCTAssertNotNil(engine)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertNil(engine.activeCapture)
        XCTAssertEqual(engine.defaultRoyaltyPercentage, 10.0, accuracy: 0.001)

        XCTAssertEqual(MintEngineState.idle.rawValue, "Idle")
        XCTAssertEqual(MintEngineState.capturing.rawValue, "Capturing")
        XCTAssertEqual(MintEngineState.readyToMint.rawValue, "Ready")
        XCTAssertEqual(MintEngineState.minted.rawValue, "Minted")
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - 7. EchoelAvatarEngine Tests
    // ═══════════════════════════════════════════════════════════════════════

    func testAvatarStyleEnum() {
        XCTAssertEqual(AvatarStyle.allCases.count, 7)
        XCTAssertEqual(AvatarStyle.photorealistic.rawValue, "Photorealistic")
        XCTAssertEqual(AvatarStyle.cymatics.rawValue, "Cymatics")
        XCTAssertEqual(AvatarStyle.abstract.rawValue, "Abstract")
        XCTAssertTrue(AvatarStyle.photorealistic.description.contains("Gaussian"))
        XCTAssertTrue(AvatarStyle.silhouette.description.contains("Privacy"))
    }

    func testAvatarAnimationStateEnum() {
        XCTAssertEqual(AvatarAnimationState.idle.rawValue, "Idle")
        XCTAssertEqual(AvatarAnimationState.speaking.rawValue, "Speaking")
        XCTAssertEqual(AvatarAnimationState.singing.rawValue, "Singing")
        XCTAssertEqual(AvatarAnimationState.performing.rawValue, "Performing")
        XCTAssertEqual(AvatarAnimationState.meditating.rawValue, "Meditating")
        XCTAssertEqual(AvatarAnimationState.listening.rawValue, "Listening")
    }

    func testFacialExpressionProperties() {
        // Neutral
        let neutral = FacialExpression.neutral
        XCTAssertEqual(neutral.jawOpen, 0)
        XCTAssertFalse(neutral.isSmiling)
        XCTAssertFalse(neutral.isMouthOpen)
        XCTAssertEqual(neutral.emotionalValence, 0, accuracy: 0.001)

        // Smiling
        var smiling = FacialExpression()
        smiling.mouthSmileLeft = 0.5
        smiling.mouthSmileRight = 0.5
        XCTAssertTrue(smiling.isSmiling)
        XCTAssertGreaterThan(smiling.emotionalValence, 0)

        // Mouth open
        var mouthOpen = FacialExpression()
        mouthOpen.jawOpen = 0.5
        XCTAssertTrue(mouthOpen.isMouthOpen)
    }

    func testAvatarAuraBioReactiveMapping() {
        let highCoherence = AvatarAura.from(coherence: 0.9, heartRate: 60, energy: 0.8)
        XCTAssertEqual(highCoherence.geometry, .fibonacci)
        XCTAssertGreaterThan(highCoherence.intensity, 0.5)

        let lowCoherence = AvatarAura.from(coherence: 0.2, heartRate: 80, energy: 0.3)
        XCTAssertEqual(lowCoherence.geometry, .chaotic)

        XCTAssertEqual(AvatarAura.AuraGeometry.allCases.count, 5)
    }

    func testAvatarEngineSharedInstance() {
        let engine = EchoelAvatarEngine.shared
        XCTAssertNotNil(engine)
        XCTAssertEqual(engine.style, .particleCloud)
        XCTAssertEqual(engine.animationState, .idle)
        XCTAssertTrue(engine.isVisible)
        XCTAssertTrue(engine.isMirrored)
        XCTAssertEqual(EchoelAvatarEngine.RenderQuality.allCases.count, 4)
        XCTAssertEqual(EchoelAvatarEngine.RenderQuality.balanced.rawValue, "Balanced")
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - 8. EchoelWorldEngine Tests
    // ═══════════════════════════════════════════════════════════════════════

    func testWorldBiomeEnum() {
        XCTAssertEqual(WorldBiome.allCases.count, 8)
        XCTAssertFalse(WorldBiome.crystal.ambientSound.isEmpty)
        XCTAssertEqual(WorldBiome.ocean.ambientSound, "deep_ocean_waves")

        let crystal = WorldBiome.crystal.primaryColor
        XCTAssertGreaterThan(crystal.b, crystal.r, "Crystal should be blue-tinted")
        let forest = WorldBiome.forest.primaryColor
        XCTAssertGreaterThan(forest.g, forest.r, "Forest should be green-tinted")
    }

    func testWorldBiomeBioReactiveMapping() {
        XCTAssertEqual(WorldBiome.from(coherence: 0.9, energy: 0.5), .mountain)
        XCTAssertEqual(WorldBiome.from(coherence: 0.7, energy: 0.6), .crystal)
        XCTAssertEqual(WorldBiome.from(coherence: 0.7, energy: 0.3), .garden)
        XCTAssertEqual(WorldBiome.from(coherence: 0.5, energy: 0.7), .nebula)
        XCTAssertEqual(WorldBiome.from(coherence: 0.5, energy: 0.3), .forest)
        XCTAssertEqual(WorldBiome.from(coherence: 0.2, energy: 0.7), .ocean)
        XCTAssertEqual(WorldBiome.from(coherence: 0.2, energy: 0.3), .desert)
    }

    func testWorldWeatherBioReactiveMapping() {
        XCTAssertEqual(WorldWeather.allCases.count, 6)
        XCTAssertEqual(WorldWeather.from(hrvSDNN: 90, coherence: 0.5), .clear)
        XCTAssertEqual(WorldWeather.from(hrvSDNN: 60, coherence: 0.5), .gentle)
        XCTAssertEqual(WorldWeather.from(hrvSDNN: 40, coherence: 0.5), .rain)
        XCTAssertEqual(WorldWeather.from(hrvSDNN: 20, coherence: 0.5), .storm)
        XCTAssertEqual(WorldWeather.from(hrvSDNN: 100, coherence: 0.95), .aurora,
                       "Peak coherence should produce aurora regardless of HRV")
    }

    func testWorldStateAndEngine() {
        XCTAssertEqual(WorldTimeOfDay.allCases.count, 7)

        let state = WorldState.initial
        XCTAssertEqual(state.biome, .forest)
        XCTAssertEqual(state.weather, .clear)
        XCTAssertEqual(state.placeName, "Genesis")
        XCTAssertEqual(state.seed, 0)

        let engine = EchoelWorldEngine.shared
        XCTAssertNotNil(engine)
        XCTAssertFalse(engine.isActive)
        XCTAssertFalse(engine.biomeLocked)
        XCTAssertEqual(engine.evolutionSpeed, 1.0, accuracy: 0.001)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - 9. EchoelGodotBridge Tests
    // ═══════════════════════════════════════════════════════════════════════

    func testGodotSceneEnum() {
        XCTAssertEqual(GodotScene.allCases.count, 10)
        XCTAssertEqual(GodotScene.bioReactiveWorld.rawValue, "bio_reactive_world")
        XCTAssertEqual(GodotScene.bioReactiveWorld.scenePath, "res://scenes/bio_reactive_world.tscn")
        XCTAssertEqual(GodotScene.nftGallery.scenePath, "res://scenes/nft_gallery.tscn")
    }

    func testGodotRendererAndStateEnums() {
        XCTAssertEqual(GodotRenderer.allCases.count, 3)
        XCTAssertEqual(GodotRenderer.forwardPlus.rawValue, "Forward+")
        XCTAssertEqual(GodotRenderer.mobile.rawValue, "Mobile")

        XCTAssertEqual(GodotEngineState.notLoaded.rawValue, "Not Loaded")
        XCTAssertEqual(GodotEngineState.running.rawValue, "Running")
        XCTAssertEqual(GodotEngineState.error.rawValue, "Error")
    }

    func testGodotBridgeSharedInstance() {
        let bridge = EchoelGodotBridge.shared
        XCTAssertNotNil(bridge)
        XCTAssertEqual(bridge.state, .notLoaded)
        XCTAssertNil(bridge.activeScene)
        XCTAssertEqual(bridge.availableScenes.count, GodotScene.allCases.count)

        let params = GodotSceneParameters()
        XCTAssertEqual(params.coherence, 0.5, accuracy: 0.001)
        XCTAssertEqual(params.heartRate, 70, accuracy: 0.001)
        XCTAssertEqual(params.dominantFrequency, 440, accuracy: 0.001)
        XCTAssertEqual(params.biome, "forest")
        XCTAssertEqual(params.weather, "clear")
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - 10. EchoelOSCEngine Tests
    // ═══════════════════════════════════════════════════════════════════════

    func testOSCTypeEnum() {
        XCTAssertEqual(OSCType.int32.rawValue, Character("i"))
        XCTAssertEqual(OSCType.float32.rawValue, Character("f"))
        XCTAssertEqual(OSCType.string.rawValue, Character("s"))
        XCTAssertEqual(OSCType.blob.rawValue, Character("b"))
        XCTAssertEqual(OSCType.trueVal.rawValue, Character("T"))
        XCTAssertEqual(OSCType.falseVal.rawValue, Character("F"))
        XCTAssertEqual(OSCType.nilVal.rawValue, Character("N"))
    }

    func testOSCValueConversions() {
        // Float conversions
        XCTAssertEqual(OSCValue.float32(0.5).floatValue, 0.5, accuracy: 0.001)
        XCTAssertEqual(OSCValue.int32(42).floatValue, 42.0, accuracy: 0.001)
        XCTAssertEqual(OSCValue.double64(3.14).floatValue, Float(3.14), accuracy: 0.01)
        XCTAssertEqual(OSCValue.int64(100).floatValue, 100.0, accuracy: 0.001)
        XCTAssertNil(OSCValue.string("hello").floatValue)
        XCTAssertNil(OSCValue.bool(true).floatValue)
        XCTAssertNil(OSCValue.nilValue.floatValue)

        // String conversions
        XCTAssertEqual(OSCValue.string("hello").stringValue, "hello")
        XCTAssertNil(OSCValue.float32(1.0).stringValue)

        // Int conversions
        XCTAssertEqual(OSCValue.int32(42).intValue, 42)
        XCTAssertEqual(OSCValue.float32(3.7).intValue, 3)
        XCTAssertNil(OSCValue.string("hello").intValue)
    }

    func testOSCMessageCreation() {
        let msg = OSCMessage(address: "/test/value", arguments: [.float32(0.5), .string("hello")])
        XCTAssertEqual(msg.address, "/test/value")
        XCTAssertEqual(msg.arguments.count, 2)
        XCTAssertEqual(msg.arguments[0].floatValue, 0.5, accuracy: 0.001)
        XCTAssertEqual(msg.arguments[1].stringValue, "hello")

        let floatMsg = OSCMessage.float("/bio/coherence", 0.85)
        XCTAssertEqual(floatMsg.arguments.count, 1)
        XCTAssertEqual(floatMsg.arguments[0].floatValue, 0.85, accuracy: 0.001)

        let stringMsg = OSCMessage.string("/world/biome", "forest")
        XCTAssertEqual(stringMsg.arguments[0].stringValue, "forest")

        let multiFloat = OSCMessage.floats("/spectrum", [0.1, 0.5, 0.9])
        XCTAssertEqual(multiFloat.arguments.count, 3)
    }

    func testOSCMessageEncodeAndDecode() {
        let original = OSCMessage(
            address: "/echoelmusic/bio/coherence",
            arguments: [.float32(0.85)]
        )
        let encoded = original.encode()
        XCTAssertGreaterThan(encoded.count, 0)

        let decoded = OSCMessage.decode(from: encoded)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.address, "/echoelmusic/bio/coherence")
        XCTAssertEqual(decoded?.arguments.count, 1)
        if let value = decoded?.arguments.first?.floatValue {
            XCTAssertEqual(value, 0.85, accuracy: 0.001)
        } else {
            XCTFail("Decoded float value should exist")
        }

        // Bundle encoding
        let bundle = OSCBundle(timetag: 1, elements: [
            .float("/bio/coherence", 0.8),
            .float("/bio/heartrate", 72),
        ])
        let bundleData = bundle.encode()
        XCTAssertGreaterThan(bundleData.count, 0)
    }

    func testOSCEngineSharedInstance() {
        let engine = EchoelOSCEngine.shared
        XCTAssertNotNil(engine)
        XCTAssertFalse(engine.isServerRunning)
        XCTAssertEqual(engine.serverPort, 8000)
        XCTAssertTrue(engine.targets.isEmpty)
        XCTAssertFalse(engine.isAutoBroadcasting)
        XCTAssertEqual(engine.namespacePrefix, "/echoelmusic")
    }

    func testOSCApplicationDefaultPorts() {
        XCTAssertEqual(OSCTarget.OSCApplication.allCases.count, 15)
        XCTAssertEqual(OSCTarget.OSCApplication.touchDesigner.defaultPort, 7000)
        XCTAssertEqual(OSCTarget.OSCApplication.qlab.defaultPort, 53000)
        XCTAssertEqual(OSCTarget.OSCApplication.superCollider.defaultPort, 57120)
        XCTAssertEqual(OSCTarget.OSCApplication.custom.defaultPort, 9000)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - 11. EchoelShowControl Tests
    // ═══════════════════════════════════════════════════════════════════════

    func testMSCCommandEnum() {
        XCTAssertEqual(MSCCommand.allCases.count, 12)
        XCTAssertEqual(MSCCommand.go.rawValue, 0x01)
        XCTAssertEqual(MSCCommand.allOff.rawValue, 0x08)
        XCTAssertEqual(MSCCommand.fire.rawValue, 0x07)
        XCTAssertEqual(MSCCommand.go.description, "GO")
        XCTAssertEqual(MSCCommand.stop.description, "STOP")
        XCTAssertEqual(MSCCommand.allOff.description, "ALL OFF")
        XCTAssertEqual(MSCCommand.goPanic.description, "PANIC")
    }

    func testMSCDeviceGroupEnum() {
        XCTAssertEqual(MSCDeviceGroup.allCases.count, 18)
        XCTAssertEqual(MSCDeviceGroup.lighting.rawValue, 0x01)
        XCTAssertEqual(MSCDeviceGroup.pyro.rawValue, 0x60)
        XCTAssertEqual(MSCDeviceGroup.allTypes.rawValue, 0x7F)
    }

    func testMSCCueNumberFormatAndEncoding() {
        let cue1 = MSCCueNumber(major: "5")
        XCTAssertEqual(cue1.description, "5")

        let cue2 = MSCCueNumber(major: "5", minor: "1")
        XCTAssertEqual(cue2.description, "5.1")
        let encoded = cue2.encode()
        XCTAssertEqual(String(bytes: encoded, encoding: .utf8), "5.1")

        let cue3 = MSCCueNumber(major: "5", minor: "1", sub: "3")
        XCTAssertEqual(cue3.description, "5.1.3")
    }

    func testMSCEventEncodingAndDecoding() {
        let event = MSCEvent(
            command: .go,
            deviceGroup: .lighting,
            cueNumber: MSCCueNumber(major: "1"),
            deviceId: 0x7F
        )
        let bytes = event.encode()
        XCTAssertEqual(bytes.first, 0xF0, "Should start with SysEx header")
        XCTAssertEqual(bytes[1], 0x7F, "Should have Universal Real-Time byte")
        XCTAssertEqual(bytes[3], 0x02, "Should have MSC sub-ID")
        XCTAssertEqual(bytes.last, 0xF7, "Should end with SysEx terminator")

        // Decode
        let decodeBytes: [UInt8] = [0xF0, 0x7F, 0x7F, 0x02, 0x01, 0x01, 0x31, 0xF7]
        let decoded = MSCEvent.decode(from: decodeBytes)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.command, .go)
        XCTAssertEqual(decoded?.deviceGroup, .lighting)
        XCTAssertEqual(decoded?.cueNumber?.major, "1")
    }

    func testShowControlSharedInstance() {
        let show = EchoelShowControl.shared
        XCTAssertNotNil(show)
        XCTAssertFalse(show.mscEnabled)
        XCTAssertFalse(show.mackieEnabled)
        XCTAssertFalse(show.huiEnabled)
        XCTAssertEqual(show.mscDeviceId, 0x7F)
        XCTAssertEqual(show.channels.count, 8)

        XCTAssertGreaterThan(MCUButton.allCases.count, 30)
        XCTAssertEqual(MCUButton.play.rawValue, 0x5E)
        XCTAssertEqual(MCUButton.stop.rawValue, 0x5D)

        XCTAssertEqual(EchoelShowControl.ControlSurfaceProtocol.allCases.count, 3)
        XCTAssertEqual(EchoelShowControl.ControlSurfaceProtocol.mackieControl.rawValue, "Mackie Control")
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - 12. EchoelIntegrationHub Tests
    // ═══════════════════════════════════════════════════════════════════════

    func testIntegrationProtocolTypes() {
        XCTAssertEqual(IntegrationProtocol.ProtocolCategory.allCases.count, 6)
        XCTAssertEqual(IntegrationProtocol.ProtocolCategory.controlProtocol.rawValue, "Control Protocol")
        XCTAssertEqual(IntegrationProtocol.ProtocolStatus.active.rawValue, "Active")
        XCTAssertEqual(IntegrationProtocol.ProtocolStatus.standby.rawValue, "Standby")
        XCTAssertEqual(IntegrationProtocol.ProtocolStatus.error.rawValue, "Error")
        XCTAssertEqual(DiscoveredDevice.DeviceType.allCases.count, 17)
    }

    func testIntegrationHubSharedInstance() {
        let hub = EchoelIntegrationHub.shared
        XCTAssertNotNil(hub)
        XCTAssertGreaterThan(hub.protocols.count, 0)
        XCTAssertEqual(hub.systemHealth, 1.0, accuracy: 0.001)
        XCTAssertFalse(hub.isScanning)

        let summary = hub.summary
        XCTAssertTrue(summary.contains("IntegrationHub"))
        XCTAssertTrue(summary.contains("protocols"))
    }

    func testIntegrationHubRegisteredProtocols() {
        let hub = EchoelIntegrationHub.shared
        let protocolIds = hub.protocols.map(\.id)

        XCTAssertTrue(protocolIds.contains("osc"))
        XCTAssertTrue(protocolIds.contains("msc"))
        XCTAssertTrue(protocolIds.contains("mackie"))
        XCTAssertTrue(protocolIds.contains("midi"))
        XCTAssertTrue(protocolIds.contains("dmx"))
        XCTAssertTrue(protocolIds.contains("dante"))
    }

    func testIntegrationRouteCreationAndRemoval() {
        let hub = EchoelIntegrationHub.shared
        let initialCount = hub.routes.count

        let route = hub.createRoute(
            name: "Test Route",
            source: IntegrationRoute.RouteEndpoint(
                protocol_: "EngineBus",
                device: "TestDevice",
                parameter: "coherence"
            ),
            destination: IntegrationRoute.RouteEndpoint(
                protocol_: "OSC",
                device: "TestTarget",
                parameter: "/bio/coherence"
            )
        )

        XCTAssertEqual(route.name, "Test Route")
        XCTAssertTrue(route.isActive)
        XCTAssertEqual(hub.routes.count, initialCount + 1)

        // Clean up
        hub.removeRoute(id: route.id)
        XCTAssertEqual(hub.routes.count, initialCount)
    }
}

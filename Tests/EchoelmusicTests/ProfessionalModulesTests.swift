import XCTest
@testable import Echoelmusic

/// Tests for Professional Studio Modules
/// Plugin Host, Visual Engine, Dolby Atmos, Medical Bridge, Social Media

// MARK: - Plugin Host Bridge Tests

@MainActor
final class PluginHostBridgeTests: XCTestCase {

    // MARK: - Plugin Format Tests

    func testPluginFormatEnumeration() throws {
        let formats = PluginFormat.allCases

        XCTAssertEqual(formats.count, 4)
        XCTAssertTrue(formats.contains(.vst3))
        XCTAssertTrue(formats.contains(.audioUnit))
        XCTAssertTrue(formats.contains(.aax))
        XCTAssertTrue(formats.contains(.clap))
    }

    func testPluginFormatFileExtensions() throws {
        XCTAssertEqual(PluginFormat.vst3.fileExtension, "vst3")
        XCTAssertEqual(PluginFormat.audioUnit.fileExtension, "component")
        XCTAssertEqual(PluginFormat.aax.fileExtension, "aaxplugin")
        XCTAssertEqual(PluginFormat.clap.fileExtension, "clap")
    }

    func testPluginFormatSearchPaths() throws {
        // VST3 should search Library paths
        let vst3Paths = PluginFormat.vst3.searchPaths
        XCTAssertFalse(vst3Paths.isEmpty)
        XCTAssertTrue(vst3Paths.contains { $0.contains("VST3") })

        // Audio Unit should search Components paths
        let auPaths = PluginFormat.audioUnit.searchPaths
        XCTAssertFalse(auPaths.isEmpty)
        XCTAssertTrue(auPaths.contains { $0.contains("Components") })
    }

    // MARK: - Plugin Metadata Tests

    func testPluginMetadataInitialization() throws {
        let metadata = PluginMetadata(
            name: "TestPlugin",
            vendor: "TestVendor",
            version: "1.0.0",
            format: .vst3,
            category: .synthesizer,
            path: URL(fileURLWithPath: "/test/path"),
            inputChannels: 0,
            outputChannels: 2,
            hasEditor: true,
            isSynth: true
        )

        XCTAssertEqual(metadata.name, "TestPlugin")
        XCTAssertEqual(metadata.vendor, "TestVendor")
        XCTAssertEqual(metadata.version, "1.0.0")
        XCTAssertEqual(metadata.format, .vst3)
        XCTAssertEqual(metadata.category, .synthesizer)
        XCTAssertEqual(metadata.inputChannels, 0)
        XCTAssertEqual(metadata.outputChannels, 2)
        XCTAssertTrue(metadata.hasEditor)
        XCTAssertTrue(metadata.isSynth)
    }

    func testPluginCategoryEnumeration() throws {
        let categories = PluginCategory.allCases

        XCTAssertGreaterThanOrEqual(categories.count, 8)
        XCTAssertTrue(categories.contains(.synthesizer))
        XCTAssertTrue(categories.contains(.effect))
        XCTAssertTrue(categories.contains(.analyzer))
        XCTAssertTrue(categories.contains(.dynamics))
        XCTAssertTrue(categories.contains(.eq))
        XCTAssertTrue(categories.contains(.reverb))
        XCTAssertTrue(categories.contains(.delay))
        XCTAssertTrue(categories.contains(.other))
    }

    // MARK: - Plugin Instance Tests

    func testPluginInstanceInitialization() throws {
        let metadata = PluginMetadata(
            name: "Test",
            vendor: "Test",
            version: "1.0",
            format: .vst3,
            category: .effect,
            path: URL(fileURLWithPath: "/test"),
            inputChannels: 2,
            outputChannels: 2,
            hasEditor: false,
            isSynth: false
        )

        let instance = PluginInstance(metadata: metadata)

        XCTAssertEqual(instance.metadata.name, "Test")
        XCTAssertFalse(instance.isLoaded)
        XCTAssertFalse(instance.isBypassed)
    }

    func testPluginInstanceBypassToggle() throws {
        let metadata = PluginMetadata(
            name: "Test",
            vendor: "Test",
            version: "1.0",
            format: .audioUnit,
            category: .eq,
            path: URL(fileURLWithPath: "/test"),
            inputChannels: 2,
            outputChannels: 2,
            hasEditor: true,
            isSynth: false
        )

        let instance = PluginInstance(metadata: metadata)
        XCTAssertFalse(instance.isBypassed)

        instance.isBypassed = true
        XCTAssertTrue(instance.isBypassed)
    }

    // MARK: - Plugin Host Manager Tests

    func testPluginHostManagerInitialization() throws {
        let manager = PluginHostManager()

        XCTAssertEqual(manager.loadedPlugins.count, 0)
        XCTAssertEqual(manager.sampleRate, 44100)
        XCTAssertEqual(manager.blockSize, 512)
    }

    func testPluginHostManagerConfiguration() throws {
        let manager = PluginHostManager()

        manager.configure(sampleRate: 96000, blockSize: 256)

        XCTAssertEqual(manager.sampleRate, 96000)
        XCTAssertEqual(manager.blockSize, 256)
    }

    // MARK: - Preset Manager Tests

    func testPresetManagerInitialization() throws {
        let presetManager = PluginPresetManager()

        XCTAssertNotNil(presetManager)
        XCTAssertTrue(presetManager.presets.isEmpty)
    }
}

// MARK: - Node Based Visual Engine Tests

@MainActor
final class NodeBasedVisualEngineTests: XCTestCase {

    // MARK: - Node Type Tests

    func testVisualNodeTypeEnumeration() throws {
        let types = VisualNodeType.allCases

        XCTAssertGreaterThanOrEqual(types.count, 6)
        XCTAssertTrue(types.contains(.TOP))  // Texture operators
        XCTAssertTrue(types.contains(.CHOP)) // Channel operators
        XCTAssertTrue(types.contains(.SOP))  // Surface operators
        XCTAssertTrue(types.contains(.MAT))  // Material
        XCTAssertTrue(types.contains(.COMP)) // Components
        XCTAssertTrue(types.contains(.DAT))  // Data
    }

    // MARK: - TOP Node Tests

    func testNoiseTOPInitialization() throws {
        let noise = NoiseTOP()

        XCTAssertEqual(noise.nodeType, .TOP)
        XCTAssertEqual(noise.noiseType, .perlin)
        XCTAssertGreaterThan(noise.scale, 0)
    }

    func testNoiseTOPTypes() throws {
        let noiseTypes = NoiseTOP.NoiseType.allCases

        XCTAssertGreaterThanOrEqual(noiseTypes.count, 4)
        XCTAssertTrue(noiseTypes.contains(.perlin))
        XCTAssertTrue(noiseTypes.contains(.simplex))
        XCTAssertTrue(noiseTypes.contains(.worley))
        XCTAssertTrue(noiseTypes.contains(.fbm))
    }

    func testCompositeTOPOperations() throws {
        let composite = CompositeTOP()

        XCTAssertEqual(composite.nodeType, .TOP)

        let operations = CompositeTOP.BlendOperation.allCases
        XCTAssertGreaterThanOrEqual(operations.count, 6)
        XCTAssertTrue(operations.contains(.over))
        XCTAssertTrue(operations.contains(.add))
        XCTAssertTrue(operations.contains(.multiply))
        XCTAssertTrue(operations.contains(.screen))
    }

    func testFeedbackTOPParameters() throws {
        let feedback = FeedbackTOP()

        XCTAssertEqual(feedback.nodeType, .TOP)
        XCTAssertGreaterThanOrEqual(feedback.feedbackAmount, 0)
        XCTAssertLessThanOrEqual(feedback.feedbackAmount, 1)
    }

    // MARK: - CHOP Node Tests

    func testAudioSpectrumCHOPInitialization() throws {
        let spectrum = AudioSpectrumCHOP()

        XCTAssertEqual(spectrum.nodeType, .CHOP)
        XCTAssertGreaterThan(spectrum.fftSize, 0)
        XCTAssertTrue(spectrum.fftSize.isPowerOf2())
    }

    func testLFOCHOPWaveforms() throws {
        let lfo = LFOCHOP()

        XCTAssertEqual(lfo.nodeType, .CHOP)

        let waveforms = LFOCHOP.Waveform.allCases
        XCTAssertGreaterThanOrEqual(waveforms.count, 5)
        XCTAssertTrue(waveforms.contains(.sine))
        XCTAssertTrue(waveforms.contains(.triangle))
        XCTAssertTrue(waveforms.contains(.square))
        XCTAssertTrue(waveforms.contains(.sawtooth))
        XCTAssertTrue(waveforms.contains(.noise))
    }

    func testLFOCHOPFrequencyRange() throws {
        let lfo = LFOCHOP()

        XCTAssertGreaterThan(lfo.frequency, 0)

        lfo.frequency = 10.0
        XCTAssertEqual(lfo.frequency, 10.0, accuracy: 0.001)
    }

    func testBioReactiveCHOPUniqueness() throws {
        // BioReactiveCHOP is unique to Echoelmusic
        let bioChop = BioReactiveCHOP()

        XCTAssertEqual(bioChop.nodeType, .CHOP)
        XCTAssertNotNil(bioChop.hrvInput)
        XCTAssertNotNil(bioChop.heartRateInput)
        XCTAssertGreaterThanOrEqual(bioChop.smoothing, 0)
        XCTAssertLessThanOrEqual(bioChop.smoothing, 1)
    }

    // MARK: - SOP Node Tests

    func testSphereSOP() throws {
        let sphere = SphereSOP()

        XCTAssertEqual(sphere.nodeType, .SOP)
        XCTAssertGreaterThan(sphere.radius, 0)
        XCTAssertGreaterThan(sphere.segments, 0)
    }

    func testParticleSOP() throws {
        let particles = ParticleSOP()

        XCTAssertEqual(particles.nodeType, .SOP)
        XCTAssertGreaterThan(particles.particleCount, 0)
        XCTAssertGreaterThanOrEqual(particles.emissionRate, 0)
    }

    // MARK: - Node Graph Manager Tests

    func testNodeGraphManagerInitialization() throws {
        let manager = NodeGraphManager()

        XCTAssertEqual(manager.nodes.count, 0)
        XCTAssertEqual(manager.connections.count, 0)
    }

    func testNodeGraphManagerAddNode() throws {
        let manager = NodeGraphManager()
        let noise = NoiseTOP()

        manager.addNode(noise)

        XCTAssertEqual(manager.nodes.count, 1)
    }

    func testNodeGraphManagerConnections() throws {
        let manager = NodeGraphManager()
        let noise = NoiseTOP()
        let composite = CompositeTOP()

        let noiseID = manager.addNode(noise)
        let compositeID = manager.addNode(composite)

        manager.connect(from: noiseID, output: 0, to: compositeID, input: 0)

        XCTAssertEqual(manager.connections.count, 1)
    }
}

// MARK: - Dolby Atmos Renderer Tests

@MainActor
final class DolbyAtmosRendererTests: XCTestCase {

    // MARK: - Audio Object Tests

    func testAudioObjectInitialization() throws {
        let object = AudioObject(
            id: "test-object",
            name: "Test",
            position: SIMD3<Float>(0, 0, 0)
        )

        XCTAssertEqual(object.id, "test-object")
        XCTAssertEqual(object.name, "Test")
        XCTAssertEqual(object.position.x, 0)
        XCTAssertEqual(object.position.y, 0)
        XCTAssertEqual(object.position.z, 0)
        XCTAssertEqual(object.gain, 1.0)
        XCTAssertEqual(object.size, 0.0)  // Point source
    }

    func testAudioObjectPositionRange() throws {
        let object = AudioObject(
            id: "positioned",
            name: "Positioned",
            position: SIMD3<Float>(-1, 0.5, 1)
        )

        // Atmos uses normalized coordinates -1 to 1
        XCTAssertGreaterThanOrEqual(object.position.x, -1)
        XCTAssertLessThanOrEqual(object.position.x, 1)
        XCTAssertGreaterThanOrEqual(object.position.y, -1)
        XCTAssertLessThanOrEqual(object.position.y, 1)
        XCTAssertGreaterThanOrEqual(object.position.z, -1)
        XCTAssertLessThanOrEqual(object.position.z, 1)
    }

    // MARK: - Speaker Layout Tests

    func testSpeakerLayoutPresets() throws {
        let layouts = SpeakerLayout.presets

        XCTAssertGreaterThanOrEqual(layouts.count, 5)

        // Verify common formats exist
        let layoutNames = layouts.map { $0.name }
        XCTAssertTrue(layoutNames.contains("5.1"))
        XCTAssertTrue(layoutNames.contains("7.1"))
        XCTAssertTrue(layoutNames.contains("7.1.4"))
        XCTAssertTrue(layoutNames.contains("9.1.6"))
    }

    func testSpeakerLayout51() throws {
        let layout51 = SpeakerLayout.preset51

        XCTAssertEqual(layout51.name, "5.1")
        XCTAssertEqual(layout51.speakerCount, 6)  // L, R, C, LFE, Ls, Rs
        XCTAssertFalse(layout51.hasHeightSpeakers)
    }

    func testSpeakerLayout714() throws {
        let layout714 = SpeakerLayout.preset714

        XCTAssertEqual(layout714.name, "7.1.4")
        XCTAssertEqual(layout714.speakerCount, 12)  // 7 + 1 LFE + 4 height
        XCTAssertTrue(layout714.hasHeightSpeakers)
        XCTAssertEqual(layout714.heightSpeakerCount, 4)
    }

    func testSpeakerLayoutNHK222() throws {
        let layout222 = SpeakerLayout.presetNHK222

        XCTAssertEqual(layout222.name, "NHK 22.2")
        XCTAssertEqual(layout222.speakerCount, 24)  // 22 + 2 LFE
        XCTAssertTrue(layout222.hasHeightSpeakers)
    }

    // MARK: - Atmos Renderer Tests

    func testAtmosRendererInitialization() throws {
        let renderer = DolbyAtmosRenderer()

        XCTAssertEqual(renderer.objects.count, 0)
        XCTAssertEqual(renderer.outputLayout, .preset714)
        XCTAssertEqual(renderer.renderMode, .objectBased)
    }

    func testAtmosRendererAddObject() throws {
        let renderer = DolbyAtmosRenderer()
        let object = AudioObject(
            id: "obj1",
            name: "Vocals",
            position: SIMD3<Float>(0, 0, 0)
        )

        renderer.addObject(object)

        XCTAssertEqual(renderer.objects.count, 1)
        XCTAssertEqual(renderer.objects.first?.name, "Vocals")
    }

    func testAtmosRenderModes() throws {
        let modes = DolbyAtmosRenderer.RenderMode.allCases

        XCTAssertGreaterThanOrEqual(modes.count, 3)
        XCTAssertTrue(modes.contains(.objectBased))
        XCTAssertTrue(modes.contains(.channelBased))
        XCTAssertTrue(modes.contains(.binaural))
    }

    // MARK: - VBAP Tests

    func testVBAPCalculation() throws {
        let renderer = DolbyAtmosRenderer()

        // Center position should have roughly equal gains to L and R
        let gains = renderer.calculateVBAP(position: SIMD3<Float>(0, 0, 1))

        XCTAssertFalse(gains.isEmpty)

        // Sum of gains should be <= 1 (power preservation)
        let totalGain = gains.reduce(0) { $0 + $1 * $1 }
        XCTAssertLessThanOrEqual(totalGain, 1.0 + 0.01)  // Small tolerance
    }

    // MARK: - Binaural Tests

    func testBinauralHRTFInitialization() throws {
        let renderer = DolbyAtmosRenderer()
        renderer.renderMode = .binaural

        XCTAssertEqual(renderer.renderMode, .binaural)
        XCTAssertNotNil(renderer.hrftDatabase)
    }

    // MARK: - LFE Tests

    func testLFECrossover() throws {
        let renderer = DolbyAtmosRenderer()

        // Default LFE crossover should be around 80-120 Hz
        XCTAssertGreaterThanOrEqual(renderer.lfeCrossoverFrequency, 80)
        XCTAssertLessThanOrEqual(renderer.lfeCrossoverFrequency, 120)
    }

    // MARK: - ADM Export Tests

    func testADMMetadataExport() throws {
        let renderer = DolbyAtmosRenderer()

        let object = AudioObject(
            id: "main-vocal",
            name: "Lead Vocal",
            position: SIMD3<Float>(0, 0.2, 0.5)
        )
        renderer.addObject(object)

        let admXML = renderer.exportADMMetadata()

        XCTAssertFalse(admXML.isEmpty)
        XCTAssertTrue(admXML.contains("audioObject"))
        XCTAssertTrue(admXML.contains("Lead Vocal"))
    }
}

// MARK: - Medical Imaging Bridge Tests

@MainActor
final class MedicalImagingBridgeTests: XCTestCase {

    // MARK: - DICOM Reader Tests

    func testDICOMReaderInitialization() throws {
        let reader = DICOMReader()

        XCTAssertNotNil(reader)
        XCTAssertEqual(reader.loadedSeries.count, 0)
    }

    func testDICOMModalityTypes() throws {
        let modalities = DICOMModality.allCases

        XCTAssertGreaterThanOrEqual(modalities.count, 5)
        XCTAssertTrue(modalities.contains(.CT))
        XCTAssertTrue(modalities.contains(.MRI))
        XCTAssertTrue(modalities.contains(.ultrasound))
        XCTAssertTrue(modalities.contains(.xRay))
        XCTAssertTrue(modalities.contains(.PET))
    }

    // MARK: - NIFTI Reader Tests

    func testNIFTIReaderInitialization() throws {
        let reader = NIFTIReader()

        XCTAssertNotNil(reader)
    }

    func testNIFTIDataTypes() throws {
        let types = NIFTIDataType.allCases

        XCTAssertGreaterThanOrEqual(types.count, 3)
        XCTAssertTrue(types.contains(.structural))
        XCTAssertTrue(types.contains(.functional))
        XCTAssertTrue(types.contains(.diffusion))
    }

    // MARK: - EEG Analysis Tests

    func testEEGBandPowerAnalysis() throws {
        let processor = PhysiologicalWaveformProcessor()

        // Generate test EEG signal (simulated alpha wave ~10 Hz)
        let sampleRate = 256.0
        let duration = 4.0
        let samples = Int(sampleRate * duration)

        var testSignal: [Float] = []
        for i in 0..<samples {
            let t = Double(i) / sampleRate
            let alpha = Float(sin(2 * Double.pi * 10 * t))  // 10 Hz alpha
            testSignal.append(alpha)
        }

        let bandPowers = processor.analyzeEEGBandPower(signal: testSignal, sampleRate: Float(sampleRate))

        // Alpha band should have highest power
        XCTAssertNotNil(bandPowers[.alpha])
        XCTAssertGreaterThan(bandPowers[.alpha] ?? 0, bandPowers[.delta] ?? 0)
        XCTAssertGreaterThan(bandPowers[.alpha] ?? 0, bandPowers[.gamma] ?? 0)
    }

    func testEEGBandFrequencyRanges() throws {
        // Verify EEG bands match clinical standards
        XCTAssertEqual(EEGBand.delta.frequencyRange, 0.5...4.0)
        XCTAssertEqual(EEGBand.theta.frequencyRange, 4.0...8.0)
        XCTAssertEqual(EEGBand.alpha.frequencyRange, 8.0...13.0)
        XCTAssertEqual(EEGBand.beta.frequencyRange, 13.0...30.0)
        XCTAssertEqual(EEGBand.gamma.frequencyRange, 30.0...100.0)
    }

    // MARK: - EKG Analysis Tests

    func testEKGRPeakDetection() throws {
        let processor = PhysiologicalWaveformProcessor()

        // Generate synthetic EKG with known R-peaks
        let sampleRate = 500.0
        var testSignal: [Float] = Array(repeating: 0, count: 5000)

        // Add R-peaks at known positions (every 500 samples = 60 BPM)
        let rPeakPositions = [500, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500]
        for pos in rPeakPositions {
            if pos < testSignal.count {
                testSignal[pos] = 1.0  // R-peak
            }
        }

        let detectedPeaks = processor.detectRPeaks(signal: testSignal, sampleRate: Float(sampleRate))

        // Should detect approximately 9 peaks
        XCTAssertGreaterThanOrEqual(detectedPeaks.count, 7)
        XCTAssertLessThanOrEqual(detectedPeaks.count, 11)
    }

    func testHeartRateCalculation() throws {
        let processor = PhysiologicalWaveformProcessor()

        // RR intervals for 60 BPM = 1000ms between beats
        let rrIntervals: [Float] = [1000, 1000, 1000, 1000, 1000]

        let hr = processor.calculateHeartRate(rrIntervals: rrIntervals)

        XCTAssertEqual(hr, 60, accuracy: 1)
    }

    func testHRVMetrics() throws {
        let processor = PhysiologicalWaveformProcessor()

        // Normal RR intervals with some variability
        let rrIntervals: [Float] = [850, 900, 875, 925, 880, 910, 870, 895]

        let metrics = processor.calculateHRVMetrics(rrIntervals: rrIntervals)

        XCTAssertNotNil(metrics.sdnn)
        XCTAssertNotNil(metrics.rmssd)
        XCTAssertGreaterThan(metrics.sdnn, 0)
        XCTAssertGreaterThan(metrics.rmssd, 0)
    }

    // MARK: - Medical Sonification Tests

    func testMedicalSonificationEngineInitialization() throws {
        let engine = MedicalSonificationEngine()

        XCTAssertNotNil(engine)
        XCTAssertEqual(engine.mappingMode, .pitch)
    }

    func testSonificationModes() throws {
        let modes = SonificationMode.allCases

        XCTAssertGreaterThanOrEqual(modes.count, 4)
        XCTAssertTrue(modes.contains(.pitch))
        XCTAssertTrue(modes.contains(.rhythm))
        XCTAssertTrue(modes.contains(.timbre))
        XCTAssertTrue(modes.contains(.spatial))
    }

    func testDataToFrequencyMapping() throws {
        let engine = MedicalSonificationEngine()

        // Test linear mapping
        let minData: Float = 0
        let maxData: Float = 100
        let testValue: Float = 50  // Middle value

        let frequency = engine.mapToFrequency(
            value: testValue,
            minValue: minData,
            maxValue: maxData,
            minFreq: 200,
            maxFreq: 2000
        )

        // Middle value should map to middle frequency
        XCTAssertEqual(frequency, 1100, accuracy: 100)
    }

    // MARK: - Privacy Compliance Tests

    func testMedicalDataPrivacyInitialization() throws {
        let privacy = MedicalDataPrivacy()

        XCTAssertNotNil(privacy)
        XCTAssertTrue(privacy.hipaaCompliant)
        XCTAssertTrue(privacy.gdprCompliant)
    }

    func testDataAnonymization() throws {
        let privacy = MedicalDataPrivacy()

        let sensitiveData = MedicalData(
            patientName: "John Doe",
            dateOfBirth: "1990-01-15",
            medicalRecordNumber: "MRN123456",
            studyData: [1.0, 2.0, 3.0]
        )

        let anonymized = privacy.anonymize(sensitiveData)

        XCTAssertNotEqual(anonymized.patientName, "John Doe")
        XCTAssertNil(anonymized.dateOfBirth)
        XCTAssertNil(anonymized.medicalRecordNumber)
        XCTAssertEqual(anonymized.studyData, sensitiveData.studyData)  // Study data preserved
    }
}

// MARK: - Social Media Command Center Tests

@MainActor
final class SocialMediaCommandCenterTests: XCTestCase {

    // MARK: - Platform Tests

    func testSocialPlatformEnumeration() throws {
        let platforms = SocialPlatform.allCases

        XCTAssertEqual(platforms.count, 10)
        XCTAssertTrue(platforms.contains(.instagram))
        XCTAssertTrue(platforms.contains(.tikTok))
        XCTAssertTrue(platforms.contains(.youtube))
        XCTAssertTrue(platforms.contains(.facebook))
        XCTAssertTrue(platforms.contains(.twitter))
        XCTAssertTrue(platforms.contains(.linkedIn))
        XCTAssertTrue(platforms.contains(.twitch))
        XCTAssertTrue(platforms.contains(.discord))
        XCTAssertTrue(platforms.contains(.threads))
        XCTAssertTrue(platforms.contains(.bluesky))
    }

    func testPlatformAPIEndpoints() throws {
        XCTAssertFalse(SocialPlatform.instagram.apiBaseURL.isEmpty)
        XCTAssertFalse(SocialPlatform.youtube.apiBaseURL.isEmpty)
        XCTAssertFalse(SocialPlatform.tikTok.apiBaseURL.isEmpty)
    }

    func testPlatformMediaRequirements() throws {
        // Instagram video requirements
        let igRequirements = SocialPlatform.instagram.videoRequirements

        XCTAssertGreaterThan(igRequirements.maxDuration, 0)
        XCTAssertGreaterThan(igRequirements.maxFileSize, 0)
        XCTAssertFalse(igRequirements.supportedFormats.isEmpty)

        // TikTok requirements
        let ttRequirements = SocialPlatform.tikTok.videoRequirements

        XCTAssertGreaterThan(ttRequirements.maxDuration, 0)
        XCTAssertTrue(ttRequirements.supportedFormats.contains("mp4"))

        // YouTube allows longer videos
        let ytRequirements = SocialPlatform.youtube.videoRequirements

        XCTAssertGreaterThan(ytRequirements.maxDuration, igRequirements.maxDuration)
    }

    // MARK: - Social Account Tests

    func testSocialAccountInitialization() throws {
        let account = SocialAccount(
            id: "acc-123",
            platform: .instagram,
            username: "@testuser",
            displayName: "Test User",
            isAuthenticated: false
        )

        XCTAssertEqual(account.id, "acc-123")
        XCTAssertEqual(account.platform, .instagram)
        XCTAssertEqual(account.username, "@testuser")
        XCTAssertFalse(account.isAuthenticated)
    }

    func testSocialAccountAuthentication() throws {
        var account = SocialAccount(
            id: "acc-456",
            platform: .youtube,
            username: "testchannel",
            displayName: "Test Channel",
            isAuthenticated: false
        )

        XCTAssertFalse(account.isAuthenticated)
        XCTAssertNil(account.accessToken)

        account.authenticate(accessToken: "test-token", refreshToken: "refresh-token")

        XCTAssertTrue(account.isAuthenticated)
        XCTAssertNotNil(account.accessToken)
        XCTAssertNotNil(account.refreshToken)
    }

    // MARK: - Social Post Tests

    func testSocialPostInitialization() throws {
        let post = SocialPost(
            id: "post-123",
            content: "Test post content",
            mediaURLs: [URL(string: "https://example.com/video.mp4")!],
            platforms: [.instagram, .tikTok],
            scheduledTime: nil
        )

        XCTAssertEqual(post.id, "post-123")
        XCTAssertEqual(post.content, "Test post content")
        XCTAssertEqual(post.mediaURLs.count, 1)
        XCTAssertEqual(post.platforms.count, 2)
        XCTAssertNil(post.scheduledTime)
        XCTAssertEqual(post.status, .draft)
    }

    func testSocialPostScheduling() throws {
        let futureDate = Date().addingTimeInterval(3600)  // 1 hour from now

        var post = SocialPost(
            id: "post-scheduled",
            content: "Scheduled post",
            mediaURLs: [],
            platforms: [.twitter],
            scheduledTime: futureDate
        )

        XCTAssertNotNil(post.scheduledTime)
        XCTAssertEqual(post.status, .draft)

        post.status = .scheduled
        XCTAssertEqual(post.status, .scheduled)
    }

    func testSocialPostStatus() throws {
        let statuses = PostStatus.allCases

        XCTAssertGreaterThanOrEqual(statuses.count, 5)
        XCTAssertTrue(statuses.contains(.draft))
        XCTAssertTrue(statuses.contains(.scheduled))
        XCTAssertTrue(statuses.contains(.publishing))
        XCTAssertTrue(statuses.contains(.published))
        XCTAssertTrue(statuses.contains(.failed))
    }

    // MARK: - Content Calendar Tests

    func testContentCalendarInitialization() throws {
        let calendar = ContentCalendar()

        XCTAssertEqual(calendar.scheduledPosts.count, 0)
    }

    func testContentCalendarSchedulePost() throws {
        let calendar = ContentCalendar()

        let post = SocialPost(
            id: "cal-post-1",
            content: "Calendar test",
            mediaURLs: [],
            platforms: [.instagram],
            scheduledTime: Date().addingTimeInterval(86400)  // Tomorrow
        )

        calendar.schedulePost(post)

        XCTAssertEqual(calendar.scheduledPosts.count, 1)
    }

    func testContentCalendarGetPostsForDate() throws {
        let calendar = ContentCalendar()

        let tomorrow = Date().addingTimeInterval(86400)

        let post1 = SocialPost(
            id: "cal-1",
            content: "Post 1",
            mediaURLs: [],
            platforms: [.instagram],
            scheduledTime: tomorrow
        )

        let post2 = SocialPost(
            id: "cal-2",
            content: "Post 2",
            mediaURLs: [],
            platforms: [.tikTok],
            scheduledTime: tomorrow.addingTimeInterval(3600)
        )

        calendar.schedulePost(post1)
        calendar.schedulePost(post2)

        let tomorrowPosts = calendar.posts(for: tomorrow)

        XCTAssertEqual(tomorrowPosts.count, 2)
    }

    // MARK: - Analytics Dashboard Tests

    func testAnalyticsDashboardInitialization() throws {
        let dashboard = AnalyticsDashboard()

        XCTAssertNotNil(dashboard)
    }

    func testAnalyticsMetrics() throws {
        let metrics = AnalyticsMetric.allCases

        XCTAssertGreaterThanOrEqual(metrics.count, 6)
        XCTAssertTrue(metrics.contains(.views))
        XCTAssertTrue(metrics.contains(.likes))
        XCTAssertTrue(metrics.contains(.comments))
        XCTAssertTrue(metrics.contains(.shares))
        XCTAssertTrue(metrics.contains(.followers))
        XCTAssertTrue(metrics.contains(.engagement))
    }

    func testEngagementRateCalculation() throws {
        let dashboard = AnalyticsDashboard()

        let stats = PostAnalytics(
            views: 10000,
            likes: 500,
            comments: 50,
            shares: 100,
            saves: 200
        )

        let engagementRate = dashboard.calculateEngagementRate(stats: stats)

        // Engagement = (likes + comments + shares + saves) / views * 100
        // = (500 + 50 + 100 + 200) / 10000 * 100 = 8.5%
        XCTAssertEqual(engagementRate, 8.5, accuracy: 0.1)
    }

    // MARK: - Multi-Platform Publishing Tests

    func testPlatformPublisherInitialization() throws {
        let publisher = PlatformPublisher()

        XCTAssertNotNil(publisher)
        XCTAssertEqual(publisher.connectedAccounts.count, 0)
    }

    func testCrossPostingValidation() throws {
        let publisher = PlatformPublisher()

        let post = SocialPost(
            id: "cross-post",
            content: String(repeating: "x", count: 500),  // Long content
            mediaURLs: [],
            platforms: [.twitter, .instagram]
        )

        let validation = publisher.validateForPlatforms(post: post)

        // Twitter has 280 char limit, so should fail
        XCTAssertFalse(validation[.twitter] ?? true)
        // Instagram has higher limit
        XCTAssertTrue(validation[.instagram] ?? false)
    }

    // MARK: - Live Streaming Tests

    func testLiveStreamSessionInitialization() throws {
        let session = LiveStreamSession(
            title: "Test Stream",
            platforms: [.twitch, .youtube]
        )

        XCTAssertEqual(session.title, "Test Stream")
        XCTAssertEqual(session.platforms.count, 2)
        XCTAssertEqual(session.status, .idle)
    }

    func testLiveStreamStatus() throws {
        let statuses = StreamStatus.allCases

        XCTAssertGreaterThanOrEqual(statuses.count, 4)
        XCTAssertTrue(statuses.contains(.idle))
        XCTAssertTrue(statuses.contains(.connecting))
        XCTAssertTrue(statuses.contains(.live))
        XCTAssertTrue(statuses.contains(.ended))
    }

    func testMultiStreamSupport() throws {
        let session = LiveStreamSession(
            title: "Multi-Platform Stream",
            platforms: [.twitch, .youtube, .facebook]
        )

        XCTAssertEqual(session.platforms.count, 3)
        XCTAssertTrue(session.isMultiStream)
    }
}

// MARK: - Helper Extensions for Tests

extension Int {
    func isPowerOf2() -> Bool {
        return self > 0 && (self & (self - 1)) == 0
    }
}

import XCTest
@testable import Echoelmusic

/// Tests for ImmersiveIsochronicSession and ClipLauncherGrid
/// Phase 10000+ Complete Feature Tests
final class ImmersiveClipLauncherTests: XCTestCase {

    // MARK: - ImmersiveIsochronicSession Tests

    // MARK: Preset Tests

    func testIsochronicPresetFrequencies() {
        // Verify all presets have valid target frequencies
        XCTAssertEqual(IsochronicPreset.deepMeditation.targetFrequency, 6.0)  // Theta
        XCTAssertEqual(IsochronicPreset.focusFlow.targetFrequency, 14.0)      // Low Beta
        XCTAssertEqual(IsochronicPreset.creativeDream.targetFrequency, 7.83)  // Schumann
        XCTAssertEqual(IsochronicPreset.relaxationPortal.targetFrequency, 10.0) // Alpha
        XCTAssertEqual(IsochronicPreset.sleepJourney.targetFrequency, 2.0)    // Delta
        XCTAssertEqual(IsochronicPreset.energyBoost.targetFrequency, 20.0)    // Beta
        XCTAssertEqual(IsochronicPreset.quantumCoherence.targetFrequency, 40.0) // Gamma
        XCTAssertEqual(IsochronicPreset.sacredGeometry.targetFrequency, 7.83) // Schumann
    }

    func testIsochronicPresetCarrierFrequencies() {
        // Verify carrier frequencies (12-TET standard tuning)
        XCTAssertEqual(IsochronicPreset.sleepJourney.carrierFrequency, 440.0)       // A4 standard
        XCTAssertEqual(IsochronicPreset.deepMeditation.carrierFrequency, 440.0)     // A4 standard
        XCTAssertEqual(IsochronicPreset.energyBoost.carrierFrequency, 523.251, accuracy: 0.01) // C5
        XCTAssertEqual(IsochronicPreset.focusFlow.carrierFrequency, 523.251, accuracy: 0.01)   // C5
        XCTAssertEqual(IsochronicPreset.quantumCoherence.carrierFrequency, 659.255, accuracy: 0.01) // E5
        XCTAssertEqual(IsochronicPreset.relaxationPortal.carrierFrequency, 440.0)   // A4 standard
    }

    func testIsochronicPresetVisualModes() {
        XCTAssertEqual(IsochronicPreset.deepMeditation.visualMode, .breathingMandala)
        XCTAssertEqual(IsochronicPreset.focusFlow.visualMode, .flowTunnel)
        XCTAssertEqual(IsochronicPreset.creativeDream.visualMode, .fractalDream)
        XCTAssertEqual(IsochronicPreset.relaxationPortal.visualMode, .coherenceField)
        XCTAssertEqual(IsochronicPreset.sleepJourney.visualMode, .gentleWaves)
        XCTAssertEqual(IsochronicPreset.energyBoost.visualMode, .energyParticles)
        XCTAssertEqual(IsochronicPreset.quantumCoherence.visualMode, .quantumField)
        XCTAssertEqual(IsochronicPreset.sacredGeometry.visualMode, .sacredPatterns)
    }

    func testIsochronicPresetDurations() {
        // Sleep and meditation should have longer durations
        XCTAssertEqual(IsochronicPreset.sleepJourney.suggestedDuration, 1800)  // 30 min
        XCTAssertEqual(IsochronicPreset.deepMeditation.suggestedDuration, 1200) // 20 min
        XCTAssertEqual(IsochronicPreset.focusFlow.suggestedDuration, 1500)     // 25 min
        XCTAssertEqual(IsochronicPreset.energyBoost.suggestedDuration, 300)    // 5 min (quick boost)
    }

    func testAllPresetsHaveDescriptions() {
        for preset in IsochronicPreset.allCases {
            XCTAssertFalse(preset.description.isEmpty, "Preset \(preset.rawValue) should have a description")
            XCTAssertGreaterThan(preset.description.count, 20, "Description should be meaningful")
        }
    }

    func testAllPresetsHaveIds() {
        for preset in IsochronicPreset.allCases {
            XCTAssertFalse(preset.id.isEmpty)
            XCTAssertEqual(preset.id, preset.rawValue)
        }
    }

    // MARK: Visual Mode Tests

    func testAllVisualModesExist() {
        XCTAssertEqual(IsochronicVisualMode.allCases.count, 10)
        XCTAssertTrue(IsochronicVisualMode.allCases.contains(.breathingMandala))
        XCTAssertTrue(IsochronicVisualMode.allCases.contains(.flowTunnel))
        XCTAssertTrue(IsochronicVisualMode.allCases.contains(.fractalDream))
        XCTAssertTrue(IsochronicVisualMode.allCases.contains(.coherenceField))
        XCTAssertTrue(IsochronicVisualMode.allCases.contains(.gentleWaves))
        XCTAssertTrue(IsochronicVisualMode.allCases.contains(.energyParticles))
        XCTAssertTrue(IsochronicVisualMode.allCases.contains(.quantumField))
        XCTAssertTrue(IsochronicVisualMode.allCases.contains(.sacredPatterns))
        XCTAssertTrue(IsochronicVisualMode.allCases.contains(.biophotonAura))
        XCTAssertTrue(IsochronicVisualMode.allCases.contains(.cosmicNebula))
    }

    // MARK: Audio Mode Tests

    func testAudioModeHeadphoneRequirements() {
        XCTAssertTrue(IsochronicAudioMode.binaural.requiresHeadphones)
        XCTAssertFalse(IsochronicAudioMode.isochronic.requiresHeadphones)
        XCTAssertFalse(IsochronicAudioMode.monaural.requiresHeadphones)
        XCTAssertFalse(IsochronicAudioMode.hybrid.requiresHeadphones)
    }

    func testAllAudioModesExist() {
        XCTAssertEqual(IsochronicAudioMode.allCases.count, 4)
    }

    // MARK: Bio Modulation Config Tests

    func testBioModulationConfigDefaults() {
        let config = BioModulationConfig()
        XCTAssertEqual(config.coherenceToVisualIntensity, 0.7)
        XCTAssertEqual(config.heartRateToTempo, 0.3)
        XCTAssertEqual(config.breathingToVisualScale, 0.5)
        XCTAssertTrue(config.adaptiveFrequency)
        XCTAssertEqual(config.targetCoherence, 0.7)
    }

    // MARK: Session State Tests

    func testSessionStateDefaults() {
        let state = IsochronicSessionState()
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(state.currentPhase, .preparation)
        XCTAssertEqual(state.elapsedTime, 0)
        XCTAssertEqual(state.currentFrequency, 10.0)
        XCTAssertEqual(state.currentCoherence, 0.5)
        XCTAssertEqual(state.visualIntensity, 0.5)
        XCTAssertEqual(state.audioLevel, 0.7)
        XCTAssertEqual(state.entrainmentScore, 0.0)
    }

    func testSessionPhases() {
        XCTAssertEqual(IsochronicSessionState.SessionPhase.preparation.rawValue, "Preparation")
        XCTAssertEqual(IsochronicSessionState.SessionPhase.rampUp.rawValue, "Ramp Up")
        XCTAssertEqual(IsochronicSessionState.SessionPhase.entrainment.rawValue, "Entrainment")
        XCTAssertEqual(IsochronicSessionState.SessionPhase.peak.rawValue, "Peak Experience")
        XCTAssertEqual(IsochronicSessionState.SessionPhase.rampDown.rawValue, "Ramp Down")
        XCTAssertEqual(IsochronicSessionState.SessionPhase.integration.rawValue, "Integration")
        XCTAssertEqual(IsochronicSessionState.SessionPhase.complete.rawValue, "Complete")
    }

    // MARK: Session Engine Tests

    func testImmersiveIsochronicSessionInitialization() async {
        let session = await ImmersiveIsochronicSession()
        await MainActor.run {
            XCTAssertFalse(session.state.isActive)
            XCTAssertEqual(session.currentPreset, .relaxationPortal)
            XCTAssertEqual(session.audioMode, .hybrid)
        }
    }

    func testVisualParametersDefaults() async {
        let session = await ImmersiveIsochronicSession()
        await MainActor.run {
            XCTAssertEqual(session.visualParameters.hue, 0.6)
            XCTAssertEqual(session.visualParameters.saturation, 0.7)
            XCTAssertEqual(session.visualParameters.brightness, 0.8)
            XCTAssertEqual(session.visualParameters.complexity, 0.5)
            XCTAssertEqual(session.visualParameters.pulseIntensity, 0.5)
            XCTAssertEqual(session.visualParameters.rotationSpeed, 0.1)
            XCTAssertEqual(session.visualParameters.scale, 1.0)
            XCTAssertEqual(session.visualParameters.particleCount, 100)
        }
    }

    func testBioInputDefaults() async {
        let session = await ImmersiveIsochronicSession()
        await MainActor.run {
            XCTAssertEqual(session.bioInput.heartRate, 70)
            XCTAssertEqual(session.bioInput.hrvCoherence, 0.5)
            XCTAssertEqual(session.bioInput.breathingRate, 12)
            XCTAssertEqual(session.bioInput.breathPhase, 0.5)
        }
    }

    func testSessionAnalyticsDefaults() async {
        let session = await ImmersiveIsochronicSession()
        await MainActor.run {
            XCTAssertEqual(session.analytics.totalDuration, 0)
            XCTAssertEqual(session.analytics.averageCoherence, 0)
            XCTAssertEqual(session.analytics.peakCoherence, 0)
            XCTAssertTrue(session.analytics.coherenceHistory.isEmpty)
            XCTAssertFalse(session.analytics.entrainmentAchieved)
            XCTAssertEqual(session.analytics.entrainmentDuration, 0)
        }
    }

    // MARK: - ClipLauncherGrid Tests

    // MARK: Clip Model Tests

    func testLauncherClipDefaults() {
        let clip = LauncherClip()
        XCTAssertEqual(clip.name, "New Clip")
        XCTAssertEqual(clip.color, .blue)
        XCTAssertEqual(clip.type, .empty)
        XCTAssertEqual(clip.state, .stopped)
        XCTAssertTrue(clip.loopEnabled)
        XCTAssertEqual(clip.duration, 4.0)
        XCTAssertEqual(clip.warpMode, .beats)
        XCTAssertEqual(clip.quantization, .bar1)
        XCTAssertEqual(clip.velocity, 1.0)
        XCTAssertNil(clip.followAction)
    }

    func testClipTypeEnumeration() {
        XCTAssertEqual(LauncherClip.ClipType.allCases.count, 3)
        XCTAssertEqual(LauncherClip.ClipType.audio.rawValue, "Audio")
        XCTAssertEqual(LauncherClip.ClipType.midi.rawValue, "MIDI")
        XCTAssertEqual(LauncherClip.ClipType.empty.rawValue, "Empty")
    }

    func testClipStateEnumeration() {
        XCTAssertEqual(LauncherClip.ClipState.stopped.rawValue, "Stopped")
        XCTAssertEqual(LauncherClip.ClipState.queued.rawValue, "Queued")
        XCTAssertEqual(LauncherClip.ClipState.playing.rawValue, "Playing")
        XCTAssertEqual(LauncherClip.ClipState.recording.rawValue, "Recording")
    }

    func testClipColorSwiftUIMapping() {
        XCTAssertEqual(LauncherClip.ClipColor.allCases.count, 10)
        for color in LauncherClip.ClipColor.allCases {
            XCTAssertNotNil(color.swiftUIColor)
        }
    }

    func testWarpModeEnumeration() {
        XCTAssertEqual(LauncherClip.WarpMode.allCases.count, 6)
        XCTAssertEqual(LauncherClip.WarpMode.beats.rawValue, "Beats")
        XCTAssertEqual(LauncherClip.WarpMode.tones.rawValue, "Tones")
        XCTAssertEqual(LauncherClip.WarpMode.texture.rawValue, "Texture")
        XCTAssertEqual(LauncherClip.WarpMode.repitch.rawValue, "Re-Pitch")
        XCTAssertEqual(LauncherClip.WarpMode.complex.rawValue, "Complex")
        XCTAssertEqual(LauncherClip.WarpMode.complexPro.rawValue, "Complex Pro")
    }

    func testQuantizationValues() {
        XCTAssertEqual(LauncherClip.Quantization.allCases.count, 8)
        XCTAssertEqual(LauncherClip.Quantization.none.beats, 0)
        XCTAssertEqual(LauncherClip.Quantization.bar1.beats, 4)
        XCTAssertEqual(LauncherClip.Quantization.bar2.beats, 8)
        XCTAssertEqual(LauncherClip.Quantization.bar4.beats, 16)
        XCTAssertEqual(LauncherClip.Quantization.bar8.beats, 32)
        XCTAssertEqual(LauncherClip.Quantization.beat1.beats, 1)
        XCTAssertEqual(LauncherClip.Quantization.beat1_2.beats, 0.5)
        XCTAssertEqual(LauncherClip.Quantization.beat1_4.beats, 0.25)
    }

    func testFollowActionTypes() {
        XCTAssertEqual(LauncherClip.FollowAction.Action.allCases.count, 9)
        XCTAssertEqual(LauncherClip.FollowAction.Action.none.rawValue, "None")
        XCTAssertEqual(LauncherClip.FollowAction.Action.stop.rawValue, "Stop")
        XCTAssertEqual(LauncherClip.FollowAction.Action.playAgain.rawValue, "Play Again")
        XCTAssertEqual(LauncherClip.FollowAction.Action.next.rawValue, "Next")
        XCTAssertEqual(LauncherClip.FollowAction.Action.any.rawValue, "Any")
    }

    // MARK: Track Model Tests

    func testLauncherTrackDefaults() {
        let track = LauncherTrack()
        XCTAssertEqual(track.name, "Track")
        XCTAssertEqual(track.type, .audio)
        XCTAssertEqual(track.clips.count, 8)
        XCTAssertEqual(track.volume, 0.8)
        XCTAssertEqual(track.pan, 0)
        XCTAssertFalse(track.isMuted)
        XCTAssertFalse(track.isSoloed)
        XCTAssertFalse(track.isArmed)
        XCTAssertEqual(track.color, .blue)
        XCTAssertEqual(track.sendLevels.count, 2)
    }

    func testTrackTypeEnumeration() {
        XCTAssertEqual(LauncherTrack.TrackType.allCases.count, 5)
        XCTAssertEqual(LauncherTrack.TrackType.audio.rawValue, "Audio")
        XCTAssertEqual(LauncherTrack.TrackType.midi.rawValue, "MIDI")
        XCTAssertEqual(LauncherTrack.TrackType.group.rawValue, "Group")
        XCTAssertEqual(LauncherTrack.TrackType.return_.rawValue, "Return")
        XCTAssertEqual(LauncherTrack.TrackType.master.rawValue, "Master")
    }

    // MARK: Scene Model Tests

    func testLauncherSceneDefaults() {
        let scene = LauncherScene()
        XCTAssertEqual(scene.name, "Scene")
        XCTAssertNil(scene.tempo)
        XCTAssertNil(scene.timeSignature)
        XCTAssertEqual(scene.color, .gray)
    }

    // MARK: Grid Engine Tests

    func testClipLauncherGridInitialization() async {
        let launcher = await ClipLauncherGrid()
        await MainActor.run {
            XCTAssertEqual(launcher.tracks.count, 8)
            XCTAssertEqual(launcher.scenes.count, 8)
            XCTAssertFalse(launcher.isPlaying)
            XCTAssertEqual(launcher.tempo, 120.0)
            XCTAssertEqual(launcher.globalQuantization, .bar1)
            XCTAssertEqual(launcher.currentBeat, 0)
            XCTAssertEqual(launcher.currentBar, 1)
            XCTAssertTrue(launcher.bioReactiveEnabled)
            XCTAssertEqual(launcher.coherenceThreshold, 0.7)
        }
    }

    func testClipLauncherCustomSize() async {
        let launcher = await ClipLauncherGrid(trackCount: 4, sceneCount: 16)
        await MainActor.run {
            XCTAssertEqual(launcher.tracks.count, 4)
            XCTAssertEqual(launcher.scenes.count, 16)
            // Each track should have clips for each scene
            for track in launcher.tracks {
                XCTAssertEqual(track.clips.count, 16)
            }
        }
    }

    func testPlaybackToggle() async {
        let launcher = await ClipLauncherGrid()
        await MainActor.run {
            XCTAssertFalse(launcher.isPlaying)
            launcher.togglePlayback()
            XCTAssertTrue(launcher.isPlaying)
            launcher.togglePlayback()
            XCTAssertFalse(launcher.isPlaying)
        }
    }

    func testTrackMuteToggle() async {
        let launcher = await ClipLauncherGrid()
        await MainActor.run {
            XCTAssertFalse(launcher.tracks[0].isMuted)
            launcher.toggleMute(trackIndex: 0)
            XCTAssertTrue(launcher.tracks[0].isMuted)
            launcher.toggleMute(trackIndex: 0)
            XCTAssertFalse(launcher.tracks[0].isMuted)
        }
    }

    func testTrackSoloToggle() async {
        let launcher = await ClipLauncherGrid()
        await MainActor.run {
            XCTAssertFalse(launcher.tracks[0].isSoloed)
            launcher.toggleSolo(trackIndex: 0)
            XCTAssertTrue(launcher.tracks[0].isSoloed)
            launcher.toggleSolo(trackIndex: 0)
            XCTAssertFalse(launcher.tracks[0].isSoloed)
        }
    }

    func testTrackArmToggle() async {
        let launcher = await ClipLauncherGrid()
        await MainActor.run {
            XCTAssertFalse(launcher.tracks[0].isArmed)
            launcher.toggleArm(trackIndex: 0)
            XCTAssertTrue(launcher.tracks[0].isArmed)
            launcher.toggleArm(trackIndex: 0)
            XCTAssertFalse(launcher.tracks[0].isArmed)
        }
    }

    func testSetTrackVolume() async {
        let launcher = await ClipLauncherGrid()
        await MainActor.run {
            launcher.setVolume(trackIndex: 0, volume: 0.5)
            XCTAssertEqual(launcher.tracks[0].volume, 0.5)

            // Test clamping
            launcher.setVolume(trackIndex: 0, volume: 1.5)
            XCTAssertEqual(launcher.tracks[0].volume, 1.0)

            launcher.setVolume(trackIndex: 0, volume: -0.5)
            XCTAssertEqual(launcher.tracks[0].volume, 0.0)
        }
    }

    func testSetTrackPan() async {
        let launcher = await ClipLauncherGrid()
        await MainActor.run {
            launcher.setPan(trackIndex: 0, pan: -0.5)
            XCTAssertEqual(launcher.tracks[0].pan, -0.5)

            // Test clamping
            launcher.setPan(trackIndex: 0, pan: 2.0)
            XCTAssertEqual(launcher.tracks[0].pan, 1.0)

            launcher.setPan(trackIndex: 0, pan: -2.0)
            XCTAssertEqual(launcher.tracks[0].pan, -1.0)
        }
    }

    func testAddClip() async {
        let launcher = await ClipLauncherGrid()
        await MainActor.run {
            launcher.addClip(trackIndex: 0, clipIndex: 0, name: "Test Clip", type: .audio)
            XCTAssertEqual(launcher.tracks[0].clips[0].name, "Test Clip")
            XCTAssertEqual(launcher.tracks[0].clips[0].type, .audio)
        }
    }

    func testDeleteClip() async {
        let launcher = await ClipLauncherGrid()
        await MainActor.run {
            launcher.addClip(trackIndex: 0, clipIndex: 0, name: "Test Clip", type: .audio)
            XCTAssertEqual(launcher.tracks[0].clips[0].type, .audio)

            launcher.deleteClip(trackIndex: 0, clipIndex: 0)
            XCTAssertEqual(launcher.tracks[0].clips[0].type, .empty)
        }
    }

    func testRenameClip() async {
        let launcher = await ClipLauncherGrid()
        await MainActor.run {
            launcher.addClip(trackIndex: 0, clipIndex: 0, name: "Original", type: .audio)
            launcher.renameClip(trackIndex: 0, clipIndex: 0, name: "Renamed")
            XCTAssertEqual(launcher.tracks[0].clips[0].name, "Renamed")
        }
    }

    func testSetClipColor() async {
        let launcher = await ClipLauncherGrid()
        await MainActor.run {
            launcher.setClipColor(trackIndex: 0, clipIndex: 0, color: .red)
            XCTAssertEqual(launcher.tracks[0].clips[0].color, .red)
        }
    }

    func testAddTrack() async {
        let launcher = await ClipLauncherGrid(trackCount: 4, sceneCount: 8)
        await MainActor.run {
            XCTAssertEqual(launcher.tracks.count, 4)
            launcher.addTrack()
            XCTAssertEqual(launcher.tracks.count, 5)
            XCTAssertEqual(launcher.tracks[4].clips.count, 8)
        }
    }

    func testRemoveTrack() async {
        let launcher = await ClipLauncherGrid(trackCount: 4, sceneCount: 8)
        await MainActor.run {
            launcher.removeTrack(at: 3)
            XCTAssertEqual(launcher.tracks.count, 3)
        }
    }

    func testAddScene() async {
        let launcher = await ClipLauncherGrid(trackCount: 4, sceneCount: 4)
        await MainActor.run {
            XCTAssertEqual(launcher.scenes.count, 4)
            launcher.addScene()
            XCTAssertEqual(launcher.scenes.count, 5)

            // All tracks should have a new clip slot
            for track in launcher.tracks {
                XCTAssertEqual(track.clips.count, 5)
            }
        }
    }

    func testRemoveScene() async {
        let launcher = await ClipLauncherGrid(trackCount: 4, sceneCount: 4)
        await MainActor.run {
            launcher.removeScene(at: 3)
            XCTAssertEqual(launcher.scenes.count, 3)

            // All tracks should have clips removed
            for track in launcher.tracks {
                XCTAssertEqual(track.clips.count, 3)
            }
        }
    }

    func testLaunchClip() async {
        let launcher = await ClipLauncherGrid()
        await MainActor.run {
            launcher.addClip(trackIndex: 0, clipIndex: 0, name: "Test", type: .audio)
            launcher.launchClip(trackIndex: 0, clipIndex: 0)

            // Should be playing or queued depending on global state
            let state = launcher.tracks[0].clips[0].state
            XCTAssertTrue(state == .playing || state == .queued)
        }
    }

    func testStopClip() async {
        let launcher = await ClipLauncherGrid()
        await MainActor.run {
            launcher.addClip(trackIndex: 0, clipIndex: 0, name: "Test", type: .audio)
            launcher.launchClip(trackIndex: 0, clipIndex: 0)
            launcher.stopClip(trackIndex: 0, clipIndex: 0)
            XCTAssertEqual(launcher.tracks[0].clips[0].state, .stopped)
        }
    }

    func testLaunchScene() async {
        let launcher = await ClipLauncherGrid()
        await MainActor.run {
            launcher.launchScene(index: 2)
            XCTAssertEqual(launcher.selectedSceneIndex, 2)
        }
    }

    func testStopAllClips() async {
        let launcher = await ClipLauncherGrid()
        await MainActor.run {
            // Add and launch some clips
            launcher.addClip(trackIndex: 0, clipIndex: 0, name: "Clip1", type: .audio)
            launcher.addClip(trackIndex: 1, clipIndex: 0, name: "Clip2", type: .midi)
            launcher.launchClip(trackIndex: 0, clipIndex: 0)
            launcher.launchClip(trackIndex: 1, clipIndex: 0)

            launcher.stopAllClips()

            XCTAssertEqual(launcher.tracks[0].clips[0].state, .stopped)
            XCTAssertEqual(launcher.tracks[1].clips[0].state, .stopped)
        }
    }

    func testBioCoherenceUpdate() async {
        let launcher = await ClipLauncherGrid()
        await MainActor.run {
            launcher.updateCoherence(0.85)
            XCTAssertEqual(launcher.currentCoherence, 0.85)
        }
    }

    // MARK: - Performance Tests

    func testClipCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = LauncherClip(name: "Perf Test", type: .audio)
            }
        }
    }

    func testTrackCreationPerformance() {
        measure {
            for _ in 0..<100 {
                _ = LauncherTrack(clipCount: 16)
            }
        }
    }

    func testPresetLookupPerformance() {
        measure {
            for _ in 0..<10000 {
                for preset in IsochronicPreset.allCases {
                    _ = preset.targetFrequency
                    _ = preset.carrierFrequency
                    _ = preset.visualMode
                }
            }
        }
    }

    // MARK: - Codable Tests

    func testClipCodable() throws {
        let clip = LauncherClip(name: "Test Clip", color: .red, type: .audio, duration: 8.0)

        let encoder = JSONEncoder()
        let data = try encoder.encode(clip)
        XCTAssertNotNil(data)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LauncherClip.self, from: data)
        XCTAssertEqual(decoded.name, "Test Clip")
        XCTAssertEqual(decoded.color, .red)
        XCTAssertEqual(decoded.type, .audio)
        XCTAssertEqual(decoded.duration, 8.0)
    }

    func testTrackCodable() throws {
        let track = LauncherTrack(name: "Bass", type: .audio, clipCount: 4, color: .green)

        let encoder = JSONEncoder()
        let data = try encoder.encode(track)
        XCTAssertNotNil(data)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LauncherTrack.self, from: data)
        XCTAssertEqual(decoded.name, "Bass")
        XCTAssertEqual(decoded.type, .audio)
        XCTAssertEqual(decoded.clips.count, 4)
        XCTAssertEqual(decoded.color, .green)
    }

    func testSceneCodable() throws {
        let scene = LauncherScene(name: "Chorus", color: .orange)

        let encoder = JSONEncoder()
        let data = try encoder.encode(scene)
        XCTAssertNotNil(data)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LauncherScene.self, from: data)
        XCTAssertEqual(decoded.name, "Chorus")
        XCTAssertEqual(decoded.color, .orange)
    }
}

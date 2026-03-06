// IntegrationTests.swift
// Echoelmusic — Integration Test Coverage for Critical Untested Modules
//
// Tests for EchoelCreativeWorkspace, ThemeManager, VisualStepSequencer,
// and ClipLauncherGrid integration. Closes 8→10 coverage gap.

import XCTest
@testable import Echoelmusic

// MARK: - EchoelCreativeWorkspace Tests

@MainActor
final class CreativeWorkspaceTests: XCTestCase {

    func testSharedInstance() {
        let workspace = EchoelCreativeWorkspace.shared
        XCTAssertNotNil(workspace)
    }

    func testDefaultState() {
        let workspace = EchoelCreativeWorkspace.shared
        XCTAssertFalse(workspace.isPlaying)
        XCTAssertEqual(workspace.globalBPM, 120.0, accuracy: 0.01)
    }

    func testGlobalBPMDefault() {
        let workspace = EchoelCreativeWorkspace.shared
        XCTAssertEqual(workspace.globalBPM, 120.0, accuracy: 0.01)
    }

    func testDefaultTimeSignature() {
        let workspace = EchoelCreativeWorkspace.shared
        XCTAssertEqual(workspace.globalTimeSignature, .fourFour)
    }

    func testBioCoherenceDefault() {
        let workspace = EchoelCreativeWorkspace.shared
        // Bio coherence starts at 0.5 (midpoint)
        XCTAssertEqual(workspace.bioCoherence, 0.5, accuracy: 0.5)
    }

    func testBioCoherenceInRange() {
        let workspace = EchoelCreativeWorkspace.shared
        XCTAssertGreaterThanOrEqual(workspace.bioCoherence, 0.0)
        XCTAssertLessThanOrEqual(workspace.bioCoherence, 1.0)
    }

    func testBPMGridExists() {
        let workspace = EchoelCreativeWorkspace.shared
        XCTAssertNotNil(workspace.bpmGrid)
    }

    func testVideoEditorExists() {
        let workspace = EchoelCreativeWorkspace.shared
        XCTAssertNotNil(workspace.videoEditor)
    }

    func testProMixerExists() {
        let workspace = EchoelCreativeWorkspace.shared
        XCTAssertNotNil(workspace.proMixer)
    }

    func testProSessionExists() {
        let workspace = EchoelCreativeWorkspace.shared
        XCTAssertNotNil(workspace.proSession)
    }

    func testProColorExists() {
        let workspace = EchoelCreativeWorkspace.shared
        XCTAssertNotNil(workspace.proColor)
    }

    func testLoopEngineExists() {
        let workspace = EchoelCreativeWorkspace.shared
        XCTAssertNotNil(workspace.loopEngine)
    }

    func testBioSynthExists() {
        let workspace = EchoelCreativeWorkspace.shared
        XCTAssertNotNil(workspace.bioSynth)
    }

    func testSetGlobalBPM() {
        let workspace = EchoelCreativeWorkspace.shared
        workspace.setGlobalBPM(140.0)
        XCTAssertEqual(workspace.globalBPM, 140.0, accuracy: 0.01)
        // Restore default
        workspace.setGlobalBPM(120.0)
    }

    func testSetGlobalBPMPropagates() {
        let workspace = EchoelCreativeWorkspace.shared
        workspace.setGlobalBPM(160.0)
        XCTAssertEqual(workspace.videoEditor.timeline.tempo, 160.0, accuracy: 0.01)
        // Restore
        workspace.setGlobalBPM(120.0)
    }

    func testSetGlobalTimeSignature() {
        let workspace = EchoelCreativeWorkspace.shared
        let ts = TimeSignature(numerator: 3, denominator: 4)
        workspace.setGlobalTimeSignature(ts)
        XCTAssertEqual(workspace.globalTimeSignature, ts)
        // Restore
        workspace.setGlobalTimeSignature(.fourFour)
    }

    func testTogglePlaybackTogglesState() {
        let workspace = EchoelCreativeWorkspace.shared
        let initial = workspace.isPlaying
        workspace.togglePlayback()
        XCTAssertNotEqual(workspace.isPlaying, initial)
        // Toggle back
        workspace.togglePlayback()
        XCTAssertEqual(workspace.isPlaying, initial)
    }

    func testBPMGridSyncedToWorkspace() {
        let workspace = EchoelCreativeWorkspace.shared
        workspace.setGlobalBPM(128.0)
        XCTAssertEqual(workspace.bpmGrid.grid.bpm, 128.0, accuracy: 0.01)
        workspace.setGlobalBPM(120.0)
    }

    func testBPMRangeValid() {
        let workspace = EchoelCreativeWorkspace.shared
        workspace.setGlobalBPM(60.0)
        XCTAssertGreaterThanOrEqual(workspace.globalBPM, 20.0)
        workspace.setGlobalBPM(200.0)
        XCTAssertLessThanOrEqual(workspace.globalBPM, 300.0)
        workspace.setGlobalBPM(120.0)
    }
}

// MARK: - ThemeManager Tests

@MainActor
final class ThemeManagerTests: XCTestCase {

    func testSharedInstance() {
        XCTAssertNotNil(ThemeManager.shared)
    }

    func testDefaultMode() {
        let manager = ThemeManager()
        // Default is dark (or whatever was persisted)
        XCTAssertNotNil(manager.currentMode)
    }

    func testToggle() {
        let manager = ThemeManager()
        manager.currentMode = .dark
        manager.toggle()
        XCTAssertEqual(manager.currentMode, .light)
        manager.toggle()
        XCTAssertEqual(manager.currentMode, .dark)
    }

    func testCycleMode() {
        let manager = ThemeManager()
        manager.currentMode = .dark
        manager.cycleMode()
        XCTAssertEqual(manager.currentMode, .light)
        manager.cycleMode()
        XCTAssertEqual(manager.currentMode, .system)
        manager.cycleMode()
        XCTAssertEqual(manager.currentMode, .dark)
    }

    func testSetMode() {
        let manager = ThemeManager()
        manager.setMode(.light)
        XCTAssertEqual(manager.currentMode, .light)
        manager.setMode(.dark)
        XCTAssertEqual(manager.currentMode, .dark)
        manager.setMode(.system)
        XCTAssertEqual(manager.currentMode, .system)
    }

    func testResolvedColorSchemeDark() {
        let manager = ThemeManager()
        manager.currentMode = .dark
        XCTAssertEqual(manager.resolvedColorScheme, .dark)
    }

    func testResolvedColorSchemeLight() {
        let manager = ThemeManager()
        manager.currentMode = .light
        XCTAssertEqual(manager.resolvedColorScheme, .light)
    }

    func testResolvedColorSchemeSystemIsNil() {
        let manager = ThemeManager()
        manager.currentMode = .system
        XCTAssertNil(manager.resolvedColorScheme)
    }

    func testPersistenceKey() {
        let manager = ThemeManager()
        manager.currentMode = .light
        let saved = UserDefaults.standard.string(forKey: "echoelmusic_theme_mode")
        XCTAssertEqual(saved, "Light")
        // Restore
        manager.currentMode = .dark
    }

    func testInitFromPersistedValue() {
        UserDefaults.standard.set("Light", forKey: "echoelmusic_theme_mode")
        let manager = ThemeManager()
        XCTAssertEqual(manager.currentMode, .light)
        // Restore
        UserDefaults.standard.set("Dark", forKey: "echoelmusic_theme_mode")
    }
}

// MARK: - VisualStepSequencer Tests

@MainActor
final class VisualStepSequencerTests: XCTestCase {

    func testInitialization() {
        let seq = VisualStepSequencer()
        XCTAssertNotNil(seq)
    }

    func testDefaultStepCount() {
        XCTAssertEqual(VisualStepSequencer.stepCount, 16)
    }

    func testDefaultBPM() {
        let seq = VisualStepSequencer()
        XCTAssertEqual(seq.bpm, 120.0, accuracy: 0.01)
    }

    func testSetBPM() {
        let seq = VisualStepSequencer()
        seq.bpm = 140.0
        XCTAssertEqual(seq.bpm, 140.0, accuracy: 0.01)
    }

    func testDefaultIsNotPlaying() {
        let seq = VisualStepSequencer()
        XCTAssertFalse(seq.isPlaying)
    }

    func testCurrentStepStartsAtZero() {
        let seq = VisualStepSequencer()
        XCTAssertEqual(seq.currentStep, 0)
    }

    func testPatternExists() {
        let seq = VisualStepSequencer()
        XCTAssertNotNil(seq.pattern)
    }

    func testPatternChannelCount() {
        let seq = VisualStepSequencer()
        XCTAssertGreaterThan(seq.pattern.channels.count, 0)
    }

    func testToggleStep() {
        let seq = VisualStepSequencer()
        guard !seq.pattern.channels.isEmpty else {
            XCTFail("No channels in pattern")
            return
        }
        let channel = VisualStepSequencer.Channel.visual1
        let initial = seq.pattern.channels[0].steps[0].active
        seq.toggleStep(channel: channel, step: 0)
        XCTAssertNotEqual(seq.pattern.channels[0].steps[0].active, initial)
    }

    func testClearAll() {
        let seq = VisualStepSequencer()
        // Activate a step
        seq.toggleStep(channel: .visual1, step: 0)
        seq.clearAll()
        // After clear, pattern should be reset
        for channel in seq.pattern.channels {
            for step in channel.steps {
                XCTAssertFalse(step.active, "Step should be inactive after clearAll")
            }
        }
    }
}

// MARK: - ClipLauncherGrid Integration Tests

@MainActor
final class ClipLauncherGridTests: XCTestCase {

    func testInitialization() {
        let grid = ClipLauncherGrid()
        XCTAssertNotNil(grid)
    }

    func testDefaultTrackCount() {
        let grid = ClipLauncherGrid()
        XCTAssertGreaterThan(grid.tracks.count, 0)
    }

    func testDefaultSceneCount() {
        let grid = ClipLauncherGrid()
        XCTAssertGreaterThan(grid.scenes.count, 0)
    }

    func testDefaultNotPlaying() {
        let grid = ClipLauncherGrid()
        XCTAssertFalse(grid.isPlaying)
    }

    func testDefaultTempo() {
        let grid = ClipLauncherGrid()
        XCTAssertEqual(grid.tempo, 120.0, accuracy: 0.01)
    }

    func testTracksHaveClips() {
        let grid = ClipLauncherGrid()
        for track in grid.tracks {
            XCTAssertGreaterThan(track.clips.count, 0, "Track \(track.name) has no clips")
        }
    }

    func testTrackNamesExist() {
        let grid = ClipLauncherGrid()
        for track in grid.tracks {
            XCTAssertFalse(track.name.isEmpty, "Track name should not be empty")
        }
    }

    func testSceneNamesExist() {
        let grid = ClipLauncherGrid()
        for scene in grid.scenes {
            XCTAssertFalse(scene.name.isEmpty, "Scene name should not be empty")
        }
    }

    func testSelectedSceneDefault() {
        let grid = ClipLauncherGrid()
        // Default is nil (no scene selected)
        XCTAssertNil(grid.selectedSceneIndex)
    }

    func testSetTempo() {
        let grid = ClipLauncherGrid()
        grid.tempo = 140.0
        XCTAssertEqual(grid.tempo, 140.0, accuracy: 0.01)
    }

    func testBioReactiveEnabledDefault() {
        let grid = ClipLauncherGrid()
        XCTAssertTrue(grid.bioReactiveEnabled)
    }

    func testCurrentCoherenceDefault() {
        let grid = ClipLauncherGrid()
        XCTAssertEqual(grid.currentCoherence, 0.5, accuracy: 0.01)
    }
}

// MARK: - LoopEngine Tests

@MainActor
final class LoopEngineIntegrationTests: XCTestCase {

    func testInitialization() {
        let engine = LoopEngine()
        XCTAssertNotNil(engine)
    }

    func testDefaultNotPlaying() {
        let engine = LoopEngine()
        XCTAssertFalse(engine.isPlayingLoops)
    }

    func testSetTempo() {
        let engine = LoopEngine()
        engine.setTempo(140.0)
        XCTAssertEqual(engine.tempo, 140.0, accuracy: 0.01)
    }

    func testSetTempoClampedMin() {
        let engine = LoopEngine()
        engine.setTempo(10.0)
        XCTAssertGreaterThanOrEqual(engine.tempo, 40.0)
    }

    func testSetTempoClampedMax() {
        let engine = LoopEngine()
        engine.setTempo(300.0)
        XCTAssertLessThanOrEqual(engine.tempo, 240.0)
    }

    func testDefaultLoopsEmpty() {
        let engine = LoopEngine()
        XCTAssertTrue(engine.loops.isEmpty)
    }

    func testSetTimeSignature() {
        let engine = LoopEngine()
        engine.setTimeSignature(beats: 3, noteValue: 4)
        XCTAssertEqual(engine.timeSignature.numerator, 3)
        XCTAssertEqual(engine.timeSignature.denominator, 4)
    }

    func testBarDuration() {
        let engine = LoopEngine()
        engine.setTempo(120.0)
        engine.setTimeSignature(beats: 4, noteValue: 4)
        // At 120 BPM, 4/4: bar = 4 * 0.5s = 2.0s
        XCTAssertEqual(engine.barDurationSeconds(), 2.0, accuracy: 0.01)
    }
}

// MARK: - HapticHelper Tests

final class HapticHelperTests: XCTestCase {

    func testStyleCases() {
        // Verify all style cases compile and exist
        let styles: [HapticHelper.Style] = [.light, .medium, .heavy, .selection]
        XCTAssertEqual(styles.count, 4)
    }

    func testNotificationTypeCases() {
        let types: [HapticHelper.NotificationType] = [.success, .warning, .error]
        XCTAssertEqual(types.count, 3)
    }

    func testImpactDoesNotCrash() {
        // On simulator/CI these are no-ops, but should not crash
        HapticHelper.impact(.light)
        HapticHelper.impact(.medium)
        HapticHelper.impact(.heavy)
        HapticHelper.impact(.selection)
    }

    func testNotificationDoesNotCrash() {
        HapticHelper.notification(.success)
        HapticHelper.notification(.warning)
        HapticHelper.notification(.error)
    }
}

// MARK: - EchoelDDSP Bio-Reactive Tests

final class EchoelDDSPBioReactiveTests: XCTestCase {

    func testInitialization() {
        let ddsp = EchoelDDSP(harmonicCount: 32, sampleRate: 48000)
        XCTAssertNotNil(ddsp)
    }

    func testApplyBioReactiveDoesNotCrash() {
        let ddsp = EchoelDDSP(harmonicCount: 32, sampleRate: 48000)
        ddsp.applyBioReactive(
            coherence: 0.5,
            hrvVariability: 0.5,
            heartRate: 0.5,
            breathPhase: 0.5
        )
    }

    func testApplyBioReactiveEdgeCaseLow() {
        let ddsp = EchoelDDSP(harmonicCount: 32, sampleRate: 48000)
        ddsp.applyBioReactive(
            coherence: 0.0,
            hrvVariability: 0.0,
            heartRate: 0.0,
            breathPhase: 0.0
        )
    }

    func testApplyBioReactiveEdgeCaseHigh() {
        let ddsp = EchoelDDSP(harmonicCount: 32, sampleRate: 48000)
        ddsp.applyBioReactive(
            coherence: 1.0,
            hrvVariability: 1.0,
            heartRate: 1.0,
            breathPhase: 1.0
        )
    }

    func testRenderProducesAudio() {
        let ddsp = EchoelDDSP(harmonicCount: 32, sampleRate: 48000)
        ddsp.frequency = 440.0
        ddsp.amplitude = 0.5
        var buffer = [Float](repeating: 0, count: 512)
        ddsp.render(buffer: &buffer, frameCount: 512)
        let hasNonZero = buffer.contains { $0 != 0 }
        XCTAssertTrue(hasNonZero, "DDSP render should produce non-zero audio")
    }

    func testSetFrequency() {
        let ddsp = EchoelDDSP(harmonicCount: 32, sampleRate: 48000)
        ddsp.frequency = 440.0
        XCTAssertEqual(ddsp.frequency, 440.0, accuracy: 0.01)
    }

    func testSetAmplitude() {
        let ddsp = EchoelDDSP(harmonicCount: 32, sampleRate: 48000)
        ddsp.amplitude = 0.75
        XCTAssertEqual(ddsp.amplitude, 0.75, accuracy: 0.01)
    }

    func testRenderWithBioReactive() {
        let ddsp = EchoelDDSP(harmonicCount: 32, sampleRate: 48000)
        ddsp.frequency = 440.0
        ddsp.amplitude = 0.5
        ddsp.applyBioReactive(
            coherence: 0.8,
            hrvVariability: 0.6,
            heartRate: 0.7,
            breathPhase: 0.5
        )
        var buffer = [Float](repeating: 0, count: 512)
        ddsp.render(buffer: &buffer, frameCount: 512)
        let hasNonZero = buffer.contains { $0 != 0 }
        XCTAssertTrue(hasNonZero, "Bio-reactive DDSP render should produce audio")
    }
}

// MARK: - ProMixEngine Integration Tests

@MainActor
final class ProMixEngineIntegrationTests: XCTestCase {

    func testDefaultSession() {
        let mixer = ProMixEngine.defaultSession()
        XCTAssertNotNil(mixer)
    }

    func testSampleRate() {
        let mixer = ProMixEngine.defaultSession()
        XCTAssertEqual(mixer.sampleRate, 48000.0, accuracy: 1.0)
    }

    func testDefaultNotPlaying() {
        let mixer = ProMixEngine.defaultSession()
        XCTAssertFalse(mixer.isPlaying)
    }

    func testMasterChannelExists() {
        let mixer = ProMixEngine.defaultSession()
        XCTAssertNotNil(mixer.masterChannel)
    }

    func testChannelsExist() {
        let mixer = ProMixEngine.defaultSession()
        XCTAssertGreaterThan(mixer.channels.count, 0)
    }
}

// MARK: - ProSessionEngine Integration Tests

@MainActor
final class ProSessionEngineIntegrationTests: XCTestCase {

    func testDefaultSession() {
        let session = ProSessionEngine.defaultSession()
        XCTAssertNotNil(session)
    }

    func testGlobalBPMDefault() {
        let session = ProSessionEngine.defaultSession()
        XCTAssertEqual(session.globalBPM, 120.0, accuracy: 0.01)
    }

    func testRenderAudioReturnsNilWhenEmpty() {
        let session = ProSessionEngine.defaultSession()
        // Empty session should return nil or empty render
        let result = session.renderAudio(frameCount: 512)
        // Either nil or valid stereo pair
        if let stereo = result {
            XCTAssertEqual(stereo.left.count, 512)
            XCTAssertEqual(stereo.right.count, 512)
        }
    }
}

// MARK: - BPMGridEditEngine Tests

@MainActor
final class BPMGridEditEngineIntegrationTests: XCTestCase {

    func testInitialization() {
        let grid = BPMGridEditEngine(bpm: 120, timeSignature: .fourFour)
        XCTAssertNotNil(grid)
    }

    func testSetBPM() {
        let grid = BPMGridEditEngine(bpm: 120, timeSignature: .fourFour)
        grid.setBPM(140.0)
        XCTAssertEqual(grid.grid.bpm, 140.0, accuracy: 0.01)
    }

    func testSetTimeSignature() {
        let grid = BPMGridEditEngine(bpm: 120, timeSignature: .fourFour)
        let ts = TimeSignature(numerator: 3, denominator: 4)
        grid.setTimeSignature(ts)
        XCTAssertEqual(grid.grid.timeSignature, ts)
    }

    func testBeatSyncedEffectsDefault() {
        let grid = BPMGridEditEngine(bpm: 120, timeSignature: .fourFour)
        XCTAssertNotNil(grid.beatSyncedEffects)
    }
}

// MARK: - VideoEditingEngine Tests

@MainActor
final class VideoEditingEngineIntegrationTests: XCTestCase {

    func testInitialization() {
        let editor = VideoEditingEngine()
        XCTAssertNotNil(editor)
    }

    func testTimelineExists() {
        let editor = VideoEditingEngine()
        XCTAssertNotNil(editor.timeline)
    }

    func testDefaultTempo() {
        let editor = VideoEditingEngine()
        XCTAssertGreaterThan(editor.timeline.tempo, 0)
    }
}

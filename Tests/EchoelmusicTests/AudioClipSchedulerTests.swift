import XCTest
@testable import Echoelmusic

/// Tests for AudioClipScheduler — real-time clip playback scheduling.
/// Validates MIDI event triggering, pattern step sequencing, audio clip launch,
/// transport advancement, and stereo mixing.
@MainActor
final class AudioClipSchedulerTests: XCTestCase {

    var sut: AudioClipScheduler!
    let bpm: Double = 120.0

    override func setUp() async throws {
        try await super.setUp()
        sut = AudioClipScheduler(sampleRate: 44100, bufferSize: 512)
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Create a MIDI clip with note events
    private func makeMIDIClip(
        notes: [MIDINoteEvent],
        length: TimeInterval = 2.0,
        loopEnabled: Bool = true
    ) -> SessionClip {
        SessionClip(
            name: "Test MIDI",
            type: .midi,
            state: .playing,
            length: length,
            loopEnabled: loopEnabled,
            midiNotes: notes
        )
    }

    /// Create a pattern clip with steps
    private func makePatternClip(
        steps: [PatternStep],
        length: TimeInterval = 2.0,
        loopEnabled: Bool = true
    ) -> SessionClip {
        SessionClip(
            name: "Test Pattern",
            type: .pattern,
            state: .playing,
            length: length,
            loopEnabled: loopEnabled,
            patternSteps: steps
        )
    }

    /// Create a simple track
    private func makeTrack(name: String = "Track 1") -> SessionTrack {
        SessionTrack(
            name: name,
            type: .midi,
            volume: 0.85,
            pan: 0.0
        )
    }

    /// Helper to advance transport by a beat delta
    private func advanceTransport(
        previousBeat: Double,
        currentBeat: Double,
        clip: SessionClip
    ) {
        sut.advanceTransport(
            previousBeat: previousBeat,
            currentBeat: currentBeat,
            bpm: bpm
        ) { trackIndex in
            trackIndex == 0 ? clip : nil
        }
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertEqual(sut.activeTrackCount, 0)
    }

    func testEnsureTrackCreatesState() {
        let trackID = UUID()
        sut.ensureTrack(index: 0, trackID: trackID)
        XCTAssertNotNil(sut.sampler(forTrack: 0))
    }

    func testEnsureTrackIdempotent() {
        let trackID = UUID()
        sut.ensureTrack(index: 0, trackID: trackID)
        let sampler1 = sut.sampler(forTrack: 0)
        sut.ensureTrack(index: 0, trackID: trackID)
        let sampler2 = sut.sampler(forTrack: 0)
        // Should be the same sampler instance (not recreated)
        XCTAssertTrue(sampler1 === sampler2)
    }

    func testNoSamplerForNonexistentTrack() {
        XCTAssertNil(sut.sampler(forTrack: 99))
    }

    // MARK: - Clip Launch Tests

    func testLaunchClipSetsActiveState() {
        let clip = makeMIDIClip(notes: [])
        let trackID = UUID()

        sut.launchClip(clip, trackIndex: 0, sceneIndex: 0, trackID: trackID, atBeat: 0.0)

        XCTAssertTrue(sut.isTrackPlaying(0))
        XCTAssertEqual(sut.activeTrackCount, 1)
    }

    func testLaunchClipOnMultipleTracks() {
        let clip1 = makeMIDIClip(notes: [])
        let clip2 = makeMIDIClip(notes: [])

        sut.launchClip(clip1, trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)
        sut.launchClip(clip2, trackIndex: 1, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)

        XCTAssertTrue(sut.isTrackPlaying(0))
        XCTAssertTrue(sut.isTrackPlaying(1))
        XCTAssertEqual(sut.activeTrackCount, 2)
    }

    func testLaunchClipReplacesExisting() {
        let clip1 = makeMIDIClip(notes: [], length: 4.0)
        let clip2 = makeMIDIClip(notes: [], length: 8.0)

        sut.launchClip(clip1, trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)
        sut.launchClip(clip2, trackIndex: 0, sceneIndex: 1, trackID: UUID(), atBeat: 0.0)

        // Should still have exactly one active clip on track 0
        XCTAssertTrue(sut.isTrackPlaying(0))
        XCTAssertEqual(sut.activeTrackCount, 1)
    }

    // MARK: - Stop Tests

    func testStopTrack() {
        let clip = makeMIDIClip(notes: [])
        sut.launchClip(clip, trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)
        XCTAssertTrue(sut.isTrackPlaying(0))

        sut.stopTrack(trackIndex: 0)
        XCTAssertFalse(sut.isTrackPlaying(0))
    }

    func testStopAll() {
        sut.launchClip(makeMIDIClip(notes: []), trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)
        sut.launchClip(makeMIDIClip(notes: []), trackIndex: 1, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)
        XCTAssertEqual(sut.activeTrackCount, 2)

        sut.stopAll()
        XCTAssertEqual(sut.activeTrackCount, 0)
    }

    func testStopNonexistentTrackDoesNotCrash() {
        sut.stopTrack(trackIndex: 99) // Should not crash
    }

    // MARK: - Transport Advancement Tests

    func testClipBeatAdvances() {
        let clip = makeMIDIClip(notes: [])
        sut.launchClip(clip, trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)

        advanceTransport(previousBeat: 0.0, currentBeat: 1.0, clip: clip)

        let beatPos = sut.clipBeatPosition(forTrack: 0)
        XCTAssertNotNil(beatPos)
        XCTAssertEqual(beatPos!, 1.0, accuracy: 0.01)
    }

    func testClipBeatLoops() {
        // A clip that's 1 second long at 120 BPM = 2 beats
        let clip = makeMIDIClip(notes: [], length: 1.0, loopEnabled: true)
        sut.launchClip(clip, trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)

        // Advance past the clip length (2 beats) to beat 3.0
        advanceTransport(previousBeat: 0.0, currentBeat: 3.0, clip: clip)

        let beatPos = sut.clipBeatPosition(forTrack: 0)
        XCTAssertNotNil(beatPos)
        // 3.0 beats mod 2.0 beats = 1.0
        XCTAssertEqual(beatPos!, 1.0, accuracy: 0.01)
    }

    func testNonLoopingClipStops() {
        let clip = makeMIDIClip(notes: [], length: 1.0, loopEnabled: false)
        sut.launchClip(clip, trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)

        // Advance past clip end
        advanceTransport(previousBeat: 0.0, currentBeat: 3.0, clip: clip)

        // Clip should have stopped
        XCTAssertFalse(sut.isTrackPlaying(0))
    }

    func testZeroDeltaBeatDoesNothing() {
        let clip = makeMIDIClip(notes: [])
        sut.launchClip(clip, trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)

        advanceTransport(previousBeat: 1.0, currentBeat: 1.0, clip: clip)

        // Beat position should remain at 0 (initial)
        let beatPos = sut.clipBeatPosition(forTrack: 0)
        XCTAssertEqual(beatPos!, 0.0, accuracy: 0.01)
    }

    // MARK: - MIDI Event Tests

    func testMIDINoteTriggered() {
        let note = MIDINoteEvent(note: 60, velocity: 100, startBeat: 0.5, duration: 0.25)
        let clip = makeMIDIClip(notes: [note], length: 2.0)
        sut.launchClip(clip, trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)

        // Advance to beat 0.6 — note at 0.5 should have been triggered
        advanceTransport(previousBeat: 0.0, currentBeat: 0.6, clip: clip)

        // Render to verify sampler was activated (should produce non-silent output)
        let buffer = sut.renderTrack(0, frameCount: 512)
        XCTAssertNotNil(buffer)
        // The sampler should have at least been called (output depends on loaded samples)
    }

    func testMultipleMIDINotes() {
        let notes = [
            MIDINoteEvent(note: 60, velocity: 100, startBeat: 0.0, duration: 0.5),
            MIDINoteEvent(note: 64, velocity: 80, startBeat: 1.0, duration: 0.5),
            MIDINoteEvent(note: 67, velocity: 90, startBeat: 1.5, duration: 0.5),
        ]
        let clip = makeMIDIClip(notes: notes, length: 4.0)
        sut.launchClip(clip, trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)

        // Advance through the clip in steps
        advanceTransport(previousBeat: 0.0, currentBeat: 0.1, clip: clip)
        advanceTransport(previousBeat: 0.1, currentBeat: 1.1, clip: clip)
        advanceTransport(previousBeat: 1.1, currentBeat: 1.6, clip: clip)

        // Track should still be playing
        XCTAssertTrue(sut.isTrackPlaying(0))
    }

    // MARK: - Pattern Step Tests

    func testPatternStepTriggered() {
        var steps = (0..<4).map { PatternStep(stepIndex: $0) }
        steps[0].isActive = true
        steps[0].velocity = 1.0
        steps[2].isActive = true
        steps[2].velocity = 0.8

        // 4 steps over 1 second at 120 BPM = 2 beats, so 0.5 beats per step
        let clip = makePatternClip(steps: steps, length: 1.0)
        sut.launchClip(clip, trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)

        // Advance past step 0 (at beat 0)
        advanceTransport(previousBeat: 0.0, currentBeat: 0.6, clip: clip)

        // Render to verify sampler activation
        let buffer = sut.renderTrack(0, frameCount: 256)
        XCTAssertNotNil(buffer)
        XCTAssertTrue(sut.isTrackPlaying(0))
    }

    func testPatternStepProbability() {
        // Create a step with 0% probability — should never trigger
        var steps = (0..<4).map { PatternStep(stepIndex: $0) }
        steps[0].isActive = true
        steps[0].probability = 0.0 // Never plays

        let clip = makePatternClip(steps: steps, length: 1.0)
        sut.launchClip(clip, trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)

        advanceTransport(previousBeat: 0.0, currentBeat: 0.6, clip: clip)

        // Track should still be playing (pattern continues even if step didn't trigger)
        XCTAssertTrue(sut.isTrackPlaying(0))
    }

    func testEmptyPatternDoesNotCrash() {
        let clip = makePatternClip(steps: [], length: 1.0)
        sut.launchClip(clip, trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)

        advanceTransport(previousBeat: 0.0, currentBeat: 1.0, clip: clip)
        XCTAssertTrue(sut.isTrackPlaying(0))
    }

    // MARK: - Audio Clip Tests

    func testAudioClipLaunchTriggersNote() {
        let clip = SessionClip(
            name: "Audio Test",
            type: .audio,
            state: .playing,
            length: 4.0,
            loopEnabled: true
        )
        sut.launchClip(clip, trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)

        advanceTransport(previousBeat: 0.0, currentBeat: 0.1, clip: clip)

        // Track should be playing
        XCTAssertTrue(sut.isTrackPlaying(0))
    }

    // MARK: - Rendering Tests

    func testRenderAllTracksEmpty() {
        let result = sut.renderAllTracks(frameCount: 512)
        XCTAssertTrue(result.isEmpty)
    }

    func testRenderAllTracksZeroFrames() {
        let result = sut.renderAllTracks(frameCount: 0)
        XCTAssertTrue(result.isEmpty)
    }

    func testRenderTrackNoActiveClip() {
        sut.ensureTrack(index: 0, trackID: UUID())
        let buffer = sut.renderTrack(0, frameCount: 512)
        XCTAssertNil(buffer)
    }

    func testRenderTrackWithActiveClip() {
        let clip = makeMIDIClip(notes: [
            MIDINoteEvent(note: 60, velocity: 100, startBeat: 0.0, duration: 1.0)
        ])
        sut.launchClip(clip, trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)
        advanceTransport(previousBeat: 0.0, currentBeat: 0.1, clip: clip)

        let buffer = sut.renderTrack(0, frameCount: 512)
        XCTAssertNotNil(buffer)
        XCTAssertEqual(buffer?.count, 512)
    }

    // MARK: - Stereo Mixing Tests

    func testMixToStereoEmpty() {
        let result = sut.mixToStereo(trackBuffers: [:], tracks: [], frameCount: 512)
        XCTAssertTrue(result.left.isEmpty)
        XCTAssertTrue(result.right.isEmpty)
    }

    func testMixToStereoZeroFrames() {
        let result = sut.mixToStereo(trackBuffers: [:], tracks: [], frameCount: 0)
        XCTAssertTrue(result.left.isEmpty)
    }

    func testMixToStereoCenter() {
        let testBuffer = [Float](repeating: 0.5, count: 256)
        let track = SessionTrack(name: "Center", type: .audio, volume: 1.0, pan: 0.0)

        let result = sut.mixToStereo(
            trackBuffers: [0: testBuffer],
            tracks: [track],
            frameCount: 256
        )

        XCTAssertEqual(result.left.count, 256)
        XCTAssertEqual(result.right.count, 256)

        // Center pan should give roughly equal level to both channels
        let leftLevel = result.left.reduce(0, +) / Float(result.left.count)
        let rightLevel = result.right.reduce(0, +) / Float(result.right.count)
        XCTAssertEqual(leftLevel, rightLevel, accuracy: 0.01)
    }

    func testMixToStereoHardLeft() {
        let testBuffer = [Float](repeating: 1.0, count: 256)
        let track = SessionTrack(name: "Left", type: .audio, volume: 1.0, pan: -1.0)

        let result = sut.mixToStereo(
            trackBuffers: [0: testBuffer],
            tracks: [track],
            frameCount: 256
        )

        // Hard left: left channel should have signal, right should be near zero
        let leftLevel = result.left.reduce(0, +) / Float(result.left.count)
        let rightLevel = result.right.reduce(0, +) / Float(result.right.count)
        XCTAssertGreaterThan(leftLevel, 0.5)
        XCTAssertLessThan(rightLevel, 0.01)
    }

    func testMixToStereoHardRight() {
        let testBuffer = [Float](repeating: 1.0, count: 256)
        let track = SessionTrack(name: "Right", type: .audio, volume: 1.0, pan: 1.0)

        let result = sut.mixToStereo(
            trackBuffers: [0: testBuffer],
            tracks: [track],
            frameCount: 256
        )

        let leftLevel = result.left.reduce(0, +) / Float(result.left.count)
        let rightLevel = result.right.reduce(0, +) / Float(result.right.count)
        XCTAssertLessThan(leftLevel, 0.01)
        XCTAssertGreaterThan(rightLevel, 0.5)
    }

    func testMixToStereoMutedTrack() {
        let testBuffer = [Float](repeating: 1.0, count: 256)
        let track = SessionTrack(name: "Muted", type: .audio, volume: 1.0, pan: 0.0, mute: true)

        let result = sut.mixToStereo(
            trackBuffers: [0: testBuffer],
            tracks: [track],
            frameCount: 256
        )

        // Muted track should produce silence
        let leftLevel = result.left.reduce(0) { $0 + abs($1) }
        XCTAssertEqual(leftLevel, 0.0, accuracy: 0.001)
    }

    func testMixToStereoSoloIsolation() {
        let buffer1 = [Float](repeating: 0.5, count: 256)
        let buffer2 = [Float](repeating: 0.8, count: 256)

        let track1 = SessionTrack(name: "Soloed", type: .audio, volume: 1.0, pan: 0.0, solo: true)
        let track2 = SessionTrack(name: "Not Soloed", type: .audio, volume: 1.0, pan: 0.0, solo: false)

        let result = sut.mixToStereo(
            trackBuffers: [0: buffer1, 1: buffer2],
            tracks: [track1, track2],
            frameCount: 256
        )

        // Only the soloed track should be heard
        let leftLevel = result.left.reduce(0, +) / Float(result.left.count)
        // Level should be from buffer1 (0.5) scaled by equal-power center pan
        XCTAssertGreaterThan(leftLevel, 0.0)
        // Should not include buffer2's 0.8 contribution
        XCTAssertLessThan(leftLevel, 0.7)
    }

    func testMixToStereoZeroVolume() {
        let testBuffer = [Float](repeating: 1.0, count: 256)
        let track = SessionTrack(name: "Silent", type: .audio, volume: 0.0, pan: 0.0)

        let result = sut.mixToStereo(
            trackBuffers: [0: testBuffer],
            tracks: [track],
            frameCount: 256
        )

        let leftLevel = result.left.reduce(0) { $0 + abs($1) }
        XCTAssertEqual(leftLevel, 0.0, accuracy: 0.001)
    }

    // MARK: - Playback Speed Tests

    func testPlaybackSpeedDoubleAdvancesFaster() {
        let clip = SessionClip(
            name: "Fast",
            type: .midi,
            state: .playing,
            length: 4.0,
            loopEnabled: true,
            playbackSpeed: 2.0
        )
        sut.launchClip(clip, trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)

        advanceTransport(previousBeat: 0.0, currentBeat: 1.0, clip: clip)

        // At 2x speed, 1 beat of transport = 2 beats of clip position
        let beatPos = sut.clipBeatPosition(forTrack: 0)
        XCTAssertNotNil(beatPos)
        XCTAssertEqual(beatPos!, 2.0, accuracy: 0.01)
    }

    func testPlaybackSpeedHalfAdvancesSlower() {
        let clip = SessionClip(
            name: "Slow",
            type: .midi,
            state: .playing,
            length: 4.0,
            loopEnabled: true,
            playbackSpeed: 0.5
        )
        sut.launchClip(clip, trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)

        advanceTransport(previousBeat: 0.0, currentBeat: 2.0, clip: clip)

        // At 0.5x speed, 2 beats of transport = 1 beat of clip position
        let beatPos = sut.clipBeatPosition(forTrack: 0)
        XCTAssertNotNil(beatPos)
        XCTAssertEqual(beatPos!, 1.0, accuracy: 0.01)
    }

    // MARK: - Bio-Reactive Tests

    func testUpdateBioDataDoesNotCrash() {
        sut.ensureTrack(index: 0, trackID: UUID())
        sut.updateBioData(hrv: 50, coherence: 0.7, heartRate: 72, breathPhase: 0.5, flow: 0.8)
        // Should not crash
    }

    // MARK: - Reset Tests

    func testReset() {
        sut.launchClip(makeMIDIClip(notes: []), trackIndex: 0, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)
        sut.launchClip(makeMIDIClip(notes: []), trackIndex: 1, sceneIndex: 0, trackID: UUID(), atBeat: 0.0)
        XCTAssertEqual(sut.activeTrackCount, 2)

        sut.reset()
        XCTAssertEqual(sut.activeTrackCount, 0)
        XCTAssertNil(sut.sampler(forTrack: 0))
    }

    // MARK: - Integration with ProSessionEngine

    func testProSessionEngineLaunchTriggersScheduler() {
        let engine = ProSessionEngine.defaultSession()
        let track = engine.addTrack(type: .midi, name: "Test MIDI")

        guard let trackIdx = engine.tracks.firstIndex(where: { $0.id == track.id }) else {
            XCTFail("Track not found")
            return
        }

        // Create and place a MIDI clip
        let clip = SessionClip(
            name: "MIDI Test",
            type: .midi,
            state: .stopped,
            length: 2.0,
            midiNotes: [
                MIDINoteEvent(note: 60, velocity: 100, startBeat: 0.0, duration: 0.5)
            ]
        )
        engine.tracks[trackIdx].ensureSlots(count: 1)
        engine.tracks[trackIdx].clips[0] = clip

        // Launch without quantization
        engine.launchClip(trackIndex: trackIdx, sceneIndex: 0)

        // Verify the scheduler has an active clip
        XCTAssertTrue(engine.audioScheduler.isTrackPlaying(trackIdx))
    }

    func testProSessionEngineStopClearsScheduler() {
        let engine = ProSessionEngine.defaultSession()
        let clip = SessionClip(
            name: "Test",
            type: .midi,
            state: .stopped,
            length: 2.0
        )
        let trackIdx = 0
        engine.tracks[trackIdx].ensureSlots(count: 1)
        engine.tracks[trackIdx].clips[0] = clip

        engine.launchClip(trackIndex: trackIdx, sceneIndex: 0)
        XCTAssertTrue(engine.audioScheduler.isTrackPlaying(trackIdx))

        engine.stopClip(trackIndex: trackIdx, sceneIndex: 0)
        XCTAssertFalse(engine.audioScheduler.isTrackPlaying(trackIdx))
    }

    func testProSessionEngineStopAllClearsScheduler() {
        let engine = ProSessionEngine.defaultSession()

        // Place clips on two tracks
        for i in 0..<2 {
            let clip = SessionClip(name: "Clip \(i)", type: .midi, state: .stopped, length: 2.0)
            engine.tracks[i].ensureSlots(count: 1)
            engine.tracks[i].clips[0] = clip
            engine.launchClip(trackIndex: i, sceneIndex: 0)
        }

        XCTAssertEqual(engine.audioScheduler.activeTrackCount, 2)

        engine.stopAllClips()
        XCTAssertEqual(engine.audioScheduler.activeTrackCount, 0)
    }

    func testProSessionEngineRenderAudioNilWhenNotPlaying() {
        let engine = ProSessionEngine.defaultSession()
        let result = engine.renderAudio(frameCount: 512)
        XCTAssertNil(result)
    }

    func testProSessionEngineRenderAudioWithActiveClip() {
        let engine = ProSessionEngine.defaultSession()

        let clip = SessionClip(
            name: "Render Test",
            type: .midi,
            state: .stopped,
            length: 2.0,
            midiNotes: [MIDINoteEvent(note: 60, velocity: 100, startBeat: 0.0, duration: 1.0)]
        )
        engine.tracks[0].ensureSlots(count: 1)
        engine.tracks[0].clips[0] = clip
        engine.launchClip(trackIndex: 0, sceneIndex: 0)

        // Advance the scheduler so the note gets triggered
        engine.audioScheduler.advanceTransport(
            previousBeat: 0.0,
            currentBeat: 0.1,
            bpm: 120.0
        ) { trackIndex in
            trackIndex == 0 ? clip : nil
        }

        let result = engine.renderAudio(frameCount: 512)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.left.count, 512)
        XCTAssertEqual(result?.right.count, 512)
    }

    func testProSessionEngineTransportStopResetsScheduler() {
        let engine = ProSessionEngine.defaultSession()

        let clip = SessionClip(name: "Test", type: .midi, state: .stopped, length: 2.0)
        engine.tracks[0].ensureSlots(count: 1)
        engine.tracks[0].clips[0] = clip
        engine.launchClip(trackIndex: 0, sceneIndex: 0)
        XCTAssertTrue(engine.audioScheduler.isTrackPlaying(0))

        engine.stop()
        XCTAssertFalse(engine.audioScheduler.isTrackPlaying(0))
    }
}

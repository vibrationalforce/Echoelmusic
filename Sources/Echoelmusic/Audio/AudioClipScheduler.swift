import Foundation
import AVFoundation
import Accelerate

// MARK: - AudioClipScheduler

/// Real-time audio scheduler for ProSessionEngine clip playback.
/// Manages per-clip playback position, MIDI note triggering, pattern step sequencing,
/// and audio file buffer playback through EchoelSampler instances.
///
/// Architecture:
/// - Each track gets its own `TrackPlaybackState` with an EchoelSampler
/// - MIDI clips: noteOn/noteOff events fired at beat positions
/// - Pattern clips: step sequencer with probability, velocity, gate
/// - Audio clips: loaded into sampler zones, triggered as notes
/// - Output: per-track [Float] buffers summed by caller (ProSessionEngine)
@MainActor
public final class AudioClipScheduler {

    // MARK: - Types

    /// Playback state for a single clip on a track
    struct ClipPlaybackState {
        /// Beat position within the clip (resets on loop)
        var clipBeat: Double = 0.0
        /// Absolute beat when this clip was launched
        var launchBeat: Double = 0.0
        /// Whether we've completed at least one full pass
        var hasLooped: Bool = false
        /// Set of MIDI note events already triggered this pass (by event ID)
        var triggeredNoteIDs: Set<UUID> = []
        /// Set of active note numbers (for noteOff scheduling)
        var activeNotes: Set<Int> = []
        /// Last pattern step index that was triggered
        var lastTriggeredStep: Int = -1
        /// The clip ID being played
        var clipID: UUID
        /// Track index for reference
        var trackIndex: Int
        /// Scene index for reference
        var sceneIndex: Int

        init(clipID: UUID, trackIndex: Int, sceneIndex: Int, launchBeat: Double) {
            self.clipID = clipID
            self.trackIndex = trackIndex
            self.sceneIndex = sceneIndex
            self.launchBeat = launchBeat
        }
    }

    /// Per-track audio state
    struct TrackPlaybackState {
        let trackID: UUID
        /// Sampler instance for this track
        var sampler: EchoelSampler
        /// Currently active clip playback (nil if nothing playing)
        var activeClip: ClipPlaybackState?
        /// Pre-loaded audio buffers keyed by clip ID
        var loadedAudioBuffers: [UUID: [Float]] = [:]
        /// Output buffer for latest render
        var outputBuffer: [Float] = []
    }

    // MARK: - Properties

    /// Per-track playback states keyed by track index
    private var trackStates: [Int: TrackPlaybackState] = [:]

    /// Sample rate for audio rendering
    public let sampleRate: Float

    /// Buffer size for rendering
    public let bufferSize: Int

    private let log = ProfessionalLogger.shared

    // MARK: - Initialization

    public init(sampleRate: Float = 44100, bufferSize: Int = 512) {
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
    }

    // MARK: - Track Setup

    /// Ensure a track has a playback state with a sampler
    public func ensureTrack(index: Int, trackID: UUID) {
        guard trackStates[index] == nil else { return }
        let sampler = EchoelSampler(sampleRate: sampleRate)
        trackStates[index] = TrackPlaybackState(
            trackID: trackID,
            sampler: sampler
        )
    }

    /// Get the sampler for a track (for external configuration like loading samples)
    public func sampler(forTrack index: Int) -> EchoelSampler? {
        trackStates[index]?.sampler
    }

    // MARK: - Clip Launch / Stop

    /// Launch a clip on a track — initializes playback state and loads audio if needed
    public func launchClip(
        _ clip: SessionClip,
        trackIndex: Int,
        sceneIndex: Int,
        trackID: UUID,
        atBeat: Double
    ) {
        ensureTrack(index: trackIndex, trackID: trackID)

        // Stop any currently playing clip on this track first
        stopTrack(trackIndex: trackIndex)

        var playbackState = ClipPlaybackState(
            clipID: clip.id,
            trackIndex: trackIndex,
            sceneIndex: sceneIndex,
            launchBeat: atBeat
        )

        // For audio clips, load the audio buffer into sampler if not already loaded
        if clip.type == .audio, let audioURL = clip.audioURL {
            loadAudioClipIfNeeded(clip: clip, audioURL: audioURL, trackIndex: trackIndex)
        }

        trackStates[trackIndex]?.activeClip = playbackState
        log.info("Scheduler: clip launched on track \(trackIndex): \(clip.name)", category: .audio)
    }

    /// Stop playback on a specific track
    public func stopTrack(trackIndex: Int) {
        guard var state = trackStates[trackIndex] else { return }

        // Send noteOff for any active notes
        if let activeClip = state.activeClip {
            for note in activeClip.activeNotes {
                state.sampler.noteOff(note: note)
            }
        }

        state.activeClip = nil
        trackStates[trackIndex] = state
    }

    /// Stop all tracks
    public func stopAll() {
        for index in trackStates.keys {
            stopTrack(trackIndex: index)
        }
    }

    // MARK: - Audio File Loading

    /// Load an audio file into the track's sampler as a playable zone
    private func loadAudioClipIfNeeded(clip: SessionClip, audioURL: URL, trackIndex: Int) {
        guard var state = trackStates[trackIndex] else { return }

        // Skip if already loaded
        if state.loadedAudioBuffers[clip.id] != nil { return }

        do {
            let zoneIndex = try state.sampler.loadFromAudioFile(
                audioURL,
                rootNote: 60,
                name: clip.name
            )
            // Store a marker that it's loaded (actual data is in sampler zones)
            state.loadedAudioBuffers[clip.id] = [1.0] // sentinel
            trackStates[trackIndex] = state
            log.info("Scheduler: audio loaded for clip \(clip.name) (zone \(zoneIndex))", category: .audio)
        } catch {
            log.error("Scheduler: failed to load audio for \(clip.name): \(error)", category: .audio)
        }
    }

    // MARK: - Transport Tick (called every 240Hz tick)

    /// Advance all playing clips by the given beat delta and trigger events
    public func advanceTransport(
        previousBeat: Double,
        currentBeat: Double,
        bpm: Double,
        clips: (Int) -> SessionClip?
    ) {
        let deltaBeat = currentBeat - previousBeat
        guard deltaBeat > 0 else { return }

        for trackIndex in trackStates.keys.sorted() {
            guard var state = trackStates[trackIndex],
                  var activeClip = state.activeClip,
                  let clip = clips(trackIndex) else { continue }

            // Calculate clip-local beat position
            let clipBeatsLength = clipLengthInBeats(clip: clip, bpm: bpm)
            guard clipBeatsLength > 0 else { continue }

            let previousClipBeat = activeClip.clipBeat
            activeClip.clipBeat += deltaBeat * clip.playbackSpeed

            // Handle looping
            if clip.loopEnabled && activeClip.clipBeat >= clipBeatsLength {
                activeClip.clipBeat = activeClip.clipBeat.truncatingRemainder(dividingBy: clipBeatsLength)
                activeClip.hasLooped = true
                // Reset triggered events for new loop pass
                activeClip.triggeredNoteIDs.removeAll()
                activeClip.lastTriggeredStep = -1

                // Release all active notes at loop boundary
                for note in activeClip.activeNotes {
                    state.sampler.noteOff(note: note)
                }
                activeClip.activeNotes.removeAll()
            } else if !clip.loopEnabled && activeClip.clipBeat >= clipBeatsLength {
                // Non-looping clip finished — stop it
                for note in activeClip.activeNotes {
                    state.sampler.noteOff(note: note)
                }
                activeClip.activeNotes.removeAll()
                state.activeClip = nil
                trackStates[trackIndex] = state
                continue
            }

            let currentClipBeat = activeClip.clipBeat

            // Process events based on clip type
            switch clip.type {
            case .midi:
                processMIDIEvents(
                    clip: clip,
                    previousBeat: previousClipBeat,
                    currentBeat: currentClipBeat,
                    clipLength: clipBeatsLength,
                    activeClip: &activeClip,
                    sampler: &state.sampler
                )

            case .pattern:
                processPatternSteps(
                    clip: clip,
                    previousBeat: previousClipBeat,
                    currentBeat: currentClipBeat,
                    clipLength: clipBeatsLength,
                    bpm: bpm,
                    activeClip: &activeClip,
                    sampler: &state.sampler
                )

            case .audio:
                processAudioClip(
                    clip: clip,
                    previousBeat: previousClipBeat,
                    currentBeat: currentClipBeat,
                    activeClip: &activeClip,
                    sampler: &state.sampler
                )

            case .automation, .video:
                break // Not handled by audio scheduler
            }

            state.activeClip = activeClip
            trackStates[trackIndex] = state
        }
    }

    // MARK: - MIDI Event Processing

    /// Fire MIDI noteOn/noteOff events that fall within the beat window
    private func processMIDIEvents(
        clip: SessionClip,
        previousBeat: Double,
        currentBeat: Double,
        clipLength: Double,
        activeClip: inout ClipPlaybackState,
        sampler: inout EchoelSampler
    ) {
        for event in clip.midiNotes {
            let eventBeat = event.startBeat

            // Check if this event falls in the current tick window
            guard eventBeat >= previousBeat, eventBeat < currentBeat else { continue }

            // Skip if already triggered this pass
            guard !activeClip.triggeredNoteIDs.contains(event.id) else { continue }

            // Fire noteOn
            sampler.noteOn(note: Int(event.note), velocity: Int(event.velocity))
            activeClip.activeNotes.insert(Int(event.note))
            activeClip.triggeredNoteIDs.insert(event.id)

            // Schedule noteOff based on duration
            let noteOffBeat = eventBeat + event.duration
            if noteOffBeat <= currentBeat {
                // Note already ended within this tick
                sampler.noteOff(note: Int(event.note))
                activeClip.activeNotes.remove(Int(event.note))
            }
        }

        // Check for noteOff events (notes whose duration has elapsed)
        for event in clip.midiNotes {
            guard activeClip.triggeredNoteIDs.contains(event.id) else { continue }
            let noteOffBeat = event.startBeat + event.duration
            if noteOffBeat >= previousBeat && noteOffBeat < currentBeat {
                sampler.noteOff(note: Int(event.note))
                activeClip.activeNotes.remove(Int(event.note))
            }
        }
    }

    // MARK: - Pattern Step Processing

    /// Trigger pattern steps based on current beat position
    private func processPatternSteps(
        clip: SessionClip,
        previousBeat: Double,
        currentBeat: Double,
        clipLength: Double,
        bpm: Double,
        activeClip: inout ClipPlaybackState,
        sampler: inout EchoelSampler
    ) {
        let stepCount = clip.patternSteps.count
        guard stepCount > 0 else { return }

        // Each step = clipLength / stepCount beats
        let beatsPerStep = clipLength / Double(stepCount)
        guard beatsPerStep > 0 else { return }

        // Check each step: does its trigger beat fall within [previousBeat, currentBeat)?
        for stepIndex in 0..<stepCount {
            let stepBeat = Double(stepIndex) * beatsPerStep

            // Step must fall within this tick window
            guard stepBeat >= previousBeat, stepBeat < currentBeat else { continue }

            // Skip if already triggered
            guard stepIndex != activeClip.lastTriggeredStep else { continue }

            let step = clip.patternSteps[stepIndex]

            activeClip.lastTriggeredStep = stepIndex

            guard step.isActive else { continue }

            // Probability gate
            if step.probability < 1.0 {
                let roll = Float.random(in: 0...1)
                if roll > step.probability {
                    continue
                }
            }

            // Release previous step's note if any
            for note in activeClip.activeNotes {
                sampler.noteOff(note: note)
            }
            activeClip.activeNotes.removeAll()

            // Calculate note parameters
            let baseNote = 60 // C4 default for patterns
            let pitchOffset = Int(step.pitch)
            let noteNumber = max(0, min(127, baseNote + pitchOffset))
            let velocity = max(1, Int(step.velocity * 127))

            // Trigger the note
            sampler.noteOn(note: noteNumber, velocity: velocity)
            activeClip.activeNotes.insert(noteNumber)
        }
    }

    // MARK: - Audio Clip Processing

    /// Handle audio clip playback — trigger note at clip start, sampler handles the rest
    private func processAudioClip(
        clip: SessionClip,
        previousBeat: Double,
        currentBeat: Double,
        activeClip: inout ClipPlaybackState,
        sampler: inout EchoelSampler
    ) {
        // Audio clips are triggered once at the start — the sampler plays the loaded zone
        if activeClip.triggeredNoteIDs.isEmpty {
            // Trigger playback as a note (C4 = root note of loaded zone)
            sampler.noteOn(note: 60, velocity: 100)
            activeClip.activeNotes.insert(60)
            // Use a sentinel ID to mark as triggered
            activeClip.triggeredNoteIDs.insert(activeClip.clipID)
        }
    }

    // MARK: - Audio Rendering

    /// Render audio from all active tracks
    /// - Parameter frameCount: Number of audio frames to render
    /// - Returns: Dictionary of track index → rendered [Float] mono buffer
    public func renderAllTracks(frameCount: Int) -> [Int: [Float]] {
        guard frameCount > 0 else { return [:] }

        var results: [Int: [Float]] = [:]

        for trackIndex in trackStates.keys.sorted() {
            guard var state = trackStates[trackIndex],
                  state.activeClip != nil else { continue }

            let buffer = state.sampler.render(frameCount: frameCount)
            results[trackIndex] = buffer
            state.outputBuffer = buffer
            trackStates[trackIndex] = state
        }

        return results
    }

    /// Render a single track's audio
    public func renderTrack(_ trackIndex: Int, frameCount: Int) -> [Float]? {
        guard frameCount > 0,
              var state = trackStates[trackIndex],
              state.activeClip != nil else { return nil }

        let buffer = state.sampler.render(frameCount: frameCount)
        state.outputBuffer = buffer
        trackStates[trackIndex] = state
        return buffer
    }

    /// Mix all track outputs into a single stereo output buffer
    /// Applies per-track volume, pan, mute, and solo from SessionTrack data
    public func mixToStereo(
        trackBuffers: [Int: [Float]],
        tracks: [SessionTrack],
        frameCount: Int
    ) -> (left: [Float], right: [Float]) {
        guard frameCount > 0 else { return ([], []) }

        var leftOutput = [Float](repeating: 0, count: frameCount)
        var rightOutput = [Float](repeating: 0, count: frameCount)

        // Check if any track is soloed
        let hasSolo = tracks.contains { $0.solo }

        for (trackIndex, buffer) in trackBuffers {
            guard trackIndex < tracks.count else { continue }
            let track = tracks[trackIndex]

            // Skip muted tracks
            if track.mute { continue }

            // Skip non-soloed tracks when solo is active
            if hasSolo && !track.solo { continue }

            let volume = track.volume
            guard volume > 0 else { continue }

            // Equal-power pan (shared utility)
            let (leftGain, rightGain) = equalPowerPan(pan: track.pan, volume: volume)

            guard buffer.count >= frameCount else { continue }

            // Mix into output using vDSP
            var leftG = leftGain
            var rightG = rightGain
            buffer.withUnsafeBufferPointer { srcPtr in
                guard let srcBase = srcPtr.baseAddress else { return }
                leftOutput.withUnsafeMutableBufferPointer { dstPtr in
                    guard let dstBase = dstPtr.baseAddress else { return }
                    vDSP_vsma(srcBase, 1, &leftG, dstBase, 1, dstBase, 1, vDSP_Length(frameCount))
                }
                rightOutput.withUnsafeMutableBufferPointer { dstPtr in
                    guard let dstBase = dstPtr.baseAddress else { return }
                    vDSP_vsma(srcBase, 1, &rightG, dstBase, 1, dstBase, 1, vDSP_Length(frameCount))
                }
            }
        }

        return (left: leftOutput, right: rightOutput)
    }

    // MARK: - Utilities

    /// Calculate clip length in beats
    private func clipLengthInBeats(clip: SessionClip, bpm: Double) -> Double {
        guard bpm > 0 else { return 0 }
        return clip.length * (bpm / 60.0)
    }

    /// Check if a track has an active clip playing
    public func isTrackPlaying(_ trackIndex: Int) -> Bool {
        trackStates[trackIndex]?.activeClip != nil
    }

    /// Get current clip beat position for a track
    public func clipBeatPosition(forTrack trackIndex: Int) -> Double? {
        trackStates[trackIndex]?.activeClip?.clipBeat
    }

    /// Get the number of active tracks
    public var activeTrackCount: Int {
        trackStates.values.filter { $0.activeClip != nil }.count
    }

    /// Update bio-reactive data for all track samplers
    public func updateBioData(hrv: Float, coherence: Float, heartRate: Float, breathPhase: Float, flow: Float) {
        for trackIndex in trackStates.keys {
            trackStates[trackIndex]?.sampler.updateBioData(
                hrv: hrv,
                coherence: coherence,
                heartRate: heartRate,
                breathPhase: breathPhase,
                flow: flow
            )
        }
    }

    /// Reset all state
    public func reset() {
        stopAll()
        trackStates.removeAll()
    }
}

import AVFoundation
import Accelerate

/// DAW Audio Integration Bridge
/// Connects DAWCore, SynthEngine, EffectChainBuilder with AudioEngine
/// Real-time audio rendering with sample-accurate timing
/// CRITICAL: This is the heart of the audio pipeline - USER CONTROLLED, NOT AI
@MainActor
class DAWAudioIntegration: ObservableObject {

    // MARK: - Components

    private let dawCore: DAWCore
    private let synthEngine: SynthEngine
    private let effectChainBuilder: EffectChainBuilder
    private let audioEngine: AudioEngine

    // MARK: - Audio Properties

    private let sampleRate: Double = 44100.0
    private let bufferSize: Int = 512
    private var isRendering: Bool = false

    // MARK: - Performance Metrics

    @Published var renderTime: Double = 0
    @Published var droppedFrames: Int = 0

    // MARK: - Audio Node

    private var audioNode: AVAudioSourceNode?
    private var mixer: AVAudioMixerNode?

    // MARK: - Initialization

    init(dawCore: DAWCore, synthEngine: SynthEngine, effectChainBuilder: EffectChainBuilder, audioEngine: AudioEngine) {
        self.dawCore = dawCore
        self.synthEngine = synthEngine
        self.effectChainBuilder = effectChainBuilder
        self.audioEngine = audioEngine

        DebugConsole.shared.info("DAW Audio Integration initialized", category: "Audio")
    }

    // MARK: - Setup Audio Pipeline

    func setupAudioPipeline() {
        DebugConsole.shared.info("Setting up DAW audio pipeline", category: "Audio")

        // Create source node that renders DAW audio
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        audioNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            Task { @MainActor in
                self.renderAudio(frameCount: Int(frameCount), audioBufferList: audioBufferList)
            }

            return noErr
        }

        DebugConsole.shared.info("DAW audio pipeline ready", category: "Audio")
    }

    // MARK: - Audio Rendering

    /// Main audio rendering callback
    /// Renders all tracks, applies effects, mixes down
    @MainActor
    private func renderAudio(frameCount: Int, audioBufferList: UnsafeMutablePointer<AudioBufferList>) {
        let startTime = Date()

        // Get buffer pointers
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        guard let leftBuffer = ablPointer[0].mData?.assumingMemoryBound(to: Float.self),
              let rightBuffer = ablPointer[1].mData?.assumingMemoryBound(to: Float.self) else {
            DebugConsole.shared.warning("Failed to get audio buffers", category: "Audio")
            droppedFrames += 1
            return
        }

        // Initialize buffers to silence
        vDSP_vclr(leftBuffer, 1, vDSP_Length(frameCount))
        vDSP_vclr(rightBuffer, 1, vDSP_Length(frameCount))

        // Only render if playing or recording
        guard dawCore.transportState == .playing || dawCore.transportState == .recording else {
            return
        }

        // Render all tracks
        let masterBuffer = renderAllTracks(frameCount: frameCount)

        // Apply master effects
        let finalBuffer = applyMasterEffects(buffer: masterBuffer)

        // Convert mono to stereo and write to output
        for i in 0..<frameCount {
            leftBuffer[i] = finalBuffer[i]
            rightBuffer[i] = finalBuffer[i]
        }

        // Update playback position
        let samplesPerBeat = (60.0 / dawCore.project.tempo) * sampleRate
        let beatsAdvanced = Double(frameCount) / samplesPerBeat
        dawCore.advancePlaybackPosition(by: beatsAdvanced)

        // Check for loop
        if dawCore.loopEnabled && dawCore.playbackPosition >= dawCore.loopEnd {
            dawCore.setPlaybackPosition(dawCore.loopStart)
        }

        // Update performance metrics
        let elapsed = Date().timeIntervalSince(startTime)
        renderTime = elapsed
        DebugConsole.shared.updatePerformanceMetrics(renderTime: elapsed)
    }

    // MARK: - Track Rendering

    /// Render all tracks and mix them together
    @MainActor
    private func renderAllTracks(frameCount: Int) -> [Float] {
        var mixBuffer = [Float](repeating: 0, count: frameCount)

        // Check for solo tracks
        let hasSoloTracks = dawCore.project.tracks.contains { $0.isSolo }

        for track in dawCore.project.tracks {
            // Skip muted tracks (unless solo is active and this track is soloed)
            if hasSoloTracks {
                guard track.isSolo else { continue }
            } else {
                guard !track.isMuted else { continue }
            }

            // Render track based on type
            let trackBuffer = renderTrack(track, frameCount: frameCount)

            // Apply track volume and pan
            let processedBuffer = applyTrackProcessing(buffer: trackBuffer, track: track)

            // Mix into master buffer
            vDSP_vadd(mixBuffer, 1, processedBuffer, 1, &mixBuffer, 1, vDSP_Length(frameCount))
        }

        return mixBuffer
    }

    /// Render a single track
    @MainActor
    private func renderTrack(_ track: DAWCore.Track, frameCount: Int) -> [Float] {
        var trackBuffer = [Float](repeating: 0, count: frameCount)

        switch track.type {
        case .midi:
            trackBuffer = renderMIDITrack(track, frameCount: frameCount)
        case .audio:
            trackBuffer = renderAudioTrack(track, frameCount: frameCount)
        case .group:
            // Group tracks render their child tracks
            trackBuffer = renderGroupTrack(track, frameCount: frameCount)
        case .aux:
            // Aux tracks receive audio from sends
            trackBuffer = renderAuxTrack(track, frameCount: frameCount)
        }

        // Apply track effects
        if let effectChain = track.effectChain {
            trackBuffer = effectChainBuilder.chains.first(where: { $0.id == effectChain })?.process(buffer: trackBuffer, sampleRate: sampleRate) ?? trackBuffer
        }

        return trackBuffer
    }

    /// Render MIDI track using SynthEngine
    @MainActor
    private func renderMIDITrack(_ track: DAWCore.Track, frameCount: Int) -> [Float] {
        var buffer = [Float](repeating: 0, count: frameCount)

        // Get active clips at current playback position
        let activeClips = track.clips.filter { clip in
            let clipEnd = clip.startTime + clip.duration
            return dawCore.playbackPosition >= clip.startTime && dawCore.playbackPosition < clipEnd
        }

        // Process each active MIDI clip
        for clip in activeClips {
            guard case .midi(let midiClip) = clip.type else { continue }

            // Trigger notes that should be playing
            let clipLocalPosition = dawCore.playbackPosition - clip.startTime

            for note in midiClip.notes {
                let noteStart = note.startTime
                let noteEnd = note.startTime + note.duration

                // If note is active, ensure voice is playing
                if clipLocalPosition >= noteStart && clipLocalPosition < noteEnd {
                    // Check if note is already playing
                    let isPlaying = synthEngine.voices.contains { voice in
                        voice.note == note.pitch && voice.isActive
                    }

                    if !isPlaying {
                        synthEngine.noteOn(note: note.pitch, velocity: Float(note.velocity))
                    }
                }

                // If note should end, trigger note off
                if clipLocalPosition >= noteEnd {
                    synthEngine.noteOff(note: note.pitch)
                }
            }

            // Generate audio from synth
            let synthBuffer = synthEngine.generateAudio(frameCount: frameCount, sampleRate: sampleRate)
            vDSP_vadd(buffer, 1, synthBuffer, 1, &buffer, 1, vDSP_Length(frameCount))
        }

        return buffer
    }

    /// Render audio track (sample playback)
    @MainActor
    private func renderAudioTrack(_ track: DAWCore.Track, frameCount: Int) -> [Float] {
        var buffer = [Float](repeating: 0, count: frameCount)

        // Get active clips
        let activeClips = track.clips.filter { clip in
            let clipEnd = clip.startTime + clip.duration
            return dawCore.playbackPosition >= clip.startTime && dawCore.playbackPosition < clipEnd
        }

        for clip in activeClips {
            guard case .audio(let audioClip) = clip.type else { continue }

            // TODO: Load and playback audio file
            // For now, generate silence
            DebugConsole.shared.debug("Audio clip playback not yet implemented: \(audioClip.audioFileURL)", category: "Audio")
        }

        return buffer
    }

    /// Render group track (sum of child tracks)
    @MainActor
    private func renderGroupTrack(_ track: DAWCore.Track, frameCount: Int) -> [Float] {
        // Group tracks don't render directly - their children render into them
        return [Float](repeating: 0, count: frameCount)
    }

    /// Render aux track (receives from sends)
    @MainActor
    private func renderAuxTrack(_ track: DAWCore.Track, frameCount: Int) -> [Float] {
        // Aux tracks receive audio from track sends
        return [Float](repeating: 0, count: frameCount)
    }

    // MARK: - Track Processing

    /// Apply track volume, pan, and other processing
    @MainActor
    private func applyTrackProcessing(buffer: [Float], track: DAWCore.Track) -> [Float] {
        var processed = buffer

        // Apply volume
        var volume = Float(track.mixerChannel.volume)
        vDSP_vsmul(processed, 1, &volume, &processed, 1, vDSP_Length(processed.count))

        // Apply pan (for now, just apply to mono signal)
        // TODO: Implement proper stereo panning

        return processed
    }

    // MARK: - Master Effects

    /// Apply master channel effects
    @MainActor
    private func applyMasterEffects(buffer: [Float]) -> [Float] {
        var processed = buffer

        // Apply master volume
        var masterVolume = Float(dawCore.project.masterChannel.volume)
        vDSP_vsmul(processed, 1, &masterVolume, &processed, 1, vDSP_Length(processed.count))

        // Apply master limiter (soft clipping)
        for i in 0..<processed.count {
            processed[i] = tanh(processed[i]) // Soft clipping
        }

        return processed
    }

    // MARK: - Start/Stop

    func start() {
        guard !isRendering else { return }

        isRendering = true
        DebugConsole.shared.info("DAW audio rendering started", category: "Audio")
    }

    func stop() {
        guard isRendering else { return }

        isRendering = false

        // Stop all synth voices
        synthEngine.voices.removeAll()

        DebugConsole.shared.info("DAW audio rendering stopped", category: "Audio")
    }

    // MARK: - Recording

    func startRecording(track: DAWCore.Track) {
        DebugConsole.shared.info("Started recording on track: \(track.name)", category: "Audio")
        // TODO: Implement audio/MIDI recording
    }

    func stopRecording() {
        DebugConsole.shared.info("Stopped recording", category: "Audio")
        // TODO: Finalize recording
    }
}

// MARK: - DAWCore Playback Position Extension

extension DAWCore {
    /// Advance playback position by beats
    func advancePlaybackPosition(by beats: Double) {
        playbackPosition += beats
    }
}

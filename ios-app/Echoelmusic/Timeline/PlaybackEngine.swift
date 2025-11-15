// PlaybackEngine.swift
// Timeline Playback Engine
//
// Sample-accurate playback engine for Timeline (Audio + MIDI + Video sync)

import Foundation
import AVFoundation
import Combine

/// Playback state
enum PlaybackState: String {
    case stopped
    case playing
    case paused
    case recording
}

/// Playback engine for Timeline
@MainActor
class PlaybackEngine: ObservableObject {

    // MARK: - Published Properties

    /// Current playback state
    @Published var state: PlaybackState = .stopped

    /// Current playhead position (samples)
    @Published var playheadPosition: Int64 = 0

    /// Is looping enabled
    @Published var isLooping: Bool = false

    /// Loop start position (samples)
    @Published var loopStart: Int64 = 0

    /// Loop end position (samples)
    @Published var loopEnd: Int64 = 0

    /// Transport tempo (BPM)
    @Published var tempo: Double = 120.0


    // MARK: - Private Properties

    /// The timeline being played
    private weak var timeline: Timeline?

    /// Audio engine for playback
    private let audioEngine: AVAudioEngine

    /// Source node (generates audio from timeline)
    private var sourceNode: AVAudioSourceNode?

    /// Main mixer node
    private let mixerNode: AVAudioMixerNode

    /// Audio format (48kHz, stereo)
    private let audioFormat: AVAudioFormat

    /// Sample rate
    private let sampleRate: Double = 48000.0

    /// Buffer size
    private let bufferSize: AVAudioFrameCount = 512

    /// Is engine running
    private var isEngineRunning: Bool = false

    /// Playback timer (for UI updates)
    private var displayTimer: Timer?

    /// Recording buffer (if recording)
    private var recordingBuffer: AVAudioPCMBuffer?

    /// Cancellables for Combine
    private var cancellables = Set<AnyCancellable>()


    // MARK: - Initialization

    init(timeline: Timeline) {
        self.timeline = timeline
        self.audioEngine = AVAudioEngine()
        self.mixerNode = audioEngine.mainMixerNode

        // Setup audio format (48kHz stereo)
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        ) else {
            fatalError("Failed to create audio format")
        }
        self.audioFormat = format

        setupAudioEngine()
    }


    // MARK: - Audio Engine Setup

    private func setupAudioEngine() {
        // Create source node that renders timeline
        let sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            // Only render if playing
            guard self.state == .playing || self.state == .recording else {
                // Silence
                self.fillSilence(audioBufferList, frameCount: frameCount)
                return noErr
            }

            // Render timeline audio
            self.renderTimeline(audioBufferList, frameCount: frameCount)

            return noErr
        }

        self.sourceNode = sourceNode

        // Attach nodes
        audioEngine.attach(sourceNode)

        // Connect: SourceNode → Mixer → Output
        audioEngine.connect(
            sourceNode,
            to: mixerNode,
            format: audioFormat
        )

        audioEngine.connect(
            mixerNode,
            to: audioEngine.outputNode,
            format: audioFormat
        )

        // Prepare engine
        audioEngine.prepare()

        print("🎛️ PlaybackEngine initialized (48kHz, \(bufferSize) samples)")
    }


    // MARK: - Transport Controls

    /// Start playback
    func play() {
        guard state != .playing else { return }

        // Start audio engine if needed
        if !isEngineRunning {
            do {
                try audioEngine.start()
                isEngineRunning = true
            } catch {
                print("⚠️ Failed to start audio engine: \(error)")
                return
            }
        }

        state = .playing
        startDisplayTimer()

        print("▶️ Playback started at position \(playheadPosition)")
    }

    /// Pause playback
    func pause() {
        guard state == .playing else { return }

        state = .paused
        stopDisplayTimer()

        print("⏸️ Playback paused at position \(playheadPosition)")
    }

    /// Stop playback
    func stop() {
        guard state != .stopped else { return }

        state = .stopped
        playheadPosition = 0
        stopDisplayTimer()

        print("⏹️ Playback stopped")
    }

    /// Toggle play/pause
    func togglePlayPause() {
        if state == .playing {
            pause()
        } else {
            play()
        }
    }

    /// Start recording
    func record() {
        guard state != .recording else { return }

        // Start audio engine
        if !isEngineRunning {
            do {
                try audioEngine.start()
                isEngineRunning = true
            } catch {
                print("⚠️ Failed to start audio engine: \(error)")
                return
            }
        }

        state = .recording
        startDisplayTimer()

        // Prepare recording buffer
        recordingBuffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: AVAudioFrameCount(sampleRate * 60)  // 1 minute buffer
        )

        print("⏺️ Recording started")
    }

    /// Stop recording and create clip
    func stopRecording() -> Clip? {
        guard state == .recording else { return nil }

        state = .stopped
        stopDisplayTimer()

        // Create clip from recording buffer
        guard let buffer = recordingBuffer else { return nil }

        // TODO: Save buffer to file and create clip
        // For now, just return nil

        recordingBuffer = nil

        print("⏹️ Recording stopped")
        return nil
    }


    // MARK: - Playhead Control

    /// Seek to position (samples)
    func seek(to position: Int64) {
        playheadPosition = max(0, position)

        // Update timeline playhead
        timeline?.playheadPosition = playheadPosition
    }

    /// Seek to bar/beat
    func seek(to barBeat: BarBeat) {
        guard let timeline = timeline else { return }
        let position = timeline.barBeatToSamples(barBeat)
        seek(to: position)
    }

    /// Skip forward (1 bar)
    func skipForward() {
        guard let timeline = timeline else { return }

        let currentBarBeat = timeline.samplesToBarBeat(playheadPosition)
        let nextBar = BarBeat(
            bar: currentBarBeat.bar + 1,
            beat: 1,
            subdivision: 0
        )

        seek(to: nextBar)
    }

    /// Skip backward (1 bar)
    func skipBackward() {
        guard let timeline = timeline else { return }

        let currentBarBeat = timeline.samplesToBarBeat(playheadPosition)
        let prevBar = BarBeat(
            bar: max(1, currentBarBeat.bar - 1),
            beat: 1,
            subdivision: 0
        )

        seek(to: prevBar)
    }


    // MARK: - Loop Control

    /// Set loop region
    func setLoop(start: Int64, end: Int64) {
        guard start < end else { return }

        loopStart = start
        loopEnd = end
        isLooping = true

        print("🔁 Loop set: \(start) - \(end)")
    }

    /// Clear loop
    func clearLoop() {
        isLooping = false
        loopStart = 0
        loopEnd = 0

        print("🔁 Loop cleared")
    }


    // MARK: - Audio Rendering

    /// Render timeline audio for current playhead position
    private func renderTimeline(_ audioBufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: AVAudioFrameCount) {
        guard let timeline = timeline else {
            fillSilence(audioBufferList, frameCount: frameCount)
            return
        }

        // Create mix buffer
        guard let mixBuffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: frameCount
        ) else {
            fillSilence(audioBufferList, frameCount: frameCount)
            return
        }

        mixBuffer.frameLength = frameCount

        // Clear mix buffer
        clearBuffer(mixBuffer)

        // Render each track
        for track in timeline.tracks {
            guard !track.isMuted else { continue }

            // Skip soloed tracks if any track is soloed
            let hasSoloedTracks = timeline.tracks.contains { $0.isSoloed }
            if hasSoloedTracks && !track.isSoloed {
                continue
            }

            // Render track audio
            if let trackBuffer = track.render(at: playheadPosition, frameCount: frameCount) {
                // Mix into main buffer
                mixBuffers(mixBuffer, trackBuffer)
            }
        }

        // Copy mix buffer to output
        copyBuffer(from: mixBuffer, to: audioBufferList)

        // Advance playhead
        advancePlayhead(by: Int64(frameCount))

        // Record if in recording mode
        if state == .recording {
            recordAudio(mixBuffer)
        }
    }

    /// Advance playhead by frame count
    private func advancePlayhead(by frameCount: Int64) {
        playheadPosition += frameCount

        // Handle looping
        if isLooping && playheadPosition >= loopEnd {
            playheadPosition = loopStart
        }

        // Update timeline
        timeline?.playheadPosition = playheadPosition
    }

    /// Fill buffer with silence
    private func fillSilence(_ audioBufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: AVAudioFrameCount) {
        let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)

        for buffer in bufferList {
            memset(buffer.mData, 0, Int(buffer.mDataByteSize))
        }
    }

    /// Clear PCM buffer
    private func clearBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0..<channelCount {
            var samples = channelData[channel]
            memset(samples, 0, frameLength * MemoryLayout<Float>.size)
        }
    }

    /// Mix two buffers together (additive)
    private func mixBuffers(_ destination: AVAudioPCMBuffer, _ source: AVAudioPCMBuffer) {
        guard let destData = destination.floatChannelData,
              let srcData = source.floatChannelData else { return }

        let frameCount = min(Int(destination.frameLength), Int(source.frameLength))
        let channelCount = min(
            Int(destination.format.channelCount),
            Int(source.format.channelCount)
        )

        for channel in 0..<channelCount {
            var dest = destData[channel]
            let src = srcData[channel]

            for frame in 0..<frameCount {
                dest[frame] += src[frame]
            }
        }
    }

    /// Copy buffer to AudioBufferList
    private func copyBuffer(from buffer: AVAudioPCMBuffer, to audioBufferList: UnsafeMutablePointer<AudioBufferList>) {
        guard let channelData = buffer.floatChannelData else { return }

        let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for (index, audioBuffer) in bufferList.enumerated() {
            guard index < channelCount else { break }

            let samples = channelData[index]
            let destPtr = audioBuffer.mData?.assumingMemoryBound(to: Float.self)

            memcpy(destPtr, samples, frameCount * MemoryLayout<Float>.size)
        }
    }

    /// Record audio to buffer
    private func recordAudio(_ buffer: AVAudioPCMBuffer) {
        guard let recordingBuffer = recordingBuffer else { return }
        guard let recordData = recordingBuffer.floatChannelData,
              let sourceData = buffer.floatChannelData else { return }

        let frameCount = Int(buffer.frameLength)
        let channelCount = min(
            Int(recordingBuffer.format.channelCount),
            Int(buffer.format.channelCount)
        )

        let currentFrame = Int(recordingBuffer.frameLength)
        let capacity = Int(recordingBuffer.frameCapacity)

        // Check if we have space
        guard currentFrame + frameCount < capacity else { return }

        // Copy samples
        for channel in 0..<channelCount {
            let dest = recordData[channel].advanced(by: currentFrame)
            let src = sourceData[channel]

            memcpy(dest, src, frameCount * MemoryLayout<Float>.size)
        }

        // Update frame length
        recordingBuffer.frameLength += AVAudioFrameCount(frameCount)
    }


    // MARK: - Display Timer

    /// Start display timer (for UI updates at 30 Hz)
    private func startDisplayTimer() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Trigger UI update (playheadPosition is @Published)
            Task { @MainActor in
                self.objectWillChange.send()
            }
        }
    }

    /// Stop display timer
    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }


    // MARK: - Cleanup

    deinit {
        stop()

        if isEngineRunning {
            audioEngine.stop()
        }

        displayTimer?.invalidate()
    }
}


// MARK: - Extensions

extension PlaybackEngine {
    /// Get current time in seconds
    var currentTimeSeconds: Double {
        Double(playheadPosition) / sampleRate
    }

    /// Get current bar/beat
    var currentBarBeat: BarBeat? {
        timeline?.samplesToBarBeat(playheadPosition)
    }

    /// Get formatted time string (MM:SS.mmm)
    var timeString: String {
        let seconds = currentTimeSeconds
        let minutes = Int(seconds / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)

        return String(format: "%02d:%02d.%03d", minutes, secs, ms)
    }

    /// Get formatted bar/beat string
    var barBeatString: String {
        guard let barBeat = currentBarBeat else { return "1.1.0" }
        return "\(barBeat.bar).\(barBeat.beat).\(barBeat.subdivision)"
    }
}

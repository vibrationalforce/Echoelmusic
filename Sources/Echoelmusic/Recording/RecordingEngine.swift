import Foundation
import AVFoundation
import Combine
import Accelerate

// MARK: - Circular Buffer for O(1) Performance
/// High-performance circular buffer replacing Array.removeFirst() O(n) with O(1)
private struct RecordingCircularBuffer<T> {
    private var buffer: [T]
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private(set) var count: Int = 0
    let capacity: Int

    init(capacity: Int, defaultValue: T) {
        self.capacity = capacity
        self.buffer = [T](repeating: defaultValue, count: capacity)
    }

    mutating func append(_ element: T) {
        buffer[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        if count < capacity {
            count += 1
        } else {
            // Buffer is full, advance read index (oldest element is overwritten)
            readIndex = (readIndex + 1) % capacity
        }
    }

    /// Returns contents in order (oldest to newest)
    func toArray() -> [T] {
        guard count > 0 else { return [] }
        var result = [T]()
        result.reserveCapacity(count)
        for i in 0..<count {
            result.append(buffer[(readIndex + i) % capacity])
        }
        return result
    }

    mutating func removeAll() {
        writeIndex = 0
        readIndex = 0
        count = 0
    }
}

/// Manages multi-track audio recording with bio-signal integration
/// Coordinates recording, playback, and real-time monitoring
@MainActor
class RecordingEngine: ObservableObject {

    // MARK: - Published Properties

    /// Current session being recorded/played
    @Published var currentSession: Session?

    // MARK: - Undo/Redo Integration
    private let undoManager = UndoRedoManager.shared

    /// Is currently recording
    @Published var isRecording: Bool = false

    /// Is currently playing back
    @Published var isPlaying: Bool = false

    /// Current playback/recording position (seconds)
    @Published var currentTime: TimeInterval = 0.0

    /// Recording level (0.0 - 1.0)
    @Published var recordingLevel: Float = 0.0

    /// Real-time waveform data for current recording
    @Published var recordingWaveform: [Float] = []

    /// Current track being recorded
    @Published var currentTrackID: UUID?


    // MARK: - Private Properties

    /// Audio engine for recording/playback
    private var audioEngine: AVAudioEngine?

    /// Input node for recording
    private var inputNode: AVAudioInputNode?

    /// Audio file for current recording
    private var audioFile: AVAudioFile?

    /// Timer for position updates
    private var timer: Timer?

    /// Waveform buffer for real-time display (max 1000 samples)
    /// Uses CircularBuffer for O(1) append instead of Array.removeFirst() O(n)
    private var waveformBuffer = RecordingCircularBuffer<Float>(capacity: 1000, defaultValue: 0.0)

    /// Reference to main audio engine for audio routing
    private weak var mainAudioEngine: AudioEngine?

    /// Directory for storing session files
    private let sessionsDirectory: URL

    /// Maximum recording duration (seconds)
    private let maxDuration: TimeInterval = 3600 // 1 hour

    /// Audio format for recording
    private let recordingFormat: AVAudioFormat

    // MARK: - Retrospective Capture (Ableton-style)

    /// Enable/disable retrospective capture
    @Published var isRetrospectiveCaptureEnabled: Bool = true

    /// Duration of retrospective buffer (seconds) - configurable for mobile
    private let retrospectiveBufferDuration: TimeInterval = 60.0

    /// Retrospective audio buffer (circular, O(1) operations)
    private var retrospectiveBuffer: RetrospectiveBuffer?

    /// Whether there's content available to capture
    @Published var hasRetrospectiveContent: Bool = false


    // MARK: - Initialization

    init() {
        // Setup sessions directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.sessionsDirectory = documentsPath.appendingPathComponent("Sessions", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

        // Setup recording format (48kHz, stereo, float32)
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 2,
            interleaved: false
        ) else {
            log.recording("❌ Failed to create recording format - using fallback", level: .error)
            // Fallback to standard format
            if let fallback48 = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2) {
                self.recordingFormat = fallback48
            } else if let fallback44 = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2) {
                self.recordingFormat = fallback44
            } else {
                log.recording("❌ Cannot create any audio format", level: .error)
                self.recordingFormat = AVAudioFormat()
            }
            return
        }
        self.recordingFormat = format

        log.recording("📁 Recording engine initialized")
        log.recording("   Sessions directory: \(sessionsDirectory.path)")
    }


    // MARK: - Audio Engine Connection

    /// Connect to main audio engine for audio routing
    func connectAudioEngine(_ audioEngine: AudioEngine) {
        self.mainAudioEngine = audioEngine
        log.recording("🔌 Connected to main audio engine")
    }


    // MARK: - Session Management

    /// Create new recording session
    func createSession(name: String, template: Session.SessionTemplate = .custom) -> Session {
        var session: Session

        switch template {
        case .meditation:
            session = Session.meditationTemplate()
        case .healing:
            session = Session.healingTemplate()
        case .creative:
            session = Session.creativeTemplate()
        case .custom:
            session = Session(name: name)
        }

        session.name = name
        currentSession = session

        log.recording("🎵 Created session: \(name)")
        return session
    }

    /// Load existing session
    func loadSession(id: UUID) throws {
        let session = try Session.load(id: id)
        currentSession = session
        log.recording("📂 Loaded session: \(session.name)")
    }

    /// Save current session
    func saveSession() throws {
        guard let session = currentSession else {
            throw RecordingError.noActiveSession
        }

        try session.save()
        log.recording("💾 Saved session: \(session.name)")
    }


    // MARK: - Recording Control

    /// Start recording a new track
    func startRecording(trackType: Track.TrackType = .audio) throws {
        guard !isRecording else {
            throw RecordingError.alreadyRecording
        }

        guard var session = currentSession else {
            throw RecordingError.noActiveSession
        }

        // Create new track
        var track = Track(
            name: "Track \(session.tracks.count + 1)",
            type: trackType
        )

        // Setup audio file for recording
        let trackURL = trackFileURL(sessionID: session.id, trackID: track.id)
        audioFile = try AVAudioFile(
            forWriting: trackURL,
            settings: recordingFormat.settings,
            commonFormat: recordingFormat.commonFormat,
            interleaved: recordingFormat.isInterleaved
        )

        track.url = trackURL
        currentTrackID = track.id

        // Add track to session
        session.tracks.append(track)
        currentSession = session

        // Setup audio engine for recording
        try setupAudioRecording()

        isRecording = true
        currentTime = 0.0
        waveformBuffer.removeAll()
        recordingWaveform.removeAll()

        // Start timer for position updates
        startTimer()

        log.recording("🔴 Started recording: \(track.name)")
    }

    /// Setup audio engine tap for recording
    private func setupAudioRecording() throws {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        inputNode = engine.inputNode
        guard let input = inputNode else { return }

        let inputFormat = input.outputFormat(forBus: 0)

        // Install tap to capture audio data
        // Reduced from 4096 to 1024 for lower latency (85ms → 21ms at 48kHz)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            Task { @MainActor [weak self] in
                self?.processRecordingBuffer(buffer)
            }
        }

        try engine.start()
        log.recording("🎙️ Audio recording engine started")
    }

    /// Process incoming audio buffer during recording
    private func processRecordingBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let channelDataValue = channelData.pointee

        // Calculate RMS for level meter
        var sum: Float = 0.0
        vDSP_sve(channelDataValue, 1, &sum, vDSP_Length(frameLength))

        var sumSquares: Float = 0.0
        vDSP_svesq(channelDataValue, 1, &sumSquares, vDSP_Length(frameLength))

        let rms = sqrt(sumSquares / Float(frameLength))
        recordingLevel = min(rms * 10.0, 1.0) // Normalize and clamp

        // Write to audio file
        if let file = audioFile {
            do {
                try file.write(from: buffer)
            } catch {
                log.error("Failed to write audio buffer to recording file: \(error)")
            }
        }

        // Update waveform buffer for real-time display
        updateWaveformBuffer(channelDataValue, frameLength: frameLength)
    }

    /// Update waveform buffer for real-time visualization
    /// PERFORMANCE: Uses O(1) CircularBuffer instead of O(n) removeFirst()
    private func updateWaveformBuffer(_ data: UnsafePointer<Float>, frameLength: Int) {
        // Downsample to fit in circular buffer
        let strideValue = max(1, frameLength / waveformBuffer.capacity)

        for i in Swift.stride(from: 0, to: frameLength, by: strideValue) {
            waveformBuffer.append(data[i])
        }

        // Update published waveform (converts circular buffer to array)
        recordingWaveform = waveformBuffer.toArray()
    }

    /// Stop recording current track
    func stopRecording() throws {
        guard isRecording else { return }

        // Stop audio engine
        if let engine = audioEngine, let input = inputNode {
            input.removeTap(onBus: 0)
            engine.stop()
        }

        isRecording = false
        stopTimer()

        // Update track duration
        if var session = currentSession,
           let lastTrackIndex = session.tracks.indices.last,
           let url = session.tracks[lastTrackIndex].url {

            session.tracks[lastTrackIndex].duration = currentTime
            session.duration = max(session.duration, currentTime)

            // Generate waveform for visualization
            session.tracks[lastTrackIndex].generateWaveform()

            currentSession = session
        }

        audioFile = nil
        audioEngine = nil
        inputNode = nil
        currentTime = 0.0
        recordingLevel = 0.0
        currentTrackID = nil

        log.recording("⏹️ Stopped recording")
    }


    // MARK: - Playback Control

    /// Start playback of current session
    func startPlayback() throws {
        guard !isPlaying else {
            throw RecordingError.alreadyPlaying
        }

        guard let session = currentSession else {
            throw RecordingError.noActiveSession
        }

        isPlaying = true
        startTimer()

        log.recording("▶️ Started playback: \(session.name)")
    }

    /// Stop playback
    func stopPlayback() {
        isPlaying = false
        stopTimer()
        currentTime = 0.0

        log.recording("⏹️ Stopped playback")
    }

    /// Pause playback
    func pausePlayback() {
        isPlaying = false
        stopTimer()

        log.recording("⏸️ Paused playback at \(currentTime)s")
    }

    /// Seek to position
    func seek(to time: TimeInterval) {
        guard let session = currentSession else { return }

        currentTime = max(0, min(time, session.duration))
        log.recording("⏩ Seeked to \(currentTime)s")
    }


    // MARK: - Track Management

    /// Add bio-data point to current session
    func addBioDataPoint(
        hrv: Double,
        heartRate: Double,
        coherence: Double,
        audioLevel: Float,
        frequency: Float
    ) {
        guard var session = currentSession, isRecording else { return }

        let dataPoint = BioDataPoint(
            timestamp: currentTime,
            hrv: hrv,
            heartRate: heartRate,
            coherence: coherence,
            audioLevel: audioLevel,
            frequency: frequency
        )

        session.bioData.append(dataPoint)
        currentSession = session
    }

    /// Mute/unmute track (undoable)
    func setTrackMuted(_ trackID: UUID, muted: Bool) {
        guard var session = currentSession else { return }
        guard let index = session.tracks.firstIndex(where: { $0.id == trackID }) else { return }

        let oldValue = session.tracks[index].isMuted
        guard oldValue != muted else { return }

        let command = TrackMuteCommand(
            trackID: trackID,
            isMuted: muted,
            applyChange: { [weak self] id, value in
                guard var session = self?.currentSession,
                      let idx = session.tracks.firstIndex(where: { $0.id == id }) else { return }
                session.tracks[idx].isMuted = value
                self?.currentSession = session
            }
        )

        undoManager.execute(command)
    }

    /// Solo track (undoable)
    func setTrackSoloed(_ trackID: UUID, soloed: Bool) {
        guard var session = currentSession else { return }
        guard let index = session.tracks.firstIndex(where: { $0.id == trackID }) else { return }

        let oldValue = session.tracks[index].isSoloed

        let command = GenericTrackCommand(
            actionName: soloed ? "Solo Track" : "Unsolo Track",
            trackID: trackID,
            execute: { [weak self] in
                guard var session = self?.currentSession,
                      let idx = session.tracks.firstIndex(where: { $0.id == trackID }) else { return }
                session.tracks[idx].isSoloed = soloed
                self?.currentSession = session
            },
            undo: { [weak self] in
                guard var session = self?.currentSession,
                      let idx = session.tracks.firstIndex(where: { $0.id == trackID }) else { return }
                session.tracks[idx].isSoloed = oldValue
                self?.currentSession = session
            }
        )

        undoManager.execute(command)
    }

    /// Phase invert track polarity (undoable)
    func setTrackPhaseInvert(_ trackID: UUID, inverted: Bool) {
        guard var session = currentSession else { return }
        guard let index = session.tracks.firstIndex(where: { $0.id == trackID }) else { return }

        let oldValue = session.tracks[index].isPhaseInverted

        let command = GenericTrackCommand(
            actionName: inverted ? "Phase Invert" : "Phase Normal",
            trackID: trackID,
            execute: { [weak self] in
                guard var session = self?.currentSession,
                      let idx = session.tracks.firstIndex(where: { $0.id == trackID }) else { return }
                session.tracks[idx].isPhaseInverted = inverted
                self?.currentSession = session
            },
            undo: { [weak self] in
                guard var session = self?.currentSession,
                      let idx = session.tracks.firstIndex(where: { $0.id == trackID }) else { return }
                session.tracks[idx].isPhaseInverted = oldValue
                self?.currentSession = session
            }
        )

        undoManager.execute(command)
    }

    /// Set track volume (undoable)
    func setTrackVolume(_ trackID: UUID, volume: Float) {
        guard var session = currentSession else { return }
        guard let index = session.tracks.firstIndex(where: { $0.id == trackID }) else { return }

        let oldValue = session.tracks[index].volume
        let newValue = max(0, min(1, volume))

        let command = TrackVolumeCommand(
            trackID: trackID,
            oldValue: oldValue,
            newValue: newValue,
            applyChange: { [weak self] id, value in
                guard var session = self?.currentSession,
                      let idx = session.tracks.firstIndex(where: { $0.id == id }) else { return }
                session.tracks[idx].volume = value
                self?.currentSession = session
            }
        )

        undoManager.execute(command)
    }

    /// Set track pan (undoable)
    func setTrackPan(_ trackID: UUID, pan: Float) {
        guard var session = currentSession else { return }
        guard let index = session.tracks.firstIndex(where: { $0.id == trackID }) else { return }

        let oldValue = session.tracks[index].pan
        let newValue = max(-1, min(1, pan))

        let command = TrackPanCommand(
            trackID: trackID,
            oldValue: oldValue,
            newValue: newValue,
            applyChange: { [weak self] id, value in
                guard var session = self?.currentSession,
                      let idx = session.tracks.firstIndex(where: { $0.id == id }) else { return }
                session.tracks[idx].pan = value
                self?.currentSession = session
            }
        )

        undoManager.execute(command)
    }

    /// Delete track (undoable - file deletion is NOT undone for safety)
    func deleteTrack(_ trackID: UUID) throws {
        guard var session = currentSession else {
            throw RecordingError.noActiveSession
        }

        guard let index = session.tracks.firstIndex(where: { $0.id == trackID }) else {
            throw RecordingError.trackNotFound
        }

        let track = session.tracks[index]
        let trackIndex = index

        let command = DeleteTrackCommand(
            track: track,
            index: trackIndex,
            addTrack: { [weak self] restoredTrack, idx in
                guard var session = self?.currentSession else { return }
                session.tracks.insert(restoredTrack, at: min(idx, session.tracks.count))
                self?.currentSession = session
            },
            removeTrack: { [weak self] id in
                guard var session = self?.currentSession,
                      let idx = session.tracks.firstIndex(where: { $0.id == id }) else { return }
                // Note: We don't delete the audio file here to allow undo
                session.tracks.remove(at: idx)
                self?.currentSession = session
            }
        )

        undoManager.execute(command)
        log.recording("🗑️ Deleted track (undoable)")
    }

    // MARK: - Undo/Redo Convenience Methods

    /// Undo last action (Cmd+Z)
    func undo() {
        undoManager.undo()
    }

    /// Redo last undone action (Cmd+Shift+Z)
    func redo() {
        undoManager.redo()
    }

    /// Whether undo is available
    var canUndo: Bool {
        undoManager.canUndo
    }

    /// Whether redo is available
    var canRedo: Bool {
        undoManager.canRedo
    }


    // MARK: - Private Helpers

    /// Start position update timer
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePosition()
            }
        }
    }

    /// Stop position update timer
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Update playback/recording position
    private func updatePosition() {
        guard isRecording || isPlaying else { return }

        currentTime += 0.1

        // Stop at max duration
        if currentTime >= maxDuration && isRecording {
            try? stopRecording()
        }

        // Stop at session end
        if let session = currentSession, currentTime >= session.duration && isPlaying {
            stopPlayback()
        }
    }

    /// Generate track file URL
    private func trackFileURL(sessionID: UUID, trackID: UUID) -> URL {
        let sessionDir = sessionsDirectory.appendingPathComponent(sessionID.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        return sessionDir.appendingPathComponent("\(trackID.uuidString).caf")
    }
}


// MARK: - Retrospective Capture

extension RecordingEngine {

    /// Initialize retrospective buffer for always-on capture
    func enableRetrospectiveCapture(sampleRate: Double = 48000, channels: Int = 2) {
        guard isRetrospectiveCaptureEnabled else { return }

        let samplesNeeded = Int(sampleRate * retrospectiveBufferDuration) * channels
        retrospectiveBuffer = RetrospectiveBuffer(
            capacity: samplesNeeded,
            sampleRate: sampleRate,
            channels: channels
        )
        log.recording("📼 Retrospective capture enabled (\(Int(retrospectiveBufferDuration))s buffer)")
    }

    /// Feed audio to retrospective buffer (call from audio tap)
    func feedRetrospectiveBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRetrospectiveCaptureEnabled,
              !isRecording, // Don't buffer while actively recording
              let retrospective = retrospectiveBuffer,
              let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)

        // Interleave and add to circular buffer
        for frame in 0..<frameLength {
            for channel in 0..<Int(buffer.format.channelCount) {
                retrospective.append(channelData[channel][frame])
            }
        }

        // Update UI state
        if retrospective.count > Int(buffer.format.sampleRate) { // At least 1 second
            hasRetrospectiveContent = true
        }
    }

    /// Capture retrospective buffer as a new track (like Ableton's Capture)
    func captureRetrospective() throws {
        guard isRetrospectiveCaptureEnabled else {
            throw RecordingError.exportFailed("Retrospective capture not enabled")
        }

        guard let retrospective = retrospectiveBuffer, retrospective.count > 0 else {
            throw RecordingError.exportFailed("No retrospective content available")
        }

        guard var session = currentSession else {
            throw RecordingError.noActiveSession
        }

        // Create new track from buffer
        var track = Track(
            name: "Captured \(session.tracks.count + 1)",
            type: .audio
        )

        let trackURL = trackFileURL(sessionID: session.id, trackID: track.id)

        // Write buffer to file
        try retrospective.writeToFile(url: trackURL, format: recordingFormat)

        track.url = trackURL
        track.duration = retrospective.duration

        // Add track to session
        session.tracks.append(track)
        currentSession = session

        // Clear buffer after capture
        retrospective.clear()
        hasRetrospectiveContent = false

        log.recording("✨ Captured retrospective audio as '\(track.name)' (\(String(format: "%.1f", track.duration))s)")
    }

    /// Clear retrospective buffer without capturing
    func clearRetrospectiveBuffer() {
        retrospectiveBuffer?.clear()
        hasRetrospectiveContent = false
    }
}

// MARK: - Retrospective Buffer

/// Lightweight circular buffer for retrospective audio capture
/// O(1) append/read operations, fixed memory footprint
class RetrospectiveBuffer {
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private(set) var count: Int = 0
    let capacity: Int
    let sampleRate: Double
    let channels: Int

    var duration: TimeInterval {
        Double(count / channels) / sampleRate
    }

    init(capacity: Int, sampleRate: Double, channels: Int) {
        self.capacity = capacity
        self.sampleRate = sampleRate
        self.channels = channels
        self.buffer = [Float](repeating: 0, count: capacity)
    }

    func append(_ sample: Float) {
        buffer[writeIndex] = sample
        writeIndex = (writeIndex + 1) % capacity
        if count < capacity {
            count += 1
        }
    }

    func clear() {
        writeIndex = 0
        count = 0
    }

    /// Write buffer contents to audio file
    func writeToFile(url: URL, format: AVAudioFormat) throws {
        guard count > 0 else { return }

        let audioFile = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )

        let frameCount = AVAudioFrameCount(count / channels)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw RecordingError.exportFailed("Failed to create PCM buffer")
        }

        pcmBuffer.frameLength = frameCount

        guard let channelData = pcmBuffer.floatChannelData else {
            throw RecordingError.exportFailed("Failed to get channel data")
        }

        // De-interleave from circular buffer
        let startIndex = count < capacity ? 0 : writeIndex
        for i in 0..<Int(frameCount) {
            let bufferIndex = (startIndex + i * channels) % capacity
            for ch in 0..<channels {
                channelData[ch][i] = buffer[(bufferIndex + ch) % capacity]
            }
        }

        try audioFile.write(from: pcmBuffer)
    }
}

// MARK: - Recording Errors

enum RecordingError: LocalizedError {
    case noActiveSession
    case alreadyRecording
    case alreadyPlaying
    case trackNotFound
    case fileNotFound
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active recording session"
        case .alreadyRecording:
            return "Already recording"
        case .alreadyPlaying:
            return "Already playing"
        case .trackNotFound:
            return "Track not found"
        case .fileNotFound:
            return "Audio file not found"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        }
    }
}

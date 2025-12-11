// ThreadSafeActors.swift
// Echoelmusic - Thread-Safe Actor Architecture
// SPDX-License-Identifier: MIT
//
// Actor-based thread safety for all critical audio/MIDI/visual operations

import Foundation
import Combine

// MARK: - Thread-Safe Audio State

/// Actor managing all audio engine state thread-safely
public actor AudioEngineActor {

    public struct AudioState: Sendable {
        public var isRunning: Bool = false
        public var sampleRate: Double = 44100
        public var bufferSize: Int = 512
        public var inputChannels: Int = 2
        public var outputChannels: Int = 2
        public var latency: TimeInterval = 0.011 // ~512 samples at 44.1kHz
        public var cpuLoad: Double = 0.0
        public var peakLevel: Float = 0.0
    }

    private var state = AudioState()
    private var stateHistory: [AudioState] = []
    private let maxHistorySize = 100

    public init() {}

    // Safe getters
    public func getState() -> AudioState { state }
    public func isRunning() -> Bool { state.isRunning }
    public func getSampleRate() -> Double { state.sampleRate }
    public func getBufferSize() -> Int { state.bufferSize }
    public func getLatency() -> TimeInterval { state.latency }
    public func getCPULoad() -> Double { state.cpuLoad }

    // Safe setters with validation
    public func setRunning(_ running: Bool) {
        saveHistory()
        state.isRunning = running
    }

    public func setSampleRate(_ rate: Double) {
        guard [8000, 11025, 22050, 44100, 48000, 88200, 96000, 176400, 192000].contains(rate) else {
            return
        }
        saveHistory()
        state.sampleRate = rate
        recalculateLatency()
    }

    public func setBufferSize(_ size: Int) {
        guard [64, 128, 256, 512, 1024, 2048, 4096].contains(size) else {
            return
        }
        saveHistory()
        state.bufferSize = size
        recalculateLatency()
    }

    public func updateCPULoad(_ load: Double) {
        state.cpuLoad = load.clamped(to: 0...1)
    }

    public func updatePeakLevel(_ level: Float) {
        state.peakLevel = level.clamped(to: 0...1)
    }

    public func configureChannels(input: Int, output: Int) {
        saveHistory()
        state.inputChannels = max(0, min(input, 64))
        state.outputChannels = max(1, min(output, 64))
    }

    // History management
    private func saveHistory() {
        stateHistory.append(state)
        if stateHistory.count > maxHistorySize {
            stateHistory.removeFirst()
        }
    }

    public func undo() -> AudioState? {
        guard let previous = stateHistory.popLast() else { return nil }
        let current = state
        state = previous
        return current
    }

    private func recalculateLatency() {
        state.latency = Double(state.bufferSize) / state.sampleRate
    }

    // Atomic operations
    public func toggleRunning() -> Bool {
        state.isRunning.toggle()
        return state.isRunning
    }
}

// MARK: - Thread-Safe MIDI State

/// Actor managing all MIDI state thread-safely
public actor MIDIEngineActor {

    public struct MIDIState: Sendable {
        public var isConnected: Bool = false
        public var inputPorts: [String] = []
        public var outputPorts: [String] = []
        public var activeNotes: Set<Int> = []
        public var lastControlChange: [Int: Int] = [:] // CC# -> Value
        public var pitchBend: Int = 8192 // Center value
        public var channelPressure: Int = 0
        public var programNumber: Int = 0
        public var bankMSB: Int = 0
        public var bankLSB: Int = 0
    }

    public struct MIDIMessage: Sendable {
        public let status: UInt8
        public let data1: UInt8
        public let data2: UInt8
        public let timestamp: TimeInterval
        public let channel: Int

        public var isNoteOn: Bool { (status & 0xF0) == 0x90 && data2 > 0 }
        public var isNoteOff: Bool { (status & 0xF0) == 0x80 || ((status & 0xF0) == 0x90 && data2 == 0) }
        public var isControlChange: Bool { (status & 0xF0) == 0xB0 }
        public var isPitchBend: Bool { (status & 0xF0) == 0xE0 }
        public var isProgramChange: Bool { (status & 0xF0) == 0xC0 }
    }

    private var state = MIDIState()
    private var messageHistory: [MIDIMessage] = []
    private let maxHistorySize = 1000

    public init() {}

    // Safe getters
    public func getState() -> MIDIState { state }
    public func isConnected() -> Bool { state.isConnected }
    public func getActiveNotes() -> Set<Int> { state.activeNotes }
    public func getControlValue(_ cc: Int) -> Int { state.lastControlChange[cc] ?? 0 }
    public func getPitchBend() -> Int { state.pitchBend }

    // Safe setters
    public func setConnected(_ connected: Bool) {
        state.isConnected = connected
        if !connected {
            state.activeNotes.removeAll()
        }
    }

    public func updatePorts(inputs: [String], outputs: [String]) {
        state.inputPorts = inputs
        state.outputPorts = outputs
    }

    // Note management
    public func noteOn(_ note: Int, velocity: Int) {
        guard (0...127).contains(note), (1...127).contains(velocity) else { return }
        state.activeNotes.insert(note)
    }

    public func noteOff(_ note: Int) {
        guard (0...127).contains(note) else { return }
        state.activeNotes.remove(note)
    }

    public func allNotesOff() {
        state.activeNotes.removeAll()
    }

    // Control changes
    public func controlChange(_ cc: Int, value: Int) {
        guard (0...127).contains(cc), (0...127).contains(value) else { return }
        state.lastControlChange[cc] = value

        // Handle special CCs
        switch cc {
        case 0: state.bankMSB = value
        case 32: state.bankLSB = value
        case 123: allNotesOff() // All Notes Off
        default: break
        }
    }

    public func pitchBend(_ value: Int) {
        state.pitchBend = value.clamped(to: 0...16383)
    }

    public func programChange(_ program: Int) {
        guard (0...127).contains(program) else { return }
        state.programNumber = program
    }

    // Message processing
    public func processMessage(_ message: MIDIMessage) {
        messageHistory.append(message)
        if messageHistory.count > maxHistorySize {
            messageHistory.removeFirst()
        }

        if message.isNoteOn {
            noteOn(Int(message.data1), velocity: Int(message.data2))
        } else if message.isNoteOff {
            noteOff(Int(message.data1))
        } else if message.isControlChange {
            controlChange(Int(message.data1), value: Int(message.data2))
        } else if message.isPitchBend {
            let bend = Int(message.data1) | (Int(message.data2) << 7)
            pitchBend(bend)
        } else if message.isProgramChange {
            programChange(Int(message.data1))
        }
    }

    public func getRecentMessages(count: Int = 100) -> [MIDIMessage] {
        Array(messageHistory.suffix(count))
    }
}

// MARK: - Thread-Safe Visual State

/// Actor managing visual rendering state thread-safely
public actor VisualEngineActor {

    public struct VisualState: Sendable {
        public var isRendering: Bool = false
        public var frameRate: Double = 60.0
        public var resolution: QuantumSize = QuantumSize(width: 1920, height: 1080)
        public var colorSpace: String = "sRGB"
        public var hdrEnabled: Bool = false
        public var currentVisualizationMode: String = "spectrum"
        public var audioReactivity: Double = 1.0
        public var brightness: Double = 1.0
        public var contrast: Double = 1.0
        public var saturation: Double = 1.0
    }

    public struct FrameMetrics: Sendable {
        public let frameNumber: UInt64
        public let renderTime: TimeInterval
        public let gpuUtilization: Double
        public let droppedFrames: Int
    }

    private var state = VisualState()
    private var frameCount: UInt64 = 0
    private var droppedFrameCount: Int = 0
    private var lastFrameTime: TimeInterval = 0

    public init() {}

    // Safe getters
    public func getState() -> VisualState { state }
    public func isRendering() -> Bool { state.isRendering }
    public func getFrameRate() -> Double { state.frameRate }
    public func getResolution() -> QuantumSize { state.resolution }
    public func getVisualizationMode() -> String { state.currentVisualizationMode }

    // Safe setters
    public func setRendering(_ rendering: Bool) {
        state.isRendering = rendering
        if rendering {
            lastFrameTime = Date.timeIntervalSinceReferenceDate
        }
    }

    public func setFrameRate(_ fps: Double) {
        state.frameRate = fps.clamped(to: 1...240)
    }

    public func setResolution(_ size: QuantumSize) {
        state.resolution = size
    }

    public func setVisualizationMode(_ mode: String) {
        state.currentVisualizationMode = mode
    }

    public func setAudioReactivity(_ level: Double) {
        state.audioReactivity = level.normalized
    }

    public func setHDR(_ enabled: Bool) {
        state.hdrEnabled = enabled
    }

    public func adjustImage(brightness: Double? = nil, contrast: Double? = nil, saturation: Double? = nil) {
        if let b = brightness { state.brightness = b.clamped(to: 0...2) }
        if let c = contrast { state.contrast = c.clamped(to: 0...2) }
        if let s = saturation { state.saturation = s.clamped(to: 0...2) }
    }

    // Frame management
    public func beginFrame() -> UInt64 {
        frameCount += 1
        return frameCount
    }

    public func endFrame(renderTime: TimeInterval) -> FrameMetrics {
        let expectedFrameTime = 1.0 / state.frameRate
        if renderTime > expectedFrameTime * 1.5 {
            droppedFrameCount += 1
        }
        lastFrameTime = Date.timeIntervalSinceReferenceDate

        return FrameMetrics(
            frameNumber: frameCount,
            renderTime: renderTime,
            gpuUtilization: min(renderTime / expectedFrameTime, 1.0),
            droppedFrames: droppedFrameCount
        )
    }

    public func resetMetrics() {
        frameCount = 0
        droppedFrameCount = 0
    }
}

// MARK: - Thread-Safe Biofeedback State

/// Actor managing biofeedback sensor state thread-safely
public actor BiofeedbackActor {

    public struct BioState: Sendable {
        public var heartRate: Double = 0
        public var hrv: Double = 0
        public var respiratoryRate: Double = 0
        public var skinConductance: Double = 0
        public var brainwaveState: String = "neutral"
        public var stressLevel: Double = 0
        public var calmLevel: Double = 0
        public var focusLevel: Double = 0
        public var isCalibrated: Bool = false
        public var lastUpdate: Date = Date()
    }

    public struct HeartRateSample: Sendable {
        public let bpm: Double
        public let timestamp: Date
        public let quality: Double // 0-1 signal quality
    }

    private var state = BioState()
    private var heartRateHistory: [HeartRateSample] = []
    private var hrvHistory: [Double] = []
    private let maxHistorySize = 300 // 5 minutes at 1Hz

    public init() {}

    // Safe getters
    public func getState() -> BioState { state }
    public func getHeartRate() -> Double { state.heartRate }
    public func getHRV() -> Double { state.hrv }
    public func getStressLevel() -> Double { state.stressLevel }
    public func getCalmLevel() -> Double { state.calmLevel }
    public func getFocusLevel() -> Double { state.focusLevel }
    public func isCalibrated() -> Bool { state.isCalibrated }

    // Safe setters with smoothing
    public func updateHeartRate(_ bpm: Double, quality: Double = 1.0) {
        guard bpm >= 30 && bpm <= 220 else { return }

        let sample = HeartRateSample(bpm: bpm, timestamp: Date(), quality: quality)
        heartRateHistory.append(sample)
        if heartRateHistory.count > maxHistorySize {
            heartRateHistory.removeFirst()
        }

        // Apply exponential smoothing
        let alpha = 0.3
        state.heartRate = alpha * bpm + (1 - alpha) * state.heartRate
        state.lastUpdate = Date()
    }

    public func updateHRV(_ mssd: Double) {
        guard mssd >= 0 && mssd <= 300 else { return }

        hrvHistory.append(mssd)
        if hrvHistory.count > maxHistorySize {
            hrvHistory.removeFirst()
        }

        // Apply smoothing
        let alpha = 0.2
        state.hrv = alpha * mssd + (1 - alpha) * state.hrv

        // Update derived metrics
        updateStressMetrics()
    }

    public func updateRespiratoryRate(_ breathsPerMinute: Double) {
        guard breathsPerMinute >= 4 && breathsPerMinute <= 40 else { return }
        state.respiratoryRate = breathsPerMinute
    }

    public func updateSkinConductance(_ microSiemens: Double) {
        guard microSiemens >= 0 && microSiemens <= 50 else { return }
        state.skinConductance = microSiemens
        updateStressMetrics()
    }

    public func setBrainwaveState(_ state: String) {
        self.state.brainwaveState = state
    }

    public func setCalibrated(_ calibrated: Bool) {
        state.isCalibrated = calibrated
    }

    // Derived metric calculation
    private func updateStressMetrics() {
        // Stress increases with lower HRV and higher skin conductance
        let hrvStress = max(0, 1 - (state.hrv / 100)) // Lower HRV = higher stress
        let scStress = (state.skinConductance / 20).normalized // Higher SC = higher stress

        state.stressLevel = (hrvStress * 0.6 + scStress * 0.4).normalized
        state.calmLevel = (1 - state.stressLevel).normalized

        // Focus is high when stress is moderate and HRV is moderate-high
        let optimalStress = 1 - abs(state.stressLevel - 0.3) * 2
        let hrvFocus = (state.hrv / 80).normalized
        state.focusLevel = (optimalStress * 0.5 + hrvFocus * 0.5).normalized
    }

    // Analytics
    public func getAverageHeartRate(minutes: Int = 5) -> Double {
        let cutoff = Date().addingTimeInterval(-Double(minutes * 60))
        let recentSamples = heartRateHistory.filter { $0.timestamp > cutoff }
        guard !recentSamples.isEmpty else { return state.heartRate }
        return recentSamples.map(\.bpm).reduce(0, +) / Double(recentSamples.count)
    }

    public func getHRVTrend() -> String {
        guard hrvHistory.count >= 10 else { return "insufficient_data" }

        let recent = Array(hrvHistory.suffix(10))
        let older = Array(hrvHistory.prefix(10))

        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let olderAvg = older.reduce(0, +) / Double(older.count)

        if recentAvg > olderAvg * 1.1 { return "improving" }
        if recentAvg < olderAvg * 0.9 { return "declining" }
        return "stable"
    }
}

// MARK: - Thread-Safe Session State

/// Actor managing recording session state thread-safely
public actor SessionActor {

    public struct SessionState: Sendable {
        public var isRecording: Bool = false
        public var isPaused: Bool = false
        public var isPlaying: Bool = false
        public var currentPosition: TimeInterval = 0
        public var duration: TimeInterval = 0
        public var trackCount: Int = 0
        public var tempo: Double = 120
        public var timeSignature: (Int, Int) = (4, 4)
        public var loopEnabled: Bool = false
        public var loopStart: TimeInterval = 0
        public var loopEnd: TimeInterval = 0
    }

    private var state = SessionState()
    private var undoStack: [SessionState] = []
    private var redoStack: [SessionState] = []

    public init() {}

    // Safe getters
    public func getState() -> SessionState { state }
    public func isRecording() -> Bool { state.isRecording }
    public func isPlaying() -> Bool { state.isPlaying }
    public func getCurrentPosition() -> TimeInterval { state.currentPosition }
    public func getDuration() -> TimeInterval { state.duration }
    public func getTempo() -> Double { state.tempo }

    // Transport controls
    public func startRecording() {
        saveState()
        state.isRecording = true
        state.isPaused = false
    }

    public func stopRecording() {
        saveState()
        state.isRecording = false
    }

    public func startPlayback() {
        state.isPlaying = true
        state.isPaused = false
    }

    public func stopPlayback() {
        state.isPlaying = false
        state.currentPosition = 0
    }

    public func pause() {
        state.isPaused = true
        state.isPlaying = false
        state.isRecording = false
    }

    public func setPosition(_ position: TimeInterval) {
        state.currentPosition = max(0, min(position, state.duration))
    }

    public func setTempo(_ bpm: Double) {
        guard bpm >= 20 && bpm <= 400 else { return }
        saveState()
        state.tempo = bpm
    }

    public func setTimeSignature(numerator: Int, denominator: Int) {
        guard [2, 3, 4, 5, 6, 7, 8, 9, 12].contains(numerator) else { return }
        guard [2, 4, 8, 16].contains(denominator) else { return }
        saveState()
        state.timeSignature = (numerator, denominator)
    }

    public func setLoop(enabled: Bool, start: TimeInterval? = nil, end: TimeInterval? = nil) {
        saveState()
        state.loopEnabled = enabled
        if let s = start { state.loopStart = max(0, s) }
        if let e = end { state.loopEnd = min(e, state.duration) }
    }

    public func updateDuration(_ duration: TimeInterval) {
        state.duration = max(0, duration)
    }

    public func updateTrackCount(_ count: Int) {
        state.trackCount = max(0, count)
    }

    // Undo/Redo
    private func saveState() {
        undoStack.append(state)
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    public func undo() -> Bool {
        guard let previous = undoStack.popLast() else { return false }
        redoStack.append(state)
        state = previous
        return true
    }

    public func redo() -> Bool {
        guard let next = redoStack.popLast() else { return false }
        undoStack.append(state)
        state = next
        return true
    }
}

// MARK: - Global Thread-Safe Managers

/// Centralized access to all thread-safe actors
public enum ThreadSafeManagers {
    public static let audio = AudioEngineActor()
    public static let midi = MIDIEngineActor()
    public static let visual = VisualEngineActor()
    public static let biofeedback = BiofeedbackActor()
    public static let session = SessionActor()
}

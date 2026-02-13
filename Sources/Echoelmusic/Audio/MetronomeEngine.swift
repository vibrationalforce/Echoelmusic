// MetronomeEngine.swift
// Echoelmusic
//
// Professional metronome engine with configurable sounds,
// time signatures, subdivision, and bio-reactive tempo.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import AVFoundation
import Combine

// MARK: - Metronome Sound

/// Available metronome click sounds
public enum MetronomeSound: String, CaseIterable, Codable, Sendable {
    case woodBlock = "Wood Block"
    case rimshot = "Rimshot"
    case click = "Click"
    case cowbell = "Cowbell"
    case hiHat = "Hi-Hat"
    case beep = "Beep"
    case subtle = "Subtle"

    /// Frequency for synthesized click (downbeat)
    var downbeatFrequency: Double {
        switch self {
        case .woodBlock: return 1200
        case .rimshot: return 1500
        case .click: return 1000
        case .cowbell: return 800
        case .hiHat: return 6000
        case .beep: return 880
        case .subtle: return 600
        }
    }

    /// Frequency for synthesized click (upbeat)
    var upbeatFrequency: Double {
        switch self {
        case .woodBlock: return 900
        case .rimshot: return 1100
        case .click: return 800
        case .cowbell: return 600
        case .hiHat: return 4000
        case .beep: return 440
        case .subtle: return 400
        }
    }
}

// MARK: - Subdivision

/// Beat subdivision for the metronome
public enum MetronomeSubdivision: String, CaseIterable, Codable, Sendable {
    case none = "None"
    case eighth = "8th Notes"
    case triplet = "Triplets"
    case sixteenth = "16th Notes"
    case swing = "Swing"

    /// Number of clicks per beat
    var clicksPerBeat: Int {
        switch self {
        case .none: return 1
        case .eighth: return 2
        case .triplet: return 3
        case .sixteenth: return 4
        case .swing: return 2
        }
    }

    /// Timing ratios for each subdivision click within a beat
    var timingRatios: [Double] {
        switch self {
        case .none: return [0.0]
        case .eighth: return [0.0, 0.5]
        case .triplet: return [0.0, 1.0/3.0, 2.0/3.0]
        case .sixteenth: return [0.0, 0.25, 0.5, 0.75]
        case .swing: return [0.0, 0.67] // Swing feel
        }
    }
}

// MARK: - Count-In Mode

/// Count-in before recording
public enum CountInMode: String, CaseIterable, Codable, Sendable {
    case off = "Off"
    case oneBar = "1 Bar"
    case twoBars = "2 Bars"
    case fourBars = "4 Bars"

    var bars: Int {
        switch self {
        case .off: return 0
        case .oneBar: return 1
        case .twoBars: return 2
        case .fourBars: return 4
        }
    }
}

// MARK: - Metronome Configuration

/// Configuration for the metronome
public struct MetronomeConfiguration: Codable, Sendable {
    public var sound: MetronomeSound
    public var subdivision: MetronomeSubdivision
    public var countIn: CountInMode
    public var volume: Float
    public var accentDownbeat: Bool
    public var muteDuringPlayback: Bool
    public var flashOnBeat: Bool
    public var hapticOnBeat: Bool
    public var panPosition: Float

    public init(
        sound: MetronomeSound = .click,
        subdivision: MetronomeSubdivision = .none,
        countIn: CountInMode = .oneBar,
        volume: Float = 0.7,
        accentDownbeat: Bool = true,
        muteDuringPlayback: Bool = false,
        flashOnBeat: Bool = true,
        hapticOnBeat: Bool = true,
        panPosition: Float = 0.0
    ) {
        self.sound = sound
        self.subdivision = subdivision
        self.countIn = countIn
        self.volume = volume
        self.accentDownbeat = accentDownbeat
        self.muteDuringPlayback = muteDuringPlayback
        self.flashOnBeat = flashOnBeat
        self.hapticOnBeat = hapticOnBeat
        self.panPosition = panPosition
    }
}

// MARK: - Metronome Engine

/// Professional metronome engine with synthesis-based click generation
@MainActor
public final class MetronomeEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public var isRunning: Bool = false
    @Published public var currentBeat: Int = 0
    @Published public var currentBar: Int = 0
    @Published public var isDownbeat: Bool = false
    @Published public var tempo: Double = 120.0
    @Published public var beatsPerBar: Int = 4
    @Published public var noteValue: Int = 4
    @Published public var configuration: MetronomeConfiguration

    /// Visual flash trigger (briefly true on each beat)
    @Published public var beatFlash: Bool = false

    /// Count-in beats remaining (0 when done)
    @Published public var countInBeatsRemaining: Int = 0

    // MARK: - Private Properties

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.echoelmusic.metronome", qos: .userInteractive)

    // Pre-generated click buffers
    private var downbeatBuffer: AVAudioPCMBuffer?
    private var upbeatBuffer: AVAudioPCMBuffer?
    private var subdivisionBuffer: AVAudioPCMBuffer?

    private let sampleRate: Double = 44100
    private let clickDuration: Double = 0.02 // 20ms click

    // MARK: - Initialization

    public init(configuration: MetronomeConfiguration = MetronomeConfiguration()) {
        self.configuration = configuration
        setupAudio()
        generateClickBuffers()
    }

    // MARK: - Audio Setup

    private func setupAudio() {
        audioEngine.attach(playerNode)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)

        audioEngine.mainMixerNode.outputVolume = configuration.volume
    }

    /// Generate synthesized click buffers
    private func generateClickBuffers() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        downbeatBuffer = generateClick(
            frequency: configuration.sound.downbeatFrequency,
            amplitude: 0.8,
            format: format
        )
        upbeatBuffer = generateClick(
            frequency: configuration.sound.upbeatFrequency,
            amplitude: 0.5,
            format: format
        )
        subdivisionBuffer = generateClick(
            frequency: configuration.sound.upbeatFrequency * 1.2,
            amplitude: 0.3,
            format: format
        )
    }

    /// Generate a single click sound
    private func generateClick(
        frequency: Double,
        amplitude: Float,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(clickDuration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData?[0] else { return nil }

        for i in 0..<Int(frameCount) {
            let time = Double(i) / sampleRate
            let envelope = Float(exp(-time * 200)) // Fast decay
            let sine = Float(sin(2.0 * .pi * frequency * time))
            // Add slight noise for character
            let noise = Float.random(in: -0.1...0.1) * envelope * 0.3
            channelData[i] = (sine * envelope + noise) * amplitude
        }

        return buffer
    }

    // MARK: - Public API

    /// Start the metronome
    public func start() {
        guard !isRunning else { return }

        do {
            try audioEngine.start()
            playerNode.play()
        } catch {
            log.audio("Metronome audio engine start failed: \(error)")
            return
        }

        currentBeat = 0
        currentBar = 0
        isRunning = true

        // Handle count-in
        if configuration.countIn != .off {
            countInBeatsRemaining = configuration.countIn.bars * beatsPerBar
        }

        startTimer()
    }

    /// Stop the metronome
    public func stop() {
        isRunning = false
        timer?.cancel()
        timer = nil
        playerNode.stop()
        audioEngine.stop()
        countInBeatsRemaining = 0
        beatFlash = false
    }

    /// Update tempo (can be called while running)
    public func setTempo(_ newTempo: Double) {
        tempo = max(20, min(300, newTempo))
        if isRunning {
            // Restart timer with new interval
            timer?.cancel()
            startTimer()
        }
    }

    /// Set time signature
    public func setTimeSignature(beats: Int, noteValue: Int) {
        self.beatsPerBar = max(1, min(16, beats))
        self.noteValue = noteValue
    }

    /// Update sound and regenerate buffers
    public func setSound(_ sound: MetronomeSound) {
        configuration.sound = sound
        generateClickBuffers()
    }

    /// Perform count-in then call completion
    public func countInAndStart(completion: @escaping () -> Void) {
        guard configuration.countIn != .off else {
            completion()
            return
        }

        countInBeatsRemaining = configuration.countIn.bars * beatsPerBar
        start()

        // The timer will call completion when count-in is done
        Task { @MainActor in
            while countInBeatsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms poll
            }
            completion()
        }
    }

    // MARK: - Timer

    private func startTimer() {
        let beatInterval = 60.0 / tempo
        let subdivisionInterval = beatInterval / Double(configuration.subdivision.clicksPerBeat)

        timer = DispatchSource.makeTimerSource(queue: timerQueue)

        var subdivisionCount = 0
        let clicksPerBeat = configuration.subdivision.clicksPerBeat

        timer?.schedule(
            deadline: .now(),
            repeating: subdivisionInterval,
            leeway: .milliseconds(1)
        )

        timer?.setEventHandler { [weak self] in
            guard let self = self else { return }

            let isMainBeat = subdivisionCount % clicksPerBeat == 0

            if isMainBeat {
                Task { @MainActor in
                    self.processBeat()
                }
            } else {
                // Subdivision click
                if let buffer = self.subdivisionBuffer {
                    self.playerNode.scheduleBuffer(buffer, completionHandler: nil)
                }
            }

            subdivisionCount += 1
        }

        timer?.resume()
    }

    /// Process a main beat
    private func processBeat() {
        let isDown = currentBeat == 0

        // Play appropriate click
        if isDown && configuration.accentDownbeat {
            if let buffer = downbeatBuffer {
                playerNode.scheduleBuffer(buffer, completionHandler: nil)
            }
        } else {
            if let buffer = upbeatBuffer {
                playerNode.scheduleBuffer(buffer, completionHandler: nil)
            }
        }

        // Update state
        isDownbeat = isDown
        currentBeat = (currentBeat + 1) % beatsPerBar
        if currentBeat == 0 {
            currentBar += 1
        }

        // Count-in tracking
        if countInBeatsRemaining > 0 {
            countInBeatsRemaining -= 1
        }

        // Visual flash
        if configuration.flashOnBeat {
            beatFlash = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms flash
                self.beatFlash = false
            }
        }
    }

    // MARK: - Bio-Reactive Tempo

    /// Adjust tempo based on heart rate (bio-reactive mode)
    /// Maps heart rate range to tempo range
    public func syncToHeartRate(_ heartRate: Double, minTempo: Double = 60, maxTempo: Double = 180) {
        // Map typical heart rate (40-200) to tempo range
        let normalizedHR = (heartRate - 40) / 160.0
        let clampedHR = max(0, min(1, normalizedHR))
        let newTempo = minTempo + clampedHR * (maxTempo - minTempo)
        setTempo(newTempo)
    }

    /// Tap tempo — call repeatedly to set tempo from taps
    private var tapTimes: [Date] = []

    public func tapTempo() {
        let now = Date()
        tapTimes.append(now)

        // Keep last 8 taps
        if tapTimes.count > 8 {
            tapTimes.removeFirst()
        }

        // Need at least 2 taps
        guard tapTimes.count >= 2 else { return }

        // Calculate average interval
        var totalInterval: TimeInterval = 0
        for i in 1..<tapTimes.count {
            totalInterval += tapTimes[i].timeIntervalSince(tapTimes[i-1])
        }
        let averageInterval = totalInterval / Double(tapTimes.count - 1)

        // Convert to BPM
        if averageInterval > 0 {
            let bpm = 60.0 / averageInterval
            setTempo(bpm)
        }

        // Reset if gap is too long (> 3 seconds)
        if tapTimes.count >= 2 {
            let lastInterval = now.timeIntervalSince(tapTimes[tapTimes.count - 2])
            if lastInterval > 3.0 {
                tapTimes = [now]
            }
        }
    }

    deinit {
        timer?.cancel()
    }
}

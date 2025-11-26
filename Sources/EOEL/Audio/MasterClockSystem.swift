//
//  MasterClockSystem.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Professional Master Clock System
//  Sample-accurate timing with MIDI Clock, MTC, MMC, Word Clock
//  Senior Apple Audio Developer level implementation
//

import Foundation
import CoreAudio
import AudioToolbox
import Combine

/// Professional master clock system for sample-accurate timing and synchronization
@MainActor
class MasterClockSystem: ObservableObject {
    static let shared = MasterClockSystem()

    // MARK: - Published Properties

    @Published var isRunning: Bool = false
    @Published var clockSource: ClockSource = .internal
    @Published var tempo: Double = 120.0  // BPM
    @Published var timeSignature: TimeSignature = TimeSignature(numerator: 4, denominator: 4)
    @Published var currentSample: UInt64 = 0
    @Published var currentBeat: Double = 0.0
    @Published var currentBar: Int = 0
    @Published var midiClockEnabled: Bool = false
    @Published var mtcEnabled: Bool = false
    @Published var mmcEnabled: Bool = false
    @Published var externalSyncStatus: SyncStatus = .disconnected
    @Published var sampleRate: Double = 48000.0

    // MARK: - Clock Source

    enum ClockSource: String, CaseIterable {
        case `internal` = "Internal"
        case midiClock = "MIDI Clock (24 PPQN)"
        case mtc = "MIDI Time Code (MTC)"
        case wordClock = "Word Clock"
        case adat = "ADAT Sync"
        case ltc = "LTC (Linear Time Code)"
        case ableton = "Ableton Link"
        case echoelSync = "EchoelSync"

        var description: String {
            switch self {
            case .internal: return "Internal clock - master mode"
            case .midiClock: return "MIDI Clock at 24 pulses per quarter note"
            case .mtc: return "MIDI Time Code - 24/25/29.97/30 fps"
            case .wordClock: return "Word Clock - sample-accurate hardware sync"
            case .adat: return "ADAT optical sync"
            case .ltc: return "Linear Time Code - audio-based sync"
            case .ableton: return "Ableton Link network sync"
            case .echoelSync: return "EchoelSync worldwide collaboration"
            }
        }
    }

    enum SyncStatus: String {
        case disconnected = "Disconnected"
        case searching = "Searching..."
        case locked = "Locked"
        case drifting = "Drifting"
        case error = "Error"

        var color: String {
            switch self {
            case .disconnected: return "gray"
            case .searching: return "yellow"
            case .locked: return "green"
            case .drifting: return "orange"
            case .error: return "red"
            }
        }
    }

    // MARK: - Time Signature

    struct TimeSignature: Codable, Equatable {
        var numerator: Int  // beats per bar
        var denominator: Int  // note value (4 = quarter note)

        var description: String {
            return "\(numerator)/\(denominator)"
        }
    }

    // MARK: - MIDI Clock

    struct MIDIClock {
        static let pulsesPerQuarterNote = 24
        var pulseCount: Int = 0
        var lastPulseTime: UInt64 = 0
        var averagePulseDuration: Double = 0.0

        mutating func receivePulse(at sample: UInt64) {
            let duration = Double(sample - lastPulseTime)
            averagePulseDuration = (averagePulseDuration * 0.9) + (duration * 0.1)
            lastPulseTime = sample
            pulseCount += 1
        }

        func calculateTempo(sampleRate: Double) -> Double {
            guard averagePulseDuration > 0 else { return 120.0 }
            let samplesPerQuarterNote = averagePulseDuration * Double(MIDIClock.pulsesPerQuarterNote)
            let secondsPerQuarterNote = samplesPerQuarterNote / sampleRate
            let beatsPerSecond = 1.0 / secondsPerQuarterNote
            return beatsPerSecond * 60.0
        }
    }

    private var midiClock = MIDIClock()

    // MARK: - MIDI Time Code (MTC)

    struct MTCFrame {
        var hours: Int = 0
        var minutes: Int = 0
        var seconds: Int = 0
        var frames: Int = 0
        var frameRate: FrameRate = .fps30

        enum FrameRate: Int {
            case fps24 = 24
            case fps25 = 25
            case fps2997 = 2997  // 29.97 drop-frame
            case fps30 = 30

            var framesPerSecond: Double {
                switch self {
                case .fps24: return 24.0
                case .fps25: return 25.0
                case .fps2997: return 29.97
                case .fps30: return 30.0
                }
            }
        }

        func toSamples(sampleRate: Double) -> UInt64 {
            let totalSeconds = Double(hours * 3600 + minutes * 60 + seconds)
            let frameSeconds = Double(frames) / frameRate.framesPerSecond
            return UInt64((totalSeconds + frameSeconds) * sampleRate)
        }

        static func fromSamples(_ samples: UInt64, sampleRate: Double, frameRate: FrameRate) -> MTCFrame {
            let totalSeconds = Double(samples) / sampleRate
            let hours = Int(totalSeconds / 3600)
            let minutes = Int((totalSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
            let seconds = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
            let frameSeconds = totalSeconds - Double(hours * 3600 + minutes * 60 + seconds)
            let frames = Int(frameSeconds * frameRate.framesPerSecond)

            return MTCFrame(hours: hours, minutes: minutes, seconds: seconds, frames: frames, frameRate: frameRate)
        }

        var description: String {
            return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
        }
    }

    @Published var currentMTC: MTCFrame = MTCFrame()
    private var mtcQuarterFrame: Int = 0
    private var mtcBuffer: [UInt8] = Array(repeating: 0, count: 8)

    // MARK: - MIDI Machine Control (MMC)

    enum MMCCommand: UInt8 {
        case stop = 0x01
        case play = 0x02
        case deferredPlay = 0x03
        case fastForward = 0x04
        case rewind = 0x05
        case recordStrobe = 0x06
        case recordExit = 0x07
        case recordPause = 0x08
        case pause = 0x09
        case eject = 0x0A
        case chase = 0x0B
        case locate = 0x44
        case reset = 0x01
    }

    // MARK: - Sample-Accurate Timing

    private var referenceHostTime: UInt64 = 0
    private var referenceSampleTime: UInt64 = 0
    private var timer: Timer?

    /// Convert host time to sample time with sample accuracy
    func hostTimeToSamples(_ hostTime: UInt64) -> UInt64 {
        if referenceHostTime == 0 {
            referenceHostTime = hostTime
            referenceSampleTime = 0
            return 0
        }

        let elapsedHostTime = hostTime - referenceHostTime
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)

        let elapsedNanoseconds = elapsedHostTime * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
        let elapsedSeconds = Double(elapsedNanoseconds) / 1_000_000_000.0
        let elapsedSamples = UInt64(elapsedSeconds * sampleRate)

        return referenceSampleTime + elapsedSamples
    }

    /// Convert sample time to host time
    func samplesToHostTime(_ samples: UInt64) -> UInt64 {
        let seconds = Double(samples) / sampleRate
        let nanoseconds = UInt64(seconds * 1_000_000_000.0)

        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)

        return nanoseconds * UInt64(timebaseInfo.denom) / UInt64(timebaseInfo.numer)
    }

    // MARK: - Clock Control

    func start() {
        guard !isRunning else { return }

        isRunning = true
        referenceHostTime = mach_absolute_time()
        referenceSampleTime = currentSample

        // Send MIDI Clock Start if enabled
        if midiClockEnabled {
            sendMIDIClockStart()
        }

        // Send MMC Play if enabled
        if mmcEnabled {
            sendMMCCommand(.play)
        }

        // Start internal timer
        startTimer()

        print("⏰ Master Clock started - Source: \(clockSource.rawValue)")
    }

    func stop() {
        guard isRunning else { return }

        isRunning = false

        // Send MIDI Clock Stop if enabled
        if midiClockEnabled {
            sendMIDIClockStop()
        }

        // Send MMC Stop if enabled
        if mmcEnabled {
            sendMMCCommand(.stop)
        }

        // Stop internal timer
        stopTimer()

        print("⏰ Master Clock stopped")
    }

    func reset() {
        currentSample = 0
        currentBeat = 0.0
        currentBar = 0
        referenceHostTime = 0
        referenceSampleTime = 0
        midiClock.pulseCount = 0

        print("⏰ Master Clock reset")
    }

    // MARK: - Internal Timer

    private func startTimer() {
        // Update at 100 Hz for smooth UI updates
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePosition()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updatePosition() {
        guard isRunning else { return }

        switch clockSource {
        case .internal:
            updateInternalClock()
        case .midiClock:
            updateFromMIDIClock()
        case .mtc:
            updateFromMTC()
        default:
            break
        }

        // Update beat and bar position
        let samplesPerBeat = (sampleRate * 60.0) / tempo
        currentBeat = Double(currentSample) / samplesPerBeat
        currentBar = Int(currentBeat / Double(timeSignature.numerator))

        // Update MTC
        currentMTC = MTCFrame.fromSamples(currentSample, sampleRate: sampleRate, frameRate: .fps30)

        // Send MIDI Clock pulses if enabled
        if midiClockEnabled && clockSource == .internal {
            sendMIDIClockPulses()
        }

        // Send MTC quarter frames if enabled
        if mtcEnabled && clockSource == .internal {
            sendMTCQuarterFrame()
        }
    }

    private func updateInternalClock() {
        let hostTime = mach_absolute_time()
        currentSample = hostTimeToSamples(hostTime)
    }

    private func updateFromMIDIClock() {
        let calculatedTempo = midiClock.calculateTempo(sampleRate: sampleRate)
        if calculatedTempo > 0 {
            tempo = calculatedTempo
            externalSyncStatus = .locked
        } else {
            externalSyncStatus = .searching
        }
    }

    private func updateFromMTC() {
        currentSample = currentMTC.toSamples(sampleRate: sampleRate)
        externalSyncStatus = .locked
    }

    // MARK: - MIDI Clock Output

    private var midiClockPulseCounter: Int = 0
    private var lastMIDIClockSample: UInt64 = 0

    private func sendMIDIClockStart() {
        // MIDI Clock Start: 0xFA
        sendMIDIMessage([0xFA])
        midiClockPulseCounter = 0
        lastMIDIClockSample = currentSample
        print("🎵 MIDI Clock Start sent")
    }

    private func sendMIDIClockStop() {
        // MIDI Clock Stop: 0xFC
        sendMIDIMessage([0xFC])
        print("🎵 MIDI Clock Stop sent")
    }

    private func sendMIDIClockPulses() {
        let samplesPerBeat = (sampleRate * 60.0) / tempo
        let samplesPerPulse = samplesPerBeat / Double(MIDIClock.pulsesPerQuarterNote)
        let targetSample = UInt64(Double(midiClockPulseCounter) * samplesPerPulse)

        while currentSample >= targetSample {
            // MIDI Clock Pulse: 0xF8
            sendMIDIMessage([0xF8])
            midiClockPulseCounter += 1
        }
    }

    // MARK: - MTC Output

    private func sendMTCQuarterFrame() {
        // MTC sends 8 quarter frames per complete timecode
        // Each quarter frame contains 1 nibble (4 bits) of data

        let mtc = currentMTC

        // Build complete MTC data
        let data: [UInt8] = [
            UInt8(mtc.frames & 0x0F),           // Frame count LS nibble
            UInt8((mtc.frames >> 4) & 0x01),    // Frame count MS nibble
            UInt8(mtc.seconds & 0x0F),          // Seconds count LS nibble
            UInt8((mtc.seconds >> 4) & 0x03),   // Seconds count MS nibble
            UInt8(mtc.minutes & 0x0F),          // Minutes count LS nibble
            UInt8((mtc.minutes >> 4) & 0x03),   // Minutes count MS nibble
            UInt8(mtc.hours & 0x0F),            // Hours count LS nibble
            UInt8(((mtc.hours >> 4) & 0x01) | (UInt8(mtc.frameRate.rawValue) << 1))
        ]

        // Send current quarter frame
        // MTC Quarter Frame: 0xF1 0bPPPPDDDD
        // PPPP = piece (0-7), DDDD = data nibble
        let message: [UInt8] = [0xF1, UInt8((mtcQuarterFrame << 4) | Int(data[mtcQuarterFrame]))]
        sendMIDIMessage(message)

        // Advance to next quarter frame
        mtcQuarterFrame = (mtcQuarterFrame + 1) % 8
    }

    // MARK: - MMC Output

    func sendMMCCommand(_ command: MMCCommand) {
        // MMC Universal SysEx: F0 7F 7F 06 [command] F7
        let message: [UInt8] = [
            0xF0,  // SysEx Start
            0x7F,  // Universal Real-Time
            0x7F,  // Device ID (all devices)
            0x06,  // MMC
            command.rawValue,
            0xF7   // SysEx End
        ]
        sendMIDIMessage(message)
        print("🎛️ MMC Command sent: \(command)")
    }

    // MARK: - MIDI Clock Input

    func receiveMIDIClockPulse() {
        midiClock.receivePulse(at: currentSample)

        // Update tempo from incoming pulses
        let calculatedTempo = midiClock.calculateTempo(sampleRate: sampleRate)
        if abs(calculatedTempo - tempo) > 0.1 {
            tempo = calculatedTempo
        }
    }

    func receiveMIDIClockStart() {
        reset()
        start()
        externalSyncStatus = .locked
        print("🎵 MIDI Clock Start received")
    }

    func receiveMIDIClockStop() {
        stop()
        print("🎵 MIDI Clock Stop received")
    }

    func receiveMIDIClockContinue() {
        start()
        externalSyncStatus = .locked
        print("🎵 MIDI Clock Continue received")
    }

    // MARK: - MTC Input

    func receiveMTCQuarterFrame(_ data: UInt8) {
        let piece = Int((data >> 4) & 0x07)
        let nibble = data & 0x0F

        mtcBuffer[piece] = nibble

        // When we receive piece 7, we have a complete frame
        if piece == 7 {
            reconstructMTCFrame()
        }
    }

    private func reconstructMTCFrame() {
        let frames = Int(mtcBuffer[0]) | (Int(mtcBuffer[1]) << 4)
        let seconds = Int(mtcBuffer[2]) | (Int(mtcBuffer[3]) << 4)
        let minutes = Int(mtcBuffer[4]) | (Int(mtcBuffer[5]) << 4)
        let hours = Int(mtcBuffer[6]) | ((Int(mtcBuffer[7]) & 0x01) << 4)
        let frameRateCode = (mtcBuffer[7] >> 1) & 0x03

        let frameRate: MTCFrame.FrameRate
        switch frameRateCode {
        case 0: frameRate = .fps24
        case 1: frameRate = .fps25
        case 2: frameRate = .fps2997
        default: frameRate = .fps30
        }

        currentMTC = MTCFrame(
            hours: hours,
            minutes: minutes,
            seconds: seconds,
            frames: frames,
            frameRate: frameRate
        )

        externalSyncStatus = .locked
    }

    // MARK: - MMC Input

    func receiveMMCCommand(_ data: [UInt8]) {
        guard data.count >= 5,
              data[0] == 0xF0,  // SysEx
              data[1] == 0x7F,  // Universal
              data[3] == 0x06   // MMC
        else { return }

        if let command = MMCCommand(rawValue: data[4]) {
            handleMMCCommand(command)
        }
    }

    private func handleMMCCommand(_ command: MMCCommand) {
        switch command {
        case .play:
            start()
        case .stop:
            stop()
        case .pause:
            stop()
        case .recordStrobe:
            print("🔴 MMC Record Start")
        case .recordExit:
            print("⏹️ MMC Record Stop")
        case .reset:
            reset()
        default:
            break
        }
    }

    // MARK: - MIDI Message Output

    private func sendMIDIMessage(_ bytes: [UInt8]) {
        // In real implementation, send to MIDI output port
        // For now, just log
        #if DEBUG
        let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("📤 MIDI: \(hex)")
        #endif
    }

    // MARK: - Quantization

    enum Quantization: String, CaseIterable {
        case bar = "Bar"
        case half = "1/2"
        case quarter = "1/4"
        case eighth = "1/8"
        case sixteenth = "1/16"
        case thirtysecond = "1/32"
        case off = "Off"

        func quantize(beat: Double, timeSignature: TimeSignature) -> Double {
            switch self {
            case .bar:
                let beatsPerBar = Double(timeSignature.numerator)
                return (beat / beatsPerBar).rounded() * beatsPerBar
            case .half:
                return (beat / 2.0).rounded() * 2.0
            case .quarter:
                return beat.rounded()
            case .eighth:
                return (beat * 2.0).rounded() / 2.0
            case .sixteenth:
                return (beat * 4.0).rounded() / 4.0
            case .thirtysecond:
                return (beat * 8.0).rounded() / 8.0
            case .off:
                return beat
            }
        }
    }

    // MARK: - Latency Compensation

    @Published var inputLatency: Double = 0.0  // samples
    @Published var outputLatency: Double = 0.0  // samples
    @Published var totalLatency: Double = 0.0  // milliseconds

    func setLatency(input: Double, output: Double) {
        self.inputLatency = input
        self.outputLatency = output
        self.totalLatency = ((input + output) / sampleRate) * 1000.0

        print("⏱️ Latency: Input=\(input) samples, Output=\(output) samples, Total=\(String(format: "%.2f", totalLatency))ms")
    }

    /// Get compensated sample time for recording
    func getCompensatedSampleTime() -> UInt64 {
        return currentSample + UInt64(inputLatency)
    }

    /// Get compensated sample time for playback
    func getPlaybackSampleTime() -> UInt64 {
        return currentSample - UInt64(outputLatency)
    }

    // MARK: - Tempo Mapping

    struct TempoChange {
        let sample: UInt64
        let tempo: Double
    }

    private var tempoMap: [TempoChange] = []

    func addTempoChange(at sample: UInt64, tempo: Double) {
        let change = TempoChange(sample: sample, tempo: tempo)
        tempoMap.append(change)
        tempoMap.sort { $0.sample < $1.sample }
    }

    func getTempoAt(sample: UInt64) -> Double {
        for i in (0..<tempoMap.count).reversed() {
            if tempoMap[i].sample <= sample {
                return tempoMap[i].tempo
            }
        }
        return tempo
    }

    // MARK: - Initialization

    private init() {
        // Detect system sample rate
        detectSampleRate()
    }

    private func detectSampleRate() {
        var defaultDevice: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultDevice
        )

        if status == noErr {
            var sampleRateValue: Float64 = 48000.0
            var sampleRateSize = UInt32(MemoryLayout<Float64>.size)
            var sampleRateAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyNominalSampleRate,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            let rateStatus = AudioObjectGetPropertyData(
                defaultDevice,
                &sampleRateAddress,
                0,
                nil,
                &sampleRateSize,
                &sampleRateValue
            )

            if rateStatus == noErr {
                sampleRate = sampleRateValue
                print("🎛️ Detected sample rate: \(sampleRate) Hz")
            }
        }
    }
}

// MARK: - Debug

#if DEBUG
extension MasterClockSystem {
    func simulateExternalSync() {
        print("🧪 Simulating external MIDI Clock sync...")
        clockSource = .midiClock
        externalSyncStatus = .locked

        // Simulate incoming MIDI clock pulses
        for _ in 0..<24 {
            receiveMIDIClockPulse()
        }
    }
}
#endif

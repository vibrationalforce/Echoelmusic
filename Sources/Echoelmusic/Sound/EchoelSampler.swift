// EchoelSampler.swift
// Echoelmusic - λ% Ralph Wiggum Lambda Loop Mode
// Native Swift Multi-Sampler Engine (Zero External Dependencies)
//
// Ported from UltraSampler C++ (JUCE) to pure Swift + Accelerate
// Original architecture: 128 zones, 16 velocity layers, 16 round-robin
//
// "I bent my wookie!" - Ralph Wiggum, Sample Interpolation Expert
//
// ═══════════════════════════════════════════════════════════════════════════════
// FEATURES:
// • Multi-sample instruments with key/velocity zones
// • Up to 128 zones, 16 velocity layers, 16 round-robin variations
// • Hermite + Sinc interpolation (via Accelerate/vDSP)
// • ADSR envelopes with curve control
// • LFOs with tempo sync
// • ZDF (zero-delay feedback) filters: LP/HP/BP/Notch
// • Bio-reactive modulation (HRV → depth, Coherence → filter, HR → tempo)
// • 64-voice polyphony with voice stealing
// ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import AVFoundation
import Accelerate

// MARK: - Constants

public enum SamplerConstants {
    public static let maxZones = 128
    public static let maxVelocityLayers = 16
    public static let maxRoundRobin = 16
    public static let maxVoices = 64
    public static let maxModSlots = 8
    public static let sincTaps = 16
}

// MARK: - Interpolation Mode

public enum SamplerInterpolation: String, CaseIterable, Sendable {
    case linear = "Linear"
    case hermite = "Hermite"
    case sinc = "Sinc"

    var quality: Int {
        switch self {
        case .linear: return 1
        case .hermite: return 2
        case .sinc: return 3
        }
    }
}

// MARK: - Filter Type

public enum SamplerFilterType: String, CaseIterable, Sendable {
    case lowpass = "Lowpass"
    case highpass = "Highpass"
    case bandpass = "Bandpass"
    case notch = "Notch"
}

// MARK: - ADSR Envelope

public struct ADSREnvelope {
    public var attack: Float = 0.005   // seconds
    public var decay: Float = 0.1      // seconds
    public var sustain: Float = 0.8    // level 0-1
    public var release: Float = 0.3    // seconds
    public var curve: Float = 1.0      // 1.0 = linear, >1 = exponential

    public init() {}

    public init(attack: Float, decay: Float, sustain: Float, release: Float) {
        self.attack = attack
        self.decay = decay
        self.sustain = sustain
        self.release = release
    }
}

// MARK: - Envelope State

enum EnvelopeStage {
    case idle, attack, decay, sustain, release
}

struct EnvelopeState {
    var stage: EnvelopeStage = .idle
    var level: Float = 0
    var sampleCounter: Int = 0

    mutating func noteOn() {
        stage = .attack
        sampleCounter = 0
    }

    mutating func noteOff() {
        stage = .release
        sampleCounter = 0
    }

    mutating func process(env: ADSREnvelope, sampleRate: Float) -> Float {
        switch stage {
        case .idle:
            return 0

        case .attack:
            let attackSamples = Swift.max(1, Int(env.attack * sampleRate))
            let t = Float(sampleCounter) / Float(attackSamples)
            level = pow(Swift.min(t, 1.0), env.curve)
            sampleCounter += 1
            if sampleCounter >= attackSamples {
                stage = .decay
                sampleCounter = 0
            }
            return level

        case .decay:
            let decaySamples = Swift.max(1, Int(env.decay * sampleRate))
            let t = Float(sampleCounter) / Float(decaySamples)
            level = 1.0 - (1.0 - env.sustain) * Swift.min(t, 1.0)
            sampleCounter += 1
            if sampleCounter >= decaySamples {
                stage = .sustain
                level = env.sustain
            }
            return level

        case .sustain:
            return env.sustain

        case .release:
            let releaseSamples = Swift.max(1, Int(env.release * sampleRate))
            let t = Float(sampleCounter) / Float(releaseSamples)
            let startLevel = level
            let current = startLevel * (1.0 - Swift.min(t, 1.0))
            sampleCounter += 1
            if sampleCounter >= releaseSamples || current < 0.0001 {
                stage = .idle
                level = 0
                return 0
            }
            level = current
            return current
        }
    }
}

// MARK: - LFO

public struct SamplerLFO {
    public enum Shape: String, CaseIterable, Sendable {
        case sine, triangle, saw, square, random
    }

    public var shape: Shape = .sine
    public var rate: Float = 1.0     // Hz (or beat divisions if tempoSync)
    public var depth: Float = 0.5    // 0-1
    public var tempoSync: Bool = false

    var phase: Float = 0

    mutating func process(sampleRate: Float, bpm: Float = 120) -> Float {
        let freq = tempoSync ? (bpm / 60.0) * rate : rate
        let phaseInc = freq / sampleRate
        phase += phaseInc
        if phase > 1.0 { phase -= 1.0 }

        let value: Float
        switch shape {
        case .sine:
            value = sin(phase * 2.0 * .pi)
        case .triangle:
            value = 4.0 * abs(phase - 0.5) - 1.0
        case .saw:
            value = 2.0 * phase - 1.0
        case .square:
            value = phase < 0.5 ? 1.0 : -1.0
        case .random:
            value = Float.random(in: -1.0...1.0)
        }
        return value * depth
    }
}

// MARK: - ZDF Filter (Zero-Delay Feedback)

struct ZDFFilter {
    var type: SamplerFilterType = .lowpass
    var cutoff: Float = 8000  // Hz
    var resonance: Float = 0  // 0-1

    // ZDF state variables
    private var s1: Float = 0
    private var s2: Float = 0

    mutating func process(_ input: Float, sampleRate: Float) -> Float {
        let g = tan(.pi * Swift.min(cutoff, sampleRate * 0.49) / sampleRate)
        let k = 2.0 - 2.0 * resonance  // Damping (resonance inverted)

        // ZDF SVF topology
        let hp = (input - (k + g) * s1 - s2) / (1.0 + k * g + g * g)
        let bp = g * hp + s1
        let lp = g * bp + s2

        // Update state
        s1 = g * hp + bp
        s2 = g * bp + lp

        switch type {
        case .lowpass: return lp
        case .highpass: return hp
        case .bandpass: return bp
        case .notch: return input - k * bp
        }
    }

    mutating func reset() {
        s1 = 0
        s2 = 0
    }
}

// MARK: - Sample Zone

/// A zone maps a key/velocity range to sample data
public struct SampleZone: Identifiable {
    public let id: UUID
    public var name: String
    public var rootNote: Int = 60               // MIDI note (C4)
    public var keyRangeLow: Int = 0             // MIDI note
    public var keyRangeHigh: Int = 127
    public var velocityLow: Int = 0             // 0-127
    public var velocityHigh: Int = 127

    // Sample data (mono Float32, pre-loaded)
    public var sampleData: [Float] = []
    public var sampleRate: Float = 44100
    public var loopStart: Int = 0
    public var loopEnd: Int = 0
    public var loopEnabled: Bool = false

    // Tuning
    public var fineTune: Float = 0              // Cents (-100 to +100)
    public var gain: Float = 1.0                // Volume
    public var pan: Float = 0                   // -1 (L) to +1 (R)

    // Round-robin
    public var roundRobinGroup: Int = 0
    public var roundRobinIndex: Int = 0

    public init(name: String = "Zone", rootNote: Int = 60) {
        self.id = UUID()
        self.name = name
        self.rootNote = rootNote
    }

    /// Check if this zone responds to a given note/velocity
    public func matches(note: Int, velocity: Int) -> Bool {
        note >= keyRangeLow && note <= keyRangeHigh &&
        velocity >= velocityLow && velocity <= velocityHigh
    }
}

// MARK: - Sampler Voice

struct SamplerVoice {
    var isActive: Bool = false
    var note: Int = 0
    var velocity: Float = 0
    var zoneIndex: Int = 0

    // Playback state
    var position: Double = 0          // Fractional sample position
    var pitchRatio: Double = 1.0      // Playback speed ratio

    // Envelope
    var ampEnvelope: EnvelopeState = EnvelopeState()
    var filterEnvelope: EnvelopeState = EnvelopeState()

    // Filter
    var filter: ZDFFilter = ZDFFilter()

    // LFOs
    var lfo1: SamplerLFO = SamplerLFO()
    var lfo2: SamplerLFO = SamplerLFO()

    // Voice age (for stealing)
    var age: Int = 0

    mutating func reset() {
        isActive = false
        position = 0
        ampEnvelope = EnvelopeState()
        filterEnvelope = EnvelopeState()
        filter.reset()
        age = 0
    }
}

// MARK: - Bio-Reactive Modulation

public struct SamplerBioModulation {
    public var hrvToFilterDepth: Float = 0.3    // HRV modulates filter cutoff
    public var coherenceToResonance: Float = 0.5 // Coherence → resonance
    public var heartRateToTempo: Bool = false    // HR syncs LFO rate
    public var breathToVolume: Float = 0.2       // Breath phase → volume swell
    public var flowToComplexity: Float = 0.4     // Flow state → round-robin spread

    public init() {}
}

// MARK: - EchoelSampler

/// Native Swift multi-sampler engine — λ∞ Lambda Loop Mode
/// Zero external dependencies, Accelerate-optimized
public final class EchoelSampler {

    // MARK: - Properties

    public var zones: [SampleZone] = []
    public var ampEnvelope: ADSREnvelope = ADSREnvelope()
    public var filterEnvelope: ADSREnvelope = ADSREnvelope(attack: 0.01, decay: 0.2, sustain: 0.5, release: 0.5)
    public var filterCutoff: Float = 8000
    public var filterResonance: Float = 0
    public var filterType: SamplerFilterType = .lowpass
    public var filterEnvelopeDepth: Float = 0      // 0-1
    public var interpolation: SamplerInterpolation = .hermite
    public var lfo1: SamplerLFO = SamplerLFO()
    public var lfo2: SamplerLFO = SamplerLFO()
    public var bioModulation: SamplerBioModulation = SamplerBioModulation()
    public var masterVolume: Float = 0.8

    // Private state
    private var voices: [SamplerVoice]
    private var sampleRate: Float = 44100
    private var roundRobinCounters: [Int: Int] = [:] // Group → current index
    private var currentBPM: Float = 120
    private var scratchBuffer: [Float]

    // Bio-reactive inputs (updated externally)
    public var hrvMs: Float = 50
    public var coherence: Float = 0.5
    public var heartRate: Float = 70
    public var breathPhase: Float = 0.5
    public var flowScore: Float = 0

    // MARK: - Init

    public init(sampleRate: Float = 44100) {
        self.sampleRate = sampleRate
        self.voices = (0..<SamplerConstants.maxVoices).map { _ in SamplerVoice() }
        self.scratchBuffer = [Float](repeating: 0, count: 4096)
    }

    // MARK: - Zone Management

    public func addZone(_ zone: SampleZone) {
        var mutableZone = zone
        if mutableZone.loopEnd == 0 {
            mutableZone.loopEnd = mutableZone.sampleData.count
        }
        zones.append(mutableZone)
    }

    public func removeZone(at index: Int) {
        guard index < zones.count else { return }
        zones.remove(at: index)
    }

    /// Load sample data from Float32 buffer with metadata
    public func loadSample(
        data: [Float],
        sampleRate: Float,
        rootNote: Int = 60,
        name: String = "Sample"
    ) -> Int {
        var zone = SampleZone(name: name, rootNote: rootNote)
        zone.sampleData = data
        zone.sampleRate = sampleRate
        zone.loopEnd = data.count
        zones.append(zone)
        return zones.count - 1
    }

    // MARK: - Note Events

    public func noteOn(note: Int, velocity: Int) {
        let vel = Float(velocity) / 127.0

        // Find matching zones
        let matchingZones = zones.enumerated().filter { $0.element.matches(note: note, velocity: velocity) }
        guard !matchingZones.isEmpty else { return }

        // Round-robin selection
        let zone: (offset: Int, element: SampleZone)
        let groups = Dictionary(grouping: matchingZones) { $0.element.roundRobinGroup }
        if let group = groups.first {
            let counter = roundRobinCounters[group.key] ?? 0
            let idx = counter % group.value.count
            zone = group.value[idx]
            roundRobinCounters[group.key] = counter + 1
        } else {
            zone = matchingZones[0]
        }

        // Allocate voice (steal oldest if needed)
        let voiceIdx = allocateVoice()

        // Calculate pitch ratio
        let semitones = Float(note - zone.element.rootNote) + zone.element.fineTune / 100.0
        let pitchRatio = Double(pow(2.0, semitones / 12.0))
            * Double(zone.element.sampleRate / sampleRate)

        voices[voiceIdx].isActive = true
        voices[voiceIdx].note = note
        voices[voiceIdx].velocity = vel
        voices[voiceIdx].zoneIndex = zone.offset
        voices[voiceIdx].position = 0
        voices[voiceIdx].pitchRatio = pitchRatio
        voices[voiceIdx].age = 0
        voices[voiceIdx].filter = ZDFFilter()
        voices[voiceIdx].filter.type = filterType
        voices[voiceIdx].ampEnvelope.noteOn()
        voices[voiceIdx].filterEnvelope.noteOn()
    }

    public func noteOff(note: Int) {
        for i in 0..<voices.count {
            if voices[i].isActive && voices[i].note == note &&
               voices[i].ampEnvelope.stage != .release {
                voices[i].ampEnvelope.noteOff()
                voices[i].filterEnvelope.noteOff()
            }
        }
    }

    public func allNotesOff() {
        for i in 0..<voices.count {
            if voices[i].isActive {
                voices[i].ampEnvelope.noteOff()
                voices[i].filterEnvelope.noteOff()
            }
        }
    }

    // MARK: - Voice Allocation

    private func allocateVoice() -> Int {
        // Find idle voice
        if let idx = voices.firstIndex(where: { !$0.isActive }) {
            return idx
        }
        // Steal oldest voice
        var oldestIdx = 0
        var oldestAge = 0
        for i in 0..<voices.count {
            if voices[i].age > oldestAge {
                oldestAge = voices[i].age
                oldestIdx = i
            }
        }
        voices[oldestIdx].reset()
        return oldestIdx
    }

    // MARK: - Render

    /// Render a buffer of samples (mono)
    public func render(frameCount: Int) -> [Float] {
        var output = [Float](repeating: 0, count: frameCount)

        // Apply bio-reactive modulation
        let bioFilterMod = hrvMs / 100.0 * bioModulation.hrvToFilterDepth
        let bioResonanceMod = coherence * bioModulation.coherenceToResonance
        let bioVolumeMod = 1.0 + (breathPhase - 0.5) * bioModulation.breathToVolume

        for i in 0..<voices.count {
            guard voices[i].isActive else { continue }
            voices[i].age += frameCount

            let zoneIdx = voices[i].zoneIndex
            guard zoneIdx < zones.count else {
                voices[i].isActive = false
                continue
            }
            let zone = zones[zoneIdx]
            guard !zone.sampleData.isEmpty else { continue }

            for frame in 0..<frameCount {
                // Amplitude envelope
                let ampLevel = voices[i].ampEnvelope.process(env: ampEnvelope, sampleRate: sampleRate)
                if voices[i].ampEnvelope.stage == .idle {
                    voices[i].isActive = false
                    break
                }

                // Filter envelope
                let filterEnvLevel = voices[i].filterEnvelope.process(env: filterEnvelope, sampleRate: sampleRate)

                // LFO
                let lfo1Val = voices[i].lfo1.process(sampleRate: sampleRate, bpm: currentBPM)

                // Interpolated sample read
                let sample = interpolateSample(voice: &voices[i], zone: zone)

                // Advance position
                voices[i].position += voices[i].pitchRatio

                // Handle loop or end
                if zone.loopEnabled {
                    if Int(voices[i].position) >= zone.loopEnd {
                        voices[i].position -= Double(zone.loopEnd - zone.loopStart)
                    }
                } else if Int(voices[i].position) >= zone.sampleData.count {
                    voices[i].isActive = false
                    break
                }

                // Filter with bio + envelope modulation
                let cutoffMod = filterCutoff
                    * (1.0 + filterEnvelopeDepth * filterEnvLevel)
                    * (1.0 + bioFilterMod)
                    * (1.0 + lfo1Val * 0.2)
                voices[i].filter.cutoff = Swift.min(cutoffMod, sampleRate * 0.49)
                voices[i].filter.resonance = Swift.min(1.0, filterResonance + bioResonanceMod)
                let filtered = voices[i].filter.process(sample, sampleRate: sampleRate)

                // Output with velocity and envelope
                output[frame] += filtered * ampLevel * voices[i].velocity * zone.gain * bioVolumeMod
            }
        }

        // Master volume
        var vol = masterVolume
        vDSP_vsmul(output, 1, &vol, &output, 1, vDSP_Length(frameCount))

        return output
    }

    // MARK: - Interpolation

    private func interpolateSample(voice: inout SamplerVoice, zone: SampleZone) -> Float {
        let pos = voice.position
        let idx = Int(pos)
        let frac = Float(pos - Double(idx))

        guard idx >= 0 && idx < zone.sampleData.count else { return 0 }

        switch interpolation {
        case .linear:
            let s0 = zone.sampleData[idx]
            let s1 = idx + 1 < zone.sampleData.count ? zone.sampleData[idx + 1] : s0
            return s0 + frac * (s1 - s0)

        case .hermite:
            // 4-point Hermite interpolation
            let im1 = idx > 0 ? idx - 1 : 0
            let i0 = idx
            let i1 = Swift.min(idx + 1, zone.sampleData.count - 1)
            let i2 = Swift.min(idx + 2, zone.sampleData.count - 1)

            let x0 = zone.sampleData[im1]
            let x1 = zone.sampleData[i0]
            let x2 = zone.sampleData[i1]
            let x3 = zone.sampleData[i2]

            let c0 = x1
            let c1 = 0.5 * (x2 - x0)
            let c2 = x0 - 2.5 * x1 + 2.0 * x2 - 0.5 * x3
            let c3 = 0.5 * (x3 - x0) + 1.5 * (x1 - x2)

            return ((c3 * frac + c2) * frac + c1) * frac + c0

        case .sinc:
            // Windowed sinc interpolation (16-point)
            var sum: Float = 0
            let taps = SamplerConstants.sincTaps
            let halfTaps = taps / 2

            for t in -halfTaps..<halfTaps {
                let sampleIdx = idx + t
                guard sampleIdx >= 0 && sampleIdx < zone.sampleData.count else { continue }

                let x = Float(t) - frac
                // Sinc function with Blackman-Harris window
                let sinc = x == 0 ? Float(1.0) : sin(.pi * x) / (.pi * x)
                let n = Float(t + halfTaps) / Float(taps)
                let window = 0.35875 - 0.48829 * cos(2.0 * .pi * n)
                    + 0.14128 * cos(4.0 * .pi * n)
                    - 0.01168 * cos(6.0 * .pi * n)

                sum += zone.sampleData[sampleIdx] * sinc * window
            }
            return sum
        }
    }

    // MARK: - Bio Update

    /// Update bio-reactive parameters from LambdaModeEngine
    public func updateBioData(hrv: Float, coherence: Float, heartRate: Float, breathPhase: Float, flow: Float) {
        self.hrvMs = hrv
        self.coherence = coherence
        self.heartRate = heartRate
        self.breathPhase = breathPhase
        self.flowScore = flow

        // Heart rate → LFO tempo sync
        if bioModulation.heartRateToTempo {
            currentBPM = heartRate
        }
    }

    // MARK: - File I/O

    /// Load sample from audio file URL (WAV, AIFF, CAF, M4A)
    /// Reads file via AVAudioFile, extracts Float32 channel data, creates zone
    public func loadFromAudioFile(
        _ url: URL,
        rootNote: Int = 60,
        name: String? = nil,
        keyRange: ClosedRange<Int>? = nil,
        velocityRange: ClosedRange<Int>? = nil
    ) throws -> Int {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw SamplerError.bufferCreationFailed
        }
        try file.read(into: buffer)

        // Extract mono float data (mix down if stereo)
        let data: [Float]
        if let channelData = buffer.floatChannelData {
            let length = Int(buffer.frameLength)
            if format.channelCount >= 2 {
                // Mix stereo to mono
                var mono = [Float](repeating: 0, count: length)
                let left = channelData[0]
                let right = channelData[1]
                for i in 0..<length {
                    mono[i] = (left[i] + right[i]) * 0.5
                }
                data = mono
            } else {
                data = Array(UnsafeBufferPointer(start: channelData[0], count: length))
            }
        } else {
            throw SamplerError.noAudioData
        }

        let zoneName = name ?? url.deletingPathExtension().lastPathComponent
        var zone = SampleZone(name: zoneName, rootNote: rootNote)
        zone.sampleData = data
        zone.sampleRate = Float(format.sampleRate)
        zone.loopEnd = data.count

        if let keyRange = keyRange {
            zone.keyRangeLow = keyRange.lowerBound
            zone.keyRangeHigh = keyRange.upperBound
        }
        if let velocityRange = velocityRange {
            zone.velocityLow = velocityRange.lowerBound
            zone.velocityHigh = velocityRange.upperBound
        }

        zones.append(zone)
        return zones.count - 1
    }

    /// Load an entire directory of samples, auto-mapping by filename
    /// Expects filenames like "C4.wav", "piano_60.wav", or just sequential naming
    public func loadSampleDirectory(_ directoryURL: URL, rootNote: Int = 36) throws -> Int {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        let audioExtensions: Set<String> = ["wav", "aif", "aiff", "caf", "m4a"]
        let audioFiles = contents
            .filter { audioExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var loadedCount = 0
        for (index, fileURL) in audioFiles.enumerated() {
            let note = detectNoteFromFilename(fileURL.lastPathComponent) ?? (rootNote + index)
            _ = try loadFromAudioFile(fileURL, rootNote: note, keyRange: note...note)
            loadedCount += 1
        }
        return loadedCount
    }

    /// Detect MIDI note from filename patterns like "C4", "Db3", "piano_60"
    private func detectNoteFromFilename(_ filename: String) -> Int? {
        let name = filename.replacingOccurrences(of: "\\.[^.]+$", with: "", options: .regularExpression)

        // Try MIDI note number: "60", "piano_60", "sample-72"
        let numberPattern = try? NSRegularExpression(pattern: "(\\d{1,3})(?:\\D|$)")
        if let match = numberPattern?.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
           let range = Range(match.range(at: 1), in: name),
           let midiNote = Int(name[range]),
           midiNote >= 0 && midiNote <= 127 {
            return midiNote
        }

        // Try note name: "C4", "Db3", "F#5"
        let noteNames = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        let notePattern = try? NSRegularExpression(pattern: "([A-Ga-g])([#b]?)(\\d)")
        if let match = notePattern?.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
           let letterRange = Range(match.range(at: 1), in: name),
           let accidentalRange = Range(match.range(at: 2), in: name),
           let octaveRange = Range(match.range(at: 3), in: name) {

            let letter = String(name[letterRange]).uppercased()
            let accidental = String(name[accidentalRange])
            let octave = Int(name[octaveRange]) ?? 4

            if let base = noteNames[letter] {
                var note = (octave + 1) * 12 + base
                if accidental == "#" { note += 1 }
                if accidental == "b" { note -= 1 }
                return note
            }
        }

        return nil
    }

    // MARK: - Synth Freeze (Synthesis → Sample Zone)

    /// Freeze a synthesis engine's output into a sampler zone
    /// Renders `duration` seconds of audio from the synth render closure, then loads as zone
    public func freezeSynthToZone(
        render: (Int) -> [Float],
        duration: Float = 2.0,
        rootNote: Int = 60,
        name: String = "Frozen Synth",
        loopEnabled: Bool = true
    ) -> Int {
        let frameCount = Int(duration * sampleRate)
        let synthOutput = render(frameCount)

        var zone = SampleZone(name: name, rootNote: rootNote)
        zone.sampleData = synthOutput
        zone.sampleRate = sampleRate
        zone.loopEnabled = loopEnabled

        if loopEnabled {
            // Find zero crossing near 80% mark for clean loop
            let searchStart = Int(Float(synthOutput.count) * 0.75)
            var loopEnd = synthOutput.count
            for i in searchStart..<synthOutput.count - 1 {
                if synthOutput[i] <= 0 && synthOutput[i + 1] > 0 {
                    loopEnd = i
                    break
                }
            }
            zone.loopStart = 0
            zone.loopEnd = loopEnd
        } else {
            zone.loopEnd = synthOutput.count
        }

        zones.append(zone)
        return zones.count - 1
    }

    /// Freeze multiple notes from a synth into a multi-sampled instrument
    /// Creates velocity-layered, round-robin zones across the keyboard
    public func freezeMultiSampled(
        render: (Int, Float, Int) -> [Float],  // (frameCount, frequency, velocity) → [Float]
        notes: [Int] = [36, 48, 60, 72, 84],   // Sample every octave
        velocityLayers: [Int] = [40, 80, 120],  // Soft, medium, hard
        duration: Float = 2.0,
        name: String = "Multi-Sample"
    ) -> Int {
        let frameCount = Int(duration * sampleRate)
        var loadedCount = 0

        for (noteIdx, note) in notes.enumerated() {
            let frequency = 440.0 * pow(2.0, Float(note - 69) / 12.0)

            // Key range: from this note to just below next sampled note
            let keyLow = noteIdx == 0 ? 0 : (notes[noteIdx - 1] + note) / 2 + 1
            let keyHigh = noteIdx == notes.count - 1 ? 127 : (note + notes[Swift.min(noteIdx + 1, notes.count - 1)]) / 2

            for (velIdx, velocity) in velocityLayers.enumerated() {
                let synthOutput = render(frameCount, frequency, velocity)

                var zone = SampleZone(name: "\(name)_\(note)_v\(velocity)", rootNote: note)
                zone.sampleData = synthOutput
                zone.sampleRate = sampleRate
                zone.keyRangeLow = keyLow
                zone.keyRangeHigh = keyHigh

                // Velocity range: divide 0-127 by layer count
                let velStep = 128 / velocityLayers.count
                zone.velocityLow = velIdx * velStep
                zone.velocityHigh = velIdx == velocityLayers.count - 1 ? 127 : (velIdx + 1) * velStep - 1

                zone.roundRobinGroup = note
                zone.roundRobinIndex = velIdx
                zone.loopEnd = synthOutput.count

                zones.append(zone)
                loadedCount += 1
            }
        }
        return loadedCount
    }

    // MARK: - Errors

    public enum SamplerError: Error, LocalizedError {
        case bufferCreationFailed
        case noAudioData
        case fileNotFound
        case unsupportedFormat

        public var errorDescription: String? {
            switch self {
            case .bufferCreationFailed: return "Failed to create audio buffer"
            case .noAudioData: return "No audio data in file"
            case .fileNotFound: return "Audio file not found"
            case .unsupportedFormat: return "Unsupported audio format"
            }
        }
    }

    // MARK: - Presets

    /// Create a basic drum kit zone layout
    public static func createDrumKit(sampleRate: Float = 44100) -> EchoelSampler {
        let sampler = EchoelSampler(sampleRate: sampleRate)
        sampler.ampEnvelope = ADSREnvelope(attack: 0.001, decay: 0.3, sustain: 0, release: 0.05)
        sampler.filterCutoff = 12000
        sampler.interpolation = .hermite
        return sampler
    }

    /// Create a melodic sampler with longer envelopes
    public static func createMelodic(sampleRate: Float = 44100) -> EchoelSampler {
        let sampler = EchoelSampler(sampleRate: sampleRate)
        sampler.ampEnvelope = ADSREnvelope(attack: 0.05, decay: 0.5, sustain: 0.7, release: 1.0)
        sampler.filterCutoff = 6000
        sampler.filterResonance = 0.2
        sampler.filterEnvelopeDepth = 0.4
        sampler.interpolation = .sinc
        return sampler
    }
}

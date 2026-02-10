import Foundation
import AVFoundation

// MARK: - Track Send

/// A send from a track to an aux/return bus (Ableton/Reaper/Pro Tools style)
struct TrackSend: Identifiable, Codable {
    let id: UUID
    var destinationID: UUID  // aux/return track ID
    var level: Float         // 0.0 to 1.0
    var isPreFader: Bool     // pre-fader = independent of track volume
    var isEnabled: Bool

    init(destinationID: UUID, level: Float = 0.5, isPreFader: Bool = false) {
        self.id = UUID()
        self.destinationID = destinationID
        self.level = level
        self.isPreFader = isPreFader
        self.isEnabled = true
    }
}

// MARK: - Track Input Source

/// Input routing for recording/monitoring (Reaper flexibility)
enum TrackInputSource: String, Codable, CaseIterable {
    case none = "None"
    case mic = "Microphone"
    case lineIn = "Line In"
    case stereoIn = "Stereo In"
    case bus = "Bus"
    case resampling = "Resampling"       // Ableton: record output of another track
    case sidechain = "Sidechain"
    case midi = "MIDI"
    case virtual = "Virtual Instrument"
}

// MARK: - Monitor Mode

/// Input monitoring mode (Ableton Live style)
enum MonitorMode: String, Codable, CaseIterable {
    case auto = "Auto"       // Monitor when armed & not playing
    case alwaysOn = "In"     // Always monitor input
    case off = "Off"         // Never monitor input
}

// MARK: - Track Color

/// Track colors for mixer/arrangement (Ableton/FL Studio palette)
enum TrackColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, cyan, blue, purple, pink
    case magenta, teal, lime, amber, indigo, rose
}

// MARK: - Track Automation Lane

/// Automation lane attached to a track (Logic/Ableton automation)
struct TrackAutomationLane: Identifiable, Codable {
    let id: UUID
    var parameter: AutomatedParameter
    var points: [AutomationPoint]
    var isVisible: Bool
    var isEnabled: Bool
    var isRecording: Bool

    init(parameter: AutomatedParameter) {
        self.id = UUID()
        self.parameter = parameter
        self.points = []
        self.isVisible = true
        self.isEnabled = true
        self.isRecording = false
    }

    /// Interpolate value at a given time
    func valueAt(time: TimeInterval) -> Float {
        guard !points.isEmpty else { return parameter.defaultValue }
        guard points.count > 1 else { return points[0].value }

        // Find surrounding points
        if time <= points[0].time { return points[0].value }
        if time >= points[points.count - 1].time { return points[points.count - 1].value }

        for i in 0..<(points.count - 1) {
            let p0 = points[i]
            let p1 = points[i + 1]
            if time >= p0.time && time <= p1.time {
                let t = Float((time - p0.time) / (p1.time - p0.time))
                switch p0.curveType {
                case .linear:
                    return p0.value + (p1.value - p0.value) * t
                case .exponential:
                    return p0.value + (p1.value - p0.value) * (t * t)
                case .logarithmic:
                    return p0.value + (p1.value - p0.value) * sqrt(t)
                case .sCurve:
                    let s = t * t * (3.0 - 2.0 * t) // smoothstep
                    return p0.value + (p1.value - p0.value) * s
                case .hold:
                    return p0.value
                }
            }
        }
        return points.last?.value ?? parameter.defaultValue
    }
}

// MARK: - Automation Point

struct AutomationPoint: Identifiable, Codable {
    let id: UUID
    var time: TimeInterval
    var value: Float      // 0.0 to 1.0 normalized
    var curveType: CurveType

    init(time: TimeInterval, value: Float, curveType: CurveType = .linear) {
        self.id = UUID()
        self.time = time
        self.value = value
        self.curveType = curveType
    }

    enum CurveType: String, Codable, CaseIterable {
        case linear, exponential, logarithmic, sCurve, hold
    }
}

// MARK: - Automated Parameter

/// Parameters that can be automated (comprehensive like Logic/Ableton)
enum AutomatedParameter: String, Codable, CaseIterable {
    case volume, pan, mute
    case sendALevel, sendBLevel, sendCLevel, sendDLevel
    case filterCutoff, filterResonance
    case reverbMix, delayMix, chorusMix
    case compThreshold, compRatio, compAttack, compRelease
    case eqLowGain, eqLowMidGain, eqHighMidGain, eqHighGain
    case eqLowFreq, eqLowMidFreq, eqHighMidFreq, eqHighFreq
    case saturationDrive, bitcrushAmount
    case pitchShift, stereoWidth
    case tempo  // for master track tempo automation

    var defaultValue: Float {
        switch self {
        case .volume: return 0.8
        case .pan: return 0.5 // center
        case .mute: return 0.0
        case .sendALevel, .sendBLevel, .sendCLevel, .sendDLevel: return 0.0
        case .filterCutoff: return 1.0
        case .filterResonance: return 0.0
        case .reverbMix, .delayMix, .chorusMix: return 0.0
        case .compThreshold: return 1.0
        case .compRatio: return 0.0
        case .compAttack: return 0.3
        case .compRelease: return 0.5
        case .eqLowGain, .eqLowMidGain, .eqHighMidGain, .eqHighGain: return 0.5
        case .eqLowFreq: return 0.1
        case .eqLowMidFreq: return 0.3
        case .eqHighMidFreq: return 0.6
        case .eqHighFreq: return 0.9
        case .saturationDrive, .bitcrushAmount: return 0.0
        case .pitchShift: return 0.5
        case .stereoWidth: return 0.5
        case .tempo: return 0.5
        }
    }

    var displayName: String {
        switch self {
        case .volume: return "Volume"
        case .pan: return "Pan"
        case .mute: return "Mute"
        case .sendALevel: return "Send A"
        case .sendBLevel: return "Send B"
        case .sendCLevel: return "Send C"
        case .sendDLevel: return "Send D"
        case .filterCutoff: return "Filter Cutoff"
        case .filterResonance: return "Filter Resonance"
        case .reverbMix: return "Reverb"
        case .delayMix: return "Delay"
        case .chorusMix: return "Chorus"
        case .compThreshold: return "Comp Threshold"
        case .compRatio: return "Comp Ratio"
        case .compAttack: return "Comp Attack"
        case .compRelease: return "Comp Release"
        case .eqLowGain: return "EQ Low"
        case .eqLowMidGain: return "EQ Low-Mid"
        case .eqHighMidGain: return "EQ High-Mid"
        case .eqHighGain: return "EQ High"
        case .eqLowFreq: return "EQ Low Freq"
        case .eqLowMidFreq: return "EQ LM Freq"
        case .eqHighMidFreq: return "EQ HM Freq"
        case .eqHighFreq: return "EQ High Freq"
        case .saturationDrive: return "Saturation"
        case .bitcrushAmount: return "Bitcrush"
        case .pitchShift: return "Pitch Shift"
        case .stereoWidth: return "Stereo Width"
        case .tempo: return "Tempo"
        }
    }
}

// MARK: - Track

/// Represents a single audio track in a recording session
/// Supports professional routing: sends, sidechain, bus output, automation
struct Track: Identifiable, Codable {
    let id: UUID
    var name: String
    var url: URL?
    var duration: TimeInterval
    var volume: Float
    var pan: Float
    var isMuted: Bool
    var isSoloed: Bool
    var effects: [String]  // Node IDs
    var waveformData: [Float]?
    var createdAt: Date
    var modifiedAt: Date

    /// Logger (computed to avoid Codable issues)
    private var log: ProfessionalLogger { ProfessionalLogger.shared }

    // MARK: - Track Type

    var type: TrackType

    enum TrackType: String, Codable {
        case audio = "Audio"
        case voice = "Voice"
        case binaural = "Binaural"
        case spatial = "Spatial"
        case master = "Master"
        case instrument = "Instrument"
        case aux = "Aux"
        case bus = "Bus"
        case send = "Send"
        case midi = "MIDI"
    }

    // MARK: - Pro Routing

    /// Send levels to aux/return tracks
    var sends: [TrackSend]

    /// Output destination bus ID (nil = master)
    var outputBusID: UUID?

    /// Input source for recording/monitoring
    var inputSource: TrackInputSource

    /// Sidechain source track ID
    var sidechainSourceID: UUID?

    /// Recording armed
    var isArmed: Bool

    /// Monitor mode (Ableton style)
    var monitorMode: MonitorMode

    /// Track color
    var trackColor: TrackColor

    /// Track group ID (linked fader groups / VCA)
    var groupID: UUID?

    /// Automation lanes
    var automationLanes: [TrackAutomationLane]

    /// Frozen state (render to audio for CPU savings)
    var isFrozen: Bool


    // MARK: - Initialization

    init(
        name: String,
        type: TrackType = .audio,
        volume: Float = 0.8,
        pan: Float = 0.0
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.url = nil
        self.duration = 0
        self.volume = volume
        self.pan = pan
        self.isMuted = false
        self.isSoloed = false
        self.effects = []
        self.waveformData = nil
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.sends = []
        self.outputBusID = nil
        self.inputSource = .none
        self.sidechainSourceID = nil
        self.isArmed = false
        self.monitorMode = .auto
        self.trackColor = .cyan
        self.groupID = nil
        self.automationLanes = []
        self.isFrozen = false
    }


    // MARK: - Audio File Management

    /// Set audio file URL for this track
    mutating func setAudioFile(_ url: URL) {
        self.url = url
        self.modifiedAt = Date()

        // Get duration from file
        if let asset = try? AVAudioFile(forReading: url) {
            self.duration = Double(asset.length) / asset.fileFormat.sampleRate
        }
    }

    /// Generate waveform data for visualization
    mutating func generateWaveform(samples: Int = 100) {
        guard let url = url else { return }

        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: frameCount
            ) else { return }

            try file.read(into: buffer)

            // Sample buffer for waveform
            guard let channelData = buffer.floatChannelData?[0] else { return }

            var waveform: [Float] = []
            let samplesPerPoint = Int(frameCount) / samples

            for i in 0..<samples {
                let startIndex = i * samplesPerPoint
                let endIndex = min(startIndex + samplesPerPoint, Int(frameCount))

                var sum: Float = 0
                for j in startIndex..<endIndex {
                    sum += abs(channelData[j])
                }

                let average = sum / Float(endIndex - startIndex)
                waveform.append(average)
            }

            self.waveformData = waveform

        } catch {
            log.error("Failed to generate waveform: \(error)", category: .recording)
        }
    }


    // MARK: - Effects Management

    mutating func addEffect(_ nodeID: String) {
        effects.append(nodeID)
        modifiedAt = Date()
    }

    mutating func removeEffect(_ nodeID: String) {
        effects.removeAll { $0 == nodeID }
        modifiedAt = Date()
    }

    // MARK: - Send Management

    mutating func addSend(to destinationID: UUID, level: Float = 0.5, preFader: Bool = false) {
        let send = TrackSend(destinationID: destinationID, level: level, isPreFader: preFader)
        sends.append(send)
        modifiedAt = Date()
    }

    mutating func removeSend(id: UUID) {
        sends.removeAll { $0.id == id }
        modifiedAt = Date()
    }

    mutating func setSendLevel(id: UUID, level: Float) {
        if let index = sends.firstIndex(where: { $0.id == id }) {
            sends[index].level = max(0, min(1, level))
            modifiedAt = Date()
        }
    }

    // MARK: - Automation Management

    mutating func addAutomationLane(for parameter: AutomatedParameter) {
        let lane = TrackAutomationLane(parameter: parameter)
        automationLanes.append(lane)
        modifiedAt = Date()
    }

    mutating func addAutomationPoint(laneID: UUID, time: TimeInterval, value: Float, curve: AutomationPoint.CurveType = .linear) {
        if let index = automationLanes.firstIndex(where: { $0.id == laneID }) {
            let point = AutomationPoint(time: time, value: value, curveType: curve)
            automationLanes[index].points.append(point)
            automationLanes[index].points.sort { $0.time < $1.time }
            modifiedAt = Date()
        }
    }

    /// Get the effective volume at a given time (with automation)
    func effectiveVolume(at time: TimeInterval) -> Float {
        if let lane = automationLanes.first(where: { $0.parameter == .volume && $0.isEnabled }) {
            return lane.valueAt(time: time)
        }
        return volume
    }

    /// Get the effective pan at a given time (with automation)
    func effectivePan(at time: TimeInterval) -> Float {
        if let lane = automationLanes.first(where: { $0.parameter == .pan && $0.isEnabled }) {
            return lane.valueAt(time: time) * 2.0 - 1.0 // convert 0-1 to -1..1
        }
        return pan
    }


    // MARK: - Playback State

    var isPlaying: Bool = false


    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id, name, url, duration, volume, pan
        case isMuted, isSoloed, effects, waveformData
        case createdAt, modifiedAt, type
        case sends, outputBusID, inputSource, sidechainSourceID
        case isArmed, monitorMode, trackColor, groupID
        case automationLanes, isFrozen
    }
}


// MARK: - Track Presets

extension Track {
    /// Create voice track preset
    static func voiceTrack() -> Track {
        var track = Track(name: "Voice", type: .voice)
        track.volume = 0.9
        track.inputSource = .mic
        track.trackColor = .orange
        return track
    }

    /// Create Multidimensional Brainwave Entrainment track
    static func binauralTrack() -> Track {
        var track = Track(name: "Multidimensional Brainwave Entrainment", type: .binaural)
        track.volume = 0.3
        track.trackColor = .purple
        return track
    }

    /// Create spatial audio track
    static func spatialTrack() -> Track {
        var track = Track(name: "Spatial", type: .spatial)
        track.volume = 0.7
        track.trackColor = .cyan
        return track
    }

    /// Create master mix track
    static func masterTrack() -> Track {
        var track = Track(name: "Master", type: .master)
        track.volume = 1.0
        track.trackColor = .red
        return track
    }

    /// Create instrument track (MIDI → Synth → Audio)
    static func instrumentTrack(name: String = "Instrument") -> Track {
        var track = Track(name: name, type: .instrument)
        track.volume = 0.8
        track.inputSource = .virtual
        track.trackColor = .green
        return track
    }

    /// Create aux/return track (for reverb, delay sends)
    static func auxTrack(name: String = "Aux") -> Track {
        var track = Track(name: name, type: .aux)
        track.volume = 0.7
        track.trackColor = .teal
        return track
    }

    /// Create bus track (for grouping/submixing)
    static func busTrack(name: String = "Bus") -> Track {
        var track = Track(name: name, type: .bus)
        track.volume = 0.9
        track.trackColor = .amber
        return track
    }

    /// Create MIDI track
    static func midiTrack(name: String = "MIDI") -> Track {
        var track = Track(name: name, type: .midi)
        track.volume = 0.8
        track.inputSource = .midi
        track.trackColor = .blue
        return track
    }

    // MARK: - Pro Session Templates

    /// Standard music production session (Logic Pro / Ableton style)
    static func proMusicSession() -> [Track] {
        let auxReverb = auxTrack(name: "Reverb Return")
        let auxDelay = auxTrack(name: "Delay Return")
        let drumBus = busTrack(name: "Drum Bus")
        let master = masterTrack()

        var kick = Track(name: "Kick", type: .audio)
        kick.trackColor = .red
        kick.outputBusID = drumBus.id

        var snare = Track(name: "Snare", type: .audio)
        snare.trackColor = .orange
        snare.outputBusID = drumBus.id

        var hihat = Track(name: "Hi-Hat", type: .audio)
        hihat.trackColor = .yellow
        hihat.outputBusID = drumBus.id

        var bass = instrumentTrack(name: "Bass")
        bass.trackColor = .blue
        bass.addSend(to: auxReverb.id, level: 0.1)
        bass.sidechainSourceID = kick.id  // sidechain to kick

        var lead = instrumentTrack(name: "Lead Synth")
        lead.trackColor = .cyan
        lead.addSend(to: auxReverb.id, level: 0.3)
        lead.addSend(to: auxDelay.id, level: 0.2)

        var pad = instrumentTrack(name: "Pad")
        pad.trackColor = .purple
        pad.addSend(to: auxReverb.id, level: 0.5)

        var vocals = Track(name: "Vocals", type: .voice)
        vocals.trackColor = .pink
        vocals.inputSource = .mic
        vocals.addSend(to: auxReverb.id, level: 0.2)
        vocals.addSend(to: auxDelay.id, level: 0.15)

        return [kick, snare, hihat, bass, lead, pad, vocals, drumBus, auxReverb, auxDelay, master]
    }

    /// DJ session with 2 decks + effects
    static func djSession() -> [Track] {
        var deckA = Track(name: "Deck A", type: .audio)
        deckA.trackColor = .cyan
        var deckB = Track(name: "Deck B", type: .audio)
        deckB.trackColor = .pink
        let fxReturn = auxTrack(name: "FX Return")
        let master = masterTrack()

        deckA.addSend(to: fxReturn.id, level: 0.0)
        deckB.addSend(to: fxReturn.id, level: 0.0)

        return [deckA, deckB, fxReturn, master]
    }

    /// Live performance session with bio-reactive routing
    static func livePerformanceSession() -> [Track] {
        let auxReverb = auxTrack(name: "Reverb")
        let auxDelay = auxTrack(name: "Delay")

        var synth1 = instrumentTrack(name: "Synth 1")
        synth1.addSend(to: auxReverb.id, level: 0.3)

        var synth2 = instrumentTrack(name: "Synth 2")
        synth2.addSend(to: auxDelay.id, level: 0.2)

        var drums = Track(name: "Drums", type: .audio)
        drums.trackColor = .red

        var bio = Track(name: "Bio-Reactive", type: .spatial)
        bio.trackColor = TrackColor.green
        bio.addSend(to: auxReverb.id, level: 0.4)

        var vocals = Track(name: "Vocals", type: .voice)
        vocals.inputSource = .mic
        vocals.addSend(to: auxReverb.id, level: 0.2)

        let master = masterTrack()

        return [synth1, synth2, drums, bio, vocals, auxReverb, auxDelay, master]
    }
}

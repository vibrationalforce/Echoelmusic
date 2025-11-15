// Track.swift
// Timeline Track - Audio, MIDI, Video, Automation
//
// Universal Track System das Audio (Reaper), MIDI (Ableton), Video (DaVinci)
// und Automation auf einer Timeline vereint

import Foundation
import AVFoundation
import SwiftUI

/// Track type
enum TrackType: String, Codable, CaseIterable {
    case audio          // Audio track (WAV, MP3, etc.)
    case midi           // MIDI/instrument track
    case video          // Video track
    case automation     // Automation track
    case group          // Group/bus track
    case master         // Master output track
}

/// Track in timeline
class Track: ObservableObject, Identifiable, Codable {

    // MARK: - Properties

    let id: UUID
    var name: String
    var type: TrackType
    var color: TrackColor

    /// Parent timeline (weak to avoid retain cycle)
    weak var timeline: Timeline?

    /// Clips on this track
    @Published var clips: [Clip]

    /// Track volume (0.0 - 1.0)
    @Published var volume: Float

    /// Track pan (-1.0 left, 0.0 center, 1.0 right)
    @Published var pan: Float

    /// Track muted
    @Published var isMuted: Bool

    /// Track soloed
    @Published var isSoloed: Bool

    /// Track armed for recording
    @Published var isArmed: Bool

    /// Track height in UI (pixels)
    var height: CGFloat

    /// Track input source (for recording)
    var inputSource: InputSource?

    /// Track output routing
    var outputRouting: OutputRouting

    /// Effect inserts (for audio/MIDI tracks)
    var effectInserts: [EffectInsert]

    /// Automation envelopes
    var automationEnvelopes: [AutomationEnvelope]

    /// MIDI channel (for MIDI tracks)
    var midiChannel: Int?

    /// Video track settings
    var videoSettings: VideoTrackSettings?

    /// Created date
    let createdAt: Date

    /// Last modified
    var modifiedAt: Date


    // MARK: - Initialization

    init(
        name: String,
        type: TrackType,
        color: TrackColor = .gray
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.color = color
        self.clips = []
        self.volume = 0.8
        self.pan = 0.0
        self.isMuted = false
        self.isSoloed = false
        self.isArmed = false
        self.height = 120
        self.outputRouting = .master
        self.effectInserts = []
        self.automationEnvelopes = []
        self.createdAt = Date()
        self.modifiedAt = Date()
    }


    // MARK: - Clip Management

    /// Add clip to track
    func addClip(_ clip: Clip) {
        // Check for overlaps
        if let overlap = clips.first(where: { $0.overlaps(with: clip) }) {
            print("⚠️ Clip overlaps with existing clip: \(overlap.name)")
            // Handle overlap (split, replace, or reject)
        }

        clips.append(clip)
        clips.sort { $0.startPosition < $1.startPosition }
        clip.track = self
        modifiedAt = Date()
    }

    /// Remove clip
    func removeClip(_ clip: Clip) {
        clips.removeAll { $0.id == clip.id }
        modifiedAt = Date()
    }

    /// Get clip at position
    func clip(at position: Int64) -> Clip? {
        clips.first { clip in
            position >= clip.startPosition && position < clip.endPosition
        }
    }

    /// Split clip at position
    func splitClip(_ clip: Clip, at position: Int64) {
        guard position > clip.startPosition && position < clip.endPosition else { return }

        // Create new clip for second half
        let newClip = clip.split(at: position)
        addClip(newClip)
    }

    /// Merge adjacent clips
    func mergeClips(_ clip1: Clip, _ clip2: Clip) {
        guard clip1.endPosition == clip2.startPosition else { return }
        // TODO: Implement clip merging
    }


    // MARK: - Audio Processing

    /// Render track audio at position
    func render(at position: Int64, frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard type == .audio || type == .midi else { return nil }
        guard let clip = clip(at: position) else { return nil }

        var buffer = clip.render(at: position, frameCount: frameCount)

        // Apply volume
        if let buffer = buffer {
            applyVolume(to: buffer, volume: volume)
        }

        // Apply pan
        if let buffer = buffer {
            applyPan(to: buffer, pan: pan)
        }

        // Apply effects
        for effect in effectInserts where effect.isEnabled {
            buffer = effect.process(buffer: buffer)
        }

        return buffer
    }

    private func applyVolume(to buffer: AVAudioPCMBuffer, volume: Float) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0..<channelCount {
            var samples = channelData[channel]
            for frame in 0..<frameCount {
                samples[frame] *= volume
            }
        }
    }

    private func applyPan(to buffer: AVAudioPCMBuffer, pan: Float) {
        guard buffer.format.channelCount == 2 else { return }
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)

        let leftGain = pan <= 0 ? 1.0 : 1.0 - pan
        let rightGain = pan >= 0 ? 1.0 : 1.0 + pan

        var leftSamples = channelData[0]
        var rightSamples = channelData[1]

        for frame in 0..<frameCount {
            leftSamples[frame] *= leftGain
            rightSamples[frame] *= rightGain
        }
    }


    // MARK: - Automation

    /// Add automation envelope
    func addAutomationEnvelope(parameter: AutomationParameter) {
        let envelope = AutomationEnvelope(parameter: parameter)
        automationEnvelopes.append(envelope)
    }

    /// Get automation value at position
    func automationValue(for parameter: AutomationParameter, at position: Int64) -> Float? {
        guard let envelope = automationEnvelopes.first(where: { $0.parameter == parameter }) else {
            return nil
        }
        return envelope.value(at: position)
    }


    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, type, color, clips, volume, pan, height
        case inputSource, outputRouting, effectInserts, automationEnvelopes
        case midiChannel, videoSettings, createdAt, modifiedAt
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(TrackType.self, forKey: .type)
        color = try container.decode(TrackColor.self, forKey: .color)
        clips = try container.decode([Clip].self, forKey: .clips)
        volume = try container.decode(Float.self, forKey: .volume)
        pan = try container.decode(Float.self, forKey: .pan)
        height = try container.decode(CGFloat.self, forKey: .height)
        inputSource = try container.decodeIfPresent(InputSource.self, forKey: .inputSource)
        outputRouting = try container.decode(OutputRouting.self, forKey: .outputRouting)
        effectInserts = try container.decode([EffectInsert].self, forKey: .effectInserts)
        automationEnvelopes = try container.decode([AutomationEnvelope].self, forKey: .automationEnvelopes)
        midiChannel = try container.decodeIfPresent(Int.self, forKey: .midiChannel)
        videoSettings = try container.decodeIfPresent(VideoTrackSettings.self, forKey: .videoSettings)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)

        // Published properties
        isMuted = false
        isSoloed = false
        isArmed = false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(color, forKey: .color)
        try container.encode(clips, forKey: .clips)
        try container.encode(volume, forKey: .volume)
        try container.encode(pan, forKey: .pan)
        try container.encode(height, forKey: .height)
        try container.encodeIfPresent(inputSource, forKey: .inputSource)
        try container.encode(outputRouting, forKey: .outputRouting)
        try container.encode(effectInserts, forKey: .effectInserts)
        try container.encode(automationEnvelopes, forKey: .automationEnvelopes)
        try container.encodeIfPresent(midiChannel, forKey: .midiChannel)
        try container.encodeIfPresent(videoSettings, forKey: .videoSettings)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
    }
}


// MARK: - Supporting Types

/// Track color
enum TrackColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, pink, gray, brown
}

/// Input source for recording
enum InputSource: Codable {
    case microphone
    case lineIn
    case midi(channel: Int)
    case resampling(trackID: UUID)
}

/// Output routing
enum OutputRouting: Codable {
    case master
    case group(trackID: UUID)
    case external(deviceID: String)
}

/// Effect insert
struct EffectInsert: Codable, Identifiable {
    let id: UUID
    var name: String
    var effectType: EffectType
    var isEnabled: Bool
    var parameters: [String: Float]

    func process(buffer: AVAudioPCMBuffer?) -> AVAudioPCMBuffer? {
        // TODO: Implement effect processing
        return buffer
    }
}

/// Effect types
enum EffectType: String, Codable {
    case reverb, delay, compressor, eq, filter, distortion, chorus, flanger, phaser
}

/// Video track settings
struct VideoTrackSettings: Codable {
    var resolution: CGSize
    var frameRate: Double
    var codec: String
    var compositeMode: CompositeMode
}

enum CompositeMode: String, Codable {
    case normal, add, multiply, screen, overlay
}

/// Automation envelope
struct AutomationEnvelope: Codable {
    let id: UUID
    var parameter: AutomationParameter
    var points: [AutomationPoint]
    var interpolation: InterpolationType

    init(parameter: AutomationParameter) {
        self.id = UUID()
        self.parameter = parameter
        self.points = []
        self.interpolation = .linear
    }

    /// Get interpolated value at position
    func value(at position: Int64) -> Float {
        guard !points.isEmpty else { return 0.0 }

        // Find surrounding points
        let before = points.last { $0.position <= position }
        let after = points.first { $0.position > position }

        guard let before = before else { return points.first!.value }
        guard let after = after else { return points.last!.value }

        // Interpolate
        let range = after.position - before.position
        let offset = position - before.position
        let t = Float(offset) / Float(range)

        switch interpolation {
        case .step:
            return before.value
        case .linear:
            return before.value + (after.value - before.value) * t
        case .bezier:
            // TODO: Implement bezier interpolation
            return before.value + (after.value - before.value) * t
        }
    }
}

/// Automation point
struct AutomationPoint: Codable {
    var position: Int64     // Position in samples
    var value: Float        // Parameter value
}

/// Automation parameter
enum AutomationParameter: String, Codable {
    case volume, pan, sendLevel, filterCutoff, filterResonance, reverbMix
}

/// Automation interpolation type
enum InterpolationType: String, Codable {
    case step, linear, bezier
}


// MARK: - Clip Extension

extension Clip {
    /// Check if this clip overlaps with another
    func overlaps(with other: Clip) -> Bool {
        !(self.endPosition <= other.startPosition || self.startPosition >= other.endPosition)
    }

    /// Split clip at position
    func split(at position: Int64) -> Clip {
        let newClip = Clip(
            name: "\(name) (2)",
            type: type,
            startPosition: position,
            duration: endPosition - position
        )

        // Copy properties
        newClip.sourceURL = sourceURL
        newClip.sourceOffset = sourceOffset + (position - startPosition)
        newClip.color = color

        // Adjust original clip
        duration = position - startPosition

        return newClip
    }
}

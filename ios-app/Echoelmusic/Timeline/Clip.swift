// Clip.swift
// Timeline Clip - Audio, MIDI, Video Clips
//
// Universal Clip System das Audio (WAV, MP3), MIDI und Video auf Timeline vereint

import Foundation
import AVFoundation
import SwiftUI

/// Clip type
enum ClipType: String, Codable, CaseIterable {
    case audio          // Audio clip (WAV, MP3, etc.)
    case midi           // MIDI clip
    case video          // Video clip
    case pattern        // Pattern clip (for loops/sequences)
}

/// Clip on timeline
class Clip: ObservableObject, Identifiable, Codable {

    // MARK: - Properties

    let id: UUID
    var name: String
    var type: ClipType
    var color: ClipColor

    /// Parent track (weak to avoid retain cycle)
    weak var track: Track?

    /// Timeline position (in samples)
    @Published var startPosition: Int64

    /// Duration on timeline (in samples)
    @Published var duration: Int64

    /// End position (computed)
    var endPosition: Int64 {
        startPosition + duration
    }

    /// Source file URL (for audio/video clips)
    var sourceURL: URL?

    /// Offset into source file (in samples)
    /// Allows using portions of audio/video files
    var sourceOffset: Int64

    /// Source duration (total length of source file)
    var sourceDuration: Int64?

    /// Loop enabled
    var isLooped: Bool

    /// Loop count (0 = infinite)
    var loopCount: Int

    /// Fade in duration (samples)
    var fadeInDuration: Int64

    /// Fade out duration (samples)
    var fadeOutDuration: Int64

    /// Playback gain (0.0 - 2.0, 1.0 = unity)
    @Published var gain: Float

    /// Pitch shift (semitones, -24 to +24)
    var pitchShift: Float

    /// Time stretch ratio (0.5 = half speed, 2.0 = double speed)
    var timeStretchRatio: Float

    /// Reverse playback
    var isReversed: Bool

    /// Muted
    @Published var isMuted: Bool

    /// Locked (prevents editing)
    var isLocked: Bool

    /// MIDI data (for MIDI clips)
    var midiData: MIDIClipData?

    /// Video composition settings
    var videoSettings: VideoClipSettings?

    /// Created date
    let createdAt: Date

    /// Last modified
    var modifiedAt: Date


    // MARK: - Initialization

    init(
        name: String,
        type: ClipType,
        startPosition: Int64,
        duration: Int64,
        color: ClipColor = .blue
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.color = color
        self.startPosition = startPosition
        self.duration = duration
        self.sourceOffset = 0
        self.isLooped = false
        self.loopCount = 0
        self.fadeInDuration = 0
        self.fadeOutDuration = 0
        self.gain = 1.0
        self.pitchShift = 0.0
        self.timeStretchRatio = 1.0
        self.isReversed = false
        self.isMuted = false
        self.isLocked = false
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    /// Initialize audio clip from file
    static func audioClip(
        name: String,
        sourceURL: URL,
        startPosition: Int64,
        sampleRate: Double
    ) -> Clip? {
        // Load audio file to get duration
        guard let audioFile = try? AVAudioFile(forReading: sourceURL) else {
            print("⚠️ Failed to load audio file: \(sourceURL.lastPathComponent)")
            return nil
        }

        let sourceDuration = audioFile.length
        let clip = Clip(
            name: name,
            type: .audio,
            startPosition: startPosition,
            duration: sourceDuration
        )
        clip.sourceURL = sourceURL
        clip.sourceDuration = sourceDuration

        return clip
    }

    /// Initialize MIDI clip
    static func midiClip(
        name: String,
        startPosition: Int64,
        duration: Int64
    ) -> Clip {
        let clip = Clip(
            name: name,
            type: .midi,
            startPosition: startPosition,
            duration: duration,
            color: .green
        )
        clip.midiData = MIDIClipData()
        return clip
    }

    /// Initialize video clip from file
    static func videoClip(
        name: String,
        sourceURL: URL,
        startPosition: Int64,
        sampleRate: Double
    ) -> Clip? {
        // Load video file to get duration
        let asset = AVAsset(url: sourceURL)
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        let durationSamples = Int64(durationSeconds * sampleRate)

        let clip = Clip(
            name: name,
            type: .video,
            startPosition: startPosition,
            duration: durationSamples,
            color: .purple
        )
        clip.sourceURL = sourceURL
        clip.sourceDuration = durationSamples
        clip.videoSettings = VideoClipSettings()

        return clip
    }


    // MARK: - Audio Rendering

    /// Render audio for this clip at given position
    func render(at position: Int64, frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard !isMuted else { return nil }
        guard position >= startPosition && position < endPosition else { return nil }

        switch type {
        case .audio:
            return renderAudio(at: position, frameCount: frameCount)
        case .midi:
            return renderMIDI(at: position, frameCount: frameCount)
        case .video:
            return renderVideoAudio(at: position, frameCount: frameCount)
        case .pattern:
            return nil  // TODO: Pattern rendering
        }
    }

    private func renderAudio(at position: Int64, frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard let sourceURL = sourceURL else { return nil }
        guard let audioFile = try? AVAudioFile(forReading: sourceURL) else { return nil }

        // Calculate position in source file
        let clipOffset = position - startPosition
        var sourcePosition = sourceOffset + clipOffset

        // Handle looping
        if isLooped, let sourceDuration = sourceDuration {
            sourcePosition = sourcePosition % sourceDuration
        }

        // Check bounds
        guard sourcePosition >= 0 && sourcePosition < audioFile.length else { return nil }

        // Create buffer
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: frameCount
        ) else { return nil }

        // Read from file
        audioFile.framePosition = sourcePosition
        do {
            try audioFile.read(into: buffer, frameCount: frameCount)
        } catch {
            print("⚠️ Audio read error: \(error)")
            return nil
        }

        // Apply gain
        applyGain(to: buffer, gain: gain)

        // Apply fades
        applyFades(to: buffer, at: position)

        // Apply pitch shift (if needed)
        if pitchShift != 0.0 {
            // TODO: Implement pitch shifting with AVAudioUnitTimePitch
        }

        // Apply time stretch (if needed)
        if timeStretchRatio != 1.0 {
            // TODO: Implement time stretching
        }

        // Apply reverse (if needed)
        if isReversed {
            reverseBuffer(buffer)
        }

        return buffer
    }

    private func renderMIDI(at position: Int64, frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        // TODO: MIDI rendering (trigger notes, synthesize)
        // This will integrate with MIDI engine
        return nil
    }

    private func renderVideoAudio(at position: Int64, frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        // TODO: Extract audio from video file
        // Similar to renderAudio but from video track
        return nil
    }


    // MARK: - Audio Processing

    private func applyGain(to buffer: AVAudioPCMBuffer, gain: Float) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0..<channelCount {
            var samples = channelData[channel]
            for frame in 0..<frameLength {
                samples[frame] *= gain
            }
        }
    }

    private func applyFades(to buffer: AVAudioPCMBuffer, at position: Int64) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        let clipOffset = position - startPosition

        // Fade in
        if fadeInDuration > 0 && clipOffset < fadeInDuration {
            for frame in 0..<frameLength {
                let samplePosition = clipOffset + Int64(frame)
                if samplePosition < fadeInDuration {
                    let fadeGain = Float(samplePosition) / Float(fadeInDuration)
                    for channel in 0..<channelCount {
                        channelData[channel][frame] *= fadeGain
                    }
                }
            }
        }

        // Fade out
        if fadeOutDuration > 0 {
            let fadeOutStart = duration - fadeOutDuration
            if clipOffset >= fadeOutStart {
                for frame in 0..<frameLength {
                    let samplePosition = clipOffset + Int64(frame)
                    if samplePosition >= fadeOutStart {
                        let fadeProgress = Float(samplePosition - fadeOutStart) / Float(fadeOutDuration)
                        let fadeGain = 1.0 - fadeProgress
                        for channel in 0..<channelCount {
                            channelData[channel][frame] *= fadeGain
                        }
                    }
                }
            }
        }
    }

    private func reverseBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0..<channelCount {
            var samples = channelData[channel]
            for i in 0..<(frameLength / 2) {
                let temp = samples[i]
                samples[i] = samples[frameLength - 1 - i]
                samples[frameLength - 1 - i] = temp
            }
        }
    }


    // MARK: - Clip Operations

    /// Move clip to new position
    func move(to position: Int64) {
        startPosition = position
        modifiedAt = Date()
    }

    /// Resize clip (change duration)
    func resize(newDuration: Int64) {
        guard newDuration > 0 else { return }

        // Clamp to source duration if not looped
        if let sourceDuration = sourceDuration, !isLooped {
            duration = min(newDuration, sourceDuration - sourceOffset)
        } else {
            duration = newDuration
        }

        modifiedAt = Date()
    }

    /// Trim start (adjust sourceOffset)
    func trimStart(by samples: Int64) {
        guard let sourceDuration = sourceDuration else { return }

        let newOffset = sourceOffset + samples
        guard newOffset >= 0 && newOffset < sourceDuration else { return }

        sourceOffset = newOffset
        startPosition += samples
        duration -= samples

        modifiedAt = Date()
    }

    /// Trim end (adjust duration)
    func trimEnd(by samples: Int64) {
        let newDuration = duration - samples
        guard newDuration > 0 else { return }

        duration = newDuration
        modifiedAt = Date()
    }

    /// Duplicate clip
    func duplicate() -> Clip {
        let newClip = Clip(
            name: "\(name) (copy)",
            type: type,
            startPosition: endPosition,  // Place after original
            duration: duration,
            color: color
        )

        newClip.sourceURL = sourceURL
        newClip.sourceOffset = sourceOffset
        newClip.sourceDuration = sourceDuration
        newClip.isLooped = isLooped
        newClip.loopCount = loopCount
        newClip.fadeInDuration = fadeInDuration
        newClip.fadeOutDuration = fadeOutDuration
        newClip.gain = gain
        newClip.pitchShift = pitchShift
        newClip.timeStretchRatio = timeStretchRatio
        newClip.isReversed = isReversed
        newClip.midiData = midiData
        newClip.videoSettings = videoSettings

        return newClip
    }


    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, type, color, startPosition, duration
        case sourceURL, sourceOffset, sourceDuration
        case isLooped, loopCount, fadeInDuration, fadeOutDuration
        case gain, pitchShift, timeStretchRatio, isReversed
        case isMuted, isLocked, midiData, videoSettings
        case createdAt, modifiedAt
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(ClipType.self, forKey: .type)
        color = try container.decode(ClipColor.self, forKey: .color)
        startPosition = try container.decode(Int64.self, forKey: .startPosition)
        duration = try container.decode(Int64.self, forKey: .duration)
        sourceURL = try container.decodeIfPresent(URL.self, forKey: .sourceURL)
        sourceOffset = try container.decode(Int64.self, forKey: .sourceOffset)
        sourceDuration = try container.decodeIfPresent(Int64.self, forKey: .sourceDuration)
        isLooped = try container.decode(Bool.self, forKey: .isLooped)
        loopCount = try container.decode(Int.self, forKey: .loopCount)
        fadeInDuration = try container.decode(Int64.self, forKey: .fadeInDuration)
        fadeOutDuration = try container.decode(Int64.self, forKey: .fadeOutDuration)
        gain = try container.decode(Float.self, forKey: .gain)
        pitchShift = try container.decode(Float.self, forKey: .pitchShift)
        timeStretchRatio = try container.decode(Float.self, forKey: .timeStretchRatio)
        isReversed = try container.decode(Bool.self, forKey: .isReversed)
        isMuted = try container.decode(Bool.self, forKey: .isMuted)
        isLocked = try container.decode(Bool.self, forKey: .isLocked)
        midiData = try container.decodeIfPresent(MIDIClipData.self, forKey: .midiData)
        videoSettings = try container.decodeIfPresent(VideoClipSettings.self, forKey: .videoSettings)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(color, forKey: .color)
        try container.encode(startPosition, forKey: .startPosition)
        try container.encode(duration, forKey: .duration)
        try container.encodeIfPresent(sourceURL, forKey: .sourceURL)
        try container.encode(sourceOffset, forKey: .sourceOffset)
        try container.encodeIfPresent(sourceDuration, forKey: .sourceDuration)
        try container.encode(isLooped, forKey: .isLooped)
        try container.encode(loopCount, forKey: .loopCount)
        try container.encode(fadeInDuration, forKey: .fadeInDuration)
        try container.encode(fadeOutDuration, forKey: .fadeOutDuration)
        try container.encode(gain, forKey: .gain)
        try container.encode(pitchShift, forKey: .pitchShift)
        try container.encode(timeStretchRatio, forKey: .timeStretchRatio)
        try container.encode(isReversed, forKey: .isReversed)
        try container.encode(isMuted, forKey: .isMuted)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encodeIfPresent(midiData, forKey: .midiData)
        try container.encodeIfPresent(videoSettings, forKey: .videoSettings)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
    }
}


// MARK: - Supporting Types

/// Clip color
enum ClipColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, pink, gray, brown
}

/// MIDI clip data
struct MIDIClipData: Codable {
    var notes: [MIDINote]
    var controlChanges: [MIDIControlChange]
    var programChanges: [MIDIProgramChange]

    init() {
        self.notes = []
        self.controlChanges = []
        self.programChanges = []
    }
}

/// MIDI note
struct MIDINote: Codable, Identifiable {
    let id: UUID
    var position: Int64      // Position in samples
    var duration: Int64      // Duration in samples
    var noteNumber: UInt8    // 0-127
    var velocity: UInt8      // 0-127
    var channel: UInt8       // 0-15

    init(position: Int64, duration: Int64, noteNumber: UInt8, velocity: UInt8, channel: UInt8 = 0) {
        self.id = UUID()
        self.position = position
        self.duration = duration
        self.noteNumber = noteNumber
        self.velocity = velocity
        self.channel = channel
    }
}

/// MIDI control change
struct MIDIControlChange: Codable, Identifiable {
    let id: UUID
    var position: Int64      // Position in samples
    var controller: UInt8    // CC number (0-127)
    var value: UInt8         // CC value (0-127)
    var channel: UInt8       // 0-15

    init(position: Int64, controller: UInt8, value: UInt8, channel: UInt8 = 0) {
        self.id = UUID()
        self.position = position
        self.controller = controller
        self.value = value
        self.channel = channel
    }
}

/// MIDI program change
struct MIDIProgramChange: Codable, Identifiable {
    let id: UUID
    var position: Int64      // Position in samples
    var program: UInt8       // Program number (0-127)
    var channel: UInt8       // 0-15

    init(position: Int64, program: UInt8, channel: UInt8 = 0) {
        self.id = UUID()
        self.position = position
        self.program = program
        self.channel = channel
    }
}

/// Video clip settings
struct VideoClipSettings: Codable {
    var opacity: Float = 1.0
    var blendMode: VideoBlendMode = .normal
    var chromaKey: ChromaKeySettings?
    var transform: VideoTransform = VideoTransform()
    var colorCorrection: ColorCorrection?
}

/// Video blend mode
enum VideoBlendMode: String, Codable {
    case normal, add, multiply, screen, overlay, difference
}

/// Chroma key settings
struct ChromaKeySettings: Codable {
    var enabled: Bool = false
    var keyColor: CodableColor
    var threshold: Float = 0.2
    var smoothness: Float = 0.1
}

/// Video transform
struct VideoTransform: Codable {
    var scale: CGFloat = 1.0
    var rotation: CGFloat = 0.0  // Degrees
    var position: CGPoint = .zero
}

/// Color correction
struct ColorCorrection: Codable {
    var brightness: Float = 0.0    // -1.0 to 1.0
    var contrast: Float = 1.0      // 0.0 to 2.0
    var saturation: Float = 1.0    // 0.0 to 2.0
    var hue: Float = 0.0           // -180 to 180 degrees
}

/// Codable color
struct CodableColor: Codable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    static var green: CodableColor {
        CodableColor(red: 0, green: 1, blue: 0, alpha: 1)
    }
}


// MARK: - Clip Extensions

extension Clip {
    /// Get human-readable duration
    func durationString(sampleRate: Double) -> String {
        let seconds = Double(duration) / sampleRate
        let minutes = Int(seconds / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)

        if minutes > 0 {
            return String(format: "%d:%02d.%03d", minutes, secs, ms)
        } else {
            return String(format: "%d.%03d s", secs, ms)
        }
    }

    /// Get clip description
    var description: String {
        "\(name) [\(type.rawValue)] @ \(startPosition)"
    }
}

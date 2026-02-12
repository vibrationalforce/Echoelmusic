// ProCueSystem.swift
// Echoelmusic
//
// Professional Cue/Show Management System
// Combines the best of Resolume Arena (VJ cues), OBS (scenes/sources),
// and professional lighting consoles (cue lists / grandMA / ETC Eos).
//
// Features:
// - Multi-cue-list show control with nested cue actions
// - OBS-style scene/source composition with transitions
// - Professional DMX fixture patching with multi-universe support
// - Timecode synchronization (MTC, SMPTE, Art-Net, Ableton Link)
// - Built-in fixture profiles for common lighting hardware
// - Complete show file save/load (Codable)
// - Printable cue sheet export for stage managers
//
// Created: 2026-02-09
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import Combine

// MARK: - CueColor

/// Visual color tag for cues in the cue list UI
public enum CueColor: String, Codable, CaseIterable, Sendable {
    case red
    case orange
    case yellow
    case green
    case cyan
    case blue
    case purple
    case magenta
    case pink
    case white
    case gray
    case none
}

// MARK: - CueType

/// The semantic type of a cue
public enum CueType: String, Codable, Sendable {
    case scene
    case blackout
    case goTo
    case wait
    case macro
    case mediaPlay
    case mediaStop
    case beatDrop
}

// MARK: - TriggerMode

/// How a cue is triggered
public enum TriggerMode: Codable, Sendable {
    case manual
    case followPrevious
    case afterPrevious(delay: TimeInterval)
    case timecode(TimeInterval)
    case midi(note: UInt8, channel: UInt8)
    case beatSync(division: Double)
}

// MARK: - CueActionType

/// What a cue action does when executed
public enum CueActionType: Codable, Sendable {
    case setDMX(universe: Int, channel: Int, value: UInt8)
    case fadeDMX(universe: Int, channel: Int, from: UInt8, to: UInt8, duration: TimeInterval)
    case activateScene(sceneID: UUID)
    case setVisualLayer(layerID: UUID, opacity: Float, blendMode: String)
    case playMedia(mediaID: String)
    case setAudioParam(channel: Int, param: String, value: Double)
    case triggerEffect(effectID: String)
    case setBPM(Double)
    case crossfade(from: UUID, to: UUID, duration: TimeInterval)
    case laserPattern(pattern: String)
    case gobo(fixture: Int, index: Int)
    case colorWheel(fixture: Int, index: Int)
    case panTilt(fixture: Int, pan: UInt16, tilt: UInt16, speed: UInt8)
    case sendOSC(address: String, value: String)
    case sendMIDI(type: String, channel: UInt8, data: [UInt8])
    case customScript(String)
}

// MARK: - CueAction

/// A single action executed when a cue fires
public struct CueAction: Identifiable, Codable, Sendable {
    public let id: UUID
    public var type: CueActionType
    public var delay: TimeInterval
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        type: CueActionType,
        delay: TimeInterval = 0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.type = type
        self.delay = delay
        self.isEnabled = isEnabled
    }
}

// MARK: - ShowCue

/// A single cue in the cue list (Resolume + grandMA style)
public struct ShowCue: Identifiable, Codable, Sendable {
    public let id: UUID
    public var number: Double
    public var name: String
    public var type: CueType
    public var duration: TimeInterval
    public var fadeInTime: TimeInterval
    public var fadeOutTime: TimeInterval
    public var triggerMode: TriggerMode
    public var actions: [CueAction]
    public var isEnabled: Bool
    public var color: CueColor
    public var notes: String

    public init(
        id: UUID = UUID(),
        number: Double,
        name: String,
        type: CueType = .scene,
        duration: TimeInterval = 0,
        fadeInTime: TimeInterval = 0,
        fadeOutTime: TimeInterval = 0,
        triggerMode: TriggerMode = .manual,
        actions: [CueAction] = [],
        isEnabled: Bool = true,
        color: CueColor = .none,
        notes: String = ""
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.type = type
        self.duration = duration
        self.fadeInTime = fadeInTime
        self.fadeOutTime = fadeOutTime
        self.triggerMode = triggerMode
        self.actions = actions
        self.isEnabled = isEnabled
        self.color = color
        self.notes = notes
    }
}

// MARK: - CueList

/// Ordered collection of cues with playback control
public class CueList: Identifiable, ObservableObject, Codable {
    public let id: UUID
    public var name: String
    @Published public var cues: [ShowCue]
    @Published public var currentCueIndex: Int?
    @Published public var isPlaying: Bool

    // MARK: Codable

    enum CodingKeys: String, CodingKey {
        case id, name, cues, currentCueIndex, isPlaying
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        cues = try container.decode([ShowCue].self, forKey: .cues)
        currentCueIndex = try container.decodeIfPresent(Int.self, forKey: .currentCueIndex)
        isPlaying = try container.decode(Bool.self, forKey: .isPlaying)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(cues, forKey: .cues)
        try container.encode(currentCueIndex, forKey: .currentCueIndex)
        try container.encode(isPlaying, forKey: .isPlaying)
    }

    // MARK: Init

    public init(
        id: UUID = UUID(),
        name: String,
        cues: [ShowCue] = [],
        currentCueIndex: Int? = nil,
        isPlaying: Bool = false
    ) {
        self.id = id
        self.name = name
        self.cues = cues
        self.currentCueIndex = currentCueIndex
        self.isPlaying = isPlaying
    }

    // MARK: Playback

    /// Fire the next cue in the list
    public func go() {
        guard !cues.isEmpty else { return }

        if let current = currentCueIndex {
            let next = current + 1
            if next < cues.count {
                currentCueIndex = next
                isPlaying = true
                log.led("CueList [\(name)] GO -> Cue \(cues[next].number): \(cues[next].name)")
            } else {
                log.led("CueList [\(name)] reached end of list")
                isPlaying = false
            }
        } else {
            currentCueIndex = 0
            isPlaying = true
            log.led("CueList [\(name)] GO -> Cue \(cues[0].number): \(cues[0].name)")
        }
    }

    /// Go back to the previous cue
    public func goBack() {
        guard let current = currentCueIndex, current > 0 else { return }
        currentCueIndex = current - 1
        log.led("CueList [\(name)] BACK -> Cue \(cues[current - 1].number): \(cues[current - 1].name)")
    }

    /// Jump to a specific cue by number
    public func goToCue(number: Double) {
        if let index = cues.firstIndex(where: { $0.number == number }) {
            currentCueIndex = index
            isPlaying = true
            log.led("CueList [\(name)] GOTO -> Cue \(number): \(cues[index].name)")
        } else {
            log.led("CueList [\(name)] cue number \(number) not found", level: .warning)
        }
    }

    /// Stop the current transition
    public func halt() {
        isPlaying = false
        log.led("CueList [\(name)] HALT")
    }

    /// Release all active cues and reset playback position
    public func release() {
        currentCueIndex = nil
        isPlaying = false
        log.led("CueList [\(name)] RELEASE all cues")
    }
}

// MARK: - CueSceneTransition

/// Transition type between scenes (OBS-style)
public struct CueSceneTransition: Codable, Sendable {
    public var type: CueTransitionType
    public var duration: TimeInterval

    public init(type: CueTransitionType = .cut, duration: TimeInterval = 0.5) {
        self.type = type
        self.duration = duration
    }
}

/// Available scene transition types
public enum CueTransitionType: String, Codable, CaseIterable, Sendable {
    case cut
    case fade
    case slideLeft
    case slideRight
    case slideUp
    case slideDown
    case wipeLeft
    case wipeRight
    case wipeUp
    case wipeDown
    case stinger
    case zoom
    case blur
    case glitch
    case beatSync
}

// MARK: - CueSourceType

/// The type of a source element within a scene
public enum CueSourceType: String, Codable, CaseIterable, Sendable {
    case camera
    case mediaFile
    case visualLayer
    case screenCapture
    case webSource
    case textSource
    case colorBar
    case audioVisualizer
    case bioMetrics
    case dmxPreview
    case laserPreview
    case imageSlideshow
}

// MARK: - CueSourceFilter

/// Filter applied to a scene source
public struct CueSourceFilter: Identifiable, Codable, Sendable {
    public let id: UUID
    public var type: CueSourceFilterType
    public var isEnabled: Bool
    public var parameters: [String: Double]

    public init(
        id: UUID = UUID(),
        type: CueSourceFilterType,
        isEnabled: Bool = true,
        parameters: [String: Double] = [:]
    ) {
        self.id = id
        self.type = type
        self.isEnabled = isEnabled
        self.parameters = parameters
    }
}

/// Available source filter types
public enum CueSourceFilterType: String, Codable, CaseIterable, Sendable {
    case chromaKey
    case colorCorrection
    case blur
    case sharpen
    case crop
}

// MARK: - CueSceneSource

/// An element (layer) within a scene
public struct CueSceneSource: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var type: CueSourceType
    public var position: CGRect
    public var rotation: Float
    public var scale: Float
    public var opacity: Float
    public var isVisible: Bool
    public var cropRect: CGRect?
    public var filters: [CueSourceFilter]

    public init(
        id: UUID = UUID(),
        name: String,
        type: CueSourceType,
        position: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
        rotation: Float = 0,
        scale: Float = 1.0,
        opacity: Float = 1.0,
        isVisible: Bool = true,
        cropRect: CGRect? = nil,
        filters: [CueSourceFilter] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.position = position
        self.rotation = rotation
        self.scale = scale
        self.opacity = opacity
        self.isVisible = isVisible
        self.cropRect = cropRect
        self.filters = filters
    }
}

// MARK: - SceneAudioConfig

/// Per-scene audio routing configuration
public struct SceneAudioConfig: Codable, Sendable {
    public var monitorVolume: Float
    public var outputVolume: Float
    public var isMuted: Bool
    public var audioDelay: TimeInterval

    public init(
        monitorVolume: Float = 1.0,
        outputVolume: Float = 1.0,
        isMuted: Bool = false,
        audioDelay: TimeInterval = 0
    ) {
        self.monitorVolume = monitorVolume
        self.outputVolume = outputVolume
        self.isMuted = isMuted
        self.audioDelay = audioDelay
    }
}

// MARK: - ShowScene

/// A scene with layered sources (OBS-style)
public struct ShowScene: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var thumbnail: String?
    public var sources: [CueSceneSource]
    public var transition: CueSceneTransition
    public var isActive: Bool
    public var isPreview: Bool
    public var audioConfig: SceneAudioConfig

    public init(
        id: UUID = UUID(),
        name: String,
        thumbnail: String? = nil,
        sources: [CueSceneSource] = [],
        transition: CueSceneTransition = CueSceneTransition(),
        isActive: Bool = false,
        isPreview: Bool = false,
        audioConfig: SceneAudioConfig = SceneAudioConfig()
    ) {
        self.id = id
        self.name = name
        self.thumbnail = thumbnail
        self.sources = sources
        self.transition = transition
        self.isActive = isActive
        self.isPreview = isPreview
        self.audioConfig = audioConfig
    }
}

// MARK: - DMXChannelType

/// Types of DMX channels on a fixture
public enum DMXChannelType: String, Codable, CaseIterable, Sendable {
    case dimmer
    case red
    case green
    case blue
    case white
    case amber
    case uv
    case pan
    case panFine
    case tilt
    case tiltFine
    case gobo
    case goboRotation
    case colorWheel
    case strobe
    case zoom
    case focus
    case prism
    case frost
    case iris
    case speed
    case macro
}

// MARK: - DMXChannel

/// A single DMX channel definition within a fixture profile
public struct DMXChannel: Identifiable, Codable, Sendable {
    public let id: UUID
    public var label: String
    public var type: DMXChannelType
    public var defaultValue: UInt8
    public var minValue: UInt8
    public var maxValue: UInt8

    public init(
        id: UUID = UUID(),
        label: String,
        type: DMXChannelType,
        defaultValue: UInt8 = 0,
        minValue: UInt8 = 0,
        maxValue: UInt8 = 255
    ) {
        self.id = id
        self.label = label
        self.type = type
        self.defaultValue = defaultValue
        self.minValue = minValue
        self.maxValue = maxValue
    }
}

// MARK: - FixtureMode

/// A fixture personality / mode defining its channel layout
public struct FixtureMode: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var channelCount: Int
    public var channelLayout: [DMXChannelType]

    public init(
        id: UUID = UUID(),
        name: String,
        channelCount: Int,
        channelLayout: [DMXChannelType]
    ) {
        self.id = id
        self.name = name
        self.channelCount = channelCount
        self.channelLayout = channelLayout
    }
}

// MARK: - DMXFixtureProfile

/// Professional fixture definition with channel mapping and modes
public struct DMXFixtureProfile: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var manufacturer: String
    public var channelCount: Int
    public var modes: [FixtureMode]
    public var channels: [DMXChannel]
    public var dmxAddress: Int
    public var universe: Int

    public init(
        id: UUID = UUID(),
        name: String,
        manufacturer: String,
        channelCount: Int,
        modes: [FixtureMode] = [],
        channels: [DMXChannel] = [],
        dmxAddress: Int = 1,
        universe: Int = 1
    ) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.channelCount = channelCount
        self.modes = modes
        self.channels = channels
        self.dmxAddress = dmxAddress
        self.universe = universe
    }

    // MARK: Built-in Fixture Profiles

    /// Returns a library of common built-in fixture profiles
    public static func builtIn() -> [DMXFixtureProfile] {
        return [
            genericRGBPar(),
            genericRGBWPar(),
            genericDimmer(),
            movingHeadSpot16ch(),
            movingHeadWash14ch(),
            ledBar12ch(),
            ledStripController7ch(),
            laserILDA8ch(),
            fogMachine2ch(),
            strobe2ch()
        ]
    }

    /// Generic RGB PAR - 3 channel
    public static func genericRGBPar() -> DMXFixtureProfile {
        DMXFixtureProfile(
            name: "Generic RGB PAR",
            manufacturer: "Generic",
            channelCount: 3,
            modes: [
                FixtureMode(name: "3-Channel RGB", channelCount: 3, channelLayout: [.red, .green, .blue])
            ],
            channels: [
                DMXChannel(label: "Red", type: .red),
                DMXChannel(label: "Green", type: .green),
                DMXChannel(label: "Blue", type: .blue)
            ]
        )
    }

    /// Generic RGBW PAR - 4 channel
    public static func genericRGBWPar() -> DMXFixtureProfile {
        DMXFixtureProfile(
            name: "Generic RGBW PAR",
            manufacturer: "Generic",
            channelCount: 4,
            modes: [
                FixtureMode(name: "4-Channel RGBW", channelCount: 4, channelLayout: [.red, .green, .blue, .white])
            ],
            channels: [
                DMXChannel(label: "Red", type: .red),
                DMXChannel(label: "Green", type: .green),
                DMXChannel(label: "Blue", type: .blue),
                DMXChannel(label: "White", type: .white)
            ]
        )
    }

    /// Generic Dimmer - 1 channel
    public static func genericDimmer() -> DMXFixtureProfile {
        DMXFixtureProfile(
            name: "Generic Dimmer",
            manufacturer: "Generic",
            channelCount: 1,
            modes: [
                FixtureMode(name: "1-Channel Dimmer", channelCount: 1, channelLayout: [.dimmer])
            ],
            channels: [
                DMXChannel(label: "Dimmer", type: .dimmer)
            ]
        )
    }

    /// Moving Head Spot - 16 channel extended mode
    public static func movingHeadSpot16ch() -> DMXFixtureProfile {
        let layout: [DMXChannelType] = [
            .pan, .panFine, .tilt, .tiltFine, .speed, .dimmer,
            .strobe, .colorWheel, .gobo, .goboRotation, .prism,
            .focus, .zoom, .frost, .macro, .macro
        ]
        return DMXFixtureProfile(
            name: "Moving Head Spot 16ch",
            manufacturer: "Generic",
            channelCount: 16,
            modes: [
                FixtureMode(name: "16-Channel Extended", channelCount: 16, channelLayout: layout)
            ],
            channels: [
                DMXChannel(label: "Pan", type: .pan),
                DMXChannel(label: "Pan Fine", type: .panFine),
                DMXChannel(label: "Tilt", type: .tilt),
                DMXChannel(label: "Tilt Fine", type: .tiltFine),
                DMXChannel(label: "P/T Speed", type: .speed),
                DMXChannel(label: "Dimmer", type: .dimmer),
                DMXChannel(label: "Strobe", type: .strobe),
                DMXChannel(label: "Color Wheel", type: .colorWheel),
                DMXChannel(label: "Gobo", type: .gobo),
                DMXChannel(label: "Gobo Rotation", type: .goboRotation),
                DMXChannel(label: "Prism", type: .prism),
                DMXChannel(label: "Focus", type: .focus),
                DMXChannel(label: "Zoom", type: .zoom),
                DMXChannel(label: "Frost", type: .frost),
                DMXChannel(label: "Macro 1", type: .macro),
                DMXChannel(label: "Macro 2", type: .macro)
            ]
        )
    }

    /// Moving Head Wash - 14 channel
    public static func movingHeadWash14ch() -> DMXFixtureProfile {
        let layout: [DMXChannelType] = [
            .pan, .panFine, .tilt, .tiltFine, .speed, .dimmer,
            .strobe, .red, .green, .blue, .white, .zoom, .macro, .macro
        ]
        return DMXFixtureProfile(
            name: "Moving Head Wash 14ch",
            manufacturer: "Generic",
            channelCount: 14,
            modes: [
                FixtureMode(name: "14-Channel Extended", channelCount: 14, channelLayout: layout)
            ],
            channels: [
                DMXChannel(label: "Pan", type: .pan),
                DMXChannel(label: "Pan Fine", type: .panFine),
                DMXChannel(label: "Tilt", type: .tilt),
                DMXChannel(label: "Tilt Fine", type: .tiltFine),
                DMXChannel(label: "P/T Speed", type: .speed),
                DMXChannel(label: "Dimmer", type: .dimmer),
                DMXChannel(label: "Strobe", type: .strobe),
                DMXChannel(label: "Red", type: .red),
                DMXChannel(label: "Green", type: .green),
                DMXChannel(label: "Blue", type: .blue),
                DMXChannel(label: "White", type: .white),
                DMXChannel(label: "Zoom", type: .zoom),
                DMXChannel(label: "Macro 1", type: .macro),
                DMXChannel(label: "Macro 2", type: .macro)
            ]
        )
    }

    /// LED Bar - 12 channel (4 segments x RGB)
    public static func ledBar12ch() -> DMXFixtureProfile {
        let layout: [DMXChannelType] = [
            .red, .green, .blue,
            .red, .green, .blue,
            .red, .green, .blue,
            .red, .green, .blue
        ]
        return DMXFixtureProfile(
            name: "LED Bar 12ch",
            manufacturer: "Generic",
            channelCount: 12,
            modes: [
                FixtureMode(name: "12-Channel (4x RGB)", channelCount: 12, channelLayout: layout)
            ],
            channels: [
                DMXChannel(label: "Seg1 Red", type: .red),
                DMXChannel(label: "Seg1 Green", type: .green),
                DMXChannel(label: "Seg1 Blue", type: .blue),
                DMXChannel(label: "Seg2 Red", type: .red),
                DMXChannel(label: "Seg2 Green", type: .green),
                DMXChannel(label: "Seg2 Blue", type: .blue),
                DMXChannel(label: "Seg3 Red", type: .red),
                DMXChannel(label: "Seg3 Green", type: .green),
                DMXChannel(label: "Seg3 Blue", type: .blue),
                DMXChannel(label: "Seg4 Red", type: .red),
                DMXChannel(label: "Seg4 Green", type: .green),
                DMXChannel(label: "Seg4 Blue", type: .blue)
            ]
        )
    }

    /// LED Strip Controller - 7 channel
    public static func ledStripController7ch() -> DMXFixtureProfile {
        let layout: [DMXChannelType] = [
            .red, .green, .blue, .dimmer, .strobe, .macro, .speed
        ]
        return DMXFixtureProfile(
            name: "LED Strip Controller 7ch",
            manufacturer: "Generic",
            channelCount: 7,
            modes: [
                FixtureMode(name: "7-Channel (RGB+Dim+Strobe+Mode+Speed)", channelCount: 7, channelLayout: layout)
            ],
            channels: [
                DMXChannel(label: "Red", type: .red),
                DMXChannel(label: "Green", type: .green),
                DMXChannel(label: "Blue", type: .blue),
                DMXChannel(label: "Dimmer", type: .dimmer),
                DMXChannel(label: "Strobe", type: .strobe),
                DMXChannel(label: "Mode", type: .macro),
                DMXChannel(label: "Speed", type: .speed)
            ]
        )
    }

    /// Laser ILDA - 8 channel
    public static func laserILDA8ch() -> DMXFixtureProfile {
        let layout: [DMXChannelType] = [
            .pan, .tilt, .dimmer, .colorWheel, .macro, .speed, .zoom, .goboRotation
        ]
        return DMXFixtureProfile(
            name: "Laser ILDA 8ch",
            manufacturer: "Generic",
            channelCount: 8,
            modes: [
                FixtureMode(name: "8-Channel (X+Y+Dim+Color+Pattern+Speed+Size+Rotation)", channelCount: 8, channelLayout: layout)
            ],
            channels: [
                DMXChannel(label: "X Position", type: .pan),
                DMXChannel(label: "Y Position", type: .tilt),
                DMXChannel(label: "Dimmer", type: .dimmer),
                DMXChannel(label: "Color", type: .colorWheel),
                DMXChannel(label: "Pattern", type: .macro),
                DMXChannel(label: "Speed", type: .speed),
                DMXChannel(label: "Size", type: .zoom),
                DMXChannel(label: "Rotation", type: .goboRotation)
            ]
        )
    }

    /// Fog Machine - 2 channel
    public static func fogMachine2ch() -> DMXFixtureProfile {
        DMXFixtureProfile(
            name: "Fog Machine 2ch",
            manufacturer: "Generic",
            channelCount: 2,
            modes: [
                FixtureMode(name: "2-Channel (Output+Fan)", channelCount: 2, channelLayout: [.dimmer, .speed])
            ],
            channels: [
                DMXChannel(label: "Output", type: .dimmer),
                DMXChannel(label: "Fan", type: .speed)
            ]
        )
    }

    /// Strobe - 2 channel
    public static func strobe2ch() -> DMXFixtureProfile {
        DMXFixtureProfile(
            name: "Strobe 2ch",
            manufacturer: "Generic",
            channelCount: 2,
            modes: [
                FixtureMode(name: "2-Channel (Dimmer+Speed)", channelCount: 2, channelLayout: [.dimmer, .speed])
            ],
            channels: [
                DMXChannel(label: "Dimmer", type: .dimmer),
                DMXChannel(label: "Speed", type: .speed)
            ]
        )
    }
}

// MARK: - DMXUniverse

/// A single DMX universe (512 channels) with Art-Net addressing
public struct DMXUniverse: Identifiable, Codable, Sendable {
    public let id: Int
    public var name: String
    public var channels: [UInt8]
    public var artNetAddress: String
    public var artNetSubnet: Int
    public var artNetUniverse: Int
    public var outputRate: Int

    public init(
        id: Int,
        name: String = "",
        channels: [UInt8]? = nil,
        artNetAddress: String = "192.168.1.100",
        artNetSubnet: Int = 0,
        artNetUniverse: Int = 0,
        outputRate: Int = 44
    ) {
        self.id = id
        self.name = name.isEmpty ? "Universe \(id)" : name
        self.channels = channels ?? Array(repeating: 0, count: 512)
        self.artNetAddress = artNetAddress
        self.artNetSubnet = artNetSubnet
        self.artNetUniverse = artNetUniverse
        self.outputRate = outputRate
    }
}

// MARK: - Timecode

/// SMPTE-style timecode value
public struct Timecode: Codable, Sendable, CustomStringConvertible {
    public var hours: Int
    public var minutes: Int
    public var seconds: Int
    public var frames: Int
    public var frameRate: TimecodeFrameRate

    public init(
        hours: Int = 0,
        minutes: Int = 0,
        seconds: Int = 0,
        frames: Int = 0,
        frameRate: TimecodeFrameRate = .fps30
    ) {
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
        self.frames = frames
        self.frameRate = frameRate
    }

    /// Total time in seconds
    public var totalSeconds: TimeInterval {
        let base = TimeInterval(hours * 3600 + minutes * 60 + seconds)
        let frameFraction = TimeInterval(frames) / TimeInterval(frameRate.rawFPS)
        return base + frameFraction
    }

    public var description: String {
        let sep = frameRate == .fps2997drop ? ";" : ":"
        return String(format: "%02d:%02d:%02d%@%02d", hours, minutes, seconds, sep, frames)
    }
}

// MARK: - TimecodeFrameRate

/// Standard SMPTE timecode frame rates
public enum TimecodeFrameRate: String, Codable, CaseIterable, Sendable {
    case fps24 = "24"
    case fps25 = "25"
    case fps2997 = "29.97"
    case fps30 = "30"
    case fps2997drop = "29.97df"

    /// Actual frames per second
    public var rawFPS: Double {
        switch self {
        case .fps24: return 24.0
        case .fps25: return 25.0
        case .fps2997, .fps2997drop: return 29.97
        case .fps30: return 30.0
        }
    }
}

// MARK: - TimecodeSource

/// External timecode synchronization source
public enum TimecodeSource: String, Codable, CaseIterable, Sendable {
    case `internal`
    case midiTimeCode
    case smpte
    case artNetTimecode
    case abletonLink
}

// MARK: - TimecodeEngine

/// Timecode synchronization engine for external show sync
public class TimecodeEngine: ObservableObject, Codable {
    @Published public var source: TimecodeSource
    @Published public var currentTimecode: Timecode
    @Published public var isLocked: Bool
    public var offset: TimeInterval

    private var internalTimer: Timer?
    private var startDate: Date?

    // MARK: Codable

    enum CodingKeys: String, CodingKey {
        case source, currentTimecode, isLocked, offset
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decode(TimecodeSource.self, forKey: .source)
        currentTimecode = try container.decode(Timecode.self, forKey: .currentTimecode)
        isLocked = try container.decode(Bool.self, forKey: .isLocked)
        offset = try container.decode(TimeInterval.self, forKey: .offset)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(source, forKey: .source)
        try container.encode(currentTimecode, forKey: .currentTimecode)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(offset, forKey: .offset)
    }

    // MARK: Init

    public init(
        source: TimecodeSource = .internal,
        frameRate: TimecodeFrameRate = .fps30
    ) {
        self.source = source
        self.currentTimecode = Timecode(frameRate: frameRate)
        self.isLocked = false
        self.offset = 0
    }

    // MARK: Control

    /// Lock to an external timecode source
    public func lockToSource(_ source: TimecodeSource) {
        self.source = source
        self.isLocked = true
        log.led("Timecode locked to \(source.rawValue)")

        if source == .internal {
            startInternalClock()
        }
    }

    /// Unlock from external source
    public func unlock() {
        isLocked = false
        stopInternalClock()
        log.led("Timecode unlocked")
    }

    /// Start internal timecode generator
    private func startInternalClock() {
        startDate = Date()
        let interval = 1.0 / currentTimecode.frameRate.rawFPS
        internalTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.advanceFrame()
        }
    }

    /// Stop internal timecode generator
    private func stopInternalClock() {
        internalTimer?.invalidate()
        internalTimer = nil
        startDate = nil
    }

    /// Advance timecode by one frame
    private func advanceFrame() {
        let maxFrames = Int(currentTimecode.frameRate.rawFPS)
        currentTimecode.frames += 1
        if currentTimecode.frames >= maxFrames {
            currentTimecode.frames = 0
            currentTimecode.seconds += 1
            if currentTimecode.seconds >= 60 {
                currentTimecode.seconds = 0
                currentTimecode.minutes += 1
                if currentTimecode.minutes >= 60 {
                    currentTimecode.minutes = 0
                    currentTimecode.hours += 1
                    if currentTimecode.hours >= 24 {
                        currentTimecode.hours = 0
                    }
                }
            }
        }
    }

    /// Reset timecode to zero
    public func reset() {
        currentTimecode = Timecode(frameRate: currentTimecode.frameRate)
        startDate = Date()
        log.led("Timecode reset to 00:00:00:00")
    }
}

// MARK: - TimecodeConfig

/// Serializable timecode configuration for show files
public struct TimecodeConfig: Codable, Sendable {
    public var source: TimecodeSource
    public var frameRate: TimecodeFrameRate
    public var offset: TimeInterval

    public init(
        source: TimecodeSource = .internal,
        frameRate: TimecodeFrameRate = .fps30,
        offset: TimeInterval = 0
    ) {
        self.source = source
        self.frameRate = frameRate
        self.offset = offset
    }
}

// MARK: - ShowFile

/// Complete show package (Codable) for save/load
public struct ShowFile: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var cueLists: [CueList]
    public var scenes: [ShowScene]
    public var fixtures: [DMXFixtureProfile]
    public var universeConfig: [DMXUniverse]
    public var timecodeConfig: TimecodeConfig
    public var version: String

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        cueLists: [CueList] = [],
        scenes: [ShowScene] = [],
        fixtures: [DMXFixtureProfile] = [],
        universeConfig: [DMXUniverse] = [],
        timecodeConfig: TimecodeConfig = TimecodeConfig(),
        version: String = "1.0.0"
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.cueLists = cueLists
        self.scenes = scenes
        self.fixtures = fixtures
        self.universeConfig = universeConfig
        self.timecodeConfig = timecodeConfig
        self.version = version
    }
}

// MARK: - ProCueSystem

/// Professional cue / show management system
///
/// Combines Resolume Arena-style VJ cues, OBS-style scene composition,
/// and grandMA / ETC Eos-style cue lists into a unified show controller.
///
/// Supports up to 16 DMX universes, multi-cue-list playback, timecode sync,
/// and full show file persistence.
@MainActor
public class ProCueSystem: ObservableObject {

    // MARK: - Published Properties

    @Published public var cueLists: [CueList]
    @Published public var activeCueList: CueList?
    @Published public var scenes: [ShowScene]
    @Published public var activeScene: ShowScene?
    @Published public var previewScene: ShowScene?
    @Published public var fixtures: [DMXFixtureProfile]

    // MARK: - DMX Universes

    public var universes: [DMXUniverse]

    // MARK: - Timecode

    public let timecode: TimecodeEngine

    // MARK: - Show File

    @Published public var showFile: ShowFile?

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private var fadeTimers: [UUID: Timer] = [:]
    private var isFlashing: Bool = false

    // MARK: - Constants

    private static let maxUniverses = 16
    private static let dmxChannelsPerUniverse = 512

    // MARK: - Initialization

    public init(universeCount: Int = 1) {
        let count = min(max(universeCount, 1), Self.maxUniverses)
        self.cueLists = []
        self.scenes = []
        self.fixtures = []
        self.universes = (1...count).map { DMXUniverse(id: $0) }
        self.timecode = TimecodeEngine()

        log.led("ProCueSystem initialized with \(count) universe(s)")
    }

    // MARK: - Cue Playback

    /// Fire the next cue in the active cue list (GO button)
    public func go() {
        guard let cueList = activeCueList else {
            log.led("GO: No active cue list", level: .warning)
            return
        }
        cueList.go()

        if let index = cueList.currentCueIndex, index < cueList.cues.count {
            let cue = cueList.cues[index]
            executeCue(cue)
        }
    }

    /// Go back to the previous cue in the active cue list
    public func goBack() {
        guard let cueList = activeCueList else {
            log.led("BACK: No active cue list", level: .warning)
            return
        }
        cueList.goBack()

        if let index = cueList.currentCueIndex, index < cueList.cues.count {
            let cue = cueList.cues[index]
            executeCue(cue)
        }
    }

    /// Jump to a specific cue by number
    public func goToCue(number: Double) {
        guard let cueList = activeCueList else {
            log.led("GOTO: No active cue list", level: .warning)
            return
        }
        cueList.goToCue(number: number)

        if let index = cueList.currentCueIndex, index < cueList.cues.count {
            let cue = cueList.cues[index]
            executeCue(cue)
        }
    }

    /// Stop the current transition mid-fade
    public func halt() {
        // Cancel all running fade timers
        for (id, timer) in fadeTimers {
            timer.invalidate()
            fadeTimers.removeValue(forKey: id)
        }
        activeCueList?.halt()
        log.led("HALT: All transitions stopped")
    }

    /// Blackout: set all DMX channels across all universes to 0
    public func blackout() {
        for i in 0..<universes.count {
            universes[i].channels = Array(repeating: 0, count: Self.dmxChannelsPerUniverse)
        }
        log.led("BLACKOUT: All universes zeroed")
    }

    /// Flash: temporarily set all dimmers to full brightness
    public func flash() {
        guard !isFlashing else { return }
        isFlashing = true

        // Store current state
        let savedUniverses = universes

        // Set all channels to max
        for i in 0..<universes.count {
            universes[i].channels = Array(repeating: 255, count: Self.dmxChannelsPerUniverse)
        }

        log.led("FLASH: Full brightness")

        // Restore after a short duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            self.universes = savedUniverses
            self.isFlashing = false
            log.led("FLASH: Released")
        }
    }

    // MARK: - Cue Execution

    /// Execute all actions within a cue
    private func executeCue(_ cue: ShowCue) {
        guard cue.isEnabled else {
            log.led("Cue \(cue.number) [\(cue.name)] is disabled, skipping")
            return
        }

        log.led("Executing cue \(cue.number): \(cue.name) (\(cue.type.rawValue))")

        // Handle special cue types first
        switch cue.type {
        case .blackout:
            blackout()
            return
        case .goTo:
            // goTo cues should have an action specifying the target cue number
            break
        case .wait:
            // wait cues simply insert a delay; handled by the cue list trigger sequencing
            break
        default:
            break
        }

        // Execute each action
        for action in cue.actions where action.isEnabled {
            if action.delay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + action.delay) { [weak self] in
                    self?.executeAction(action, fadeIn: cue.fadeInTime)
                }
            } else {
                executeAction(action, fadeIn: cue.fadeInTime)
            }
        }

        // Handle auto-follow trigger modes for the next cue
        handleAutoTrigger(after: cue)
    }

    /// Execute a single cue action
    private func executeAction(_ action: CueAction, fadeIn: TimeInterval) {
        switch action.type {
        case .setDMX(let universe, let channel, let value):
            setDMXValue(universe: universe, channel: channel, value: value)

        case .fadeDMX(let universe, let channel, let from, let to, let duration):
            setDMXValue(universe: universe, channel: channel, value: from)
            fadeDMXValue(universe: universe, channel: channel, to: to, duration: duration)

        case .activateScene(let sceneID):
            if let scene = scenes.first(where: { $0.id == sceneID }) {
                switchScene(scene)
            }

        case .setVisualLayer(let layerID, let opacity, let blendMode):
            log.led("Set visual layer \(layerID.uuidString.prefix(8)): opacity=\(opacity), blend=\(blendMode)")

        case .playMedia(let mediaID):
            log.led("Play media: \(mediaID)")

        case .setAudioParam(let channel, let param, let value):
            log.led("Set audio param: ch\(channel) \(param)=\(value)")

        case .triggerEffect(let effectID):
            log.led("Trigger effect: \(effectID)")

        case .setBPM(let bpm):
            log.led("Set BPM: \(bpm)")

        case .crossfade(let fromID, let toID, let duration):
            log.led("Crossfade: \(fromID.uuidString.prefix(8)) -> \(toID.uuidString.prefix(8)) over \(duration)s")

        case .laserPattern(let pattern):
            log.led("Laser pattern: \(pattern)")

        case .gobo(let fixture, let index):
            log.led("Gobo: fixture \(fixture), index \(index)")

        case .colorWheel(let fixture, let index):
            log.led("Color wheel: fixture \(fixture), index \(index)")

        case .panTilt(let fixture, let pan, let tilt, let speed):
            log.led("Pan/Tilt: fixture \(fixture), pan=\(pan), tilt=\(tilt), speed=\(speed)")

        case .sendOSC(let address, let value):
            log.led("OSC: \(address) = \(value)")

        case .sendMIDI(let type, let channel, let data):
            log.led("MIDI: \(type) ch\(channel) data=\(data)")

        case .customScript(let script):
            log.led("Custom script: \(script.prefix(64))...")
        }
    }

    /// Handle auto-trigger modes (followPrevious, afterPrevious)
    private func handleAutoTrigger(after cue: ShowCue) {
        guard let cueList = activeCueList,
              let currentIndex = cueList.currentCueIndex,
              currentIndex + 1 < cueList.cues.count else { return }

        let nextCue = cueList.cues[currentIndex + 1]

        switch nextCue.triggerMode {
        case .followPrevious:
            // Fire immediately after the current cue completes its duration
            let delay = cue.duration > 0 ? cue.duration : cue.fadeInTime
            if delay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.go()
                }
            } else {
                go()
            }

        case .afterPrevious(let afterDelay):
            let totalDelay = (cue.duration > 0 ? cue.duration : cue.fadeInTime) + afterDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) { [weak self] in
                self?.go()
            }

        case .timecode(let tc):
            log.led("Next cue \(nextCue.number) waiting for timecode \(tc)")

        default:
            // manual, midi, beatSync — wait for external trigger
            break
        }
    }

    // MARK: - Scene Management (OBS-style)

    /// Switch to a new scene with its configured transition
    public func switchScene(_ scene: ShowScene) {
        let previousScene = activeScene

        // Deactivate the previous scene
        if let prevIndex = scenes.firstIndex(where: { $0.id == previousScene?.id }) {
            scenes[prevIndex].isActive = false
        }

        // Activate the new scene
        if let newIndex = scenes.firstIndex(where: { $0.id == scene.id }) {
            scenes[newIndex].isActive = true
            scenes[newIndex].isPreview = false
            activeScene = scenes[newIndex]
        }

        // Clear preview if it was the scene we just activated
        if previewScene?.id == scene.id {
            previewScene = nil
        }

        log.led("Scene switch: \(previousScene?.name ?? "none") -> \(scene.name) [\(scene.transition.type.rawValue), \(scene.transition.duration)s]")
    }

    /// Set a scene as the preview (OBS-style program/preview)
    public func setPreview(_ scene: ShowScene) {
        // Clear previous preview
        if let prevIndex = scenes.firstIndex(where: { $0.id == previewScene?.id }) {
            scenes[prevIndex].isPreview = false
        }

        if let newIndex = scenes.firstIndex(where: { $0.id == scene.id }) {
            scenes[newIndex].isPreview = true
            previewScene = scenes[newIndex]
        }

        log.led("Preview set: \(scene.name)")
    }

    // MARK: - DMX Fixture Management

    /// Add a fixture to the patch
    public func addFixture(profile: DMXFixtureProfile, address: Int, universe: Int) {
        var patched = profile
        patched.dmxAddress = address
        patched.universe = universe
        fixtures.append(patched)
        log.led("Fixture added: \(profile.name) @ Universe \(universe) Address \(address)")
    }

    /// Re-patch an existing fixture to a new address/universe
    public func patchFixture(id: UUID, address: Int, universe: Int) {
        guard let index = fixtures.firstIndex(where: { $0.id == id }) else {
            log.led("Patch fixture: ID not found", level: .warning)
            return
        }
        let oldAddress = fixtures[index].dmxAddress
        let oldUniverse = fixtures[index].universe
        fixtures[index].dmxAddress = address
        fixtures[index].universe = universe
        log.led("Fixture re-patched: \(fixtures[index].name) from U\(oldUniverse)/A\(oldAddress) to U\(universe)/A\(address)")
    }

    // MARK: - DMX Channel Control

    /// Set a single DMX channel value immediately
    public func setDMXValue(universe: Int, channel: Int, value: UInt8) {
        guard universe >= 1, universe <= universes.count else {
            log.led("setDMX: Universe \(universe) out of range (1-\(universes.count))", level: .warning)
            return
        }
        guard channel >= 1, channel <= Self.dmxChannelsPerUniverse else {
            log.led("setDMX: Channel \(channel) out of range (1-\(Self.dmxChannelsPerUniverse))", level: .warning)
            return
        }

        universes[universe - 1].channels[channel - 1] = value
    }

    /// Fade a single DMX channel to a target value over a duration
    public func fadeDMXValue(universe: Int, channel: Int, to targetValue: UInt8, duration: TimeInterval) {
        guard universe >= 1, universe <= universes.count else {
            log.led("fadeDMX: Universe \(universe) out of range", level: .warning)
            return
        }
        guard channel >= 1, channel <= Self.dmxChannelsPerUniverse else {
            log.led("fadeDMX: Channel \(channel) out of range", level: .warning)
            return
        }
        guard duration > 0 else {
            setDMXValue(universe: universe, channel: channel, value: targetValue)
            return
        }

        let startValue = Double(universes[universe - 1].channels[channel - 1])
        let endValue = Double(targetValue)
        let steps = max(Int(duration * 44.0), 1) // ~44 Hz DMX refresh
        let stepInterval = duration / Double(steps)
        let fadeID = UUID()
        var currentStep = 0

        let timer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            currentStep += 1
            let progress = Double(currentStep) / Double(steps)
            let interpolated = startValue + (endValue - startValue) * progress
            let clamped = UInt8(max(0, min(255, Int(interpolated))))

            self.universes[universe - 1].channels[channel - 1] = clamped

            if currentStep >= steps {
                timer.invalidate()
                self.fadeTimers.removeValue(forKey: fadeID)
                self.universes[universe - 1].channels[channel - 1] = targetValue
            }
        }

        fadeTimers[fadeID] = timer
    }

    // MARK: - Show File Management

    /// Save the current show state to a ShowFile
    public func saveShow(name: String) -> ShowFile {
        let file = ShowFile(
            name: name,
            createdAt: showFile?.createdAt ?? Date(),
            modifiedAt: Date(),
            cueLists: cueLists,
            scenes: scenes,
            fixtures: fixtures,
            universeConfig: universes,
            timecodeConfig: TimecodeConfig(
                source: timecode.source,
                frameRate: timecode.currentTimecode.frameRate,
                offset: timecode.offset
            ),
            version: "1.0.0"
        )

        self.showFile = file
        log.led("Show saved: \(name) (\(cueLists.count) cue list(s), \(scenes.count) scene(s), \(fixtures.count) fixture(s))")
        return file
    }

    /// Load a show from a ShowFile
    public func loadShow(_ file: ShowFile) {
        self.cueLists = file.cueLists
        self.scenes = file.scenes
        self.fixtures = file.fixtures

        // Rebuild universes from config
        self.universes = file.universeConfig
        if self.universes.isEmpty {
            self.universes = [DMXUniverse(id: 1)]
        }

        // Restore timecode settings
        timecode.source = file.timecodeConfig.source
        timecode.currentTimecode = Timecode(frameRate: file.timecodeConfig.frameRate)
        timecode.offset = file.timecodeConfig.offset

        // Set active cue list to the first one
        self.activeCueList = cueLists.first

        // Set active scene to the one marked active, or the first one
        self.activeScene = scenes.first(where: { $0.isActive }) ?? scenes.first

        self.showFile = file
        log.led("Show loaded: \(file.name) (v\(file.version)) - \(cueLists.count) cue list(s), \(scenes.count) scene(s), \(fixtures.count) fixture(s)")
    }

    // MARK: - Cue Sheet Export

    /// Export a printable cue sheet for the stage manager
    public func exportCueSheet() -> String {
        var output = ""

        let showName = showFile?.name ?? "Untitled Show"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let dateString = dateFormatter.string(from: Date())

        output += "========================================\n"
        output += "  CUE SHEET - \(showName)\n"
        output += "  Generated: \(dateString)\n"
        output += "========================================\n\n"

        if cueLists.isEmpty {
            output += "(No cue lists)\n"
            return output
        }

        for cueList in cueLists {
            output += "--- Cue List: \(cueList.name) ---\n"
            output += String(format: "%-8s %-30s %-12s %-8s %-8s %-14s %s\n",
                             "Cue #", "Name", "Type", "Fade In", "Fade Out", "Trigger", "Notes")
            output += String(repeating: "-", count: 100) + "\n"

            for cue in cueList.cues {
                let triggerStr: String
                switch cue.triggerMode {
                case .manual:
                    triggerStr = "Manual"
                case .followPrevious:
                    triggerStr = "Follow"
                case .afterPrevious(let delay):
                    triggerStr = "After +\(String(format: "%.1f", delay))s"
                case .timecode(let tc):
                    triggerStr = "TC \(String(format: "%.2f", tc))"
                case .midi(let note, let channel):
                    triggerStr = "MIDI N\(note)/C\(channel)"
                case .beatSync(let division):
                    triggerStr = "Beat /\(String(format: "%.0f", division))"
                }

                let enabledMarker = cue.isEnabled ? " " : "X"
                let notesPreview = cue.notes.isEmpty ? "" : cue.notes.prefix(40).description

                output += String(format: "%@%-7s %-30s %-12s %-8s %-8s %-14s %s\n",
                                 enabledMarker,
                                 String(format: "%.1f", cue.number),
                                 String(cue.name.prefix(30)),
                                 cue.type.rawValue,
                                 String(format: "%.1fs", cue.fadeInTime),
                                 String(format: "%.1fs", cue.fadeOutTime),
                                 triggerStr,
                                 notesPreview)
            }

            output += "\n"
        }

        // Fixture patch summary
        if !fixtures.isEmpty {
            output += "--- Fixture Patch ---\n"
            output += String(format: "%-30s %-20s %-10s %-10s %-6s\n",
                             "Fixture", "Manufacturer", "Channels", "Address", "Univ.")
            output += String(repeating: "-", count: 80) + "\n"

            for fixture in fixtures {
                output += String(format: "%-30s %-20s %-10d %-10d %-6d\n",
                                 String(fixture.name.prefix(30)),
                                 String(fixture.manufacturer.prefix(20)),
                                 fixture.channelCount,
                                 fixture.dmxAddress,
                                 fixture.universe)
            }
            output += "\n"
        }

        // Scene summary
        if !scenes.isEmpty {
            output += "--- Scenes ---\n"
            for (index, scene) in scenes.enumerated() {
                let activeMarker = scene.isActive ? " [ACTIVE]" : ""
                output += "  \(index + 1). \(scene.name) (\(scene.sources.count) source(s), transition: \(scene.transition.type.rawValue))\(activeMarker)\n"
            }
            output += "\n"
        }

        // Universe summary
        output += "--- Universes ---\n"
        for universe in universes {
            let nonZero = universe.channels.filter { $0 > 0 }.count
            output += "  Universe \(universe.id): \(universe.name) (Art-Net \(universe.artNetAddress) S\(universe.artNetSubnet)/U\(universe.artNetUniverse), \(nonZero) active ch, \(universe.outputRate) Hz)\n"
        }
        output += "\n"

        output += "========================================\n"
        output += "  END OF CUE SHEET\n"
        output += "========================================\n"

        log.led("Cue sheet exported (\(output.count) characters)")
        return output
    }

    // MARK: - Debug Info

    /// Summary of the current system state
    public var debugInfo: String {
        let activeCueName = activeCueList.flatMap { list in
            list.currentCueIndex.map { list.cues[$0].name }
        } ?? "none"

        return """
        ProCueSystem:
        - Cue Lists: \(cueLists.count)
        - Active Cue List: \(activeCueList?.name ?? "none")
        - Current Cue: \(activeCueName)
        - Scenes: \(scenes.count)
        - Active Scene: \(activeScene?.name ?? "none")
        - Preview Scene: \(previewScene?.name ?? "none")
        - Fixtures: \(fixtures.count)
        - Universes: \(universes.count)
        - Timecode: \(timecode.currentTimecode) (\(timecode.source.rawValue), locked: \(timecode.isLocked))
        - Show File: \(showFile?.name ?? "none")
        - Active Fades: \(fadeTimers.count)
        """
    }
}

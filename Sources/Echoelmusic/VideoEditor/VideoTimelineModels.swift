//
//  VideoTimelineModels.swift
//  Echoelmusic
//
//  Created: 2025-11-28
//  Professional Video Timeline Data Models
//
//  Separated from VideoTimelineView for clean MVVM architecture
//

import SwiftUI
import Foundation

// MARK: - Video Clip

/// Represents a video clip on the timeline
public struct VideoClipModel: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var sourceURL: URL?
    public var trackId: UUID
    public var startTime: Double // seconds on timeline
    public var inPoint: Double // source in point
    public var outPoint: Double // source out point
    public var speed: Double = 1.0
    public var isReversed: Bool = false
    public var opacity: Float = 1.0
    public var blendMode: BlendMode = .normal
    public var transform: ClipTransform = ClipTransform()
    public var effects: [VideoEffectModel] = []
    public var audioEnabled: Bool = true
    public var audioVolume: Float = 1.0
    public var transitions: ClipTransitions = ClipTransitions()
    public var color: CodableColor = CodableColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)

    public var duration: Double { outPoint - inPoint }
    public var endTime: Double { startTime + duration }

    public init(
        id: UUID = UUID(),
        name: String,
        sourceURL: URL? = nil,
        trackId: UUID,
        startTime: Double,
        inPoint: Double,
        outPoint: Double,
        color: CodableColor = CodableColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
    ) {
        self.id = id
        self.name = name
        self.sourceURL = sourceURL
        self.trackId = trackId
        self.startTime = startTime
        self.inPoint = inPoint
        self.outPoint = outPoint
        self.color = color
    }

    // MARK: - Blend Modes

    public enum BlendMode: String, Codable, CaseIterable {
        case normal = "Normal"
        case add = "Add"
        case multiply = "Multiply"
        case screen = "Screen"
        case overlay = "Overlay"
        case softLight = "Soft Light"
        case hardLight = "Hard Light"
        case difference = "Difference"
        case exclusion = "Exclusion"
        case colorDodge = "Color Dodge"
        case colorBurn = "Color Burn"
        case darken = "Darken"
        case lighten = "Lighten"
        case hue = "Hue"
        case saturation = "Saturation"
        case color = "Color"
        case luminosity = "Luminosity"
    }
}

// MARK: - Clip Transform

public struct ClipTransform: Codable, Equatable {
    public var positionX: Double = 0
    public var positionY: Double = 0
    public var scaleX: Double = 1.0
    public var scaleY: Double = 1.0
    public var rotation: Double = 0 // degrees
    public var anchorX: Double = 0.5
    public var anchorY: Double = 0.5

    public init() {}

    public init(positionX: Double, positionY: Double, scaleX: Double, scaleY: Double, rotation: Double) {
        self.positionX = positionX
        self.positionY = positionY
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.rotation = rotation
    }
}

// MARK: - Clip Transitions

public struct ClipTransitions: Codable, Equatable {
    public var inTransition: Transition?
    public var outTransition: Transition?

    public init() {}

    public struct Transition: Codable, Equatable {
        public var type: TransitionType
        public var duration: Double
        public var easing: EasingType

        public init(type: TransitionType, duration: Double, easing: EasingType = .easeInOut) {
            self.type = type
            self.duration = duration
            self.easing = easing
        }

        public enum TransitionType: String, Codable, CaseIterable {
            case cut = "Cut"
            case crossDissolve = "Cross Dissolve"
            case fade = "Fade"
            case wipe = "Wipe"
            case slide = "Slide"
            case push = "Push"
            case zoom = "Zoom"
            case iris = "Iris"
            case pageFlip = "Page Flip"
            case doorway = "Doorway"
            case cube = "Cube"
            case ripple = "Ripple"
            case swirl = "Swirl"
        }

        public enum EasingType: String, Codable, CaseIterable {
            case linear = "Linear"
            case easeIn = "Ease In"
            case easeOut = "Ease Out"
            case easeInOut = "Ease In Out"
            case bounce = "Bounce"
            case elastic = "Elastic"
        }
    }
}

// MARK: - Video Effect

/// Video effect applied to a clip
public struct VideoEffectModel: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var type: EffectType
    public var isEnabled: Bool = true
    public var parameters: [String: Double]
    public var keyframes: [EffectKeyframe] = []

    public init(id: UUID = UUID(), name: String, type: EffectType, parameters: [String: Double] = [:]) {
        self.id = id
        self.name = name
        self.type = type
        self.parameters = parameters
    }

    public enum EffectType: String, Codable, CaseIterable {
        // Color Correction
        case colorCorrection = "Color Correction"
        case curves = "Curves"
        case levels = "Levels"
        case hslSecondary = "HSL Secondary"
        case colorWheels = "Color Wheels"
        case lut = "LUT"

        // Blur & Sharpen
        case gaussianBlur = "Gaussian Blur"
        case motionBlur = "Motion Blur"
        case radialBlur = "Radial Blur"
        case zoomBlur = "Zoom Blur"
        case sharpen = "Sharpen"
        case unsharpMask = "Unsharp Mask"

        // Distortion
        case transform = "Transform"
        case warp = "Warp"
        case spherize = "Spherize"
        case twirl = "Twirl"
        case ripple = "Ripple"
        case wave = "Wave"
        case fishEye = "Fish Eye"
        case perspective = "Perspective"

        // Stylize
        case glow = "Glow"
        case vignette = "Vignette"
        case filmGrain = "Film Grain"
        case chromaticAberration = "Chromatic Aberration"
        case pixelate = "Pixelate"
        case posterize = "Posterize"
        case oilPaint = "Oil Paint"
        case sketch = "Sketch"
        case halftone = "Halftone"

        // Keying
        case chromaKey = "Chroma Key"
        case lumaKey = "Luma Key"
        case differenceKey = "Difference Key"

        // Generate
        case solidColor = "Solid Color"
        case gradient = "Gradient"
        case noise = "Noise"
        case fractalNoise = "Fractal Noise"

        // Time
        case echo = "Echo"
        case trails = "Trails"
        case timeRemap = "Time Remap"

        public var category: String {
            switch self {
            case .colorCorrection, .curves, .levels, .hslSecondary, .colorWheels, .lut:
                return "Color"
            case .gaussianBlur, .motionBlur, .radialBlur, .zoomBlur, .sharpen, .unsharpMask:
                return "Blur & Sharpen"
            case .transform, .warp, .spherize, .twirl, .ripple, .wave, .fishEye, .perspective:
                return "Distortion"
            case .glow, .vignette, .filmGrain, .chromaticAberration, .pixelate, .posterize, .oilPaint, .sketch, .halftone:
                return "Stylize"
            case .chromaKey, .lumaKey, .differenceKey:
                return "Keying"
            case .solidColor, .gradient, .noise, .fractalNoise:
                return "Generate"
            case .echo, .trails, .timeRemap:
                return "Time"
            }
        }
    }

    public struct EffectKeyframe: Codable, Identifiable, Equatable {
        public let id: UUID
        public var time: Double
        public var value: Double
        public var interpolation: InterpolationType

        public init(time: Double, value: Double, interpolation: InterpolationType = .linear) {
            self.id = UUID()
            self.time = time
            self.value = value
            self.interpolation = interpolation
        }

        public enum InterpolationType: String, Codable {
            case linear
            case bezier
            case hold
        }
    }
}

// MARK: - Video Track

/// Video track in the timeline
public struct VideoTrackModel: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var type: TrackType
    public var clips: [VideoClipModel]
    public var isVisible: Bool = true
    public var isLocked: Bool = false
    public var isMuted: Bool = false
    public var height: CGFloat = 60
    public var opacity: Float = 1.0
    public var blendMode: VideoClipModel.BlendMode = .normal

    public init(id: UUID = UUID(), name: String, type: TrackType, clips: [VideoClipModel] = []) {
        self.id = id
        self.name = name
        self.type = type
        self.clips = clips
    }

    public enum TrackType: String, Codable {
        case video
        case audio
        case title
        case adjustment
        case composite
    }
}

// MARK: - Audio Clip

/// Audio clip for audio tracks
public struct AudioClipModel: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var sourceURL: URL?
    public var trackId: UUID
    public var startTime: Double
    public var inPoint: Double
    public var outPoint: Double
    public var volume: Float = 1.0
    public var pan: Float = 0
    public var fadeIn: Double = 0
    public var fadeOut: Double = 0
    public var effects: [AudioEffectReference] = []
    public var waveformData: [Float]?

    public var duration: Double { outPoint - inPoint }

    public init(id: UUID = UUID(), name: String, sourceURL: URL? = nil, trackId: UUID, startTime: Double, inPoint: Double, outPoint: Double) {
        self.id = id
        self.name = name
        self.sourceURL = sourceURL
        self.trackId = trackId
        self.startTime = startTime
        self.inPoint = inPoint
        self.outPoint = outPoint
    }

    public struct AudioEffectReference: Codable, Identifiable, Equatable {
        public let id: UUID
        public var effectName: String
        public var parameters: [String: Double]

        public init(effectName: String, parameters: [String: Double] = [:]) {
            self.id = UUID()
            self.effectName = effectName
            self.parameters = parameters
        }
    }
}

// MARK: - Title Clip

/// Title/Text overlay
public struct TitleClipModel: Identifiable, Codable, Equatable {
    public let id: UUID
    public var text: String
    public var trackId: UUID
    public var startTime: Double
    public var duration: Double
    public var font: String = "Helvetica Neue"
    public var fontSize: CGFloat = 72
    public var fontWeight: FontWeight = .bold
    public var textColor: CodableColor = CodableColor(red: 1, green: 1, blue: 1, alpha: 1)
    public var backgroundColor: CodableColor?
    public var strokeColor: CodableColor?
    public var strokeWidth: CGFloat = 0
    public var shadowEnabled: Bool = false
    public var shadowColor: CodableColor = CodableColor(red: 0, green: 0, blue: 0, alpha: 1)
    public var shadowOffset: CGSize = CGSize(width: 2, height: 2)
    public var shadowBlur: CGFloat = 4
    public var alignment: TextAlignment = .center
    public var position: CGPoint = CGPoint(x: 0.5, y: 0.5)
    public var animation: TitleAnimation?

    public init(id: UUID = UUID(), text: String, trackId: UUID, startTime: Double, duration: Double) {
        self.id = id
        self.text = text
        self.trackId = trackId
        self.startTime = startTime
        self.duration = duration
    }

    public enum FontWeight: String, Codable, CaseIterable {
        case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
    }

    public enum TextAlignment: String, Codable {
        case left, center, right
    }

    public struct TitleAnimation: Codable, Equatable {
        public var inAnimation: AnimationType
        public var outAnimation: AnimationType
        public var inDuration: Double
        public var outDuration: Double

        public init(inAnimation: AnimationType, outAnimation: AnimationType, inDuration: Double = 0.5, outDuration: Double = 0.5) {
            self.inAnimation = inAnimation
            self.outAnimation = outAnimation
            self.inDuration = inDuration
            self.outDuration = outDuration
        }

        public enum AnimationType: String, Codable, CaseIterable {
            case none = "None"
            case fade = "Fade"
            case slideLeft = "Slide Left"
            case slideRight = "Slide Right"
            case slideUp = "Slide Up"
            case slideDown = "Slide Down"
            case scale = "Scale"
            case typewriter = "Typewriter"
            case blur = "Blur"
            case bounce = "Bounce"
        }
    }
}

// MARK: - Codable Color

/// Codable color wrapper for serialization
public struct CodableColor: Codable, Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    #if canImport(SwiftUI)
    public var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    public init(color: Color) {
        // Default to white since Color doesn't expose components directly
        self.red = 1
        self.green = 1
        self.blue = 1
        self.alpha = 1
    }
    #endif

    // Named colors
    public static let red = CodableColor(red: 1, green: 0, blue: 0, alpha: 1)
    public static let green = CodableColor(red: 0, green: 1, blue: 0, alpha: 1)
    public static let blue = CodableColor(red: 0, green: 0, blue: 1, alpha: 1)
    public static let yellow = CodableColor(red: 1, green: 1, blue: 0, alpha: 1)
    public static let orange = CodableColor(red: 1, green: 0.5, blue: 0, alpha: 1)
    public static let white = CodableColor(red: 1, green: 1, blue: 1, alpha: 1)
    public static let black = CodableColor(red: 0, green: 0, blue: 0, alpha: 1)
}

// MARK: - Timeline Marker

/// Timeline marker for navigation and notes
public struct TimelineMarkerModel: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var time: Double
    public var color: CodableColor
    public var type: MarkerType
    public var notes: String?

    public init(id: UUID = UUID(), name: String, time: Double, color: CodableColor = .yellow, type: MarkerType = .standard) {
        self.id = id
        self.name = name
        self.time = time
        self.color = color
        self.type = type
    }

    public enum MarkerType: String, Codable {
        case standard
        case chapter
        case todo
        case note
    }
}

// MARK: - Timeline State (for Undo/Redo)

/// Snapshot of timeline state for undo/redo
public struct TimelineStateSnapshot: Codable {
    public var videoTracks: [VideoTrackModel]
    public var audioTracks: [VideoTrackModel]
    public var markers: [TimelineMarkerModel]
    public var timestamp: Date

    public init(videoTracks: [VideoTrackModel], audioTracks: [VideoTrackModel], markers: [TimelineMarkerModel]) {
        self.videoTracks = videoTracks
        self.audioTracks = audioTracks
        self.markers = markers
        self.timestamp = Date()
    }
}

// MARK: - Edit Mode

public enum TimelineEditMode: String, CaseIterable {
    case select = "Select"
    case blade = "Blade"
    case trim = "Trim"
    case slip = "Slip"
    case slide = "Slide"
    case roll = "Roll"
    case ripple = "Ripple"
    case timeStretch = "Time Stretch"

    public var icon: String {
        switch self {
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .blade: return "scissors"
        case .trim: return "arrow.left.and.right"
        case .slip: return "arrow.left.arrow.right"
        case .slide: return "arrow.left.arrow.right.square"
        case .roll: return "arrow.left.and.right.circle"
        case .ripple: return "waveform.path"
        case .timeStretch: return "timer"
        }
    }
}

// MARK: - Scope Types

public enum TimelineScopeType: String, CaseIterable {
    case waveform = "Waveform"
    case vectorscope = "Vectorscope"
    case histogram = "Histogram"
    case parade = "RGB Parade"
}

// MARK: - Preview Resolution

public enum PreviewResolution: String, CaseIterable {
    case full = "Full"
    case half = "1/2"
    case quarter = "1/4"
    case eighth = "1/8"

    public var scale: CGFloat {
        switch self {
        case .full: return 1.0
        case .half: return 0.5
        case .quarter: return 0.25
        case .eighth: return 0.125
        }
    }
}

// MARK: - Project Settings

public struct ProjectSettings: Codable {
    public var name: String
    public var resolution: Resolution
    public var frameRate: FrameRate
    public var colorSpace: ColorSpace
    public var audioSampleRate: Int = 48000
    public var audioBitDepth: Int = 24

    public init(name: String = "Untitled Project", resolution: Resolution = .uhd4K, frameRate: FrameRate = .fps30) {
        self.name = name
        self.resolution = resolution
        self.frameRate = frameRate
        self.colorSpace = .rec709
    }

    public enum Resolution: String, Codable, CaseIterable {
        case hd720 = "720p"
        case hd1080 = "1080p"
        case uhd4K = "4K UHD"
        case dci4K = "4K DCI"
        case uhd8K = "8K UHD"

        public var width: Int {
            switch self {
            case .hd720: return 1280
            case .hd1080: return 1920
            case .uhd4K: return 3840
            case .dci4K: return 4096
            case .uhd8K: return 7680
            }
        }

        public var height: Int {
            switch self {
            case .hd720: return 720
            case .hd1080: return 1080
            case .uhd4K: return 2160
            case .dci4K: return 2160
            case .uhd8K: return 4320
            }
        }
    }

    public enum FrameRate: String, Codable, CaseIterable {
        case fps24 = "24 fps"
        case fps25 = "25 fps"
        case fps30 = "30 fps"
        case fps50 = "50 fps"
        case fps60 = "60 fps"
        case fps120 = "120 fps"

        public var value: Double {
            switch self {
            case .fps24: return 24.0
            case .fps25: return 25.0
            case .fps30: return 30.0
            case .fps50: return 50.0
            case .fps60: return 60.0
            case .fps120: return 120.0
            }
        }
    }

    public enum ColorSpace: String, Codable, CaseIterable {
        case rec709 = "Rec. 709"
        case rec2020 = "Rec. 2020"
        case dciP3 = "DCI-P3"
        case sRGB = "sRGB"
        case aces = "ACES"
    }
}

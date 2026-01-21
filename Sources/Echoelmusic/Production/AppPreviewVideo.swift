// AppPreviewVideo.swift
// Echoelmusic
//
// App Store Preview Video Script & Configuration
// Complete production specification for creating preview videos
//
// Created: 2026-01-07

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Logger instance for App Preview operations
private let log = Logger.shared

// MARK: - App Preview Script

/// Complete 30-second App Store preview video script with timing and assets
public struct AppPreviewScript: Codable, Sendable {
    public let version: String
    public let duration: TimeInterval
    public let scenes: [PreviewScene]
    public let videoSpecs: VideoSpecifications
    public let voiceoverScript: VoiceoverScript
    public let musicCues: MusicCues
    public let productionNotes: ProductionNotes

    public init(
        version: String = "1.0",
        duration: TimeInterval = 30.0,
        scenes: [PreviewScene],
        videoSpecs: VideoSpecifications,
        voiceoverScript: VoiceoverScript,
        musicCues: MusicCues,
        productionNotes: ProductionNotes
    ) {
        self.version = version
        self.duration = duration
        self.scenes = scenes
        self.videoSpecs = videoSpecs
        self.voiceoverScript = voiceoverScript
        self.musicCues = musicCues
        self.productionNotes = productionNotes
    }

    /// Default 30-second preview script
    public static let standard = AppPreviewScript(
        duration: 30.0,
        scenes: PreviewScene.standardScenes,
        videoSpecs: .iPhone,
        voiceoverScript: .english,
        musicCues: .cinematic,
        productionNotes: .appStore
    )
}

// MARK: - Preview Scene

/// Individual scene in the preview video
public struct PreviewScene: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let startTime: TimeInterval
    public let duration: TimeInterval
    public let visualDescription: String
    public let onScreenText: [TextOverlay]
    public let uiElements: [String]
    public let cameraMovement: CameraMovement
    public let transition: SceneTransition

    public var endTime: TimeInterval {
        startTime + duration
    }

    public init(
        id: String,
        name: String,
        startTime: TimeInterval,
        duration: TimeInterval,
        visualDescription: String,
        onScreenText: [TextOverlay],
        uiElements: [String],
        cameraMovement: CameraMovement = .static,
        transition: SceneTransition = .cut
    ) {
        self.id = id
        self.name = name
        self.startTime = startTime
        self.duration = duration
        self.visualDescription = visualDescription
        self.onScreenText = onScreenText
        self.uiElements = uiElements
        self.cameraMovement = cameraMovement
        self.transition = transition
    }

    /// Standard 30-second preview scenes
    public static let standardScenes: [PreviewScene] = [
        // Scene 1: Opening Hook (0-3s)
        PreviewScene(
            id: "scene_1_hook",
            name: "Opening Hook",
            startTime: 0.0,
            duration: 3.0,
            visualDescription: """
            Black screen fades to Echoelmusic app icon with subtle glow.
            App icon morphs into a pulsing heart surrounded by sound waves.
            Background: Deep cosmic purple gradient with particle effects.
            """,
            onScreenText: [
                TextOverlay(
                    text: "Transform Your Body Into Music",
                    font: .headline,
                    position: .center,
                    startTime: 0.5,
                    duration: 2.5,
                    animation: .fadeIn
                )
            ],
            uiElements: ["App Icon", "Heart Pulse", "Sound Waves"],
            cameraMovement: .slowZoomIn,
            transition: .dissolve
        ),

        // Scene 2: Bio-Reactive Demo (3-8s)
        PreviewScene(
            id: "scene_2_bioreactive",
            name: "Bio-Reactive Demo",
            startTime: 3.0,
            duration: 5.0,
            visualDescription: """
            iPhone screen showing real-time heart rate visualization.
            Heart rate: 72 BPM displayed prominently.
            Coherence meter rises from 45% to 85%.
            Waveform visualization responds to heartbeat.
            Sacred geometry particles sync with heart rhythm.
            """,
            onScreenText: [
                TextOverlay(
                    text: "Real-Time Heart Rate",
                    font: .subheadline,
                    position: .top,
                    startTime: 3.2,
                    duration: 1.5,
                    animation: .fadeIn
                ),
                TextOverlay(
                    text: "Your Heart Controls The Music",
                    font: .body,
                    position: .bottom,
                    startTime: 4.5,
                    duration: 3.0,
                    animation: .slideUp
                )
            ],
            uiElements: [
                "Heart Rate Display",
                "Coherence Meter",
                "Waveform Visualization",
                "BPM Counter"
            ],
            cameraMovement: .panRight,
            transition: .crossDissolve
        ),

        // Scene 3: Quantum Visuals (8-13s)
        PreviewScene(
            id: "scene_3_quantum",
            name: "Quantum Visuals",
            startTime: 8.0,
            duration: 5.0,
            visualDescription: """
            Explosion of quantum visual effects:
            - Sacred geometry (Flower of Life) expands from center
            - Particle systems flow in Fibonacci spirals
            - Color shifts from blue to purple to gold
            - Mandala patterns rotate and morph
            - Light rays emanate from center
            Full screen visual showcase, minimal UI
            """,
            onScreenText: [
                TextOverlay(
                    text: "Quantum Visuals",
                    font: .headline,
                    position: .topLeading,
                    startTime: 8.5,
                    duration: 2.0,
                    animation: .fadeIn
                ),
                TextOverlay(
                    text: "Sacred Geometry • Particles • Fractals",
                    font: .caption,
                    position: .bottomLeading,
                    startTime: 9.5,
                    duration: 3.0,
                    animation: .fadeIn
                )
            ],
            uiElements: [
                "Sacred Geometry Layer",
                "Particle System",
                "Mandala Rotator",
                "Color Gradient"
            ],
            cameraMovement: .rotateClockwise,
            transition: .zoom
        ),

        // Scene 4: Cinematic Orchestral (13-18s)
        PreviewScene(
            id: "scene_4_orchestral",
            name: "Cinematic Orchestral",
            startTime: 13.0,
            duration: 5.0,
            visualDescription: """
            Split screen view:
            Left: Orchestra section controls (Strings, Brass, Woodwinds)
            Right: Animated musical score with notes flowing
            Background: Concert hall with stage lighting
            Articulation selector showing 'Legato' → 'Spiccato'
            Dynamic marking changes: 'mp' → 'f' → 'ff'
            """,
            onScreenText: [
                TextOverlay(
                    text: "Professional Orchestral Scoring",
                    font: .headline,
                    position: .top,
                    startTime: 13.5,
                    duration: 2.5,
                    animation: .fadeIn
                ),
                TextOverlay(
                    text: "Walt Disney & Hollywood Style",
                    font: .subheadline,
                    position: .center,
                    startTime: 15.0,
                    duration: 2.5,
                    animation: .fadeIn
                )
            ],
            uiElements: [
                "Orchestra Section Buttons",
                "Articulation Picker",
                "Dynamic Slider",
                "Musical Score View",
                "Stage Positioning Map"
            ],
            cameraMovement: .panLeft,
            transition: .wipe
        ),

        // Scene 5: Worldwide Collaboration (18-23s)
        PreviewScene(
            id: "scene_5_collaboration",
            name: "Worldwide Collaboration",
            startTime: 18.0,
            duration: 5.0,
            visualDescription: """
            3D globe with connection lines between users.
            User avatars appear in different countries (USA, Germany, Japan, Brazil).
            Real-time coherence sync visualization with pulsing connections.
            Participant count: 4 → 12 → 47 users joining.
            Group coherence meter shows synchronized rise.
            Bottom: Session type 'Music Jam Session'
            """,
            onScreenText: [
                TextOverlay(
                    text: "Collaborate Worldwide",
                    font: .headline,
                    position: .top,
                    startTime: 18.5,
                    duration: 2.0,
                    animation: .fadeIn
                ),
                TextOverlay(
                    text: "Zero-Latency Sync • 1000+ Users",
                    font: .body,
                    position: .bottom,
                    startTime: 19.5,
                    duration: 3.0,
                    animation: .slideUp
                )
            ],
            uiElements: [
                "3D Globe View",
                "User Avatars",
                "Connection Lines",
                "Participant Counter",
                "Group Coherence Meter",
                "Session Info Panel"
            ],
            cameraMovement: .orbitAroundGlobe,
            transition: .crossDissolve
        ),

        // Scene 6: Call to Action (23-30s)
        PreviewScene(
            id: "scene_6_cta",
            name: "Call to Action",
            startTime: 23.0,
            duration: 7.0,
            visualDescription: """
            Montage of 4-6 quick feature highlights (0.5s each):
            - Breathing guide interface
            - Laser light show designer
            - AI sound designer plugin
            - Apple Watch complication
            - visionOS immersive space
            - Preset browser

            Final frame (25-30s):
            - App icon centered
            - Echoelmusic logo
            - "Download Now" button with glow
            - 5-star rating display
            - Platform icons (iPhone, iPad, Mac, Watch, Vision Pro)
            """,
            onScreenText: [
                TextOverlay(
                    text: "Download Echoelmusic",
                    font: .largeTitle,
                    position: .center,
                    startTime: 25.0,
                    duration: 5.0,
                    animation: .scaleUp
                ),
                TextOverlay(
                    text: "Available on iPhone, iPad, Mac, Watch & Vision Pro",
                    font: .caption,
                    position: .bottom,
                    startTime: 26.0,
                    duration: 4.0,
                    animation: .fadeIn
                )
            ],
            uiElements: [
                "Feature Montage",
                "App Icon",
                "Logo",
                "Download Button",
                "Star Rating",
                "Platform Icons"
            ],
            cameraMovement: .zoomOut,
            transition: .fadeToBlack
        )
    ]
}

// MARK: - Text Overlay

public struct TextOverlay: Codable, Sendable {
    public enum Font: String, Codable, Sendable {
        case largeTitle
        case title
        case headline
        case subheadline
        case body
        case callout
        case caption
        case footnote

        public var size: CGFloat {
            switch self {
            case .largeTitle: return 48
            case .title: return 36
            case .headline: return 28
            case .subheadline: return 22
            case .body: return 20
            case .callout: return 18
            case .caption: return 16
            case .footnote: return 14
            }
        }
    }

    public enum Position: String, Codable, Sendable {
        case top, center, bottom
        case topLeading, topTrailing
        case leading, trailing
        case bottomLeading, bottomTrailing
    }

    public enum Animation: String, Codable, Sendable {
        case fadeIn, fadeOut
        case slideUp, slideDown, slideLeft, slideRight
        case scaleUp, scaleDown
        case typewriter
        case none
    }

    public let text: String
    public let font: Font
    public let position: Position
    public let startTime: TimeInterval
    public let duration: TimeInterval
    public let animation: Animation
    public let color: String // Hex color

    public var endTime: TimeInterval {
        startTime + duration
    }

    public init(
        text: String,
        font: Font,
        position: Position,
        startTime: TimeInterval,
        duration: TimeInterval,
        animation: Animation = .fadeIn,
        color: String = "#FFFFFF"
    ) {
        self.text = text
        self.font = font
        self.position = position
        self.startTime = startTime
        self.duration = duration
        self.animation = animation
        self.color = color
    }
}

// MARK: - Camera Movement

public enum CameraMovement: String, Codable, Sendable {
    case `static`
    case slowZoomIn
    case slowZoomOut
    case panLeft
    case panRight
    case panUp
    case panDown
    case rotateClockwise
    case rotateCounterClockwise
    case orbitAroundGlobe
    case zoomOut
    case dollyIn
    case dollyOut

    public var description: String {
        switch self {
        case .static: return "Fixed camera position"
        case .slowZoomIn: return "Slow zoom toward subject (0-10%)"
        case .slowZoomOut: return "Slow zoom away from subject"
        case .panLeft: return "Pan camera left (10-20° over duration)"
        case .panRight: return "Pan camera right (10-20° over duration)"
        case .panUp: return "Pan camera up"
        case .panDown: return "Pan camera down"
        case .rotateClockwise: return "Rotate clockwise around center"
        case .rotateCounterClockwise: return "Rotate counter-clockwise"
        case .orbitAroundGlobe: return "Orbit 45° around 3D globe"
        case .zoomOut: return "Fast zoom out reveal"
        case .dollyIn: return "Camera moves forward"
        case .dollyOut: return "Camera moves backward"
        }
    }
}

// MARK: - Scene Transition

public enum SceneTransition: String, Codable, Sendable {
    case cut
    case dissolve
    case crossDissolve
    case fadeToBlack
    case fadeFromBlack
    case wipe
    case slide
    case zoom
    case spin

    public var durationSeconds: TimeInterval {
        switch self {
        case .cut: return 0.0
        case .dissolve, .crossDissolve: return 0.5
        case .fadeToBlack, .fadeFromBlack: return 0.8
        case .wipe, .slide: return 0.4
        case .zoom, .spin: return 0.6
        }
    }
}

// MARK: - Video Specifications

public struct VideoSpecifications: Codable, Sendable {
    public let platform: Platform
    public let resolution: Resolution
    public let aspectRatio: String
    public let frameRate: Int
    public let duration: TimeInterval
    public let codec: String
    public let bitrate: String
    public let fileFormat: String

    public enum Platform: String, Codable, Sendable {
        case iPhone
        case iPad
        case mac
        case appleTV
        case appleWatch
        case visionPro
    }

    public struct Resolution: Codable, Sendable {
        public let width: Int
        public let height: Int

        public var description: String {
            "\(width)×\(height)"
        }

        public init(width: Int, height: Int) {
            self.width = width
            self.height = height
        }
    }

    public init(
        platform: Platform,
        resolution: Resolution,
        aspectRatio: String,
        frameRate: Int = 30,
        duration: TimeInterval = 30.0,
        codec: String = "H.264",
        bitrate: String = "8-10 Mbps",
        fileFormat: String = "MOV or MP4"
    ) {
        self.platform = platform
        self.resolution = resolution
        self.aspectRatio = aspectRatio
        self.frameRate = frameRate
        self.duration = duration
        self.codec = codec
        self.bitrate = bitrate
        self.fileFormat = fileFormat
    }

    // MARK: Platform Presets

    public static let iPhone = VideoSpecifications(
        platform: .iPhone,
        resolution: Resolution(width: 886, height: 1920),
        aspectRatio: "9:19.5",
        frameRate: 30,
        duration: 30.0
    )

    public static let iPhoneAlternate = VideoSpecifications(
        platform: .iPhone,
        resolution: Resolution(width: 1080, height: 1920),
        aspectRatio: "9:16",
        frameRate: 30,
        duration: 30.0
    )

    public static let iPad = VideoSpecifications(
        platform: .iPad,
        resolution: Resolution(width: 1200, height: 1600),
        aspectRatio: "3:4",
        frameRate: 30,
        duration: 30.0
    )

    public static let mac = VideoSpecifications(
        platform: .mac,
        resolution: Resolution(width: 1920, height: 1080),
        aspectRatio: "16:9",
        frameRate: 30,
        duration: 30.0
    )

    public static let appleTV = VideoSpecifications(
        platform: .appleTV,
        resolution: Resolution(width: 1920, height: 1080),
        aspectRatio: "16:9",
        frameRate: 30,
        duration: 30.0
    )

    public static let appleWatch = VideoSpecifications(
        platform: .appleWatch,
        resolution: Resolution(width: 348, height: 442),
        aspectRatio: "4:5",
        frameRate: 30,
        duration: 15.0
    )

    public static let visionPro = VideoSpecifications(
        platform: .visionPro,
        resolution: Resolution(width: 1920, height: 1080),
        aspectRatio: "16:9",
        frameRate: 30,
        duration: 30.0
    )
}

// MARK: - Voiceover Script

public struct VoiceoverScript: Codable, Sendable {
    public let language: String
    public let languageCode: String
    public let lines: [VoiceoverLine]
    public let tone: VoiceTone
    public let gender: VoiceGender
    public let pace: VoicePace

    public enum VoiceTone: String, Codable, Sendable {
        case excited
        case calm
        case professional
        case inspiring
        case friendly
        case dramatic
    }

    public enum VoiceGender: String, Codable, Sendable {
        case male
        case female
        case neutral
    }

    public enum VoicePace: String, Codable, Sendable {
        case slow
        case medium
        case fast
    }

    public init(
        language: String,
        languageCode: String,
        lines: [VoiceoverLine],
        tone: VoiceTone = .inspiring,
        gender: VoiceGender = .neutral,
        pace: VoicePace = .medium
    ) {
        self.language = language
        self.languageCode = languageCode
        self.lines = lines
        self.tone = tone
        self.gender = gender
        self.pace = pace
    }

    // MARK: Language Presets

    public static let english = VoiceoverScript(
        language: "English",
        languageCode: "en-US",
        lines: [
            VoiceoverLine(
                startTime: 0.5,
                duration: 2.5,
                text: "What if your body could create music?",
                emphasis: [.word(2), .word(6)]
            ),
            VoiceoverLine(
                startTime: 3.5,
                duration: 4.0,
                text: "Echoelmusic transforms your heart rate, breathing, and movements into stunning audio and visuals.",
                emphasis: [.word(4), .word(6)]
            ),
            VoiceoverLine(
                startTime: 8.5,
                duration: 4.0,
                text: "Experience quantum-inspired visuals that react to your inner state.",
                emphasis: [.word(1), .word(7)]
            ),
            VoiceoverLine(
                startTime: 13.5,
                duration: 4.0,
                text: "Compose cinematic orchestral scores, Walt Disney style.",
                emphasis: [.word(4), .word(5)]
            ),
            VoiceoverLine(
                startTime: 18.5,
                duration: 4.0,
                text: "Collaborate with thousands of users worldwide in real-time.",
                emphasis: [.word(0), .word(6)]
            ),
            VoiceoverLine(
                startTime: 24.0,
                duration: 5.5,
                text: "Download Echoelmusic today. Transform your consciousness into art.",
                emphasis: [.word(1), .word(6)]
            )
        ],
        tone: .inspiring,
        gender: .neutral,
        pace: .medium
    )

    public static let german = VoiceoverScript(
        language: "German",
        languageCode: "de-DE",
        lines: [
            VoiceoverLine(
                startTime: 0.5,
                duration: 2.5,
                text: "Was wäre, wenn dein Körper Musik erschaffen könnte?",
                emphasis: [.word(5)]
            ),
            VoiceoverLine(
                startTime: 3.5,
                duration: 4.0,
                text: "Echoelmusic verwandelt deinen Herzschlag, Atmung und Bewegungen in atemberaubende Audio- und Visualeffekte.",
                emphasis: [.word(1), .word(9)]
            ),
            VoiceoverLine(
                startTime: 8.5,
                duration: 4.0,
                text: "Erlebe quanteninspirierte Visualisierungen, die auf deinen inneren Zustand reagieren.",
                emphasis: [.word(1), .word(8)]
            ),
            VoiceoverLine(
                startTime: 13.5,
                duration: 4.0,
                text: "Komponiere filmreife Orchester-Partituren im Walt Disney Stil.",
                emphasis: [.word(3), .word(5)]
            ),
            VoiceoverLine(
                startTime: 18.5,
                duration: 4.0,
                text: "Arbeite mit tausenden Nutzern weltweit in Echtzeit zusammen.",
                emphasis: [.word(3), .word(6)]
            ),
            VoiceoverLine(
                startTime: 24.0,
                duration: 5.5,
                text: "Lade Echoelmusic noch heute herunter. Verwandle dein Bewusstsein in Kunst.",
                emphasis: [.word(1), .word(8)]
            )
        ],
        tone: .inspiring,
        gender: .neutral,
        pace: .medium
    )

    public static let japanese = VoiceoverScript(
        language: "Japanese",
        languageCode: "ja-JP",
        lines: [
            VoiceoverLine(
                startTime: 0.5,
                duration: 2.5,
                text: "もしあなたの体が音楽を創り出せたら?",
                emphasis: [.word(2), .word(4)]
            ),
            VoiceoverLine(
                startTime: 3.5,
                duration: 4.0,
                text: "Echoelmusicは心拍数、呼吸、動きを美しい音楽とビジュアルに変換します。",
                emphasis: [.word(2), .word(7)]
            ),
            VoiceoverLine(
                startTime: 8.5,
                duration: 4.0,
                text: "あなたの内なる状態に反応する量子ビジュアルを体験してください。",
                emphasis: [.word(4), .word(6)]
            ),
            VoiceoverLine(
                startTime: 13.5,
                duration: 4.0,
                text: "ウォルト・ディズニースタイルの映画的なオーケストラ楽譜を作曲します。",
                emphasis: [.word(1), .word(5)]
            ),
            VoiceoverLine(
                startTime: 18.5,
                duration: 4.0,
                text: "世界中の何千人ものユーザーとリアルタイムでコラボレーションします。",
                emphasis: [.word(2), .word(6)]
            ),
            VoiceoverLine(
                startTime: 24.0,
                duration: 5.5,
                text: "今すぐEchoelmusicをダウンロード。あなたの意識をアートに変えましょう。",
                emphasis: [.word(1), .word(7)]
            )
        ],
        tone: .inspiring,
        gender: .neutral,
        pace: .medium
    )
}

public struct VoiceoverLine: Codable, Sendable {
    public let startTime: TimeInterval
    public let duration: TimeInterval
    public let text: String
    public let emphasis: [Emphasis]

    public enum Emphasis: Codable, Sendable {
        case word(Int) // Word index to emphasize
        case phrase(Range<Int>) // Range of words

        enum CodingKeys: String, CodingKey {
            case type
            case wordIndex
            case rangeStart
            case rangeEnd
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "word":
                let index = try container.decode(Int.self, forKey: .wordIndex)
                self = .word(index)
            case "phrase":
                let start = try container.decode(Int.self, forKey: .rangeStart)
                let end = try container.decode(Int.self, forKey: .rangeEnd)
                self = .phrase(start..<end)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown emphasis type"
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .word(let index):
                try container.encode("word", forKey: .type)
                try container.encode(index, forKey: .wordIndex)
            case .phrase(let range):
                try container.encode("phrase", forKey: .type)
                try container.encode(range.lowerBound, forKey: .rangeStart)
                try container.encode(range.upperBound, forKey: .rangeEnd)
            }
        }
    }

    public var endTime: TimeInterval {
        startTime + duration
    }

    public init(
        startTime: TimeInterval,
        duration: TimeInterval,
        text: String,
        emphasis: [Emphasis] = []
    ) {
        self.startTime = startTime
        self.duration = duration
        self.text = text
        self.emphasis = emphasis
    }
}

// MARK: - Music Cues

public struct MusicCues: Codable, Sendable {
    public let backgroundMusic: BackgroundMusic
    public let soundEffects: [SoundEffect]
    public let audioMixing: AudioMixing

    public init(
        backgroundMusic: BackgroundMusic,
        soundEffects: [SoundEffect],
        audioMixing: AudioMixing
    ) {
        self.backgroundMusic = backgroundMusic
        self.soundEffects = soundEffects
        self.audioMixing = audioMixing
    }

    public static let cinematic = MusicCues(
        backgroundMusic: BackgroundMusic(
            style: .cinematic,
            bpm: 80,
            key: "C Minor",
            mood: .inspiring,
            description: "Epic cinematic underscore with rising strings and piano"
        ),
        soundEffects: [
            SoundEffect(
                name: "Heartbeat Pulse",
                timing: [3.5, 4.0, 4.5],
                volume: 0.4,
                description: "Low thump synced to heart visualization"
            ),
            SoundEffect(
                name: "Quantum Shimmer",
                timing: [8.5, 10.0, 11.5],
                volume: 0.3,
                description: "Ethereal particle sound for quantum visuals"
            ),
            SoundEffect(
                name: "Orchestral Swell",
                timing: [13.5],
                volume: 0.5,
                description: "Full orchestra crescendo"
            ),
            SoundEffect(
                name: "Globe Whoosh",
                timing: [18.5],
                volume: 0.35,
                description: "Spatial whoosh as globe appears"
            ),
            SoundEffect(
                name: "Success Chime",
                timing: [25.0],
                volume: 0.4,
                description: "Pleasant chime for CTA reveal"
            )
        ],
        audioMixing: AudioMixing(
            musicVolume: 0.6,
            voiceoverVolume: 1.0,
            sfxVolume: 0.5,
            duckingAmount: 0.4,
            duckingDuration: 0.3,
            fadeInDuration: 2.0,
            fadeOutDuration: 3.0
        )
    )
}

public struct BackgroundMusic: Codable, Sendable {
    public enum Style: String, Codable, Sendable {
        case cinematic
        case electronic
        case ambient
        case orchestral
        case hybrid
    }

    public enum Mood: String, Codable, Sendable {
        case inspiring
        case energetic
        case calm
        case epic
        case mysterious
        case uplifting
    }

    public let style: Style
    public let bpm: Int
    public let key: String
    public let mood: Mood
    public let description: String

    public init(style: Style, bpm: Int, key: String, mood: Mood, description: String) {
        self.style = style
        self.bpm = bpm
        self.key = key
        self.mood = mood
        self.description = description
    }
}

public struct SoundEffect: Codable, Sendable {
    public let name: String
    public let timing: [TimeInterval] // When to play (can repeat)
    public let volume: Double // 0.0 - 1.0
    public let description: String

    public init(name: String, timing: [TimeInterval], volume: Double, description: String) {
        self.name = name
        self.timing = timing
        self.volume = volume
        self.description = description
    }
}

public struct AudioMixing: Codable, Sendable {
    public let musicVolume: Double // Background music level (0.0 - 1.0)
    public let voiceoverVolume: Double // Voiceover level (0.0 - 1.0)
    public let sfxVolume: Double // Sound effects level (0.0 - 1.0)
    public let duckingAmount: Double // How much to reduce music during voiceover
    public let duckingDuration: TimeInterval // How long to fade in/out ducking
    public let fadeInDuration: TimeInterval // Music fade in at start
    public let fadeOutDuration: TimeInterval // Music fade out at end

    public init(
        musicVolume: Double = 0.6,
        voiceoverVolume: Double = 1.0,
        sfxVolume: Double = 0.5,
        duckingAmount: Double = 0.4,
        duckingDuration: TimeInterval = 0.3,
        fadeInDuration: TimeInterval = 2.0,
        fadeOutDuration: TimeInterval = 3.0
    ) {
        self.musicVolume = musicVolume
        self.voiceoverVolume = voiceoverVolume
        self.sfxVolume = sfxVolume
        self.duckingAmount = duckingAmount
        self.duckingDuration = duckingDuration
        self.fadeInDuration = fadeInDuration
        self.fadeOutDuration = fadeOutDuration
    }
}

// MARK: - Production Notes

public struct ProductionNotes: Codable, Sendable {
    public let recordingTips: [String]
    public let editingGuidelines: [String]
    public let compressionSettings: CompressionSettings
    public let submissionRequirements: [String]
    public let assetChecklist: [String]
    public let timingNotes: [String]

    public init(
        recordingTips: [String],
        editingGuidelines: [String],
        compressionSettings: CompressionSettings,
        submissionRequirements: [String],
        assetChecklist: [String],
        timingNotes: [String]
    ) {
        self.recordingTips = recordingTips
        self.editingGuidelines = editingGuidelines
        self.compressionSettings = compressionSettings
        self.submissionRequirements = submissionRequirements
        self.assetChecklist = assetChecklist
        self.timingNotes = timingNotes
    }

    public static let appStore = ProductionNotes(
        recordingTips: [
            "Use screen recording at native resolution (not scaled)",
            "Record at 60 FPS, export at 30 FPS for smooth motion",
            "Ensure device is in portrait orientation for iPhone videos",
            "Disable notifications and clear status bar before recording",
            "Use airplane mode to hide cellular/wifi indicators",
            "Set device to 100% brightness for vibrant colors",
            "Record multiple takes of each scene for options",
            "Capture extra B-roll footage for transitions",
            "Use tripod or stabilizer for steady footage",
            "Record in ProRes 422 HQ for maximum quality"
        ],
        editingGuidelines: [
            "Match exact timing from PreviewScene specifications",
            "Apply color grading for consistent look across scenes",
            "Add motion blur to smooth 60→30 FPS conversion",
            "Use easing curves (ease-in-out) for all animations",
            "Ensure text is readable at all device sizes",
            "Test video on actual devices before submission",
            "Verify all text overlays are safe in title-safe area",
            "Check that transitions are smooth and intentional",
            "Ensure voiceover is perfectly synced with visuals",
            "Export master copy at highest quality before compression",
            "Create separate video files for each platform",
            "Add burned-in captions for accessibility (optional but recommended)"
        ],
        compressionSettings: CompressionSettings(
            codec: "H.264",
            profile: "High",
            level: "4.0",
            bitrate: "8-10 Mbps",
            keyframeInterval: 90,
            colorSpace: "Rec. 709",
            audioCodec: "AAC",
            audioBitrate: "256 kbps",
            audioSampleRate: 48000
        ),
        submissionRequirements: [
            "Maximum file size: 500 MB per video",
            "Maximum duration: 30 seconds (15s for Apple Watch)",
            "Minimum 3 preview videos recommended",
            "Must not include price or promotional text",
            "Cannot reference other platforms (Android, competitors)",
            "Must accurately represent app functionality",
            "No watermarks or logos from external tools",
            "Must be appropriate for all ages (if app is 4+)",
            "Audio must be clear and professional quality",
            "No copyrighted music without proper licensing"
        ],
        assetChecklist: [
            "✓ App icon at various sizes (1024x1024, 180x180, etc.)",
            "✓ Heart rate visualization with sample data",
            "✓ Coherence meter animation",
            "✓ Quantum visual effects rendered",
            "✓ Sacred geometry patterns",
            "✓ Orchestra section UI elements",
            "✓ Musical score animation",
            "✓ 3D globe with connection lines",
            "✓ User avatars and location pins",
            "✓ Feature montage clips (6+ features)",
            "✓ Platform icons (iPhone, iPad, Mac, Watch, Vision Pro)",
            "✓ 'Download Now' button with glow effect",
            "✓ 5-star rating graphic",
            "✓ Background music track (licensed)",
            "✓ Voiceover recording (professional quality)",
            "✓ Sound effects library",
            "✓ Echoelmusic logo (transparent PNG)"
        ],
        timingNotes: [
            "Scene 1 (0-3s): Quick hook to grab attention immediately",
            "Scene 2 (3-8s): First feature demo must be impressive",
            "Scene 3 (8-13s): Visual spectacle at the midpoint",
            "Scene 4 (13-18s): Show unique differentiator (orchestral)",
            "Scene 5 (18-23s): Social proof and collaboration",
            "Scene 6 (23-30s): Clear call-to-action, leave no ambiguity",
            "Keep pace energetic but not rushed",
            "Allow 0.5s breathing room between voiceover lines",
            "Sync beat/pulse effects with background music downbeats",
            "Build intensity gradually toward CTA"
        ]
    )
}

public struct CompressionSettings: Codable, Sendable {
    public let codec: String
    public let profile: String
    public let level: String
    public let bitrate: String
    public let keyframeInterval: Int
    public let colorSpace: String
    public let audioCodec: String
    public let audioBitrate: String
    public let audioSampleRate: Int

    public init(
        codec: String,
        profile: String,
        level: String,
        bitrate: String,
        keyframeInterval: Int,
        colorSpace: String,
        audioCodec: String,
        audioBitrate: String,
        audioSampleRate: Int
    ) {
        self.codec = codec
        self.profile = profile
        self.level = level
        self.bitrate = bitrate
        self.keyframeInterval = keyframeInterval
        self.colorSpace = colorSpace
        self.audioCodec = audioCodec
        self.audioBitrate = audioBitrate
        self.audioSampleRate = audioSampleRate
    }
}

// MARK: - Scene Assets

public struct SceneAssets: Codable, Sendable {
    public let sceneId: String
    public let requiredAssets: [Asset]

    public struct Asset: Codable, Sendable {
        public let name: String
        public let type: AssetType
        public let specifications: String
        public let source: String

        public enum AssetType: String, Codable, Sendable {
            case screenRecording
            case animation
            case stillImage
            case graphicElement
            case threeD = "3D"
        }

        public init(name: String, type: AssetType, specifications: String, source: String) {
            self.name = name
            self.type = type
            self.specifications = specifications
            self.source = source
        }
    }

    public init(sceneId: String, requiredAssets: [Asset]) {
        self.sceneId = sceneId
        self.requiredAssets = requiredAssets
    }

    public static let allSceneAssets: [SceneAssets] = [
        SceneAssets(sceneId: "scene_1_hook", requiredAssets: [
            Asset(
                name: "App Icon",
                type: .stillImage,
                specifications: "1024x1024, PNG with transparency",
                source: "Sources/Echoelmusic/Resources/AppIcon.appiconset/"
            ),
            Asset(
                name: "Heart Pulse Animation",
                type: .animation,
                specifications: "Animated heart with glow, 60 FPS",
                source: "Create in After Effects or Motion"
            ),
            Asset(
                name: "Sound Wave Graphics",
                type: .graphicElement,
                specifications: "Circular waveform, animated",
                source: "Generate from real audio data"
            ),
            Asset(
                name: "Cosmic Background",
                type: .animation,
                specifications: "Purple gradient with particles",
                source: "Create procedurally or pre-render"
            )
        ]),

        SceneAssets(sceneId: "scene_2_bioreactive", requiredAssets: [
            Asset(
                name: "HealthKit Integration Screen",
                type: .screenRecording,
                specifications: "iPhone 15 Pro recording, portrait",
                source: "Record live app with simulated HRV data"
            ),
            Asset(
                name: "Heart Rate Visualization",
                type: .animation,
                specifications: "Real-time waveform, 72 BPM",
                source: "Capture from UnifiedControlHub view"
            ),
            Asset(
                name: "Coherence Meter",
                type: .animation,
                specifications: "Circular gauge rising 45% → 85%",
                source: "Screen record or recreate in Motion"
            ),
            Asset(
                name: "Sacred Geometry Particles",
                type: .animation,
                specifications: "Particle system synced to heartbeat",
                source: "PhotonicsVisualizationEngine output"
            )
        ]),

        SceneAssets(sceneId: "scene_3_quantum", requiredAssets: [
            Asset(
                name: "Flower of Life",
                type: .animation,
                specifications: "Expanding sacred geometry, 4K",
                source: "QuantumLightEmulator visualization"
            ),
            Asset(
                name: "Fibonacci Spiral Particles",
                type: .animation,
                specifications: "Golden ratio particle flow",
                source: "PhotonicsVisualizationEngine"
            ),
            Asset(
                name: "Mandala Rotation",
                type: .animation,
                specifications: "12-fold symmetry, morphing",
                source: "Pre-render from visualization engine"
            ),
            Asset(
                name: "Light Ray Effects",
                type: .animation,
                specifications: "Volumetric god rays from center",
                source: "Add in post or use Metal shader"
            )
        ]),

        SceneAssets(sceneId: "scene_4_orchestral", requiredAssets: [
            Asset(
                name: "Orchestra Section UI",
                type: .screenRecording,
                specifications: "CinematicScoringEngine controls",
                source: "Record from FilmScoreComposer view"
            ),
            Asset(
                name: "Musical Score Animation",
                type: .animation,
                specifications: "Notes flowing on staff",
                source: "Create in After Effects with music notation"
            ),
            Asset(
                name: "Concert Hall Background",
                type: .stillImage,
                specifications: "Photo or 3D render of stage",
                source: "Stock photo or Cinema 4D render"
            ),
            Asset(
                name: "Articulation Selector",
                type: .animation,
                specifications: "Picker wheel changing values",
                source: "Screen record SwiftUI picker"
            )
        ]),

        SceneAssets(sceneId: "scene_5_collaboration", requiredAssets: [
            Asset(
                name: "3D Globe",
                type: .threeD,
                specifications: "Rotating Earth with connections",
                source: "SceneKit or Unity render"
            ),
            Asset(
                name: "User Avatars",
                type: .graphicElement,
                specifications: "Circular profile images with flags",
                source: "Design in Figma, export as PNG"
            ),
            Asset(
                name: "Connection Lines",
                type: .animation,
                specifications: "Animated arcs between users",
                source: "Procedural animation in 3D software"
            ),
            Asset(
                name: "Participant Counter",
                type: .animation,
                specifications: "Number counting up: 4 → 47",
                source: "Create animated text in Motion"
            )
        ]),

        SceneAssets(sceneId: "scene_6_cta", requiredAssets: [
            Asset(
                name: "Feature Montage Clips",
                type: .screenRecording,
                specifications: "6 clips, 0.5s each, rapid cuts",
                source: "Screen record from various app features"
            ),
            Asset(
                name: "App Icon (Final Frame)",
                type: .stillImage,
                specifications: "1024x1024, centered on black",
                source: "AppIcon.appiconset"
            ),
            Asset(
                name: "Echoelmusic Logo",
                type: .stillImage,
                specifications: "Transparent PNG, white version",
                source: "Design in Illustrator"
            ),
            Asset(
                name: "Download Button",
                type: .graphicElement,
                specifications: "Rounded rect with glow effect",
                source: "Create in Figma or After Effects"
            ),
            Asset(
                name: "Platform Icons",
                type: .stillImage,
                specifications: "iPhone, iPad, Mac, Watch, Vision Pro",
                source: "SF Symbols or custom icons"
            )
        ])
    ]
}

// MARK: - Export Utility

public struct AppPreviewExporter {
    /// Export full script as JSON
    public static func exportJSON(script: AppPreviewScript) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(script)
    }

    /// Export voiceover script as plain text
    public static func exportVoiceoverText(script: VoiceoverScript) -> String {
        var output = "# Voiceover Script - \(script.language)\n\n"
        output += "Language: \(script.language) (\(script.languageCode))\n"
        output += "Tone: \(script.tone.rawValue.capitalized)\n"
        output += "Gender: \(script.gender.rawValue.capitalized)\n"
        output += "Pace: \(script.pace.rawValue.capitalized)\n\n"
        output += "---\n\n"

        for (index, line) in script.lines.enumerated() {
            output += "## Line \(index + 1) (\(String(format: "%.1f", line.startTime))s - \(String(format: "%.1f", line.endTime))s)\n\n"
            output += "\(line.text)\n\n"

            if !line.emphasis.isEmpty {
                output += "*Emphasis: "
                for emph in line.emphasis {
                    switch emph {
                    case .word(let idx):
                        output += "word \(idx), "
                    case .phrase(let range):
                        output += "words \(range.lowerBound)-\(range.upperBound), "
                    }
                }
                output += "*\n\n"
            }
        }

        return output
    }

    /// Export scene breakdown as CSV for production schedule
    public static func exportSceneCSV(scenes: [PreviewScene]) -> String {
        var csv = "Scene ID,Name,Start Time,Duration,End Time,Visual Description,On-Screen Text Count,Camera Movement,Transition\n"

        for scene in scenes {
            let row = [
                scene.id,
                scene.name,
                String(format: "%.1f", scene.startTime),
                String(format: "%.1f", scene.duration),
                String(format: "%.1f", scene.endTime),
                "\"\(scene.visualDescription.replacingOccurrences(of: "\n", with: " "))\"",
                String(scene.onScreenText.count),
                scene.cameraMovement.rawValue,
                scene.transition.rawValue
            ]
            csv += row.joined(separator: ",") + "\n"
        }

        return csv
    }
}

// MARK: - Preview Generation Helper

#if DEBUG
public struct AppPreviewDebugHelper {
    /// Log full script breakdown for debugging
    public static func logScriptBreakdown(script: AppPreviewScript = .standard) {
        log.debug("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", category: .video)
        log.debug("APP STORE PREVIEW VIDEO SCRIPT", category: .video)
        log.debug("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", category: .video)
        log.debug("Duration: \(script.duration)s", category: .video)
        log.debug("Platform: \(script.videoSpecs.platform.rawValue)", category: .video)
        log.debug("Resolution: \(script.videoSpecs.resolution.description)", category: .video)
        log.debug("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", category: .video)

        for scene in script.scenes {
            log.debug("Scene: \(scene.name) (\(String(format: "%.1f", scene.startTime))s - \(String(format: "%.1f", scene.endTime))s)", category: .video)
            log.debug("   \(scene.visualDescription.replacingOccurrences(of: "\n", with: "\n   "))", category: .video)
            log.debug("   Camera: \(scene.cameraMovement.rawValue)", category: .video)

            if !scene.onScreenText.isEmpty {
                log.debug("   Text Overlays:", category: .video)
                for text in scene.onScreenText {
                    log.debug("   - \(text.text) (\(String(format: "%.1f", text.startTime))s)", category: .video)
                }
            }
        }

        log.debug("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", category: .video)
        log.debug("VOICEOVER SCRIPT (\(script.voiceoverScript.language))", category: .video)
        log.debug("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", category: .video)

        for (index, line) in script.voiceoverScript.lines.enumerated() {
            log.debug("\(index + 1). (\(String(format: "%.1f", line.startTime))s) \(line.text)", category: .video)
        }

        log.debug("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", category: .video)
    }

    /// Deprecated: Use logScriptBreakdown() instead
    @available(*, deprecated, renamed: "logScriptBreakdown")
    public static func printScriptBreakdown(script: AppPreviewScript = .standard) {
        logScriptBreakdown(script: script)
    }
}
#endif

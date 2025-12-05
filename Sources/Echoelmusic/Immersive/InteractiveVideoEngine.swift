// InteractiveVideoEngine.swift
// Echoelmusic
//
// Interactive Video System with Hotspots, Annotations, Overlays, and Branching Stories
// Supports all platforms: visionOS, WebXR, Meta Quest, Android XR, Windows MR
//
// Created by Echoelmusic on 2025-12-05.

import Foundation
import SwiftUI
import Combine
import simd

// MARK: - Interactive Story

public struct InteractiveStory: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var description: String
    public var author: String
    public var version: String
    public var scenes: [Scene]
    public var startSceneId: UUID
    public var globalAssets: [Asset]
    public var variables: [String: VariableValue]
    public var analytics: AnalyticsConfig
    public var accessibility: AccessibilityConfig
    public var createdAt: Date
    public var updatedAt: Date

    public struct Scene: Identifiable, Codable {
        public let id: UUID
        public var name: String
        public var videoURL: URL?
        public var audioURL: URL?
        public var duration: TimeInterval
        public var hotspots: [Hotspot]
        public var annotations: [Annotation]
        public var overlays: [Overlay]
        public var branches: [Branch]
        public var triggers: [TimeTrigger]
        public var ambientAudio: URL?
        public var skybox: URL?
        public var defaultTransition: Transition
    }

    public struct Asset: Identifiable, Codable {
        public let id: UUID
        public var name: String
        public var type: AssetType
        public var url: URL
        public var preload: Bool

        public enum AssetType: String, Codable {
            case image, video, audio, model3D, texture, font
        }
    }

    public enum VariableValue: Codable {
        case string(String)
        case int(Int)
        case float(Float)
        case bool(Bool)
        case array([VariableValue])
    }

    public struct AnalyticsConfig: Codable {
        public var trackViews: Bool
        public var trackInteractions: Bool
        public var trackProgress: Bool
        public var trackChoices: Bool
        public var customEvents: [String]
    }

    public struct AccessibilityConfig: Codable {
        public var subtitlesAvailable: Bool
        public var audioDescriptionAvailable: Bool
        public var signLanguageAvailable: Bool
        public var defaultSubtitleLanguage: String?
        public var highContrastMode: Bool
    }

    public init(title: String) {
        self.id = UUID()
        self.title = title
        self.description = ""
        self.author = ""
        self.version = "1.0"
        self.scenes = []
        self.startSceneId = UUID()
        self.globalAssets = []
        self.variables = [:]
        self.analytics = AnalyticsConfig(
            trackViews: true,
            trackInteractions: true,
            trackProgress: true,
            trackChoices: true,
            customEvents: []
        )
        self.accessibility = AccessibilityConfig(
            subtitlesAvailable: true,
            audioDescriptionAvailable: false,
            signLanguageAvailable: false,
            highContrastMode: false
        )
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Hotspot

public struct Hotspot: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var type: HotspotType
    public var shape: HotspotShape
    public var position: SphericalPosition
    public var size: SIMD2<Float>
    public var rotation: Float // degrees
    public var timeRange: ClosedRange<TimeInterval>
    public var style: HotspotStyle
    public var content: HotspotContent
    public var actions: [HotspotAction]
    public var conditions: [Condition]
    public var audioFeedback: URL?
    public var hapticPattern: HapticPattern?

    public enum HotspotType: String, Codable {
        case info = "Information"
        case navigation = "Navigation"
        case media = "Media"
        case product = "Product"
        case quiz = "Quiz"
        case social = "Social"
        case teleport = "Teleport"
        case custom = "Custom"
    }

    public enum HotspotShape: String, Codable {
        case circle, rectangle, polygon, sphere, cylinder, custom
    }

    public struct SphericalPosition: Codable {
        public var longitude: Float // -180 to 180
        public var latitude: Float // -90 to 90
        public var depth: Float // distance from center
        public var lockToHead: Bool // follows head movement

        public init(longitude: Float = 0, latitude: Float = 0, depth: Float = 5, lockToHead: Bool = false) {
            self.longitude = longitude
            self.latitude = latitude
            self.depth = depth
            self.lockToHead = lockToHead
        }

        public var cartesian: SIMD3<Float> {
            let lonRad = longitude * .pi / 180
            let latRad = latitude * .pi / 180
            return SIMD3<Float>(
                depth * cos(latRad) * sin(lonRad),
                depth * sin(latRad),
                -depth * cos(latRad) * cos(lonRad)
            )
        }
    }

    public struct HotspotStyle: Codable {
        public var icon: String?
        public var iconColor: String
        public var backgroundColor: String
        public var borderColor: String
        public var borderWidth: Float
        public var opacity: Float
        public var glowColor: String?
        public var glowIntensity: Float
        public var pulseAnimation: Bool
        public var pulseSpeed: Float
        public var scaleOnHover: Float
        public var visibleWhenNotLooking: Bool

        public static let `default` = HotspotStyle(
            icon: "circle.fill",
            iconColor: "#FFFFFF",
            backgroundColor: "#00000080",
            borderColor: "#FFFFFF",
            borderWidth: 2,
            opacity: 1.0,
            glowColor: "#6366F1",
            glowIntensity: 0.5,
            pulseAnimation: true,
            pulseSpeed: 1.0,
            scaleOnHover: 1.2,
            visibleWhenNotLooking: true
        )
    }

    public struct HotspotContent: Codable {
        public var title: String?
        public var subtitle: String?
        public var body: String?
        public var imageURL: URL?
        public var videoURL: URL?
        public var audioURL: URL?
        public var modelURL: URL?
        public var linkURL: URL?
        public var price: String?
        public var rating: Float?
        public var customHTML: String?
        public var customData: [String: String]

        public init() {
            self.customData = [:]
        }
    }

    public struct HotspotAction: Codable {
        public var trigger: Trigger
        public var action: Action
        public var delay: TimeInterval
        public var conditions: [Condition]

        public enum Trigger: String, Codable {
            case gaze = "Gaze"
            case gazeDwell = "Gaze Dwell"
            case click = "Click"
            case hover = "Hover"
            case proximity = "Proximity"
            case voice = "Voice"
            case gesture = "Gesture"
            case controller = "Controller"
        }

        public enum Action: Codable {
            case showContent
            case hideContent
            case playVideo(url: URL)
            case playAudio(url: URL)
            case navigateScene(sceneId: UUID)
            case jumpToTime(time: TimeInterval)
            case openURL(url: URL)
            case setVariable(name: String, value: InteractiveStory.VariableValue)
            case triggerAnimation(name: String)
            case sendAnalytics(event: String, data: [String: String])
            case showQuiz(quizId: UUID)
            case addToCart(productId: String)
            case share(platform: String)
            case teleport(position: SphericalPosition)
            case custom(handler: String)
        }
    }

    public enum HapticPattern: String, Codable {
        case light, medium, heavy, selection, success, warning, error
    }

    public init(name: String, type: HotspotType, position: SphericalPosition) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.shape = .circle
        self.position = position
        self.size = SIMD2<Float>(0.3, 0.3)
        self.rotation = 0
        self.timeRange = 0...Double.infinity
        self.style = .default
        self.content = HotspotContent()
        self.actions = []
        self.conditions = []
    }
}

// MARK: - Annotation

public struct Annotation: Identifiable, Codable {
    public let id: UUID
    public var type: AnnotationType
    public var position: Hotspot.SphericalPosition
    public var timeRange: ClosedRange<TimeInterval>
    public var content: AnnotationContent
    public var style: AnnotationStyle
    public var animation: AnnotationAnimation

    public enum AnnotationType: String, Codable {
        case text = "Text"
        case title = "Title"
        case subtitle = "Subtitle"
        case caption = "Caption"
        case callout = "Callout"
        case label = "Label"
        case badge = "Badge"
        case tooltip = "Tooltip"
        case speechBubble = "Speech Bubble"
    }

    public struct AnnotationContent: Codable {
        public var text: String
        public var formattedText: String? // HTML/Markdown
        public var icon: String?
        public var imageURL: URL?
        public var speakerName: String?
        public var language: String?
    }

    public struct AnnotationStyle: Codable {
        public var fontFamily: String
        public var fontSize: Float
        public var fontWeight: String
        public var textColor: String
        public var backgroundColor: String
        public var backgroundBlur: Float
        public var cornerRadius: Float
        public var padding: Float
        public var maxWidth: Float
        public var alignment: TextAlignment
        public var shadow: Bool
        public var outline: Bool
        public var outlineColor: String

        public enum TextAlignment: String, Codable {
            case left, center, right
        }

        public static let `default` = AnnotationStyle(
            fontFamily: "SF Pro",
            fontSize: 18,
            fontWeight: "regular",
            textColor: "#FFFFFF",
            backgroundColor: "#00000099",
            backgroundBlur: 10,
            cornerRadius: 8,
            padding: 12,
            maxWidth: 400,
            alignment: .center,
            shadow: true,
            outline: false,
            outlineColor: "#FFFFFF"
        )
    }

    public struct AnnotationAnimation: Codable {
        public var entrance: AnimationType
        public var exit: AnimationType
        public var duration: TimeInterval
        public var delay: TimeInterval

        public enum AnimationType: String, Codable {
            case none, fade, scale, slide, bounce, typewriter
        }

        public static let `default` = AnnotationAnimation(
            entrance: .fade,
            exit: .fade,
            duration: 0.3,
            delay: 0
        )
    }

    public init(type: AnnotationType, text: String, position: Hotspot.SphericalPosition, timeRange: ClosedRange<TimeInterval>) {
        self.id = UUID()
        self.type = type
        self.position = position
        self.timeRange = timeRange
        self.content = AnnotationContent(text: text)
        self.style = .default
        self.animation = .default
    }
}

// MARK: - Overlay

public struct Overlay: Identifiable, Codable {
    public let id: UUID
    public var type: OverlayType
    public var layer: OverlayLayer
    public var position: OverlayPosition
    public var size: OverlaySize
    public var timeRange: ClosedRange<TimeInterval>
    public var content: OverlayContent
    public var style: OverlayStyle
    public var interactivity: OverlayInteractivity

    public enum OverlayType: String, Codable {
        case image = "Image"
        case video = "Video"
        case lowerThird = "Lower Third"
        case logo = "Logo"
        case watermark = "Watermark"
        case progressBar = "Progress Bar"
        case chapterMarker = "Chapter Marker"
        case socialFeed = "Social Feed"
        case liveChat = "Live Chat"
        case poll = "Poll"
        case countdown = "Countdown"
        case musicVisualizer = "Music Visualizer"
        case bioMetrics = "Bio Metrics"
        case miniMap = "Mini Map"
        case compass = "Compass"
        case custom = "Custom"
    }

    public enum OverlayLayer: Int, Codable {
        case background = 0
        case content = 1
        case ui = 2
        case foreground = 3
        case hud = 4
    }

    public struct OverlayPosition: Codable {
        public var anchor: Anchor
        public var offsetX: Float
        public var offsetY: Float
        public var sphericalPosition: Hotspot.SphericalPosition?
        public var followGaze: Bool
        public var lockToWorld: Bool

        public enum Anchor: String, Codable {
            case topLeft, topCenter, topRight
            case centerLeft, center, centerRight
            case bottomLeft, bottomCenter, bottomRight
            case spherical // Uses sphericalPosition
        }

        public static let bottomCenter = OverlayPosition(
            anchor: .bottomCenter,
            offsetX: 0,
            offsetY: -50,
            followGaze: false,
            lockToWorld: false
        )
    }

    public struct OverlaySize: Codable {
        public var width: SizeValue
        public var height: SizeValue
        public var maintainAspectRatio: Bool

        public enum SizeValue: Codable {
            case pixels(Float)
            case percentage(Float)
            case auto

            public var isAuto: Bool {
                if case .auto = self { return true }
                return false
            }
        }
    }

    public struct OverlayContent: Codable {
        public var imageURL: URL?
        public var videoURL: URL?
        public var text: String?
        public var htmlContent: String?
        public var dataBinding: String? // Variable name to bind
        public var refreshInterval: TimeInterval?
    }

    public struct OverlayStyle: Codable {
        public var opacity: Float
        public var backgroundColor: String?
        public var cornerRadius: Float
        public var shadow: ShadowStyle?
        public var border: BorderStyle?
        public var blur: Float

        public struct ShadowStyle: Codable {
            public var color: String
            public var radius: Float
            public var offsetX: Float
            public var offsetY: Float
        }

        public struct BorderStyle: Codable {
            public var color: String
            public var width: Float
        }

        public static let `default` = OverlayStyle(
            opacity: 1.0,
            cornerRadius: 0,
            blur: 0
        )
    }

    public struct OverlayInteractivity: Codable {
        public var clickable: Bool
        public var draggable: Bool
        public var resizable: Bool
        public var dismissible: Bool
        public var actions: [Hotspot.HotspotAction]
    }

    public init(type: OverlayType, position: OverlayPosition) {
        self.id = UUID()
        self.type = type
        self.layer = .ui
        self.position = position
        self.size = OverlaySize(width: .auto, height: .auto, maintainAspectRatio: true)
        self.timeRange = 0...Double.infinity
        self.content = OverlayContent()
        self.style = .default
        self.interactivity = OverlayInteractivity(
            clickable: false,
            draggable: false,
            resizable: false,
            dismissible: false,
            actions: []
        )
    }
}

// MARK: - Branching

public struct Branch: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var type: BranchType
    public var displayTime: TimeInterval
    public var duration: TimeInterval
    public var choices: [Choice]
    public var defaultChoiceId: UUID?
    public var timeoutAction: TimeoutAction
    public var style: BranchStyle

    public enum BranchType: String, Codable {
        case choice = "Choice"
        case conditional = "Conditional"
        case random = "Random"
        case loop = "Loop"
        case parallel = "Parallel"
    }

    public struct Choice: Identifiable, Codable {
        public let id: UUID
        public var label: String
        public var description: String?
        public var imageURL: URL?
        public var position: ChoicePosition
        public var targetSceneId: UUID?
        public var targetTime: TimeInterval?
        public var conditions: [Condition]
        public var consequences: [Consequence]
        public var analytics: ChoiceAnalytics

        public struct ChoicePosition: Codable {
            public var index: Int // 0-based position
            public var customPosition: Hotspot.SphericalPosition?
        }

        public struct Consequence: Codable {
            public var type: ConsequenceType
            public var variable: String?
            public var value: InteractiveStory.VariableValue?
            public var delay: TimeInterval

            public enum ConsequenceType: String, Codable {
                case setVariable, incrementVariable, unlockContent, sendEvent
            }
        }

        public struct ChoiceAnalytics: Codable {
            public var trackSelection: Bool
            public var trackHover: Bool
            public var eventName: String?
        }

        public init(label: String, targetSceneId: UUID) {
            self.id = UUID()
            self.label = label
            self.targetSceneId = targetSceneId
            self.position = ChoicePosition(index: 0)
            self.conditions = []
            self.consequences = []
            self.analytics = ChoiceAnalytics(trackSelection: true, trackHover: false)
        }
    }

    public enum TimeoutAction: Codable {
        case selectDefault
        case repeatPrompt
        case skipBranch
        case endStory
    }

    public struct BranchStyle: Codable {
        public var layout: Layout
        public var backgroundColor: String
        public var choiceStyle: ChoiceStyle
        public var showTimer: Bool
        public var timerStyle: TimerStyle

        public enum Layout: String, Codable {
            case horizontal, vertical, radial, grid, custom
        }

        public struct ChoiceStyle: Codable {
            public var width: Float
            public var height: Float
            public var backgroundColor: String
            public var selectedColor: String
            public var textColor: String
            public var fontSize: Float
            public var cornerRadius: Float
            public var spacing: Float
        }

        public struct TimerStyle: Codable {
            public var position: String
            public var style: String
            public var color: String
        }

        public static let `default` = BranchStyle(
            layout: .horizontal,
            backgroundColor: "#00000080",
            choiceStyle: ChoiceStyle(
                width: 200,
                height: 120,
                backgroundColor: "#333333",
                selectedColor: "#6366F1",
                textColor: "#FFFFFF",
                fontSize: 18,
                cornerRadius: 12,
                spacing: 20
            ),
            showTimer: true,
            timerStyle: TimerStyle(
                position: "top",
                style: "bar",
                color: "#6366F1"
            )
        )
    }

    public init(name: String, displayTime: TimeInterval, duration: TimeInterval = 10) {
        self.id = UUID()
        self.name = name
        self.type = .choice
        self.displayTime = displayTime
        self.duration = duration
        self.choices = []
        self.timeoutAction = .selectDefault
        self.style = .default
    }
}

// MARK: - Time Trigger

public struct TimeTrigger: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var time: TimeInterval
    public var repeatInterval: TimeInterval?
    public var actions: [TriggerAction]
    public var conditions: [Condition]

    public enum TriggerAction: Codable {
        case showHotspot(id: UUID)
        case hideHotspot(id: UUID)
        case showAnnotation(id: UUID)
        case hideAnnotation(id: UUID)
        case showOverlay(id: UUID)
        case hideOverlay(id: UUID)
        case playAudio(url: URL)
        case stopAudio
        case setVariable(name: String, value: InteractiveStory.VariableValue)
        case sendAnalytics(event: String)
        case triggerHaptic(pattern: Hotspot.HapticPattern)
        case adjustComfort(level: String)
        case custom(handler: String)
    }

    public init(name: String, time: TimeInterval) {
        self.id = UUID()
        self.name = name
        self.time = time
        self.actions = []
        self.conditions = []
    }
}

// MARK: - Transition

public struct Transition: Codable {
    public var type: TransitionType
    public var duration: TimeInterval
    public var easing: Easing
    public var direction: Direction?

    public enum TransitionType: String, Codable {
        case cut, fade, crossfade, wipe, zoom, spin, blur, custom
    }

    public enum Easing: String, Codable {
        case linear, easeIn, easeOut, easeInOut, spring
    }

    public enum Direction: String, Codable {
        case left, right, up, down
    }

    public static let `default` = Transition(
        type: .crossfade,
        duration: 0.5,
        easing: .easeInOut
    )
}

// MARK: - Condition

public struct Condition: Codable {
    public var type: ConditionType
    public var variable: String?
    public var comparison: Comparison?
    public var value: InteractiveStory.VariableValue?

    public enum ConditionType: String, Codable {
        case variableEquals
        case variableGreaterThan
        case variableLessThan
        case variableContains
        case sceneVisited
        case choiceMade
        case timeElapsed
        case platform
        case bioState
        case random
    }

    public enum Comparison: String, Codable {
        case equals, notEquals, greaterThan, lessThan, contains
    }
}

// MARK: - Interactive Video Engine

@MainActor
public final class InteractiveVideoEngine: ObservableObject {
    public static let shared = InteractiveVideoEngine()

    // MARK: Published State

    @Published public private(set) var currentStory: InteractiveStory?
    @Published public private(set) var currentScene: InteractiveStory.Scene?
    @Published public private(set) var currentTime: TimeInterval = 0
    @Published public private(set) var isPlaying = false
    @Published public private(set) var activeHotspots: [Hotspot] = []
    @Published public private(set) var activeAnnotations: [Annotation] = []
    @Published public private(set) var activeOverlays: [Overlay] = []
    @Published public private(set) var activeBranch: Branch?
    @Published public private(set) var hoveredHotspot: Hotspot?
    @Published public private(set) var selectedChoice: Branch.Choice?
    @Published public private(set) var storyProgress: Float = 0
    @Published public private(set) var visitedScenes: Set<UUID> = []
    @Published public private(set) var madeChoices: [UUID: UUID] = [:] // branchId: choiceId

    // MARK: Configuration

    public var gazeDwellTime: TimeInterval = 1.5
    public var enableHaptics = true
    public var enableAudioFeedback = true
    public var showHotspotHints = true
    public var autoAdvanceOnTimeout = true

    // MARK: Private

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private var gazeTimer: Timer?
    private var branchTimer: Timer?
    private var analyticsBuffer: [AnalyticsEvent] = []

    // MARK: Initialization

    private init() {
        setupUpdateLoop()
    }

    // MARK: - Story Management

    /// Load an interactive story
    public func loadStory(_ story: InteractiveStory) async throws {
        currentStory = story
        visitedScenes = []
        madeChoices = [:]
        storyProgress = 0

        // Preload global assets
        for asset in story.globalAssets where asset.preload {
            try await preloadAsset(asset)
        }

        // Navigate to start scene
        if let startScene = story.scenes.first(where: { $0.id == story.startSceneId }) {
            await navigateToScene(startScene)
        } else if let firstScene = story.scenes.first {
            await navigateToScene(firstScene)
        }

        logAnalytics(.storyLoaded(storyId: story.id, title: story.title))
    }

    /// Navigate to a specific scene
    public func navigateToScene(_ scene: InteractiveStory.Scene, transition: Transition = .default) async {
        // Apply transition
        await applyTransition(transition, from: currentScene, to: scene)

        currentScene = scene
        currentTime = 0
        visitedScenes.insert(scene.id)

        // Reset active elements
        updateActiveElements()

        // Start ambient audio if present
        if let ambientAudio = scene.ambientAudio {
            await playAmbientAudio(ambientAudio)
        }

        logAnalytics(.sceneEntered(sceneId: scene.id, name: scene.name))

        // Calculate progress
        if let story = currentStory {
            storyProgress = Float(visitedScenes.count) / Float(story.scenes.count)
        }
    }

    // MARK: - Playback Control

    public func play() {
        isPlaying = true
        startUpdateLoop()
        logAnalytics(.playbackStarted)
    }

    public func pause() {
        isPlaying = false
        stopUpdateLoop()
        logAnalytics(.playbackPaused(time: currentTime))
    }

    public func seek(to time: TimeInterval) {
        currentTime = time
        updateActiveElements()
        checkTimeTriggers()
        logAnalytics(.seeked(time: time))
    }

    // MARK: - Hotspot Interaction

    /// Handle gaze on hotspot
    public func gazeOnHotspot(_ hotspot: Hotspot) {
        guard hoveredHotspot?.id != hotspot.id else { return }

        hoveredHotspot = hotspot

        // Start dwell timer
        gazeTimer?.invalidate()
        gazeTimer = Timer.scheduledTimer(withTimeInterval: gazeDwellTime, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.activateHotspot(hotspot, trigger: .gazeDwell)
            }
        }

        // Audio feedback
        if enableAudioFeedback, let audioURL = hotspot.audioFeedback {
            playFeedbackAudio(audioURL)
        }

        logAnalytics(.hotspotHovered(hotspotId: hotspot.id, name: hotspot.name))
    }

    /// Handle gaze leaving hotspot
    public func gazeLeftHotspot() {
        hoveredHotspot = nil
        gazeTimer?.invalidate()
        gazeTimer = nil
    }

    /// Click/tap on hotspot
    public func clickHotspot(_ hotspot: Hotspot) {
        activateHotspot(hotspot, trigger: .click)
    }

    /// Activate hotspot with specific trigger
    public func activateHotspot(_ hotspot: Hotspot, trigger: Hotspot.HotspotAction.Trigger) {
        // Check conditions
        guard checkConditions(hotspot.conditions) else { return }

        // Find matching action
        guard let action = hotspot.actions.first(where: { $0.trigger == trigger }) else { return }

        // Check action conditions
        guard checkConditions(action.conditions) else { return }

        // Haptic feedback
        if enableHaptics, let pattern = hotspot.hapticPattern {
            triggerHaptic(pattern)
        }

        // Execute action after delay
        Task {
            if action.delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(action.delay * 1_000_000_000))
            }
            await executeAction(action.action)
        }

        logAnalytics(.hotspotActivated(
            hotspotId: hotspot.id,
            name: hotspot.name,
            trigger: trigger.rawValue
        ))
    }

    // MARK: - Branch/Choice Handling

    /// Show branching choices
    public func showBranch(_ branch: Branch) {
        activeBranch = branch

        // Start timeout timer
        branchTimer?.invalidate()
        branchTimer = Timer.scheduledTimer(withTimeInterval: branch.duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleBranchTimeout(branch)
            }
        }

        // Pause video during choice
        pause()

        logAnalytics(.branchShown(branchId: branch.id, name: branch.name, choiceCount: branch.choices.count))
    }

    /// Select a choice
    public func selectChoice(_ choice: Branch.Choice) async {
        guard let branch = activeBranch else { return }

        selectedChoice = choice
        madeChoices[branch.id] = choice.id

        // Cancel timeout
        branchTimer?.invalidate()

        // Apply consequences
        for consequence in choice.consequences {
            await applyConsequence(consequence)
        }

        // Navigate to target
        if let targetSceneId = choice.targetSceneId,
           let story = currentStory,
           let targetScene = story.scenes.first(where: { $0.id == targetSceneId }) {
            await navigateToScene(targetScene)
        } else if let targetTime = choice.targetTime {
            seek(to: targetTime)
        }

        // Clear branch
        activeBranch = nil
        selectedChoice = nil

        // Resume playback
        play()

        logAnalytics(.choiceSelected(
            branchId: branch.id,
            choiceId: choice.id,
            label: choice.label
        ))
    }

    private func handleBranchTimeout(_ branch: Branch) {
        guard activeBranch?.id == branch.id else { return }

        switch branch.timeoutAction {
        case .selectDefault:
            if let defaultId = branch.defaultChoiceId,
               let defaultChoice = branch.choices.first(where: { $0.id == defaultId }) {
                Task { await selectChoice(defaultChoice) }
            } else if let firstChoice = branch.choices.first {
                Task { await selectChoice(firstChoice) }
            }

        case .repeatPrompt:
            showBranch(branch) // Restart timer

        case .skipBranch:
            activeBranch = nil
            play()

        case .endStory:
            activeBranch = nil
            isPlaying = false
            logAnalytics(.storyEnded(reason: "timeout"))
        }

        logAnalytics(.branchTimeout(branchId: branch.id))
    }

    // MARK: - Action Execution

    private func executeAction(_ action: Hotspot.HotspotAction.Action) async {
        switch action {
        case .showContent:
            // Show expanded content panel
            break

        case .hideContent:
            // Hide content panel
            break

        case .playVideo(let url):
            await playEmbeddedVideo(url)

        case .playAudio(let url):
            await playEmbeddedAudio(url)

        case .navigateScene(let sceneId):
            if let story = currentStory,
               let scene = story.scenes.first(where: { $0.id == sceneId }) {
                await navigateToScene(scene)
            }

        case .jumpToTime(let time):
            seek(to: time)

        case .openURL(let url):
            openExternalURL(url)

        case .setVariable(let name, let value):
            setVariable(name, value: value)

        case .triggerAnimation(let name):
            triggerAnimation(name)

        case .sendAnalytics(let event, let data):
            logAnalytics(.customEvent(name: event, data: data))

        case .showQuiz(let quizId):
            await showQuiz(quizId)

        case .addToCart(let productId):
            await addToCart(productId)

        case .share(let platform):
            await shareContent(platform)

        case .teleport(let position):
            await teleportUser(to: position)

        case .custom(let handler):
            await executeCustomHandler(handler)
        }
    }

    // MARK: - Update Loop

    private func setupUpdateLoop() {
        // Frame update timer
    }

    private func startUpdateLoop() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
    }

    private func stopUpdateLoop() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func update() {
        guard isPlaying else { return }

        // Update time
        currentTime += 1.0/60.0

        // Update active elements
        updateActiveElements()

        // Check time triggers
        checkTimeTriggers()

        // Check for branches
        checkBranches()

        // Check scene end
        if let scene = currentScene, currentTime >= scene.duration {
            handleSceneEnd()
        }
    }

    private func updateActiveElements() {
        guard let scene = currentScene else { return }

        activeHotspots = scene.hotspots.filter { hotspot in
            hotspot.timeRange.contains(currentTime) && checkConditions(hotspot.conditions)
        }

        activeAnnotations = scene.annotations.filter { annotation in
            annotation.timeRange.contains(currentTime)
        }

        activeOverlays = scene.overlays.filter { overlay in
            overlay.timeRange.contains(currentTime)
        }
    }

    private func checkTimeTriggers() {
        guard let scene = currentScene else { return }

        for trigger in scene.triggers {
            let shouldTrigger: Bool
            if let repeatInterval = trigger.repeatInterval {
                let timeSinceFirst = currentTime - trigger.time
                shouldTrigger = timeSinceFirst >= 0 && timeSinceFirst.truncatingRemainder(dividingBy: repeatInterval) < 1.0/60.0
            } else {
                shouldTrigger = abs(currentTime - trigger.time) < 1.0/60.0
            }

            if shouldTrigger && checkConditions(trigger.conditions) {
                for action in trigger.actions {
                    executeTriggerAction(action)
                }
            }
        }
    }

    private func checkBranches() {
        guard let scene = currentScene, activeBranch == nil else { return }

        for branch in scene.branches {
            if abs(currentTime - branch.displayTime) < 1.0/60.0 {
                showBranch(branch)
                break
            }
        }
    }

    private func handleSceneEnd() {
        guard let scene = currentScene else { return }

        // Check for auto-navigation based on default transition
        // Or end story if no more scenes
        isPlaying = false
        logAnalytics(.sceneEnded(sceneId: scene.id))
    }

    // MARK: - Helpers

    private func checkConditions(_ conditions: [Condition]) -> Bool {
        for condition in conditions {
            if !evaluateCondition(condition) {
                return false
            }
        }
        return true
    }

    private func evaluateCondition(_ condition: Condition) -> Bool {
        guard let story = currentStory else { return true }

        switch condition.type {
        case .sceneVisited:
            if let variable = condition.variable, let sceneId = UUID(uuidString: variable) {
                return visitedScenes.contains(sceneId)
            }
        case .choiceMade:
            if let variable = condition.variable, let branchId = UUID(uuidString: variable) {
                return madeChoices[branchId] != nil
            }
        case .variableEquals:
            if let name = condition.variable, let value = condition.value {
                return story.variables[name] == value
            }
        default:
            break
        }

        return true
    }

    private func setVariable(_ name: String, value: InteractiveStory.VariableValue) {
        currentStory?.variables[name] = value
    }

    private func applyConsequence(_ consequence: Branch.Choice.Consequence) async {
        switch consequence.type {
        case .setVariable:
            if let name = consequence.variable, let value = consequence.value {
                setVariable(name, value: value)
            }
        case .incrementVariable:
            // Increment numeric variable
            break
        case .unlockContent:
            // Unlock content
            break
        case .sendEvent:
            if let name = consequence.variable {
                logAnalytics(.customEvent(name: name, data: [:]))
            }
        }
    }

    private func executeTriggerAction(_ action: TimeTrigger.TriggerAction) {
        // Execute time-based trigger actions
    }

    private func applyTransition(_ transition: Transition, from: InteractiveStory.Scene?, to: InteractiveStory.Scene) async {
        // Apply visual transition
    }

    private func preloadAsset(_ asset: InteractiveStory.Asset) async throws {
        // Preload asset
    }

    private func playAmbientAudio(_ url: URL) async {
        // Play ambient audio
    }

    private func playEmbeddedVideo(_ url: URL) async {
        // Play embedded video
    }

    private func playEmbeddedAudio(_ url: URL) async {
        // Play embedded audio
    }

    private func playFeedbackAudio(_ url: URL) {
        // Play feedback sound
    }

    private func triggerHaptic(_ pattern: Hotspot.HapticPattern) {
        // Trigger haptic feedback
    }

    private func openExternalURL(_ url: URL) {
        // Open URL
    }

    private func triggerAnimation(_ name: String) {
        // Trigger named animation
    }

    private func showQuiz(_ quizId: UUID) async {
        // Show quiz UI
    }

    private func addToCart(_ productId: String) async {
        // E-commerce integration
    }

    private func shareContent(_ platform: String) async {
        // Social sharing
    }

    private func teleportUser(to position: Hotspot.SphericalPosition) async {
        // VR teleportation
    }

    private func executeCustomHandler(_ handler: String) async {
        // Custom JavaScript/handler execution
    }

    // MARK: - Analytics

    private enum AnalyticsEvent {
        case storyLoaded(storyId: UUID, title: String)
        case sceneEntered(sceneId: UUID, name: String)
        case sceneEnded(sceneId: UUID)
        case playbackStarted
        case playbackPaused(time: TimeInterval)
        case seeked(time: TimeInterval)
        case hotspotHovered(hotspotId: UUID, name: String)
        case hotspotActivated(hotspotId: UUID, name: String, trigger: String)
        case branchShown(branchId: UUID, name: String, choiceCount: Int)
        case branchTimeout(branchId: UUID)
        case choiceSelected(branchId: UUID, choiceId: UUID, label: String)
        case storyEnded(reason: String)
        case customEvent(name: String, data: [String: String])
    }

    private func logAnalytics(_ event: AnalyticsEvent) {
        analyticsBuffer.append(event)

        // Flush buffer periodically
        if analyticsBuffer.count >= 50 {
            flushAnalytics()
        }
    }

    private func flushAnalytics() {
        // Send to analytics service
        analyticsBuffer.removeAll()
    }
}

// MARK: - Extension for Codable VariableValue Equatable

extension InteractiveStory.VariableValue: Equatable {
    public static func == (lhs: InteractiveStory.VariableValue, rhs: InteractiveStory.VariableValue) -> Bool {
        switch (lhs, rhs) {
        case (.string(let l), .string(let r)): return l == r
        case (.int(let l), .int(let r)): return l == r
        case (.float(let l), .float(let r)): return l == r
        case (.bool(let l), .bool(let r)): return l == r
        case (.array(let l), .array(let r)): return l == r
        default: return false
        }
    }
}

#if DEBUG
extension InteractiveVideoEngine {
    public static func createSampleStory() -> InteractiveStory {
        var story = InteractiveStory(title: "Sample Interactive Experience")

        let scene1 = InteractiveStory.Scene(
            id: UUID(),
            name: "Opening",
            duration: 60,
            hotspots: [
                Hotspot(
                    name: "Info Point",
                    type: .info,
                    position: Hotspot.SphericalPosition(longitude: 45, latitude: 0)
                )
            ],
            annotations: [
                Annotation(
                    type: .title,
                    text: "Welcome to the Experience",
                    position: Hotspot.SphericalPosition(longitude: 0, latitude: 10),
                    timeRange: 0...5
                )
            ],
            overlays: [],
            branches: [],
            triggers: [],
            defaultTransition: .default
        )

        story.scenes = [scene1]
        story.startSceneId = scene1.id

        return story
    }
}
#endif

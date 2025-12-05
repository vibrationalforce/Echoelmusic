// CrossPlatformImmersiveEngine.swift
// Echoelmusic
//
// Universal Cross-Platform Immersive Video Engine
// Supports: visionOS, WebXR, Meta Quest (OpenXR), Android XR, Windows MR, SteamVR
//
// Created by Echoelmusic on 2025-12-05.

import Foundation
import Combine
import simd

// MARK: - XR Platform Definitions

/// All supported XR platforms
public enum XRPlatform: String, CaseIterable, Codable {
    // Apple Ecosystem
    case visionOS = "visionOS"
    case iOS_AR = "iOS AR"

    // Meta
    case metaQuest3 = "Meta Quest 3"
    case metaQuestPro = "Meta Quest Pro"
    case metaQuest2 = "Meta Quest 2"

    // Web
    case webXR = "WebXR"
    case webVR = "WebVR (Legacy)"

    // Android
    case androidXR = "Android XR"
    case googleCardboard = "Google Cardboard"

    // Windows/PC
    case windowsMR = "Windows Mixed Reality"
    case steamVR = "SteamVR"
    case varjoXR = "Varjo XR"
    case pico4 = "Pico 4"

    // Console
    case playstationVR2 = "PlayStation VR2"

    // Standalone
    case htcViveFocus = "HTC Vive Focus"
    case lynx = "Lynx R-1"

    public var category: PlatformCategory {
        switch self {
        case .visionOS, .iOS_AR:
            return .apple
        case .metaQuest3, .metaQuestPro, .metaQuest2:
            return .meta
        case .webXR, .webVR:
            return .web
        case .androidXR, .googleCardboard:
            return .android
        case .windowsMR, .steamVR, .varjoXR:
            return .pcvr
        case .pico4, .htcViveFocus, .lynx:
            return .standalone
        case .playstationVR2:
            return .console
        }
    }

    public var supportsHandTracking: Bool {
        switch self {
        case .visionOS, .metaQuest3, .metaQuestPro, .varjoXR, .pico4:
            return true
        default:
            return false
        }
    }

    public var supportsEyeTracking: Bool {
        switch self {
        case .visionOS, .metaQuestPro, .varjoXR, .playstationVR2, .pico4:
            return true
        default:
            return false
        }
    }

    public var maxRefreshRate: Int {
        switch self {
        case .visionOS: return 100
        case .metaQuest3, .metaQuestPro: return 120
        case .metaQuest2: return 120
        case .playstationVR2: return 120
        case .varjoXR: return 200
        case .pico4: return 90
        default: return 90
        }
    }

    public var nativeResolutionPerEye: (width: Int, height: Int) {
        switch self {
        case .visionOS: return (3660, 3200)
        case .metaQuest3: return (2064, 2208)
        case .metaQuestPro: return (1800, 1920)
        case .metaQuest2: return (1832, 1920)
        case .playstationVR2: return (2000, 2040)
        case .varjoXR: return (2880, 2720)
        case .pico4: return (2160, 2160)
        default: return (1920, 1080)
        }
    }

    public enum PlatformCategory: String {
        case apple, meta, web, android, pcvr, standalone, console
    }
}

// MARK: - Immersive Video Format

public enum ImmersiveVideoFormat: String, CaseIterable, Codable {
    // Spherical
    case equirectangular360 = "360° Equirectangular"
    case equirectangular180 = "180° Equirectangular"
    case cubemap = "Cubemap"
    case equiangularCubemap = "Equi-Angular Cubemap (EAC)"

    // Stereoscopic
    case stereoSideBySide = "Side-by-Side 3D"
    case stereoTopBottom = "Top-Bottom 3D"
    case stereoMVHEVC = "MV-HEVC (Apple)"

    // Volumetric
    case pointCloud = "Point Cloud"
    case meshSequence = "Mesh Sequence"
    case gaussianSplat = "Gaussian Splatting"
    case nerf = "NeRF"

    // Light Field
    case lightField = "Light Field"
    case holoVideo = "Holographic Video"

    // Standard
    case flat2D = "Flat 2D"

    public var requiresSpecialPlayer: Bool {
        switch self {
        case .pointCloud, .meshSequence, .gaussianSplat, .nerf, .lightField, .holoVideo:
            return true
        default:
            return false
        }
    }

    public var supportedPlatforms: [XRPlatform] {
        switch self {
        case .stereoMVHEVC:
            return [.visionOS, .iOS_AR]
        case .gaussianSplat, .nerf:
            return [.visionOS, .metaQuest3, .metaQuestPro, .steamVR, .varjoXR]
        default:
            return XRPlatform.allCases
        }
    }
}

// MARK: - Spatial Audio Format

public enum SpatialAudioFormat: String, CaseIterable, Codable {
    case stereo = "Stereo"
    case surroundSound51 = "5.1 Surround"
    case surroundSound71 = "7.1 Surround"
    case dolbyAtmos = "Dolby Atmos"
    case ambisonicsFirstOrder = "Ambisonics 1st Order"
    case ambisonicsSecondOrder = "Ambisonics 2nd Order"
    case ambisonicsThirdOrder = "Ambisonics 3rd Order"
    case objectBased = "Object-Based Audio"
    case apac = "APAC (Apple)"
    case resonanceAudio = "Resonance Audio (Google)"
    case metaSpatialAudio = "Meta Spatial Audio"

    public var channelCount: Int {
        switch self {
        case .stereo: return 2
        case .surroundSound51: return 6
        case .surroundSound71: return 8
        case .dolbyAtmos: return 16 // Object tracks
        case .ambisonicsFirstOrder: return 4
        case .ambisonicsSecondOrder: return 9
        case .ambisonicsThirdOrder: return 16
        case .objectBased: return 128 // Max objects
        case .apac, .resonanceAudio, .metaSpatialAudio: return 128
        }
    }
}

// MARK: - Platform Capability

public struct PlatformCapability: Codable {
    public let platform: XRPlatform
    public let supportsVideo360: Bool
    public let supportsVideo180: Bool
    public let supportsStereo3D: Bool
    public let supportsVolumetric: Bool
    public let supportsHandTracking: Bool
    public let supportsEyeTracking: Bool
    public let supportsPassthrough: Bool
    public let supportsRoomScale: Bool
    public let maxVideoResolution: (width: Int, height: Int)
    public let supportedAudioFormats: [SpatialAudioFormat]
    public let supportedCodecs: [String]
    public let hasNativeSDK: Bool
    public let requiresAdapter: Bool

    public init(platform: XRPlatform) {
        self.platform = platform

        switch platform {
        case .visionOS:
            supportsVideo360 = true
            supportsVideo180 = true
            supportsStereo3D = true
            supportsVolumetric = true
            supportsHandTracking = true
            supportsEyeTracking = true
            supportsPassthrough = true
            supportsRoomScale = true
            maxVideoResolution = (8192, 8192)
            supportedAudioFormats = [.stereo, .surroundSound51, .surroundSound71, .dolbyAtmos, .ambisonicsThirdOrder, .apac]
            supportedCodecs = ["HEVC", "H.264", "ProRes", "MV-HEVC"]
            hasNativeSDK = true
            requiresAdapter = false

        case .metaQuest3, .metaQuestPro:
            supportsVideo360 = true
            supportsVideo180 = true
            supportsStereo3D = true
            supportsVolumetric = true
            supportsHandTracking = true
            supportsEyeTracking = platform == .metaQuestPro
            supportsPassthrough = true
            supportsRoomScale = true
            maxVideoResolution = (8192, 8192)
            supportedAudioFormats = [.stereo, .surroundSound51, .ambisonicsSecondOrder, .metaSpatialAudio]
            supportedCodecs = ["HEVC", "H.264", "AV1"]
            hasNativeSDK = false
            requiresAdapter = true

        case .webXR:
            supportsVideo360 = true
            supportsVideo180 = true
            supportsStereo3D = true
            supportsVolumetric = false
            supportsHandTracking = true
            supportsEyeTracking = false
            supportsPassthrough = true
            supportsRoomScale = true
            maxVideoResolution = (4096, 4096)
            supportedAudioFormats = [.stereo, .ambisonicsFirstOrder, .resonanceAudio]
            supportedCodecs = ["VP9", "H.264", "AV1"]
            hasNativeSDK = false
            requiresAdapter = true

        case .steamVR:
            supportsVideo360 = true
            supportsVideo180 = true
            supportsStereo3D = true
            supportsVolumetric = true
            supportsHandTracking = true
            supportsEyeTracking = true
            supportsPassthrough = true
            supportsRoomScale = true
            maxVideoResolution = (16384, 16384)
            supportedAudioFormats = SpatialAudioFormat.allCases
            supportedCodecs = ["HEVC", "H.264", "AV1", "VP9", "ProRes"]
            hasNativeSDK = false
            requiresAdapter = true

        default:
            supportsVideo360 = true
            supportsVideo180 = true
            supportsStereo3D = true
            supportsVolumetric = false
            supportsHandTracking = platform.supportsHandTracking
            supportsEyeTracking = platform.supportsEyeTracking
            supportsPassthrough = true
            supportsRoomScale = true
            maxVideoResolution = (4096, 4096)
            supportedAudioFormats = [.stereo, .surroundSound51, .ambisonicsFirstOrder]
            supportedCodecs = ["HEVC", "H.264"]
            hasNativeSDK = false
            requiresAdapter = true
        }
    }
}

// MARK: - Immersive Content

public struct ImmersiveContent: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var description: String
    public var videoFormat: ImmersiveVideoFormat
    public var audioFormat: SpatialAudioFormat
    public var videoURL: URL?
    public var audioURL: URL?
    public var thumbnailURL: URL?
    public var duration: TimeInterval
    public var resolution: (width: Int, height: Int)
    public var frameRate: Float
    public var bitrate: Int
    public var metadata: ContentMetadata
    public var interactiveElements: [InteractiveElement]
    public var chapters: [Chapter]
    public var supportedPlatforms: [XRPlatform]
    public var createdAt: Date
    public var updatedAt: Date

    public struct ContentMetadata: Codable {
        public var creator: String?
        public var copyright: String?
        public var tags: [String]
        public var genre: String?
        public var language: String?
        public var ageRating: String?
        public var motionIntensity: MotionIntensity
        public var comfortLevel: ComfortLevel
        public var bioReactiveEnabled: Bool
    }

    public struct Chapter: Identifiable, Codable {
        public let id: UUID
        public var title: String
        public var startTime: TimeInterval
        public var endTime: TimeInterval
        public var thumbnailURL: URL?
    }

    public enum MotionIntensity: String, Codable {
        case none, low, moderate, high, extreme
    }

    public enum ComfortLevel: String, Codable {
        case comfortable, moderate, intense, accessibility
    }

    public init(
        title: String,
        videoFormat: ImmersiveVideoFormat,
        audioFormat: SpatialAudioFormat = .stereo,
        duration: TimeInterval = 0
    ) {
        self.id = UUID()
        self.title = title
        self.description = ""
        self.videoFormat = videoFormat
        self.audioFormat = audioFormat
        self.duration = duration
        self.resolution = (3840, 2160)
        self.frameRate = 60
        self.bitrate = 50_000_000
        self.metadata = ContentMetadata(
            motionIntensity: .low,
            comfortLevel: .comfortable,
            bioReactiveEnabled: true
        )
        self.interactiveElements = []
        self.chapters = []
        self.supportedPlatforms = videoFormat.supportedPlatforms
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Interactive Element

public struct InteractiveElement: Identifiable, Codable {
    public let id: UUID
    public var type: ElementType
    public var position: SIMD3<Float> // Spherical coordinates (longitude, latitude, depth)
    public var size: SIMD2<Float>
    public var startTime: TimeInterval
    public var endTime: TimeInterval
    public var content: ElementContent
    public var style: ElementStyle
    public var actions: [ElementAction]
    public var conditions: [ElementCondition]
    public var isVisible: Bool
    public var gazeDwellTime: TimeInterval // Time to activate with gaze

    public enum ElementType: String, Codable {
        case hotspot = "Hotspot"
        case annotation = "Annotation"
        case button = "Button"
        case infoCard = "Info Card"
        case videoOverlay = "Video Overlay"
        case imageOverlay = "Image Overlay"
        case audioZone = "Audio Zone"
        case teleport = "Teleport Point"
        case branchingChoice = "Branching Choice"
        case quiz = "Quiz"
        case productTag = "Product Tag"
        case socialLink = "Social Link"
        case spatialAnchor = "Spatial Anchor"
    }

    public struct ElementContent: Codable {
        public var title: String?
        public var text: String?
        public var imageURL: URL?
        public var videoURL: URL?
        public var audioURL: URL?
        public var modelURL: URL? // 3D model
        public var linkURL: URL?
        public var customData: [String: String]
    }

    public struct ElementStyle: Codable {
        public var backgroundColor: String // Hex color
        public var textColor: String
        public var borderColor: String
        public var borderWidth: Float
        public var cornerRadius: Float
        public var opacity: Float
        public var glowEffect: Bool
        public var pulseAnimation: Bool
        public var facesCamera: Bool // Billboard effect
    }

    public struct ElementAction: Codable {
        public var trigger: Trigger
        public var actionType: ActionType
        public var parameters: [String: String]

        public enum Trigger: String, Codable {
            case gaze, click, hover, proximity, voice, gesture, time
        }

        public enum ActionType: String, Codable {
            case navigate, playMedia, showInfo, hideElement, triggerAnimation
            case jumpToTime, openURL, sendAnalytics, branchStory, playAudio
            case showModel, teleport, changeSkybox, adjustComfort
        }
    }

    public struct ElementCondition: Codable {
        public var type: ConditionType
        public var value: String

        public enum ConditionType: String, Codable {
            case timeRange, viewCount, previousChoice, platform, bioState
        }
    }

    public init(type: ElementType, position: SIMD3<Float>) {
        self.id = UUID()
        self.type = type
        self.position = position
        self.size = SIMD2<Float>(0.2, 0.2)
        self.startTime = 0
        self.endTime = .infinity
        self.content = ElementContent()
        self.style = ElementStyle(
            backgroundColor: "#000000AA",
            textColor: "#FFFFFF",
            borderColor: "#FFFFFF",
            borderWidth: 2,
            cornerRadius: 8,
            opacity: 1.0,
            glowEffect: true,
            pulseAnimation: true,
            facesCamera: true
        )
        self.actions = []
        self.conditions = []
        self.isVisible = true
        self.gazeDwellTime = 1.0
    }
}

// MARK: - Cross-Platform Immersive Engine

@MainActor
public final class CrossPlatformImmersiveEngine: ObservableObject {
    public static let shared = CrossPlatformImmersiveEngine()

    // MARK: Published State

    @Published public private(set) var currentPlatform: XRPlatform = .visionOS
    @Published public private(set) var detectedPlatforms: [XRPlatform] = []
    @Published public private(set) var platformCapabilities: [XRPlatform: PlatformCapability] = [:]
    @Published public private(set) var isPlaying = false
    @Published public private(set) var currentTime: TimeInterval = 0
    @Published public private(set) var currentContent: ImmersiveContent?
    @Published public private(set) var activeInteractiveElements: [InteractiveElement] = []
    @Published public private(set) var headPose: HeadPose = .identity
    @Published public private(set) var handTrackingData: HandTrackingData?
    @Published public private(set) var eyeTrackingData: EyeTrackingData?
    @Published public private(set) var comfortMetrics: ComfortMetrics = .default

    // MARK: Configuration

    public var preferredQuality: QualityPreset = .auto
    public var enableBioReactivity = true
    public var enableAnalytics = true
    public var hapticFeedbackEnabled = true

    // MARK: Platform Adapters

    private var webXRAdapter: WebXRAdapter?
    private var openXRAdapter: OpenXRAdapter?
    private var androidXRAdapter: AndroidXRAdapter?

    // MARK: Private

    private var cancellables = Set<AnyCancellable>()
    private var displayLink: CADisplayLink?
    private var interactiveElementTimer: Timer?
    private var analyticsEvents: [AnalyticsEvent] = []

    // MARK: Initialization

    private init() {
        detectPlatforms()
        initializePlatformCapabilities()
        setupTrackingUpdates()
    }

    // MARK: - Platform Detection

    private func detectPlatforms() {
        var detected: [XRPlatform] = []

        #if os(visionOS)
        detected.append(.visionOS)
        currentPlatform = .visionOS
        #elseif os(iOS)
        detected.append(.iOS_AR)
        currentPlatform = .iOS_AR
        #elseif os(macOS)
        // Check for connected HMDs
        detected.append(.steamVR)
        detected.append(.webXR)
        currentPlatform = .steamVR
        #endif

        // Always support WebXR as fallback
        if !detected.contains(.webXR) {
            detected.append(.webXR)
        }

        detectedPlatforms = detected
    }

    private func initializePlatformCapabilities() {
        for platform in XRPlatform.allCases {
            platformCapabilities[platform] = PlatformCapability(platform: platform)
        }
    }

    // MARK: - Content Playback

    /// Load immersive content
    public func loadContent(_ content: ImmersiveContent) async throws {
        guard content.supportedPlatforms.contains(currentPlatform) else {
            throw ImmersiveError.platformNotSupported(
                content: content.title,
                platform: currentPlatform
            )
        }

        currentContent = content
        activeInteractiveElements = content.interactiveElements.filter { $0.startTime == 0 }

        // Initialize platform-specific player
        try await initializePlayer(for: content)

        // Log analytics
        logEvent(.contentLoaded(contentId: content.id))
    }

    /// Start playback
    public func play() async {
        guard currentContent != nil else { return }

        isPlaying = true
        startInteractiveElementTracking()
        startComfortMonitoring()

        logEvent(.playbackStarted)
    }

    /// Pause playback
    public func pause() {
        isPlaying = false
        stopInteractiveElementTracking()

        logEvent(.playbackPaused(time: currentTime))
    }

    /// Seek to time
    public func seek(to time: TimeInterval) async {
        currentTime = time
        updateActiveInteractiveElements()

        logEvent(.seeked(time: time))
    }

    /// Stop playback
    public func stop() {
        isPlaying = false
        currentTime = 0
        activeInteractiveElements = []
        stopInteractiveElementTracking()

        logEvent(.playbackStopped)
    }

    // MARK: - Interactive Elements

    /// Handle interaction with element
    public func interact(with element: InteractiveElement, trigger: InteractiveElement.ElementAction.Trigger) async {
        guard let action = element.actions.first(where: { $0.trigger == trigger }) else { return }

        // Haptic feedback
        if hapticFeedbackEnabled {
            triggerHapticFeedback(for: action.actionType)
        }

        // Execute action
        switch action.actionType {
        case .navigate:
            if let urlString = action.parameters["url"], let url = URL(string: urlString) {
                await handleNavigation(to: url)
            }

        case .playMedia:
            if let mediaId = action.parameters["mediaId"] {
                await playEmbeddedMedia(mediaId)
            }

        case .showInfo:
            showInfoCard(for: element)

        case .jumpToTime:
            if let timeString = action.parameters["time"], let time = TimeInterval(timeString) {
                await seek(to: time)
            }

        case .branchStory:
            if let branchId = action.parameters["branchId"] {
                await handleBranching(branchId: branchId)
            }

        case .teleport:
            if let positionString = action.parameters["position"] {
                await teleportUser(to: parsePosition(positionString))
            }

        case .openURL:
            if let urlString = action.parameters["url"], let url = URL(string: urlString) {
                openExternalURL(url)
            }

        case .adjustComfort:
            if let levelString = action.parameters["level"],
               let level = ImmersiveContent.ComfortLevel(rawValue: levelString) {
                setComfortLevel(level)
            }

        default:
            break
        }

        logEvent(.interactionTriggered(
            elementId: element.id,
            trigger: trigger.rawValue,
            action: action.actionType.rawValue
        ))
    }

    /// Check gaze intersection
    public func checkGazeIntersection() -> InteractiveElement? {
        guard let eyeData = eyeTrackingData else { return nil }

        for element in activeInteractiveElements {
            if isGazeOnElement(element, gazeDirection: eyeData.gazeDirection) {
                return element
            }
        }

        return nil
    }

    // MARK: - Platform Adaptation

    /// Export content for specific platform
    public func exportContent(_ content: ImmersiveContent, for platform: XRPlatform) async throws -> ExportResult {
        guard let capability = platformCapabilities[platform] else {
            throw ImmersiveError.unknownPlatform
        }

        var exportedContent = content

        // Adapt video format
        if !content.videoFormat.supportedPlatforms.contains(platform) {
            exportedContent.videoFormat = recommendVideoFormat(for: platform)
        }

        // Adapt audio format
        if !capability.supportedAudioFormats.contains(content.audioFormat) {
            exportedContent.audioFormat = capability.supportedAudioFormats.first ?? .stereo
        }

        // Adapt resolution
        let maxRes = capability.maxVideoResolution
        if content.resolution.width > maxRes.width || content.resolution.height > maxRes.height {
            exportedContent.resolution = maxRes
        }

        // Generate platform-specific manifest
        let manifest = generateManifest(for: exportedContent, platform: platform)

        return ExportResult(
            content: exportedContent,
            platform: platform,
            manifest: manifest,
            warnings: collectWarnings(original: content, exported: exportedContent)
        )
    }

    /// Get recommended video format for platform
    public func recommendVideoFormat(for platform: XRPlatform) -> ImmersiveVideoFormat {
        switch platform {
        case .visionOS:
            return .stereoMVHEVC
        case .metaQuest3, .metaQuestPro, .metaQuest2:
            return .equirectangular180
        case .webXR:
            return .equirectangular360
        case .steamVR, .windowsMR:
            return .cubemap
        default:
            return .equirectangular360
        }
    }

    // MARK: - Multi-Platform Streaming

    /// Start multi-platform stream
    public func startMultiPlatformStream(_ content: ImmersiveContent, to platforms: [XRPlatform]) async throws -> StreamSession {
        var streamEndpoints: [StreamEndpoint] = []

        for platform in platforms {
            let endpoint = try await createStreamEndpoint(for: platform, content: content)
            streamEndpoints.append(endpoint)
        }

        let session = StreamSession(
            id: UUID(),
            content: content,
            endpoints: streamEndpoints,
            startTime: Date()
        )

        logEvent(.streamStarted(platforms: platforms.map { $0.rawValue }))

        return session
    }

    // MARK: - Bio-Reactive Integration

    /// Update bio state for reactive content
    public func updateBioState(_ bioData: BioReactiveState) {
        guard enableBioReactivity else { return }

        // Adjust comfort based on stress levels
        if bioData.stressLevel > 0.7 {
            setComfortLevel(.comfortable)
        }

        // Modulate visuals based on coherence
        adjustVisualsForCoherence(bioData.coherence)

        // Update spatial audio based on HRV
        adjustSpatialAudioForHRV(bioData.hrv)
    }

    // MARK: - Comfort Management

    /// Set comfort level
    public func setComfortLevel(_ level: ImmersiveContent.ComfortLevel) {
        var metrics = comfortMetrics

        switch level {
        case .comfortable:
            metrics.vignetteIntensity = 0.3
            metrics.motionSmoothing = 0.8
            metrics.maxRotationSpeed = 45 // degrees per second
            metrics.tunnelVision = true

        case .moderate:
            metrics.vignetteIntensity = 0.15
            metrics.motionSmoothing = 0.5
            metrics.maxRotationSpeed = 90
            metrics.tunnelVision = false

        case .intense:
            metrics.vignetteIntensity = 0
            metrics.motionSmoothing = 0.2
            metrics.maxRotationSpeed = 180
            metrics.tunnelVision = false

        case .accessibility:
            metrics.vignetteIntensity = 0.5
            metrics.motionSmoothing = 1.0
            metrics.maxRotationSpeed = 30
            metrics.tunnelVision = true
            metrics.reducedMotion = true
        }

        comfortMetrics = metrics
    }

    // MARK: - Tracking Updates

    private func setupTrackingUpdates() {
        // Head pose updates would come from platform-specific APIs
        Timer.publish(every: 1.0/90.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTracking()
            }
            .store(in: &cancellables)
    }

    private func updateTracking() {
        // Platform-specific tracking updates
        #if os(visionOS)
        // Use ARKit for tracking
        #elseif os(iOS)
        // Use ARKit for tracking
        #else
        // Use OpenXR or WebXR adapter
        #endif
    }

    // MARK: - Private Helpers

    private func initializePlayer(for content: ImmersiveContent) async throws {
        // Platform-specific player initialization
    }

    private func startInteractiveElementTracking() {
        interactiveElementTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateActiveInteractiveElements()
            }
        }
    }

    private func stopInteractiveElementTracking() {
        interactiveElementTimer?.invalidate()
        interactiveElementTimer = nil
    }

    private func updateActiveInteractiveElements() {
        guard let content = currentContent else { return }

        activeInteractiveElements = content.interactiveElements.filter { element in
            element.startTime <= currentTime && element.endTime >= currentTime && element.isVisible
        }
    }

    private func isGazeOnElement(_ element: InteractiveElement, gazeDirection: SIMD3<Float>) -> Bool {
        // Simplified intersection test
        let elementDirection = normalize(element.position)
        let dotProduct = dot(gazeDirection, elementDirection)
        return dotProduct > 0.98 // ~10 degree cone
    }

    private func handleNavigation(to url: URL) async {
        // Handle navigation
    }

    private func playEmbeddedMedia(_ mediaId: String) async {
        // Play embedded media
    }

    private func showInfoCard(for element: InteractiveElement) {
        // Show info card UI
    }

    private func handleBranching(branchId: String) async {
        // Handle story branching
    }

    private func teleportUser(to position: SIMD3<Float>) async {
        // Teleport user in VR
    }

    private func openExternalURL(_ url: URL) {
        // Open URL
    }

    private func parsePosition(_ string: String) -> SIMD3<Float> {
        // Parse position string
        return SIMD3<Float>(0, 0, 0)
    }

    private func triggerHapticFeedback(for action: InteractiveElement.ElementAction.ActionType) {
        // Platform-specific haptics
    }

    private func startComfortMonitoring() {
        // Monitor user comfort
    }

    private func adjustVisualsForCoherence(_ coherence: Float) {
        // Adjust visual parameters
    }

    private func adjustSpatialAudioForHRV(_ hrv: Float) {
        // Adjust spatial audio
    }

    private func createStreamEndpoint(for platform: XRPlatform, content: ImmersiveContent) async throws -> StreamEndpoint {
        return StreamEndpoint(
            platform: platform,
            url: URL(string: "rtmp://stream.example.com/\(platform.rawValue)")!,
            resolution: platformCapabilities[platform]?.maxVideoResolution ?? (1920, 1080),
            bitrate: 8_000_000
        )
    }

    private func generateManifest(for content: ImmersiveContent, platform: XRPlatform) -> String {
        // Generate platform-specific manifest (HLS, DASH, etc.)
        return """
        {
          "platform": "\(platform.rawValue)",
          "content": "\(content.title)",
          "format": "\(content.videoFormat.rawValue)",
          "audio": "\(content.audioFormat.rawValue)"
        }
        """
    }

    private func collectWarnings(original: ImmersiveContent, exported: ImmersiveContent) -> [String] {
        var warnings: [String] = []

        if original.videoFormat != exported.videoFormat {
            warnings.append("Video format converted from \(original.videoFormat.rawValue) to \(exported.videoFormat.rawValue)")
        }

        if original.audioFormat != exported.audioFormat {
            warnings.append("Audio format converted from \(original.audioFormat.rawValue) to \(exported.audioFormat.rawValue)")
        }

        if original.resolution != exported.resolution {
            warnings.append("Resolution reduced from \(original.resolution.width)x\(original.resolution.height) to \(exported.resolution.width)x\(exported.resolution.height)")
        }

        return warnings
    }

    private func logEvent(_ event: AnalyticsEvent) {
        guard enableAnalytics else { return }
        analyticsEvents.append(event)
    }
}

// MARK: - Supporting Types

public struct HeadPose {
    public var position: SIMD3<Float>
    public var rotation: simd_quatf
    public var velocity: SIMD3<Float>
    public var angularVelocity: SIMD3<Float>

    public static let identity = HeadPose(
        position: SIMD3<Float>(0, 1.6, 0),
        rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
        velocity: SIMD3<Float>(0, 0, 0),
        angularVelocity: SIMD3<Float>(0, 0, 0)
    )
}

public struct HandTrackingData {
    public var leftHand: HandData?
    public var rightHand: HandData?

    public struct HandData {
        public var joints: [SIMD3<Float>]
        public var gesture: HandGesture
        public var confidence: Float

        public enum HandGesture: String {
            case none, pinch, grab, point, thumbsUp, peace, openPalm
        }
    }
}

public struct EyeTrackingData {
    public var gazeDirection: SIMD3<Float>
    public var gazePoint: SIMD3<Float>
    public var leftPupilDilation: Float
    public var rightPupilDilation: Float
    public var blinkDetected: Bool
}

public struct ComfortMetrics {
    public var vignetteIntensity: Float
    public var motionSmoothing: Float
    public var maxRotationSpeed: Float
    public var tunnelVision: Bool
    public var reducedMotion: Bool

    public static let `default` = ComfortMetrics(
        vignetteIntensity: 0.15,
        motionSmoothing: 0.5,
        maxRotationSpeed: 90,
        tunnelVision: false,
        reducedMotion: false
    )
}

public struct BioReactiveState {
    public var hrv: Float
    public var heartRate: Float
    public var coherence: Float
    public var stressLevel: Float
    public var relaxationLevel: Float
}

public enum QualityPreset: String, CaseIterable {
    case auto, low, medium, high, ultra
}

public struct ExportResult {
    public let content: ImmersiveContent
    public let platform: XRPlatform
    public let manifest: String
    public let warnings: [String]
}

public struct StreamSession: Identifiable {
    public let id: UUID
    public let content: ImmersiveContent
    public let endpoints: [StreamEndpoint]
    public let startTime: Date
}

public struct StreamEndpoint {
    public let platform: XRPlatform
    public let url: URL
    public let resolution: (width: Int, height: Int)
    public let bitrate: Int
}

public enum AnalyticsEvent {
    case contentLoaded(contentId: UUID)
    case playbackStarted
    case playbackPaused(time: TimeInterval)
    case playbackStopped
    case seeked(time: TimeInterval)
    case interactionTriggered(elementId: UUID, trigger: String, action: String)
    case streamStarted(platforms: [String])
}

public enum ImmersiveError: Error {
    case platformNotSupported(content: String, platform: XRPlatform)
    case unknownPlatform
    case contentNotLoaded
    case streamingFailed(reason: String)
}

// MARK: - Platform Adapters (Stubs)

public class WebXRAdapter {
    // WebXR JavaScript bridge
}

public class OpenXRAdapter {
    // OpenXR C/C++ bridge for Quest, WMR, SteamVR
}

public class AndroidXRAdapter {
    // Android XR bridge
}

#if canImport(QuartzCore)
import QuartzCore
#endif

#if DEBUG
extension CrossPlatformImmersiveEngine {
    public static func createTestContent() -> ImmersiveContent {
        var content = ImmersiveContent(
            title: "Test 360 Video",
            videoFormat: .equirectangular360,
            audioFormat: .ambisonicsFirstOrder,
            duration: 300
        )

        content.interactiveElements = [
            InteractiveElement(type: .hotspot, position: SIMD3<Float>(0, 0, -5)),
            InteractiveElement(type: .infoCard, position: SIMD3<Float>(2, 1, -3)),
        ]

        return content
    }
}
#endif

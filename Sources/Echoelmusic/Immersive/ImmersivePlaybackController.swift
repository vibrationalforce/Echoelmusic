import Foundation
import AVFoundation
import Combine
import simd

#if os(visionOS)
import RealityKit
import Spatial
#endif

/// Immersive Playback Controller
/// Orchestrates AIV + APAC for synchronized immersive audio-visual playback
/// with comfort-aware adjustments and bio-reactive modulation
@MainActor
@Observable
class ImmersivePlaybackController {

    // MARK: - Published State

    /// Playback state
    var playbackState: PlaybackState = .stopped

    /// Current playback position
    var currentTime: TimeInterval = 0

    /// Total duration
    var duration: TimeInterval = 0

    /// Playback rate (0.5 - 2.0)
    var playbackRate: Float = 1.0

    /// Current comfort score
    var comfortScore: Float = 1.0

    /// Active comfort adjustments
    var activeAdjustments: ComfortAdjustments = ComfortAdjustments()

    /// Is bio-reactive mode enabled
    var bioReactiveEnabled: Bool = true

    /// Current experience quality
    var experienceQuality: ExperienceQuality = .high

    // MARK: - Playback State

    enum PlaybackState: String {
        case stopped
        case loading
        case playing
        case paused
        case buffering
        case error
    }

    enum ExperienceQuality: String {
        case low        // 30fps, reduced effects
        case medium     // 60fps, standard effects
        case high       // 90fps, full effects
        case ultra      // 120fps, maximum quality
    }

    // MARK: - Comfort Adjustments

    struct ComfortAdjustments {
        var vignetteRadius: Float = 1.0
        var vignetteIntensity: Float = 0.0
        var fovReduction: Float = 0.0
        var motionBlur: Float = 0.0
        var depthScaling: Float = 1.0
        var audioAttenuation: Float = 0.0
        var stabilizationStrength: Float = 0.0
        var reframeEnabled: Bool = false
    }

    // MARK: - Immersive Content

    struct ImmersiveContent {
        var id: UUID
        var title: String
        var videoURL: URL?
        var audioURL: URL?
        var metadataURL: URL?
        var contentType: ContentType
        var renderingMode: RenderingMode
        var spatialAudioType: SpatialAudioType

        enum ContentType: String {
            case video180       // 180° video
            case video360       // 360° video
            case spatialVideo   // Apple Spatial Video (MV-HEVC)
            case immersiveVideo // Apple Immersive Video (AIV)
            case mixedReality   // AR overlay content
            case volumetric     // Volumetric capture
        }

        enum RenderingMode: String {
            case monoscopic     // 2D spherical
            case stereoscopic   // Side-by-side 3D
            case multiview      // MV-HEVC
            case pointCloud     // Volumetric points
            case mesh           // Textured mesh
        }

        enum SpatialAudioType: String {
            case stereo         // Standard stereo
            case ambisonics     // Ambisonic (1st-3rd order)
            case objectBased    // Object-based audio
            case channelBased   // 5.1/7.1/Atmos
            case apac           // Apple Positional Audio Codec
        }
    }

    // MARK: - Dependencies

    private let aivEngine: AIVMetadataEngine
    private let apacEngine: APACSpatialAudioEngine

    // Video playback
    private var videoPlayer: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?

    // Audio sync
    private var audioSyncOffset: TimeInterval = 0

    // Content
    private var currentContent: ImmersiveContent?
    private var loadedMetadata: AIVMetadataEngine.AIVMetadata?

    // Bio-data
    private var currentHRV: Float = 50.0
    private var currentCoherence: Float = 0.5

    // Frame timing
    private var lastFrameTime: TimeInterval = 0
    private var frameRate: Float = 90.0

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(aivEngine: AIVMetadataEngine, apacEngine: APACSpatialAudioEngine) {
        self.aivEngine = aivEngine
        self.apacEngine = apacEngine

        setupObservers()

        print("🎬 ImmersivePlaybackController: Initialized")
    }

    private func setupObservers() {
        // Observe video player status
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in
                self?.handlePlaybackEnded()
            }
            .store(in: &cancellables)
    }

    // MARK: - Content Loading

    func loadContent(_ content: ImmersiveContent) async throws {
        playbackState = .loading
        currentContent = content

        print("🎬 Loading immersive content: \(content.title)")

        // Load video if present
        if let videoURL = content.videoURL {
            try await loadVideo(url: videoURL, renderingMode: content.renderingMode)
        }

        // Load spatial audio if present
        if let audioURL = content.audioURL {
            try await loadSpatialAudio(url: audioURL, type: content.spatialAudioType)
        }

        // Load AIV metadata if present
        if let metadataURL = content.metadataURL {
            try await loadMetadata(url: metadataURL)
        }

        playbackState = .stopped

        print("🎬 Content loaded successfully")
    }

    private func loadVideo(url: URL, renderingMode: ImmersiveContent.RenderingMode) async throws {
        let asset = AVURLAsset(url: url)

        // Load duration
        let durationValue = try await asset.load(.duration)
        duration = durationValue.seconds

        // Create player item
        playerItem = AVPlayerItem(asset: asset)

        // Create player
        videoPlayer = AVPlayer(playerItem: playerItem)
        videoPlayer?.actionAtItemEnd = .pause

        // Setup time observer
        let interval = CMTime(seconds: 1.0/60.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = videoPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.handleTimeUpdate(time: time.seconds)
        }

        print("🎬 Video loaded: \(duration)s, mode: \(renderingMode)")
    }

    private func loadSpatialAudio(url: URL, type: ImmersiveContent.SpatialAudioType) async throws {
        // Create spatial audio source
        let sourceID = try await apacEngine.createSource(
            name: "Main Audio",
            position: .zero,
            type: type == .ambisonics ? .ambisonic : .pointSource,
            audioFile: url
        )

        print("🎬 Spatial audio loaded: \(type)")
    }

    private func loadMetadata(url: URL) async throws {
        let data = try Data(contentsOf: url)

        if aivEngine.importMetadata(data) {
            print("🎬 AIV metadata loaded")
        }
    }

    // MARK: - Playback Control

    func play() {
        guard playbackState != .playing else { return }

        videoPlayer?.play()
        playbackState = .playing

        // Start spatial audio
        for source in apacEngine.activeSources {
            apacEngine.playSource(source.id)
        }

        // Start immersive session
        aivEngine.startImmersiveSession()

        print("▶️ Playback started")
    }

    func pause() {
        guard playbackState == .playing else { return }

        videoPlayer?.pause()
        playbackState = .paused

        // Pause spatial audio
        for source in apacEngine.activeSources {
            apacEngine.stopSource(source.id)
        }

        print("⏸️ Playback paused")
    }

    func stop() {
        videoPlayer?.pause()
        videoPlayer?.seek(to: .zero)
        currentTime = 0
        playbackState = .stopped

        // Stop spatial audio
        for source in apacEngine.activeSources {
            apacEngine.stopSource(source.id)
        }

        // End immersive session
        aivEngine.endImmersiveSession()

        print("⏹️ Playback stopped")
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        videoPlayer?.seek(to: cmTime)
        currentTime = time
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = max(0.5, min(2.0, rate))
        videoPlayer?.rate = playbackRate
    }

    // MARK: - Frame Updates

    private func handleTimeUpdate(time: TimeInterval) {
        currentTime = time

        // Calculate frame delta
        let deltaTime = time - lastFrameTime
        lastFrameTime = time

        // Get current head pose (would come from ARKit/visionOS)
        let headPosition = getCurrentHeadPosition()
        let headOrientation = getCurrentHeadOrientation()

        // Update listener position for spatial audio
        apacEngine.updateListener(position: headPosition, orientation: headOrientation)

        // Analyze motion comfort
        comfortScore = aivEngine.analyzeFrameMotion(
            position: headPosition,
            rotation: headOrientation,
            timestamp: time
        )

        // Get comfort adjustments
        let aivAdjustments = aivEngine.getComfortAdjustmentsForFrame()

        // Apply comfort adjustments
        applyComfortAdjustments(aivAdjustments)

        // Apply bio-reactive modulation
        if bioReactiveEnabled {
            applyBioReactiveModulation()
        }

        // Sync spatial audio positions with video
        syncSpatialAudioToVideo(time: time)
    }

    private func getCurrentHeadPosition() -> SIMD3<Float> {
        // In production, this comes from ARKit/visionOS head tracking
        return .zero
    }

    private func getCurrentHeadOrientation() -> simd_quatf {
        // In production, this comes from ARKit/visionOS head tracking
        return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    }

    // MARK: - Comfort System

    private func applyComfortAdjustments(_ aivAdjustments: AIVMetadataEngine.ComfortAdjustments) {
        activeAdjustments.vignetteRadius = aivAdjustments.vignetteRadius
        activeAdjustments.vignetteIntensity = 1.0 - aivAdjustments.vignetteRadius
        activeAdjustments.fovReduction = aivAdjustments.fovReduction
        activeAdjustments.motionBlur = aivAdjustments.blurAmount
        activeAdjustments.stabilizationStrength = aivAdjustments.stabilizationStrength

        // Audio comfort - slight attenuation during discomfort
        if comfortScore < 0.5 {
            activeAdjustments.audioAttenuation = (0.5 - comfortScore) * 0.3
        } else {
            activeAdjustments.audioAttenuation = 0
        }

        // Depth scaling - reduce 3D effect during discomfort
        if comfortScore < 0.4 {
            activeAdjustments.depthScaling = 0.5 + (comfortScore * 1.25)
            aivEngine.setStereoscopicDepth(activeAdjustments.depthScaling)
        }
    }

    // MARK: - Bio-Reactive Modulation

    func updateBioData(hrv: Float, coherence: Float) {
        currentHRV = hrv
        currentCoherence = coherence

        // Forward to engines
        aivEngine.updateBioData(hrv: hrv, coherence: coherence)
        apacEngine.applyBioReactiveModulation(hrv: hrv, coherence: coherence)
    }

    private func applyBioReactiveModulation() {
        // Adjust playback based on bio-data

        // Lower coherence = more comfort measures
        if currentCoherence < 0.4 {
            // Auto-apply accessibility preset during high stress
            if comfortScore < 0.6 {
                aivEngine.applyComfortPreset(.accessibility)
            }
        }

        // High coherence = allow more immersion
        if currentCoherence > 0.8 && comfortScore > 0.8 {
            aivEngine.applyComfortPreset(.moderate)
        }
    }

    // MARK: - A/V Sync

    private func syncSpatialAudioToVideo(time: TimeInterval) {
        // Ensure spatial audio is synced with video
        let adjustedTime = time + audioSyncOffset

        // Update spatial anchor positions if they have keyframes
        // This would read from the AIV metadata timeline
    }

    func setAudioSyncOffset(_ offset: TimeInterval) {
        audioSyncOffset = max(-1.0, min(1.0, offset))
    }

    // MARK: - Quality Control

    func setExperienceQuality(_ quality: ExperienceQuality) {
        experienceQuality = quality

        switch quality {
        case .low:
            frameRate = 30
            aivEngine.applyComfortPreset(.comfortable)

        case .medium:
            frameRate = 60
            aivEngine.applyComfortPreset(.moderate)

        case .high:
            frameRate = 90
            // Use loaded metadata presets

        case .ultra:
            frameRate = 120
            aivEngine.applyComfortPreset(.intense)
        }

        print("🎬 Experience quality set to: \(quality)")
    }

    // MARK: - Event Handling

    private func handlePlaybackEnded() {
        playbackState = .stopped
        aivEngine.endImmersiveSession()

        print("🎬 Playback ended")
    }

    // MARK: - Cleanup

    func cleanup() {
        stop()

        if let observer = timeObserver {
            videoPlayer?.removeTimeObserver(observer)
        }

        videoPlayer = nil
        playerItem = nil
        currentContent = nil
    }

    deinit {
        cleanup()
    }
}

// MARK: - Immersive Experience Builder

extension ImmersivePlaybackController {

    /// Create a complete immersive experience from Echoelmusic project
    func createExperienceFromProject(
        visualizationData: [Float],
        audioURL: URL,
        bioData: (hrv: [Float], coherence: [Float])
    ) async throws -> ImmersiveContent {
        let content = ImmersiveContent(
            id: UUID(),
            title: "Echoelmusic Experience",
            videoURL: nil,  // Will be generated
            audioURL: audioURL,
            metadataURL: nil,
            contentType: .immersiveVideo,
            renderingMode: .stereoscopic,
            spatialAudioType: .apac
        )

        // Generate spatial audio anchors from visualization
        await generateSpatialAnchorsFromVisualization(visualizationData)

        // Apply bio-data timeline
        applyBioDataTimeline(bioData)

        return content
    }

    private func generateSpatialAnchorsFromVisualization(_ data: [Float]) async {
        // Create spatial audio sources based on frequency bands
        let bands = 8

        for i in 0..<bands {
            let angle = Float(i) / Float(bands) * 2 * .pi
            let radius: Float = 3.0
            let position = SIMD3<Float>(
                cos(angle) * radius,
                0,
                sin(angle) * radius
            )

            _ = try? await apacEngine.createSource(
                name: "Band \(i + 1)",
                position: position,
                type: .pointSource
            )
        }
    }

    private func applyBioDataTimeline(_ bioData: (hrv: [Float], coherence: [Float])) {
        // Store bio-data for timeline-based modulation
        // This would be used during playback
    }
}

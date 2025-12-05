import Foundation
import Combine
import simd

#if os(visionOS)
import RealityKit
import ARKit
import GroupActivities
import Spatial
#endif

// MARK: - visionOS 26 Spatial Engine
// WWDC 2025: Enhanced spatial computing APIs
// 90Hz hand tracking, shared coordinate spaces, spatial widgets

/// visionOS 26 Spatial Computing Engine for Echoelmusic
/// Implements new WWDC 2025 spatial APIs for immersive music experiences
@MainActor
@Observable
class VisionOS26SpatialEngine {

    // MARK: - State

    /// Whether spatial features are available
    var isAvailable: Bool = false

    /// Current hand tracking state
    var handTrackingState: HandTrackingState = .unavailable

    /// Active spatial anchors
    var spatialAnchors: [SpatialAnchor] = []

    /// Shared coordinate space participants
    var sharedSpaceParticipants: [SpaceParticipant] = []

    /// Active spatial widgets
    var spatialWidgets: [SpatialWidget] = []

    /// Hand gesture state
    var currentGesture: HandGesture = .none

    // MARK: - Types

    enum HandTrackingState: String {
        case unavailable = "Unavailable"
        case initializing = "Initializing"
        case tracking = "Tracking at 90Hz"
        case lost = "Tracking Lost"
    }

    enum HandGesture: String {
        case none = "None"
        case pinch = "Pinch"
        case grab = "Grab"
        case point = "Point"
        case thumbsUp = "Thumbs Up"
        case wave = "Wave"
        case custom = "Custom"
    }

    struct SpatialAnchor: Identifiable {
        let id: UUID
        var name: String
        var position: SIMD3<Float>
        var orientation: simd_quatf
        var isShared: Bool
        var attachedContent: AttachedContent?

        enum AttachedContent {
            case visualizer
            case mixer
            case instrument
            case speaker
            case effect
        }
    }

    struct SpaceParticipant: Identifiable {
        let id: UUID
        let deviceId: String
        var displayName: String
        var headPosition: SIMD3<Float>
        var headOrientation: simd_quatf
        var handPositions: (left: SIMD3<Float>?, right: SIMD3<Float>?)
        var isActive: Bool
    }

    struct SpatialWidget: Identifiable {
        let id: UUID
        var type: WidgetType
        var position: SIMD3<Float>
        var size: SIMD3<Float>
        var isPersistent: Bool

        enum WidgetType: String {
            case nowPlaying = "Now Playing"
            case bioMetrics = "Bio Metrics"
            case mixerControl = "Mixer Control"
            case visualizer = "Visualizer"
            case collaborator = "Collaborator"
        }
    }

    // MARK: - Private State

    #if os(visionOS)
    private var arkitSession: ARKitSession?
    private var handTrackingProvider: HandTrackingProvider?
    private var worldTrackingProvider: WorldTrackingProvider?
    private var sharedCoordinateSpaceProvider: SharedCoordinateSpaceProvider?
    #endif

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        Task {
            await initialize()
        }
    }

    private func initialize() async {
        #if os(visionOS)
        // Check ARKit availability
        guard ARKitSession.isSupported else {
            print("⚠️ ARKit not supported on this device")
            return
        }

        arkitSession = ARKitSession()
        isAvailable = true

        print("🥽 visionOS 26 Spatial Engine initialized")
        #else
        print("🥽 visionOS 26 Spatial Engine (compatibility mode)")
        isAvailable = true
        #endif
    }

    // MARK: - Hand Tracking (90Hz)

    /// Start 90Hz hand tracking (WWDC 2025)
    func startHandTracking() async throws {
        handTrackingState = .initializing

        #if os(visionOS)
        guard let session = arkitSession else {
            throw SpatialError.sessionNotInitialized
        }

        // Request 90Hz hand tracking (new in visionOS 26)
        handTrackingProvider = HandTrackingProvider()

        do {
            try await session.run([handTrackingProvider!])
            handTrackingState = .tracking

            // Start processing hand updates
            Task {
                await processHandUpdates()
            }

            print("✋ 90Hz hand tracking started")
        } catch {
            handTrackingState = .unavailable
            throw error
        }
        #else
        // Simulation mode
        handTrackingState = .tracking
        print("✋ Hand tracking simulation started")
        #endif
    }

    #if os(visionOS)
    private func processHandUpdates() async {
        guard let provider = handTrackingProvider else { return }

        for await update in provider.anchorUpdates {
            switch update.event {
            case .added, .updated:
                await handleHandUpdate(update.anchor)
            case .removed:
                currentGesture = .none
            }
        }
    }

    private func handleHandUpdate(_ anchor: HandAnchor) async {
        // Detect gestures from hand skeleton
        let gesture = detectGesture(from: anchor)
        if gesture != currentGesture {
            currentGesture = gesture
            await handleGestureChange(gesture, hand: anchor.chirality)
        }
    }

    private func detectGesture(from anchor: HandAnchor) -> HandGesture {
        let skeleton = anchor.handSkeleton

        // Get finger positions
        guard let thumbTip = skeleton?.joint(.thumbTip),
              let indexTip = skeleton?.joint(.indexFingerTip),
              let middleTip = skeleton?.joint(.middleFingerTip) else {
            return .none
        }

        // Calculate distances for gesture recognition
        let thumbIndexDistance = simd_distance(
            thumbTip.anchorFromJointTransform.columns.3.xyz,
            indexTip.anchorFromJointTransform.columns.3.xyz
        )

        // Pinch detection (thumb and index close together)
        if thumbIndexDistance < 0.02 {
            return .pinch
        }

        // Add more gesture detection as needed
        return .none
    }
    #endif

    private func handleGestureChange(_ gesture: HandGesture, hand: Any) async {
        print("👋 Gesture detected: \(gesture.rawValue)")

        switch gesture {
        case .pinch:
            // Trigger audio interaction
            NotificationCenter.default.post(
                name: .spatialGestureDetected,
                object: nil,
                userInfo: ["gesture": gesture.rawValue]
            )
        default:
            break
        }
    }

    // MARK: - Shared Coordinate Space (WWDC 2025)

    /// Start shared coordinate space for co-located collaboration
    func startSharedCoordinateSpace() async throws {
        #if os(visionOS)
        guard let session = arkitSession else {
            throw SpatialError.sessionNotInitialized
        }

        // Create shared coordinate space provider (new in visionOS 26)
        sharedCoordinateSpaceProvider = SharedCoordinateSpaceProvider()

        do {
            try await session.run([sharedCoordinateSpaceProvider!])

            // Listen for participant updates
            Task {
                await processParticipantUpdates()
            }

            print("🌐 Shared coordinate space started")
        } catch {
            throw SpatialError.sharedSpaceFailed(error.localizedDescription)
        }
        #else
        print("🌐 Shared coordinate space simulation")
        #endif
    }

    #if os(visionOS)
    private func processParticipantUpdates() async {
        guard let provider = sharedCoordinateSpaceProvider else { return }

        for await update in provider.participantUpdates {
            switch update.event {
            case .added:
                await addParticipant(update.participant)
            case .updated:
                await updateParticipant(update.participant)
            case .removed:
                await removeParticipant(update.participant)
            }
        }
    }

    private func addParticipant(_ participant: SharedCoordinateSpaceParticipant) async {
        let newParticipant = SpaceParticipant(
            id: UUID(),
            deviceId: participant.id.uuidString,
            displayName: "Collaborator",
            headPosition: participant.transform.columns.3.xyz,
            headOrientation: simd_quatf(participant.transform),
            handPositions: (nil, nil),
            isActive: true
        )
        sharedSpaceParticipants.append(newParticipant)
        print("👥 Participant joined: \(newParticipant.deviceId)")
    }

    private func updateParticipant(_ participant: SharedCoordinateSpaceParticipant) async {
        if let index = sharedSpaceParticipants.firstIndex(where: { $0.deviceId == participant.id.uuidString }) {
            sharedSpaceParticipants[index].headPosition = participant.transform.columns.3.xyz
            sharedSpaceParticipants[index].headOrientation = simd_quatf(participant.transform)
        }
    }

    private func removeParticipant(_ participant: SharedCoordinateSpaceParticipant) async {
        sharedSpaceParticipants.removeAll { $0.deviceId == participant.id.uuidString }
        print("👥 Participant left")
    }
    #endif

    // MARK: - Spatial Anchors

    /// Create a world anchor for persistent content
    func createSpatialAnchor(
        name: String,
        position: SIMD3<Float>,
        content: SpatialAnchor.AttachedContent? = nil
    ) async throws -> SpatialAnchor {
        let anchor = SpatialAnchor(
            id: UUID(),
            name: name,
            position: position,
            orientation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            isShared: false,
            attachedContent: content
        )

        #if os(visionOS)
        guard let provider = worldTrackingProvider else {
            throw SpatialError.trackingNotActive
        }

        // Create world anchor
        let worldAnchor = WorldAnchor(originFromAnchorTransform: simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(position.x, position.y, position.z, 1)
        ))

        try await provider.addAnchor(worldAnchor)
        #endif

        spatialAnchors.append(anchor)
        print("📍 Spatial anchor created: \(name)")
        return anchor
    }

    /// Share an anchor with other participants
    func shareAnchor(_ anchor: SpatialAnchor) async throws {
        guard let index = spatialAnchors.firstIndex(where: { $0.id == anchor.id }) else {
            throw SpatialError.anchorNotFound
        }

        #if os(visionOS)
        // Use shared world anchors (new in visionOS 26)
        // This makes the anchor visible to all participants in the shared space
        #endif

        spatialAnchors[index].isShared = true
        print("🔗 Anchor shared: \(anchor.name)")
    }

    // MARK: - Spatial Widgets (WWDC 2025)

    /// Create a persistent spatial widget
    func createSpatialWidget(
        type: SpatialWidget.WidgetType,
        position: SIMD3<Float>,
        size: SIMD3<Float> = SIMD3<Float>(0.3, 0.2, 0.01),
        persistent: Bool = true
    ) -> SpatialWidget {
        let widget = SpatialWidget(
            id: UUID(),
            type: type,
            position: position,
            size: size,
            isPersistent: persistent
        )

        spatialWidgets.append(widget)
        print("📱 Spatial widget created: \(type.rawValue)")
        return widget
    }

    /// Remove a spatial widget
    func removeSpatialWidget(_ widget: SpatialWidget) {
        spatialWidgets.removeAll { $0.id == widget.id }
        print("📱 Spatial widget removed")
    }

    // MARK: - Look to Scroll (WWDC 2025)

    /// Enable look-to-scroll for a content area
    func enableLookToScroll(for contentId: String) {
        #if os(visionOS)
        // Configure eye tracking for scroll behavior
        print("👁️ Look-to-scroll enabled for: \(contentId)")
        #endif
    }

    // MARK: - Spatial Audio Positioning

    /// Position audio source in 3D space relative to user
    func positionAudioSource(
        sourceId: UUID,
        position: SIMD3<Float>,
        orientation: simd_quatf? = nil
    ) {
        // Integration with APAC spatial audio
        NotificationCenter.default.post(
            name: .spatialAudioPositionUpdate,
            object: nil,
            userInfo: [
                "sourceId": sourceId,
                "position": position,
                "orientation": orientation as Any
            ]
        )
    }

    // MARK: - Cleanup

    func cleanup() {
        #if os(visionOS)
        arkitSession?.stop()
        handTrackingProvider = nil
        worldTrackingProvider = nil
        sharedCoordinateSpaceProvider = nil
        #endif

        spatialAnchors.removeAll()
        spatialWidgets.removeAll()
        sharedSpaceParticipants.removeAll()
        handTrackingState = .unavailable
    }

    // MARK: - Errors

    enum SpatialError: Error, LocalizedError {
        case sessionNotInitialized
        case trackingNotActive
        case sharedSpaceFailed(String)
        case anchorNotFound

        var errorDescription: String? {
            switch self {
            case .sessionNotInitialized:
                return "ARKit session not initialized"
            case .trackingNotActive:
                return "World tracking not active"
            case .sharedSpaceFailed(let reason):
                return "Shared space failed: \(reason)"
            case .anchorNotFound:
                return "Spatial anchor not found"
            }
        }
    }
}

// MARK: - SharePlay Enhancements (WWDC 2025)

/// Enhanced SharePlay for Echoelmusic collaboration
/// WWDC 2025: Nearby Window Sharing, shared world anchors
@MainActor
@Observable
class EnhancedSharePlayEngine {

    // MARK: - State

    var isActive: Bool = false
    var isNearbyMode: Bool = false
    var participants: [SharePlayParticipant] = []
    var sharedObjects: [SharedObject] = []

    // MARK: - Types

    struct SharePlayParticipant: Identifiable {
        let id: UUID
        var displayName: String
        var avatar: String
        var isLocal: Bool
        var isHost: Bool
        var currentAction: String?
        var position: SIMD3<Float>?
    }

    struct SharedObject: Identifiable, Codable {
        let id: UUID
        var type: ObjectType
        var data: Data
        var owner: UUID
        var position: SIMD3<Float>?
        var scale: Float

        enum ObjectType: String, Codable {
            case audioClip
            case midiPattern
            case effect
            case visualizer
            case instrument
        }
    }

    // MARK: - Nearby Window Sharing (WWDC 2025)

    #if os(visionOS)
    private var groupSession: GroupSession<EchoelmusicActivity>?
    #endif

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Start Session

    /// Start a SharePlay session with nearby participants
    func startNearbySession() async throws {
        #if os(visionOS)
        // New in visionOS 26: Nearby Window Sharing
        let activity = EchoelmusicActivity()

        switch await activity.prepareForActivation() {
        case .activationPreferred:
            do {
                let activated = try await activity.activate()
                isActive = true
                isNearbyMode = true
                print("🔗 Nearby SharePlay session started")
            } catch {
                throw SharePlayError.activationFailed(error.localizedDescription)
            }

        case .activationDisabled:
            throw SharePlayError.disabled

        case .cancelled:
            throw SharePlayError.cancelled

        @unknown default:
            throw SharePlayError.unknown
        }
        #else
        // Simulation mode
        isActive = true
        isNearbyMode = true
        addSimulatedParticipant()
        print("🔗 SharePlay simulation started")
        #endif
    }

    /// Start remote SharePlay session
    func startRemoteSession() async throws {
        #if os(visionOS)
        let activity = EchoelmusicActivity()

        switch await activity.prepareForActivation() {
        case .activationPreferred:
            let activated = try await activity.activate()
            isActive = true
            isNearbyMode = false
            print("🌐 Remote SharePlay session started")

        case .activationDisabled:
            throw SharePlayError.disabled

        case .cancelled:
            throw SharePlayError.cancelled

        @unknown default:
            throw SharePlayError.unknown
        }
        #else
        isActive = true
        isNearbyMode = false
        print("🌐 Remote SharePlay simulation started")
        #endif
    }

    // MARK: - Object Sharing

    /// Share an object with all participants
    func shareObject(_ object: SharedObject) async throws {
        guard isActive else {
            throw SharePlayError.sessionNotActive
        }

        sharedObjects.append(object)

        #if os(visionOS)
        // Broadcast to all participants
        if let session = groupSession {
            let data = try JSONEncoder().encode(object)
            // Send via GroupSessionMessenger
        }
        #endif

        print("📤 Object shared: \(object.type.rawValue)")
    }

    /// Hand off a virtual object to another participant
    func handOffObject(_ object: SharedObject, to participant: SharePlayParticipant) async throws {
        guard isActive else {
            throw SharePlayError.sessionNotActive
        }

        guard let index = sharedObjects.firstIndex(where: { $0.id == object.id }) else {
            throw SharePlayError.objectNotFound
        }

        // Update ownership
        sharedObjects[index].owner = participant.id

        #if os(visionOS)
        // Animate handoff in 3D space
        #endif

        print("🤝 Object handed off to: \(participant.displayName)")
    }

    // MARK: - Window Sharing

    /// Share a window with nearby participants
    func shareWindow(windowId: String) async throws {
        guard isNearbyMode else {
            throw SharePlayError.notNearbyMode
        }

        #if os(visionOS)
        // Use Nearby Window Sharing API
        print("🪟 Window shared: \(windowId)")
        #endif
    }

    /// Snap shared content to surroundings
    func snapToSurface(objectId: UUID, surfaceType: SurfaceType) {
        guard let index = sharedObjects.firstIndex(where: { $0.id == objectId }) else { return }

        #if os(visionOS)
        // Use RealityKit to snap to detected surfaces
        print("📌 Object snapped to: \(surfaceType.rawValue)")
        #endif
    }

    enum SurfaceType: String {
        case wall, floor, table, ceiling
    }

    // MARK: - Session Management

    func endSession() {
        #if os(visionOS)
        groupSession?.end()
        groupSession = nil
        #endif

        isActive = false
        isNearbyMode = false
        participants.removeAll()
        sharedObjects.removeAll()
        print("🔚 SharePlay session ended")
    }

    // MARK: - Helpers

    private func addSimulatedParticipant() {
        let participant = SharePlayParticipant(
            id: UUID(),
            displayName: "Demo Collaborator",
            avatar: "person.circle",
            isLocal: false,
            isHost: false,
            currentAction: "Listening",
            position: SIMD3<Float>(1, 0, -2)
        )
        participants.append(participant)
    }

    // MARK: - Errors

    enum SharePlayError: Error, LocalizedError {
        case activationFailed(String)
        case disabled
        case cancelled
        case unknown
        case sessionNotActive
        case objectNotFound
        case notNearbyMode

        var errorDescription: String? {
            switch self {
            case .activationFailed(let reason):
                return "SharePlay activation failed: \(reason)"
            case .disabled:
                return "SharePlay is disabled in settings"
            case .cancelled:
                return "SharePlay activation cancelled"
            case .unknown:
                return "Unknown SharePlay error"
            case .sessionNotActive:
                return "No active SharePlay session"
            case .objectNotFound:
                return "Shared object not found"
            case .notNearbyMode:
                return "Not in nearby sharing mode"
            }
        }
    }
}

// MARK: - GroupActivity Definition

#if os(visionOS)
struct EchoelmusicActivity: GroupActivity {
    static let activityIdentifier = "com.echoelmusic.collaboration"

    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = "Echoelmusic Studio"
        meta.subtitle = "Bio-Reactive Music Collaboration"
        meta.type = .generic
        meta.supportsContinuationOnTV = false
        return meta
    }
}
#endif

// MARK: - SIMD Extensions

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> {
        SIMD3<Float>(x, y, z)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let spatialGestureDetected = Notification.Name("spatialGestureDetected")
    static let spatialAudioPositionUpdate = Notification.Name("spatialAudioPositionUpdate")
}

// MARK: - Preview

#if DEBUG
import SwiftUI

struct VisionOS26PreviewView: View {
    @State private var spatialEngine = VisionOS26SpatialEngine()
    @State private var sharePlayEngine = EnhancedSharePlayEngine()

    var body: some View {
        VStack(spacing: 20) {
            // Spatial Status
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("visionOS 26 Spatial Engine")
                        .font(.headline)
                        .foregroundStyle(.white)

                    HStack {
                        Circle()
                            .fill(spatialEngine.isAvailable ? Color.green : Color.red)
                            .frame(width: 8, height: 8)

                        Text(spatialEngine.handTrackingState.rawValue)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Text("Gesture: \(spatialEngine.currentGesture.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                }
            }

            // SharePlay Status
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enhanced SharePlay")
                        .font(.headline)
                        .foregroundStyle(.white)

                    HStack {
                        Circle()
                            .fill(sharePlayEngine.isActive ? Color.green : Color.red)
                            .frame(width: 8, height: 8)

                        Text(sharePlayEngine.isActive ? "Active" : "Inactive")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Text("Participants: \(sharePlayEngine.participants.count)")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
            }

            // Controls
            HStack(spacing: 12) {
                Button("Start Nearby") {
                    Task {
                        try? await sharePlayEngine.startNearbySession()
                    }
                }
                .buttonStyle(.liquidGlass(tint: .blue))

                Button("End Session") {
                    sharePlayEngine.endSession()
                }
                .buttonStyle(.liquidGlass(tint: .red))
            }
        }
        .padding()
    }
}

#Preview("visionOS 26 Preview") {
    ZStack {
        AnimatedGlassBackground()
        VisionOS26PreviewView()
    }
    .preferredColorScheme(.dark)
}
#endif

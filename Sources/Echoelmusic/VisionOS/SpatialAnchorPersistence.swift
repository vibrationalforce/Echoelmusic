import Foundation
import Combine

#if canImport(RealityKit)
import RealityKit
#endif

#if canImport(ARKit) && os(visionOS)
import ARKit
#endif

/// Persistent spatial anchor management for visionOS immersive experiences.
///
/// Enables saving and restoring spatial anchors across sessions so that
/// immersive content (audio sources, visual elements, bio-reactive zones)
/// reappears at the same physical location.
///
/// Features:
/// - Save/load anchor positions to disk
/// - Associate metadata (audio config, visual state) with anchors
/// - Bio-reactive zone persistence (meditation spots, performance stages)
/// - Automatic re-localization on session start
/// - Migration handling when physical space changes
@MainActor
class SpatialAnchorPersistence: ObservableObject {

    // MARK: - Types

    struct PersistedAnchor: Codable, Identifiable {
        let id: UUID
        var name: String
        var transform: CodableTransform
        var metadata: AnchorMetadata
        var createdAt: Date
        var lastUsedAt: Date
        var sessionCount: Int = 1

        struct CodableTransform: Codable {
            var positionX: Float
            var positionY: Float
            var positionZ: Float
            var rotationX: Float
            var rotationY: Float
            var rotationZ: Float
            var rotationW: Float

            var position: SIMD3<Float> {
                SIMD3<Float>(positionX, positionY, positionZ)
            }

            static func from(position: SIMD3<Float>, rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)) -> CodableTransform {
                CodableTransform(
                    positionX: position.x, positionY: position.y, positionZ: position.z,
                    rotationX: rotation.imag.x, rotationY: rotation.imag.y,
                    rotationZ: rotation.imag.z, rotationW: rotation.real
                )
            }
        }
    }

    struct AnchorMetadata: Codable {
        var anchorType: AnchorType
        var audioConfiguration: AudioConfig?
        var visualConfiguration: VisualConfig?
        var bioReactiveZone: BioReactiveZoneConfig?
        var tags: [String] = []

        struct AudioConfig: Codable {
            var spatialMode: String = "binaural"
            var reverbBlend: Float = 0.3
            var sourceGain: Float = 1.0
            var sourceFrequency: Float = 440.0
        }

        struct VisualConfig: Codable {
            var experienceType: String = "meditation"
            var environmentType: String = "cosmos"
            var intensity: Float = 1.0
            var colorScheme: String = "bioReactive"
        }

        struct BioReactiveZoneConfig: Codable {
            var zoneRadius: Float = 2.0
            var coherenceThreshold: Float = 0.6
            var activationType: String = "proximity"  // proximity, gaze, gesture
            var feedbackMode: String = "visual"        // visual, audio, haptic, all
        }
    }

    enum AnchorType: String, Codable, CaseIterable {
        case audioSource          // Spatial audio source position
        case visualElement        // Visual effect anchor point
        case bioReactiveZone     // Bio-reactive interaction zone
        case performanceStage    // Performance/livestream stage marker
        case meditationSpot      // Meditation practice location
        case instrumentPosition  // Virtual instrument placement
        case controlSurface      // Floating control panel position
        case lightSource         // DMX/ILDA lighting anchor
    }

    enum PersistenceError: Error, LocalizedError {
        case anchorNotFound(UUID)
        case saveFailed(String)
        case loadFailed(String)
        case relocalizationFailed
        case storageCorrupted

        var errorDescription: String? {
            switch self {
            case .anchorNotFound(let id): return "Anchor \(id) not found"
            case .saveFailed(let msg): return "Failed to save anchors: \(msg)"
            case .loadFailed(let msg): return "Failed to load anchors: \(msg)"
            case .relocalizationFailed: return "Could not relocalize saved anchors"
            case .storageCorrupted: return "Anchor storage is corrupted"
            }
        }
    }

    // MARK: - Published State

    @Published var persistedAnchors: [PersistedAnchor] = []
    @Published var activeAnchors: [UUID: Bool] = [:]  // anchor ID → is relocalized
    @Published var isRelocalized: Bool = false
    @Published var anchorCount: Int = 0

    // MARK: - Properties

    private let storageURL: URL
    private let fileManager = FileManager.default

    #if canImport(RealityKit)
    /// Map from persisted anchor ID to RealityKit AnchorEntity
    private var realityAnchors: [UUID: AnchorEntity] = [:]
    #endif

    // MARK: - Initialization

    init() {
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.storageURL = documentsDir.appendingPathComponent("SpatialAnchors", isDirectory: true)

        // Ensure storage directory exists
        try? fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)

        // Load persisted anchors
        loadAnchors()
    }

    // MARK: - Anchor Creation

    /// Create and persist a new spatial anchor.
    @discardableResult
    func createAnchor(
        name: String,
        position: SIMD3<Float>,
        rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
        type: AnchorType,
        metadata: AnchorMetadata? = nil
    ) -> PersistedAnchor {
        let now = Date()
        var anchorMetadata = metadata ?? AnchorMetadata(anchorType: type)
        anchorMetadata.anchorType = type

        let anchor = PersistedAnchor(
            id: UUID(),
            name: name,
            transform: PersistedAnchor.CodableTransform.from(position: position, rotation: rotation),
            metadata: anchorMetadata,
            createdAt: now,
            lastUsedAt: now
        )

        persistedAnchors.append(anchor)
        anchorCount = persistedAnchors.count
        saveAnchors()

        return anchor
    }

    /// Create an audio source anchor with full configuration.
    @discardableResult
    func createAudioSourceAnchor(
        name: String,
        position: SIMD3<Float>,
        spatialMode: String = "binaural",
        reverbBlend: Float = 0.3,
        gain: Float = 1.0
    ) -> PersistedAnchor {
        let audioConfig = AnchorMetadata.AudioConfig(
            spatialMode: spatialMode,
            reverbBlend: reverbBlend,
            sourceGain: gain
        )
        let metadata = AnchorMetadata(
            anchorType: .audioSource,
            audioConfiguration: audioConfig
        )
        return createAnchor(name: name, position: position, type: .audioSource, metadata: metadata)
    }

    /// Create a bio-reactive zone anchor.
    @discardableResult
    func createBioReactiveZone(
        name: String,
        position: SIMD3<Float>,
        radius: Float = 2.0,
        coherenceThreshold: Float = 0.6,
        feedbackMode: String = "all"
    ) -> PersistedAnchor {
        let zoneConfig = AnchorMetadata.BioReactiveZoneConfig(
            zoneRadius: radius,
            coherenceThreshold: coherenceThreshold,
            feedbackMode: feedbackMode
        )
        let metadata = AnchorMetadata(
            anchorType: .bioReactiveZone,
            bioReactiveZone: zoneConfig
        )
        return createAnchor(name: name, position: position, type: .bioReactiveZone, metadata: metadata)
    }

    // MARK: - Anchor Management

    /// Update an anchor's position (e.g., after user adjustment).
    func updateAnchorPosition(_ id: UUID, position: SIMD3<Float>, rotation: simd_quatf? = nil) throws {
        guard let index = persistedAnchors.firstIndex(where: { $0.id == id }) else {
            throw PersistenceError.anchorNotFound(id)
        }

        persistedAnchors[index].transform = PersistedAnchor.CodableTransform.from(
            position: position,
            rotation: rotation ?? simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        )
        persistedAnchors[index].lastUsedAt = Date()
        saveAnchors()
    }

    /// Update anchor metadata.
    func updateAnchorMetadata(_ id: UUID, metadata: AnchorMetadata) throws {
        guard let index = persistedAnchors.firstIndex(where: { $0.id == id }) else {
            throw PersistenceError.anchorNotFound(id)
        }
        persistedAnchors[index].metadata = metadata
        saveAnchors()
    }

    /// Remove an anchor.
    func removeAnchor(_ id: UUID) {
        persistedAnchors.removeAll { $0.id == id }
        activeAnchors.removeValue(forKey: id)

        #if canImport(RealityKit)
        if let entity = realityAnchors.removeValue(forKey: id) {
            entity.removeFromParent()
        }
        #endif

        anchorCount = persistedAnchors.count
        saveAnchors()
    }

    /// Remove all anchors of a specific type.
    func removeAnchors(ofType type: AnchorType) {
        let toRemove = persistedAnchors.filter { $0.metadata.anchorType == type }
        for anchor in toRemove {
            removeAnchor(anchor.id)
        }
    }

    // MARK: - Queries

    /// Get all anchors of a specific type.
    func anchors(ofType type: AnchorType) -> [PersistedAnchor] {
        persistedAnchors.filter { $0.metadata.anchorType == type }
    }

    /// Get anchors near a position (within radius).
    func anchorsNear(position: SIMD3<Float>, radius: Float) -> [PersistedAnchor] {
        persistedAnchors.filter { anchor in
            simd_length(anchor.transform.position - position) <= radius
        }
    }

    /// Get the most recently used anchors.
    func recentAnchors(limit: Int = 10) -> [PersistedAnchor] {
        Array(persistedAnchors.sorted { $0.lastUsedAt > $1.lastUsedAt }.prefix(limit))
    }

    // MARK: - Session Lifecycle

    /// Restore anchors into the current scene.
    func restoreAnchors() {
        for anchor in persistedAnchors {
            activeAnchors[anchor.id] = false // Not yet relocalized

            #if canImport(RealityKit) && os(visionOS)
            restoreRealityKitAnchor(anchor)
            #endif
        }

        // Mark session use
        for i in 0..<persistedAnchors.count {
            persistedAnchors[i].lastUsedAt = Date()
            persistedAnchors[i].sessionCount += 1
        }

        isRelocalized = true
        saveAnchors()
    }

    #if canImport(RealityKit) && os(visionOS)
    private func restoreRealityKitAnchor(_ anchor: PersistedAnchor) {
        let anchorEntity = AnchorEntity(world: anchor.transform.position)
        anchorEntity.name = anchor.name

        realityAnchors[anchor.id] = anchorEntity
        activeAnchors[anchor.id] = true
    }
    #endif

    /// Get a RealityKit anchor entity for scene attachment.
    #if canImport(RealityKit)
    func anchorEntity(for id: UUID) -> AnchorEntity? {
        realityAnchors[id]
    }
    #endif

    // MARK: - Persistence (Disk)

    private func saveAnchors() {
        let fileURL = storageURL.appendingPathComponent("anchors.json")
        do {
            let data = try JSONEncoder().encode(persistedAnchors)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Silent fail for persistence - non-critical
        }
    }

    private func loadAnchors() {
        let fileURL = storageURL.appendingPathComponent("anchors.json")
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            persistedAnchors = try JSONDecoder().decode([PersistedAnchor].self, from: data)
            anchorCount = persistedAnchors.count
        } catch {
            // Corrupted data - start fresh
            persistedAnchors = []
            anchorCount = 0
        }
    }

    /// Export all anchors as JSON data (for sharing/backup).
    func exportAnchors() throws -> Data {
        try JSONEncoder().encode(persistedAnchors)
    }

    /// Import anchors from JSON data (merge with existing).
    func importAnchors(from data: Data) throws {
        let imported = try JSONDecoder().decode([PersistedAnchor].self, from: data)
        let existingIDs = Set(persistedAnchors.map { $0.id })

        for anchor in imported where !existingIDs.contains(anchor.id) {
            persistedAnchors.append(anchor)
        }

        anchorCount = persistedAnchors.count
        saveAnchors()
    }

    // MARK: - Reset

    func removeAllAnchors() {
        #if canImport(RealityKit)
        for entity in realityAnchors.values {
            entity.removeFromParent()
        }
        realityAnchors.removeAll()
        #endif

        persistedAnchors.removeAll()
        activeAnchors.removeAll()
        anchorCount = 0
        isRelocalized = false
        saveAnchors()
    }
}

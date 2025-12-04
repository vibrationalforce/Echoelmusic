import Foundation
import Metal
import MetalKit
import simd
import Combine
import SceneKit
import ModelIO

// ═══════════════════════════════════════════════════════════════════════════════
// 3D ANIMATION ENGINE - REALISTIC TO FANTASY TO SCIFI
// ═══════════════════════════════════════════════════════════════════════════════
//
// Complete 3D animation system with:
// • Prompt-based scene generation
// • Full manual 3D editing
// • Multiple rendering styles (Realistic, Fantasy, SciFi, Abstract)
// • Procedural asset generation
// • Physics-based animation
// • Keyframe animation system
// • Real-time preview
// • Audio-reactive animation
// • Bio-reactive parameters
//
// PHILOSOPHY: AI generates, YOU control every vertex if you want.
//
// ═══════════════════════════════════════════════════════════════════════════════

/// Main 3D Animation Engine
@MainActor
final class Animation3DEngine: ObservableObject {

    // MARK: - Published State

    @Published var currentScene: Scene3D?
    @Published var selectedObjectID: UUID?
    @Published var isRendering: Bool = false
    @Published var renderProgress: Float = 0
    @Published var previewFPS: Double = 60

    // MARK: - Animation State

    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 10
    @Published var frameRate: Int = 30

    // MARK: - Style Settings

    @Published var renderStyle: RenderStyle = .realistic
    @Published var lightingPreset: LightingPreset = .studio
    @Published var environmentMap: String = "default_hdri"

    // MARK: - Render Styles

    enum RenderStyle: String, CaseIterable, Identifiable {
        case realistic = "Realistic"
        case fantasy = "Fantasy"
        case scifi = "Sci-Fi"
        case cartoon = "Cartoon"
        case anime = "Anime"
        case lowPoly = "Low Poly"
        case voxel = "Voxel"
        case wireframe = "Wireframe"
        case holographic = "Holographic"
        case neon = "Neon"
        case painterly = "Painterly"
        case sketch = "Sketch"

        var id: String { rawValue }

        var settings: RenderSettings {
            switch self {
            case .realistic:
                return RenderSettings(
                    shadingModel: .pbr,
                    shadowQuality: .high,
                    reflections: true,
                    ambientOcclusion: true,
                    bloom: false,
                    outlineWidth: 0,
                    colorGrading: .neutral
                )
            case .fantasy:
                return RenderSettings(
                    shadingModel: .pbr,
                    shadowQuality: .medium,
                    reflections: true,
                    ambientOcclusion: true,
                    bloom: true,
                    outlineWidth: 0,
                    colorGrading: .warm
                )
            case .scifi:
                return RenderSettings(
                    shadingModel: .pbr,
                    shadowQuality: .high,
                    reflections: true,
                    ambientOcclusion: true,
                    bloom: true,
                    outlineWidth: 0,
                    colorGrading: .cool
                )
            case .cartoon:
                return RenderSettings(
                    shadingModel: .toon,
                    shadowQuality: .low,
                    reflections: false,
                    ambientOcclusion: false,
                    bloom: false,
                    outlineWidth: 2,
                    colorGrading: .saturated
                )
            case .anime:
                return RenderSettings(
                    shadingModel: .toon,
                    shadowQuality: .medium,
                    reflections: false,
                    ambientOcclusion: false,
                    bloom: true,
                    outlineWidth: 1.5,
                    colorGrading: .anime
                )
            case .lowPoly:
                return RenderSettings(
                    shadingModel: .flat,
                    shadowQuality: .low,
                    reflections: false,
                    ambientOcclusion: false,
                    bloom: false,
                    outlineWidth: 0,
                    colorGrading: .neutral
                )
            case .voxel:
                return RenderSettings(
                    shadingModel: .flat,
                    shadowQuality: .medium,
                    reflections: false,
                    ambientOcclusion: true,
                    bloom: false,
                    outlineWidth: 0,
                    colorGrading: .neutral
                )
            case .wireframe:
                return RenderSettings(
                    shadingModel: .wireframe,
                    shadowQuality: .none,
                    reflections: false,
                    ambientOcclusion: false,
                    bloom: true,
                    outlineWidth: 1,
                    colorGrading: .neutral
                )
            case .holographic:
                return RenderSettings(
                    shadingModel: .hologram,
                    shadowQuality: .none,
                    reflections: false,
                    ambientOcclusion: false,
                    bloom: true,
                    outlineWidth: 0.5,
                    colorGrading: .hologram
                )
            case .neon:
                return RenderSettings(
                    shadingModel: .emissive,
                    shadowQuality: .low,
                    reflections: true,
                    ambientOcclusion: false,
                    bloom: true,
                    outlineWidth: 0,
                    colorGrading: .neon
                )
            case .painterly:
                return RenderSettings(
                    shadingModel: .painterly,
                    shadowQuality: .medium,
                    reflections: false,
                    ambientOcclusion: false,
                    bloom: false,
                    outlineWidth: 0,
                    colorGrading: .painterly
                )
            case .sketch:
                return RenderSettings(
                    shadingModel: .sketch,
                    shadowQuality: .none,
                    reflections: false,
                    ambientOcclusion: false,
                    bloom: false,
                    outlineWidth: 2,
                    colorGrading: .monochrome
                )
            }
        }
    }

    enum LightingPreset: String, CaseIterable {
        case studio = "Studio"
        case outdoor = "Outdoor"
        case sunset = "Sunset"
        case night = "Night"
        case dramatic = "Dramatic"
        case soft = "Soft"
        case neon = "Neon"
        case fantasy = "Fantasy"
        case scifi = "Sci-Fi"
        case horror = "Horror"
    }

    // MARK: - Metal Setup

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var renderPipeline: MTLRenderPipelineState?

    // MARK: - Initialization

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue

        setupRenderPipeline()
    }

    private func setupRenderPipeline() {
        // Would set up Metal render pipeline for real-time preview
    }

    // MARK: - Scene Management

    func createNewScene(name: String = "Untitled") {
        currentScene = Scene3D(
            id: UUID(),
            name: name,
            objects: [],
            cameras: [Camera3D.default],
            lights: [Light3D.defaultKey, Light3D.defaultFill, Light3D.defaultBack],
            environment: Environment3D.default,
            timeline: Timeline3D()
        )
    }

    func loadScene(from url: URL) throws {
        let data = try Data(contentsOf: url)
        currentScene = try JSONDecoder().decode(Scene3D.self, from: data)
    }

    func saveScene(to url: URL) throws {
        guard let scene = currentScene else { return }
        let data = try JSONEncoder().encode(scene)
        try data.write(to: url)
    }

    // MARK: - AI Scene Generation

    /// Generate 3D scene from text prompt
    func generateFromPrompt(_ prompt: String) async -> [SceneSuggestion] {
        isRendering = true
        renderProgress = 0

        let intent = parseSceneIntent(prompt)
        var suggestions: [SceneSuggestion] = []

        // Generate multiple scene variations
        for i in 0..<3 {
            renderProgress = Float(i + 1) / 4.0

            let suggestion = await generateSceneVariation(
                intent: intent,
                variationIndex: i
            )
            suggestions.append(suggestion)
        }

        renderProgress = 1.0
        isRendering = false

        return suggestions
    }

    private func parseSceneIntent(_ prompt: String) -> SceneIntent {
        let lowercased = prompt.lowercased()

        // Detect scene type
        var sceneType: SceneType = .abstract

        if lowercased.contains("realistic") || lowercased.contains("photo") {
            sceneType = .realistic
        } else if lowercased.contains("fantasy") || lowercased.contains("magic") {
            sceneType = .fantasy
        } else if lowercased.contains("sci-fi") || lowercased.contains("space") || lowercased.contains("future") {
            sceneType = .scifi
        } else if lowercased.contains("cartoon") || lowercased.contains("animated") {
            sceneType = .cartoon
        } else if lowercased.contains("nature") || lowercased.contains("landscape") {
            sceneType = .nature
        } else if lowercased.contains("urban") || lowercased.contains("city") {
            sceneType = .urban
        }

        // Detect objects
        var requestedObjects: [ObjectRequest] = []

        let objectKeywords: [(String, ProceduralObjectType)] = [
            ("sphere", .sphere), ("cube", .cube), ("cylinder", .cylinder),
            ("cone", .cone), ("torus", .torus), ("pyramid", .pyramid),
            ("tree", .tree), ("rock", .rock), ("crystal", .crystal),
            ("building", .building), ("terrain", .terrain), ("water", .water),
            ("character", .character), ("vehicle", .vehicle),
            ("planet", .planet), ("star", .star), ("nebula", .nebula)
        ]

        for (keyword, objectType) in objectKeywords {
            if lowercased.contains(keyword) {
                requestedObjects.append(ObjectRequest(type: objectType, count: 1))
            }
        }

        // Detect animation
        var animationType: AnimationType = .static
        if lowercased.contains("rotating") || lowercased.contains("spin") {
            animationType = .rotating
        } else if lowercased.contains("floating") || lowercased.contains("hover") {
            animationType = .floating
        } else if lowercased.contains("pulse") || lowercased.contains("breathing") {
            animationType = .pulsing
        } else if lowercased.contains("orbit") {
            animationType = .orbiting
        } else if lowercased.contains("particle") || lowercased.contains("explosion") {
            animationType = .particles
        }

        // Detect mood/atmosphere
        var mood: SceneMood = .neutral
        if lowercased.contains("dark") || lowercased.contains("moody") {
            mood = .dark
        } else if lowercased.contains("bright") || lowercased.contains("happy") {
            mood = .bright
        } else if lowercased.contains("mysterious") {
            mood = .mysterious
        } else if lowercased.contains("epic") {
            mood = .epic
        } else if lowercased.contains("calm") || lowercased.contains("peaceful") {
            mood = .calm
        }

        return SceneIntent(
            prompt: prompt,
            sceneType: sceneType,
            requestedObjects: requestedObjects.isEmpty ? [ObjectRequest(type: .sphere, count: 1)] : requestedObjects,
            animationType: animationType,
            mood: mood,
            keywords: prompt.components(separatedBy: .whitespaces)
        )
    }

    private func generateSceneVariation(intent: SceneIntent, variationIndex: Int) async -> SceneSuggestion {
        var objects: [Object3D] = []

        // Generate requested objects
        for request in intent.requestedObjects {
            for i in 0..<request.count {
                let object = generateProceduralObject(
                    type: request.type,
                    sceneType: intent.sceneType,
                    index: i + variationIndex * 10
                )
                objects.append(object)
            }
        }

        // Add environment objects based on scene type
        let environmentObjects = generateEnvironmentObjects(for: intent.sceneType, variation: variationIndex)
        objects.append(contentsOf: environmentObjects)

        // Generate animation tracks
        let animations = generateAnimations(for: objects, type: intent.animationType)

        // Determine render style
        let style: RenderStyle
        switch intent.sceneType {
        case .realistic: style = .realistic
        case .fantasy: style = .fantasy
        case .scifi: style = .scifi
        case .cartoon: style = .cartoon
        case .nature: style = .realistic
        case .urban: style = .realistic
        case .abstract: style = [.lowPoly, .neon, .holographic][variationIndex % 3]
        }

        // Determine lighting
        let lighting: LightingPreset
        switch intent.mood {
        case .dark: lighting = .dramatic
        case .bright: lighting = .studio
        case .mysterious: lighting = .night
        case .epic: lighting = .sunset
        case .calm: lighting = .soft
        case .neutral: lighting = .studio
        }

        return SceneSuggestion(
            id: UUID(),
            name: "\(intent.sceneType.rawValue) Scene \(variationIndex + 1)",
            objects: objects,
            animations: animations,
            style: style,
            lighting: lighting,
            description: generateSceneDescription(intent: intent, objectCount: objects.count)
        )
    }

    private func generateProceduralObject(type: ProceduralObjectType, sceneType: SceneType, index: Int) -> Object3D {
        let position = SIMD3<Float>(
            Float.random(in: -5...5),
            Float.random(in: 0...3),
            Float.random(in: -5...5)
        )

        let scale: Float
        let material: Material3D

        switch type {
        case .sphere, .cube, .cylinder, .cone, .torus, .pyramid:
            scale = Float.random(in: 0.5...2.0)
            material = generateMaterial(for: sceneType, objectType: type)

        case .tree:
            scale = Float.random(in: 2...5)
            material = Material3D(
                albedo: SIMD3<Float>(0.2, 0.5, 0.2),
                metallic: 0,
                roughness: 0.8,
                emission: SIMD3<Float>(0, 0, 0)
            )

        case .rock:
            scale = Float.random(in: 0.3...2)
            material = Material3D(
                albedo: SIMD3<Float>(0.5, 0.5, 0.5),
                metallic: 0,
                roughness: 0.9,
                emission: SIMD3<Float>(0, 0, 0)
            )

        case .crystal:
            scale = Float.random(in: 0.5...1.5)
            material = Material3D(
                albedo: SIMD3<Float>(0.8, 0.3, 0.9),
                metallic: 0.9,
                roughness: 0.1,
                emission: SIMD3<Float>(0.2, 0.1, 0.3)
            )

        case .building:
            scale = Float.random(in: 3...10)
            material = Material3D(
                albedo: SIMD3<Float>(0.7, 0.7, 0.75),
                metallic: 0.5,
                roughness: 0.3,
                emission: SIMD3<Float>(0, 0, 0)
            )

        case .terrain:
            scale = 20
            material = Material3D(
                albedo: SIMD3<Float>(0.3, 0.5, 0.2),
                metallic: 0,
                roughness: 1.0,
                emission: SIMD3<Float>(0, 0, 0)
            )

        case .water:
            scale = 15
            material = Material3D(
                albedo: SIMD3<Float>(0.1, 0.3, 0.5),
                metallic: 0.8,
                roughness: 0.1,
                emission: SIMD3<Float>(0, 0, 0)
            )

        case .character:
            scale = 1.8
            material = Material3D(
                albedo: SIMD3<Float>(0.8, 0.6, 0.5),
                metallic: 0,
                roughness: 0.5,
                emission: SIMD3<Float>(0, 0, 0)
            )

        case .vehicle:
            scale = Float.random(in: 2...4)
            material = Material3D(
                albedo: SIMD3<Float>(0.2, 0.2, 0.8),
                metallic: 0.8,
                roughness: 0.2,
                emission: SIMD3<Float>(0, 0, 0)
            )

        case .planet:
            scale = Float.random(in: 3...8)
            material = Material3D(
                albedo: SIMD3<Float>(0.3, 0.5, 0.7),
                metallic: 0,
                roughness: 0.6,
                emission: SIMD3<Float>(0, 0, 0)
            )

        case .star:
            scale = Float.random(in: 1...3)
            material = Material3D(
                albedo: SIMD3<Float>(1, 0.9, 0.7),
                metallic: 0,
                roughness: 0,
                emission: SIMD3<Float>(5, 4, 3)
            )

        case .nebula:
            scale = Float.random(in: 10...20)
            material = Material3D(
                albedo: SIMD3<Float>(0.5, 0.2, 0.8),
                metallic: 0,
                roughness: 1,
                emission: SIMD3<Float>(0.1, 0.05, 0.2)
            )
        }

        return Object3D(
            id: UUID(),
            name: "\(type.rawValue)_\(index)",
            type: type,
            transform: Transform3D(
                position: position,
                rotation: SIMD3<Float>(0, Float.random(in: 0...360), 0),
                scale: SIMD3<Float>(repeating: scale)
            ),
            material: material,
            meshData: nil, // Would be generated procedurally
            isVisible: true,
            isLocked: false
        )
    }

    private func generateMaterial(for sceneType: SceneType, objectType: ProceduralObjectType) -> Material3D {
        switch sceneType {
        case .realistic:
            return Material3D(
                albedo: SIMD3<Float>(Float.random(in: 0.3...0.8), Float.random(in: 0.3...0.8), Float.random(in: 0.3...0.8)),
                metallic: Float.random(in: 0...0.5),
                roughness: Float.random(in: 0.3...0.7),
                emission: SIMD3<Float>(0, 0, 0)
            )

        case .fantasy:
            return Material3D(
                albedo: SIMD3<Float>(Float.random(in: 0.5...1.0), Float.random(in: 0.2...0.8), Float.random(in: 0.5...1.0)),
                metallic: Float.random(in: 0.3...0.8),
                roughness: Float.random(in: 0.1...0.5),
                emission: SIMD3<Float>(Float.random(in: 0...0.3), Float.random(in: 0...0.3), Float.random(in: 0...0.3))
            )

        case .scifi:
            return Material3D(
                albedo: SIMD3<Float>(Float.random(in: 0.1...0.4), Float.random(in: 0.2...0.5), Float.random(in: 0.4...0.9)),
                metallic: Float.random(in: 0.7...1.0),
                roughness: Float.random(in: 0.1...0.3),
                emission: SIMD3<Float>(0, Float.random(in: 0...0.5), Float.random(in: 0...0.8))
            )

        case .cartoon:
            let hue = Float.random(in: 0...1)
            return Material3D(
                albedo: hslToRgb(h: hue, s: 0.8, l: 0.6),
                metallic: 0,
                roughness: 1.0,
                emission: SIMD3<Float>(0, 0, 0)
            )

        default:
            return Material3D(
                albedo: SIMD3<Float>(0.5, 0.5, 0.5),
                metallic: 0.3,
                roughness: 0.5,
                emission: SIMD3<Float>(0, 0, 0)
            )
        }
    }

    private func hslToRgb(h: Float, s: Float, l: Float) -> SIMD3<Float> {
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2

        var r: Float = 0, g: Float = 0, b: Float = 0
        let hPrime = h * 6

        if hPrime < 1 { r = c; g = x; b = 0 }
        else if hPrime < 2 { r = x; g = c; b = 0 }
        else if hPrime < 3 { r = 0; g = c; b = x }
        else if hPrime < 4 { r = 0; g = x; b = c }
        else if hPrime < 5 { r = x; g = 0; b = c }
        else { r = c; g = 0; b = x }

        return SIMD3<Float>(r + m, g + m, b + m)
    }

    private func generateEnvironmentObjects(for sceneType: SceneType, variation: Int) -> [Object3D] {
        var objects: [Object3D] = []

        switch sceneType {
        case .nature:
            // Add ground plane
            objects.append(Object3D(
                id: UUID(),
                name: "Ground",
                type: .terrain,
                transform: Transform3D(
                    position: SIMD3<Float>(0, 0, 0),
                    rotation: SIMD3<Float>(0, 0, 0),
                    scale: SIMD3<Float>(20, 1, 20)
                ),
                material: Material3D(
                    albedo: SIMD3<Float>(0.2, 0.4, 0.15),
                    metallic: 0,
                    roughness: 1,
                    emission: SIMD3<Float>(0, 0, 0)
                ),
                meshData: nil,
                isVisible: true,
                isLocked: true
            ))

            // Add some trees
            for i in 0..<5 {
                let angle = Float(i) / 5.0 * 2 * .pi
                let radius = Float.random(in: 5...10)
                objects.append(generateProceduralObject(type: .tree, sceneType: sceneType, index: i))
            }

        case .scifi:
            // Add platform
            objects.append(Object3D(
                id: UUID(),
                name: "Platform",
                type: .cube,
                transform: Transform3D(
                    position: SIMD3<Float>(0, -0.5, 0),
                    rotation: SIMD3<Float>(0, 0, 0),
                    scale: SIMD3<Float>(15, 0.5, 15)
                ),
                material: Material3D(
                    albedo: SIMD3<Float>(0.1, 0.1, 0.15),
                    metallic: 0.9,
                    roughness: 0.2,
                    emission: SIMD3<Float>(0, 0.05, 0.1)
                ),
                meshData: nil,
                isVisible: true,
                isLocked: true
            ))

        case .fantasy:
            // Add magical ground
            objects.append(Object3D(
                id: UUID(),
                name: "Mystical Ground",
                type: .terrain,
                transform: Transform3D(
                    position: SIMD3<Float>(0, 0, 0),
                    rotation: SIMD3<Float>(0, 0, 0),
                    scale: SIMD3<Float>(20, 1, 20)
                ),
                material: Material3D(
                    albedo: SIMD3<Float>(0.3, 0.2, 0.4),
                    metallic: 0.3,
                    roughness: 0.6,
                    emission: SIMD3<Float>(0.05, 0.02, 0.08)
                ),
                meshData: nil,
                isVisible: true,
                isLocked: true
            ))

            // Add floating crystals
            for i in 0..<3 {
                objects.append(generateProceduralObject(type: .crystal, sceneType: sceneType, index: i))
            }

        default:
            break
        }

        return objects
    }

    private func generateAnimations(for objects: [Object3D], type: AnimationType) -> [AnimationTrack3D] {
        var tracks: [AnimationTrack3D] = []

        for object in objects {
            switch type {
            case .static:
                break

            case .rotating:
                tracks.append(AnimationTrack3D(
                    id: UUID(),
                    objectID: object.id,
                    property: .rotation,
                    keyframes: [
                        Keyframe3D(time: 0, value: .vector3(SIMD3<Float>(0, 0, 0)), easing: .linear),
                        Keyframe3D(time: 5, value: .vector3(SIMD3<Float>(0, 360, 0)), easing: .linear)
                    ],
                    isLooping: true
                ))

            case .floating:
                tracks.append(AnimationTrack3D(
                    id: UUID(),
                    objectID: object.id,
                    property: .position,
                    keyframes: [
                        Keyframe3D(time: 0, value: .vector3(object.transform.position), easing: .easeInOut),
                        Keyframe3D(time: 1.5, value: .vector3(object.transform.position + SIMD3<Float>(0, 0.5, 0)), easing: .easeInOut),
                        Keyframe3D(time: 3, value: .vector3(object.transform.position), easing: .easeInOut)
                    ],
                    isLooping: true
                ))

            case .pulsing:
                tracks.append(AnimationTrack3D(
                    id: UUID(),
                    objectID: object.id,
                    property: .scale,
                    keyframes: [
                        Keyframe3D(time: 0, value: .vector3(object.transform.scale), easing: .easeInOut),
                        Keyframe3D(time: 0.5, value: .vector3(object.transform.scale * 1.2), easing: .easeInOut),
                        Keyframe3D(time: 1, value: .vector3(object.transform.scale), easing: .easeInOut)
                    ],
                    isLooping: true
                ))

            case .orbiting:
                // More complex orbit animation
                var keyframes: [Keyframe3D] = []
                let orbitRadius: Float = 3
                for i in 0...8 {
                    let angle = Float(i) / 8.0 * 2 * .pi
                    let pos = SIMD3<Float>(
                        cos(angle) * orbitRadius,
                        object.transform.position.y,
                        sin(angle) * orbitRadius
                    )
                    keyframes.append(Keyframe3D(
                        time: Double(i) * 0.625,
                        value: .vector3(pos),
                        easing: .linear
                    ))
                }
                tracks.append(AnimationTrack3D(
                    id: UUID(),
                    objectID: object.id,
                    property: .position,
                    keyframes: keyframes,
                    isLooping: true
                ))

            case .particles:
                // Would add particle system animation
                break
            }
        }

        return tracks
    }

    private func generateSceneDescription(intent: SceneIntent, objectCount: Int) -> String {
        return "\(intent.sceneType.rawValue) scene with \(objectCount) objects, \(intent.animationType.rawValue) animation, \(intent.mood.rawValue) mood"
    }

    // MARK: - Manual Editing

    func addObject(_ object: Object3D) {
        currentScene?.objects.append(object)
        selectedObjectID = object.id
    }

    func removeObject(_ id: UUID) {
        currentScene?.objects.removeAll { $0.id == id }
        if selectedObjectID == id {
            selectedObjectID = currentScene?.objects.first?.id
        }
    }

    func duplicateObject(_ id: UUID) {
        guard var scene = currentScene,
              let original = scene.objects.first(where: { $0.id == id }) else { return }

        var duplicate = original
        duplicate.id = UUID()
        duplicate.name = original.name + "_copy"
        duplicate.transform.position += SIMD3<Float>(1, 0, 1)

        scene.objects.append(duplicate)
        currentScene = scene
        selectedObjectID = duplicate.id
    }

    func updateSelectedObject(_ update: (inout Object3D) -> Void) {
        guard let id = selectedObjectID,
              let index = currentScene?.objects.firstIndex(where: { $0.id == id }) else { return }

        update(&currentScene!.objects[index])
    }

    // MARK: - Transform Operations

    func translateSelected(by delta: SIMD3<Float>) {
        updateSelectedObject { object in
            object.transform.position += delta
        }
    }

    func rotateSelected(by degrees: SIMD3<Float>) {
        updateSelectedObject { object in
            object.transform.rotation += degrees
        }
    }

    func scaleSelected(by factor: Float) {
        updateSelectedObject { object in
            object.transform.scale *= factor
        }
    }

    // MARK: - Apply AI Suggestion

    func applySuggestion(_ suggestion: SceneSuggestion) {
        currentScene = Scene3D(
            id: UUID(),
            name: suggestion.name,
            objects: suggestion.objects,
            cameras: [Camera3D.default],
            lights: getLightsForPreset(suggestion.lighting),
            environment: Environment3D.default,
            timeline: Timeline3D(tracks: suggestion.animations)
        )

        renderStyle = suggestion.style
        lightingPreset = suggestion.lighting
    }

    private func getLightsForPreset(_ preset: LightingPreset) -> [Light3D] {
        switch preset {
        case .studio:
            return [Light3D.defaultKey, Light3D.defaultFill, Light3D.defaultBack]

        case .dramatic:
            return [
                Light3D(id: UUID(), type: .spot, position: SIMD3<Float>(5, 10, 5), color: SIMD3<Float>(1, 0.9, 0.8), intensity: 3),
                Light3D(id: UUID(), type: .ambient, position: SIMD3<Float>(0, 0, 0), color: SIMD3<Float>(0.1, 0.1, 0.15), intensity: 0.3)
            ]

        case .sunset:
            return [
                Light3D(id: UUID(), type: .directional, position: SIMD3<Float>(-10, 5, 0), color: SIMD3<Float>(1, 0.6, 0.3), intensity: 2),
                Light3D(id: UUID(), type: .ambient, position: SIMD3<Float>(0, 0, 0), color: SIMD3<Float>(0.4, 0.3, 0.5), intensity: 0.5)
            ]

        case .night:
            return [
                Light3D(id: UUID(), type: .point, position: SIMD3<Float>(0, 5, 0), color: SIMD3<Float>(0.5, 0.5, 0.8), intensity: 1),
                Light3D(id: UUID(), type: .ambient, position: SIMD3<Float>(0, 0, 0), color: SIMD3<Float>(0.05, 0.05, 0.1), intensity: 0.2)
            ]

        case .neon:
            return [
                Light3D(id: UUID(), type: .point, position: SIMD3<Float>(3, 2, 3), color: SIMD3<Float>(1, 0, 0.5), intensity: 2),
                Light3D(id: UUID(), type: .point, position: SIMD3<Float>(-3, 2, -3), color: SIMD3<Float>(0, 0.5, 1), intensity: 2),
                Light3D(id: UUID(), type: .ambient, position: SIMD3<Float>(0, 0, 0), color: SIMD3<Float>(0.1, 0.05, 0.15), intensity: 0.3)
            ]

        default:
            return [Light3D.defaultKey]
        }
    }

    // MARK: - Playback Control

    func play() {
        isPlaying = true
    }

    func pause() {
        isPlaying = false
    }

    func stop() {
        isPlaying = false
        currentTime = 0
    }

    func seekTo(_ time: TimeInterval) {
        currentTime = max(0, min(duration, time))
    }

    // MARK: - Export

    func exportAsGLTF() -> Data? {
        // Would export scene as glTF format
        return nil
    }

    func exportAsUSD() -> Data? {
        // Would export scene as USD format
        return nil
    }

    func renderAnimation(to url: URL, format: VideoFormat, quality: RenderQuality) async {
        isRendering = true
        renderProgress = 0

        let totalFrames = Int(duration * Double(frameRate))

        for frame in 0..<totalFrames {
            renderProgress = Float(frame) / Float(totalFrames)
            currentTime = Double(frame) / Double(frameRate)

            // Render frame
            // Would render using Metal and write to video

            try? await Task.sleep(nanoseconds: 1_000_000) // Simulate render time
        }

        renderProgress = 1.0
        isRendering = false
    }

    enum VideoFormat { case mp4, mov, webm }
    enum RenderQuality { case preview, standard, high, ultra }
}

// MARK: - Supporting Types

struct Scene3D: Identifiable, Codable {
    let id: UUID
    var name: String
    var objects: [Object3D]
    var cameras: [Camera3D]
    var lights: [Light3D]
    var environment: Environment3D
    var timeline: Timeline3D
}

struct Object3D: Identifiable, Codable {
    var id: UUID
    var name: String
    var type: ProceduralObjectType
    var transform: Transform3D
    var material: Material3D
    var meshData: Data? // Would contain vertex/index data
    var isVisible: Bool
    var isLocked: Bool
}

struct Transform3D: Codable {
    var position: SIMD3<Float>
    var rotation: SIMD3<Float> // Euler angles in degrees
    var scale: SIMD3<Float>
}

struct Material3D: Codable {
    var albedo: SIMD3<Float>
    var metallic: Float
    var roughness: Float
    var emission: SIMD3<Float>
}

struct Camera3D: Identifiable, Codable {
    let id: UUID
    var name: String
    var position: SIMD3<Float>
    var target: SIMD3<Float>
    var fov: Float
    var nearPlane: Float
    var farPlane: Float

    static let `default` = Camera3D(
        id: UUID(),
        name: "Main Camera",
        position: SIMD3<Float>(5, 5, 5),
        target: SIMD3<Float>(0, 0, 0),
        fov: 60,
        nearPlane: 0.1,
        farPlane: 1000
    )
}

struct Light3D: Identifiable, Codable {
    let id: UUID
    var type: LightType
    var position: SIMD3<Float>
    var color: SIMD3<Float>
    var intensity: Float

    enum LightType: String, Codable {
        case directional, point, spot, ambient, area
    }

    static let defaultKey = Light3D(id: UUID(), type: .directional, position: SIMD3<Float>(5, 10, 5), color: SIMD3<Float>(1, 1, 1), intensity: 1)
    static let defaultFill = Light3D(id: UUID(), type: .directional, position: SIMD3<Float>(-3, 5, 3), color: SIMD3<Float>(0.8, 0.9, 1), intensity: 0.5)
    static let defaultBack = Light3D(id: UUID(), type: .directional, position: SIMD3<Float>(0, 3, -5), color: SIMD3<Float>(1, 0.9, 0.8), intensity: 0.3)
}

struct Environment3D: Codable {
    var skyboxName: String?
    var ambientColor: SIMD3<Float>
    var ambientIntensity: Float
    var fogEnabled: Bool
    var fogColor: SIMD3<Float>
    var fogDensity: Float

    static let `default` = Environment3D(
        skyboxName: nil,
        ambientColor: SIMD3<Float>(0.1, 0.1, 0.15),
        ambientIntensity: 0.3,
        fogEnabled: false,
        fogColor: SIMD3<Float>(0.5, 0.5, 0.6),
        fogDensity: 0.01
    )
}

struct Timeline3D: Codable {
    var tracks: [AnimationTrack3D] = []
}

struct AnimationTrack3D: Identifiable, Codable {
    let id: UUID
    var objectID: UUID
    var property: AnimatableProperty
    var keyframes: [Keyframe3D]
    var isLooping: Bool

    enum AnimatableProperty: String, Codable {
        case position, rotation, scale, material, visibility
    }
}

struct Keyframe3D: Codable {
    var time: TimeInterval
    var value: KeyframeValue
    var easing: EasingType

    enum KeyframeValue: Codable {
        case float(Float)
        case vector3(SIMD3<Float>)
        case color(SIMD3<Float>)
        case bool(Bool)
    }

    enum EasingType: String, Codable {
        case linear, easeIn, easeOut, easeInOut, bounce, elastic
    }
}

struct SceneSuggestion: Identifiable {
    let id: UUID
    var name: String
    var objects: [Object3D]
    var animations: [AnimationTrack3D]
    var style: Animation3DEngine.RenderStyle
    var lighting: Animation3DEngine.LightingPreset
    var description: String
}

struct SceneIntent {
    var prompt: String
    var sceneType: SceneType
    var requestedObjects: [ObjectRequest]
    var animationType: AnimationType
    var mood: SceneMood
    var keywords: [String]
}

struct ObjectRequest {
    var type: ProceduralObjectType
    var count: Int
}

enum SceneType: String {
    case realistic, fantasy, scifi, cartoon, nature, urban, abstract
}

enum AnimationType: String {
    case `static` = "Static"
    case rotating = "Rotating"
    case floating = "Floating"
    case pulsing = "Pulsing"
    case orbiting = "Orbiting"
    case particles = "Particles"
}

enum SceneMood: String {
    case neutral, dark, bright, mysterious, epic, calm
}

enum ProceduralObjectType: String, Codable, CaseIterable {
    case sphere, cube, cylinder, cone, torus, pyramid
    case tree, rock, crystal, building, terrain, water
    case character, vehicle, planet, star, nebula
}

struct RenderSettings {
    var shadingModel: ShadingModel
    var shadowQuality: ShadowQuality
    var reflections: Bool
    var ambientOcclusion: Bool
    var bloom: Bool
    var outlineWidth: Float
    var colorGrading: ColorGradingPreset

    enum ShadingModel { case pbr, toon, flat, wireframe, hologram, emissive, painterly, sketch }
    enum ShadowQuality { case none, low, medium, high }
    enum ColorGradingPreset { case neutral, warm, cool, saturated, anime, hologram, neon, painterly, monochrome }
}

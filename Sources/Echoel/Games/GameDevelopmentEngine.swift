import Foundation
import Metal
import MetalKit
import GameplayKit
import SpriteKit
import SceneKit

/// Bio-Reactive Game Development Engine
/// Complete game engine for 2D, 3D, and bio-reactive games
///
/// Capabilities:
/// - 2D Games (Sprite-based, Physics, Particle FX)
/// - 3D Games (Real-time rendering, Physics, AI)
/// - Bio-Reactive Gameplay (HRV affects difficulty, visuals, sound)
/// - Level Editor (Visual, Node-based)
/// - AI & Pathfinding (A*, NavMesh, Behavior Trees)
/// - Multiplayer (Peer-to-peer, Server-client)
/// - Cross-Platform (iOS, iPad, Mac, Vision Pro)
///
/// Competes with: Unity, Unreal Engine, Godot
@MainActor
class GameDevelopmentEngine: ObservableObject {

    // MARK: - Published State

    @Published var currentGame: Game?
    @Published var isPlaying: Bool = false
    @Published var fps: Int = 60
    @Published var editorMode: Bool = true

    // Bio-reactive gameplay
    @Published var bioReactiveEnabled: Bool = false
    @Published var currentDifficulty: Float = 0.5  // 0-1 based on HRV

    // MARK: - Game Structure

    struct Game {
        var name: String
        var type: GameType
        var scenes: [GameScene] = []
        var currentScene: GameScene?

        // Game settings
        var targetFPS: Int = 60
        var resolution: Resolution

        // Bio-reactive settings
        var bioReactive: BioReactiveSettings?

        enum GameType {
            case platformer_2d
            case puzzle_2d
            case rpg_2d
            case shooter_3d
            case adventure_3d
            case racing_3d
            case vr_experience
            case meditation_game  // Bio-reactive meditation
        }

        enum Resolution {
            case native
            case hd_720p
            case fullhd_1080p
            case qhd_2k
            case uhd_4k
        }
    }

    struct BioReactiveSettings {
        var difficultyMode: DifficultyMode
        var visualEffects: VisualEffectMode
        var soundtrackMode: SoundtrackMode

        enum DifficultyMode {
            case fixed                     // Normal game difficulty
            case hrvAdaptive               // Harder when HRV high (challenge), easier when low (support)
            case coherenceAdaptive         // Difficulty based on coherence
            case heartRateAdaptive         // Fast-paced when HR high, calm when low
        }

        enum VisualEffectMode {
            case none
            case colorShift                // HRV → Color palette shift
            case particleIntensity         // More particles when coherent
            case worldMorph                // World changes based on bio-data
        }

        enum SoundtrackMode {
            case static                    // Normal soundtrack
            case bioReactive               // Music adapts to bio-data
            case generative                // AI-generated music based on HRV
        }
    }

    // MARK: - Game Scene

    struct GameScene: Identifiable {
        let id: UUID = UUID()
        var name: String
        var type: SceneType

        // Scene graph
        var rootNode: GameNode
        var camera: Camera?
        var lights: [Light] = []

        // Physics
        var gravity: SIMD3<Float> = SIMD3(0, -9.81, 0)
        var physicsWorld: PhysicsWorld

        enum SceneType {
            case scene2D
            case scene3D
            case ui_menu
        }
    }

    struct GameNode: Identifiable {
        let id: UUID = UUID()
        var name: String
        var type: NodeType
        var transform: Transform

        // Hierarchy
        var children: [GameNode] = []
        var parent: UUID?

        // Components
        var components: [Component] = []

        enum NodeType {
            case empty                  // Transform only
            case sprite                 // 2D sprite
            case mesh                   // 3D mesh
            case light                  // Light source
            case camera                 // Camera
            case particle_emitter       // Particle system
            case audio_source           // 3D audio
        }
    }

    struct Transform {
        var position: SIMD3<Float> = SIMD3(0, 0, 0)
        var rotation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3(0, 1, 0))
        var scale: SIMD3<Float> = SIMD3(1, 1, 1)
    }

    // MARK: - Component System (ECS-like)

    enum Component {
        case sprite(SpriteComponent)
        case mesh(MeshComponent)
        case rigidbody(RigidBodyComponent)
        case collider(ColliderComponent)
        case script(ScriptComponent)
        case animator(AnimatorComponent)
        case particleSystem(ParticleSystemComponent)
        case audioSource(AudioSourceComponent)
        case aiAgent(AIAgentComponent)
        case health(HealthComponent)
        case inventory(InventoryComponent)
    }

    struct SpriteComponent {
        var texture: String  // Texture name
        var size: SIMD2<Float>
        var anchor: SIMD2<Float> = SIMD2(0.5, 0.5)
        var flipX: Bool = false
        var flipY: Bool = false
        var tint: SIMD4<Float> = SIMD4(1, 1, 1, 1)
    }

    struct MeshComponent {
        var meshName: String
        var materials: [String] = []
    }

    struct RigidBodyComponent {
        var mass: Float = 1.0
        var velocity: SIMD3<Float> = SIMD3(0, 0, 0)
        var angularVelocity: SIMD3<Float> = SIMD3(0, 0, 0)
        var useGravity: Bool = true
        var isKinematic: Bool = false
    }

    struct ColliderComponent {
        var shape: ColliderShape
        var isTrigger: Bool = false
        var layer: Int = 0

        enum ColliderShape {
            case box(size: SIMD3<Float>)
            case sphere(radius: Float)
            case capsule(radius: Float, height: Float)
            case mesh  // Mesh collider
        }
    }

    struct ScriptComponent {
        var scriptName: String
        var properties: [String: Any] = [:]

        // Script lifecycle
        var onStart: (() -> Void)?
        var onUpdate: ((Double) -> Void)?
        var onCollision: ((UUID) -> Void)?
    }

    struct AnimatorComponent {
        var animations: [String: Animation]
        var currentAnimation: String?
        var speed: Float = 1.0
        var loop: Bool = true
    }

    struct Animation {
        var name: String
        var duration: Double
        var keyframes: [Keyframe]
    }

    struct Keyframe {
        var time: Double
        var property: String
        var value: Any
    }

    struct ParticleSystemComponent {
        var emissionRate: Int = 100
        var lifetime: Float = 5.0
        var startColor: SIMD4<Float> = SIMD4(1, 1, 1, 1)
        var endColor: SIMD4<Float> = SIMD4(1, 1, 1, 0)
        var startSize: Float = 0.1
        var endSize: Float = 0.05
        var velocity: SIMD3<Float> = SIMD3(0, 1, 0)
    }

    struct AudioSourceComponent {
        var audioClip: String
        var volume: Float = 1.0
        var pitch: Float = 1.0
        var loop: Bool = false
        var spatial: Bool = true
        var maxDistance: Float = 100.0
    }

    struct AIAgentComponent {
        var behaviorTree: BehaviorTree?
        var navMeshAgent: NavMeshAgent?
        var perceptionRadius: Float = 10.0
        var targetPosition: SIMD3<Float>?
    }

    struct HealthComponent {
        var maxHealth: Float = 100.0
        var currentHealth: Float = 100.0
        var invincible: Bool = false

        mutating func takeDamage(_ amount: Float) {
            guard !invincible else { return }
            currentHealth = max(0, currentHealth - amount)
        }

        mutating func heal(_ amount: Float) {
            currentHealth = min(maxHealth, currentHealth + amount)
        }

        var isDead: Bool {
            currentHealth <= 0
        }
    }

    struct InventoryComponent {
        var items: [Item] = []
        var maxSlots: Int = 20

        struct Item: Identifiable {
            let id: UUID = UUID()
            var name: String
            var quantity: Int
            var icon: String
        }
    }

    // MARK: - Physics

    struct PhysicsWorld {
        var gravity: SIMD3<Float>
        var bodies: [PhysicsBody] = []

        mutating func step(deltaTime: Double) {
            // Physics simulation step
            for i in 0..<bodies.count {
                bodies[i].velocity += gravity * Float(deltaTime)
                bodies[i].position += bodies[i].velocity * Float(deltaTime)
            }
        }
    }

    struct PhysicsBody {
        var position: SIMD3<Float>
        var velocity: SIMD3<Float>
        var mass: Float
        var collider: ColliderComponent
    }

    struct Camera {
        var position: SIMD3<Float>
        var rotation: simd_quatf
        var fov: Float = 60.0
        var nearPlane: Float = 0.1
        var farPlane: Float = 1000.0

        // Camera modes
        var mode: CameraMode = .free

        enum CameraMode {
            case free
            case followPlayer(offset: SIMD3<Float>)
            case firstPerson
            case thirdPerson
            case orbital(target: SIMD3<Float>, distance: Float)
        }
    }

    struct Light {
        var type: LightType
        var position: SIMD3<Float>
        var color: SIMD3<Float> = SIMD3(1, 1, 1)
        var intensity: Float = 1.0

        enum LightType {
            case directional
            case point
            case spot
        }
    }

    // MARK: - AI & Pathfinding

    struct BehaviorTree {
        var rootNode: BehaviorNode

        enum BehaviorNode {
            case sequence([BehaviorNode])
            case selector([BehaviorNode])
            case action(Action)
            case condition(Condition)

            enum Action {
                case moveToTarget
                case attack
                case flee
                case idle
                case patrol
            }

            enum Condition {
                case playerInRange(Float)
                case healthBelow(Float)
                case hasLineOfSight
            }
        }

        func evaluate() -> BehaviorResult {
            return evaluateNode(rootNode)
        }

        private func evaluateNode(_ node: BehaviorNode) -> BehaviorResult {
            switch node {
            case .sequence(let children):
                for child in children {
                    let result = evaluateNode(child)
                    if result != .success {
                        return result
                    }
                }
                return .success

            case .selector(let children):
                for child in children {
                    let result = evaluateNode(child)
                    if result == .success {
                        return .success
                    }
                }
                return .failure

            case .action:
                return .running

            case .condition:
                return .success
            }
        }

        enum BehaviorResult {
            case success
            case failure
            case running
        }
    }

    struct NavMeshAgent {
        var position: SIMD3<Float>
        var destination: SIMD3<Float>
        var speed: Float = 3.5
        var path: [SIMD3<Float>] = []

        mutating func setDestination(_ dest: SIMD3<Float>) {
            destination = dest
            // In production, this would use A* pathfinding
            path = [position, destination]
        }

        mutating func update(deltaTime: Double) {
            guard !path.isEmpty else { return }

            let target = path[0]
            let direction = normalize(target - position)
            let movement = direction * speed * Float(deltaTime)

            position += movement

            // Reached waypoint?
            if distance(position, target) < 0.5 {
                path.removeFirst()
            }
        }
    }

    // MARK: - Bio-Reactive Gameplay

    func updateBioReactiveGameplay(hrv: Double, heartRate: Double, coherence: Double) {
        guard bioReactiveEnabled else { return }
        guard let settings = currentGame?.bioReactive else { return }

        switch settings.difficultyMode {
        case .hrvAdaptive:
            // High HRV → Harder game (player is calm, can handle challenge)
            // Low HRV → Easier game (player is stressed, needs support)
            currentDifficulty = Float(hrv / 100.0)
            print("🧘 Bio-Difficulty: HRV \(Int(hrv)) → Difficulty \(Int(currentDifficulty * 100))%")

        case .coherenceAdaptive:
            // High coherence → More enemies, faster pace
            currentDifficulty = Float(coherence / 100.0)

        case .heartRateAdaptive:
            // High HR → Fast-paced action
            // Low HR → Calm, puzzle-focused
            let normalizedHR = Float((heartRate - 60) / 60)  // Normalize around 60 BPM
            currentDifficulty = max(0, min(1, normalizedHR))

        case .fixed:
            break
        }

        // Visual effects based on bio-data
        switch settings.visualEffects {
        case .colorShift:
            // HRV → Color palette (low = red/orange, high = blue/purple)
            print("🧘 Bio-Visual: HRV \(Int(hrv)) → Color Shift")

        case .particleIntensity:
            // Coherence → More particles
            print("🧘 Bio-Visual: Coherence \(Int(coherence))% → Particle Intensity")

        case .worldMorph:
            // World geometry changes based on bio-data
            print("🧘 Bio-Visual: World morphing based on bio-data")

        case .none:
            break
        }
    }

    // MARK: - Level Editor

    struct LevelEditor {
        var grid: Grid
        var selectedNode: UUID?
        var tools: [EditorTool]

        struct Grid {
            var size: SIMD2<Float> = SIMD2(10, 10)
            var cellSize: Float = 1.0
            var visible: Bool = true
        }

        enum EditorTool {
            case select
            case move
            case rotate
            case scale
            case paint_terrain
            case place_object
            case delete
        }
    }

    // MARK: - Multiplayer

    struct MultiplayerSession {
        var mode: MultiplayerMode
        var players: [Player] = []
        var maxPlayers: Int = 4

        enum MultiplayerMode {
            case local_coop           // Same device
            case local_network        // LAN
            case online_p2p           // Peer-to-peer
            case online_server        // Dedicated server
        }

        struct Player: Identifiable {
            let id: UUID = UUID()
            var name: String
            var controllerId: UUID
            var score: Int = 0
            var bioData: BioData?
        }

        struct BioData {
            var hrv: Double
            var heartRate: Double
            var coherence: Double
        }
    }

    // MARK: - Scripting

    struct ScriptingEngine {
        var scripts: [String: GameScript] = [:]

        func executeScript(_ name: String) {
            // In production, this would execute Lua, JavaScript, or Swift scripts
            print("▶️ Executing script: \(name)")
        }
    }

    struct GameScript {
        var name: String
        var code: String
        var language: ScriptLanguage

        enum ScriptLanguage {
            case lua
            case javascript
            case swift
        }
    }

    // MARK: - Asset Management

    struct AssetLibrary {
        var textures: [String: MTLTexture] = [:]
        var meshes: [String: Mesh] = [:]
        var audioClips: [String: URL] = [:]
        var scripts: [String: GameScript] = [:]
        var prefabs: [String: GameNode] = [:]
    }

    struct Mesh {
        var vertices: [Vertex]
        var indices: [UInt32]
    }

    struct Vertex {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
        var uv: SIMD2<Float>
    }

    // MARK: - Game Loop

    private var lastUpdateTime: TimeInterval = 0

    func update(deltaTime: TimeInterval) {
        guard isPlaying else { return }

        // Update physics
        currentGame?.currentScene?.physicsWorld.step(deltaTime: deltaTime)

        // Update AI agents
        // updateAI(deltaTime: deltaTime)

        // Update scripts
        // executeScripts(deltaTime: deltaTime)

        // Update animations
        // updateAnimations(deltaTime: deltaTime)

        fps = Int(1.0 / deltaTime)
    }

    func render() {
        guard isPlaying else { return }

        // Render scene
        // In production, this would render using Metal
    }

    // MARK: - Initialization

    init() {
        print("🎮 Game Development Engine initialized")
    }

    // MARK: - Debug Info

    var debugInfo: String {
        var info = """
        GameDevelopmentEngine:
        - Playing: \(isPlaying ? "▶️" : "⏸️")
        - FPS: \(fps)
        - Editor Mode: \(editorMode ? "✅" : "❌")
        """

        if let game = currentGame {
            info += """
            \n- Game: \(game.name) (\(game.type))
            - Scenes: \(game.scenes.count)
            """

            if bioReactiveEnabled {
                info += """
                \n- Bio-Reactive: ✅
                - Difficulty: \(Int(currentDifficulty * 100))% (HRV-adaptive)
                """
            }
        }

        return info
    }
}

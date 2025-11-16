import Foundation
import Metal
import Combine
import AVFoundation

/// Central coordinator for complete Echoelmusic system integration
/// Orchestrates all components: Camera, Streaming, Biometrics, Particles, Audio, Backend
@MainActor
class EchoelmusicAppCoordinator: ObservableObject {

    // MARK: - Published State

    @Published var isInitialized: Bool = false
    @Published var isStreaming: Bool = false
    @Published var isRecording: Bool = false
    @Published var systemHealth: SystemHealth = .initializing

    enum SystemHealth {
        case initializing
        case healthy
        case degraded(reason: String)
        case critical(reason: String)
    }

    // MARK: - Core Components

    private let device: MTLDevice
    private let unifiedControlHub: UnifiedControlHub
    private var cameraStreamingManager: CameraStreamingManager?
    private var particleEngine: MetalParticleEngine?
    private var audioEngine: AudioEngine?

    // MARK: - API Client

    private let apiBaseURL = "https://api.echoelmusic.com"  // Production
    // private let apiBaseURL = "http://localhost:8000"  // Development

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Update Loop

    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0

    // MARK: - Initialization

    init(device: MTLDevice, audioEngine: AudioEngine) {
        self.device = device
        self.audioEngine = audioEngine

        // Initialize UnifiedControlHub
        self.unifiedControlHub = UnifiedControlHub(audioEngine: audioEngine)

        print("🚀 EchoelmusicAppCoordinator: Initializing...")
    }

    // MARK: - Launch Complete System

    func launchCompleteSystem() async throws {
        print("🎬 Launching complete Echoelmusic system...")

        // 1. Initialize Camera & Streaming
        guard let cameraManager = CameraStreamingManager(device: device) else {
            throw CoordinatorError.cameraInitFailed
        }
        self.cameraStreamingManager = cameraManager

        try cameraManager.setupMultiCamera()
        print("✅ Multi-camera system initialized")

        // 2. Initialize Particle Engine
        guard let particles = MetalParticleEngine(device: device, particleCount: 100_000) else {
            throw CoordinatorError.particleEngineInitFailed
        }
        self.particleEngine = particles
        particles.setScreenSize(width: 1920, height: 1080)
        particles.start()
        print("✅ Metal particle engine initialized (100k particles @ 60 FPS)")

        // 3. Enable Biometric Monitoring
        try await unifiedControlHub.enableBiometricMonitoring()
        print("✅ Biometric monitoring enabled")

        // 4. Enable Face Tracking
        unifiedControlHub.enableFaceTracking()
        print("✅ Face tracking enabled")

        // 5. Enable Hand Tracking
        unifiedControlHub.enableHandTracking()
        print("✅ Hand tracking enabled")

        // 6. Start Audio Engine
        audioEngine?.start()
        print("✅ Audio engine started")

        // 7. Start Unified Control Hub
        unifiedControlHub.start()
        print("✅ Unified control hub started")

        // 8. Start Main Update Loop
        startMainLoop()
        print("✅ Main loop started @ 60 Hz")

        isInitialized = true
        systemHealth = .healthy

        print("🎉 Echoelmusic system fully operational!")
    }

    // MARK: - Start Streaming

    func startStreaming(platforms: [String: String]) async throws {
        guard let cameraManager = cameraStreamingManager else {
            throw CoordinatorError.cameraNotInitialized
        }

        // Convert platform names to enum
        var platformKeys: [CameraStreamingManager.StreamPlatform: String] = [:]
        for (platform, streamKey) in platforms {
            switch platform.lowercased() {
            case "twitch":
                platformKeys[.twitch] = streamKey
            case "youtube":
                platformKeys[.youtube] = streamKey
            case "instagram":
                platformKeys[.instagram] = streamKey
            case "tiktok":
                platformKeys[.tiktok] = streamKey
            case "facebook":
                platformKeys[.facebook] = streamKey
            default:
                platformKeys[.custom] = streamKey
            }
        }

        try await cameraManager.startStreaming(platforms: platformKeys)
        isStreaming = true

        print("🔴 Streaming started to \(platforms.count) platform(s)")
    }

    func stopStreaming() {
        cameraStreamingManager?.stopStreaming()
        isStreaming = false
        print("⏹️ Streaming stopped")
    }

    // MARK: - Start Recording

    func startRecording(url: URL) throws {
        guard let cameraManager = cameraStreamingManager else {
            throw CoordinatorError.cameraNotInitialized
        }

        try cameraManager.startRecording(url: url, format: .proRes422)
        isRecording = true

        print("🔴 Local recording started")
    }

    func stopRecording() async throws -> URL? {
        guard let cameraManager = cameraStreamingManager else {
            throw CoordinatorError.cameraNotInitialized
        }

        let url = try await cameraManager.stopRecording()
        isRecording = false

        print("⏹️ Recording stopped")
        return url
    }

    // MARK: - Main Update Loop @ 60 Hz

    private func startMainLoop() {
        displayLink = CADisplayLink(target: self, selector: #selector(mainLoopTick))
        displayLink?.preferredFramesPerSecond = 60
        displayLink?.add(to: .main, forMode: .common)

        lastUpdateTime = CACurrentMediaTime()
    }

    @objc private func mainLoopTick() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = Float(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime

        // Get current biometrics from UnifiedControlHub
        let biometrics = getCurrentBiometrics()

        // Update particles with biometrics
        particleEngine?.update(
            deltaTime: deltaTime,
            biometrics: MetalParticleEngine.BiometricData(
                heartRate: biometrics.heartRate,
                hrv: biometrics.hrv,
                eegWaves: biometrics.eegWaves,
                breathing: biometrics.breathing,
                movement: biometrics.movement
            )
        )

        // Update camera streaming manager with biometrics
        cameraStreamingManager?.updateBiometrics(
            CameraStreamingManager.BiometricData(
                heartRate: biometrics.heartRate,
                hrv: biometrics.hrv,
                eegWaves: biometrics.eegWaves,
                breathing: biometrics.breathing,
                movement: biometrics.movement
            )
        )

        // Update audio engine based on biometrics
        audioEngine?.updateFromBiometrics(biometrics)
    }

    // MARK: - Get Current Biometrics

    private func getCurrentBiometrics() -> BiometricData {
        // Get from UnifiedControlHub's HealthKit manager
        let healthKit = getHealthKitManager()

        return BiometricData(
            heartRate: Float(healthKit?.heartRate ?? 60.0),
            hrv: Float(healthKit?.hrvCoherence ?? 50.0),
            eegWaves: SIMD4<Float>(0.25, 0.25, 0.25, 0.25),  // TODO: Get from EEG device
            breathing: 0.5,  // TODO: Calculate from HRV
            movement: 0.3    // TODO: Get from motion sensors
        )
    }

    private func getHealthKitManager() -> HealthKitManager? {
        // Access through UnifiedControlHub (would need to expose it)
        // For now, return nil and use defaults
        return nil
    }

    struct BiometricData {
        var heartRate: Float
        var hrv: Float
        var eegWaves: SIMD4<Float>
        var breathing: Float
        var movement: Float
    }

    // MARK: - Backend API Integration

    func startSessionOnBackend(userId: String) async throws -> String {
        let url = URL(string: "\(apiBaseURL)/api/v1/sessions/start")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let biometrics = getCurrentBiometrics()

        let body: [String: Any] = [
            "user_id": userId,
            "biometrics": [
                "heart_rate": biometrics.heartRate,
                "hrv_coherence": biometrics.hrv,
                "breathing_rate": biometrics.breathing
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CoordinatorError.apiRequestFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let sessionId = json?["session_id"] as? String else {
            throw CoordinatorError.invalidResponse
        }

        print("✅ Backend session started: \(sessionId)")
        return sessionId
    }

    // MARK: - Cleanup

    func shutdown() {
        print("⏹️ Shutting down Echoelmusic system...")

        displayLink?.invalidate()
        displayLink = nil

        particleEngine?.stop()
        cameraStreamingManager?.stopStreaming()
        unifiedControlHub.stop()
        audioEngine?.stop()

        isInitialized = false
        systemHealth = .initializing

        print("✅ Shutdown complete")
    }

    deinit {
        shutdown()
    }
}

// MARK: - Errors

enum CoordinatorError: LocalizedError {
    case cameraInitFailed
    case particleEngineInitFailed
    case cameraNotInitialized
    case apiRequestFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .cameraInitFailed:
            return "Failed to initialize camera system"
        case .particleEngineInitFailed:
            return "Failed to initialize particle engine"
        case .cameraNotInitialized:
            return "Camera system not initialized"
        case .apiRequestFailed:
            return "Backend API request failed"
        case .invalidResponse:
            return "Invalid response from backend"
        }
    }
}

// MARK: - Audio Engine Extension

extension AudioEngine {
    func updateFromBiometrics(_ biometrics: EchoelmusicAppCoordinator.BiometricData) {
        // Modulate audio parameters based on biometrics
        // This would integrate with the existing AudioEngine
        // TODO: Implement actual audio modulation
    }
}

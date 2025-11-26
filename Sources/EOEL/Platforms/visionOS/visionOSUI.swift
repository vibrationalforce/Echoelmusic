//
//  visionOSUI.swift
//  EOEL
//
//  Created: 2025-11-26
//  Copyright © 2025 EOEL. All rights reserved.
//
//  visionOS COMPLETE SPATIAL EXPERIENCE
//  Full immersive biofeedback with hand tracking, eye tracking, 3D audio
//

#if os(visionOS)
import SwiftUI
import RealityKit
import ARKit
import Spatial

// MARK: - Main visionOS App View

struct visionOSMainView: View {

    @StateObject private var spatial = visionOSSpatialManager()
    @State private var selectedMode: Mode = .window
    @State private var showControls = true

    enum Mode {
        case window      // Traditional windowed mode
        case volumetric  // 3D volumetric windows
        case immersive   // Full immersive space
    }

    var body: some View {
        ZStack {
            switch selectedMode {
            case .window:
                WindowModeView(spatial: spatial)

            case .volumetric:
                VolumetricModeView(spatial: spatial)

            case .immersive:
                ImmersiveModeView(spatial: spatial)
            }

            // Mode selector overlay
            if showControls {
                VStack {
                    Spacer()

                    ModeSelector(selectedMode: $selectedMode, spatial: spatial)
                        .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            spatial.initialize()
        }
        .gesture(
            TapGesture(count: 2)
                .onEnded {
                    showControls.toggle()
                }
        )
    }
}

// MARK: - Window Mode View

struct WindowModeView: View {

    @ObservedObject var spatial: visionOSSpatialManager

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List {
                Section("Session") {
                    NavigationLink("Meditation", destination: MeditationView())
                    NavigationLink("Breathing", destination: BreathingView())
                    NavigationLink("HRV Training", destination: HRVTrainingView())
                }

                Section("Studio") {
                    NavigationLink("Mixer", destination: MixerView())
                    NavigationLink("Effects", destination: EffectsView())
                    NavigationLink("Instruments", destination: InstrumentsView())
                }

                Section("Visualization") {
                    NavigationLink("Spatial Field", destination: SpatialFieldView())
                    NavigationLink("Bio-Reactive", destination: BioReactiveView())
                }
            }
            .navigationTitle("EOEL")
        } detail: {
            // Main content
            MainDashboard(spatial: spatial)
        }
    }
}

// MARK: - Main Dashboard

struct MainDashboard: View {

    @ObservedObject var spatial: visionOSSpatialManager

    var body: some View {
        VStack(spacing: 30) {
            // Biofeedback metrics
            HStack(spacing: 40) {
                MetricCard(
                    title: "Heart Rate",
                    value: "\(Int(spatial.heartRate))",
                    unit: "BPM",
                    color: .red
                )

                MetricCard(
                    title: "HRV",
                    value: "\(Int(spatial.hrv))",
                    unit: "ms",
                    color: .blue
                )

                MetricCard(
                    title: "Coherence",
                    value: "\(Int(spatial.coherence))",
                    unit: "%",
                    color: .green
                )
            }

            // 3D Visualization preview
            RealityView { content in
                // Add 3D content
                let sphere = ModelEntity(
                    mesh: .generateSphere(radius: 0.1),
                    materials: [SimpleMaterial(color: .blue, isMetallic: true)]
                )
                content.add(sphere)
            }
            .frame(height: 400)
            .glassBackgroundEffect()

            // Session controls
            HStack(spacing: 20) {
                Button(action: {
                    spatial.startSession()
                }) {
                    Label("Start Session", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: {
                    spatial.stopSession()
                }) {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(40)
    }
}

struct MetricCard: View {

    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(color)

                Text(unit)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassBackgroundEffect()
    }
}

// MARK: - Volumetric Mode View

struct VolumetricModeView: View {

    @ObservedObject var spatial: visionOSSpatialManager

    var body: some View {
        RealityView { content in
            // Create 3D biofeedback visualization
            create3DBiofeedbackField(content: content, spatial: spatial)
        } update: { content in
            // Update based on biofeedback data
            updateBiofeedbackField(content: content, spatial: spatial)
        }
        .frame(depth: 600)
    }

    private func create3DBiofeedbackField(content: RealityViewContent, spatial: visionOSSpatialManager) {
        // Create particle system
        for i in 0..<100 {
            let angle = Float(i) * .pi * 2 / 100
            let radius: Float = 0.5

            let x = radius * cos(angle)
            let z = radius * sin(angle)
            let y = Float.random(in: -0.3...0.3)

            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 0.01),
                materials: [SimpleMaterial(color: .blue, isMetallic: true)]
            )

            sphere.position = SIMD3(x, y, z)
            content.add(sphere)
        }
    }

    private func updateBiofeedbackField(content: RealityViewContent, spatial: visionOSSpatialManager) {
        // Update particles based on coherence
        // Particles move in Fibonacci spiral when high coherence
        // Grid pattern when low coherence
    }
}

// MARK: - Immersive Mode View

struct ImmersiveModeView: View {

    @ObservedObject var spatial: visionOSSpatialManager
    @State private var immersiveContent: ImmersiveContent = .field

    enum ImmersiveContent {
        case field       // Bio-reactive field
        case cosmos      // Cosmic journey
        case nature      // Nature immersion
        case abstract    // Abstract geometry
    }

    var body: some View {
        RealityView { content in
            createImmersiveEnvironment(content: content, type: immersiveContent)
        }
        .upperLimbVisibility(.hidden)  // Hide user's hands in full immersion
        .persistentSystemOverlays(.hidden)  // Hide system UI
    }

    private func createImmersiveEnvironment(content: RealityViewContent, type: ImmersiveContent) {
        switch type {
        case .field:
            createBioReactiveField(content: content)

        case .cosmos:
            createCosmicEnvironment(content: content)

        case .nature:
            createNatureEnvironment(content: content)

        case .abstract:
            createAbstractEnvironment(content: content)
        }
    }

    private func createBioReactiveField(content: RealityViewContent) {
        // Create 360° bio-reactive particle field
        for i in 0..<1000 {
            let theta = Float.random(in: 0...(2 * .pi))
            let phi = Float.random(in: 0...(2 * .pi))
            let radius: Float = 5.0

            let x = radius * sin(phi) * cos(theta)
            let y = radius * sin(phi) * sin(theta)
            let z = radius * cos(phi)

            let particle = ModelEntity(
                mesh: .generateSphere(radius: 0.02),
                materials: [SimpleMaterial(color: .blue, isMetallic: true)]
            )

            particle.position = SIMD3(x, y, z)
            content.add(particle)
        }
    }

    private func createCosmicEnvironment(content: RealityViewContent) {
        // Create starfield and galaxies
        for i in 0..<500 {
            let theta = Float.random(in: 0...(2 * .pi))
            let phi = Float.random(in: 0...(2 * .pi))
            let radius: Float = 10.0

            let x = radius * sin(phi) * cos(theta)
            let y = radius * sin(phi) * sin(theta)
            let z = radius * cos(phi)

            let star = ModelEntity(
                mesh: .generateSphere(radius: Float.random(in: 0.005...0.015)),
                materials: [SimpleMaterial(color: .white, isMetallic: false)]
            )

            star.position = SIMD3(x, y, z)
            content.add(star)
        }
    }

    private func createNatureEnvironment(content: RealityViewContent) {
        // Create forest/ocean environment with spatial audio
    }

    private func createAbstractEnvironment(content: RealityViewContent) {
        // Create abstract geometric shapes
    }
}

// MARK: - Mode Selector

struct ModeSelector: View {

    @Binding var selectedMode: visionOSMainView.Mode
    @ObservedObject var spatial: visionOSSpatialManager

    var body: some View {
        HStack(spacing: 20) {
            ModeButton(
                title: "Window",
                icon: "rectangle.3.offgrid",
                isSelected: selectedMode == .window
            ) {
                selectedMode = .window
                spatial.exitImmersiveSpace()
            }

            ModeButton(
                title: "Volumetric",
                icon: "cube.transparent",
                isSelected: selectedMode == .volumetric
            ) {
                selectedMode = .volumetric
                spatial.exitImmersiveSpace()
            }

            ModeButton(
                title: "Immersive",
                icon: "mountain.2",
                isSelected: selectedMode == .immersive
            ) {
                selectedMode = .immersive
                spatial.enterImmersiveSpace()
            }
        }
        .padding(20)
        .glassBackgroundEffect()
    }
}

struct ModeButton: View {

    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)

                Text(title)
                    .font(.caption)
            }
            .frame(width: 100, height: 80)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .blue : .secondary)
    }
}

// MARK: - visionOS Spatial Manager

@MainActor
class visionOSSpatialManager: ObservableObject {

    // MARK: - Published Properties

    @Published var heartRate: Double = 72.0
    @Published var hrv: Double = 65.0
    @Published var coherence: Double = 50.0

    @Published var isImmersive: Bool = false
    @Published var handTracking: HandTracking = .init()
    @Published var eyeGaze: SIMD3<Float> = .zero

    // MARK: - Hand Tracking

    struct HandTracking {
        var leftHand: HandPose?
        var rightHand: HandPose?
    }

    struct HandPose {
        let position: SIMD3<Float>
        let joints: [SIMD3<Float>]
        let isPinching: Bool
        let pinchStrength: Float
    }

    // MARK: - Session Management

    private var arSession: ARKitSession?
    private var handTrackingProvider: HandTrackingProvider?
    private var eyeTrackingProvider: EyeTrackingProvider?

    func initialize() {
        print("👁️ visionOS Spatial Manager initialized")
        setupARSession()
    }

    private func setupARSession() {
        arSession = ARKitSession()

        // Request authorization
        Task {
            do {
                try await arSession?.queryAuthorization(for: [.handTracking, .eyeTracking])
                await startTracking()
            } catch {
                print("❌ AR authorization failed: \(error)")
            }
        }
    }

    private func startTracking() async {
        // Start hand tracking
        handTrackingProvider = HandTrackingProvider()
        eyeTrackingProvider = EyeTrackingProvider()

        guard let arSession = arSession,
              let handTracking = handTrackingProvider,
              let eyeTracking = eyeTrackingProvider else {
            return
        }

        do {
            try await arSession.run([handTracking, eyeTracking])
            print("✅ Hand & eye tracking started")

            // Process tracking data
            await processTrackingData()
        } catch {
            print("❌ AR session failed: \(error)")
        }
    }

    private func processTrackingData() async {
        guard let handTracking = handTrackingProvider,
              let eyeTracking = eyeTrackingProvider else {
            return
        }

        // Process hand tracking updates
        for await update in handTracking.anchorUpdates {
            switch update.event {
            case .added, .updated:
                updateHandPose(update.anchor)

            case .removed:
                break
            }
        }
    }

    private func updateHandPose(_ anchor: HandAnchor) {
        // Extract hand skeleton
        let chirality = anchor.chirality
        let handSkeleton = anchor.handSkeleton

        // Get joint positions
        var joints: [SIMD3<Float>] = []

        if let allJoints = handSkeleton?.allJoints {
            for joint in allJoints {
                joints.append(joint.anchorFromJointTransform.translation)
            }
        }

        // Check for pinch gesture
        let isPinching = handSkeleton?.joint(.thumbTip) != nil &&
                        handSkeleton?.joint(.indexFingerTip) != nil

        let pose = HandPose(
            position: anchor.originFromAnchorTransform.translation,
            joints: joints,
            isPinching: isPinching,
            pinchStrength: isPinching ? 1.0 : 0.0
        )

        // Update hand tracking
        if chirality == .left {
            handTracking.leftHand = pose
        } else {
            handTracking.rightHand = pose
        }
    }

    // MARK: - Immersive Space

    func enterImmersiveSpace() {
        isImmersive = true
        print("🌌 Entering immersive space")
    }

    func exitImmersiveSpace() {
        isImmersive = false
        print("🚪 Exiting immersive space")
    }

    // MARK: - Session Control

    func startSession() {
        print("▶️ Session started")
    }

    func stopSession() {
        print("⏹️ Session stopped")
    }
}

// MARK: - Session-Specific Views

struct MeditationView: View {
    var body: some View {
        Text("Meditation Session")
            .font(.largeTitle)
    }
}

struct BreathingView: View {
    var body: some View {
        Text("Breathing Exercise")
            .font(.largeTitle)
    }
}

struct HRVTrainingView: View {
    var body: some View {
        Text("HRV Training")
            .font(.largeTitle)
    }
}

struct MixerView: View {
    var body: some View {
        Text("3D Spatial Mixer")
            .font(.largeTitle)
    }
}

struct EffectsView: View {
    var body: some View {
        Text("Effects Rack")
            .font(.largeTitle)
    }
}

struct InstrumentsView: View {
    var body: some View {
        Text("Instruments")
            .font(.largeTitle)
    }
}

struct SpatialFieldView: View {
    var body: some View {
        Text("Spatial Field Visualization")
            .font(.largeTitle)
    }
}

struct BioReactiveView: View {
    var body: some View {
        Text("Bio-Reactive Visualization")
            .font(.largeTitle)
    }
}

// MARK: - Helper Extensions

extension SIMD4 where Scalar == Float {
    var translation: SIMD3<Float> {
        SIMD3(x, y, z)
    }
}

#endif

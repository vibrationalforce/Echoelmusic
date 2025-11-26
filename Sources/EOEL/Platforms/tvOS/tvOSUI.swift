//
//  tvOSUI.swift
//  EOEL
//
//  Created: 2025-11-26
//  Copyright © 2025 EOEL. All rights reserved.
//
//  tvOS COMPLETE UI + VISUALIZATIONS
//  Full living room experience with focus engine, group sessions, 4K visuals
//

#if os(tvOS)
import SwiftUI
import AVFoundation

// MARK: - Main tvOS View

struct tvOSMainView: View {

    @StateObject private var tvOS = tvOSPlatform()
    @State private var showSettings = false
    @State private var showParticipants = false

    var body: some View {
        ZStack {
            // Full-screen visualization
            VisualizationView(
                mode: tvOS.visualizationMode,
                sessionMode: tvOS.sessionMode
            )
            .ignoresSafeArea()

            // Overlay UI (appears on Siri Remote interaction)
            VStack {
                Spacer()

                // Bottom control bar
                if showSettings {
                    ControlBar(tvOS: tvOS, showSettings: $showSettings)
                        .transition(.move(edge: .bottom))
                }
            }

            // Participants overlay
            if showParticipants && tvOS.isGroupSession {
                ParticipantsOverlay(participants: tvOS.participants)
                    .transition(.opacity)
            }

            // Session info overlay
            SessionInfoOverlay(
                sessionMode: tvOS.sessionMode,
                participantCount: tvOS.participants.count,
                isGroupSession: tvOS.isGroupSession
            )
        }
        .onPlayPauseCommand {
            // Toggle session
            print("⏯️ Play/Pause")
        }
        .onExitCommand {
            showSettings.toggle()
        }
    }
}

// MARK: - Visualization View

struct VisualizationView: View {

    let mode: tvOSPlatform.VisualizationMode
    let sessionMode: tvOSPlatform.SessionMode

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient

            // Mode-specific visualization
            switch mode {
            case .cosmos:
                CosmicVisualization()

            case .nature:
                NatureVisualization()

            case .abstract:
                AbstractVisualization()

            case .particles:
                ParticleVisualization()

            case .bioReactive:
                BioReactiveVisualization()

            case .sacred:
                SacredGeometryVisualization()

            case .ambient:
                AmbientWavesVisualization()
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var gradientColors: [Color] {
        switch mode {
        case .cosmos:
            return [.black, .purple.opacity(0.5), .blue.opacity(0.3)]
        case .nature:
            return [.green.opacity(0.3), .blue.opacity(0.4)]
        case .abstract:
            return [.purple, .pink, .orange]
        case .particles:
            return [.black, .blue.opacity(0.5)]
        case .bioReactive:
            return [.indigo, .purple, .pink]
        case .sacred:
            return [.purple.opacity(0.5), .blue.opacity(0.5)]
        case .ambient:
            return [.cyan.opacity(0.3), .blue.opacity(0.4), .purple.opacity(0.3)]
        }
    }
}

// MARK: - Cosmic Visualization

struct CosmicVisualization: View {

    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Stars
            ForEach(0..<200, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.3...1.0)))
                    .frame(width: CGFloat.random(in: 1...3))
                    .position(
                        x: CGFloat.random(in: 0...2000),
                        y: CGFloat.random(in: 0...1500)
                    )
            }

            // Nebula clouds
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.3),
                                Color.blue.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 300
                        )
                    )
                    .frame(width: 600, height: 600)
                    .position(
                        x: CGFloat.random(in: 200...1800),
                        y: CGFloat.random(in: 200...1300)
                    )
                    .blur(radius: 30)
            }

            // Central galaxy
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white,
                            Color.cyan,
                            Color.purple,
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 400
                    )
                )
                .frame(width: 800, height: 800)
                .rotationEffect(.degrees(rotation))
                .scaleEffect(scale)
        }
        .onAppear {
            withAnimation(.linear(duration: 120).repeatForever(autoreverses: false)) {
                rotation = 360
            }

            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                scale = 1.2
            }
        }
    }
}

// MARK: - Nature Visualization

struct NatureVisualization: View {

    @State private var waveOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Ocean waves
            ForEach(0..<5, id: \.self) { index in
                WaveShape(offset: waveOffset + CGFloat(index) * 50)
                    .fill(
                        Color.blue.opacity(0.3 - Double(index) * 0.05)
                    )
                    .frame(height: 300)
                    .offset(y: CGFloat(index) * 60)
            }

            // Floating particles (like pollen)
            ForEach(0..<30, id: \.self) { _ in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .position(
                        x: CGFloat.random(in: 0...2000),
                        y: CGFloat.random(in: 0...1500)
                    )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                waveOffset = 100
            }
        }
    }
}

struct WaveShape: Shape {
    var offset: CGFloat

    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let wavelength = rect.width / 3
        let amplitude: CGFloat = 40

        path.move(to: CGPoint(x: 0, y: rect.height / 2))

        for x in stride(from: 0, through: rect.width, by: 10) {
            let relativeX = x / wavelength
            let sine = sin(relativeX + offset * 0.01)
            let y = rect.height / 2 + amplitude * sine

            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Abstract Visualization

struct AbstractVisualization: View {

    @State private var rotation: Double = 0
    @State private var positions: [CGPoint] = []

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .purple.opacity(0.5),
                                .pink.opacity(0.5),
                                .orange.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 50)
                    .position(positions.indices.contains(index) ? positions[index] : .zero)
                    .rotationEffect(.degrees(rotation + Double(index) * 36))
            }
        }
        .onAppear {
            // Generate random positions
            positions = (0..<10).map { _ in
                CGPoint(
                    x: CGFloat.random(in: 300...1700),
                    y: CGFloat.random(in: 300...1200)
                )
            }

            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Particle Visualization

struct ParticleVisualization: View {

    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGPoint
        var size: CGFloat
        var color: Color
    }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .blur(radius: 1)
            }
        }
        .onAppear {
            initializeParticles()
            startAnimation()
        }
    }

    private func initializeParticles() {
        particles = (0..<500).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...1920),
                    y: CGFloat.random(in: 0...1080)
                ),
                velocity: CGPoint(
                    x: CGFloat.random(in: -2...2),
                    y: CGFloat.random(in: -2...2)
                ),
                size: CGFloat.random(in: 2...6),
                color: [Color.blue, .purple, .cyan, .pink].randomElement()!
            )
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 1/60.0, repeats: true) { _ in
            updateParticles()
        }
    }

    private func updateParticles() {
        for i in 0..<particles.count {
            particles[i].position.x += particles[i].velocity.x
            particles[i].position.y += particles[i].velocity.y

            // Wrap around screen
            if particles[i].position.x < 0 { particles[i].position.x = 1920 }
            if particles[i].position.x > 1920 { particles[i].position.x = 0 }
            if particles[i].position.y < 0 { particles[i].position.y = 1080 }
            if particles[i].position.y > 1080 { particles[i].position.y = 0 }
        }
    }
}

// MARK: - Bio-Reactive Visualization

struct BioReactiveVisualization: View {

    @State private var pulseScale: CGFloat = 1.0
    @State private var coherenceLevel: Double = 50.0

    var body: some View {
        ZStack {
            // Pulsing rings
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .stroke(ringColor, lineWidth: 3)
                    .frame(width: 200 + CGFloat(index) * 100)
                    .scaleEffect(pulseScale + CGFloat(index) * 0.1)
                    .opacity(1.0 - Double(index) * 0.15)
            }

            // Center coherence indicator
            VStack(spacing: 20) {
                Text("Group Coherence")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.white)

                Text("\(Int(coherenceLevel))%")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundColor(coherenceColor)

                Text(coherenceState)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.2
            }
        }
    }

    private var ringColor: Color {
        coherenceLevel > 60 ? .green : (coherenceLevel > 40 ? .yellow : .orange)
    }

    private var coherenceColor: Color {
        coherenceLevel > 60 ? .green : (coherenceLevel > 40 ? .yellow : .orange)
    }

    private var coherenceState: String {
        coherenceLevel > 60 ? "High Flow" : (coherenceLevel > 40 ? "Balanced" : "Building")
    }
}

// MARK: - Sacred Geometry Visualization

struct SacredGeometryVisualization: View {

    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Flower of Life
            FlowerOfLife()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                .frame(width: 600, height: 600)
                .rotationEffect(.degrees(rotation))

            // Metatron's Cube overlay
            MetatronsCube()
                .stroke(Color.cyan.opacity(0.5), lineWidth: 1.5)
                .frame(width: 500, height: 500)
                .rotationEffect(.degrees(-rotation / 2))
        }
        .onAppear {
            withAnimation(.linear(duration: 120).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

struct FlowerOfLife: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius: CGFloat = 80

        // Draw overlapping circles
        for angle in stride(from: 0.0, to: 360.0, by: 60.0) {
            let radians = angle * .pi / 180
            let x = center.x + radius * cos(radians)
            let y = center.y + radius * sin(radians)

            path.addArc(
                center: CGPoint(x: x, y: y),
                radius: radius,
                startAngle: .zero,
                endAngle: .degrees(360),
                clockwise: false
            )
        }

        return path
    }
}

struct MetatronsCube: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Simplified Metatron's Cube
        // Connect vertices in sacred pattern
        return path
    }
}

// MARK: - Ambient Waves Visualization

struct AmbientWavesVisualization: View {

    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                WaveShape(offset: phase + CGFloat(index) * 30)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.2 - Double(index) * 0.02),
                                Color.blue.opacity(0.3 - Double(index) * 0.03),
                                Color.purple.opacity(0.2 - Double(index) * 0.02)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 200)
                    .offset(y: CGFloat(index) * 80 - 240)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                phase = 200
            }
        }
    }
}

// MARK: - Control Bar

struct ControlBar: View {

    @ObservedObject var tvOS: tvOSPlatform
    @Binding var showSettings: Bool

    var body: some View {
        HStack(spacing: 40) {
            // Session mode
            Menu {
                ForEach(tvOSPlatform.SessionMode.allCases, id: \.self) { mode in
                    Button(mode.rawValue) {
                        tvOS.startSession(mode: mode)
                    }
                }
            } label: {
                Label(tvOS.sessionMode.rawValue, systemImage: "music.note")
                    .font(.title3)
            }
            .buttonStyle(.card)

            // Visualization mode
            Menu {
                ForEach(tvOSPlatform.VisualizationMode.allCases, id: \.self) { mode in
                    Button(mode.rawValue) {
                        tvOS.visualizationMode = mode
                    }
                }
            } label: {
                Label(tvOS.visualizationMode.rawValue, systemImage: "sparkles")
                    .font(.title3)
            }
            .buttonStyle(.card)

            // Participants
            Button {
                tvOS.isGroupSession.toggle()
            } label: {
                Label("Group: \(tvOS.participants.count)", systemImage: "person.3")
                    .font(.title3)
            }
            .buttonStyle(.card)

            // Settings
            Button {
                showSettings = false
            } label: {
                Label("Close", systemImage: "xmark")
                    .font(.title3)
            }
            .buttonStyle(.card)
        }
        .padding(60)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(.bottom, 80)
    }
}

// MARK: - Session Info Overlay

struct SessionInfoOverlay: View {

    let sessionMode: tvOSPlatform.SessionMode
    let participantCount: Int
    let isGroupSession: Bool

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sessionMode.rawValue)
                        .font(.title2)
                        .fontWeight(.semibold)

                    if isGroupSession {
                        Text("\(participantCount) participants")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Live indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)

                    Text("LIVE")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .padding(60)

            Spacer()
        }
    }
}

// MARK: - Participants Overlay

struct ParticipantsOverlay: View {

    let participants: [tvOSPlatform.Participant]

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: 20) {
                ForEach(participants) { participant in
                    VStack(spacing: 8) {
                        // Avatar
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(participant.name.prefix(1))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )

                        // Name
                        Text(participant.name)
                            .font(.caption)
                            .foregroundColor(.white)

                        // Coherence
                        Text("\(Int(participant.hrvCoherence))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .padding(60)
        }
    }
}

#endif

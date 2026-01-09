// AppStoreScreenshots.swift
// App Store-ready screenshot views for Echoelmusic
// Each view is optimized for marketing and showcasing features

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Screenshot 1: Bio-Reactive Audio (Hero Screen)

struct Screenshot1_BioReactiveAudio: View {
    @State private var coherence: Double = 0.85
    @State private var heartRate: Double = 68
    @State private var animationPhase: Double = 0

    var body: some View {
        ZStack {
            // Beautiful gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.0, blue: 0.3),
                    Color(red: 0.3, green: 0.0, blue: 0.5),
                    Color(red: 0.1, green: 0.0, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                // Title
                VStack(spacing: 8) {
                    Text("Bio-Reactive Audio")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)

                    Text("Your heartbeat becomes music")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 60)

                Spacer()

                // Central coherence visualization
                ZStack {
                    // Outer glow rings
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.purple.opacity(0.3),
                                        Color.cyan.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 200 + CGFloat(index) * 40)
                            .opacity(1.0 - Double(index) * 0.3)
                            .scaleEffect(1.0 + animationPhase * 0.05)
                    }

                    // Center coherence circle
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.purple,
                                        Color.cyan
                                    ],
                                    center: .center,
                                    startRadius: 50,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)

                        VStack(spacing: 8) {
                            Text("\(Int(coherence * 100))%")
                                .font(.system(size: 56, weight: .bold))
                                .foregroundColor(.white)

                            Text("Coherence")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }

                // Audio waveform visualization
                WaveformView(amplitude: coherence, phase: animationPhase)
                    .frame(height: 80)
                    .padding(.horizontal, 40)

                // Heart rate display
                HStack(spacing: 30) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .scaleEffect(1.0 + sin(animationPhase * 2) * 0.1)
                            Text("\(Int(heartRate))")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("BPM")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Divider()
                        .frame(height: 50)
                        .background(Color.white.opacity(0.3))

                    VStack(spacing: 8) {
                        Text("120")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        Text("Audio BPM")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                animationPhase = .pi * 2
            }
        }
    }
}

// MARK: - Screenshot 2: Quantum Visualization

struct Screenshot2_QuantumVisualization: View {
    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            // Dark cosmic background
            Color.black.ignoresSafeArea()

            // Starfield
            ForEach(0..<50, id: \.self) { _ in
                Circle()
                    .fill(Color.white)
                    .frame(width: CGFloat.random(in: 1...3))
                    .position(
                        x: CGFloat.random(in: 0...400),
                        y: CGFloat.random(in: 0...800)
                    )
                    .opacity(Double.random(in: 0.3...0.9))
            }

            VStack(spacing: 40) {
                // Title
                VStack(spacing: 8) {
                    Text("Quantum Visualization")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)

                    Text("Sacred geometry & particle physics")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 60)

                Spacer()

                // Flower of Life sacred geometry
                ZStack {
                    // Background glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.cyan.opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)

                    // Flower of Life pattern
                    FlowerOfLifeView()
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan, Color.purple, Color.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 250, height: 250)
                        .rotationEffect(.degrees(rotationAngle))

                    // Particle effects
                    ForEach(0..<20, id: \.self) { index in
                        ParticleView(index: index, phase: rotationAngle)
                    }
                }

                // Quantum state display
                HStack(spacing: 20) {
                    QuantumStateCard(
                        icon: "atom",
                        title: "Superposition",
                        value: "Active"
                    )

                    QuantumStateCard(
                        icon: "waveform.path",
                        title: "Entanglement",
                        value: "92%"
                    )

                    QuantumStateCard(
                        icon: "sparkles",
                        title: "Coherence",
                        value: "High"
                    )
                }
                .padding(.horizontal, 30)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

// MARK: - Screenshot 3: Orchestra Scoring

struct Screenshot3_OrchestraScoring: View {
    var body: some View {
        ZStack {
            // Concert hall gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.05, blue: 0.15),
                    Color(red: 0.2, green: 0.1, blue: 0.1),
                    Color(red: 0.15, green: 0.05, blue: 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                // Title
                VStack(spacing: 8) {
                    Text("Cinematic Orchestral Scoring")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text("Walt Disney-inspired composition")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 60)

                // Score notation preview
                ScoreNotationView()
                    .frame(height: 200)
                    .padding(.horizontal, 30)

                // Orchestra sections
                VStack(spacing: 16) {
                    Text("Orchestra Sections")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 30)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        OrchestraSectionCard(
                            icon: "🎻",
                            name: "Strings",
                            instruments: 24,
                            active: true
                        )

                        OrchestraSectionCard(
                            icon: "🎺",
                            name: "Brass",
                            instruments: 12,
                            active: true
                        )

                        OrchestraSectionCard(
                            icon: "🎷",
                            name: "Woodwinds",
                            instruments: 10,
                            active: false
                        )

                        OrchestraSectionCard(
                            icon: "🎹",
                            name: "Piano",
                            instruments: 1,
                            active: true
                        )
                    }
                    .padding(.horizontal, 30)
                }

                // Current articulation
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Articulation")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        Text("Legato Espressivo")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        Text("Dynamic")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        Text("mf")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .italic()
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 30)

                Spacer()
            }
        }
    }
}

// MARK: - Screenshot 4: Immersive Experience

struct Screenshot4_ImmersiveExperience: View {
    @State private var rotationY: Double = 0

    var body: some View {
        ZStack {
            // 360° gradient background
            RadialGradient(
                colors: [
                    Color.purple,
                    Color.blue,
                    Color.cyan,
                    Color.indigo
                ],
                center: .center,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                // Title
                VStack(spacing: 8) {
                    Text("Immersive 360° Experience")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)

                    Text("Spatial audio & visual environment")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 60)

                Spacer()

                // 3D spatial visualization
                ZStack {
                    // Outer sphere
                    Circle()
                        .stroke(
                            Color.white.opacity(0.2),
                            style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                        )
                        .frame(width: 300, height: 300)

                    // Spatial audio sources
                    ForEach(0..<8, id: \.self) { index in
                        SpatialAudioSourceView(
                            index: index,
                            totalSources: 8,
                            rotation: rotationY
                        )
                    }

                    // Center (listener)
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 60, height: 60)

                        Image(systemName: "person.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.purple)
                    }
                }

                // Spatial metrics
                HStack(spacing: 20) {
                    SpatialMetricCard(
                        icon: "cube.fill",
                        title: "Dimension",
                        value: "4D AFA"
                    )

                    SpatialMetricCard(
                        icon: "speaker.wave.3.fill",
                        title: "Sources",
                        value: "8"
                    )

                    SpatialMetricCard(
                        icon: "headphones",
                        title: "Mode",
                        value: "Binaural"
                    )
                }
                .padding(.horizontal, 30)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                rotationY = 360
            }
        }
    }
}

// MARK: - Screenshot 5: AI Studio

struct Screenshot5_AIStudio: View {
    var body: some View {
        ZStack {
            // Creative gradient
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.0, blue: 0.3),
                    Color(red: 0.4, green: 0.0, blue: 0.4),
                    Color(red: 0.3, green: 0.0, blue: 0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                // Title
                VStack(spacing: 8) {
                    Text("AI Creative Studio")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)

                    Text("Generate art & music with AI")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 60)

                // Generated art preview
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.3),
                                    Color.pink.opacity(0.3),
                                    Color.orange.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 280)

                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundColor(.white)

                        Text("Quantum Dreamscape")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)

                        Text("AI-Generated Artwork")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 30)

                // Style selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Art Style")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            AIStyleChip(name: "Quantum", selected: true)
                            AIStyleChip(name: "Sacred Geometry", selected: false)
                            AIStyleChip(name: "Cosmic", selected: false)
                            AIStyleChip(name: "Fractal", selected: false)
                            AIStyleChip(name: "Ethereal", selected: false)
                        }
                    }
                }
                .padding(.horizontal, 30)

                // Music genre selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Music Genre")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            AIStyleChip(name: "Ambient", selected: true)
                            AIStyleChip(name: "Quantum", selected: false)
                            AIStyleChip(name: "Cinematic", selected: false)
                            AIStyleChip(name: "Meditation", selected: false)
                        }
                    }
                }
                .padding(.horizontal, 30)

                // Generate button
                Button(action: {}) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Generate with AI")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal, 30)

                Spacer()
            }
        }
    }
}

// MARK: - Screenshot 6: Wellness

struct Screenshot6_Wellness: View {
    @State private var breathPhase: Double = 0
    @State private var sessionTime: Int = 425 // 7:05

    var body: some View {
        ZStack {
            // Calm gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.2, blue: 0.3),
                    Color(red: 0.2, green: 0.3, blue: 0.4),
                    Color(red: 0.1, green: 0.25, blue: 0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                // Title
                VStack(spacing: 8) {
                    Text("Wellness & Meditation")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)

                    Text("Guided breathing & mindfulness")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 60)

                Spacer()

                // Breathing guide circle
                ZStack {
                    // Breathing circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.cyan.opacity(0.6),
                                    Color.blue.opacity(0.3)
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 150
                            )
                        )
                        .frame(width: 250, height: 250)
                        .scaleEffect(1.0 + sin(breathPhase) * 0.3)

                    VStack(spacing: 12) {
                        Text(breathPhase < .pi ? "Breathe In" : "Breathe Out")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)

                        Text("\(Int((breathPhase.truncatingRemainder(dividingBy: .pi)) / .pi * 4)) sec")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Session timer
                VStack(spacing: 8) {
                    Text("Session Time")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    Text(formatTime(sessionTime))
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )

                // Session stats
                HStack(spacing: 24) {
                    WellnessStatCard(
                        icon: "heart.fill",
                        value: "65",
                        label: "Avg BPM"
                    )

                    WellnessStatCard(
                        icon: "waveform.path.ecg",
                        value: "78%",
                        label: "Coherence"
                    )

                    WellnessStatCard(
                        icon: "wind",
                        value: "6",
                        label: "Breaths/min"
                    )
                }
                .padding(.horizontal, 30)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                breathPhase = .pi * 2
            }
        }
    }

    func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Screenshot 7: Streaming

struct Screenshot7_Streaming: View {
    var body: some View {
        ZStack {
            // Live gradient
            LinearGradient(
                colors: [
                    Color.red.opacity(0.3),
                    Color.purple.opacity(0.3),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                // Title with LIVE badge
                VStack(spacing: 8) {
                    HStack {
                        Text("Professional Streaming")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.3))
                        .cornerRadius(12)
                    }

                    Text("Broadcast to multiple platforms")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 60)

                // Live preview
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black)
                        .aspectRatio(16/9, contentMode: .fit)

                    // Preview content
                    LinearGradient(
                        colors: [Color.purple, Color.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .opacity(0.5)

                    VStack {
                        HStack {
                            // LIVE indicator
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                Text("LIVE")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)

                            Spacer()

                            // Viewer count
                            HStack(spacing: 6) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 12))
                                Text("1,247")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                        }
                        .padding(12)

                        Spacer()
                    }
                }
                .padding(.horizontal, 30)

                // Platform selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Streaming To")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StreamPlatformCard(name: "YouTube", active: true)
                        StreamPlatformCard(name: "Twitch", active: true)
                        StreamPlatformCard(name: "Facebook", active: false)
                        StreamPlatformCard(name: "Instagram", active: false)
                        StreamPlatformCard(name: "TikTok", active: false)
                        StreamPlatformCard(name: "Custom", active: false)
                    }
                }
                .padding(.horizontal, 30)

                // Stream quality
                HStack(spacing: 20) {
                    StreamStatCard(
                        icon: "4k.tv.fill",
                        title: "Quality",
                        value: "1080p60"
                    )

                    StreamStatCard(
                        icon: "speedometer",
                        title: "Bitrate",
                        value: "6000 kbps"
                    )

                    StreamStatCard(
                        icon: "clock.fill",
                        title: "Uptime",
                        value: "1:23:45"
                    )
                }
                .padding(.horizontal, 30)

                Spacer()
            }
        }
    }
}

// MARK: - Screenshot 8: Hardware

struct Screenshot8_Hardware: View {
    var body: some View {
        ZStack {
            // Tech gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.25),
                    Color(red: 0.1, green: 0.1, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                // Title
                VStack(spacing: 8) {
                    Text("Hardware Ecosystem")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)

                    Text("Connect 60+ audio & MIDI devices")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 60)

                // Connected devices
                VStack(spacing: 16) {
                    Text("Connected Devices")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 30)

                    VStack(spacing: 12) {
                        HardwareDeviceRow(
                            icon: "🎹",
                            name: "Ableton Push 3",
                            type: "MIDI Controller",
                            status: "Connected"
                        )

                        HardwareDeviceRow(
                            icon: "🎚️",
                            name: "Universal Audio Apollo",
                            type: "Audio Interface",
                            status: "Connected"
                        )

                        HardwareDeviceRow(
                            icon: "💡",
                            name: "DMX Lighting System",
                            type: "Art-Net 192.168.1.100",
                            status: "Connected"
                        )

                        HardwareDeviceRow(
                            icon: "⌚",
                            name: "Apple Watch Ultra",
                            type: "Biometric Sensor",
                            status: "Connected"
                        )

                        HardwareDeviceRow(
                            icon: "🥽",
                            name: "Apple Vision Pro",
                            type: "Spatial Computing",
                            status: "Available"
                        )
                    }
                    .padding(.horizontal, 30)
                }

                // Push 3 visualization
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                        )

                    VStack(spacing: 16) {
                        Image(systemName: "rectangle.grid.3x2.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.cyan)

                        Text("Ableton Push 3")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)

                        HStack(spacing: 20) {
                            VStack(spacing: 4) {
                                Text("64")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Pads")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            VStack(spacing: 4) {
                                Text("11")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Encoders")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            VStack(spacing: 4) {
                                Text("RGB")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Text("LEDs")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    .padding(24)
                }
                .frame(height: 200)
                .padding(.horizontal, 30)

                Spacer()
            }
        }
    }
}

// MARK: - Screenshot 9: Collaboration

struct Screenshot9_Collaboration: View {
    var body: some View {
        ZStack {
            // Network gradient
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.2, blue: 0.3),
                    Color(red: 0.0, green: 0.3, blue: 0.4),
                    Color(red: 0.0, green: 0.25, blue: 0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                // Title
                VStack(spacing: 8) {
                    Text("Worldwide Collaboration")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)

                    Text("Zero-latency global sessions")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 60)

                // Session info
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group Meditation Session")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 14))
                                Text("147 participants")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.8))

                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.system(size: 14))
                                Text("12 countries")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    Spacer()
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 30)

                // Participant avatars
                VStack(alignment: .leading, spacing: 16) {
                    Text("Active Participants")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0..<8, id: \.self) { index in
                                ParticipantAvatar(
                                    name: ["Alex", "Maria", "Kenji", "Sofia", "Chen", "Aisha", "Marco", "Priya"][index],
                                    coherence: [0.85, 0.78, 0.92, 0.81, 0.88, 0.75, 0.94, 0.83][index],
                                    country: ["🇺🇸", "🇪🇸", "🇯🇵", "🇮🇹", "🇨🇳", "🇦🇪", "🇧🇷", "🇮🇳"][index]
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 30)

                // Group coherence
                VStack(spacing: 16) {
                    Text("Group Coherence")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 12)
                            .frame(width: 180, height: 180)

                        Circle()
                            .trim(from: 0, to: 0.86)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.cyan, Color.green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .frame(width: 180, height: 180)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 4) {
                            Text("86%")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)

                            Text("Synchronized")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }

                // Sync stats
                HStack(spacing: 20) {
                    CollabStatCard(
                        icon: "heart.fill",
                        title: "Heart Sync",
                        value: "92%"
                    )

                    CollabStatCard(
                        icon: "wind",
                        title: "Breath Sync",
                        value: "88%"
                    )

                    CollabStatCard(
                        icon: "waveform",
                        title: "Latency",
                        value: "8ms"
                    )
                }
                .padding(.horizontal, 30)

                Spacer()
            }
        }
    }
}

// MARK: - Screenshot 10: Accessibility

struct Screenshot10_Accessibility: View {
    var body: some View {
        ZStack {
            // Inclusive gradient
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.15, blue: 0.25),
                    Color(red: 0.25, green: 0.2, blue: 0.3),
                    Color(red: 0.2, green: 0.15, blue: 0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                // Title
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "accessibility")
                            .font(.system(size: 32))
                            .foregroundColor(.white)

                        Text("Accessibility")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text("Music for ALL abilities - WCAG AAA")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 60)

                // Accessibility profiles
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose Your Profile")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    VStack(spacing: 12) {
                        AccessibilityProfileCard(
                            icon: "eye.slash.fill",
                            name: "Blind/Low Vision",
                            description: "VoiceOver optimized with spatial audio cues",
                            active: true
                        )

                        AccessibilityProfileCard(
                            icon: "ear.fill",
                            name: "Deaf/Hard of Hearing",
                            description: "Visual alerts and haptic feedback",
                            active: false
                        )

                        AccessibilityProfileCard(
                            icon: "hand.raised.fill",
                            name: "Motor Limited",
                            description: "Voice control and switch access",
                            active: false
                        )

                        AccessibilityProfileCard(
                            icon: "brain.head.profile",
                            name: "Cognitive Support",
                            description: "Simplified interface and clear navigation",
                            active: false
                        )
                    }
                }
                .padding(.horizontal, 30)

                // Features
                VStack(alignment: .leading, spacing: 16) {
                    Text("Active Features")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    VStack(spacing: 10) {
                        AccessibilityFeatureRow(
                            icon: "textformat.size",
                            name: "Large Text",
                            enabled: true
                        )

                        AccessibilityFeatureRow(
                            icon: "circle.lefthalf.filled",
                            name: "High Contrast",
                            enabled: true
                        )

                        AccessibilityFeatureRow(
                            icon: "speaker.wave.3.fill",
                            name: "Audio Descriptions",
                            enabled: true
                        )

                        AccessibilityFeatureRow(
                            icon: "hand.tap.fill",
                            name: "Haptic Feedback",
                            enabled: true
                        )
                    }
                }
                .padding(.horizontal, 30)

                Spacer()
            }
        }
    }
}

// MARK: - Helper Views

struct WaveformView: View {
    let amplitude: Double
    let phase: Double

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height / 2

                path.move(to: CGPoint(x: 0, y: midHeight))

                for x in stride(from: 0, to: width, by: 2) {
                    let relativeX = x / width
                    let sine = sin((relativeX * 4 * .pi) + phase)
                    let y = midHeight + (sine * midHeight * amplitude)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(
                LinearGradient(
                    colors: [Color.cyan, Color.purple],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 3
            )
        }
    }
}

struct FlowerOfLifeView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 3

        // Center circle
        path.addEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        // 6 surrounding circles
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius

            path.addEllipse(in: CGRect(
                x: x - radius,
                y: y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }

        return path
    }
}

struct ParticleView: View {
    let index: Int
    let phase: Double

    var body: some View {
        let angle = Double(index) * (.pi * 2 / 20) + phase * 0.1
        let radius: CGFloat = 150 + CGFloat(index % 3) * 20

        Circle()
            .fill(Color.cyan.opacity(0.6))
            .frame(width: 6, height: 6)
            .offset(
                x: cos(angle) * radius,
                y: sin(angle) * radius
            )
    }
}

struct QuantumStateCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.cyan)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct ScoreNotationView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.9))

            VStack(spacing: 8) {
                // Staff lines
                ForEach(0..<5) { index in
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 1)
                }

                HStack(spacing: 20) {
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.black)

                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.black)

                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.black)

                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.black)
                }
                .offset(y: -60)
            }
            .padding(.horizontal, 30)
        }
    }
}

struct OrchestraSectionCard: View {
    let icon: String
    let name: String
    let instruments: Int
    let active: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 40))

            Text(name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text("\(instruments) instruments")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(active ? Color.purple.opacity(0.3) : Color.white.opacity(0.1))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(active ? Color.purple : Color.white.opacity(0.2), lineWidth: 2)
                )
        )
    }
}

struct SpatialAudioSourceView: View {
    let index: Int
    let totalSources: Int
    let rotation: Double

    var body: some View {
        let angle = (Double(index) / Double(totalSources)) * 2 * .pi + rotation * .pi / 180
        let radius: CGFloat = 120

        ZStack {
            Circle()
                .fill(Color.cyan)
                .frame(width: 20, height: 20)

            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 10))
                .foregroundColor(.white)
        }
        .offset(
            x: cos(angle) * radius,
            y: sin(angle) * radius
        )
    }
}

struct SpatialMetricCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.cyan)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.1))
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct AIStyleChip: View {
    let name: String
    let selected: Bool

    var body: some View {
        Text(name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(selected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(selected ? Color.purple : Color.white.opacity(0.1))
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(selected ? Color.purple : Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
    }
}

struct WellnessStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.cyan)

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct StreamPlatformCard: View {
    let name: String
    let active: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: active ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24))
                .foregroundColor(active ? .green : .white.opacity(0.3))

            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(active ? .white : .white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(active ? Color.green.opacity(0.2) : Color.white.opacity(0.05))
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(active ? Color.green : Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct StreamStatCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.7))

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct HardwareDeviceRow: View {
    let icon: String
    let name: String
    let type: String
    let status: String

    var body: some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(type)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(status == "Connected" ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)

                Text(status)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(status == "Connected" ? .green : .orange)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct ParticipantAvatar: View {
    let name: String
    let coherence: Double
    let country: String

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                Text(String(name.prefix(1)))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                // Coherence ring
                Circle()
                    .trim(from: 0, to: coherence)
                    .stroke(Color.green, lineWidth: 3)
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
            }

            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)

            Text(country)
                .font(.system(size: 14))
        }
    }
}

struct CollabStatCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.cyan)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.1))
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct AccessibilityProfileCard: View {
    let icon: String
    let name: String
    let description: String
    let active: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(active ? .cyan : .white.opacity(0.5))
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }

            Spacer()

            if active {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(active ? Color.cyan.opacity(0.15) : Color.white.opacity(0.05))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(active ? Color.cyan : Color.white.opacity(0.2), lineWidth: 2)
                )
        )
    }
}

struct AccessibilityFeatureRow: View {
    let icon: String
    let name: String
    let enabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(enabled ? .green : .white.opacity(0.5))
                .frame(width: 30)

            Text(name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            Toggle("", isOn: .constant(enabled))
                .labelsHidden()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview Providers

#if DEBUG
struct AppStoreScreenshots_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // iPhone 15 Pro Max
            Screenshot1_BioReactiveAudio()
                .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
                .previewDisplayName("1. Bio-Reactive Audio")

            Screenshot2_QuantumVisualization()
                .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
                .previewDisplayName("2. Quantum Visualization")

            Screenshot3_OrchestraScoring()
                .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
                .previewDisplayName("3. Orchestra Scoring")

            Screenshot4_ImmersiveExperience()
                .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
                .previewDisplayName("4. Immersive Experience")

            Screenshot5_AIStudio()
                .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
                .previewDisplayName("5. AI Studio")

            Screenshot6_Wellness()
                .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
                .previewDisplayName("6. Wellness")

            Screenshot7_Streaming()
                .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
                .previewDisplayName("7. Streaming")

            Screenshot8_Hardware()
                .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
                .previewDisplayName("8. Hardware")

            Screenshot9_Collaboration()
                .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
                .previewDisplayName("9. Collaboration")

            Screenshot10_Accessibility()
                .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
                .previewDisplayName("10. Accessibility")
        }
    }
}

// iPad Pro previews
struct AppStoreScreenshots_iPad_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            Screenshot1_BioReactiveAudio()
                .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch)"))
                .previewDisplayName("iPad - Bio-Reactive")

            Screenshot2_QuantumVisualization()
                .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch)"))
                .previewDisplayName("iPad - Quantum")

            Screenshot5_AIStudio()
                .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch)"))
                .previewDisplayName("iPad - AI Studio")
        }
    }
}
#endif

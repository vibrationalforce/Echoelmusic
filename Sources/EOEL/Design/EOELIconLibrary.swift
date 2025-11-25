//
//  EOELIconLibrary.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  EOEL Icon Library
//  Comprehensive icon system with vaporwave styling
//  SF Symbols + Custom icons with neon glow effects
//

import SwiftUI

/// Central icon library for EOEL
struct EOELIcon {

    // MARK: - Music & Audio

    struct Music {
        static let waveform = "waveform"
        static let waveformCircle = "waveform.circle.fill"
        static let music = "music.note"
        static let musicList = "music.note.list"
        static let microphone = "mic.fill"
        static let headphones = "headphones"
        static let speaker = "speaker.wave.3.fill"
        static let volume = "speaker.wave.2.fill"
        static let mute = "speaker.slash.fill"
        static let equalizer = "slider.horizontal.3"
        static let metronome = "metronome.fill"
        static let tuningFork = "tuningfork"
    }

    // MARK: - Transport Controls

    struct Transport {
        static let play = "play.fill"
        static let playCircle = "play.circle.fill"
        static let pause = "pause.fill"
        static let pauseCircle = "pause.circle.fill"
        static let stop = "stop.fill"
        static let stopCircle = "stop.circle.fill"
        static let record = "record.circle"
        static let recordFill = "record.circle.fill"
        static let forward = "forward.fill"
        static let backward = "backward.fill"
        static let skipForward = "forward.end.fill"
        static let skipBackward = "backward.end.fill"
        static let shuffle = "shuffle"
        static let repeat = "repeat"
        static let repeatOne = "repeat.1"
    }

    // MARK: - MIDI & Instruments

    struct MIDI {
        static let piano = "pianokeys"
        static let pianoInverse = "pianokeys.inverse"
        static let drum = "beats.headphones"
        static let guitar = "guitars.fill"
        static let synth = "waveform.path.ecg"
        static let midi = "cable.connector"
        static let midiKeyboard = "keyboard"
    }

    // MARK: - Recording

    struct Recording {
        static let rec = "circle.fill"
        static let recCircle = "record.circle.fill"
        static let arm = "target"
        static let punch = "scissors"
        static let overdub = "layers.fill"
        static let take = "film.fill"
        static let quantize = "grid"
        static let metronome = "metronome"
    }

    // MARK: - Tracks & Mixing

    struct Mixing {
        static let track = "waveform.path"
        static let fader = "slider.vertical.3"
        static let pan = "slider.horizontal.below.rectangle"
        static let mute = "speaker.slash"
        static let solo = "s.circle.fill"
        static let auxSend = "arrow.turn.up.right"
        static let insert = "plus.rectangle.on.rectangle"
        static let mixer = "slider.horizontal.3"
        static let automation = "waveform.path.ecg"
    }

    // MARK: - Effects

    struct Effects {
        static let eq = "waveform.path.ecg.rectangle.fill"
        static let compressor = "waveform.badge.minus"
        static let reverb = "water.waves"
        static let delay = "arrow.3.trianglepath"
        static let distortion = "bolt.fill"
        static let chorus = "arrow.triangle.branch"
        static let filter = "waveform.path.badge.minus"
        static let gate = "rectangle.portrait.split.2x1"
    }

    // MARK: - Sync & Clock

    struct Sync {
        static let clock = "clock.fill"
        static let timer = "timer"
        static let sync = "arrow.triangle.2.circlepath"
        static let link = "link"
        static let network = "network"
        static let wifi = "wifi"
        static let bluetooth = "bluetooth"
    }

    // MARK: - Hardware

    struct Hardware {
        static let audioInterface = "hifispeaker.fill"
        static let midiInterface = "cable.connector"
        static let usb = "cable.connector"
        static let thunderbolt = "bolt.fill"
        static let device = "cube.box.fill"
        static let controller = "gamecontroller.fill"
    }

    // MARK: - Studio & Workflow

    struct Studio {
        static let session = "folder.fill"
        static let project = "doc.fill"
        static let export = "square.and.arrow.up"
        static let import = "square.and.arrow.down"
        static let save = "externaldrive.fill"
        static let settings = "gearshape.fill"
        static let preferences = "slider.horizontal.3"
    }

    // MARK: - Collaboration

    struct Collaboration {
        static let user = "person.fill"
        static let users = "person.3.fill"
        static let chat = "message.fill"
        static let video = "video.fill"
        static let screen = "rectangle.on.rectangle"
        static let broadcast = "antenna.radiowaves.left.and.right"
    }

    // MARK: - Status

    struct Status {
        static let success = "checkmark.circle.fill"
        static let error = "xmark.circle.fill"
        static let warning = "exclamationmark.triangle.fill"
        static let info = "info.circle.fill"
        static let locked = "lock.fill"
        static let unlocked = "lock.open.fill"
    }

    // MARK: - Vaporwave Specific

    struct Vaporwave {
        static let grid = "square.grid.3x3"
        static let wave = "waveform"
        static let chrome = "sparkles"
        static let neon = "sun.max.fill"
        static let palm = "tree.fill"
        static let sunset = "sunset.fill"
        static let pyramid = "triangle.fill"
        static let cube = "cube.fill"
    }
}

// MARK: - Neon Icon

/// Icon with neon glow effect
struct NeonIcon: View {
    let systemName: String
    var color: Color = VaporwaveDesignSystem.Colors.neonCyan
    var size: CGFloat = VaporwaveDesignSystem.IconSize.medium

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size))
            .foregroundColor(color)
            .shadow(color: color.opacity(0.8), radius: 4)
            .shadow(color: color.opacity(0.6), radius: 8)
            .shadow(color: color.opacity(0.4), radius: 12)
    }
}

// MARK: - Chrome Icon

/// Icon with chrome metallic effect
struct ChromeIcon: View {
    let systemName: String
    var size: CGFloat = VaporwaveDesignSystem.IconSize.medium

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size))
            .foregroundStyle(VaporwaveDesignSystem.Colors.chromeGradient)
            .shadow(color: .white.opacity(0.5), radius: 2)
    }
}

// MARK: - Animated Icon

/// Icon with pulsing animation
struct PulsingIcon: View {
    let systemName: String
    var color: Color = VaporwaveDesignSystem.Colors.neonPink
    var size: CGFloat = VaporwaveDesignSystem.IconSize.medium

    @State private var isPulsing = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size))
            .foregroundColor(color)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .shadow(color: color.opacity(isPulsing ? 1.0 : 0.5), radius: isPulsing ? 15 : 8)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Rotating Icon

/// Icon with continuous rotation
struct RotatingIcon: View {
    let systemName: String
    var color: Color = VaporwaveDesignSystem.Colors.neonCyan
    var size: CGFloat = VaporwaveDesignSystem.IconSize.medium
    var duration: Double = 2.0

    @State private var rotation: Double = 0

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size))
            .foregroundColor(color)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Level Indicator Icon

/// Icon with level indicator (for volume, etc.)
struct LevelIndicatorIcon: View {
    let level: Double  // 0.0 to 1.0
    var color: Color = VaporwaveDesignSystem.Colors.neonCyan
    var size: CGFloat = VaporwaveDesignSystem.IconSize.medium

    var body: some View {
        ZStack {
            // Base icon
            Image(systemName: speakerIcon)
                .font(.system(size: size))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.6), radius: 8)

            // Level bars
            HStack(spacing: 2) {
                ForEach(0..<3) { i in
                    if Double(i) / 3.0 < level {
                        Rectangle()
                            .fill(color)
                            .frame(width: 2, height: CGFloat(4 + i * 2))
                    }
                }
            }
            .offset(x: size * 0.3)
        }
    }

    private var speakerIcon: String {
        if level < 0.1 { return "speaker.slash.fill" }
        else if level < 0.5 { return "speaker.wave.1.fill" }
        else if level < 0.8 { return "speaker.wave.2.fill" }
        else { return "speaker.wave.3.fill" }
    }
}

// MARK: - Status Icon

/// Icon with status badge
struct StatusIcon: View {
    let systemName: String
    var status: Status = .inactive
    var color: Color = VaporwaveDesignSystem.Colors.neonCyan
    var size: CGFloat = VaporwaveDesignSystem.IconSize.medium

    enum Status {
        case active, inactive, error, warning

        var color: Color {
            switch self {
            case .active: return VaporwaveDesignSystem.Colors.laserGreen
            case .inactive: return Color.gray
            case .error: return Color.red
            case .warning: return VaporwaveDesignSystem.Colors.sunsetOrange
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: systemName)
                .font(.system(size: size))
                .foregroundColor(color)

            // Status badge
            Circle()
                .fill(status.color)
                .frame(width: size * 0.35, height: size * 0.35)
                .shadow(color: status.color.opacity(0.8), radius: 4)
                .offset(x: size * 0.2, y: -size * 0.2)
        }
    }
}

// MARK: - Transport Button

/// Styled transport control button
struct TransportButton: View {
    let icon: String
    let action: () -> Void
    var isActive: Bool = false
    var color: Color = VaporwaveDesignSystem.Colors.neonCyan
    var size: CGFloat = 64

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background circle
                Circle()
                    .fill(
                        LiquidGlassMaterial(
                            color: isActive ? color : .gray,
                            opacity: isActive ? 0.3 : 0.2
                        )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isActive ? color : Color.gray.opacity(0.5),
                                lineWidth: 2
                            )
                            .shadow(
                                color: isActive ? color.opacity(0.6) : .clear,
                                radius: isPressed ? 15 : 10
                            )
                    )

                // Icon
                Image(systemName: icon)
                    .font(.system(size: size * 0.4))
                    .foregroundColor(isActive ? color : .white.opacity(0.7))
                    .shadow(
                        color: isActive ? color.opacity(0.8) : .clear,
                        radius: 8
                    )
            }
            .frame(width: size, height: size)
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(VaporwaveDesignSystem.Animation.bouncySpring, value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Icon Grid Preview

#Preview("Icon Library") {
    ZStack {
        VaporwaveDesignSystem.Colors.spaceGradient
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: VaporwaveDesignSystem.Spacing.xlarge) {
                // Section: Neon Icons
                VStack(spacing: VaporwaveDesignSystem.Spacing.medium) {
                    NeonText(
                        text: "NEON ICONS",
                        color: VaporwaveDesignSystem.Colors.neonCyan,
                        font: VaporwaveDesignSystem.Typography.headline
                    )

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6)) {
                        NeonIcon(systemName: EOELIcon.Music.waveformCircle, color: VaporwaveDesignSystem.Colors.neonCyan)
                        NeonIcon(systemName: EOELIcon.Transport.playCircle, color: VaporwaveDesignSystem.Colors.laserGreen)
                        NeonIcon(systemName: EOELIcon.Transport.recordFill, color: VaporwaveDesignSystem.Colors.neonPink)
                        NeonIcon(systemName: EOELIcon.MIDI.piano, color: VaporwaveDesignSystem.Colors.neonPurple)
                        NeonIcon(systemName: EOELIcon.Effects.reverb, color: VaporwaveDesignSystem.Colors.electricBlue)
                        NeonIcon(systemName: EOELIcon.Sync.sync, color: VaporwaveDesignSystem.Colors.sunsetOrange)
                    }
                }

                // Section: Chrome Icons
                VStack(spacing: VaporwaveDesignSystem.Spacing.medium) {
                    ChromeText(text: "CHROME", font: VaporwaveDesignSystem.Typography.headline)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6)) {
                        ChromeIcon(systemName: EOELIcon.Music.music, size: 40)
                        ChromeIcon(systemName: EOELIcon.MIDI.synth, size: 40)
                        ChromeIcon(systemName: EOELIcon.Effects.eq, size: 40)
                        ChromeIcon(systemName: EOELIcon.Studio.settings, size: 40)
                        ChromeIcon(systemName: EOELIcon.Vaporwave.cube, size: 40)
                        ChromeIcon(systemName: EOELIcon.Vaporwave.pyramid, size: 40)
                    }
                }

                // Section: Animated Icons
                VStack(spacing: VaporwaveDesignSystem.Spacing.medium) {
                    NeonText(
                        text: "ANIMATED",
                        color: VaporwaveDesignSystem.Colors.neonPink,
                        font: VaporwaveDesignSystem.Typography.headline
                    )

                    HStack(spacing: VaporwaveDesignSystem.Spacing.xlarge) {
                        PulsingIcon(
                            systemName: EOELIcon.Recording.recCircle,
                            color: VaporwaveDesignSystem.Colors.neonPink,
                            size: 48
                        )

                        RotatingIcon(
                            systemName: EOELIcon.Sync.sync,
                            color: VaporwaveDesignSystem.Colors.neonCyan,
                            size: 48
                        )

                        StatusIcon(
                            systemName: EOELIcon.Collaboration.broadcast,
                            status: .active,
                            color: VaporwaveDesignSystem.Colors.laserGreen,
                            size: 48
                        )
                    }
                }

                // Section: Transport Controls
                VStack(spacing: VaporwaveDesignSystem.Spacing.medium) {
                    NeonText(
                        text: "TRANSPORT",
                        color: VaporwaveDesignSystem.Colors.laserGreen,
                        font: VaporwaveDesignSystem.Typography.headline
                    )

                    HStack(spacing: VaporwaveDesignSystem.Spacing.large) {
                        TransportButton(
                            icon: EOELIcon.Transport.backward,
                            action: {},
                            color: VaporwaveDesignSystem.Colors.neonCyan,
                            size: 56
                        )

                        TransportButton(
                            icon: EOELIcon.Transport.play,
                            action: {},
                            isActive: true,
                            color: VaporwaveDesignSystem.Colors.laserGreen,
                            size: 72
                        )

                        TransportButton(
                            icon: EOELIcon.Transport.recordFill,
                            action: {},
                            color: VaporwaveDesignSystem.Colors.neonPink,
                            size: 56
                        )

                        TransportButton(
                            icon: EOELIcon.Transport.forward,
                            action: {},
                            color: VaporwaveDesignSystem.Colors.neonCyan,
                            size: 56
                        )
                    }
                }
            }
            .padding()
        }
    }
}

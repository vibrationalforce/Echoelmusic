//
//  LiquidGlassComponents.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Liquid Glass UI Components
//  Glassmorphism buttons, sliders, cards, controls
//  Ultra-modern frosted glass aesthetic with neon accents
//

import SwiftUI

// MARK: - Liquid Glass Button

struct LiquidGlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var glowColor: Color = VaporwaveDesignSystem.Colors.neonCyan
    var size: ButtonSize = .medium

    enum ButtonSize {
        case small, medium, large

        var height: CGFloat {
            switch self {
            case .small: return 36
            case .medium: return 48
            case .large: return 64
            }
        }

        var font: Font {
            switch self {
            case .small: return VaporwaveDesignSystem.Typography.caption
            case .medium: return VaporwaveDesignSystem.Typography.body
            case .large: return VaporwaveDesignSystem.Typography.subheadline
            }
        }
    }

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: VaporwaveDesignSystem.Spacing.small) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(size.font)
                }
                Text(title)
                    .font(size.font)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(height: size.height)
            .padding(.horizontal, VaporwaveDesignSystem.Spacing.large)
            .background(
                ZStack {
                    // Glass base
                    LiquidGlassMaterial(color: glowColor, opacity: 0.2)

                    // Neon border
                    RoundedRectangle(cornerRadius: VaporwaveDesignSystem.CornerRadius.medium)
                        .strokeBorder(glowColor, lineWidth: isPressed ? 3 : 2)
                        .shadow(color: glowColor.opacity(0.5), radius: isPressed ? 15 : 10)
                        .shadow(color: glowColor.opacity(0.3), radius: isPressed ? 25 : 20)
                }
            )
            .cornerRadius(VaporwaveDesignSystem.CornerRadius.medium)
            .scaleEffect(isPressed ? 0.95 : 1.0)
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

// MARK: - Liquid Glass Slider

struct LiquidGlassSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var label: String?
    var glowColor: Color = VaporwaveDesignSystem.Colors.neonPurple

    var body: some View {
        VStack(alignment: .leading, spacing: VaporwaveDesignSystem.Spacing.small) {
            if let label = label {
                HStack {
                    NeonText(text: label, color: glowColor, font: VaporwaveDesignSystem.Typography.caption)
                    Spacer()
                    Text(String(format: "%.1f", value))
                        .font(VaporwaveDesignSystem.Typography.caption)
                        .foregroundColor(glowColor)
                        .fontWeight(.bold)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(
                            LiquidGlassMaterial(color: glowColor, opacity: 0.15)
                        )
                        .frame(height: 8)
                        .overlay(
                            Capsule()
                                .strokeBorder(glowColor.opacity(0.3), lineWidth: 1)
                        )

                    // Fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [glowColor, glowColor.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: thumbPosition(in: geometry.size.width), height: 8)
                        .shadow(color: glowColor.opacity(0.6), radius: 5)
                        .shadow(color: glowColor.opacity(0.4), radius: 10)

                    // Thumb
                    Circle()
                        .fill(
                            ZStack {
                                LiquidGlassMaterial(color: .white, opacity: 0.3)
                                Circle()
                                    .strokeBorder(glowColor, lineWidth: 2)
                                    .shadow(color: glowColor, radius: 8)
                            }
                        )
                        .frame(width: 24, height: 24)
                        .offset(x: thumbPosition(in: geometry.size.width) - 12)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let percent = Double(gesture.location.x / geometry.size.width)
                            let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * percent
                            value = min(max(newValue, range.lowerBound), range.upperBound)
                        }
                )
            }
            .frame(height: 24)
        }
    }

    private func thumbPosition(in width: CGFloat) -> CGFloat {
        let percent = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return width * CGFloat(percent)
    }
}

// MARK: - Liquid Glass Knob

struct LiquidGlassKnob: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var label: String
    var glowColor: Color = VaporwaveDesignSystem.Colors.neonCyan
    var size: CGFloat = 80

    @State private var isDragging = false

    var body: some View {
        VStack(spacing: VaporwaveDesignSystem.Spacing.small) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(
                        LiquidGlassMaterial(color: glowColor, opacity: 0.2),
                        lineWidth: 8
                    )
                    .shadow(color: glowColor.opacity(0.3), radius: 5)

                // Value arc
                Circle()
                    .trim(from: 0, to: normalizedValue)
                    .stroke(
                        LinearGradient(
                            colors: [glowColor, glowColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: glowColor, radius: 10)

                // Center knob
                Circle()
                    .fill(
                        ZStack {
                            LiquidGlassMaterial(color: .white, opacity: 0.1)
                            Circle()
                                .strokeBorder(glowColor.opacity(0.5), lineWidth: 2)
                        }
                    )
                    .frame(width: size * 0.6)
                    .shadow(color: glowColor.opacity(0.4), radius: isDragging ? 15 : 8)

                // Indicator line
                Rectangle()
                    .fill(glowColor)
                    .frame(width: 3, height: size * 0.3)
                    .offset(y: -size * 0.25)
                    .rotationEffect(.degrees(rotation))
                    .shadow(color: glowColor, radius: 5)

                // Value text
                Text(String(format: "%.0f", value))
                    .font(VaporwaveDesignSystem.Typography.body)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(-45))  // Start at bottom-left
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        isDragging = true
                        let vector = CGVector(dx: gesture.location.x - size/2, dy: gesture.location.y - size/2)
                        let radians = atan2(vector.dy, vector.dx)
                        var degrees = radians * 180 / .pi + 90
                        if degrees < 0 { degrees += 360 }

                        let percent = degrees / 270.0  // 270 degree rotation
                        let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * percent
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            // Label
            NeonText(text: label, color: glowColor, font: VaporwaveDesignSystem.Typography.caption)
        }
    }

    private var normalizedValue: CGFloat {
        CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    private var rotation: Double {
        normalizedValue * 270  // 270 degree rotation
    }
}

// MARK: - Liquid Glass Card

struct LiquidGlassCard<Content: View>: View {
    let content: Content
    var glowColor: Color = VaporwaveDesignSystem.Colors.neonCyan
    var padding: CGFloat = VaporwaveDesignSystem.Spacing.large

    init(glowColor: Color = VaporwaveDesignSystem.Colors.neonCyan,
         padding: CGFloat = VaporwaveDesignSystem.Spacing.large,
         @ViewBuilder content: () -> Content) {
        self.glowColor = glowColor
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    // Glass base
                    LiquidGlassMaterial(color: glowColor, opacity: 0.12)

                    // Subtle border
                    RoundedRectangle(cornerRadius: VaporwaveDesignSystem.CornerRadius.large)
                        .strokeBorder(
                            LinearGradient(
                                colors: [glowColor.opacity(0.6), glowColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .cornerRadius(VaporwaveDesignSystem.CornerRadius.large)
            .shadow(color: glowColor.opacity(0.2), radius: 15, x: 0, y: 5)
    }
}

// MARK: - Liquid Glass Toggle

struct LiquidGlassToggle: View {
    @Binding var isOn: Bool
    var label: String
    var glowColor: Color = VaporwaveDesignSystem.Colors.neonPink

    var body: some View {
        Button {
            withAnimation(VaporwaveDesignSystem.Animation.bouncySpring) {
                isOn.toggle()
            }
        } label: {
            HStack {
                Text(label)
                    .font(VaporwaveDesignSystem.Typography.body)
                    .foregroundColor(.white)

                Spacer()

                ZStack {
                    // Track
                    Capsule()
                        .fill(
                            isOn ?
                            LiquidGlassMaterial(color: glowColor, opacity: 0.3) :
                            LiquidGlassMaterial(color: .gray, opacity: 0.2)
                        )
                        .frame(width: 50, height: 28)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isOn ? glowColor : Color.gray,
                                    lineWidth: 2
                                )
                                .shadow(
                                    color: isOn ? glowColor.opacity(0.5) : .clear,
                                    radius: 8
                                )
                        )

                    // Thumb
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .shadow(color: isOn ? glowColor : .black.opacity(0.2), radius: 4)
                        .offset(x: isOn ? 11 : -11)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Liquid Glass Segment Control

struct LiquidGlassSegmentControl: View {
    @Binding var selection: Int
    let options: [String]
    var glowColor: Color = VaporwaveDesignSystem.Colors.neonCyan

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    withAnimation(VaporwaveDesignSystem.Animation.smoothSpring) {
                        selection = index
                    }
                } label: {
                    Text(option)
                        .font(VaporwaveDesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(selection == index ? .white : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VaporwaveDesignSystem.Spacing.small)
                        .background(
                            ZStack {
                                if selection == index {
                                    LiquidGlassMaterial(color: glowColor, opacity: 0.3)
                                    RoundedRectangle(cornerRadius: VaporwaveDesignSystem.CornerRadius.small)
                                        .strokeBorder(glowColor, lineWidth: 1)
                                        .shadow(color: glowColor.opacity(0.5), radius: 8)
                                }
                            }
                        )
                        .cornerRadius(VaporwaveDesignSystem.CornerRadius.small)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            LiquidGlassMaterial(color: .gray, opacity: 0.1)
        )
        .cornerRadius(VaporwaveDesignSystem.CornerRadius.medium)
    }
}

// MARK: - Liquid Glass Level Meter

struct LiquidGlassLevelMeter: View {
    var level: Double  // 0.0 to 1.0
    var peakLevel: Double = 0.0
    var orientation: Orientation = .vertical
    var glowColor: Color = VaporwaveDesignSystem.Colors.laserGreen

    enum Orientation {
        case horizontal, vertical
    }

    var body: some View {
        GeometryReader { geometry in
            let size = orientation == .vertical ? geometry.size.height : geometry.size.width

            ZStack(alignment: orientation == .vertical ? .bottom : .leading) {
                // Background
                Rectangle()
                    .fill(LiquidGlassMaterial(color: .gray, opacity: 0.2))

                // Level fill with gradient
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: orientation == .vertical ? .bottom : .leading,
                            endPoint: orientation == .vertical ? .top : .trailing
                        )
                    )
                    .frame(
                        width: orientation == .vertical ? nil : size * CGFloat(level),
                        height: orientation == .vertical ? size * CGFloat(level) : nil
                    )
                    .shadow(color: currentColor.opacity(0.6), radius: 5)

                // Peak indicator
                if peakLevel > 0 {
                    Rectangle()
                        .fill(Color.red)
                        .frame(
                            width: orientation == .vertical ? nil : 2,
                            height: orientation == .vertical ? 2 : nil
                        )
                        .offset(
                            x: orientation == .vertical ? 0 : size * CGFloat(peakLevel),
                            y: orientation == .vertical ? -size * CGFloat(peakLevel) : 0
                        )
                }
            }
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private var gradientColors: [Color] {
        if level < 0.7 {
            return [VaporwaveDesignSystem.Colors.laserGreen, VaporwaveDesignSystem.Colors.laserGreen.opacity(0.6)]
        } else if level < 0.9 {
            return [VaporwaveDesignSystem.Colors.sunsetOrange, VaporwaveDesignSystem.Colors.laserGreen]
        } else {
            return [Color.red, VaporwaveDesignSystem.Colors.sunsetOrange]
        }
    }

    private var currentColor: Color {
        if level < 0.7 { return VaporwaveDesignSystem.Colors.laserGreen }
        else if level < 0.9 { return VaporwaveDesignSystem.Colors.sunsetOrange }
        else { return .red }
    }
}

// MARK: - Liquid Glass Progress Bar

struct LiquidGlassProgressBar: View {
    var progress: Double  // 0.0 to 1.0
    var label: String?
    var glowColor: Color = VaporwaveDesignSystem.Colors.neonPurple

    var body: some View {
        VStack(alignment: .leading, spacing: VaporwaveDesignSystem.Spacing.small) {
            if let label = label {
                HStack {
                    Text(label)
                        .font(VaporwaveDesignSystem.Typography.caption)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(VaporwaveDesignSystem.Typography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(glowColor)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(LiquidGlassMaterial(color: .gray, opacity: 0.2))

                    // Progress fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [glowColor, glowColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(progress))
                        .shadow(color: glowColor.opacity(0.6), radius: 8)
                }
            }
            .frame(height: 12)
        }
    }
}

// MARK: - Liquid Glass Badge

struct LiquidGlassBadge: View {
    let text: String
    var glowColor: Color = VaporwaveDesignSystem.Colors.neonPink

    var body: some View {
        Text(text)
            .font(VaporwaveDesignSystem.Typography.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, VaporwaveDesignSystem.Spacing.small)
            .padding(.vertical, 4)
            .background(
                ZStack {
                    LiquidGlassMaterial(color: glowColor, opacity: 0.3)
                    Capsule()
                        .strokeBorder(glowColor, lineWidth: 1)
                        .shadow(color: glowColor.opacity(0.5), radius: 4)
                }
            )
            .cornerRadius(VaporwaveDesignSystem.CornerRadius.pill)
    }
}

// MARK: - Liquid Glass Tab Bar

struct LiquidGlassTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [(icon: String, title: String)]
    var glowColor: Color = VaporwaveDesignSystem.Colors.neonCyan

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    withAnimation(VaporwaveDesignSystem.Animation.smoothSpring) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: VaporwaveDesignSystem.Spacing.tiny) {
                        Image(systemName: tab.icon)
                            .font(.title2)
                            .foregroundColor(selectedTab == index ? glowColor : .white.opacity(0.5))
                            .shadow(
                                color: selectedTab == index ? glowColor : .clear,
                                radius: 8
                            )

                        Text(tab.title)
                            .font(VaporwaveDesignSystem.Typography.caption)
                            .foregroundColor(selectedTab == index ? glowColor : .white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VaporwaveDesignSystem.Spacing.small)
                    .background(
                        selectedTab == index ?
                        LiquidGlassMaterial(color: glowColor, opacity: 0.15) :
                        Color.clear
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            LiquidGlassMaterial(color: .gray, opacity: 0.1)
        )
    }
}

// MARK: - Preview

#Preview("Liquid Glass Components") {
    ZStack {
        VaporwaveDesignSystem.Colors.spaceGradient
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: VaporwaveDesignSystem.Spacing.xlarge) {
                // Buttons
                VStack(spacing: VaporwaveDesignSystem.Spacing.medium) {
                    LiquidGlassButton(title: "Play", icon: "play.fill", action: {})
                    LiquidGlassButton(
                        title: "Record",
                        icon: "record.circle",
                        action: {},
                        glowColor: VaporwaveDesignSystem.Colors.neonPink,
                        size: .large
                    )
                }

                // Slider
                LiquidGlassCard {
                    LiquidGlassSlider(
                        value: .constant(0.7),
                        range: 0...1,
                        label: "Volume",
                        glowColor: VaporwaveDesignSystem.Colors.neonPurple
                    )
                }

                // Knobs
                HStack {
                    LiquidGlassKnob(
                        value: .constant(50),
                        range: 0...100,
                        label: "Cutoff",
                        glowColor: VaporwaveDesignSystem.Colors.neonCyan
                    )

                    LiquidGlassKnob(
                        value: .constant(75),
                        range: 0...100,
                        label: "Resonance",
                        glowColor: VaporwaveDesignSystem.Colors.neonPink
                    )
                }

                // Level Meters
                HStack(spacing: VaporwaveDesignSystem.Spacing.small) {
                    ForEach(0..<8) { i in
                        LiquidGlassLevelMeter(
                            level: Double.random(in: 0.3...0.9),
                            peakLevel: 0.95,
                            glowColor: VaporwaveDesignSystem.Colors.laserGreen
                        )
                        .frame(width: 20, height: 150)
                    }
                }

                // Badges
                HStack {
                    LiquidGlassBadge(text: "LIVE", glowColor: .red)
                    LiquidGlassBadge(text: "REC", glowColor: VaporwaveDesignSystem.Colors.neonPink)
                    LiquidGlassBadge(text: "SYNC", glowColor: VaporwaveDesignSystem.Colors.neonCyan)
                }
            }
            .padding()
        }
    }
}

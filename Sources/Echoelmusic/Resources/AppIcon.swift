//
//  AppIcon.swift
//  Echoelmusic
//
//  Programmatic App Icon Generation for All Platforms
//  Bio-Audio Waveform Theme — EKG morphing into sine wave
//
//  Created: 2026-01-05
//  Updated: 2026-02-14
//

import Foundation
import SwiftUI

#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - App Icon Generator

public struct AppIconGenerator {

    // MARK: - Icon Sizes (All Platforms)

    public enum IconSize: CaseIterable {
        // iOS
        case iOS_20_2x, iOS_20_3x
        case iOS_29_2x, iOS_29_3x
        case iOS_40_2x, iOS_40_3x
        case iOS_60_2x, iOS_60_3x
        case iOS_1024

        // iPad
        case iPad_20, iPad_20_2x
        case iPad_29, iPad_29_2x
        case iPad_40, iPad_40_2x
        case iPad_76, iPad_76_2x
        case iPad_83_5_2x

        // macOS
        case macOS_16, macOS_16_2x
        case macOS_32, macOS_32_2x
        case macOS_128, macOS_128_2x
        case macOS_256, macOS_256_2x
        case macOS_512, macOS_512_2x

        // watchOS
        case watchOS_24_2x
        case watchOS_27_5_2x
        case watchOS_29_2x, watchOS_29_3x
        case watchOS_40_2x
        case watchOS_44_2x
        case watchOS_50_2x
        case watchOS_86_2x
        case watchOS_98_2x
        case watchOS_108_2x
        case watchOS_1024

        public var size: CGFloat {
            switch self {
            // iOS
            case .iOS_20_2x: return 40
            case .iOS_20_3x: return 60
            case .iOS_29_2x: return 58
            case .iOS_29_3x: return 87
            case .iOS_40_2x: return 80
            case .iOS_40_3x: return 120
            case .iOS_60_2x: return 120
            case .iOS_60_3x: return 180
            case .iOS_1024: return 1024

            // iPad
            case .iPad_20: return 20
            case .iPad_20_2x: return 40
            case .iPad_29: return 29
            case .iPad_29_2x: return 58
            case .iPad_40: return 40
            case .iPad_40_2x: return 80
            case .iPad_76: return 76
            case .iPad_76_2x: return 152
            case .iPad_83_5_2x: return 167

            // macOS
            case .macOS_16: return 16
            case .macOS_16_2x: return 32
            case .macOS_32: return 32
            case .macOS_32_2x: return 64
            case .macOS_128: return 128
            case .macOS_128_2x: return 256
            case .macOS_256: return 256
            case .macOS_256_2x: return 512
            case .macOS_512: return 512
            case .macOS_512_2x: return 1024

            // watchOS
            case .watchOS_24_2x: return 48
            case .watchOS_27_5_2x: return 55
            case .watchOS_29_2x: return 58
            case .watchOS_29_3x: return 87
            case .watchOS_40_2x: return 80
            case .watchOS_44_2x: return 88
            case .watchOS_50_2x: return 100
            case .watchOS_86_2x: return 172
            case .watchOS_98_2x: return 196
            case .watchOS_108_2x: return 216
            case .watchOS_1024: return 1024
            }
        }

        public var filename: String {
            switch self {
            // iOS
            case .iOS_20_2x: return "AppIcon-20@2x"
            case .iOS_20_3x: return "AppIcon-20@3x"
            case .iOS_29_2x: return "AppIcon-29@2x"
            case .iOS_29_3x: return "AppIcon-29@3x"
            case .iOS_40_2x: return "AppIcon-40@2x"
            case .iOS_40_3x: return "AppIcon-40@3x"
            case .iOS_60_2x: return "AppIcon-60@2x"
            case .iOS_60_3x: return "AppIcon-60@3x"
            case .iOS_1024: return "AppIcon-1024"

            // iPad
            case .iPad_20: return "AppIcon-iPad-20"
            case .iPad_20_2x: return "AppIcon-iPad-20@2x"
            case .iPad_29: return "AppIcon-iPad-29"
            case .iPad_29_2x: return "AppIcon-iPad-29@2x"
            case .iPad_40: return "AppIcon-iPad-40"
            case .iPad_40_2x: return "AppIcon-iPad-40@2x"
            case .iPad_76: return "AppIcon-iPad-76"
            case .iPad_76_2x: return "AppIcon-iPad-76@2x"
            case .iPad_83_5_2x: return "AppIcon-iPad-83.5@2x"

            // macOS
            case .macOS_16: return "AppIcon-macOS-16"
            case .macOS_16_2x: return "AppIcon-macOS-16@2x"
            case .macOS_32: return "AppIcon-macOS-32"
            case .macOS_32_2x: return "AppIcon-macOS-32@2x"
            case .macOS_128: return "AppIcon-macOS-128"
            case .macOS_128_2x: return "AppIcon-macOS-128@2x"
            case .macOS_256: return "AppIcon-macOS-256"
            case .macOS_256_2x: return "AppIcon-macOS-256@2x"
            case .macOS_512: return "AppIcon-macOS-512"
            case .macOS_512_2x: return "AppIcon-macOS-512@2x"

            // watchOS
            case .watchOS_24_2x: return "AppIcon-Watch-24@2x"
            case .watchOS_27_5_2x: return "AppIcon-Watch-27.5@2x"
            case .watchOS_29_2x: return "AppIcon-Watch-29@2x"
            case .watchOS_29_3x: return "AppIcon-Watch-29@3x"
            case .watchOS_40_2x: return "AppIcon-Watch-40@2x"
            case .watchOS_44_2x: return "AppIcon-Watch-44@2x"
            case .watchOS_50_2x: return "AppIcon-Watch-50@2x"
            case .watchOS_86_2x: return "AppIcon-Watch-86@2x"
            case .watchOS_98_2x: return "AppIcon-Watch-98@2x"
            case .watchOS_108_2x: return "AppIcon-Watch-108@2x"
            case .watchOS_1024: return "AppIcon-Watch-1024"
            }
        }
    }

    // MARK: - Icon Design Constants (Rainbow Spectrum Waveform Theme)
    // Physics: CIE 1931 octave transposition — audio frequency → light wavelength → color

    public struct Design {
        /// Green - Primary (#22C55E) — Mid frequency, 530nm
        public static let primaryColor = Color(red: 0.133, green: 0.773, blue: 0.369)
        /// Rose - Heart (#F472B6)
        public static let heartColor = Color(red: 0.957, green: 0.447, blue: 0.714)
        /// Deep Space - Background (#030712)
        public static let backgroundColor = Color(red: 0.012, green: 0.027, blue: 0.071)

        // Rainbow spectrum colors (octave transposition: audio → light)
        /// Red (#EF4444) — Sub-Bass ~40Hz, 700nm
        public static let spectrumRed = Color(red: 0.937, green: 0.267, blue: 0.267)
        /// Orange (#F97316) — Bass ~125Hz, 640nm
        public static let spectrumOrange = Color(red: 0.976, green: 0.451, blue: 0.086)
        /// Yellow (#EAB308) — Low-Mid ~355Hz, 585nm
        public static let spectrumYellow = Color(red: 0.918, green: 0.702, blue: 0.031)
        /// Green (#22C55E) — Mid ~1kHz, 530nm
        public static let spectrumGreen = Color(red: 0.133, green: 0.773, blue: 0.369)
        /// Cyan (#06B6D4) — Upper-Mid ~2.8kHz, 485nm
        public static let spectrumCyan = Color(red: 0.024, green: 0.714, blue: 0.831)
        /// Blue (#3B82F6) — High ~5.6kHz, 440nm
        public static let spectrumBlue = Color(red: 0.231, green: 0.510, blue: 0.965)
        /// Violet (#8B5CF6) — Air ~12.6kHz, 410nm
        public static let spectrumViolet = Color(red: 0.545, green: 0.361, blue: 0.965)

        /// Full rainbow spectrum gradient (bio → spectrum)
        public static let spectrumGradient: [Color] = [
            Color.white.opacity(0.6),
            Color(red: 0.957, green: 0.447, blue: 0.714),  // rose (heart)
            Color(red: 0.937, green: 0.267, blue: 0.267),  // red (700nm)
            Color(red: 0.976, green: 0.451, blue: 0.086),  // orange (640nm)
            Color(red: 0.918, green: 0.702, blue: 0.031),  // yellow (585nm)
            Color(red: 0.133, green: 0.773, blue: 0.369),  // green (530nm)
            Color(red: 0.024, green: 0.714, blue: 0.831),  // cyan (485nm)
            Color(red: 0.231, green: 0.510, blue: 0.965),  // blue (440nm)
            Color(red: 0.545, green: 0.361, blue: 0.965)   // violet (410nm)
        ]

        /// Glow spectrum (lower opacity)
        public static let glowGradient: [Color] = [
            Color(red: 0.957, green: 0.447, blue: 0.714).opacity(0.2),
            Color(red: 0.937, green: 0.267, blue: 0.267).opacity(0.35),
            Color(red: 0.976, green: 0.451, blue: 0.086).opacity(0.4),
            Color(red: 0.918, green: 0.702, blue: 0.031).opacity(0.4),
            Color(red: 0.133, green: 0.773, blue: 0.369).opacity(0.5),
            Color(red: 0.024, green: 0.714, blue: 0.831).opacity(0.4),
            Color(red: 0.231, green: 0.510, blue: 0.965).opacity(0.35),
            Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.25)
        ]
    }
}

// MARK: - SwiftUI App Icon View

public struct AppIconView: View {
    let size: CGFloat

    public init(size: CGFloat = 1024) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Background gradient - Deep space
            LinearGradient(
                colors: [
                    Color(red: 0.012, green: 0.027, blue: 0.071),  // #030712
                    Color(red: 0.016, green: 0.102, blue: 0.055),  // #041a0e
                    Color(red: 0.012, green: 0.027, blue: 0.071)   // #030712
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Ambient glow — subtle spectrum tint
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppIconGenerator.Design.spectrumGreen.opacity(0.08),
                            AppIconGenerator.Design.spectrumCyan.opacity(0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.42
                    )
                )
                .frame(width: size * 0.84, height: size * 0.84)

            // Glass shine overlay
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.white.opacity(0.02),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .frame(width: size, height: size)

            // Echo resonance rings
            EchoRings(size: size)

            // Bio-Audio Waveform
            WaveformSymbol(size: size * 0.72)

            // Ambient particles
            AmbientParticles(size: size)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

// MARK: - Echo Resonance Rings

struct EchoRings: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Spectrum-tinted rings: warm inner → cool outer
            Circle()
                .stroke(AppIconGenerator.Design.spectrumOrange.opacity(0.08), lineWidth: size * 0.002)
                .frame(width: size * 0.2, height: size * 0.2)
                .offset(x: -size * 0.03)
            Circle()
                .stroke(AppIconGenerator.Design.spectrumGreen.opacity(0.07), lineWidth: size * 0.002)
                .frame(width: size * 0.36, height: size * 0.36)
                .offset(x: -size * 0.03)
            Circle()
                .stroke(AppIconGenerator.Design.spectrumCyan.opacity(0.05), lineWidth: size * 0.0015)
                .frame(width: size * 0.54, height: size * 0.54)
                .offset(x: -size * 0.03)
            Circle()
                .stroke(AppIconGenerator.Design.spectrumViolet.opacity(0.03), lineWidth: size * 0.0012)
                .frame(width: size * 0.74, height: size * 0.74)
                .offset(x: -size * 0.03)
        }
    }
}

// MARK: - Bio-Audio Waveform Symbol

struct WaveformSymbol: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Glow layer — rainbow spectrum
            WaveformPath()
                .stroke(
                    LinearGradient(
                        colors: AppIconGenerator.Design.glowGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: size * 0.03)
                .frame(width: size, height: size)

            // Main waveform stroke — rainbow spectrum
            WaveformPath()
                .stroke(
                    LinearGradient(
                        colors: AppIconGenerator.Design.spectrumGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: size * 0.016, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: AppIconGenerator.Design.spectrumGreen.opacity(0.4), radius: size * 0.01)
                .frame(width: size, height: size)

            // White specular highlight
            WaveformPath()
                .stroke(
                    Color.white.opacity(0.18),
                    style: StrokeStyle(lineWidth: size * 0.004, lineCap: .round, lineJoin: .round)
                )
                .frame(width: size, height: size)

            // Heart pulse dot at EKG R-peak
            ZStack {
                Circle()
                    .fill(AppIconGenerator.Design.heartColor.opacity(0.6))
                    .frame(width: size * 0.04, height: size * 0.04)
                    .blur(radius: size * 0.008)
                Circle()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: size * 0.016, height: size * 0.016)
            }
            .offset(x: -size * 0.3, y: -size * 0.22)
        }
    }
}

// MARK: - Waveform Path Shape

/// Bio-signal (EKG) morphing into audio sine wave.
/// Left: sharp angular QRS complex. Right: smooth sine curves.
struct WaveformPath: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cy = h * 0.5  // center baseline

        var path = Path()

        // Flat baseline lead-in
        path.move(to: CGPoint(x: w * 0.02, y: cy))
        path.addLine(to: CGPoint(x: w * 0.16, y: cy))

        // EKG QRS complex — sharp angular spikes
        path.addLine(to: CGPoint(x: w * 0.20, y: h * 0.28))   // R peak (sharp up)
        path.addLine(to: CGPoint(x: w * 0.24, y: h * 0.68))   // S valley (sharp down)
        path.addLine(to: CGPoint(x: w * 0.27, y: h * 0.39))   // secondary peak

        // Smooth return to baseline
        path.addCurve(
            to: CGPoint(x: w * 0.35, y: cy),
            control1: CGPoint(x: w * 0.29, y: h * 0.44),
            control2: CGPoint(x: w * 0.32, y: cy)
        )

        // Flat transition gap
        path.addLine(to: CGPoint(x: w * 0.40, y: cy))

        // Sine wave 1 — crest
        path.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.40),
            control1: CGPoint(x: w * 0.43, y: cy),
            control2: CGPoint(x: w * 0.47, y: h * 0.40)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.56, y: cy),
            control1: CGPoint(x: w * 0.53, y: h * 0.40),
            control2: CGPoint(x: w * 0.55, y: cy)
        )

        // Sine wave 1 — trough
        path.addCurve(
            to: CGPoint(x: w * 0.65, y: h * 0.60),
            control1: CGPoint(x: w * 0.58, y: cy),
            control2: CGPoint(x: w * 0.62, y: h * 0.60)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.71, y: cy),
            control1: CGPoint(x: w * 0.68, y: h * 0.60),
            control2: CGPoint(x: w * 0.70, y: cy)
        )

        // Sine wave 2 — crest (slightly larger amplitude)
        path.addCurve(
            to: CGPoint(x: w * 0.80, y: h * 0.38),
            control1: CGPoint(x: w * 0.73, y: cy),
            control2: CGPoint(x: w * 0.77, y: h * 0.38)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.86, y: cy),
            control1: CGPoint(x: w * 0.83, y: h * 0.38),
            control2: CGPoint(x: w * 0.85, y: cy)
        )

        // Flat ending
        path.addLine(to: CGPoint(x: w * 0.98, y: cy))

        return path
    }
}

// MARK: - Ambient Particles

struct AmbientParticles: View {
    let size: CGFloat

    // Spectrum-distributed particles: position maps to frequency → color
    private let particles: [(x: CGFloat, y: CGFloat, color: Int, opacity: Double)] = [
        (0.20, 0.34, 0, 0.18),  // rose (bio side)
        (0.24, 0.66, 1, 0.12),  // red
        (0.36, 0.25, 7, 0.18),  // white
        (0.31, 0.74, 0, 0.10),  // rose
        (0.51, 0.30, 2, 0.14),  // orange
        (0.55, 0.70, 3, 0.12),  // yellow
        (0.65, 0.37, 4, 0.16),  // green
        (0.71, 0.64, 5, 0.14),  // cyan
        (0.81, 0.42, 6, 0.14),  // blue
        (0.83, 0.61, 7, 0.12),  // violet
    ]

    private let colors: [Color] = [
        Color(red: 0.957, green: 0.447, blue: 0.714), // 0: rose (heart)
        Color(red: 0.937, green: 0.267, blue: 0.267), // 1: red (700nm)
        Color(red: 0.976, green: 0.451, blue: 0.086), // 2: orange (640nm)
        Color(red: 0.918, green: 0.702, blue: 0.031), // 3: yellow (585nm)
        Color(red: 0.133, green: 0.773, blue: 0.369), // 4: green (530nm)
        Color(red: 0.024, green: 0.714, blue: 0.831), // 5: cyan (485nm)
        Color(red: 0.231, green: 0.510, blue: 0.965), // 6: blue (440nm)
        Color(red: 0.545, green: 0.361, blue: 0.965), // 7: violet (410nm)
    ]

    var body: some View {
        ForEach(0..<particles.count, id: \.self) { i in
            let p = particles[i]
            Circle()
                .fill(p.color < 3 ? colors[p.color] : colors[p.color])
                .opacity(p.opacity)
                .frame(width: size * 0.008, height: size * 0.008)
                .offset(
                    x: (p.x - 0.5) * size,
                    y: (p.y - 0.5) * size
                )
        }
    }
}

// MARK: - Launch Screen View

public struct LaunchScreenView: View {
    @State private var isAnimating = false

    public init() {}

    public var body: some View {
        ZStack {
            // Background
            Color(red: 0.012, green: 0.027, blue: 0.071)
                .ignoresSafeArea()

            // Animated pulse rings — spectrum tinted
            ForEach(0..<5, id: \.self) { ring in
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                AppIconGenerator.Design.spectrumRed.opacity(0.2),
                                AppIconGenerator.Design.spectrumOrange.opacity(0.25),
                                AppIconGenerator.Design.spectrumYellow.opacity(0.25),
                                AppIconGenerator.Design.spectrumGreen.opacity(0.3),
                                AppIconGenerator.Design.spectrumCyan.opacity(0.25),
                                AppIconGenerator.Design.spectrumBlue.opacity(0.25),
                                AppIconGenerator.Design.spectrumViolet.opacity(0.2),
                                AppIconGenerator.Design.spectrumRed.opacity(0.2)
                            ],
                            center: .center
                        ),
                        lineWidth: 2
                    )
                    .frame(width: CGFloat(100 + ring * 80), height: CGFloat(100 + ring * 80))
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                    .opacity(isAnimating ? 0.8 : 0.4)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(ring) * 0.2),
                        value: isAnimating
                    )
            }

            VStack(spacing: 30) {
                // App icon
                AppIconView(size: 120)
                    .shadow(color: AppIconGenerator.Design.spectrumGreen.opacity(0.5), radius: 20)

                // App name
                Text("Echoelmusic")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Create from Within")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppIconGenerator.Design.spectrumRed,
                                AppIconGenerator.Design.spectrumOrange,
                                AppIconGenerator.Design.spectrumYellow,
                                AppIconGenerator.Design.spectrumGreen,
                                AppIconGenerator.Design.spectrumCyan,
                                AppIconGenerator.Design.spectrumBlue,
                                AppIconGenerator.Design.spectrumViolet
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppIconGenerator.Design.spectrumGreen))
                    .scaleEffect(1.2)
                    .padding(.top, 40)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Asset Catalog JSON Generator

public struct AssetCatalogGenerator {

    public static func generateContentsJSON() -> String {
        """
        {
          "images" : [
            {
              "filename" : "AppIcon-1024.png",
              "idiom" : "universal",
              "platform" : "ios",
              "size" : "1024x1024"
            },
            {
              "filename" : "AppIcon-macOS-512@2x.png",
              "idiom" : "mac",
              "scale" : "2x",
              "size" : "512x512"
            },
            {
              "filename" : "AppIcon-macOS-512.png",
              "idiom" : "mac",
              "scale" : "1x",
              "size" : "512x512"
            },
            {
              "filename" : "AppIcon-macOS-256@2x.png",
              "idiom" : "mac",
              "scale" : "2x",
              "size" : "256x256"
            },
            {
              "filename" : "AppIcon-macOS-256.png",
              "idiom" : "mac",
              "scale" : "1x",
              "size" : "256x256"
            },
            {
              "filename" : "AppIcon-macOS-128@2x.png",
              "idiom" : "mac",
              "scale" : "2x",
              "size" : "128x128"
            },
            {
              "filename" : "AppIcon-macOS-128.png",
              "idiom" : "mac",
              "scale" : "1x",
              "size" : "128x128"
            },
            {
              "filename" : "AppIcon-macOS-32@2x.png",
              "idiom" : "mac",
              "scale" : "2x",
              "size" : "32x32"
            },
            {
              "filename" : "AppIcon-macOS-32.png",
              "idiom" : "mac",
              "scale" : "1x",
              "size" : "32x32"
            },
            {
              "filename" : "AppIcon-macOS-16@2x.png",
              "idiom" : "mac",
              "scale" : "2x",
              "size" : "16x16"
            },
            {
              "filename" : "AppIcon-macOS-16.png",
              "idiom" : "mac",
              "scale" : "1x",
              "size" : "16x16"
            }
          ],
          "info" : {
            "author" : "Echoelmusic",
            "version" : 1
          }
        }
        """
    }

    public static func generateWatchContentsJSON() -> String {
        """
        {
          "images" : [
            {
              "filename" : "AppIcon-Watch-1024.png",
              "idiom" : "watch-marketing",
              "scale" : "1x",
              "size" : "1024x1024"
            },
            {
              "filename" : "AppIcon-Watch-108@2x.png",
              "idiom" : "watch",
              "role" : "quickLook",
              "scale" : "2x",
              "size" : "108x108",
              "subtype" : "49mm"
            },
            {
              "filename" : "AppIcon-Watch-98@2x.png",
              "idiom" : "watch",
              "role" : "quickLook",
              "scale" : "2x",
              "size" : "98x98",
              "subtype" : "45mm"
            },
            {
              "filename" : "AppIcon-Watch-86@2x.png",
              "idiom" : "watch",
              "role" : "quickLook",
              "scale" : "2x",
              "size" : "86x86",
              "subtype" : "41mm"
            }
          ],
          "info" : {
            "author" : "Echoelmusic",
            "version" : 1
          }
        }
        """
    }
}

// MARK: - Preview Provider

#if DEBUG
struct AppIconView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AppIconView(size: 1024)
                .previewLayout(.fixed(width: 1024, height: 1024))
                .previewDisplayName("App Icon 1024")

            AppIconView(size: 180)
                .previewLayout(.fixed(width: 180, height: 180))
                .previewDisplayName("App Icon 180")

            LaunchScreenView()
                .previewDisplayName("Launch Screen")
        }
    }
}
#endif

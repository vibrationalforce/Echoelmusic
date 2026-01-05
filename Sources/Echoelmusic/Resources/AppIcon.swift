//
//  AppIcon.swift
//  Echoelmusic
//
//  Programmatic App Icon Generation for All Platforms
//  A+++ Icon Design - Quantum Light Theme
//
//  Created: 2026-01-05
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

    // MARK: - Icon Design Constants

    public struct Design {
        public static let primaryColor = Color(red: 0.4, green: 0.2, blue: 0.8) // Deep purple
        public static let secondaryColor = Color(red: 0.2, green: 0.8, blue: 0.9) // Cyan
        public static let accentColor = Color(red: 0.9, green: 0.3, blue: 0.5) // Magenta
        public static let backgroundColor = Color(red: 0.05, green: 0.05, blue: 0.15) // Deep space

        public static let gradientColors: [Color] = [
            Color(red: 0.3, green: 0.1, blue: 0.6),
            Color(red: 0.5, green: 0.2, blue: 0.8),
            Color(red: 0.2, green: 0.6, blue: 0.9)
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
            // Background gradient
            RadialGradient(
                colors: [
                    Color(red: 0.2, green: 0.1, blue: 0.4),
                    Color(red: 0.05, green: 0.02, blue: 0.15)
                ],
                center: .center,
                startRadius: 0,
                endRadius: size * 0.7
            )

            // Quantum rings
            ForEach(0..<5, id: \.self) { ring in
                QuantumRing(
                    radius: size * 0.15 * CGFloat(ring + 1),
                    thickness: size * 0.008,
                    opacity: 0.3 - Double(ring) * 0.05
                )
            }

            // Center atom symbol
            AtomSymbol(size: size * 0.4)

            // Photon particles
            PhotonParticles(size: size)

            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.cyan.opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.3
                    )
                )
                .frame(width: size * 0.5, height: size * 0.5)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

struct QuantumRing: View {
    let radius: CGFloat
    let thickness: CGFloat
    let opacity: Double

    var body: some View {
        Circle()
            .stroke(
                AngularGradient(
                    colors: [
                        Color.purple.opacity(opacity),
                        Color.cyan.opacity(opacity * 0.7),
                        Color.purple.opacity(opacity)
                    ],
                    center: .center
                ),
                lineWidth: thickness
            )
            .frame(width: radius * 2, height: radius * 2)
    }
}

struct AtomSymbol: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Nucleus
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, Color.cyan],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.1
                    )
                )
                .frame(width: size * 0.15, height: size * 0.15)
                .shadow(color: .cyan, radius: size * 0.05)

            // Electron orbits
            ForEach(0..<3, id: \.self) { orbit in
                ElectronOrbit(
                    size: size,
                    rotation: Double(orbit) * 60
                )
            }
        }
    }
}

struct ElectronOrbit: View {
    let size: CGFloat
    let rotation: Double

    var body: some View {
        ZStack {
            // Orbit path
            Ellipse()
                .stroke(
                    LinearGradient(
                        colors: [.cyan.opacity(0.5), .purple.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: size * 0.015
                )
                .frame(width: size * 0.9, height: size * 0.35)

            // Electron
            Circle()
                .fill(Color.white)
                .frame(width: size * 0.08, height: size * 0.08)
                .shadow(color: .cyan, radius: size * 0.03)
                .offset(x: size * 0.4)
        }
        .rotationEffect(.degrees(rotation))
    }
}

struct PhotonParticles: View {
    let size: CGFloat

    var body: some View {
        ForEach(0..<12, id: \.self) { i in
            let angle = Double(i) * (360.0 / 12.0)
            let distance = size * 0.35
            let x = cos(angle * .pi / 180) * distance
            let y = sin(angle * .pi / 180) * distance

            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: size * 0.02, height: size * 0.02)
                .shadow(color: .cyan, radius: size * 0.01)
                .offset(x: x, y: y)
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
            Color(red: 0.05, green: 0.02, blue: 0.1)
                .ignoresSafeArea()

            // Animated rings
            ForEach(0..<5, id: \.self) { ring in
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.purple.opacity(0.3),
                                Color.cyan.opacity(0.2),
                                Color.purple.opacity(0.3)
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
                    .shadow(color: .purple.opacity(0.5), radius: 20)

                // App name
                Text("Echoelmusic")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Quantum Light Experience")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.cyan.opacity(0.8))

                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
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

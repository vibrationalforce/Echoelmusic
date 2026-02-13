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

    // MARK: - Icon Design Constants (Liquid Glass Theme)

    public struct Design {
        /// Green - Primary (#22C55E)
        public static let primaryColor = Color(red: 0.133, green: 0.773, blue: 0.369)
        /// Emerald - Secondary (#10B981)
        public static let secondaryColor = Color(red: 0.063, green: 0.725, blue: 0.506)
        /// Mint - Accent (#34D399)
        public static let accentColor = Color(red: 0.204, green: 0.827, blue: 0.6)
        /// Deep Space - Background (#030712)
        public static let backgroundColor = Color(red: 0.012, green: 0.027, blue: 0.071)

        public static let gradientColors: [Color] = [
            Color(red: 0.133, green: 0.773, blue: 0.369),  // green
            Color(red: 0.063, green: 0.725, blue: 0.506),  // emerald
            Color(red: 0.204, green: 0.827, blue: 0.6)     // mint
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
            // Background gradient - Liquid glass deep space
            LinearGradient(
                colors: [
                    Color(red: 0.012, green: 0.027, blue: 0.071),  // #030712
                    Color(red: 0.016, green: 0.102, blue: 0.055),  // #041a0e
                    Color(red: 0.012, green: 0.027, blue: 0.071)   // #030712
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Ambient glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.063, green: 0.725, blue: 0.506).opacity(0.15), // emerald
                            Color(red: 0.133, green: 0.773, blue: 0.369).opacity(0.08), // green
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
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.03),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .frame(width: size, height: size)

            // Outer quantum ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.133, green: 0.773, blue: 0.369).opacity(0.2),
                            Color(red: 0.133, green: 0.773, blue: 0.369).opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: size * 0.004
                )
                .frame(width: size * 0.8, height: size * 0.8)

            // Center atom symbol
            AtomSymbol(size: size * 0.68)

            // Photon particles
            PhotonParticles(size: size)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

struct AtomSymbol: View {
    let size: CGFloat

    private let orbitColors: [(primary: Color, highlight: Color)] = [
        (Color(red: 0.133, green: 0.773, blue: 0.369), Color(red: 0.133, green: 0.773, blue: 0.369)), // green
        (Color(red: 0.063, green: 0.725, blue: 0.506), Color(red: 0.063, green: 0.725, blue: 0.506)), // emerald
        (Color(red: 0.204, green: 0.827, blue: 0.6), Color(red: 0.204, green: 0.827, blue: 0.6))      // mint
    ]

    var body: some View {
        ZStack {
            // Nucleus glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.98),
                            Color.white.opacity(0.7),
                            Color(red: 0.133, green: 0.773, blue: 0.369).opacity(0.3), // green
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.1
                    )
                )
                .frame(width: size * 0.14, height: size * 0.14)

            // Nucleus core
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: size * 0.09, height: size * 0.09)

            // Glass highlight on nucleus
            Ellipse()
                .fill(Color.white.opacity(0.5))
                .frame(width: size * 0.05, height: size * 0.03)
                .offset(x: -size * 0.015, y: -size * 0.02)

            // Electron orbits
            ForEach(0..<3, id: \.self) { orbit in
                ElectronOrbit(
                    size: size,
                    rotation: Double(orbit) * 60,
                    orbitColor: orbitColors[orbit].primary,
                    electronGlow: orbitColors[orbit].highlight
                )
            }
        }
    }
}

struct ElectronOrbit: View {
    let size: CGFloat
    let rotation: Double
    let orbitColor: Color
    let electronGlow: Color

    var body: some View {
        ZStack {
            // Orbit path - gradient
            Ellipse()
                .stroke(
                    LinearGradient(
                        colors: [
                            orbitColor.opacity(0.8),
                            orbitColor.opacity(0.5),
                            orbitColor.opacity(0.2)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: size * 0.016
                )
                .frame(width: size * 0.96, height: size * 0.37)

            // White glass highlight stroke
            Ellipse()
                .stroke(Color.white.opacity(0.2), lineWidth: size * 0.003)
                .frame(width: size * 0.96, height: size * 0.37)

            // Electron with glow halo
            ZStack {
                Circle()
                    .fill(electronGlow.opacity(0.25))
                    .frame(width: size * 0.08, height: size * 0.08)
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: size * 0.056, height: size * 0.056)
            }
            .offset(x: size * 0.48)
        }
        .rotationEffect(.degrees(rotation))
    }
}

struct PhotonParticles: View {
    let size: CGFloat

    private let particleColors: [Color] = [
        Color(red: 0.133, green: 0.773, blue: 0.369), // green
        Color(red: 0.063, green: 0.725, blue: 0.506), // emerald
        Color(red: 0.204, green: 0.827, blue: 0.6),   // mint
        Color(red: 0.133, green: 0.773, blue: 0.369),
        Color(red: 0.063, green: 0.725, blue: 0.506),
        Color(red: 0.204, green: 0.827, blue: 0.6),
        Color(red: 0.133, green: 0.773, blue: 0.369),
        Color(red: 0.063, green: 0.725, blue: 0.506)
    ]

    var body: some View {
        ForEach(0..<8, id: \.self) { i in
            let angle = Double(i) * (360.0 / 8.0)
            let distance = size * 0.38
            let x = cos(angle * .pi / 180) * distance
            let y = sin(angle * .pi / 180) * distance

            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: size * 0.012, height: size * 0.012)
                .shadow(color: particleColors[i].opacity(0.4), radius: size * 0.008)
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
            // Background - Liquid glass deep space
            Color(red: 0.012, green: 0.027, blue: 0.071) // #030712
                .ignoresSafeArea()

            // Animated rings - Green liquid glass
            ForEach(0..<5, id: \.self) { ring in
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(red: 0.133, green: 0.773, blue: 0.369).opacity(0.3), // green
                                Color(red: 0.063, green: 0.725, blue: 0.506).opacity(0.2), // emerald
                                Color(red: 0.133, green: 0.773, blue: 0.369).opacity(0.3)  // green
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
                    .shadow(color: Color(red: 0.133, green: 0.773, blue: 0.369).opacity(0.5), radius: 20) // green

                // App name
                Text("Echoelmusic")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Create from Within")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.063, green: 0.725, blue: 0.506).opacity(0.8)) // emerald

                // Loading indicator - emerald
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.063, green: 0.725, blue: 0.506)))
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

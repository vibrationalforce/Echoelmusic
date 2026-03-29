#if canImport(SwiftUI)
//
//  AppIcon.swift
//  Echoelmusic
//

// MARK: - Brand Wave Shape (inlined from deleted EchoelWaveDesign.swift)

import SwiftUI

/// SVG-matched triple S-curve wave for app icon and brand mark.
struct EchoelBrandWaveShape: Shape {
    var waveIndex: Int

    init(waveIndex: Int = 0) {
        self.waveIndex = waveIndex
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        func x(_ v: CGFloat) -> CGFloat { (v / 1024.0) * w }
        func y(_ v: CGFloat) -> CGFloat { (v / 1024.0) * h }
        let centerY: CGFloat = 610.0 + CGFloat(waveIndex) * 100.0

        var path = Path()
        path.move(to: CGPoint(x: x(245), y: y(centerY)))
        path.addCurve(to: CGPoint(x: x(425), y: y(centerY)),
                       control1: CGPoint(x: x(295), y: y(centerY - 55)),
                       control2: CGPoint(x: x(375), y: y(centerY - 55)))
        path.addCurve(to: CGPoint(x: x(599), y: y(centerY)),
                       control1: CGPoint(x: x(475), y: y(centerY + 55)),
                       control2: CGPoint(x: x(549), y: y(centerY + 55)))
        path.addCurve(to: CGPoint(x: x(779), y: y(centerY)),
                       control1: CGPoint(x: x(649), y: y(centerY - 55)),
                       control2: CGPoint(x: x(729), y: y(centerY - 55)))
        return path
    }
}

/// Complete brand mark: "E" letter + 3 sine waves on black background.
struct EchoelWaveformMark: View {
    var animated: Bool = false

    private let brandColor = Color(white: 0.878)
    private let waveOpacities: [CGFloat] = [0.8, 0.4, 0.2]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                Color.black
                Text("E")
                    .font(.system(size: size * 0.52, weight: .bold))
                    .foregroundColor(brandColor)
                    .offset(y: -size * 0.05)

                ForEach(0..<3, id: \.self) { i in
                    EchoelBrandWaveShape(waveIndex: i)
                        .stroke(brandColor.opacity(waveOpacities[i]),
                                style: StrokeStyle(lineWidth: max(2, size * 0.03), lineCap: .round))
                }
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
//  Programmatic App Icon Generation for All Platforms
//  Monochrome E + 3 waves — matches echoelmusic.com
//
//  Created: 2026-01-05
//  Updated: 2026-03-17
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

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

    // MARK: - Icon Design Constants (Monochrome — matches echoelmusic.com)
    // E + 3 sine wave curves, #E0E0E0 on #000000

    public struct Design {
        /// Primary brand color — #E0E0E0 (light gray)
        public static let primaryColor = Color(white: 0.878)
        /// Background — true black #000000
        public static let backgroundColor = Color.black
    }
}

// MARK: - SwiftUI App Icon View

/// App icon matching echoelmusic.com: "E" + 3 sine wave curves, monochrome #E0E0E0 on #000.
/// Uses EchoelBrandWaveShape from EchoelWaveDesign.swift for consistent wave rendering.
public struct AppIconView: View {
    let size: CGFloat

    public init(size: CGFloat = 1024) {
        self.size = size
    }

    /// Brand color — #E0E0E0
    private let brandColor = Color(white: 0.878)
    /// Wave opacities matching website SVG: 0.8, 0.4, 0.2
    private let waveOpacities: [CGFloat] = [0.8, 0.4, 0.2]

    public var body: some View {
        ZStack {
            // True black background
            Color.black

            // "E" letter — positioned in upper portion (matching SVG y≈46%)
            Text("E")
                .font(.system(size: size * 0.42, weight: .bold, design: .default))
                .foregroundColor(brandColor)
                .offset(y: -size * 0.1)

            // Three sine wave curves underneath
            ForEach(0..<3, id: \.self) { i in
                let strokeW = max(2, size * 0.03)

                // Soft glow layer (wider, subtle)
                EchoelBrandWaveShape(waveIndex: i)
                    .stroke(
                        brandColor.opacity(waveOpacities[i] * 0.2),
                        style: StrokeStyle(lineWidth: strokeW * 1.5, lineCap: .round)
                    )

                // Main stroke
                EchoelBrandWaveShape(waveIndex: i)
                    .stroke(
                        brandColor.opacity(waveOpacities[i]),
                        style: StrokeStyle(lineWidth: strokeW, lineCap: .round)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

// MARK: - Launch Screen View

/// Launch screen matching echoelmusic.com: monochrome E + waves on black.
public struct LaunchScreenView: View {

    public init() {}

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // Brand mark — E + 3 waves (matches website)
                EchoelWaveformMark(animated: false)
                    .frame(width: 120, height: 120)

                // App name
                Text("Echoelmusic")
                    .font(.system(size: 36, weight: .bold, design: .default))
                    .foregroundColor(Color(white: 0.878))

                Text("Create from Within")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(white: 0.878).opacity(0.55))

                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(white: 0.878)))
                    .scaleEffect(1.2)
                    .padding(.top, 40)
            }
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
#endif

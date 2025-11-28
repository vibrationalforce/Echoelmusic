//
//  ColorExtensions.swift
//  Echoelmusic
//
//  Essential Color Utilities
//  Hex string parsing, serialization, common conversions
//

import SwiftUI

extension Color {

    // MARK: - Hex Initialization

    /// Initialize Color from hex string
    /// Supports: "#RRGGBB", "RRGGBB", "#RRGGBBAA", "RRGGBBAA"
    /// - Parameter hex: Hex color string
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0

        guard Scanner(string: hex).scanHexInt64(&int) else {
            return nil
        }

        let r, g, b, a: UInt64
        switch hex.count {
        case 6: // RGB (e.g., "FF5733")
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8: // RGBA (e.g., "FF5733FF")
            (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }

    // MARK: - Hex String Conversion

    /// Convert Color to hex string
    /// - Parameter includeAlpha: Include alpha channel in output (default: false)
    /// - Returns: Hex string (e.g., "#FF5733" or "#FF5733FF")
    func toHex(includeAlpha: Bool = false) -> String {
        #if canImport(UIKit)
        guard let components = UIColor(self).cgColor.components else {
            return includeAlpha ? "#000000FF" : "#000000"
        }
        #elseif canImport(AppKit)
        guard let components = NSColor(self).cgColor.components else {
            return includeAlpha ? "#000000FF" : "#000000"
        }
        #endif

        let r = Int((components[0]) * 255.0)
        let g = Int((components.count > 1 ? components[1] : 0) * 255.0)
        let b = Int((components.count > 2 ? components[2] : 0) * 255.0)
        let a = Int((components.count > 3 ? components[3] : 1) * 255.0)

        if includeAlpha {
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        } else {
            return String(format: "#%02X%02X%02X", r, g, b)
        }
    }

    // MARK: - Color Adjustments

    /// Lighten color by percentage
    /// - Parameter percentage: 0.0 to 1.0
    /// - Returns: Lightened color
    func lighter(by percentage: Double = 0.2) -> Color {
        return adjust(by: abs(percentage))
    }

    /// Darken color by percentage
    /// - Parameter percentage: 0.0 to 1.0
    /// - Returns: Darkened color
    func darker(by percentage: Double = 0.2) -> Color {
        return adjust(by: -abs(percentage))
    }

    private func adjust(by percentage: Double) -> Color {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        return Color(
            hue: Double(h),
            saturation: Double(s),
            brightness: min(max(Double(b) + percentage, 0.0), 1.0),
            opacity: Double(a)
        )
        #elseif canImport(AppKit)
        let nsColor = NSColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        return Color(
            hue: Double(h),
            saturation: Double(s),
            brightness: min(max(Double(b) + percentage, 0.0), 1.0),
            opacity: Double(a)
        )
        #endif
    }

    // MARK: - Predefined Colors with Hex

    /// Vaporwave color palette
    struct Vaporwave {
        static let neonPink = Color(hex: "FF1493")!
        static let neonPurple = Color(hex: "9400FF")!
        static let neonCyan = Color(hex: "00FAFF")!
        static let sunsetOrange = Color(hex: "FF6B35")!
        static let pastelPurple = Color(hex: "C996CC")!
        static let pastelPink = Color(hex: "FFB3D9")!
        static let darkPurple = Color(hex: "1A0933")!
        static let darkBlue = Color(hex: "0A0E27")!
        static let chrome = Color(hex: "E0E0E0")!
    }

    // MARK: - Utility

    /// Check if color is "dark" (luminance < 0.5)
    var isDark: Bool {
        #if canImport(UIKit)
        guard let components = UIColor(self).cgColor.components else { return true }
        #elseif canImport(AppKit)
        guard let components = NSColor(self).cgColor.components else { return true }
        #endif

        let r = components[0]
        let g = components.count > 1 ? components[1] : 0
        let b = components.count > 2 ? components[2] : 0

        // Calculate relative luminance
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance < 0.5
    }

    /// Get contrasting color (black or white) for text
    var contrastingTextColor: Color {
        return isDark ? .white : .black
    }
}

// MARK: - Codable Support

extension Color: Codable {
    enum CodingKeys: String, CodingKey {
        case hex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hex = try container.decode(String.self, forKey: .hex)

        guard let color = Color(hex: hex) else {
            throw DecodingError.dataCorruptedError(
                forKey: .hex,
                in: container,
                debugDescription: "Invalid hex color string: \(hex)"
            )
        }

        self = color
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.toHex(includeAlpha: true), forKey: .hex)
    }
}

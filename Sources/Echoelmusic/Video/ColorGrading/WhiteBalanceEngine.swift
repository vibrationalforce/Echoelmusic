import Foundation
import CoreImage
import Metal
import simd

/// Professional White Balance Engine for Cinema-Grade Video Production
///
/// Features:
/// - Temperature control (2500K - 10000K)
/// - Industry-standard presets (3200K Tungsten, 5600K Daylight, 5500K Flash)
/// - Tint adjustment (green/magenta shift)
/// - Auto white balance with color picker
/// - Custom preset storage
/// - Real-time preview
///
/// Color Temperature Science:
/// - 2500K-3000K: Warm tungsten/candlelight (orange)
/// - 3200K: Standard tungsten indoor lighting 🔥
/// - 5500K: Flash/studio lighting
/// - 5600K: Daylight/outdoor ☀️
/// - 6500K: Overcast daylight
/// - 10000K: Blue sky/shade
@MainActor
class WhiteBalanceEngine: ObservableObject {

    // MARK: - Published State

    /// Current color temperature in Kelvin (2500K - 10000K)
    @Published var temperature: Float = 5600.0  // Default: Daylight

    /// Tint adjustment (-1.0 to +1.0, negative = green, positive = magenta)
    @Published var tint: Float = 0.0

    /// Currently selected preset
    @Published var currentPreset: WhiteBalancePreset = .daylight

    /// Custom saved presets
    @Published var customPresets: [CustomPreset] = []


    // MARK: - White Balance Presets

    enum WhiteBalancePreset: String, CaseIterable {
        case tungsten = "Tungsten (3200K)"
        case daylight = "Daylight (5600K)"
        case flash = "Flash (5500K)"
        case cloudy = "Cloudy (6500K)"
        case shade = "Shade (7500K)"
        case fluorescent = "Fluorescent (4000K)"
        case candlelight = "Candlelight (2500K)"
        case custom = "Custom"

        var temperature: Float {
            switch self {
            case .candlelight: return 2500.0
            case .tungsten: return 3200.0  // 🔥 Indoor tungsten
            case .fluorescent: return 4000.0
            case .flash: return 5500.0
            case .daylight: return 5600.0  // ☀️ Outdoor daylight
            case .cloudy: return 6500.0
            case .shade: return 7500.0
            case .custom: return 5600.0    // Default to daylight
            }
        }

        var icon: String {
            switch self {
            case .candlelight: return "🕯️"
            case .tungsten: return "💡"
            case .fluorescent: return "💡"
            case .flash: return "⚡"
            case .daylight: return "☀️"
            case .cloudy: return "☁️"
            case .shade: return "🌳"
            case .custom: return "⭐"
            }
        }
    }

    struct CustomPreset: Identifiable, Codable {
        let id: UUID
        let name: String
        let temperature: Float
        let tint: Float
        let createdAt: Date

        init(name: String, temperature: Float, tint: Float) {
            self.id = UUID()
            self.name = name
            self.temperature = temperature
            self.tint = tint
            self.createdAt = Date()
        }
    }


    // MARK: - Core Image Context

    private let ciContext: CIContext
    private let device: MTLDevice


    // MARK: - Initialization

    init() {
        // Get Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal not available")
        }

        self.device = device
        self.ciContext = CIContext(mtlDevice: device, options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .cacheIntermediates: false
        ])

        // Load custom presets
        loadCustomPresets()

        print("✅ WhiteBalanceEngine initialized")
        print("   Default: \(currentPreset.rawValue)")
    }


    // MARK: - Public API

    /// Apply white balance to image
    func apply(to image: CIImage) -> CIImage {
        // Convert temperature to RGB multipliers
        let rgb = temperatureToRGB(temperature)

        // Apply tint (green/magenta shift)
        let tintedRGB = applyTint(rgb: rgb, tint: tint)

        // Create color matrix filter
        guard let filter = CIFilter(name: "CIColorMatrix") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)

        // Red channel
        filter.setValue(CIVector(x: CGFloat(tintedRGB.x), y: 0, z: 0, w: 0), forKey: "inputRVector")

        // Green channel
        filter.setValue(CIVector(x: 0, y: CGFloat(tintedRGB.y), z: 0, w: 0), forKey: "inputGVector")

        // Blue channel
        filter.setValue(CIVector(x: 0, y: 0, z: CGFloat(tintedRGB.z), w: 0), forKey: "inputBVector")

        // Alpha channel (unchanged)
        filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")

        return filter.outputImage ?? image
    }

    /// Set white balance preset
    func setPreset(_ preset: WhiteBalancePreset) {
        currentPreset = preset
        temperature = preset.temperature
        tint = 0.0  // Reset tint when changing presets

        print("🎨 White Balance: \(preset.rawValue)")
    }

    /// Auto white balance from color sample
    /// - Parameter color: Sample color from neutral gray area
    func autoBalance(from color: SIMD3<Float>) {
        // Calculate temperature from color
        // Neutral gray should be (0.5, 0.5, 0.5)
        // If blue > red, scene is too warm (low temp needed)
        // If red > blue, scene is too cool (high temp needed)

        let redBlueDiff = color.x - color.z

        // Map difference to temperature range
        // Positive diff (red > blue) → increase temp (warmer)
        // Negative diff (blue > red) → decrease temp (cooler)
        let tempAdjustment = redBlueDiff * 2000.0  // Scale factor

        temperature = clamp(5600.0 + tempAdjustment, min: 2500.0, max: 10000.0)

        // Calculate tint from green channel
        let greenDeviation = (color.y - 0.5) * 2.0  // -1 to +1
        tint = clamp(-greenDeviation, min: -1.0, max: 1.0)

        currentPreset = .custom

        print("🎨 Auto White Balance: \(Int(temperature))K, Tint: \(String(format: "%.2f", tint))")
    }

    /// Save current settings as custom preset
    func saveCustomPreset(name: String) {
        let preset = CustomPreset(
            name: name,
            temperature: temperature,
            tint: tint
        )

        customPresets.append(preset)
        saveCustomPresets()

        print("💾 Saved custom preset: \(name)")
    }

    /// Load custom preset
    func loadCustomPreset(_ preset: CustomPreset) {
        temperature = preset.temperature
        tint = preset.tint
        currentPreset = .custom

        print("📂 Loaded custom preset: \(preset.name)")
    }

    /// Delete custom preset
    func deleteCustomPreset(_ preset: CustomPreset) {
        customPresets.removeAll { $0.id == preset.id }
        saveCustomPresets()

        print("🗑️ Deleted custom preset: \(preset.name)")
    }


    // MARK: - Color Temperature Algorithm

    /// Convert color temperature (Kelvin) to RGB multipliers
    /// Based on Tanner Helland's algorithm
    /// http://www.tannerhelland.com/4435/convert-temperature-rgb-algorithm-code/
    private func temperatureToRGB(_ kelvin: Float) -> SIMD3<Float> {
        let temp = kelvin / 100.0

        var red: Float
        var green: Float
        var blue: Float

        // Red
        if temp <= 66 {
            red = 1.0
        } else {
            red = temp - 60.0
            red = 329.698727446 * pow(red, -0.1332047592)
            red = clamp(red / 255.0, min: 0.0, max: 1.0)
        }

        // Green
        if temp <= 66 {
            green = temp
            green = 99.4708025861 * log(green) - 161.1195681661
            green = clamp(green / 255.0, min: 0.0, max: 1.0)
        } else {
            green = temp - 60.0
            green = 288.1221695283 * pow(green, -0.0755148492)
            green = clamp(green / 255.0, min: 0.0, max: 1.0)
        }

        // Blue
        if temp >= 66 {
            blue = 1.0
        } else if temp <= 19 {
            blue = 0.0
        } else {
            blue = temp - 10.0
            blue = 138.5177312231 * log(blue) - 305.0447927307
            blue = clamp(blue / 255.0, min: 0.0, max: 1.0)
        }

        return SIMD3<Float>(red, green, blue)
    }

    /// Apply tint (green/magenta shift) to RGB multipliers
    private func applyTint(rgb: SIMD3<Float>, tint: Float) -> SIMD3<Float> {
        var result = rgb

        if tint < 0 {
            // Green shift (increase green, decrease magenta)
            result.y *= 1.0 + abs(tint) * 0.3  // Increase green
            result.x *= 1.0 - abs(tint) * 0.15 // Decrease red
            result.z *= 1.0 - abs(tint) * 0.15 // Decrease blue
        } else if tint > 0 {
            // Magenta shift (increase red+blue, decrease green)
            result.x *= 1.0 + tint * 0.15      // Increase red
            result.z *= 1.0 + tint * 0.15      // Increase blue
            result.y *= 1.0 - tint * 0.3       // Decrease green
        }

        return result
    }

    /// Clamp value to range
    private func clamp(_ value: Float, min: Float, max: Float) -> Float {
        return Swift.max(min, Swift.min(max, value))
    }


    // MARK: - Persistence

    private func saveCustomPresets() {
        if let encoded = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(encoded, forKey: "WhiteBalanceCustomPresets")
        }
    }

    private func loadCustomPresets() {
        if let data = UserDefaults.standard.data(forKey: "WhiteBalanceCustomPresets"),
           let decoded = try? JSONDecoder().decode([CustomPreset].self, from: data) {
            customPresets = decoded
        }
    }


    // MARK: - Utility

    /// Get descriptive name for current temperature
    func temperatureDescription() -> String {
        switch temperature {
        case 2500..<3000:
            return "Warm Candlelight"
        case 3000..<3500:
            return "Tungsten Indoor"
        case 3500..<4500:
            return "Warm White"
        case 4500..<5000:
            return "Cool White"
        case 5000..<6000:
            return "Daylight"
        case 6000..<7000:
            return "Overcast"
        case 7000..<8000:
            return "Shade"
        default:
            return "Blue Sky"
        }
    }

    /// Get color swatch for current temperature
    func temperatureColor() -> SIMD3<Float> {
        return temperatureToRGB(temperature)
    }
}


// MARK: - Preview Helpers

#if DEBUG
extension WhiteBalanceEngine {
    static var preview: WhiteBalanceEngine {
        let engine = WhiteBalanceEngine()
        engine.temperature = 5600.0  // Daylight
        engine.tint = 0.0
        return engine
    }
}
#endif

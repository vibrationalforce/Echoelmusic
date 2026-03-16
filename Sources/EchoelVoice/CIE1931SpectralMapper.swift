#if canImport(CoreGraphics)
import Foundation
import CoreGraphics

/// Maps audio frequencies to visible light colors via CIE 1931 octave transposition
///
/// Physics: Audio frequencies are transposed up ~40 octaves into the visible
/// electromagnetic spectrum (380-780nm). Each audio frequency band maps to
/// a specific wavelength of light.
///
/// Reference: CIE 1931 color matching functions, octave transposition method
///
/// Audio Band → Wavelength → RGB:
/// - Sub-Bass  (~40 Hz)    → 700nm → Red
/// - Bass      (~125 Hz)   → 640nm → Orange
/// - Low-Mid   (~355 Hz)   → 585nm → Yellow
/// - Mid       (~1 kHz)    → 530nm → Green
/// - Upper-Mid (~2.8 kHz)  → 485nm → Cyan
/// - Presence  (~5.6 kHz)  → 450nm → Blue
/// - Brilliance(~8 kHz)    → 430nm → Indigo
/// - Air       (~12.6 kHz) → 410nm → Violet
struct CIE1931SpectralMapper {

    /// RGB color result (0-1 range)
    struct SpectralColor {
        var r: Float
        var g: Float
        var b: Float
        var brightness: Float  // Overall intensity

        static let black = SpectralColor(r: 0, g: 0, b: 0, brightness: 0)
    }

    /// Band-to-wavelength mapping (pre-calculated)
    /// Index matches VocalDSPKernel.spectralBands tuple order
    private static let bandWavelengths: [Float] = [
        700,  // Sub-Bass  → Red
        640,  // Bass      → Orange
        585,  // Low-Mid   → Yellow
        530,  // Mid       → Green
        485,  // Upper-Mid → Cyan
        450,  // Presence  → Blue
        430,  // Brilliance→ Indigo
        410   // Air       → Violet
    ]

    /// Convert a wavelength (380-780nm) to RGB using CIE 1931 approximation
    /// Based on Dan Bruton's wavelength-to-RGB algorithm
    static func wavelengthToRGB(_ wavelength: Float) -> (r: Float, g: Float, b: Float) {
        var r: Float = 0
        var g: Float = 0
        var b: Float = 0

        if wavelength >= 380 && wavelength < 440 {
            r = -(wavelength - 440) / (440 - 380)
            g = 0
            b = 1.0
        } else if wavelength >= 440 && wavelength < 490 {
            r = 0
            g = (wavelength - 440) / (490 - 440)
            b = 1.0
        } else if wavelength >= 490 && wavelength < 510 {
            r = 0
            g = 1.0
            b = -(wavelength - 510) / (510 - 490)
        } else if wavelength >= 510 && wavelength < 580 {
            r = (wavelength - 510) / (580 - 510)
            g = 1.0
            b = 0
        } else if wavelength >= 580 && wavelength < 645 {
            r = 1.0
            g = -(wavelength - 645) / (645 - 580)
            b = 0
        } else if wavelength >= 645 && wavelength <= 780 {
            r = 1.0
            g = 0
            b = 0
        }

        // Intensity falloff at edges of visible spectrum
        var intensity: Float = 1.0
        if wavelength >= 380 && wavelength < 420 {
            intensity = 0.3 + 0.7 * (wavelength - 380) / (420 - 380)
        } else if wavelength >= 645 && wavelength <= 780 {
            intensity = 0.3 + 0.7 * (780 - wavelength) / (780 - 645)
        }

        return (r * intensity, g * intensity, b * intensity)
    }

    /// Map audio frequency (Hz) to a visible light wavelength (nm)
    /// Uses octave transposition: ~40 octaves up from audio to light
    static func frequencyToWavelength(_ frequency: Float) -> Float {
        guard frequency > 20 else { return 700 }  // Below hearing → red
        guard frequency < 20000 else { return 380 }  // Above hearing → violet

        // Logarithmic mapping: 20Hz→700nm, 20kHz→380nm
        let logMin: Float = Foundation.log(20.0)
        let logMax: Float = Foundation.log(20000.0)
        let logFreq = Foundation.log(frequency)

        let t = (logFreq - logMin) / (logMax - logMin)  // 0 (low) to 1 (high)
        return 700 - t * (700 - 380)  // Red to Violet
    }

    /// Convert spectral band energies to a blended color
    /// Each band contributes its CIE wavelength color weighted by energy
    static func bandsToColor(
        _ bands: (Float, Float, Float, Float, Float, Float, Float, Float)
    ) -> SpectralColor {
        let bandArray = [bands.0, bands.1, bands.2, bands.3,
                         bands.4, bands.5, bands.6, bands.7]

        var totalR: Float = 0
        var totalG: Float = 0
        var totalB: Float = 0
        var totalWeight: Float = 0

        for i in 0..<8 {
            let energy = bandArray[i]
            guard energy > 0.001 else { continue }

            let (r, g, b) = wavelengthToRGB(bandWavelengths[i])
            totalR += r * energy
            totalG += g * energy
            totalB += b * energy
            totalWeight += energy
        }

        guard totalWeight > 0.001 else { return .black }

        // Normalize
        let maxComponent = max(totalR, max(totalG, totalB))
        let scale: Float = maxComponent > 0 ? 1.0 / maxComponent : 0

        return SpectralColor(
            r: min(1.0, totalR * scale),
            g: min(1.0, totalG * scale),
            b: min(1.0, totalB * scale),
            brightness: min(1.0, totalWeight * 2.0)
        )
    }

    /// Get color for a single dominant frequency
    static func colorForFrequency(_ frequency: Float, energy: Float) -> SpectralColor {
        let wavelength = frequencyToWavelength(frequency)
        let (r, g, b) = wavelengthToRGB(wavelength)
        return SpectralColor(
            r: r,
            g: g,
            b: b,
            brightness: min(1.0, energy * 2.0)
        )
    }

    /// Convert SpectralColor to CGColor for Core Graphics rendering
    static func toCGColor(_ color: SpectralColor) -> CGColor {
        CGColor(
            red: CGFloat(color.r * color.brightness),
            green: CGFloat(color.g * color.brightness),
            blue: CGFloat(color.b * color.brightness),
            alpha: 1.0
        )
    }
}
#endif

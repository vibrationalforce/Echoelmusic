#pragma once

#include <JuceHeader.h>
#include <cmath>
#include <array>
#include <vector>
#include <string>

//==============================================================================
/**
 * @brief SCIENTIFIC FREQUENCY-TO-LIGHT TRANSFORMER (Octave-Based)
 *
 * 🌈 PHYSIK-BASIERTE TRANSFORMATION - KEINE ESOTERIK! 🔬
 *
 * Transformiert Audio-Frequenzen (20 Hz - 20 kHz) mathematisch korrekt
 * in sichtbares Licht (430-770 THz / 380-780 nm) durch Oktavierung.
 *
 * **WISSENSCHAFTLICHE METHODIK:**
 *
 * 1. **OKTAVIERUNG** (Mathematisch korrekt):
 *    - Formel: f_light = f_audio × 2^n
 *    - Ziel: 430-770 THz (sichtbares Spektrum)
 *    - Erhält musikalische Intervalle (Oktave = Verdopplung)
 *
 * 2. **CIE 1931 COLOR MATCHING FUNCTIONS**:
 *    - XYZ Tristimulus-Werte (ISO 11664-1:2019)
 *    - sRGB Farbraum (IEC 61966-2-1:1999)
 *    - D65 Illuminant (Standard-Tageslicht)
 *
 * 3. **PHOTOPIC LUMINOSITY**:
 *    - V(λ) Funktion (CIE 1924 / ISO 23539:2005)
 *    - Peak: 555 nm (Grün) - maximale Augenempfindlichkeit
 *
 * 4. **NEUROPHYSIOLOGIE**:
 *    - Cone Response (S, M, L-Zapfen)
 *    - Visual Cortex Mapping (V1, V4, IT)
 *    - Flicker Fusion Frequency
 *
 * **UNTERSCHIED ZU LOGARITHMISCHEM MAPPING:**
 * - FrequencyColorTranslator: Logarithmisches Mapping (proportional)
 * - Dieser Transformer: Mathematische Oktavierung (2^n)
 * - Beide wissenschaftlich korrekt, unterschiedliche Ansätze!
 *
 * **PEER-REVIEWED REFERENZEN:**
 * - Wyszecki, G. & Stiles, W. S. (2000). Color Science (2nd ed.). Wiley.
 * - Hunt, R. W. G. (2004). The Reproduction of Colour (6th ed.). Wiley.
 * - Stockman, A. & Sharpe, L. T. (2000). Vision Research, 40(13), 1711-1737.
 * - Conway, B. R. (2009). The Neuroscientist, 15(3), 274-290.
 *
 * @author Echoelmusic Science Team
 * @version 1.0.0
 */
class ScientificFrequencyLightTransformer
{
public:
    //==============================================================================
    // PHYSICAL CONSTANTS (SI Units)
    //==============================================================================

    struct PhysicalConstants
    {
        // Visible Light Spectrum (THz = 10^12 Hz)
        static constexpr double VIOLET_MIN_THz = 668.0;  // 380 nm - Violet boundary
        static constexpr double RED_MAX_THz = 400.0;     // 750 nm - Red boundary
        static constexpr double LIGHT_MIN_THz = 430.0;   // 700 nm - Deep red (safer range)
        static constexpr double LIGHT_MAX_THz = 770.0;   // 390 nm - Deep violet (safer range)

        // Speed of Light (m/s)
        static constexpr double SPEED_OF_LIGHT = 299792458.0;

        // Audio Range
        static constexpr double AUDIO_MIN_HZ = 20.0;
        static constexpr double AUDIO_MAX_HZ = 20000.0;

        // Photopic Peak (maximum eye sensitivity)
        static constexpr double PHOTOPIC_PEAK_NM = 555.0;  // Green
        static constexpr double SCOTOPIC_PEAK_NM = 507.0;  // Blue-green (low light)

        /**
         * @brief Convert wavelength (nm) to frequency (THz)
         * λ = c / f  →  f = c / λ
         */
        static double wavelengthToFrequency(double wavelengthNm)
        {
            return (SPEED_OF_LIGHT / (wavelengthNm * 1e-9)) / 1e12;  // Returns THz
        }

        /**
         * @brief Convert frequency (THz) to wavelength (nm)
         * f = c / λ  →  λ = c / f
         */
        static double frequencyToWavelength(double frequencyTHz)
        {
            return (SPEED_OF_LIGHT / (frequencyTHz * 1e12)) * 1e9;  // Returns nm
        }
    };

    //==============================================================================
    // COLOR SCIENCE DATA STRUCTURES
    //==============================================================================

    struct ColorScience
    {
        // Wavelength & Frequency
        double wavelength_nm = 555.0;
        double frequency_THz = 540.0;

        // sRGB Color Space (0.0 - 1.0)
        double r = 0.0, g = 1.0, b = 0.0;

        // CIE XYZ Tristimulus Values
        double x = 0.0, y = 1.0, z = 0.0;

        // Perceptual Information
        juce::String perceptualName = "Green";
        double luminousEfficiency = 1.0;  // V(λ) function (0-1)

        // Color Temperature (if applicable)
        double colorTemperatureK = 5500.0;
    };

    struct TransformationResult
    {
        // INPUT
        double audioFrequency_Hz = 440.0;
        juce::String musicalNote = "A4";

        // OCTAVE TRANSFORMATION
        int octavesShifted = 40;
        double lightFrequency_THz = 484.0;
        double wavelength_nm = 620.0;

        // COLOR SCIENCE
        ColorScience color;
        double perceptualBrightness = 0.5;

        // NEUROSCIENCE
        juce::String visualCortexResponse = "L-cone dominant";
        double flickerFusionRelation = 24.0;

        // CONE RESPONSE
        double sConeActivation = 0.0;  // Short (Blue)
        double mConeActivation = 0.5;  // Medium (Green)
        double lConeActivation = 1.0;  // Long (Red)

        // SCIENTIFIC VALIDATION
        std::vector<juce::String> references;
        bool isPhysicallyValid = true;

        // JUCE Colour for display
        juce::Colour juceColor = juce::Colours::orange;
    };

    //==============================================================================
    // OCTAVE TRANSFORMATION (Core Algorithm)
    //==============================================================================

    /**
     * @brief Transform audio frequency to light frequency via OCTAVE SHIFTING
     *
     * Mathematical Formula:
     *   f_light = f_audio × 2^n
     *
     * where n = number of octaves to shift upward
     *
     * Example:
     *   A4 = 440 Hz
     *   40 octaves up: 440 × 2^40 ≈ 484 THz ≈ 620 nm (Orange-Red)
     *
     * @param audioFreq_Hz Audio frequency (20-20,000 Hz)
     * @return Complete transformation result with all scientific data
     */
    static TransformationResult transformToLight(double audioFreq_Hz)
    {
        TransformationResult result;
        result.audioFrequency_Hz = juce::jlimit(PhysicalConstants::AUDIO_MIN_HZ,
                                                 PhysicalConstants::AUDIO_MAX_HZ,
                                                 audioFreq_Hz);

        // Musical note identification
        result.musicalNote = frequencyToNote(result.audioFrequency_Hz);

        // OCTAVE TRANSFORMATION
        double targetFreq = result.audioFrequency_Hz;
        result.octavesShifted = 0;

        const double MIN_VISIBLE_HZ = PhysicalConstants::LIGHT_MIN_THz * 1e12;  // 430 THz
        const double MAX_VISIBLE_HZ = PhysicalConstants::LIGHT_MAX_THz * 1e12;  // 770 THz

        // Shift upward until in visible range
        while (targetFreq < MIN_VISIBLE_HZ)
        {
            targetFreq *= 2.0;
            result.octavesShifted++;
        }

        // If overshoot, shift back one octave
        if (targetFreq > MAX_VISIBLE_HZ)
        {
            targetFreq /= 2.0;
            result.octavesShifted--;
        }

        result.lightFrequency_THz = targetFreq / 1e12;
        result.wavelength_nm = PhysicalConstants::frequencyToWavelength(result.lightFrequency_THz);

        // SCIENTIFIC COLOR CALCULATION
        result.color = calculateScientificColor(result.wavelength_nm);
        result.juceColor = juce::Colour::fromFloatRGBA(
            static_cast<float>(result.color.r),
            static_cast<float>(result.color.g),
            static_cast<float>(result.color.b),
            1.0f);

        // PERCEPTUAL BRIGHTNESS (Photopic Luminosity)
        result.perceptualBrightness = calculatePhotopicLuminosity(result.wavelength_nm);

        // NEUROPHYSIOLOGY
        result.visualCortexResponse = getVisualCortexResponse(result.wavelength_nm);
        result.flickerFusionRelation = calculateFlickerFusion(result.audioFrequency_Hz);

        // CONE RESPONSES
        auto cones = calculateConeResponse(result.wavelength_nm);
        result.sConeActivation = cones[0];
        result.mConeActivation = cones[1];
        result.lConeActivation = cones[2];

        // SCIENTIFIC REFERENCES
        result.references = {
            "Wyszecki & Stiles (2000). Color Science. Wiley.",
            "Hunt (2004). The Reproduction of Colour. Wiley.",
            "Stockman & Sharpe (2000). Vision Research, 40(13).",
            "CIE 1931 Color Matching Functions (ISO 11664-1:2019)",
            "sRGB Color Space (IEC 61966-2-1:1999)"
        };

        // VALIDATION
        result.isPhysicallyValid = (result.wavelength_nm >= 380.0 && result.wavelength_nm <= 780.0);

        return result;
    }

    //==============================================================================
    // CIE 1931 COLOR MATCHING FUNCTIONS
    //==============================================================================

    /**
     * @brief Calculate scientifically accurate color using CIE 1931 standard
     *
     * Uses wavelength-to-XYZ-to-sRGB transformation pipeline:
     * 1. Wavelength → CIE XYZ (color matching functions)
     * 2. XYZ → Linear RGB (D65 matrix)
     * 3. Linear RGB → sRGB (gamma correction)
     *
     * Reference: ISO 11664-1:2019(E)/CIE S 014-1/E:2006
     */
    static ColorScience calculateScientificColor(double wavelength_nm)
    {
        ColorScience color;
        color.wavelength_nm = wavelength_nm;
        color.frequency_THz = PhysicalConstants::wavelengthToFrequency(wavelength_nm);

        // CIE 1931 2° Standard Observer (Approximation)
        // Full tables available in ISO standard, this uses Bruton's algorithm
        auto xyz = getCIE1931XYZ(wavelength_nm);
        color.x = xyz[0];
        color.y = xyz[1];
        color.z = xyz[2];

        // XYZ → Linear RGB (D65 illuminant, sRGB primaries)
        // Matrix from IEC 61966-2-1:1999
        double linearR = 3.2404542 * color.x - 1.5371385 * color.y - 0.4985314 * color.z;
        double linearG = -0.9692660 * color.x + 1.8760108 * color.y + 0.0415560 * color.z;
        double linearB = 0.0556434 * color.x - 0.2040259 * color.y + 1.0572252 * color.z;

        // Apply gamma correction (sRGB)
        color.r = juce::jlimit(0.0, 1.0, gammaCorrect(linearR));
        color.g = juce::jlimit(0.0, 1.0, gammaCorrect(linearG));
        color.b = juce::jlimit(0.0, 1.0, gammaCorrect(linearB));

        // Perceptual color name
        color.perceptualName = getPerceptualColorName(wavelength_nm);

        // Photopic luminous efficiency V(λ)
        color.luminousEfficiency = calculatePhotopicLuminosity(wavelength_nm);

        // Color temperature (approximate)
        color.colorTemperatureK = wavelengthToColorTemperature(wavelength_nm);

        return color;
    }

private:
    //==============================================================================
    // CIE 1931 COLOR MATCHING FUNCTIONS (Simplified)
    //==============================================================================

    /**
     * @brief CIE 1931 XYZ color matching functions (approximation)
     *
     * Returns normalized [X, Y, Z] tristimulus values for a given wavelength.
     * This uses Bruton's analytical approximation for real-time performance.
     *
     * For production use, consider full CIE tables from ISO 11664-1:2019.
     */
    static std::array<double, 3> getCIE1931XYZ(double wavelength_nm)
    {
        // Simplified Bruton's algorithm (wavelength to RGB, then RGB to XYZ)
        // For full accuracy, use tabulated CIE 1931 2° standard observer data

        double r = 0.0, g = 0.0, b = 0.0;

        if (wavelength_nm >= 380.0 && wavelength_nm < 440.0)
        {
            // Violet to Blue
            r = -(wavelength_nm - 440.0) / (440.0 - 380.0);
            b = 1.0;
        }
        else if (wavelength_nm >= 440.0 && wavelength_nm < 490.0)
        {
            // Blue to Cyan
            g = (wavelength_nm - 440.0) / (490.0 - 440.0);
            b = 1.0;
        }
        else if (wavelength_nm >= 490.0 && wavelength_nm < 510.0)
        {
            // Cyan to Green
            g = 1.0;
            b = -(wavelength_nm - 510.0) / (510.0 - 490.0);
        }
        else if (wavelength_nm >= 510.0 && wavelength_nm < 580.0)
        {
            // Green to Yellow
            r = (wavelength_nm - 510.0) / (580.0 - 510.0);
            g = 1.0;
        }
        else if (wavelength_nm >= 580.0 && wavelength_nm < 645.0)
        {
            // Yellow to Red
            r = 1.0;
            g = -(wavelength_nm - 645.0) / (645.0 - 580.0);
        }
        else if (wavelength_nm >= 645.0 && wavelength_nm <= 780.0)
        {
            // Red
            r = 1.0;
        }

        // Apply intensity falloff at spectrum edges (human eye sensitivity)
        double intensity = 1.0;
        if (wavelength_nm >= 380.0 && wavelength_nm < 420.0)
            intensity = 0.3 + 0.7 * (wavelength_nm - 380.0) / (420.0 - 380.0);
        else if (wavelength_nm >= 700.0 && wavelength_nm <= 780.0)
            intensity = 0.3 + 0.7 * (780.0 - wavelength_nm) / (780.0 - 700.0);

        r *= intensity;
        g *= intensity;
        b *= intensity;

        // RGB → XYZ conversion (simplified, assumes sRGB primaries)
        double x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375;
        double y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750;
        double z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041;

        return {x, y, z};
    }

    /**
     * @brief sRGB gamma correction
     *
     * Reference: IEC 61966-2-1:1999
     */
    static double gammaCorrect(double linear)
    {
        if (linear <= 0.0031308)
            return 12.92 * linear;
        else
            return 1.055 * std::pow(linear, 1.0 / 2.4) - 0.055;
    }

    //==============================================================================
    // PHOTOPIC LUMINOSITY FUNCTION V(λ)
    //==============================================================================

    /**
     * @brief Photopic luminous efficiency function V(λ)
     *
     * CIE 1924 photopic luminosity function (ISO 23539:2005).
     * Peak at 555 nm (green) = maximum human eye sensitivity.
     *
     * @param wavelength_nm Wavelength in nanometers
     * @return Luminous efficiency (0.0 to 1.0)
     */
    static double calculatePhotopicLuminosity(double wavelength_nm)
    {
        // Gaussian approximation of V(λ) function
        // Peak: 555 nm, FWHM ≈ 160 nm
        const double peak = 555.0;
        const double sigma = 68.0;  // Adjusted for realistic V(λ) shape

        return std::exp(-std::pow(wavelength_nm - peak, 2.0) / (2.0 * std::pow(sigma, 2.0)));
    }

    //==============================================================================
    // CONE RESPONSE FUNCTIONS
    //==============================================================================

    /**
     * @brief Calculate S, M, L cone responses (Stockman & Sharpe 2000)
     *
     * Returns normalized cone activation for a given wavelength.
     * Based on Stockman & Sharpe (2000) cone fundamentals.
     *
     * @return [S-cone, M-cone, L-cone] activations (0.0 - 1.0)
     */
    static std::array<double, 3> calculateConeResponse(double wavelength_nm)
    {
        // Simplified Gaussian approximations of cone sensitivities
        // S-cone: Peak ~420 nm (Blue)
        // M-cone: Peak ~530 nm (Green)
        // L-cone: Peak ~560 nm (Yellow-Green/Red)

        auto gaussianPeak = [](double wl, double peak, double width) -> double
        {
            return std::exp(-std::pow(wl - peak, 2.0) / (2.0 * std::pow(width, 2.0)));
        };

        double sCone = gaussianPeak(wavelength_nm, 420.0, 50.0);
        double mCone = gaussianPeak(wavelength_nm, 530.0, 60.0);
        double lCone = gaussianPeak(wavelength_nm, 560.0, 70.0);

        return {sCone, mCone, lCone};
    }

    //==============================================================================
    // NEUROPHYSIOLOGY
    //==============================================================================

    /**
     * @brief Visual cortex response based on wavelength
     *
     * Reference: Conway, B. R. (2009). The Neuroscientist, 15(3), 274-290
     */
    static juce::String getVisualCortexResponse(double wavelength_nm)
    {
        if (wavelength_nm < 450.0)
            return "S-cone activation → Parvocellular pathway → V1 blob → V4 color";
        else if (wavelength_nm < 530.0)
            return "M-cone dominant → Magnocellular pathway → V4 color processing";
        else if (wavelength_nm < 560.0)
            return "L+M cone balanced → Maximum luminance → V1 → V4/IT";
        else
            return "L-cone dominant → Ventral stream → V4/IT color object recognition";
    }

    /**
     * @brief Calculate flicker fusion frequency relation
     *
     * Critical Flicker Fusion Frequency (CFF) research.
     * Reference: Davis, E. T. et al. (1983). Vision Research, 23(12)
     */
    static double calculateFlickerFusion(double audioFreq_Hz)
    {
        // Human CFF threshold: ~24-60 Hz (varies by luminance)
        if (audioFreq_Hz < 24.0)
            return audioFreq_Hz;  // Below fusion threshold (visible flicker)
        else if (audioFreq_Hz < 60.0)
            return 24.0 + (audioFreq_Hz - 24.0) * 0.5;  // Transition range
        else
            return 60.0;  // Maximum CFF for most humans
    }

    //==============================================================================
    // UTILITY FUNCTIONS
    //==============================================================================

    static juce::String getPerceptualColorName(double wavelength_nm)
    {
        if (wavelength_nm < 450.0) return "Violet";
        if (wavelength_nm < 485.0) return "Blue";
        if (wavelength_nm < 500.0) return "Cyan";
        if (wavelength_nm < 565.0) return "Green";
        if (wavelength_nm < 590.0) return "Yellow";
        if (wavelength_nm < 625.0) return "Orange";
        return "Red";
    }

    static double wavelengthToColorTemperature(double wavelength_nm)
    {
        // Approximate color temperature for dominant wavelength
        // This is a simplified heuristic, not exact Planckian locus
        if (wavelength_nm < 480.0) return 10000.0;  // Cool blue
        if (wavelength_nm < 550.0) return 6500.0;   // Daylight
        if (wavelength_nm < 590.0) return 5000.0;   // Warm white
        if (wavelength_nm < 620.0) return 3500.0;   // Orange
        return 2500.0;  // Warm red
    }

    /**
     * @brief Convert frequency to musical note name
     */
    static juce::String frequencyToNote(double frequency_Hz)
    {
        const char* noteNames[] = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};

        // A4 = 440 Hz reference
        double a4 = 440.0;
        double halfSteps = 12.0 * std::log2(frequency_Hz / a4);
        int midiNote = static_cast<int>(std::round(69 + halfSteps));

        int octave = (midiNote / 12) - 1;
        int noteIndex = midiNote % 12;

        return juce::String(noteNames[noteIndex]) + juce::String(octave);
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ScientificFrequencyLightTransformer)
};

/*
  ==============================================================================
   ECHOELMUSIC - Biofeedback Color Correction
   Automatische Farbkorrektur basierend auf physiologischem Zustand

   Mapping:
   - Heart Rate ↑ → Wärmere Farben (Orange/Rot)
   - Heart Rate ↓ → Kühlere Farben (Blau/Cyan)
   - HRV Coherence ↑ → Höhere Sättigung
   - Stress ↑ → Desaturation + Contrast ↑
   - Flow State → Vibrant Colors + Smooth Transitions

   Professionelle LUTs (Look-Up Tables) passen sich in Echtzeit an:
   - Cinematic LUTs (Film-Look)
   - Commercial LUTs (Werbung-Look)
   - Music Video LUTs (MTV-Style)
   - Custom Biofeedback LUTs (Einzigartig!)
  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>

namespace Echoelmusic {
namespace Video {

//==============================================================================
/** Color Grading LUT (Look-Up Table) */
struct ColorLUT {
    juce::String name;
    int size;  // 33x33x33 or 64x64x64
    std::vector<juce::Colour> data;  // RGB cube

    // Load from .cube file (DaVinci Resolve format)
    static ColorLUT loadFromCubeFile(const juce::File& file);

    // Apply LUT to color
    juce::Colour apply(const juce::Colour& input) const;
};

//==============================================================================
/** Biofeedback-driven Color Parameters */
struct BiofeedbackColorParams {
    // Temperature (Warmth)
    float temperature;      // -1.0 (cool/blue) to +1.0 (warm/orange)

    // Tint
    float tint;            // -1.0 (green) to +1.0 (magenta)

    // Saturation
    float saturation;      // 0.0 (B&W) to 2.0 (hyper-saturated)

    // Contrast
    float contrast;        // 0.0 (flat) to 2.0 (high contrast)

    // Exposure
    float exposure;        // -2.0 (dark) to +2.0 (bright)

    // Vibrance (smart saturation)
    float vibrance;        // 0.0 to 2.0

    // Highlights/Shadows
    float highlights;      // -1.0 (crush) to +1.0 (boost)
    float shadows;         // -1.0 (crush) to +1.0 (lift)

    // Color shift (Hue rotation)
    float hueShift;        // -180° to +180°

    // Smoothness (für Biofeedback-Übergänge)
    float smoothingFactor; // 0.0 (instant) to 1.0 (very smooth)
};

//==============================================================================
/** Physiological State → Color Mapping */
struct PhysiologicalState {
    // Raw biofeedback
    float heartRate;       // BPM
    float hrv;            // Heart Rate Variability
    float coherence;      // HRV Coherence (0-100)
    float stress;         // Stress Index (0-100)
    float breathing;      // Breaths per minute

    // Derived states
    bool isFlowState;     // Coherence > 70, HRV balanced
    bool isStressed;      // Stress > 60
    bool isRelaxed;       // HR < 60, HRV high
    bool isExcited;       // HR > 100
};

//==============================================================================
/**
 * Biofeedback Color Corrector
 *
 * Passt Farbkorrektur automatisch an physiologischen Zustand an:
 *
 * Heart Rate Mapping:
 *   60-70 BPM  → Cool (Temperature: -0.3)
 *   70-80 BPM  → Neutral (Temperature: 0.0)
 *   80-100 BPM → Warm (Temperature: +0.3)
 *   100+ BPM   → Hot (Temperature: +0.6)
 *
 * Coherence Mapping:
 *   < 30       → Low Saturation (0.7)
 *   30-60      → Normal Saturation (1.0)
 *   60-80      → High Saturation (1.3)
 *   80+        → Vibrant (1.5)
 *
 * Stress Mapping:
 *   < 30       → Soft (Contrast: 0.9)
 *   30-60      → Normal (Contrast: 1.0)
 *   60-80      → Punchy (Contrast: 1.2)
 *   80+        → Harsh (Contrast: 1.4, Desaturate)
 */
class BiofeedbackColorCorrection {
public:
    BiofeedbackColorCorrection();
    ~BiofeedbackColorCorrection();

    //==============================================================================
    // Biofeedback Input
    void updatePhysiologicalState(const PhysiologicalState& state);

    //==============================================================================
    // Color Correction
    juce::Image applyColorCorrection(const juce::Image& input);
    void applyColorCorrectionInPlace(juce::Image& image);

    // Get current color parameters (influenced by biofeedback)
    BiofeedbackColorParams getCurrentColorParams() const;

    //==============================================================================
    // LUT Management
    void loadLUT(const juce::File& lutFile);
    void setLUTIntensity(float intensity);  // 0.0 (bypass) to 1.0 (full LUT)

    //==============================================================================
    // Manual Overrides (Optional)
    void setManualTemperature(float temp);
    void setManualSaturation(float sat);
    void setManualContrast(float contrast);
    void enableBiofeedbackControl(bool enable);

    //==============================================================================
    // Presets
    enum class ColorPreset {
        Cinematic,      // Film-Look (soft, warm)
        Commercial,     // Werbung (punchy, vibrant)
        MusicVideo,     // MTV-Style (saturated, contrast)
        Natural,        // Natural (subtle correction)
        BiofeedbackDriven  // Fully biofeedback-controlled
    };

    void setPreset(ColorPreset preset);

    //==============================================================================
    // Callbacks
    std::function<void(const BiofeedbackColorParams&)> onColorParamsChanged;

private:
    //==============================================================================
    // Internal mapping functions
    float mapHeartRateToTemperature(float heartRate);
    float mapCoherenceToSaturation(float coherence);
    float mapStressToContrast(float stress);
    float mapBreathingToExposure(float breathing);

    // Color operations
    void applyTemperature(juce::Image& image, float temperature);
    void applySaturation(juce::Image& image, float saturation);
    void applyContrast(juce::Image& image, float contrast);
    void applyExposure(juce::Image& image, float exposure);
    void applyHueShift(juce::Image& image, float hueShift);

    // LUT application
    juce::Colour applyLUT(const juce::Colour& input);

    // Smoothing (to avoid jarring transitions)
    float smoothValue(float current, float target, float smoothingFactor);

    //==============================================================================
    // State
    PhysiologicalState currentState;
    BiofeedbackColorParams currentParams;
    BiofeedbackColorParams targetParams;  // For smooth transitions

    // LUT
    std::unique_ptr<ColorLUT> currentLUT;
    float lutIntensity = 1.0f;

    // Settings
    bool biofeedbackEnabled = true;
    ColorPreset currentPreset = ColorPreset::BiofeedbackDriven;

    // Smoothing
    float smoothingFactor = 0.95f;  // 0.0 = instant, 1.0 = very slow

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BiofeedbackColorCorrection)
};

//==============================================================================
/**
 * Real-Time LUT Interpolator
 *
 * 3D LUT interpolation using trilinear interpolation
 */
class LUTInterpolator {
public:
    static juce::Colour interpolate(const ColorLUT& lut, const juce::Colour& input) {
        if (lut.data.empty()) return input;

        float r = input.getFloatRed();
        float g = input.getFloatGreen();
        float b = input.getFloatBlue();

        // Map to LUT coordinates
        float x = r * (lut.size - 1);
        float y = g * (lut.size - 1);
        float z = b * (lut.size - 1);

        // Integer coordinates
        int x0 = juce::jlimit(0, lut.size - 2, (int)x);
        int y0 = juce::jlimit(0, lut.size - 2, (int)y);
        int z0 = juce::jlimit(0, lut.size - 2, (int)z);
        int x1 = x0 + 1;
        int y1 = y0 + 1;
        int z1 = z0 + 1;

        // Fractional parts
        float xd = x - x0;
        float yd = y - y0;
        float zd = z - z0;

        // Trilinear interpolation
        auto getColor = [&](int ix, int iy, int iz) {
            int index = iz * lut.size * lut.size + iy * lut.size + ix;
            return lut.data[juce::jlimit(0, (int)lut.data.size() - 1, index)];
        };

        juce::Colour c000 = getColor(x0, y0, z0);
        juce::Colour c001 = getColor(x0, y0, z1);
        juce::Colour c010 = getColor(x0, y1, z0);
        juce::Colour c011 = getColor(x0, y1, z1);
        juce::Colour c100 = getColor(x1, y0, z0);
        juce::Colour c101 = getColor(x1, y0, z1);
        juce::Colour c110 = getColor(x1, y1, z0);
        juce::Colour c111 = getColor(x1, y1, z1);

        // Interpolate along x
        auto lerpColor = [](const juce::Colour& a, const juce::Colour& b, float t) {
            return juce::Colour::fromFloatRGBA(
                a.getFloatRed()   + (b.getFloatRed()   - a.getFloatRed())   * t,
                a.getFloatGreen() + (b.getFloatGreen() - a.getFloatGreen()) * t,
                a.getFloatBlue()  + (b.getFloatBlue()  - a.getFloatBlue())  * t,
                1.0f
            );
        };

        juce::Colour c00 = lerpColor(c000, c100, xd);
        juce::Colour c01 = lerpColor(c001, c101, xd);
        juce::Colour c10 = lerpColor(c010, c110, xd);
        juce::Colour c11 = lerpColor(c011, c111, xd);

        // Interpolate along y
        juce::Colour c0 = lerpColor(c00, c10, yd);
        juce::Colour c1 = lerpColor(c01, c11, yd);

        // Interpolate along z
        return lerpColor(c0, c1, zd);
    }
};

//==============================================================================
/**
 * Color Temperature Converter
 *
 * Converts temperature shift to RGB multipliers
 * Based on Planckian locus approximation
 */
class ColorTemperatureConverter {
public:
    struct RGBMultiplier {
        float r, g, b;
    };

    /**
     * Temperature: -1.0 (cool/blue) to +1.0 (warm/orange)
     */
    static RGBMultiplier temperatureToRGB(float temperature) {
        RGBMultiplier mult;

        if (temperature < 0.0f) {
            // Cool (add blue, reduce red)
            mult.r = 1.0f + temperature * 0.3f;
            mult.g = 1.0f;
            mult.b = 1.0f - temperature * 0.4f;
        } else {
            // Warm (add red/orange, reduce blue)
            mult.r = 1.0f + temperature * 0.4f;
            mult.g = 1.0f + temperature * 0.2f;
            mult.b = 1.0f - temperature * 0.5f;
        }

        return mult;
    }
};

} // namespace Video
} // namespace Echoelmusic

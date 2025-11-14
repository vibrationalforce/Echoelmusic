#pragma once

#include <JuceHeader.h>
#include <cmath>

//==============================================================================
/**
 * ⚠️ ⚠️ ⚠️ WICHTIGE SICHERHEITSHINWEISE ⚠️ ⚠️ ⚠️
 *
 * DIESES SYSTEM IST NUR FÜR ENTERTAINMENT/ATMOSPHÄRE!
 * KEINE MEDIZINISCHEN VERSPRECHEN! KEINE THERAPEUTISCHEN CLAIMS!
 *
 * **DISCLAIMER**: NUR FÜR FORSCHUNG UND UNTERHALTUNG!
 * Siehe AudioVisualEntrainment.h für vollständige Warnungen!
 */

//==============================================================================
/**
 * @brief Color Light Therapy (Atmospheric Effects)
 *
 * Wissenschaftlich fundiertes Farblichtsystem basierend auf
 * Circadian Rhythm Research und Photobiology.
 *
 * **WISSENSCHAFTLICHE BASIS** (NUR zur Information, KEINE Claims!):
 *
 * 1. **Circadian Photoreception**:
 *    - Intrinsically Photosensitive Retinal Ganglion Cells (ipRGCs)
 *    - Peak sensitivity: ~480 nm (blue light)
 *    - Dokumentiert: Berson et al. (2002), Lucas et al. (2014)
 *
 * 2. **Melatonin Suppression** (documented effect, NO claims!):
 *    - Blue light (460-480 nm): Strong effect
 *    - Red light (> 600 nm): Minimal effect
 *    - Dokumentiert: Brainard et al. (2001), Lockley et al. (2003)
 *
 * 3. **Color Temperature** (Kelvin):
 *    - Warm (< 3000 K): Red-orange (minimal circadian impact)
 *    - Neutral (4000-5000 K): White (moderate)
 *    - Cool (> 6000 K): Blue-white (strong circadian impact)
 *
 * 4. **Light Intensity** (Lux):
 *    - Low (< 100 lux): Minimal effect
 *    - Medium (100-500 lux): Moderate effect
 *    - High (> 1000 lux): Strong effect
 *
 * **WICHTIG**: Dies ist KEIN therapeutisches Gerät!
 * Nur atmosphärische Effekte für Entertainment/Research!
 *
 * References (EDUCATIONAL ONLY):
 * - Berson et al. (2002): Science 295(5557): 1070-1073
 * - Brainard et al. (2001): J Neurosci 21(16): 6405-6412
 * - Lockley et al. (2003): Curr Biol 13(7): 594-598
 * - Lucas et al. (2014): Trends Neurosci 37(1): 1-9
 */
class ColorLightTherapy
{
public:
    //==============================================================================
    // Color Modes (based on photobiology research)

    enum class ColorMode
    {
        Warm,           // Red-Orange (< 3000 K) - minimal circadian impact
        Neutral,        // White (4000-5000 K) - moderate
        Cool,           // Blue-White (> 6000 K) - strong circadian impact
        Daylight,       // Natural daylight (5500-6500 K)
        Sunset,         // Warm sunset colors (2000-3000 K)
        Night,          // Deep red (minimal melatonin suppression)
        Custom          // User-defined
    };

    //==============================================================================
    struct ColorSettings
    {
        ColorMode mode = ColorMode::Warm;

        // Color (RGB or Temperature)
        juce::Colour customColor = juce::Colours::orange;
        float colorTemperatureK = 3000.0f;         // Kelvin

        // Intensity (safety limits!)
        float intensity = 0.3f;                    // Max 30% by default (safety)
        float maxIntensity = 0.5f;                 // Never exceed 50% (safety!)

        // Duration limits (safety!)
        float maxDurationMinutes = 30.0f;          // Max 30 minutes

        // Pulsing/Breathing effect
        bool pulsingEnabled = false;
        float pulseFrequencyHz = 0.1f;             // 0.1 Hz = 10s cycle (slow!)

        // Safety
        bool safetyWarningAcknowledged = false;
    };

    //==============================================================================
    struct LightState
    {
        bool isActive = false;
        float elapsedSeconds = 0.0f;
        juce::Colour currentColor;
        float currentIntensity = 0.0f;
        float pulsePhase = 0.0f;
        bool maxDurationReached = false;
    };

    //==============================================================================
    ColorLightTherapy()
    {
        reset();
    }

    //==============================================================================
    /**
     * @brief Start color light session
     *
     * ⚠️ WARNINGS MUST BE ACKNOWLEDGED FIRST! ⚠️
     */
    bool startSession(const ColorSettings& settings)
    {
        // SAFETY CHECK
        if (!settings.safetyWarningAcknowledged)
        {
            DBG("⚠️ SAFETY WARNING NOT ACKNOWLEDGED! Session not started.");
            return false;
        }

        // SAFETY CHECK: Limit intensity
        currentSettings = settings;
        if (currentSettings.intensity > 0.5f)
        {
            DBG("⚠️ WARNING: Intensity too high! Limiting to 50% for safety.");
            currentSettings.intensity = 0.5f;
        }

        // Initialize state
        lightState.isActive = true;
        lightState.elapsedSeconds = 0.0f;
        lightState.currentIntensity = currentSettings.intensity;
        lightState.pulsePhase = 0.0f;
        lightState.maxDurationReached = false;

        // Set color based on mode
        updateColorFromMode();

        return true;
    }

    void stopSession()
    {
        lightState.isActive = false;
        lightState.currentIntensity = 0.0f;
    }

    void reset()
    {
        lightState = LightState();
        currentSettings = ColorSettings();
    }

    //==============================================================================
    /**
     * @brief Update light state (call every frame)
     */
    void update(float deltaSeconds)
    {
        if (!lightState.isActive)
            return;

        // Update elapsed time
        lightState.elapsedSeconds += deltaSeconds;

        // Check max duration (SAFETY!)
        if (lightState.elapsedSeconds >= currentSettings.maxDurationMinutes * 60.0f)
        {
            if (!lightState.maxDurationReached)
            {
                lightState.maxDurationReached = true;
                stopSession();
                DBG("⚠️ Max duration reached. Stopping session for safety.");
            }
        }

        // Update pulse phase
        if (currentSettings.pulsingEnabled)
        {
            float phaseIncrement = 2.0f * juce::MathConstants<float>::pi *
                                  currentSettings.pulseFrequencyHz * deltaSeconds;
            lightState.pulsePhase += phaseIncrement;

            while (lightState.pulsePhase >= 2.0f * juce::MathConstants<float>::pi)
                lightState.pulsePhase -= 2.0f * juce::MathConstants<float>::pi;

            // Modulate intensity (breathing effect)
            float modulation = (std::sin(lightState.pulsePhase) + 1.0f) * 0.5f;  // 0-1
            lightState.currentIntensity = currentSettings.intensity * (0.5f + modulation * 0.5f);  // 50-100%
        }
        else
        {
            lightState.currentIntensity = currentSettings.intensity;
        }
    }

    //==============================================================================
    /**
     * @brief Get current light color (with intensity applied)
     */
    juce::Colour getCurrentColor() const
    {
        if (!lightState.isActive)
            return juce::Colours::black;

        return lightState.currentColor.withAlpha(lightState.currentIntensity);
    }

    /**
     * @brief Get current RGB values (0-1)
     */
    std::array<float, 3> getCurrentRGB() const
    {
        auto color = getCurrentColor();
        return {color.getFloatRed(), color.getFloatGreen(), color.getFloatBlue()};
    }

    const LightState& getLightState() const
    {
        return lightState;
    }

    const ColorSettings& getSettings() const
    {
        return currentSettings;
    }

    //==============================================================================
    /**
     * @brief Get color for mode (based on research)
     */
    static juce::Colour getColorForMode(ColorMode mode)
    {
        switch (mode)
        {
            case ColorMode::Warm:
                // Red-Orange (~2700 K) - minimal circadian impact
                return juce::Colour(255, 140, 60);

            case ColorMode::Neutral:
                // Neutral white (~4500 K)
                return juce::Colour(255, 228, 206);

            case ColorMode::Cool:
                // Cool blue-white (~6500 K) - strong circadian impact
                return juce::Colour(200, 220, 255);

            case ColorMode::Daylight:
                // Natural daylight (~5500 K)
                return juce::Colour(255, 250, 240);

            case ColorMode::Sunset:
                // Warm sunset (~2500 K)
                return juce::Colour(255, 100, 30);

            case ColorMode::Night:
                // Deep red (~2000 K) - minimal melatonin suppression
                return juce::Colour(255, 50, 0);

            default:
                return juce::Colours::white;
        }
    }

    /**
     * @brief Convert color temperature (Kelvin) to RGB
     *
     * Uses Tanner Helland's algorithm (from FrequencyColorTranslator)
     */
    static juce::Colour kelvinToRGB(float temperatureK)
    {
        temperatureK = juce::jlimit(1000.0f, 40000.0f, temperatureK);
        float temp = temperatureK / 100.0f;

        float r, g, b;

        // Red
        if (temp <= 66.0f)
            r = 1.0f;
        else
        {
            r = 329.698727446f * std::pow(temp - 60.0f, -0.1332047592f);
            r = juce::jlimit(0.0f, 1.0f, r / 255.0f);
        }

        // Green
        if (temp <= 66.0f)
        {
            g = 99.4708025861f * std::log(temp) - 161.1195681661f;
            g = juce::jlimit(0.0f, 1.0f, g / 255.0f);
        }
        else
        {
            g = 288.1221695283f * std::pow(temp - 60.0f, -0.0755148492f);
            g = juce::jlimit(0.0f, 1.0f, g / 255.0f);
        }

        // Blue
        if (temp >= 66.0f)
            b = 1.0f;
        else if (temp <= 19.0f)
            b = 0.0f;
        else
        {
            b = 138.5177312231f * std::log(temp - 10.0f) - 305.0447927307f;
            b = juce::jlimit(0.0f, 1.0f, b / 255.0f);
        }

        return juce::Colour::fromFloatRGBA(r, g, b, 1.0f);
    }

    /**
     * @brief Get mode name (for display)
     */
    static juce::String getModeName(ColorMode mode)
    {
        switch (mode)
        {
            case ColorMode::Warm: return "Warm (< 3000 K)";
            case ColorMode::Neutral: return "Neutral (~4500 K)";
            case ColorMode::Cool: return "Cool (> 6000 K)";
            case ColorMode::Daylight: return "Daylight (~5500 K)";
            case ColorMode::Sunset: return "Sunset (~2500 K)";
            case ColorMode::Night: return "Night (~2000 K)";
            default: return "Custom";
        }
    }

private:
    //==============================================================================
    void updateColorFromMode()
    {
        if (currentSettings.mode == ColorMode::Custom)
        {
            lightState.currentColor = currentSettings.customColor;
        }
        else
        {
            // Get color from Kelvin temperature
            lightState.currentColor = kelvinToRGB(currentSettings.colorTemperatureK);
        }
    }

    //==============================================================================
    ColorSettings currentSettings;
    LightState lightState;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ColorLightTherapy)
};

//==============================================================================
/**
 * @brief Combined Color + Audio-Visual System
 *
 * Combines color light therapy with audio-visual entrainment
 * for synchronized multi-sensory effects.
 *
 * ⚠️ SAME WARNINGS AS ABOVE APPLY! ⚠️
 */
class MultiSensoryWellnessSystem
{
public:
    MultiSensoryWellnessSystem() = default;

    // Initialize both systems
    AudioVisualEntrainment& getAVE() { return aveSystem; }
    ColorLightTherapy& getColorLight() { return colorSystem; }

    // Combined update
    void update(float deltaSeconds)
    {
        aveSystem.update(deltaSeconds);
        colorSystem.update(deltaSeconds);
    }

    // Emergency stop all
    void emergencyStopAll()
    {
        aveSystem.emergencyStop();
        colorSystem.stopSession();
    }

    // Check if any system is active
    bool isAnySystemActive() const
    {
        return aveSystem.getSessionState().isActive ||
               colorSystem.getLightState().isActive;
    }

private:
    AudioVisualEntrainment aveSystem;
    ColorLightTherapy colorSystem;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MultiSensoryWellnessSystem)
};

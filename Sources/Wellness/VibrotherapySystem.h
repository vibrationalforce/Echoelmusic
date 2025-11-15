#pragma once

#include <JuceHeader.h>
#include <cmath>
#include <array>

//==============================================================================
/**
 * ⚠️ ⚠️ ⚠️ WICHTIGE SICHERHEITSHINWEISE ⚠️ ⚠️ ⚠️
 *
 * DIESES SYSTEM IST NUR FÜR ENTERTAINMENT/FORSCHUNGSZWECKE!
 * KEINE MEDIZINISCHEN VERSPRECHEN! KEINE THERAPEUTISCHEN CLAIMS!
 *
 * **WARNUNGEN**:
 * ⚠️ NICHT verwenden bei Herzschrittmacher oder Herzproblemen
 * ⚠️ NICHT verwenden bei Schwangerschaft
 * ⚠️ NICHT verwenden bei neurologischen Erkrankungen
 * ⚠️ NICHT verwenden bei akuten Entzündungen oder Verletzungen
 * ⚠️ NICHT verwenden bei Thrombose oder Durchblutungsstörungen
 * ⚠️ NICHT verwenden bei Epilepsie
 * ⚠️ Bei Unwohlsein SOFORT stoppen!
 *
 * **HAFTUNGSAUSSCHLUSS**:
 * - Dies ist KEIN medizinisches Gerät
 * - Dies ist KEINE Therapie
 * - Ersetzen Sie NIEMALS ärztliche Behandlung
 * - Konsultieren Sie einen Arzt vor der Nutzung
 * - Nutzung auf eigenes Risiko
 *
 * **RECHTLICHER HINWEIS**:
 * Alle Aussagen sind für Bildungs- und Forschungszwecke.
 * Keine therapeutischen Wirkungen werden versprochen oder impliziert.
 */

//==============================================================================
/**
 * @brief Vibrotactile/Vibrotherapy System
 *
 * Wissenschaftlich fundiertes rhythmisches Vibrationssystem basierend auf
 * haptischer Wahrnehmungsforschung.
 *
 * **WISSENSCHAFTLICHE BASIS** (NUR zur Information, KEINE Claims!):
 *
 * 1. **Mechanoreceptors** (Tactile Sensing):
 *    - Meissner corpuscles: 10-50 Hz (flutter, light touch)
 *    - Pacinian corpuscles: 40-800 Hz (vibration, deep pressure)
 *    - Documented: Bolanowski et al. (1988), Gescheider et al. (2004)
 *
 * 2. **Optimal Frequency Ranges** (perception research):
 *    - Low frequency (10-50 Hz): Deep, rumbling sensation
 *    - Mid frequency (50-200 Hz): Clear vibration perception
 *    - High frequency (200-400 Hz): Fine, buzzing sensation
 *    - Documented: Verrillo (1992), Jones & Sarter (2008)
 *
 * 3. **Amplitude/Intensity**:
 *    - Detection threshold: ~0.1-1 μm displacement
 *    - Comfort range: Low to moderate intensity
 *    - Pain threshold: Avoid high intensities
 *    - Documented: Gescheider (1997)
 *
 * 4. **Rhythmic Patterns**:
 *    - Constant (continuous vibration)
 *    - Pulsed (on/off cycles)
 *    - Ramped (gradual intensity change)
 *    - Complex (multi-frequency)
 *
 * 5. **Safety Considerations**:
 *    - LOW intensity only (< 50% maximum)
 *    - SHORT duration (< 30 minutes)
 *    - AVOID continuous high-frequency vibration
 *    - User control: ALWAYS allow immediate stop
 *
 * **DISCLAIMER**: NUR FÜR FORSCHUNG UND UNTERHALTUNG!
 *
 * References (EDUCATIONAL ONLY):
 * - Bolanowski et al. (1988): J Acoust Soc Am 84(5): 1680-1694
 * - Verrillo (1992): Perception & Psychophysics 51(2): 99-113
 * - Gescheider et al. (2004): Somatosens Mot Res 21(3-4): 149-160
 * - Jones & Sarter (2008): Annu Rev Psychol 59: 467-493
 */
class VibrotherapySystem
{
public:
    //==============================================================================
    // Vibration Modes (based on mechanoreceptor research)

    enum class VibrationMode
    {
        LowFrequency,       // 10-50 Hz (Meissner corpuscles - flutter)
        MidFrequency,       // 50-200 Hz (optimal perception)
        HighFrequency,      // 200-400 Hz (Pacinian corpuscles)
        Pulsed,             // Rhythmic on/off pattern
        Ramped,             // Gradual intensity changes
        AudioSynchronized,  // Sync with music/bio-data
        Custom              // User-defined
    };

    //==============================================================================
    struct VibrationSettings
    {
        VibrationMode mode = VibrationMode::MidFrequency;

        // Frequency (Hz)
        float frequencyHz = 100.0f;                // Default: 100 Hz (optimal perception)

        // Intensity (0-1)
        float intensity = 0.3f;                    // Max 30% by default (safety)
        float maxIntensity = 0.5f;                 // Never exceed 50% (safety!)

        // Duration limits (safety!)
        float maxDurationMinutes = 30.0f;          // Max 30 minutes

        // Pattern settings
        bool pulsedEnabled = false;
        float pulseFrequencyHz = 2.0f;             // 2 Hz pulse rate (slow, comfortable)
        float pulseDutyCycle = 0.5f;               // 50% on, 50% off

        // Ramping
        bool rampingEnabled = false;
        float rampFrequencyHz = 0.1f;              // 0.1 Hz = 10s cycle

        // Audio synchronization
        bool audioSyncEnabled = false;
        float audioSyncAmount = 0.5f;              // 50% audio modulation

        // Safety
        bool safetyWarningAcknowledged = false;
    };

    //==============================================================================
    struct VibrationState
    {
        bool isActive = false;
        float elapsedSeconds = 0.0f;
        float currentIntensity = 0.0f;
        float currentPhase = 0.0f;                 // Oscillator phase (0-2π)
        float pulsePhase = 0.0f;                   // Pulse modulation phase
        float rampPhase = 0.0f;                    // Ramp modulation phase
        bool maxDurationReached = false;
    };

    //==============================================================================
    VibrotherapySystem()
    {
        reset();
    }

    //==============================================================================
    /**
     * @brief Start vibration session
     *
     * ⚠️ WARNINGS MUST BE ACKNOWLEDGED FIRST! ⚠️
     */
    bool startSession(const VibrationSettings& settings)
    {
        // SAFETY CHECK
        if (!settings.safetyWarningAcknowledged)
        {
            DBG("⚠️ SAFETY WARNING NOT ACKNOWLEDGED! Session not started.");
            return false;
        }

        // SAFETY CHECK: Validate frequency (avoid extreme frequencies)
        if (settings.frequencyHz < 10.0f || settings.frequencyHz > 400.0f)
        {
            DBG("⚠️ WARNING: Frequency " + juce::String(settings.frequencyHz) +
                " Hz is outside safe range (10-400 Hz)! Session not started.");
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
        vibrationState.isActive = true;
        vibrationState.elapsedSeconds = 0.0f;
        vibrationState.currentIntensity = 0.0f;  // Start at 0, ramp up gradually
        vibrationState.currentPhase = 0.0f;
        vibrationState.pulsePhase = 0.0f;
        vibrationState.rampPhase = 0.0f;
        vibrationState.maxDurationReached = false;

        return true;
    }

    void stopSession()
    {
        vibrationState.isActive = false;
        vibrationState.currentIntensity = 0.0f;
    }

    void reset()
    {
        vibrationState = VibrationState();
        currentSettings = VibrationSettings();
    }

    //==============================================================================
    /**
     * @brief Update vibration state (call every frame)
     */
    void update(float deltaSeconds)
    {
        if (!vibrationState.isActive)
            return;

        // Update elapsed time
        vibrationState.elapsedSeconds += deltaSeconds;

        // Check max duration (SAFETY!)
        if (vibrationState.elapsedSeconds >= currentSettings.maxDurationMinutes * 60.0f)
        {
            if (!vibrationState.maxDurationReached)
            {
                vibrationState.maxDurationReached = true;
                stopSession();
                DBG("⚠️ Max duration reached. Stopping session for safety.");
            }
        }

        // Update main oscillator phase
        float phaseIncrement = 2.0f * juce::MathConstants<float>::pi *
                              currentSettings.frequencyHz * deltaSeconds;
        vibrationState.currentPhase += phaseIncrement;

        // Wrap phase
        while (vibrationState.currentPhase >= 2.0f * juce::MathConstants<float>::pi)
            vibrationState.currentPhase -= 2.0f * juce::MathConstants<float>::pi;

        // Update modulation phases
        updateModulation(deltaSeconds);

        // Update intensity with gradual ramp-in (safety)
        updateIntensity(deltaSeconds);
    }

    //==============================================================================
    /**
     * @brief Get current vibration amplitude (-1 to +1)
     *
     * This can be used to control haptic actuators, motors, or transducers.
     *
     * @return Vibration amplitude
     */
    float getVibrationAmplitude() const
    {
        if (!vibrationState.isActive)
            return 0.0f;

        // Base sine wave
        float amplitude = std::sin(vibrationState.currentPhase);

        // Apply pulse modulation
        if (currentSettings.pulsedEnabled)
        {
            float pulseValue = (std::sin(vibrationState.pulsePhase) + 1.0f) * 0.5f;  // 0-1

            // Square wave pulse (on/off)
            float pulse = (pulseValue < currentSettings.pulseDutyCycle) ? 1.0f : 0.0f;
            amplitude *= pulse;
        }

        // Apply ramp modulation
        if (currentSettings.rampingEnabled)
        {
            float rampValue = (std::sin(vibrationState.rampPhase) + 1.0f) * 0.5f;  // 0-1
            amplitude *= (0.5f + rampValue * 0.5f);  // 50-100% modulation
        }

        // Apply intensity
        amplitude *= vibrationState.currentIntensity;

        return juce::jlimit(-1.0f, 1.0f, amplitude);
    }

    /**
     * @brief Get current vibration intensity (0-1)
     */
    float getCurrentIntensity() const
    {
        return vibrationState.currentIntensity;
    }

    /**
     * @brief Set audio synchronization value (-1 to +1)
     *
     * Allows external audio signal to modulate vibration intensity.
     */
    void setAudioSyncValue(float audioValue)
    {
        if (!currentSettings.audioSyncEnabled)
            return;

        // Apply audio modulation (0-1 range)
        audioSyncValue = std::abs(audioValue);
    }

    const VibrationState& getVibrationState() const
    {
        return vibrationState;
    }

    const VibrationSettings& getSettings() const
    {
        return currentSettings;
    }

    //==============================================================================
    /**
     * @brief Get frequency range for mode
     */
    static std::pair<float, float> getFrequencyRange(VibrationMode mode)
    {
        switch (mode)
        {
            case VibrationMode::LowFrequency:
                return {10.0f, 50.0f};    // Meissner corpuscles

            case VibrationMode::MidFrequency:
                return {50.0f, 200.0f};   // Optimal perception

            case VibrationMode::HighFrequency:
                return {200.0f, 400.0f};  // Pacinian corpuscles

            default:
                return {10.0f, 400.0f};
        }
    }

    /**
     * @brief Get mode name (for display)
     */
    static juce::String getModeName(VibrationMode mode)
    {
        switch (mode)
        {
            case VibrationMode::LowFrequency: return "Low Freq (10-50 Hz)";
            case VibrationMode::MidFrequency: return "Mid Freq (50-200 Hz)";
            case VibrationMode::HighFrequency: return "High Freq (200-400 Hz)";
            case VibrationMode::Pulsed: return "Pulsed Pattern";
            case VibrationMode::Ramped: return "Ramped Intensity";
            case VibrationMode::AudioSynchronized: return "Audio Sync";
            default: return "Custom";
        }
    }

    /**
     * @brief Get mode description
     */
    static juce::String getModeDescription(VibrationMode mode)
    {
        switch (mode)
        {
            case VibrationMode::LowFrequency:
                return "Deep, rumbling sensation (Meissner corpuscles)";

            case VibrationMode::MidFrequency:
                return "Clear vibration perception (optimal range)";

            case VibrationMode::HighFrequency:
                return "Fine, buzzing sensation (Pacinian corpuscles)";

            case VibrationMode::Pulsed:
                return "Rhythmic on/off pattern (comfortable pulsing)";

            case VibrationMode::Ramped:
                return "Gradual intensity changes (smooth waves)";

            case VibrationMode::AudioSynchronized:
                return "Synchronized with music/audio (reactive)";

            default:
                return "User-defined pattern";
        }
    }

private:
    //==============================================================================
    void updateModulation(float deltaSeconds)
    {
        // Update pulse phase
        if (currentSettings.pulsedEnabled)
        {
            float pulseIncrement = 2.0f * juce::MathConstants<float>::pi *
                                  currentSettings.pulseFrequencyHz * deltaSeconds;
            vibrationState.pulsePhase += pulseIncrement;

            while (vibrationState.pulsePhase >= 2.0f * juce::MathConstants<float>::pi)
                vibrationState.pulsePhase -= 2.0f * juce::MathConstants<float>::pi;
        }

        // Update ramp phase
        if (currentSettings.rampingEnabled)
        {
            float rampIncrement = 2.0f * juce::MathConstants<float>::pi *
                                 currentSettings.rampFrequencyHz * deltaSeconds;
            vibrationState.rampPhase += rampIncrement;

            while (vibrationState.rampPhase >= 2.0f * juce::MathConstants<float>::pi)
                vibrationState.rampPhase -= 2.0f * juce::MathConstants<float>::pi;
        }
    }

    void updateIntensity(float deltaSeconds)
    {
        // Gradual ramp-in for safety (5-second ramp)
        float targetIntensity = currentSettings.intensity;

        // Apply audio sync modulation
        if (currentSettings.audioSyncEnabled)
        {
            targetIntensity *= (1.0f - currentSettings.audioSyncAmount) +
                             (audioSyncValue * currentSettings.audioSyncAmount);
        }

        // Smooth ramp
        float rampSpeed = 1.0f / 5.0f;  // 5-second ramp-in
        if (vibrationState.currentIntensity < targetIntensity)
        {
            vibrationState.currentIntensity += rampSpeed * deltaSeconds;
            if (vibrationState.currentIntensity > targetIntensity)
                vibrationState.currentIntensity = targetIntensity;
        }
        else if (vibrationState.currentIntensity > targetIntensity)
        {
            vibrationState.currentIntensity -= rampSpeed * deltaSeconds;
            if (vibrationState.currentIntensity < targetIntensity)
                vibrationState.currentIntensity = targetIntensity;
        }

        // Clamp to max intensity (safety)
        vibrationState.currentIntensity = juce::jmin(vibrationState.currentIntensity,
                                                     currentSettings.maxIntensity);
    }

    //==============================================================================
    VibrationSettings currentSettings;
    VibrationState vibrationState;
    float audioSyncValue = 0.0f;  // Audio sync input (0-1)

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(VibrotherapySystem)
};

//==============================================================================
/**
 * @brief Multi-Actuator Vibration Controller
 *
 * Controls multiple vibration actuators for spatial haptic effects.
 */
class MultiActuatorController
{
public:
    //==============================================================================
    struct ActuatorChannel
    {
        juce::String name;
        std::unique_ptr<VibrotherapySystem> system;
        float gainMultiplier = 1.0f;
        bool enabled = true;

        // Constructor
        ActuatorChannel() : system(std::make_unique<VibrotherapySystem>()) {}

        // Default move operations
        ActuatorChannel(ActuatorChannel&&) noexcept = default;
        ActuatorChannel& operator=(ActuatorChannel&&) noexcept = default;

        // Delete copy operations
        ActuatorChannel(const ActuatorChannel&) = delete;
        ActuatorChannel& operator=(const ActuatorChannel&) = delete;
    };

    //==============================================================================
    /**
     * @brief Add actuator channel
     */
    void addActuator(const juce::String& name)
    {
        ActuatorChannel channel;
        channel.name = name;
        actuators.push_back(std::move(channel));
    }

    /**
     * @brief Get number of actuators
     */
    int getNumActuators() const
    {
        return static_cast<int>(actuators.size());
    }

    /**
     * @brief Get actuator system
     */
    VibrotherapySystem* getActuator(int index)
    {
        if (index < 0 || index >= static_cast<int>(actuators.size()))
            return nullptr;

        return actuators[index].system.get();
    }

    /**
     * @brief Update all actuators
     */
    void updateAll(float deltaSeconds)
    {
        for (auto& actuator : actuators)
        {
            if (actuator.enabled && actuator.system)
                actuator.system->update(deltaSeconds);
        }
    }

    /**
     * @brief Get mixed vibration output (all actuators combined)
     */
    float getMixedOutput() const
    {
        float mixedOutput = 0.0f;
        int activeCount = 0;

        for (const auto& actuator : actuators)
        {
            if (actuator.enabled && actuator.system && actuator.system->getVibrationState().isActive)
            {
                mixedOutput += actuator.system->getVibrationAmplitude() * actuator.gainMultiplier;
                activeCount++;
            }
        }

        // Average to prevent clipping
        if (activeCount > 0)
            mixedOutput /= static_cast<float>(activeCount);

        return juce::jlimit(-1.0f, 1.0f, mixedOutput);
    }

    /**
     * @brief Emergency stop all actuators
     */
    void emergencyStopAll()
    {
        for (auto& actuator : actuators)
        {
            if (actuator.system)
                actuator.system->stopSession();
        }
    }

private:
    std::vector<ActuatorChannel> actuators;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MultiActuatorController)
};

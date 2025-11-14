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
 * ⚠️ NICHT verwenden bei Epilepsie oder Photosensitivität
 * ⚠️ NICHT verwenden mit Herzschrittmacher oder Herzproblemen
 * ⚠️ NICHT verwenden während der Schwangerschaft
 * ⚠️ NICHT verwenden beim Autofahren oder Bedienen von Maschinen
 * ⚠️ NICHT verwenden bei Anfallsleiden jeglicher Art
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
 * @brief Audio-Visual Brainwave Entrainment (AVE)
 *
 * Wissenschaftlich fundiertes System für rhythmische audiovisuelle Stimulation.
 *
 * **WISSENSCHAFTLICHE BASIS** (NUR zur Information!):
 *
 * 1. **Frequency Following Response (FFR)**:
 *    - Gehirn synchronisiert sich mit externen rhythmischen Reizen
 *    - Dokumentiert: Galambos et al. (1981), Picton et al. (2003)
 *    - Mechanism: Neuronal entrainment
 *
 * 2. **Brainwave Frequency Bands** (EEG Research):
 *    - Delta (0.5-4 Hz): Tiefschlaf (Dokumentiert, keine Claims!)
 *    - Theta (4-8 Hz): Meditation (Dokumentiert, keine Claims!)
 *    - Alpha (8-13 Hz): Entspannung (Dokumentiert, keine Claims!)
 *    - Beta (13-30 Hz): Konzentration (Dokumentiert, keine Claims!)
 *    - Gamma (30-100 Hz): Aufmerksamkeit (Dokumentiert, keine Claims!)
 *
 * 3. **Safety Considerations**:
 *    - Flicker frequency: AVOID 15-25 Hz (epilepsy risk zone)
 *    - Light intensity: LOW (< 50% brightness recommended)
 *    - Duration: SHORT sessions (< 20 minutes recommended)
 *    - User control: ALWAYS allow immediate stop
 *
 * **DISCLAIMER**: NUR FÜR FORSCHUNG UND UNTERHALTUNG!
 *
 * References (EDUCATIONAL ONLY):
 * - Galambos et al. (1981): PNAS 78(4): 2643-2647
 * - Picton et al. (2003): Audiol Neurootol 8(5): 241-299
 * - Siever (2000): Alternative Therapies 6(2): 68-75
 * - Huang & Charyton (2008): Alternative Therapies 14(5): 38-49
 */
class AudioVisualEntrainment
{
public:
    //==============================================================================
    // Brainwave Frequency Bands (EEG Classification)

    enum class FrequencyBand
    {
        Delta,      // 0.5-4 Hz   (ONLY documented as deep sleep state)
        Theta,      // 4-8 Hz     (ONLY documented as meditative state)
        Alpha,      // 8-13 Hz    (ONLY documented as relaxed state)
        Beta,       // 13-30 Hz   (ONLY documented as active state)
        Gamma,      // 30-100 Hz  (ONLY documented as focused state)
        Custom      // User-defined
    };

    //==============================================================================
    struct SessionSettings
    {
        FrequencyBand targetBand = FrequencyBand::Alpha;
        float targetFrequencyHz = 10.0f;           // Target entrainment frequency

        // Safety limits (IMPORTANT!)
        float maxIntensity = 0.3f;                 // Max 30% intensity (safety)
        float maxDurationMinutes = 20.0f;          // Max 20 minutes (safety)

        // Audio stimulation
        bool audioEnabled = true;
        float audioVolume = 0.2f;                  // Low volume (20%)

        // Visual stimulation
        bool visualEnabled = false;                // OFF by default (safety!)
        float visualIntensity = 0.2f;              // Low intensity (20%)

        // Ramping (gradual on/off - safer!)
        float rampInSeconds = 5.0f;                // 5s ramp-in
        float rampOutSeconds = 5.0f;               // 5s ramp-out

        // Warning acknowledged (MUST be true to use!)
        bool safetyWarningAcknowledged = false;
    };

    //==============================================================================
    struct SessionState
    {
        bool isActive = false;
        float elapsedSeconds = 0.0f;
        float currentIntensity = 0.0f;             // Current intensity (0-1)
        float currentPhase = 0.0f;                 // Oscillator phase (0-2π)
        bool inRampIn = false;
        bool inRampOut = false;
        bool maxDurationReached = false;
    };

    //==============================================================================
    AudioVisualEntrainment()
    {
        reset();
    }

    //==============================================================================
    /**
     * @brief Start entrainment session
     *
     * ⚠️ WARNINGS MUST BE ACKNOWLEDGED FIRST! ⚠️
     *
     * @param settings Session settings (with safety limits)
     * @return True if started successfully, false if warnings not acknowledged
     */
    bool startSession(const SessionSettings& settings)
    {
        // SAFETY CHECK: Warnings MUST be acknowledged!
        if (!settings.safetyWarningAcknowledged)
        {
            DBG("⚠️ SAFETY WARNING NOT ACKNOWLEDGED! Session not started.");
            return false;
        }

        // SAFETY CHECK: Validate frequency (avoid epilepsy risk zone 15-25 Hz)
        if (settings.targetFrequencyHz >= 15.0f && settings.targetFrequencyHz <= 25.0f)
        {
            DBG("⚠️ WARNING: Frequency " + juce::String(settings.targetFrequencyHz) +
                " Hz is in EPILEPSY RISK ZONE (15-25 Hz)! Session not started.");
            return false;
        }

        // SAFETY CHECK: Validate intensity (max 50%)
        if (settings.maxIntensity > 0.5f)
        {
            DBG("⚠️ WARNING: Intensity too high! Limiting to 50% for safety.");
            currentSettings = settings;
            currentSettings.maxIntensity = 0.5f;
        }
        else
        {
            currentSettings = settings;
        }

        // Initialize state
        sessionState.isActive = true;
        sessionState.elapsedSeconds = 0.0f;
        sessionState.currentIntensity = 0.0f;
        sessionState.currentPhase = 0.0f;
        sessionState.inRampIn = true;
        sessionState.inRampOut = false;
        sessionState.maxDurationReached = false;

        return true;
    }

    /**
     * @brief Stop entrainment session
     */
    void stopSession()
    {
        if (sessionState.isActive && !sessionState.inRampOut)
        {
            // Start ramp-out
            sessionState.inRampOut = true;
            sessionState.inRampIn = false;
        }
    }

    /**
     * @brief Emergency stop (immediate)
     */
    void emergencyStop()
    {
        sessionState.isActive = false;
        sessionState.currentIntensity = 0.0f;
        sessionState.inRampOut = false;
        sessionState.inRampIn = false;
    }

    /**
     * @brief Reset all state
     */
    void reset()
    {
        sessionState = SessionState();
        currentSettings = SessionSettings();
    }

    //==============================================================================
    /**
     * @brief Update session state (call every frame)
     *
     * @param deltaSeconds Time since last update
     */
    void update(float deltaSeconds)
    {
        if (!sessionState.isActive)
            return;

        // Update elapsed time
        sessionState.elapsedSeconds += deltaSeconds;

        // Check max duration (SAFETY!)
        if (sessionState.elapsedSeconds >= currentSettings.maxDurationMinutes * 60.0f)
        {
            if (!sessionState.maxDurationReached)
            {
                sessionState.maxDurationReached = true;
                stopSession();  // Auto-stop after max duration
                DBG("⚠️ Max duration reached. Stopping session for safety.");
            }
        }

        // Update phase (oscillator)
        float phaseIncrement = 2.0f * juce::MathConstants<float>::pi *
                              currentSettings.targetFrequencyHz * deltaSeconds;
        sessionState.currentPhase += phaseIncrement;

        // Wrap phase
        while (sessionState.currentPhase >= 2.0f * juce::MathConstants<float>::pi)
            sessionState.currentPhase -= 2.0f * juce::MathConstants<float>::pi;

        // Update intensity (ramping)
        updateIntensity(deltaSeconds);

        // Check if ramp-out complete
        if (sessionState.inRampOut && sessionState.currentIntensity <= 0.0f)
        {
            sessionState.isActive = false;
        }
    }

    //==============================================================================
    /**
     * @brief Get current audio sample (binaural beat or isochronic tone)
     *
     * @return Audio sample (-1 to +1)
     */
    float getAudioSample() const
    {
        if (!sessionState.isActive || !currentSettings.audioEnabled)
            return 0.0f;

        // Isochronic tone (pulsing sine wave)
        float carrier = std::sin(sessionState.currentPhase * 10.0f);  // 10x freq for audibility
        float modulator = (std::sin(sessionState.currentPhase) + 1.0f) * 0.5f;  // 0-1 modulation

        float sample = carrier * modulator * sessionState.currentIntensity * currentSettings.audioVolume;
        return juce::jlimit(-1.0f, 1.0f, sample);
    }

    /**
     * @brief Get current visual brightness (0-1)
     *
     * @return Brightness (0-1)
     */
    float getVisualBrightness() const
    {
        if (!sessionState.isActive || !currentSettings.visualEnabled)
            return 0.0f;

        // Sine wave brightness modulation
        float brightness = (std::sin(sessionState.currentPhase) + 1.0f) * 0.5f;  // 0-1
        brightness *= sessionState.currentIntensity * currentSettings.visualIntensity;

        return juce::jlimit(0.0f, 1.0f, brightness);
    }

    /**
     * @brief Get session state
     */
    const SessionState& getSessionState() const
    {
        return sessionState;
    }

    /**
     * @brief Get current settings
     */
    const SessionSettings& getSettings() const
    {
        return currentSettings;
    }

    //==============================================================================
    /**
     * @brief Get frequency range for band
     *
     * @param band Frequency band
     * @return {min Hz, max Hz}
     */
    static std::pair<float, float> getFrequencyRange(FrequencyBand band)
    {
        switch (band)
        {
            case FrequencyBand::Delta: return {0.5f, 4.0f};
            case FrequencyBand::Theta: return {4.0f, 8.0f};
            case FrequencyBand::Alpha: return {8.0f, 13.0f};
            case FrequencyBand::Beta: return {13.0f, 30.0f};
            case FrequencyBand::Gamma: return {30.0f, 100.0f};
            default: return {0.5f, 100.0f};
        }
    }

    /**
     * @brief Get band name (for display only)
     */
    static juce::String getBandName(FrequencyBand band)
    {
        switch (band)
        {
            case FrequencyBand::Delta: return "Delta (0.5-4 Hz)";
            case FrequencyBand::Theta: return "Theta (4-8 Hz)";
            case FrequencyBand::Alpha: return "Alpha (8-13 Hz)";
            case FrequencyBand::Beta: return "Beta (13-30 Hz)";
            case FrequencyBand::Gamma: return "Gamma (30-100 Hz)";
            default: return "Custom";
        }
    }

    /**
     * @brief Check if frequency is in epilepsy risk zone
     *
     * @param frequencyHz Frequency to check
     * @return True if in risk zone (15-25 Hz)
     */
    static bool isEpilepsyRiskZone(float frequencyHz)
    {
        return (frequencyHz >= 15.0f && frequencyHz <= 25.0f);
    }

private:
    //==============================================================================
    void updateIntensity(float deltaSeconds)
    {
        if (sessionState.inRampIn)
        {
            // Ramp in (gradual increase)
            float rampSpeed = 1.0f / currentSettings.rampInSeconds;
            sessionState.currentIntensity += rampSpeed * deltaSeconds;

            if (sessionState.currentIntensity >= currentSettings.maxIntensity)
            {
                sessionState.currentIntensity = currentSettings.maxIntensity;
                sessionState.inRampIn = false;
            }
        }
        else if (sessionState.inRampOut)
        {
            // Ramp out (gradual decrease)
            float rampSpeed = 1.0f / currentSettings.rampOutSeconds;
            sessionState.currentIntensity -= rampSpeed * deltaSeconds;

            if (sessionState.currentIntensity <= 0.0f)
            {
                sessionState.currentIntensity = 0.0f;
            }
        }
    }

    //==============================================================================
    SessionSettings currentSettings;
    SessionState sessionState;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AudioVisualEntrainment)
};

//==============================================================================
/**
 * @brief Safety Warning Dialog (MUST be shown before use!)
 */
class SafetyWarningText
{
public:
    static juce::String getWarningText()
    {
        return R"(
⚠️⚠️⚠️ WICHTIGE SICHERHEITSHINWEISE ⚠️⚠️⚠️

DIESES SYSTEM IST NUR FÜR ENTERTAINMENT/FORSCHUNGSZWECKE!

KEINE MEDIZINISCHEN VERSPRECHEN! KEINE THERAPEUTISCHEN CLAIMS!

**WARNUNGEN - NICHT VERWENDEN BEI**:
❌ Epilepsie oder Anfallsleiden
❌ Photosensitivität oder Lichtempfindlichkeit
❌ Herzschrittmacher oder Herzproblemen
❌ Schwangerschaft
❌ Migräne-Anfälligkeit
❌ Psychischen Erkrankungen ohne ärztliche Aufsicht

**NICHT VERWENDEN WÄHREND**:
❌ Autofahren oder Bedienen von Maschinen
❌ Bei Müdigkeit oder Erschöpfung
❌ Unter Einfluss von Medikamenten/Alkohol

**HAFTUNGSAUSSCHLUSS**:
• Dies ist KEIN medizinisches Gerät
• Dies ist KEINE Therapie oder Behandlung
• Ersetzen Sie NIEMALS ärztliche Behandlung!
• Konsultieren Sie einen Arzt vor der Nutzung
• Nutzung erfolgt auf eigenes Risiko

**BEI UNWOHLSEIN**:
• SOFORT stoppen!
• Licht und Ton ausschalten!
• Bei anhaltenden Symptomen: Arzt aufsuchen!

Alle Aussagen sind für Bildungs- und Forschungszwecke.
Keine therapeutischen Wirkungen werden versprochen.

Ich habe diese Warnungen gelesen und verstanden.
)";
    }

    static juce::String getDisclaimerShort()
    {
        return "⚠️ FOR ENTERTAINMENT/RESEARCH ONLY • NOT A MEDICAL DEVICE • CONSULT PHYSICIAN BEFORE USE ⚠️";
    }
};

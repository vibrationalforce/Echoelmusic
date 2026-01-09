#pragma once

#include <JuceHeader.h>
#include <map>
#include <vector>

/**
 * BrainwaveEntrainment
 *
 * WISSENSCHAFTLICH FUNDIERTES Binaural-Beat und Isochronic-Tone System.
 * Basiert auf peer-reviewed Forschung (Goessl 2017, MIT Tsai Lab, Huang & Charyton 2008).
 *
 * DISCLAIMER:
 * - Dies ist KEIN medizinisches Geraet
 * - Keine therapeutischen Ansprueche
 * - Nur fuer Entspannung, Meditation und kreative Zwecke
 * - Bei Epilepsie oder Anfallsleiden NICHT verwenden
 * - Ergebnisse sind subjektiv und variieren individuell
 *
 * Wissenschaftliche Basis:
 * - Delta (0.5-4 Hz): Tiefschlaf-assoziiert
 * - Theta (4-8 Hz): Meditation, Entspannung (Goessl 2017)
 * - Alpha (8-14 Hz): Entspannte Wachheit
 * - Beta (14-30 Hz): Konzentration, Aufmerksamkeit
 * - Gamma (40 Hz): MIT GENUS Forschung (Li-Huei Tsai Lab)
 *
 * Referenzen:
 * - Goessl VC et al. (2017). Psychophysiology. doi:10.1111/psyp.12911
 * - MIT Tsai Lab: 40Hz Gamma Entrainment Research
 * - Huang TL, Charyton C (2008). Alternative Therapies 14(5): 38-49
 */
class BrainwaveEntrainment
{
public:
    //==========================================================================
    // Brainwave States (Scientifically Validated)
    //==========================================================================

    enum class BrainwaveState
    {
        Delta,           // 0.5-4 Hz (Deep sleep associated)
        Theta,           // 4-8 Hz (Meditation, relaxation)
        Alpha,           // 8-14 Hz (Relaxed wakefulness)
        Beta,            // 14-30 Hz (Focus, alertness)
        Gamma            // 30-50 Hz (Higher cognitive functions)
    };

    //==========================================================================
    // Entrainment Session
    //==========================================================================

    struct EntrainmentSession
    {
        juce::String name;
        BrainwaveState targetState;

        // Primary entrainment frequency (Hz)
        float entrainmentFrequency = 10.0f;  // Alpha default

        // Carrier frequency for Multidimensional Brainwave Entrainment (Hz)
        float carrierFrequency = 200.0f;  // Audible carrier

        // Duration & amplitude
        float duration = 600.0f;     // Seconds (10 min default)
        float amplitude = 0.3f;      // 0.0 to 1.0 (gentle default)

        // Modulation (optional breathing rhythm)
        float amplitudeModulation = 0.0f;  // Hz

        EntrainmentSession() = default;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    BrainwaveEntrainment();
    ~BrainwaveEntrainment() = default;

    //==========================================================================
    // Session Management
    //==========================================================================

    /** Get preset session for brainwave state */
    EntrainmentSession getPresetSession(BrainwaveState state);

    /** Set custom session */
    void setSession(const EntrainmentSession& session);
    const EntrainmentSession& getCurrentSession() const { return currentSession; }

    /** Set specific entrainment frequency (Hz) */
    void setEntrainmentFrequency(float frequencyHz);

    /** Set carrier frequency for Multidimensional Brainwave Entrainment (Hz) */
    void setCarrierFrequency(float frequencyHz);

    //==========================================================================
    // Entrainment Mode
    //==========================================================================

    enum class EntrainmentMode
    {
        BinauralBeat,    // Requires stereo headphones
        IsochronicTone,  // Works with speakers
        Combined         // Both methods
    };

    void setMode(EntrainmentMode mode);
    EntrainmentMode getMode() const { return entrainmentMode; }

    //==========================================================================
    // Bio-Feedback Integration (Optional)
    //==========================================================================

    /** Update with current bio-data for adaptive entrainment */
    void setBioData(float hrv, float coherence, float heartRate);

    /** Enable adaptive frequency adjustment */
    void setAdaptiveEnabled(bool enabled);

    //==========================================================================
    // Session Control
    //==========================================================================

    void startSession();
    void stopSession();
    void pauseSession();
    void resumeSession();

    float getSessionProgress() const;
    double getRemainingTime() const;
    bool isSessionActive() const { return sessionActive; }

    //==========================================================================
    // Processing
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Visualization
    //==========================================================================

    std::vector<float> getCurrentWaveform() const;

    //==========================================================================
    // Health Disclaimer
    //==========================================================================

    static juce::String getDisclaimer()
    {
        return "DISCLAIMER: This is NOT a medical device. Multidimensional Brainwave Entrainment and "
               "isochronic tones are for relaxation and creative purposes only. "
               "Do NOT use if you have epilepsy or seizure disorders. "
               "Results vary individually. Consult a physician before use.";
    }

private:
    //==========================================================================
    // Member Variables
    //==========================================================================

    EntrainmentSession currentSession;
    EntrainmentMode entrainmentMode = EntrainmentMode::BinauralBeat;

    bool sessionActive = false;
    bool sessionPaused = false;
    double sessionStartTime = 0.0;
    double sessionDuration = 0.0;
    double elapsedTime = 0.0;

    // Bio-feedback
    float currentHRV = 0.5f;
    float currentCoherence = 0.5f;
    float currentHeartRate = 70.0f;
    bool adaptiveEnabled = false;

    // Audio generation
    double currentSampleRate = 48000.0;
    std::array<double, 2> oscillatorPhases {{0.0, 0.0}};
    double isochronicPhase = 0.0;

    // Visualization
    std::vector<float> currentWaveform;

    //==========================================================================
    // Frequency Database (Scientifically Validated Only)
    //==========================================================================

    void initializeFrequencyDatabase();
    std::map<BrainwaveState, std::pair<float, float>> brainwaveRanges;

    //==========================================================================
    // Audio Generation
    //==========================================================================

    void generateBinauralBeat(juce::AudioBuffer<float>& buffer);
    void generateIsochronicTone(juce::AudioBuffer<float>& buffer);
    void applyAmplitudeModulation(juce::AudioBuffer<float>& buffer, float modFreq);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (BrainwaveEntrainment)
};

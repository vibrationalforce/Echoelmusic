#pragma once

#include <JuceHeader.h>
#include <map>
#include <vector>

/**
 * ResonanceHealer
 *
 * Professional healing frequency system for organ resonance and wellness.
 * Brings organs back into coherence using specific frequencies.
 *
 * Features:
 * - Organ-specific resonance frequencies
 * - Solfeggio frequencies (396Hz, 417Hz, 528Hz, etc.)
 * - Schumann resonance (7.83Hz Earth frequency)
 * - Chakra tuning frequencies
 * - Binaural beats (Alpha, Beta, Theta, Delta, Gamma)
 * - Isochronic tones
 * - Bio-feedback integration
 * - Personalized healing programs
 * - Session tracking & progress monitoring
 */
class ResonanceHealer
{
public:
    //==========================================================================
    // Organ Resonance Frequencies (Research-based)
    //==========================================================================

    enum class Organ
    {
        Brain,           // 72 Hz
        Heart,           // 67-70 Hz
        Lungs,           // 58-65 Hz
        Liver,           // 55-60 Hz
        Kidneys,         // 50-55 Hz
        Stomach,         // 58 Hz
        Intestines,      // 48 Hz
        Pancreas,        // 60 Hz
        Spleen,          // 55 Hz
        Thyroid,         // 16 Hz
        AdrenalGlands,   // 24 Hz
        Bones,           // 38 Hz
        Muscles,         // 25 Hz
        Nerves,          // 72 Hz
        Blood,           // 60 Hz
        WholeBody        // 8 Hz (Schumann)
    };

    //==========================================================================
    // Healing Program
    //==========================================================================

    struct HealingProgram
    {
        juce::String name;
        Organ targetOrgan;

        // Primary frequency
        float frequency = 440.0f;    // Hz

        // Harmonic support frequencies
        std::vector<float> harmonics;

        // Binaural beat (if applicable)
        float binauralBeatFreq = 0.0f;  // Delta/Theta/Alpha/Beta/Gamma

        // Duration & amplitude
        float duration = 600.0f;     // Seconds (10 min default)
        float amplitude = 0.3f;      // 0.0 to 1.0 (gentle default)

        // Modulation
        float amplitudeModulation = 0.0f;  // Hz (breathing rhythm)
        float frequencyModulation = 0.0f;  // Hz (subtle drift)

        HealingProgram() = default;
    };

    //==========================================================================
    // Solfeggio Frequencies
    //==========================================================================

    enum class SolfeggioTone
    {
        UT_396,          // Liberation from fear/guilt
        RE_417,          // Facilitating change
        MI_528,          // DNA repair, love frequency
        FA_639,          // Relationships, connection
        SOL_741,         // Awakening intuition
        LA_852,          // Returning to spiritual order
        SI_963           // Divine consciousness
    };

    //==========================================================================
    // Chakra Frequencies
    //==========================================================================

    enum class Chakra
    {
        Root,            // 194.18 Hz (C)
        Sacral,          // 210.42 Hz (D)
        SolarPlexus,     // 126.22 Hz (E)
        Heart,           // 136.10 Hz (F#)
        Throat,          // 141.27 Hz (G)
        ThirdEye,        // 221.23 Hz (A)
        Crown            // 172.06 Hz (B)
    };

    //==========================================================================
    // Brainwave States (Binaural Beats)
    //==========================================================================

    enum class BrainwaveState
    {
        Delta,           // 0.5-4 Hz (Deep sleep, healing)
        Theta,           // 4-8 Hz (Meditation, creativity)
        Alpha,           // 8-14 Hz (Relaxation, learning)
        Beta,            // 14-30 Hz (Focus, alertness)
        Gamma            // 30-100 Hz (Higher consciousness)
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    ResonanceHealer();
    ~ResonanceHealer() = default;

    //==========================================================================
    // Program Management
    //==========================================================================

    /** Get built-in healing program for organ */
    HealingProgram getOrganProgram(Organ organ);

    /** Get Solfeggio frequency program */
    HealingProgram getSolfeggioProgram(SolfeggioTone tone);

    /** Get Chakra tuning program */
    HealingProgram getChakraProgram(Chakra chakra);

    /** Create custom program */
    void setCustomProgram(const HealingProgram& program);
    const HealingProgram& getCurrentProgram() const { return currentProgram; }

    //==========================================================================
    // Binaural Beats
    //==========================================================================

    /** Set binaural beat for brainwave entrainment */
    void setBinauralBeat(BrainwaveState state);
    void setBinauralBeatFrequency(float frequencyHz);

    /** Enable/disable binaural mode */
    void setBinauralEnabled(bool enabled);
    bool isBinauralEnabled() const { return binauralEnabled; }

    //==========================================================================
    // Bio-Feedback Integration
    //==========================================================================

    /** Update with current bio-data for adaptive healing */
    void setBioData(float hrv, float coherence, float heartRate);

    /** Enable adaptive frequency adjustment based on bio-feedback */
    void setAdaptiveHealingEnabled(bool enabled);

    /** Get suggested healing program based on bio-data */
    HealingProgram suggestProgramFromBioData();

    //==========================================================================
    // Session Control
    //==========================================================================

    /** Start healing session */
    void startSession();

    /** Stop healing session */
    void stopSession();

    /** Pause/Resume */
    void pauseSession();
    void resumeSession();

    /** Get session progress (0.0 to 1.0) */
    float getSessionProgress() const;

    /** Get remaining time (seconds) */
    double getRemainingTime() const;

    bool isSessionActive() const { return sessionActive; }

    //==========================================================================
    // Processing
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Session History & Tracking
    //==========================================================================

    struct SessionRecord
    {
        juce::String date;
        juce::String programName;
        Organ targetOrgan;
        float duration;              // Actual duration completed
        float avgCoherence;          // Average coherence during session
        float startHRV;
        float endHRV;
        bool completed;

        SessionRecord() = default;
    };

    /** Get session history */
    std::vector<SessionRecord> getSessionHistory() const;

    /** Save session record */
    void saveSession(const SessionRecord& record);

    //==========================================================================
    // Visualization
    //==========================================================================

    /** Get current frequency spectrum (for visualization) */
    std::vector<float> getCurrentSpectrum() const;

    /** Get waveform data */
    std::vector<float> getCurrentWaveform() const;

private:
    //==========================================================================
    // Member Variables
    //==========================================================================

    HealingProgram currentProgram;

    bool sessionActive = false;
    bool sessionPaused = false;
    double sessionStartTime = 0.0;
    double sessionDuration = 0.0;
    double elapsedTime = 0.0;

    // Binaural
    bool binauralEnabled = false;
    float binauralBeatFreq = 10.0f;  // Alpha default

    // Bio-feedback
    float currentHRV = 0.5f;
    float currentCoherence = 0.5f;
    float currentHeartRate = 70.0f;
    bool adaptiveHealingEnabled = true;

    // Audio generation
    double currentSampleRate = 48000.0;
    std::array<double, 2> oscillatorPhases {{0.0, 0.0}};  // L/R for binaural

    // Session history
    std::vector<SessionRecord> sessionHistory;

    // Visualization
    std::vector<float> currentSpectrum;
    std::vector<float> currentWaveform;

    //==========================================================================
    // Frequency Database
    //==========================================================================

    void initializeFrequencyDatabase();
    std::map<Organ, float> organFrequencies;
    std::map<SolfeggioTone, float> solfeggioFrequencies;
    std::map<Chakra, float> chakraFrequencies;
    std::map<BrainwaveState, std::pair<float, float>> brainwaveRanges;

    //==========================================================================
    // Audio Generation
    //==========================================================================

    void generateTone(juce::AudioBuffer<float>& buffer, float frequency, float amplitude);
    void generateBinauralBeat(juce::AudioBuffer<float>& buffer, float carrierFreq, float beatFreq);
    void applyAmplitudeModulation(juce::AudioBuffer<float>& buffer, float modFreq);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (ResonanceHealer)
};

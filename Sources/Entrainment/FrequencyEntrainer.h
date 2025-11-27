#pragma once

#include <JuceHeader.h>
#include <map>
#include <vector>

/**
 * FrequencyEntrainer
 *
 * Evidence-based brainwave entrainment system using auditory stimulation.
 *
 * Scientific Foundation:
 * - Brainwave entrainment via binaural beats (Oster, 1973; Lane et al., 1998)
 * - Frequency Following Response (FFR) in auditory processing
 * - EEG-validated brainwave frequency ranges (Niedermeyer & da Silva, 2005)
 *
 * Features:
 * - Binaural beats (Alpha, Beta, Theta, Delta, Gamma)
 * - Isochronic tones for monaural entrainment
 * - Bio-feedback integration (HRV, coherence)
 * - Session tracking & progress monitoring
 *
 * DISCLAIMER: This is a wellness tool, not a medical device.
 * Consult a healthcare professional for medical concerns.
 */
class FrequencyEntrainer
{
public:
    //==========================================================================
    // Brainwave States (Evidence-Based EEG Ranges)
    // Reference: Niedermeyer & da Silva (2005) "Electroencephalography"
    //==========================================================================

    enum class BrainwaveState
    {
        Delta,           // 0.5-4 Hz (Deep sleep, restoration)
        Theta,           // 4-8 Hz (Relaxation, meditation)
        Alpha,           // 8-13 Hz (Calm alertness, learning)
        Beta,            // 13-30 Hz (Active thinking, focus)
        Gamma            // 30-100 Hz (High-level information processing)
    };

    //==========================================================================
    // Entrainment Program
    //==========================================================================

    struct EntrainmentProgram
    {
        juce::String name;
        BrainwaveState targetState;

        // Primary carrier frequency (Hz)
        float carrierFrequency = 200.0f;

        // Beat frequency for entrainment (Hz)
        float beatFrequency = 10.0f;  // Alpha default

        // Harmonic support frequencies
        std::vector<float> harmonics;

        // Duration & amplitude
        float duration = 600.0f;     // Seconds (10 min default)
        float amplitude = 0.3f;      // 0.0 to 1.0 (gentle default)

        // Modulation
        float amplitudeModulation = 0.0f;  // Hz (breathing rhythm)
        float frequencyModulation = 0.0f;  // Hz (subtle drift)

        EntrainmentProgram() = default;
    };

    //==========================================================================
    // Preset Programs (Evidence-Based)
    //==========================================================================

    enum class ProgramPreset
    {
        // Sleep & Rest
        DeepSleep,           // Delta (2 Hz) - Sleep onset
        LightSleep,          // Theta (4 Hz) - Light sleep stages

        // Relaxation
        Meditation,          // Theta (6 Hz) - Meditative states
        Relaxation,          // Alpha (10 Hz) - Calm alertness
        StressReduction,     // Alpha-Theta border (8 Hz)

        // Focus & Performance
        LearningState,       // Alpha (10-12 Hz) - Optimal learning
        FocusedWork,         // Low Beta (14 Hz) - Concentration
        ActiveThinking,      // Beta (18 Hz) - Problem solving
        PeakPerformance,     // Gamma (40 Hz) - High cognition

        // Biofeedback-Driven
        AdaptiveCoherence    // Adjusts based on HRV/coherence
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    FrequencyEntrainer();
    ~FrequencyEntrainer() = default;

    //==========================================================================
    // Program Management
    //==========================================================================

    /** Get preset entrainment program */
    EntrainmentProgram getPresetProgram(ProgramPreset preset);

    /** Get program for specific brainwave state */
    EntrainmentProgram getBrainwaveProgram(BrainwaveState state);

    /** Create custom program */
    void setCustomProgram(const EntrainmentProgram& program);
    const EntrainmentProgram& getCurrentProgram() const { return currentProgram; }

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

    /** Update with current bio-data for adaptive entrainment */
    void setBioData(float hrv, float coherence, float heartRate);

    /** Enable adaptive frequency adjustment based on bio-feedback */
    void setAdaptiveEnabled(bool enabled);

    /** Get suggested program based on bio-data */
    EntrainmentProgram suggestProgramFromBioData();

    //==========================================================================
    // Session Control
    //==========================================================================

    /** Start entrainment session */
    void startSession();

    /** Stop entrainment session */
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
        BrainwaveState targetState;
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

    EntrainmentProgram currentProgram;

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
    bool adaptiveEnabled = true;

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
    std::map<BrainwaveState, std::pair<float, float>> brainwaveRanges;

    //==========================================================================
    // Audio Generation
    //==========================================================================

    void generateTone(juce::AudioBuffer<float>& buffer, float frequency, float amplitude);
    void generateBinauralBeat(juce::AudioBuffer<float>& buffer, float carrierFreq, float beatFreq);
    void applyAmplitudeModulation(juce::AudioBuffer<float>& buffer, float modFreq);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (FrequencyEntrainer)
};

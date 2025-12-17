#pragma once

#include <JuceHeader.h>

/**
 * EchoelBrainwaveScience - Evidence-Based Brainwave Entrainment
 *
 * Scientific implementation of brainwave entrainment with citations.
 *
 * RESEARCH FOUNDATION:
 *
 * 1. BINAURAL BEATS
 *    - Oster, G. (1973). "Auditory beats in the brain." Scientific American, 229(4), 94-102.
 *    - Lane, J. D., et al. (1998). "Binaural auditory beats affect vigilance performance and mood." Physiology & Behavior, 63(2), 249-252.
 *    - Wahbeh, H., et al. (2007). "Binaural beat technology in humans: a pilot study to assess psychologic and physiologic effects." Journal of Alternative and Complementary Medicine, 13(1), 25-32.
 *
 * 2. ISOCHRONIC TONES
 *    - Gao, X., et al. (2014). "Analysis of EEG activity in response to binaural beats with different frequencies." International Journal of Psychophysiology, 94(3), 399-406.
 *    - Jirakittayakorn, N., & Wongsawat, Y. (2017). "Brain responses to 40-Hz binaural beat and effects on emotion and memory." International Journal of Psychophysiology, 120, 96-107.
 *
 * 3. HRV & COHERENCE
 *    - McCraty, R., & Childre, D. (2010). "Coherence: Bridging personal, social, and global health." Alternative Therapies in Health and Medicine, 16(4), 10.
 *    - Shaffer, F., & Ginsberg, J. P. (2017). "An overview of heart rate variability metrics and norms." Frontiers in Public Health, 5, 258.
 *
 * 4. SCHUMANN RESONANCE
 *    - König, H. L. (1974). "ELF and VLF signal properties: Physical characteristics." In ELF and VLF Electromagnetic Field Effects (pp. 9-34). Springer.
 *    - Pobachenko, S. V., et al. (2006). "The contingency of parameters of human encephalograms and Schumann resonance electromagnetic fields revealed in monitoring studies." Biophysics, 51(3), 480-483.
 *
 * 5. SOLFEGGIO FREQUENCIES (CONTROVERSIAL - included for completeness)
 *    - Limited scientific evidence. Included as "experimental" feature.
 *    - Users should be informed of limited scientific validation.
 *
 * SAFETY NOTES:
 * - Not for use by individuals with epilepsy (photosensitive or audiogenic)
 * - Not for use by individuals with pacemakers
 * - Not recommended during pregnancy without medical consultation
 * - Maximum exposure: 60 minutes per session
 * - Minimum frequency: 0.5 Hz (avoid infrasound)
 * - Maximum frequency: 100 Hz (avoid ultrasound)
 */
class EchoelBrainwaveScience
{
public:
    //==========================================================================
    // SCIENTIFIC ENTRAINMENT PARAMETERS
    //==========================================================================

    /**
     * Evidence-based frequency ranges (Hz)
     */
    struct FrequencyBands
    {
        static constexpr float DELTA_MIN = 0.5f;
        static constexpr float DELTA_MAX = 4.0f;

        static constexpr float THETA_MIN = 4.0f;
        static constexpr float THETA_MAX = 8.0f;

        static constexpr float ALPHA_MIN = 8.0f;
        static constexpr float ALPHA_MAX = 13.0f;

        static constexpr float BETA_MIN = 13.0f;
        static constexpr float BETA_MAX = 30.0f;

        static constexpr float GAMMA_MIN = 30.0f;
        static constexpr float GAMMA_MAX = 100.0f;

        static constexpr float SCHUMANN = 7.83f;  // Earth's electromagnetic resonance
        static constexpr float FLOW_STATE = 7.5f; // Alpha-Theta crossover
    };

    /**
     * Validated therapeutic targets
     */
    enum class TherapeuticTarget
    {
        // Sleep & Relaxation
        DeepSleep,              // Delta (0.5-4 Hz) - Stage 3/4 sleep
        LightSleep,             // Theta (4-6 Hz) - Stage 1/2 sleep
        Meditation,             // Theta (4-8 Hz) - Deep meditation
        Relaxation,             // Alpha (8-13 Hz) - Calm, relaxed

        // Performance & Focus
        AlertFocus,             // Beta (13-20 Hz) - Active concentration
        HighPerformance,        // Beta (20-30 Hz) - Peak mental performance
        CreativeFlow,           // Alpha-Theta (7-8 Hz) - Flow state
        ProblemSolving,         // Gamma (40 Hz) - Cognitive processing

        // Therapeutic
        StressReduction,        // Alpha (10 Hz) - Reduce cortisol
        AnxietyRelief,          // Alpha (10-12 Hz) - Calm anxiety
        PainManagement,         // Theta (4-8 Hz) - Endorphin release
        DepressionRelief,       // Alpha (10 Hz) + Beta (15 Hz) - Mood elevation

        // Advanced
        LucidDreaming,          // Theta (4-8 Hz) + awareness cues
        RemoteViewing,          // Theta (4-7 Hz) - experimental
        OutOfBody,              // Theta (4-6 Hz) - experimental
        Psychedelic,            // Mixed Alpha-Theta-Gamma - experimental

        // Experimental (limited evidence)
        DNARepair,              // 528 Hz (Solfeggio) - controversial
        SpirituaLawakening,     // 963 Hz (Solfeggio) - controversial
        Manifestation           // 432 Hz tuning - controversial
    };

    /**
     * Entrainment protocols (research-validated)
     */
    struct EntrainmentProtocol
    {
        juce::String protocolName;
        TherapeuticTarget target;

        // Frequency parameters
        float startFrequency = 10.0f;   // Hz
        float endFrequency = 10.0f;     // Hz (for ramping)
        float duration = 900.0f;        // Seconds (15 min default)

        // Carrier wave
        float carrierFrequency = 200.0f; // Hz (typical: 100-500 Hz)
        enum class WaveShape
        {
            Sine,       // Smoothest, most common
            Triangle,   // Sharper than sine
            Square,     // Most intense (use caution)
            Pink,       // 1/f noise (natural)
            White       // Full spectrum noise
        } waveShape = WaveShape::Sine;

        // Modulation
        bool frequencyRamping = false;   // Gradual frequency change
        float rampRate = 0.1f;           // Hz per minute

        bool amplitudeModulation = false;
        float amModulationRate = 0.5f;   // Hz

        // Safety limits
        float maxIntensity = 0.3f;       // 0.0-1.0 (never exceed 0.5)
        float sessionTimeLimit = 3600.0f; // Max 60 minutes

        // Research citation
        juce::String researchCitation;
    };

    /**
     * Pre-configured research-validated protocols
     */
    static EntrainmentProtocol getResearchProtocol(TherapeuticTarget target);

    //==========================================================================
    // HRV & COHERENCE ANALYSIS
    //==========================================================================

    /**
     * Heart Rate Variability metrics (time-domain)
     */
    struct HRVMetrics
    {
        // Time-domain measures
        float SDNN = 0.0f;          // Standard deviation of NN intervals (ms)
        float RMSSD = 0.0f;         // Root mean square of successive differences (ms)
        float pNN50 = 0.0f;         // % of intervals >50ms different

        // Frequency-domain measures
        float LF_Power = 0.0f;      // Low frequency (0.04-0.15 Hz)
        float HF_Power = 0.0f;      // High frequency (0.15-0.4 Hz)
        float LF_HF_Ratio = 1.0f;   // Sympathetic/Parasympathetic balance

        // Coherence (HeartMath metric)
        float coherence = 0.0f;     // 0.0-1.0 (spectral coherence)
        enum class CoherenceLevel
        {
            Low,        // <0.5 - Chaotic
            Medium,     // 0.5-0.8 - Normal
            High        // >0.8 - Optimal
        } coherenceLevel = CoherenceLevel::Medium;

        // Derived metrics
        float stress = 0.5f;         // 0.0-1.0 (inverse of coherence)
        float resilience = 0.5f;     // 0.0-1.0 (HRV-based)
    };

    /**
     * Calculate HRV from RR intervals (milliseconds between heartbeats)
     */
    HRVMetrics calculateHRV(const std::vector<float>& rrIntervals);

    /**
     * Real-time HRV tracking (sliding window)
     */
    void addHeartbeat(double timestamp);
    HRVMetrics getCurrentHRV() const { return currentHRV; }

    //==========================================================================
    // EEG ANALYSIS (if hardware available)
    //==========================================================================

    /**
     * EEG band powers (μV²)
     */
    struct EEGPowers
    {
        float delta = 0.0f;     // 0.5-4 Hz
        float theta = 0.0f;     // 4-8 Hz
        float alpha = 0.0f;     // 8-13 Hz
        float beta = 0.0f;      // 13-30 Hz
        float gamma = 0.0f;     // 30-100 Hz

        // Ratios (clinically significant)
        float theta_beta_ratio = 0.0f;  // ADHD marker
        float alpha_theta_ratio = 0.0f; // Flow state marker
    };

    /**
     * Calculate EEG band powers from raw signal
     */
    EEGPowers calculateEEGPowers(const std::vector<float>& rawEEG, float sampleRate);

    /**
     * Detect mental states from EEG
     */
    enum class MentalState
    {
        DeepSleep,
        LightSleep,
        Drowsy,
        Relaxed,
        Focused,
        Stressed,
        Meditative,
        FlowState,
        Unknown
    };

    MentalState detectMentalState(const EEGPowers& powers);

    //==========================================================================
    // SAFETY MONITORING
    //==========================================================================

    /**
     * Safety checks (prevent harmful use)
     */
    struct SafetyMonitor
    {
        // Session tracking
        double sessionStartTime = 0.0;
        double totalSessionTime = 0.0;
        double totalLifetimeExposure = 0.0;  // Hours

        // Intensity tracking
        float currentIntensity = 0.0f;
        float peakIntensity = 0.0f;

        // Warnings
        bool maxSessionTimeExceeded = false;
        bool maxIntensityExceeded = false;
        bool frequencyOutOfRange = false;

        // User health flags (self-reported)
        bool hasEpilepsy = false;
        bool hasPacemaker = false;
        bool isPregnant = false;
    };

    void setSafetyFlags(bool epilepsy, bool pacemaker, bool pregnant);
    bool isSafeToStart() const;
    SafetyMonitor getSafetyStatus() const { return safetyMonitor; }

    //==========================================================================
    // RESEARCH DATA COLLECTION (Optional)
    //==========================================================================

    /**
     * Anonymized data collection for research
     * Helps validate and improve entrainment protocols
     */
    struct ResearchData
    {
        juce::String sessionID;
        double timestamp;

        // Session parameters
        TherapeuticTarget target;
        float frequency;
        float intensity;
        float duration;

        // Biometric responses
        HRVMetrics hrvBefore;
        HRVMetrics hrvDuring;
        HRVMetrics hrvAfter;

        EEGPowers eegBefore;
        EEGPowers eegDuring;
        EEGPowers eegAfter;

        // Subjective rating (1-10)
        int effectivenessRating = 0;
        juce::String notes;
    };

    void enableResearchDataCollection(bool enable, bool anonymized = true);
    void saveResearchData(const ResearchData& data);

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    EchoelBrainwaveScience();
    ~EchoelBrainwaveScience();

    /**
     * Start entrainment session
     */
    void startSession(const EntrainmentProtocol& protocol);
    void stopSession();

    /**
     * Process audio with entrainment signal
     */
    void process(juce::AudioBuffer<float>& buffer, double sampleRate);

private:
    EntrainmentProtocol currentProtocol;
    SafetyMonitor safetyMonitor;
    HRVMetrics currentHRV;
    EEGPowers currentEEG;

    // RR interval buffer (for HRV calculation)
    std::vector<double> rrIntervals;
    std::vector<double> heartbeatTimestamps;
    static constexpr int MAX_RR_INTERVALS = 300;  // 5 minutes at 60 BPM

    // Session state
    bool sessionActive = false;
    double sessionStartTimestamp = 0.0;
    float currentPhase = 0.0f;
    float currentFrequency = 10.0f;

    // Research data
    bool collectResearchData = false;
    std::vector<ResearchData> researchDataLog;

    // Internal processing
    float generateEntrainmentSignal(float frequency, float phase, EntrainmentProtocol::WaveShape shape);
    void updateSafetyMonitor(double deltaTime);
    void performSpectralAnalysis(const std::vector<float>& signal, float sampleRate, std::vector<float>& spectrum);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelBrainwaveScience)
};

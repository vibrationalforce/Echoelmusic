#pragma once

#include <JuceHeader.h>
#include <cmath>

//==============================================================================
/**
 * @brief Intelligent Dynamic Processor & Spectral Tools
 *
 * Professional dynamics and spectral processing calculations based on:
 * - Psychoacoustic research (attack/release times)
 * - Studio best practices (ratio, threshold optimization)
 * - Sengpielaudio.com (dB calculations, loudness)
 * - Music production techniques
 *
 * **Scientific Foundation**:
 * 1. **Decibels (dB)**: dB = 20 × log₁₀(amplitude_ratio)
 *    - +6 dB = 2× amplitude
 *    - -6 dB = 0.5× amplitude
 *    - +20 dB = 10× amplitude
 *
 * 2. **Attack/Release Times**:
 *    - Attack: How fast compressor responds to signal increase
 *    - Release: How fast compressor returns to normal
 *    - Optimal times depend on signal type and musical context
 *
 * 3. **Compression Ratio**:
 *    - 2:1 = gentle (mastering)
 *    - 4:1 = moderate (vocals, bass)
 *    - 10:1 = heavy (limiting, drums)
 *    - ∞:1 = brick-wall limiting
 *
 * 4. **Knee**:
 *    - Hard knee: Sudden compression onset
 *    - Soft knee: Gradual compression onset (more musical)
 *
 * References:
 * - https://www.sengpielaudio.com/calculator-dBu.htm
 * - https://www.sengpielaudio.com/calculator-loudness.htm
 */
class IntelligentDynamicProcessor
{
public:
    //==============================================================================
    /**
     * @brief Calculate optimal attack time based on signal type
     *
     * Attack time determines how fast the compressor responds.
     *
     * **Typical Attack Times**:
     * - Fast (0.1-1 ms): Transient control (drums, percussion)
     * - Medium (5-20 ms): Vocals, guitars
     * - Slow (30-100 ms): Bass, mix bus (preserve transients)
     *
     * Returns attack time in milliseconds.
     */
    static float calculateOptimalAttack(const juce::String& signalType,
                                       float aggressiveness = 0.5f)
    {
        // aggressiveness: 0-1 (0 = gentle, 1 = aggressive)
        aggressiveness = juce::jlimit(0.0f, 1.0f, aggressiveness);

        float baseAttack = 10.0f;  // Default medium

        if (signalType == "Drums" || signalType == "Percussion")
        {
            baseAttack = 1.0f;   // Fast (preserve punch or control transients)
        }
        else if (signalType == "Vocals")
        {
            baseAttack = 10.0f;  // Medium
        }
        else if (signalType == "Bass")
        {
            baseAttack = 30.0f;  // Slow (preserve low-end transients)
        }
        else if (signalType == "Guitar")
        {
            baseAttack = 15.0f;  // Medium-fast
        }
        else if (signalType == "Mix Bus" || signalType == "Master")
        {
            baseAttack = 30.0f;  // Slow (transparent)
        }
        else if (signalType == "Piano")
        {
            baseAttack = 5.0f;   // Fast-medium (control dynamics but preserve attack)
        }

        // Adjust based on aggressiveness
        // More aggressive = faster attack (more compression)
        float attackMs = baseAttack * (1.0f - aggressiveness * 0.7f);

        return juce::jlimit(0.1f, 100.0f, attackMs);
    }

    /**
     * @brief Calculate optimal release time based on tempo
     *
     * Release time should often be synchronized to music tempo for
     * natural "breathing" compression.
     *
     * **Typical Release Times**:
     * - Fast (50-100 ms): Aggressive, pumping effect
     * - Medium (200-500 ms): General purpose
     * - Slow (500-1500 ms): Gentle, transparent
     * - Auto: Adapts to signal dynamics
     *
     * Returns release time in milliseconds.
     */
    static float calculateOptimalRelease(float bpm,
                                        const juce::String& signalType,
                                        bool tempoSync = true)
    {
        if (tempoSync)
        {
            // Sync to quarter note or eighth note
            float quarterNoteMs = 60000.0f / bpm;

            if (signalType == "Drums" || signalType == "Percussion")
                return quarterNoteMs / 2.0f;  // 1/8 note (faster)
            else if (signalType == "Mix Bus" || signalType == "Master")
                return quarterNoteMs;         // 1/4 note
            else
                return quarterNoteMs * 0.75f; // Between 1/8 and 1/4
        }
        else
        {
            // Fixed release times
            if (signalType == "Drums")
                return 100.0f;   // Fast
            else if (signalType == "Vocals")
                return 300.0f;   // Medium
            else if (signalType == "Bass")
                return 400.0f;   // Medium-slow
            else if (signalType == "Mix Bus" || signalType == "Master")
                return 500.0f;   // Slow
            else
                return 250.0f;   // Default medium
        }
    }

    //==============================================================================
    /**
     * @brief Calculate optimal compression ratio
     *
     * Ratio determines how much compression is applied above threshold.
     *
     * **Typical Ratios**:
     * - 1.5:1 to 2:1 = Very gentle (mastering, mix bus)
     * - 3:1 to 4:1 = Moderate (vocals, bass, general use)
     * - 6:1 to 10:1 = Heavy (drums, aggressive compression)
     * - 20:1 to ∞:1 = Limiting (peak control)
     */
    static float calculateOptimalRatio(const juce::String& purpose,
                                      float intensity = 0.5f)
    {
        // intensity: 0-1 (0 = gentle, 1 = aggressive)
        intensity = juce::jlimit(0.0f, 1.0f, intensity);

        float baseRatio = 4.0f;  // Default moderate

        if (purpose == "Mastering" || purpose == "Mix Bus")
        {
            baseRatio = 2.0f;    // Gentle
        }
        else if (purpose == "Vocals")
        {
            baseRatio = 4.0f;    // Moderate
        }
        else if (purpose == "Drums")
        {
            baseRatio = 6.0f;    // Heavy
        }
        else if (purpose == "Bass")
        {
            baseRatio = 5.0f;    // Moderate-heavy
        }
        else if (purpose == "Limiting")
        {
            baseRatio = 20.0f;   // Brick-wall
        }
        else if (purpose == "Parallel")
        {
            baseRatio = 10.0f;   // Very heavy (for parallel compression)
        }

        // Adjust based on intensity
        float ratio = baseRatio * (0.5f + intensity);

        return juce::jlimit(1.5f, 30.0f, ratio);
    }

    /**
     * @brief Calculate makeup gain after compression
     *
     * Makeup gain compensates for level reduction caused by compression.
     *
     * Approximate makeup gain = Threshold / (1 + Ratio)
     */
    static float calculateMakeupGain(float thresholdDb,
                                    float ratio,
                                    float reductionDb)
    {
        // Simple estimation: compensate for average gain reduction
        float makeupDb = reductionDb * 0.7f;  // ~70% compensation (to taste)

        return juce::jlimit(0.0f, 20.0f, makeupDb);
    }

    //==============================================================================
    /**
     * @brief Calculate sidechain filter frequency
     *
     * Sidechain filtering allows compressor to respond only to specific
     * frequency ranges.
     *
     * **Common Uses**:
     * - High-pass filter: Reduce bass pumping (80-120 Hz)
     * - Band-pass filter: De-essing (4-8 kHz)
     * - Frequency-dependent compression
     */
    static float calculateSidechainHPF(const juce::String& purpose)
    {
        if (purpose == "Bass Pumping Reduction")
            return 80.0f;    // HPF at 80 Hz (remove sub-bass from detection)
        else if (purpose == "Kick Sidechain")
            return 60.0f;    // HPF at 60 Hz (focus on kick fundamental)
        else if (purpose == "De-essing")
            return 4000.0f;  // HPF at 4 kHz (focus on sibilance)
        else if (purpose == "Vocal Presence")
            return 200.0f;   // HPF at 200 Hz
        else
            return 0.0f;     // No filtering
    }

    //==============================================================================
    /**
     * @brief Convert amplitude ratio to dB
     */
    static float amplitudeToDB(float amplitude)
    {
        if (amplitude <= 0.0f)
            return -100.0f;  // Very quiet

        return 20.0f * std::log10(amplitude);
    }

    /**
     * @brief Convert dB to amplitude ratio
     */
    static float dBToAmplitude(float dB)
    {
        return std::pow(10.0f, dB / 20.0f);
    }

    /**
     * @brief Calculate gain reduction (dB) from compression
     *
     * Given input level, threshold, and ratio, calculates gain reduction.
     */
    static float calculateGainReduction(float inputDb,
                                       float thresholdDb,
                                       float ratio)
    {
        if (inputDb <= thresholdDb)
            return 0.0f;  // No compression below threshold

        // Gain reduction = (input - threshold) × (1 - 1/ratio)
        float overshoot = inputDb - thresholdDb;
        float gainReduction = overshoot * (1.0f - 1.0f / ratio);

        return gainReduction;
    }

    //==============================================================================
    /**
     * @brief Calculate RMS from samples (loudness detection)
     *
     * RMS (Root Mean Square) provides better loudness measurement than peak.
     */
    static float calculateRMS(const float* samples, int numSamples)
    {
        if (numSamples <= 0)
            return 0.0f;

        float sum = 0.0f;
        for (int i = 0; i < numSamples; ++i)
        {
            float sample = samples[i];
            sum += sample * sample;
        }

        return std::sqrt(sum / static_cast<float>(numSamples));
    }

    /**
     * @brief Calculate peak from samples
     */
    static float calculatePeak(const float* samples, int numSamples)
    {
        float peak = 0.0f;
        for (int i = 0; i < numSamples; ++i)
        {
            peak = juce::jmax(peak, std::abs(samples[i]));
        }
        return peak;
    }

    /**
     * @brief Calculate crest factor (peak / RMS ratio)
     *
     * Crest factor indicates dynamic range:
     * - Low crest (~1-2): Heavily compressed, dense
     * - Medium crest (~3-5): Normal music
     * - High crest (~6-12): Very dynamic, classical
     */
    static float calculateCrestFactor(const float* samples, int numSamples)
    {
        float peak = calculatePeak(samples, numSamples);
        float rms = calculateRMS(samples, numSamples);

        if (rms < 0.0001f)
            return 1.0f;

        return peak / rms;
    }

    /**
     * @brief Calculate crest factor in dB
     */
    static float calculateCrestFactorDB(const float* samples, int numSamples)
    {
        float crestFactor = calculateCrestFactor(samples, numSamples);
        return amplitudeToDB(crestFactor);
    }
};

//==============================================================================
/**
 * @brief Spectral Balance & Loudness Calculator
 *
 * Professional loudness and spectral analysis based on:
 * - ITU-R BS.1770 (LUFS/LKFS loudness measurement)
 * - EBU R128 (broadcast loudness standards)
 * - ISO 226:2003 (equal loudness contours)
 * - Sengpielaudio.com (loudness calculations)
 *
 * **Scientific Foundation**:
 * 1. **LUFS (Loudness Units Full Scale)**:
 *    - Standardized loudness measurement
 *    - Frequency-weighted (K-weighting)
 *    - Integrated, short-term, momentary measurements
 *
 * 2. **K-Weighting Filter**:
 *    - High-shelf filter (+4 dB above 2 kHz)
 *    - High-pass filter (-3 dB at 100 Hz)
 *    - Models human loudness perception
 *
 * 3. **Reference Levels**:
 *    - Spotify: -14 LUFS (music streaming)
 *    - YouTube: -13 LUFS
 *    - Apple Music: -16 LUFS
 *    - Broadcast: -23 LUFS (EBU R128)
 *    - CD mastering: -9 to -12 LUFS (loud)
 *
 * References:
 * - ITU-R BS.1770-4: "Algorithms to measure audio programme loudness"
 * - EBU R128: "Loudness normalisation and permitted maximum level"
 * - https://www.sengpielaudio.com/calculator-loudness.htm
 */
class LoudnessCalculator
{
public:
    //==============================================================================
    /**
     * @brief Get target LUFS for platform/genre
     */
    static float getTargetLUFS(const juce::String& platform)
    {
        if (platform == "Spotify")
            return -14.0f;
        else if (platform == "YouTube")
            return -13.0f;
        else if (platform == "Apple Music")
            return -16.0f;
        else if (platform == "Tidal")
            return -14.0f;
        else if (platform == "Broadcast TV" || platform == "EBU R128")
            return -23.0f;
        else if (platform == "Podcast")
            return -16.0f;
        else if (platform == "CD Mastering (Loud)")
            return -9.0f;
        else if (platform == "CD Mastering (Dynamic)")
            return -12.0f;
        else if (platform == "Vinyl")
            return -16.0f;  // More dynamic for vinyl
        else
            return -14.0f;  // Default streaming
    }

    /**
     * @brief Calculate headroom from peak to LUFS target
     *
     * Headroom = 0 dBFS - Peak Level
     *
     * Recommended headroom:
     * - Streaming: 1-2 dB (avoid clipping on codec)
     * - CD: 0.1-0.3 dB (true peak limiting)
     * - Broadcast: 1 dB
     */
    static float calculateHeadroom(float peakDb)
    {
        return 0.0f - peakDb;  // dBFS (0 dB = full scale)
    }

    /**
     * @brief Suggest limiting ceiling based on platform
     */
    static float getLimitingCeiling(const juce::String& platform)
    {
        if (platform == "Streaming" || platform == "Spotify" || platform == "Apple Music")
            return -1.0f;    // -1 dBTP (true peak)
        else if (platform == "CD")
            return -0.3f;    // -0.3 dBTP (tight)
        else if (platform == "Broadcast")
            return -1.0f;    // -1 dBTP
        else if (platform == "Mastering")
            return -0.1f;    // -0.1 dBTP (very tight)
        else
            return -1.0f;    // Default safe
    }

    /**
     * @brief Calculate dynamic range (DR meter)
     *
     * Dynamic Range = Peak - RMS (approximately)
     *
     * DR ratings:
     * - DR6 or less: Very compressed (loud EDM, pop)
     * - DR7-DR9: Moderately compressed (modern rock, pop)
     * - DR10-DR13: Good dynamics (jazz, acoustic, indie)
     * - DR14+: Very dynamic (classical, audiophile)
     */
    static int calculateDynamicRange(float peakDb, float rmsDb)
    {
        float drValue = peakDb - rmsDb;
        return static_cast<int>(std::round(drValue));
    }

    /**
     * @brief Recommend dynamic range target for genre
     */
    static int getTargetDynamicRange(const juce::String& genre)
    {
        if (genre == "EDM" || genre == "Electronic" || genre == "Pop")
            return 7;        // DR7 (loud, compressed)
        else if (genre == "Rock" || genre == "Metal")
            return 8;        // DR8
        else if (genre == "Hip-Hop")
            return 9;        // DR9
        else if (genre == "Jazz" || genre == "Acoustic" || genre == "Indie")
            return 12;       // DR12 (dynamic)
        else if (genre == "Classical" || genre == "Audiophile")
            return 15;       // DR15 (very dynamic)
        else
            return 10;       // Default balanced
    }
};
